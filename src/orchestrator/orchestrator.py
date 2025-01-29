import boto3
import logging
import os
import uuid
import json
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

def create_response(status_code, message=None, data=None):
    """
    Gera uma resposta formatada.
    """
    response = {"statusCode": status_code, "body": {}}
    if message:
        response["body"]["message"] = message
    if data:
        response["body"].update(data)
    return response

def normalize_body(event):
    """
    Normaliza o corpo da requisição para garantir que seja um dicionário.
    """
    if isinstance(event.get("body"), str):
        return json.loads(event["body"])  # Desserializa string JSON para dicionário
    elif isinstance(event.get("body"), dict):
        return event["body"]  # Já está em formato de dicionário
    else:
        raise ValueError("Request body is missing or invalid.")

def validate_request(body):
    """
    Valida os campos obrigatórios na requisição.
    """
    required_fields = ["video_url", "email"]
    missing_fields = [field for field in required_fields if field not in body]
    if missing_fields:
        raise ValueError(f"Missing required fields: {', '.join(missing_fields)}")

def decode_token(token):
    """
    Decodifica o token JWT usando o Cognito para obter o user_name.
    """
    try:
        response = cognito.get_user(AccessToken=token)
        user_name = response["user_name"]
        logger.info(f"Decoded token for user_name: {user_name}")
        return user_name
    except ClientError as e:
        logger.error(f"Failed to decode token: {e}")
        raise ValueError("Invalid token")

def save_to_dynamodb(video_id, user_name, video_url, email, step_function_execution_id):
    """
    Salva os dados no DynamoDB.
    """
    try:
        table = dynamodb.Table(TABLE_NAME)
        item = {
            "video_id": video_id,
            "user_name": user_name,
            "video_url": video_url,
            "email": email,
            "status": "INITIATED",
            "stepFunctionId": step_function_execution_id,
        }
        table.put_item(Item=item)
        logger.info(f"Data saved to DynamoDB for video_id: {video_id}")
    except Exception as e:
        logger.error(f"Failed to save data to DynamoDB: {e}")
        raise

def start_step_function(video_id, user_name, video_url, email):
    """
    Inicia a execução da Step Function.
    """
    try:
        step_function_response = stepfunctions.start_execution(
            stateMachineArn=STEP_FUNCTION_ARN,
            input=json.dumps({
                "user_name": user_name,
                "email": email,
                "video_id": video_id,
                "video_url": video_url
            }),
        )
        step_function_execution_id = step_function_response["executionArn"]
        logger.info(f"Step Function started with Execution ID: {step_function_execution_id}")
        return step_function_execution_id

    except Exception as e:
        logger.error(f"Failed to start Step Function: {e}")
        raise

def lambda_handler(event, context):
    """
    Entrada principal da Lambda.
    """
    try:
        logger.info(f"Received event: {json.dumps(event)}")

        # Normalizar o corpo da requisição
        body = normalize_body(event)

        # Validar os campos obrigatórios no corpo da requisição
        validate_request(body)

        # Extrair dados do corpo da requisição
        token = event["headers"].get("Authorization", "").replace("Bearer ", "")
        if not token:
            raise ValueError("Authorization token is missing")

        video_url = body["video_url"]
        email = body["email"]

        # Decodificar o token para obter o user_name
        user_name = decode_token(token)

        # Gerar UUID para video_id
        video_id = str(uuid.uuid4())

        # Iniciar Step Function e salvar no DynamoDB
        step_function_execution_id = start_step_function(video_id, user_name, video_url, email)
        save_to_dynamodb(video_id, user_name, video_url, email, step_function_execution_id)

        # Retornar resposta estruturada
        return create_response(200, data={
            "user_name": user_name,
            "email": email,
            "video_id": video_id,
            "video_url": video_url,
            "stepFunctionId": step_function_execution_id
        })

    except ValueError as ve:
        logger.error(f"Validation error: {ve}")
        return create_response(400, message=str(ve))

    except Exception as e:
        logger.error(f"Unexpected error: {e}")
        return create_response(500, message="An unexpected error occurred. Please try again later.")

