import json
import os
from unittest import TestCase
from unittest.mock import patch, MagicMock

from botocore.exceptions import ClientError

# Definir variáveis de ambiente mockadas
os.environ["DYNAMO_TABLE_NAME"] = "mocked_table"
os.environ["STEP_FUNCTION_ARN"] = "mocked_step_function"
os.environ["COGNITO_USER_POOL_ID"] = "mocked_cognito_pool"
os.environ["AWS_REGION"] = "us-east-1"

# Importar a Lambda após definir variáveis de ambiente
from src.orchestrator.orchestrator import lambda_handler, validate_request, normalize_body, decode_token, \
    start_step_function, save_to_dynamodb


class TestLambdaOrchestrator(TestCase):
    def setUp(self):
        self.event = {
            "headers": {"Authorization": "Bearer mock_token"},
            "body": json.dumps({
                "video_url": "https://example.com/video.mp4",
                "frame_rate": 30,  # Adicionado frame_rate para evitar erro de validação
                "email": "test@example.com"
            })
        }
        self.context = {}

    @patch("src.orchestrator.orchestrator.boto3.client")
    def test_decode_token_success(self, mock_boto3_client):
        """
        Testa se o token é decodificado corretamente via Cognito.
        """
        mock_cognito = MagicMock()
        mock_cognito.get_user.return_value = {"Username": "mocked_user"}
        mock_boto3_client.return_value = mock_cognito

        user_name = decode_token("mock_token")
        self.assertEqual(user_name, "mocked_user")

    @patch("src.orchestrator.orchestrator.boto3.client")
    def test_decode_token_failure(self, mock_boto3_client):
        """
        Testa erro ao decodificar um token inválido.
        """
        mock_cognito = MagicMock()
        error_response = {"Error": {"Code": "NotAuthorizedException", "Message": "Invalid token"}}
        mock_cognito.get_user.side_effect = ClientError(error_response, "GetUser")

        mock_boto3_client.return_value = mock_cognito

        with self.assertRaises(ValueError) as context:
            decode_token("invalid_token")

        self.assertEqual(str(context.exception), "Invalid token")

    def test_lambda_handler_invalid_token(self):
        """
        Testa erro ao receber um token inválido na requisição.
        """
        self.event["headers"]["Authorization"] = ""

        response = lambda_handler(self.event, self.context)
        response_body = response["body"]

        self.assertEqual(response["statusCode"], 400)
        self.assertIn("Authorization token is missing", response_body["message"])

    @patch("src.orchestrator.orchestrator.boto3.client")
    @patch("src.orchestrator.orchestrator.boto3.resource")
    def test_lambda_handler_dynamodb_failure(self, mock_boto3_resource, mock_boto3_client):
        """
        Testa erro ao salvar no DynamoDB.
        """
        mock_cognito = MagicMock()
        mock_cognito.get_user.return_value = {"Username": "mocked_user"}

        # Mock de DynamoDB com erro
        mock_dynamodb = MagicMock()
        mock_dynamodb.put_item.side_effect = Exception("DynamoDB Failure")
        mock_boto3_resource.return_value.Table.return_value = mock_dynamodb

        def boto3_client_side_effect(service_name):
            if service_name == "cognito-idp":
                return mock_cognito

        mock_boto3_client.side_effect = boto3_client_side_effect

        response = lambda_handler(self.event, self.context)
        response_body = response["body"]

        self.assertEqual(response["statusCode"], 500)
        self.assertIn("An unexpected error occurred. Please try again later.", response_body["message"])

    def test_lambda_handler_missing_fields(self):
        """
        Testa erro quando a requisição está faltando campos obrigatórios.
        """
        self.event["body"] = json.dumps({"email": "test@example.com"})  # Falta "video_url" e "frame_rate"
        response = lambda_handler(self.event, self.context)
        response_body = response["body"]

        self.assertEqual(response["statusCode"], 400)
        self.assertIn("Missing required fields", response_body["message"])

    def test_normalize_body_with_dict(self):
        """
        Testa se normalize_body retorna corretamente um dicionário já estruturado.
        """
        event = {"body": {"video_url": "https://example.com/video.mp4", "email": "test@example.com"}}
        body = normalize_body(event)
        self.assertIsInstance(body, dict)
        self.assertEqual(body["video_url"], "https://example.com/video.mp4")

    def test_normalize_body_invalid(self):
        """
        Testa se normalize_body levanta erro quando o body está ausente ou inválido.
        """
        event = {"body": None}  # Corpo ausente
        with self.assertRaises(ValueError) as context:
            normalize_body(event)
        self.assertEqual(str(context.exception), "Request body is missing or invalid.")

    ### 2. Testar save_to_dynamodb para falha e sucesso ###

    @patch("src.orchestrator.orchestrator.dynamodb")
    def test_save_to_dynamodb_success(self, mock_dynamodb):
        """
        Testa se os dados são corretamente salvos no DynamoDB sem erro.
        """
        mock_table = MagicMock()
        mock_dynamodb.Table.return_value = mock_table

        save_to_dynamodb("video_id", "mocked_user", "video_url", 30, "email", "step_function_execution_id")

        mock_table.put_item.assert_called_once()

    @patch("src.orchestrator.orchestrator.boto3.resource")
    def test_save_to_dynamodb_failure(self, mock_boto3_resource):
        """
        Testa se o erro ao salvar no DynamoDB é tratado corretamente.
        """
        mock_table = MagicMock()
        error_response = {"Error": {"Code": "InternalServerError", "Message": "DynamoDB is down"}}
        mock_table.put_item.side_effect = ClientError(error_response, "PutItem")

        mock_boto3_resource.return_value.Table.return_value = mock_table

        with self.assertRaises(Exception) as context:
            save_to_dynamodb("video_id", "mocked_user", "video_url", 30, "email", "step_function_execution_id")

        self.assertEqual(str(context.exception), "Database error. Please try again later.")

    ### 3. Testar Step Function ###

    @patch("src.orchestrator.orchestrator.stepfunctions")
    def test_start_step_function_success(self, mock_stepfunctions):
        """
        Testa se a execução da Step Function retorna corretamente a executionArn.
        """
        mock_stepfunctions.start_execution.return_value = {"executionArn": "mock_execution_arn"}

        execution_id = start_step_function("video_id", "mocked_user", "video_url", 30, "email")

        self.assertEqual(execution_id, "mock_execution_arn")

    @patch("src.orchestrator.orchestrator.boto3.client")
    def test_start_step_function_failure(self, mock_boto3_client):
        """
        Testa se erro ao iniciar a Step Function é tratado corretamente.
        """
        mock_stepfunctions = MagicMock()
        error_response = {"Error": {"Code": "InvalidSignatureException", "Message": "The request signature is invalid"}}
        mock_stepfunctions.start_execution.side_effect = ClientError(error_response, "StartExecution")

        mock_boto3_client.return_value = mock_stepfunctions

        with self.assertRaises(ClientError):
            start_step_function("video_id", "mocked_user", "video_url", 30, "email")
