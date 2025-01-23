######### LAMBDA OUTPUTS ###############################################

# ARN da função Lambda principal
output "lambda_arn" {
  value       = aws_lambda_function.lambda_function.arn
  description = "ARN da função Lambda principal (${var.lambda_name})"
}

# Nome do grupo de logs da Lambda principal
output "lambda_log_group_name" {
  value       = aws_cloudwatch_log_group.lambda_log_group.name
  description = "Nome do grupo de logs no CloudWatch para a função Lambda (${var.lambda_name})"
}

######### STEP FUNCTION OUTPUT #########################################

# ARN da Step Function
output "step_function_arn" {
  value       = aws_sfn_state_machine.step_function.arn
  description = "ARN da Step Function (${var.step_function_name})"
}

######### IAM OUTPUTS ##################################################

# Nome da role da função Lambda principal
output "lambda_role_name" {
  value       = aws_iam_role.lambda_role.name
  description = "Nome da role IAM associada à função Lambda principal (${var.lambda_name})"
}

# Nome da política IAM da função Lambda principal
output "lambda_policy_name" {
  value       = aws_iam_policy.lambda_policy.name
  description = "Nome da política IAM associada à função Lambda principal (${var.lambda_name})"
}

# Nome da role da Step Function
output "step_function_role_name" {
  value       = aws_iam_role.step_function_role.name
  description = "Nome da role IAM associada à Step Function (${var.step_function_name})"
}

# Nome da política IAM da Step Function
output "step_function_policy_name" {
  value       = aws_iam_policy.step_function_policy.name
  description = "Nome da política IAM associada à Step Function (${var.step_function_name})"
}
