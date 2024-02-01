import azure.functions as func
import logging
import json
import jsonschema

# load env vars
from dotenv import load_dotenv
load_dotenv()

# list all env vars
import os
from jsonschema.exceptions import ValidationError


import argparse
from prepdocslib.blobmanager import BlobManager
from prepdocs import prepdocs

app = func.FunctionApp()

@app.function_name(name="TextEmbedder")
@app.route(route="embed")
def text_chunking(req: func.HttpRequest) -> func.HttpResponse:
    logging.info('Python HTTP trigger function processed a request.')
    for k, v in os.environ.items():
        logging.info(f'{k}={v}')

    args_dict = {
        "datalakestorageaccount": os.getenv("DATALAKE_STORAGE_ACCOUNT") or "",
        "datalakefilesystem": os.getenv("DATALAKE_FILESYSTEM", "gptkbcontainer"),
        "datalakepath": os.getenv("DATALAKE_PATH") or "",
        "datalakekey": os.getenv("DATALAKE_KEY") or "",
        "useacls": os.getenv("USE_ACLS", "").lower() == "true" or False,
        "category": os.getenv("CATEGORY") or "",
        "skipblobs": os.getenv("SKIP_BLOBS").lower() == "true" if os.getenv("SKIP_BLOBS") is not None else True,
        "storageaccount": os.getenv("AZURE_STORAGE_ACCOUNT") or "",
        "container": os.getenv("AZURE_STORAGE_CONTAINER") or "",
        # "storagekey": os.getenv("storagekey") or "",
        "tenantid": os.getenv("AZURE_TENANT_ID") or "",
        "searchservice": os.getenv("AZURE_SEARCH_SERVICE") or "",
        "index": os.getenv("AZURE_SEARCH_INDEX") or "",
        # "searchkey": os.getenv("searchkey") or "",
        "searchanalyzername": os.getenv("SEARCH_ANALYZER_NAME", "en.microsoft"),
        "openaihost": os.getenv("OPENAI_HOST") or "",
        "openaiservice": os.getenv("AZURE_OPENAI_SERVICE") or "",
        "openaideployment": os.getenv("AZURE_OPENAI_EMB_DEPLOYMENT") or "",
        "openaimodelname": os.getenv("AZURE_OPENAI_EMB_MODEL_NAME") or "",
        "novectors": os.getenv("NO_VECTORS") or False,
        "disablebatchvectors": os.getenv("DISABLE_BATCH_VECTORS").lower() == "true" if os.getenv("DISABLE_BATCH_VECTORS") is not None else False,
        "openaikey": os.getenv("openaikey") or "",
        "openaiorg": os.getenv("OPENAI_ORG") or "",
        "remove": os.getenv("REMOVE", "").lower() == "true" or False,
        "removeall": os.getenv("REMOVE_ALL", "").lower() == "true" or False,
        "localpdfparser": os.getenv("LOCAL_PDF_PARSER", "").lower() == "true" or False,
        "formrecognizerservice": os.getenv("AZURE_FORMRECOGNIZER_SERVICE") or "",
        # "formrecognizerkey": os.getenv("formrecognizerkey") or "",
        "searchimages": os.getenv("SEARCH_IMAGES").lower() == "true" if os.getenv("SEARCH_IMAGES") is not None else False,
        "visionendpoint": os.getenv("AZURE_VISION_ENDPOINT") or "",
        "visionkey": os.getenv("visionkey") or "",
        "visionKeyVaultName": os.getenv("AZURE_KEY_VAULT_NAME") or "",
        "visionKeyVaultkey": os.getenv("VISION_SECRET_NAME") or "",
        "verbose": os.getenv("VERBOSE").lower() == "true" if os.getenv("VERBOSE") is not None else False
    }

    # change args_dict to args
    args = argparse.Namespace(**args_dict)



    request = req.get_json()
    logging.info(f"request: {request}")

    try:
        jsonschema.validate(request, schema=get_request_schema_embd())
    except ValidationError as e:
        return func.HttpResponse("Invalid request: {0}".format(e), status_code=400)

    # blob_url = "https://chatdata505.blob.core.windows.net/test/public/Audi%20Mitarbeiterstipendium%20Ingolstadt/FAQ%20Audi%20Mitarbeiter%20Stipendium%20Ingolstadt.pdf"
    urls = []
    blob_names = []
    for value in request["values"]:
        
        # get blob url
        blob_url = value["data"]["blob_url"]  
        # get storage account from url
        storage_account = blob_url.split(".")[0].split("//")[1]
        # get container from url
        container = blob_url.split("/")[3]

        # check storage account is the same as args["storageaccount"]
        if storage_account != args.storageaccount:
            return func.HttpResponse("Invalid storage account", status_code=400)
        # check container is the same as args["container"]
        if container != args.container:
            return func.HttpResponse("Invalid container", status_code=400)
          
        # get blob name 
        blob_name = blob_url.split("/")[-1]
        
        urls.append(blob_url)
        blob_names.append(blob_name)

        # create a unique temp folder
        # temp_folder = f"{args.container}/temp/{blob_name}"
        # files.append(temp_folder)
        # download blob to temp folder
        # await blob_manager.download_blob(blob_name, temp_folder)

    # process files
    args.urls = urls
    args.blob_names = blob_names
    args.files = []
    args.documents = []
    documents = prepdocs(args)

    # 'id': 'file-FAQ_Audi_Mitarb...466-page-0', 
    # 'content': 'FAQ Audi\nMitarbeiter...m möglich?', 
    # 'category': 'test', 
    # 'sourcepage': 'FAQ Audi Mitarbeiter...pdf#page=1', 
    # 'sourcefile': 'FAQ Audi Mitarbeiter...lstadt.pdf', 
    # 'embedding': 
    # round all the numbers in the 'embedding' list to six decimal places, effectively converting them to single-precision floating-point numbers.


    values = []
    for index, value in enumerate(request['values']):
        recordId = value['recordId']
        docs =[]
        for chunk in documents[index]:
            chunk["embedding"] = [float(f"{x:.6f}") for x in chunk["embedding"]]
            docs.append(chunk)

        values.append({
            "recordId": recordId,
            "data": {
                "chunks": docs
            },
            "errors": None,
            "warnings": None
        })


    response_body = { "values": values }
    logging.info(f'no values: {len(values)}')

    logging.info(f'response_body: {response_body}')

    response = func.HttpResponse(json.dumps(response_body, default=lambda obj: obj.__dict__))
    response.headers['Content-Type'] = 'application/json'    
    return response

def get_request_schema_embd():
    return {
        "$schema": "http://json-schema.org/draft-04/schema#",
        "type": "object",
        "properties": {
            "values": {
                "type": "array",
                "minItems": 1,
                "items": {
                    "type": "object",
                    "properties": {
                        "recordId": {"type": "string"},
                        "data": {
                            "type": "object",
                            "properties": {
                                "blob_url": {"type": "string", "minLength": 1},
                            },
                            "required": ["blob_url"],
                        },
                    },
                    "required": ["recordId", "data"],
                },
            }
        },
        "required": ["values"],
    }

