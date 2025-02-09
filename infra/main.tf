######### PROVEDOR AWS #################################################
# Configuração do provedor AWS
provider "aws" {
  region = var.aws_region
}

######### DADOS AWS ####################################################
# Obter informações sobre a conta AWS (ID da conta, ARN, etc.)
data "aws_caller_identity" "current" {}

# Obter o User Pool ID do Cognito no SSM
data "aws_ssm_parameter" "cognito_user_pool_id" {
  name = var.cognito_user_pool_id_ssm
}

######### FUNÇÃO LAMBDA ################################################
# Função Lambda principal
resource "aws_lambda_function" "lambda_function" {
  function_name = "${var.prefix_name}-${var.lambda_name}-lambda"
  handler       = var.lambda_handler
  runtime       = var.lambda_runtime
  role          = aws_iam_role.lambda_role.arn
  filename      = var.lambda_zip_path
  source_code_hash = filebase64sha256(var.lambda_zip_path)

  # Variáveis de ambiente para a Lambda
  environment {
    variables = {
      DYNAMO_TABLE_NAME    = var.dynamo_table_name
      STEP_FUNCTION_ARN    = aws_sfn_state_machine.step_function.arn
      COGNITO_USER_POOL_ID = data.aws_ssm_parameter.cognito_user_pool_id.value
    }
  }
}

######### GRUPO DE LOGS ###############################################
# Grupo de logs no CloudWatch para a Lambda
resource "aws_cloudwatch_log_group" "lambda_log_group" {
  name              = "/aws/lambda/${var.prefix_name}-${var.lambda_name}-lambda"
  retention_in_days = var.log_retention_days
}

# Grupo de logs no CloudWatch para a Step Function
resource "aws_cloudwatch_log_group" "step_function_log_group" {
  name              = "/aws/states/${var.prefix_name}-${var.step_function_name}"
  retention_in_days = var.log_retention_days
}

######### IAM: FUNÇÃO LAMBDA ##########################################
# Role IAM para a Lambda principal
resource "aws_iam_role" "lambda_role" {
  name = "${var.prefix_name}-${var.lambda_name}-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action = "sts:AssumeRole",
      Effect = "Allow",
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
}

# Política de permissões para a Lambda principal
resource "aws_iam_policy" "lambda_policy" {
  name = "${var.prefix_name}-${var.lambda_name}-policy"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        # Permissões para o DynamoDB
        Action   = ["dynamodb:PutItem", "dynamodb:GetItem"],
        Effect   = "Allow",
        Resource = "arn:aws:dynamodb:${var.aws_region}:${data.aws_caller_identity.current.account_id}:table/${var.dynamo_table_name}"
      },
      {
        # Permissão para iniciar a Step Function
        Action   = ["states:StartExecution"],
        Effect   = "Allow",
        Resource = aws_sfn_state_machine.step_function.arn
      },
      {
        # Permissões para consultar informações do Cognito
        Action   = [
          "cognito-idp:GetUser",
          "cognito-idp:AdminGetUser"
        ],
        Effect   = "Allow",
        Resource = "*"
      },
      {
        # Permissões para logs no CloudWatch
        Action   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"],
        Effect   = "Allow",
        Resource = "arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/*"
      }
    ]
  })
}

# Anexar a política de permissões à role da Lambda
resource "aws_iam_role_policy_attachment" "lambda_policy_attachment" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.lambda_policy.arn
}

######### IAM: STEP FUNCTION ###########################################
# Role IAM para a Step Function
resource "aws_iam_role" "step_function_role" {
  name = "${var.prefix_name}-${var.step_function_name}-role"

  assume_role_policy = jsonencode({
    Version: "2012-10-17",
    Statement: [{
      Effect: "Allow",
      Principal: { Service: "states.amazonaws.com" },
      Action: "sts:AssumeRole"
    }]
  })
}

# Política de permissões para a Step Function
resource "aws_iam_policy" "step_function_policy" {
  name = "${var.prefix_name}-${var.step_function_name}-policy"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        # Permissões para atualizar o DynamoDB
        Action   = ["dynamodb:UpdateItem", "dynamodb:GetItem"],
        Effect   = "Allow",
        Resource = "arn:aws:dynamodb:${var.aws_region}:${data.aws_caller_identity.current.account_id}:table/${var.dynamo_table_name}"
      },
      {
        # Permissões para invocar Lambdas
        Action   = ["lambda:InvokeFunction"],
        Effect   = "Allow",
        Resource = [
          "arn:aws:lambda:${var.aws_region}:${data.aws_caller_identity.current.account_id}:function:${var.prefix_name}-${var.lambda_upload_name}-lambda",
          "arn:aws:lambda:${var.aws_region}:${data.aws_caller_identity.current.account_id}:function:${var.prefix_name}-${var.lambda_processing_name}-lambda",
          "arn:aws:lambda:${var.aws_region}:${data.aws_caller_identity.current.account_id}:function:${var.prefix_name}-${var.lambda_send_name}-lambda"
        ]
      },
      {
        # Permissões para logs no CloudWatch
        Action   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"],
        Effect   = "Allow",
        Resource = "arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/*"
      }
    ]
  })
}

# Anexar a política de permissões à role da Step Function
resource "aws_iam_role_policy_attachment" "step_function_policy_attachment" {
  role       = aws_iam_role.step_function_role.name
  policy_arn = aws_iam_policy.step_function_policy.arn
}
