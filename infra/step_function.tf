######### STEP FUNCTION ################################################
# Step Function para processar o fluxo do vídeo
resource "aws_sfn_state_machine" "step_function" {
  name     = "${var.prefix_name}-${var.step_function_name}"
  role_arn = aws_iam_role.step_function_role.arn

  definition = <<EOF
{
  "Comment": "Step Function for video processing",
  "StartAt": "UpdateStatusToUploadStarted",
  "States": {
    "UpdateStatusToUploadStarted": {
      "Type": "Task",
      "Resource": "arn:aws:states:::dynamodb:updateItem",
      "Parameters": {
        "TableName": "${var.dynamo_table_name}",
        "Key": {
          "videoId": {
            "S.$": "$.videoId"
          },
          "username": {
            "S.$": "$.username"
          }
        },
        "UpdateExpression": "SET #status = :status",
        "ExpressionAttributeNames": {
          "#status": "status"
        },
        "ExpressionAttributeValues": {
          ":status": {
            "S": "UPLOAD_STARTED"
          }
        }
      },
      "Next": "Upload"
    },
    "Upload": {
      "Type": "Task",
      "Resource": "arn:aws:lambda:${var.aws_region}:${data.aws_caller_identity.current.account_id}:function/${var.prefix_name}-${var.lambda_upload_name}-lambda",
      "Next": "UpdateStatusToUploadCompleted"
    },
    "UpdateStatusToUploadCompleted": {
      "Type": "Task",
      "Resource": "arn:aws:states:::dynamodb:updateItem",
      "Parameters": {
        "TableName": "${var.dynamo_table_name}",
        "Key": {
          "videoId": {
            "S.$": "$.videoId"
          },
          "username": {
            "S.$": "$.username"
          }
        },
        "UpdateExpression": "SET #status = :status",
        "ExpressionAttributeNames": {
          "#status": "status"
        },
        "ExpressionAttributeValues": {
          ":status": {
            "S": "UPLOAD_COMPLETED"
          }
        }
      },
      "Next": "Processing"
    },
    "Processing": {
      "Type": "Task",
      "Resource": "arn:aws:lambda:${var.aws_region}:${data.aws_caller_identity.current.account_id}:function/${var.prefix_name}-${var.lambda_processing_name}-lambda",
      "Next": "UpdateStatusToProcessingCompleted"
    },
    "UpdateStatusToProcessingCompleted": {
      "Type": "Task",
      "Resource": "arn:aws:states:::dynamodb:updateItem",
      "Parameters": {
        "TableName": "${var.dynamo_table_name}",
        "Key": {
          "videoId": {
            "S.$": "$.videoId"
          },
          "username": {
            "S.$": "$.username"
          }
        },
        "UpdateExpression": "SET #status = :status",
        "ExpressionAttributeNames": {
          "#status": "status"
        },
        "ExpressionAttributeValues": {
          ":status": {
            "S": "PROCESSING_COMPLETED"
          }
        }
      },
      "Next": "Send"
    },
    "Send": {
      "Type": "Task",
      "Resource": "arn:aws:lambda:${var.aws_region}:${data.aws_caller_identity.current.account_id}:function/${var.prefix_name}-${var.lambda_send_name}-lambda",
      "End": true
    }
  }
}
EOF
}
