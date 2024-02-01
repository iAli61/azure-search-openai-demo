import argparse
import asyncio
import os
from typing import Any, Optional
from azure.core.credentials import AzureKeyCredential

from prepdocslib.blobmanager import BlobManager
from prepdocslib.embeddings import (
    AzureOpenAIEmbeddingService,
    ImageEmbeddings,
    OpenAIEmbeddings,
    OpenAIEmbeddingService,
)
from prepdocslib.filestrategy import DocumentAction, FileStrategy
from prepdocslib.listfilestrategy import (
    ADLSGen2ListFileStrategy,
    ListFileStrategy,
    LocalListFileStrategy,
)
from prepdocslib.pdfparser import DocumentAnalysisPdfParser, LocalPdfParser, PdfParser
from prepdocslib.strategy import SearchInfo, Strategy
from prepdocslib.textsplitter import TextSplitter

from urllib.parse import unquote
import tempfile

import logging
from azure.identity import DefaultAzureCredential
from azure.core.credentials_async import AsyncTokenCredential


def is_key_empty(key):
    return key is None or len(key.strip()) == 0


async def setup_file_strategy(args: Any, credential) -> FileStrategy:

    blob_manager = BlobManager(
        endpoint=f"https://{args.storageaccount}.blob.core.windows.net",
        container=args.container,
        # credential=args.storagekey,
        credential=credential,
        store_page_images=args.searchimages,
        verbose=args.verbose,
    )

    temp_dir = tempfile.gettempdir()
    for i in range(len(args.urls)):
        blob_url = args.urls[i]
        blob_name = args.blob_names[i]
        # create a unique temp folder
        temp_folder = unquote(f"{temp_dir}/{args.container}/temp/{blob_name.split('.')[0]}")
        logging.info(f"temp_folder: {temp_folder}")
        os.makedirs(temp_folder, exist_ok=True)
        file_path = unquote(f"{temp_folder}/{blob_name}")
        args.files.append(file_path)
        # download blob to temp folder
        blob = unquote('/'.join(blob_url.split('//')[-1].split('/')[2:]))
        await blob_manager.download_blob(blob, file_path)
    

    pdf_parser: PdfParser
    if args.localpdfparser:
        pdf_parser = LocalPdfParser()
    else:
        # check if Azure Document Intelligence credentials are provided
        if args.formrecognizerservice is None:
            print(
                "Error: Azure Document Intelligence service is not provided. Please provide --formrecognizerservice or use --localpdfparser for local pypdf parser."
            )
            exit(1)
        # formrecognizer_creds = AzureKeyCredential(args.formrecognizerkey)
        pdf_parser = DocumentAnalysisPdfParser(
            endpoint=f"https://{args.formrecognizerservice}.cognitiveservices.azure.com/",
            credential=credential,
            # credential=formrecognizer_creds,
            verbose=args.verbose,
        )

    use_vectors = not args.novectors
    embeddings: Optional[OpenAIEmbeddings] = None
    if use_vectors and args.openaihost != "openai":
        
        azure_open_ai_credential = AzureKeyCredential(args.openaikey)

        embeddings = AzureOpenAIEmbeddingService(
            open_ai_service=args.openaiservice,
            open_ai_deployment=args.openaideployment,
            open_ai_model_name=args.openaimodelname,
            credential=azure_open_ai_credential,
            # credential=credential,
            disable_batch=args.disablebatchvectors,
            verbose=args.verbose,
        )
    elif use_vectors:
        embeddings = OpenAIEmbeddingService(
            open_ai_model_name=args.openaimodelname,
            credential=args.openaikey,
            organization=args.openaiorg,
            disable_batch=args.disablebatchvectors,
            verbose=args.verbose,
        )

    image_embeddings: Optional[ImageEmbeddings] = None

    if args.searchimages:
        image_embeddings = (
            ImageEmbeddings(credential=args.visionkey, endpoint=args.visionendpoint, verbose=args.verbose) if args.visionendpoint else None
        )

    print("Processing files...")
    list_file_strategy: ListFileStrategy
    if args.datalakestorageaccount:
        
        print(f"Using Data Lake Gen2 Storage Account {args.datalakestorageaccount}")
        list_file_strategy = ADLSGen2ListFileStrategy(
            data_lake_storage_account=args.datalakestorageaccount,
            data_lake_filesystem=args.datalakefilesystem,
            data_lake_path=args.datalakepath,
            credential=args.datalakekey,
            verbose=args.verbose,
        )
    else:
        print(f"Using local files in {args.files}")
        list_file_strategy = LocalListFileStrategy(path_pattern=args.files, verbose=args.verbose)

    if args.removeall:
        document_action = DocumentAction.RemoveAll
    elif args.remove:
        document_action = DocumentAction.Remove
    else:
        document_action = DocumentAction.Add

    return FileStrategy(
        list_file_strategy=list_file_strategy,
        blob_manager=blob_manager,
        pdf_parser=pdf_parser,
        text_splitter=TextSplitter(has_image_embeddings=args.searchimages),
        document_action=document_action,
        embeddings=embeddings,
        image_embeddings=image_embeddings,
        search_analyzer_name=args.searchanalyzername,
        use_acls=args.useacls,
        category=args.category,
        documents=args.documents,
    )


