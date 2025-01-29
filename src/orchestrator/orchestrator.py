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
    required_fields = ["video_url", "frame_rate", "email"]
    missing_fields = [field for field in required_fields if field not in body]
    if missing_fields:
        raise ValueError(f"Missing required fields: {', '.join(missing_fields)}")

def decode_token(token):
    """
    Decodifica o token JWT usando o Cognito para obter o user_name.
    """
    try:
        cognito_client = boto3.client("cognito-idp")  # Criar instância dentro da função
        response = cognito_client.get_user(AccessToken=token)
        user_name = response["Username"]
        logger.info(f"Decoded token for user_name: {user_name}")
        return user_name
    except ClientError as e:
        logger.error(f"Failed to decode token: {e}")
        raise ValueError("Invalid token")

def save_to_dynamodb(user_name, email, video_id, video_url, frame_rate,step_function_execution_id):
    """
    Salva os dados no DynamoDB.
    """
    try:
        table = dynamodb.Table(TABLE_NAME)
        item = {
            "user_name": user_name,
            "email": email,
            "video_id": video_id,
            "video_url": video_url,
            "frame_rate": frame_rate,
            "status": "INITIATED",
            "step_function_id": step_function_execution_id,
        }
        table.put_item(Item=item)
        logger.info(f"Data saved to DynamoDB for video_id: {video_id}")
    except ClientError as e:
        logger.error(f"Failed to save data to DynamoDB: {e}")
        raise Exception("Database error. Please try again later.")

def start_step_function(user_name, email, video_id, video_url, frame_rate):
    """
    Inicia a execução da Step Function.
    """
    try:
        step_function_response = stepfunctions.start_execution(
            stateMachineArn=STEP_FUNCTION_ARN,
            input=json.dumps({
                "body": {
                    "user_name": user_name,
                    "email": email,
                    "video_id": video_id,
                    "video_url": video_url,
                    "frame_rate": frame_rate
                }
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

        frame_rate = body["frame_rate"]

        if not isinstance(frame_rate, int) or frame_rate <= 0:
            logger.error("[process_video_frames] Invalid frame rate number.")
            raise ValueError("Invalid frame rate number, must be an integer greater than 0")

        video_url = body["video_url"]
        email = body["email"]

        # Decodificar o token para obter o user_name
        user_name = decode_token(token)

        # Gerar UUID para video_id
        video_id = str(uuid.uuid4())

        # Iniciar Step Function e salvar no DynamoDB
        step_function_execution_id = start_step_function(user_name, email, video_id, video_url, frame_rate)
        save_to_dynamodb(user_name, email, video_id, video_url, frame_rate,step_function_execution_id)

        # Retornar resposta estruturada
        return create_response(200, data={
            "user_name": user_name,
            "email": email,
            "video_id": video_id,
            "video_url": video_url,
            "frame_rate": frame_rate,
            "step_function_execution_id": step_function_execution_id
        })

    except ValueError as ve:
        logger.error(f"Validation error: {ve}")
        return create_response(400, message=str(ve))

    except Exception as e:
        logger.error(f"Unexpected error: {e}")
        return create_response(500, message="An unexpected error occurred. Please try again later.")