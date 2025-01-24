import boto3
import logging
import os
import uuid
from botocore.exceptions import ClientError

# Configuração do logger
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Inicialização de clientes AWS
dynamodb = boto3.resource("dynamodb")
cognito = boto3.client("cognito-idp")
stepfunctions = boto3.client("stepfunctions")

# Variáveis de ambiente
TABLE_NAME = os.environ["DYNAMO_TABLE_NAME"]
STEP_FUNCTION_ARN = os.environ["STEP_FUNCTION_ARN"]
COGNITO_USER_POOL_ID = os.environ["COGNITO_USER_POOL_ID"]

def validate_request(event):
    """
    Valida os campos obrigatórios na requisição.
    """
    required_fields = ["videoLink", "email"]
    missing_fields = [field for field in required_fields if field not in event["body"]]
    if missing_fields:
        raise ValueError(f"Missing required fields: {', '.join(missing_fields)}")

    if "Authorization" not in event["headers"]:
        raise ValueError("Authorization token is missing")

def decode_token(token):
    """
    Decodifica o token JWT usando o Cognito para obter o username.
    """
    try:
        response = cognito.get_user(AccessToken=token)
        username = response["Username"]
        return username
    except ClientError as e:
        logger.error(f"Failed to decode token: {e}")
        raise ValueError("Invalid token")

def lambda_handler(event, context):
    """
    Entrada principal da Lambda.
    """
    try:
        # Validação da requisição
        validate_request(event)
        token = event["headers"]["Authorization"].replace("Bearer ", "")
        video_link = event["body"]["videoLink"]
        email = event["body"]["email"]

        # Decodificar o token para obter o username
        username = decode_token(token)

        # Gerar UUID para videoId
        video_id = str(uuid.uuid4())

        # Iniciar Step Function
        step_function_response = stepfunctions.start_execution(
            stateMachineArn=STEP_FUNCTION_ARN,
            input={
                "videoId": video_id,
                "username": username,
                "videoLink": video_link,
                "email": email,
            },
        )

        # Obter o ARN da execução da Step Function
        step_function_execution_id = step_function_response["executionArn"]

        # Salvar os dados no DynamoDB
        table = dynamodb.Table(TABLE_NAME)
        item = {
            "videoId": video_id,
            "username": username,
            "videoLink": video_link,
            "email": email,
            "status": "INITIATED",
            "stepFunctionId": step_function_execution_id,
        }
        table.put_item(Item=item)

        logger.info(f"Process started for videoId: {video_id} with Step Function ID: {step_function_execution_id}")

        return {
            "statusCode": 200,
            "body": {
                "videoId": video_id,
                "username": username,
                "status": "INITIATED",
                "stepFunctionId": step_function_execution_id,
            }
        }
    except ValueError as ve:
        logger.error(f"Validation error: {ve}")
        return {"statusCode": 400, "body": str(ve)}
    except Exception as e:
        logger.error(f"Unexpected error: {e}")
        return {"statusCode": 500, "body": "Internal server error"}