async def main(strategy: Strategy, credential, args: Any):

    # search_creds = (
    #     credential if is_key_empty(args.searchkey) else AzureKeyCredential(args.searchkey)
    # )

    search_info = SearchInfo(
        endpoint=f"https://{args.searchservice}.search.windows.net/",
        credential=credential,
        index_name=args.index,
        verbose=args.verbose,
    )

    if not args.remove and not args.removeall:
        await strategy.setup(search_info)

    args.documents = await strategy.run(search_info)

def prepdocs(args):
    # Use the current user identity to authenticate with Azure OpenAI, AI Search and Blob Storage (no secrets needed,
    # just use 'az login' locally, and managed identity when deployed on Azure). If you need to use keys, use separate AzureKeyCredential instances with the
    # keys for each service
    # If you encounter a blocking error during a DefaultAzureCredential resolution, you can exclude the problematic credential by using a parameter (ex. exclude_shared_token_cache_credential=True)
    credentials = DefaultAzureCredential()
    # azure_credential = DefaultAzureCredential(exclude_shared_token_cache_credential=True)

    loop = asyncio.new_event_loop()
    asyncio.set_event_loop(loop)
    file_strategy = loop.run_until_complete(setup_file_strategy(args, credentials))
    loop.run_until_complete(main(file_strategy, credentials, args))
    loop.close()
    # remove temp folder
    try:
        for file in args.files:
            os.remove(file)
            os.rmdir(os.path.dirname(file))
    except Exception as e:
        logging.error(f"Error removing temp folder: {e}")

    return args.documents

if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="Prepare documents by extracting content from PDFs, splitting content into sections, uploading to blob storage, and indexing in a search index.",
        epilog="Example: prepdocs.py '..\data\*' --storageaccount myaccount --container mycontainer --searchservice mysearch --index myindex -v",
    )
    parser.add_argument("files", nargs="?", help="Files to be processed")
    parser.add_argument(
        "--datalakestorageaccount", required=False, help="Optional. Azure Data Lake Storage Gen2 Account name"
    )
    # ...

    # Retrieve parameters from environment variables
    args = parser.parse_args([
        os.getenv("FILES") or "",
        "--datalakestorageaccount", os.getenv("DATALAKE_STORAGE_ACCOUNT") or "",
        "--datalakefilesystem", os.getenv("DATALAKE_FILESYSTEM", "gptkbcontainer"),
        "--datalakepath", os.getenv("DATALAKE_PATH") or "",
        "--datalakekey", os.getenv("DATALAKE_KEY") or "",
        "--useacls", str(os.getenv("USE_ACLS") or ""),
        "--category", os.getenv("CATEGORY") or "",
        "--skipblobs", str(os.getenv("SKIP_BLOBS") or ""),
        "--storageaccount", os.getenv("AZURE_STORAGE_ACCOUNT") or "",
        "--container", os.getenv("AZURE_STORAGE_CONTAINER") or "",
        "--storagekey", os.getenv("storagekey") or "",
        "--tenantid", os.getenv("AZURE_TENANT_ID") or "",
        "--searchservice", os.getenv("AZURE_SEARCH_SERVICE") or "",
        "--index", os.getenv("AZURE_SEARCH_INDEX") or "",
        "--searchkey", os.getenv("searchkey") or "",
        "--searchanalyzername", os.getenv("SEARCH_ANALYZER_NAME", "en.microsoft"),
        "--openaihost", os.getenv("OPENAI_HOST") or "",
        "--openaiservice", os.getenv("AZURE_OPENAI_SERVICE") or "",
        "--openaideployment", os.getenv("AZURE_OPENAI_EMB_DEPLOYMENT") or "",
        "--openaimodelname", os.getenv("AZURE_OPENAI_EMB_MODEL_NAME") or "",
        "--novectors", str(os.getenv("NO_VECTORS") or False),
        "--disablebatchvectors", str(os.getenv("DISABLE_BATCH_VECTORS") or False),
        "--openaikey", os.getenv("openaikey") or "",
        "--openaiorg", os.getenv("OPENAI_ORG") or "",
        "--remove", str(os.getenv("REMOVE") or False),
        "--removeall", str(os.getenv("REMOVE_ALL") or False),
        "--localpdfparser", str(os.getenv("LOCAL_PDF_PARSER") or False),
        "--formrecognizerservice", os.getenv("AZURE_FORMRECOGNIZER_SERVICE") or "",
        "--formrecognizerkey", os.getenv("formrecognizerkey") or "",
        "--searchimages", str(os.getenv("SEARCH_IMAGES") or False),
        "--visionendpoint", os.getenv("AZURE_VISION_ENDPOINT") or "",
        "--visionkey", os.getenv("visionkey") or "",
        "--visionKeyVaultName", os.getenv("AZURE_KEY_VAULT_NAME") or "",
        "--visionKeyVaultkey", os.getenv("VISION_SECRET_NAME") or "",
        "--verbose", str(os.getenv("VERBOSE") or False)
    ])

    # loop = asyncio.get_event_loop()
    # file_strategy = loop.run_until_complete(setup_file_strategy(args))
    # loop.run_until_complete(main(file_strategy, args))
    # loop.close()
