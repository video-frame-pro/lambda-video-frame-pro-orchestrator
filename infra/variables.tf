######### PREFIXO DO PROJETO ###########################################

variable "prefix_name" {
  description = "Prefixo para nomear todos os recursos do projeto"
}

######### AWS INFOS ####################################################

variable "aws_region" {
  description = "Região AWS onde os recursos serão provisionados"
}

######### PROJECT INFOS ################################################

variable "lambda_name" {
  description = "Nome da função Lambda principal"
}

variable "lambda_handler" {
  description = "Handler da função Lambda principal"
}

variable "lambda_zip_path" {
  description = "Caminho para o pacote ZIP contendo o código da função Lambda"
}

######### DYNAMO INFOS #################################################

variable "dynamo_table_name" {
  description = "Nome da tabela DynamoDB usada para armazenar informações de vídeos"
}

######### LOGS CLOUD WATCH #############################################

variable "log_retention_days" {
  description = "Número de dias para retenção dos logs no CloudWatch"
}

######### STEP FUNCTION INFOS ##########################################

variable "step_function_name" {
  description = "Nome da Step Function para processar o fluxo de vídeos"
}

variable "lambda_upload_name" {
  description = "Nome da função Lambda responsável pelo upload na Step Function"
}

variable "lambda_processing_name" {
  description = "Nome da função Lambda responsável pelo processamento na Step Function"
}

variable "lambda_send_name" {
  description = "Nome da função Lambda responsável pelo envio de resultados na Step Function"
}

######### SSM VARIABLES INFOS ##########################################

variable "cognito_user_pool_id_ssm" {
  description = "Caminho no SSM para o ID do User Pool do Cognito"
}
