resource "aws_sfn_state_machine" "step_function" {
  name     = "${var.prefix_name}-${var.step_function_name}"
  role_arn = aws_iam_role.step_function_role.arn

  definition = <<EOF
{
  "Comment": "Step Function for video processing with retries and error handling",
  "StartAt": "LogInput",
  "States": {
    "LogInput": {
      "Type": "Pass",
      "ResultPath": "$.log",
      "Next": "UpdateStatusToUploadStarted"
    },
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
      "Retry": [
        {
          "ErrorEquals": ["DynamoDB.ProvisionedThroughputExceededException"],
          "IntervalSeconds": 2,
          "MaxAttempts": 3,
          "BackoffRate": 2
        }
      ],
      "Catch": [
        {
          "ErrorEquals": ["States.ALL"],
          "ResultPath": "$.error",
          "Next": "LogError"
        }
      ],
      "Next": "Upload"
    },
    "Upload": {
      "Type": "Task",
      "Resource": "arn:aws:lambda:${var.aws_region}:${data.aws_caller_identity.current.account_id}:function:${var.prefix_name}-${var.lambda_upload_name}-lambda",
      "Retry": [
        {
          "ErrorEquals": ["Lambda.ServiceException", "Lambda.AWSLambdaException"],
          "IntervalSeconds": 2,
          "MaxAttempts": 2,
          "BackoffRate": 1.5
        },
        {
          "ErrorEquals": ["Lambda.TooManyRequestsException"],
          "IntervalSeconds": 5,
          "MaxAttempts": 3,
          "BackoffRate": 2
        }
      ],
      "Catch": [
        {
          "ErrorEquals": ["States.ALL"],
          "ResultPath": "$.error",
          "Next": "LogError"
        }
      ],
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
      "Catch": [
        {
          "ErrorEquals": ["States.ALL"],
          "ResultPath": "$.error",
          "Next": "LogError"
        }
      ],
      "Next": "Processing"
    },
    "Processing": {
      "Type": "Task",
      "Resource": "arn:aws:lambda:${var.aws_region}:${data.aws_caller_identity.current.account_id}:function:${var.prefix_name}-${var.lambda_processing_name}-lambda",
      "Catch": [
        {
          "ErrorEquals": ["States.ALL"],
          "ResultPath": "$.error",
          "Next": "LogError"
        }
      ],
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
      "Catch": [
        {
          "ErrorEquals": ["States.ALL"],
          "ResultPath": "$.error",
          "Next": "LogError"
        }
      ],
      "Next": "Send"
    },
    "Send": {
      "Type": "Task",
      "Resource": "arn:aws:lambda:${var.aws_region}:${data.aws_caller_identity.current.account_id}:function:${var.prefix_name}-${var.lambda_send_name}-lambda",
      "Catch": [
        {
          "ErrorEquals": ["States.ALL"],
          "ResultPath": "$.error",
          "Next": "LogError"
        }
      ],
      "End": true
    },
    "LogError": {
      "Type": "Pass",
      "Parameters": {
        "ErrorMessage": "An error occurred",
        "ErrorDetails.$": "$.error"
      },
      "Next": "FailState"
    },
    "FailState": {
      "Type": "Fail",
      "Error": "WorkflowFailed",
      "Cause": "An error occurred during the execution of the Step Function."
    }
  }
}
EOF

  depends_on = [
    aws_iam_role.step_function_role
  ]
}
