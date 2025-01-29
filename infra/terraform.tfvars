######### PREFIXO DO PROJETO ###########################################
prefix_name = "video-frame-pro" # Prefixo para nomear todos os recursos

######### AWS INFOS ####################################################
aws_region = "us-east-1" # Região AWS onde os recursos serão provisionados

######### PROJECT INFOS ################################################
lambda_name     = "orchestrator" # Nome da função Lambda principal
lambda_handler  = "orchestrator.lambda_handler" # Handler da função Lambda principal
lambda_zip_path = "../lambda/orchestrator/orchestrator.zip" # Caminho para o ZIP da função Lambda
lambda_runtime  = "python3.12" # Runtime da função Lambda principal

######### DYNAMO INFOS #################################################
dynamo_table_name = "video-frame-pro-metadata-table" # Nome da tabela DynamoDB para armazenar informações

######### LOGS CLOUD WATCH #############################################
log_retention_days = 7 # Dias para retenção dos logs no CloudWatch

######### STEP FUNCTION INFOS ##########################################
step_function_name     = "VideoProcessingStateMachine" # Nome da Step Function
lambda_upload_name     = "upload" # Nome da Lambda para upload
lambda_processing_name = "processing" # Nome da Lambda para processamento
lambda_send_name       = "send" # Nome da Lambda para envio de resultados

######### SSM VARIABLES INFOS ##########################################
cognito_user_pool_id_ssm = "/video-frame-pro/cognito/user_pool_id" # Caminho no SSM para o User Pool ID do Cognito
