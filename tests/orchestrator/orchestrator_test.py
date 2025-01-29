import json
import os
from unittest import TestCase
from unittest.mock import patch, MagicMock

# Definir variáveis de ambiente mockadas
os.environ["DYNAMO_TABLE_NAME"] = "mocked_table"
os.environ["STEP_FUNCTION_ARN"] = "mocked_step_function"
os.environ["COGNITO_USER_POOL_ID"] = "mocked_cognito_pool"

# Importar a Lambda após definir variáveis de ambiente
from src.orchestrator.orchestrator import lambda_handler, validate_request, normalize_body, decode_token

class TestLambdaOrchestrator(TestCase):
    def setUp(self):
        self.event = {
            "headers": {"Authorization": "Bearer mock_token"},
            "body": json.dumps({
                "video_url": "https://example.com/video.mp4",
                "email": "test@example.com"
            })
        }
        self.context = {}

    @patch("src.orchestrator.orchestrator.boto3.client")
    @patch("src.orchestrator.orchestrator.boto3.resource")
    @patch("src.orchestrator.orchestrator.uuid.uuid4")
    def test_lambda_handler_success(self, mock_uuid, mock_boto3_resource, mock_boto3_client):
        """
        Testa um fluxo bem-sucedido da Lambda.
        """
        mock_uuid.return_value = "mocked-video-id"

        # Mock do Cognito
        mock_cognito = MagicMock()
        mock_cognito.get_user.return_value = {"Username": "mocked_user"}

        # Mock do DynamoDB
        mock_dynamodb = MagicMock()
        mock_boto3_resource.return_value.Table.return_value = mock_dynamodb

        # Mock da Step Function
        mock_stepfunctions = MagicMock()
        mock_stepfunctions.start_execution.return_value = {"executionArn": "mocked_step_function_arn"}

        def boto3_client_side_effect(service_name):
            if service_name == "cognito-idp":
                return mock_cognito
            elif service_name == "stepfunctions":
                return mock_stepfunctions
            return MagicMock()

        mock_boto3_client.side_effect = boto3_client_side_effect

        response = lambda_handler(self.event, self.context)
        response_body = response["body"]

        self.assertEqual(response["statusCode"], 200)
        self.assertEqual(response_body["video_id"], "mocked-video-id")
        self.assertEqual(response_body["stepFunctionId"], "mocked_step_function_arn")

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
        mock_cognito.get_user.side_effect = Exception("Invalid token")
        mock_boto3_client.return_value = mock_cognito

        with self.assertRaises(ValueError):
            decode_token("invalid_token")

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

        # Mock do DynamoDB com falha
        mock_dynamodb = MagicMock()
        mock_dynamodb.put_item.side_effect = Exception("DynamoDB Failure")
        mock_boto3_resource.return_value.Table.return_value = mock_dynamodb

        def boto3_client_side_effect(service_name):
            if service_name == "cognito-idp":
                return mock_cognito
            return MagicMock()

        mock_boto3_client.side_effect = boto3_client_side_effect

        response = lambda_handler(self.event, self.context)
        response_body = response["body"]

        self.assertEqual(response["statusCode"], 500)
        self.assertIn("An unexpected error occurred", response_body["message"])

    def test_lambda_handler_missing_fields(self):
        """
        Testa erro quando a requisição está faltando campos obrigatórios.
        """
        self.event["body"] = json.dumps({"email": "test@example.com"})  # Falta "video_url"
        response = lambda_handler(self.event, self.context)
        response_body = response["body"]

        self.assertEqual(response["statusCode"], 400)
        self.assertIn("Missing required fields", response_body["message"])