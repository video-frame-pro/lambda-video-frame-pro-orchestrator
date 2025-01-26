resource "aws_sfn_state_machine" "step_function" {
  name     = "${var.prefix_name}-${var.step_function_name}"
  role_arn = aws_iam_role.step_function_role.arn

  definition = <<EOF
{
  "Comment": "Step Function for video processing with validation, retries, and error handling",
  "StartAt": "LogInput",
  "States": {
    "LogInput": {
      "Type": "Pass",
      "ResultPath": "$.log",
      "Next": "WaitBeforeDynamoUpdate"
    },
    "WaitBeforeDynamoUpdate": {
      "Type": "Wait",
      "Seconds": 5,
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
      "Next": "ValidateUpdateToUploadStarted"
    },
    "ValidateUpdateToUploadStarted": {
      "Type": "Task",
      "Resource": "arn:aws:states:::dynamodb:getItem",
      "Parameters": {
        "TableName": "${var.dynamo_table_name}",
        "Key": {
          "videoId": {
            "S.$": "$.videoId"
          },
          "username": {
            "S.$": "$.username"
          }
        }
      },
      "ResultPath": "$.ValidationResult",
      "Next": "CheckValidationToUploadStarted"
    },
    "CheckValidationToUploadStarted": {
      "Type": "Choice",
      "Choices": [
        {
          "Variable": "$.ValidationResult.Item.status.S",
          "StringEquals": "UPLOAD_STARTED",
          "Next": "Upload"
        }
      ],
      "Default": "LogError"
    },
    "Upload": {
      "Type": "Task",
      "Resource": "arn:aws:lambda:${var.aws_region}:${data.aws_caller_identity.current.account_id}:function:${var.prefix_name}-${var.lambda_upload_name}-lambda",
      "Retry": [
        {
          "ErrorEquals": ["Lambda.ServiceException", "Lambda.AWSLambdaException"],
          "IntervalSeconds": 2,
          "MaxAttempts": 3,
          "BackoffRate": 2
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
      "Next": "ValidateUpdateToUploadCompleted"
    },
    "ValidateUpdateToUploadCompleted": {
      "Type": "Task",
      "Resource": "arn:aws:states:::dynamodb:getItem",
      "Parameters": {
        "TableName": "${var.dynamo_table_name}",
        "Key": {
          "videoId": {
            "S.$": "$.videoId"
          },
          "username": {
            "S.$": "$.username"
          }
        }
      },
      "ResultPath": "$.ValidationResult",
      "Next": "CheckValidationToUploadCompleted"
    },
    "CheckValidationToUploadCompleted": {
      "Type": "Choice",
      "Choices": [
        {
          "Variable": "$.ValidationResult.Item.status.S",
          "StringEquals": "UPLOAD_COMPLETED",
          "Next": "Processing"
        }
      ],
      "Default": "LogError"
    },
    "Processing": {
      "Type": "Task",
      "Resource": "arn:aws:lambda:${var.aws_region}:${data.aws_caller_identity.current.account_id}:function:${var.prefix_name}-${var.lambda_processing_name}-lambda",
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
      "Resource": "arn:aws:lambda:${var.aws_region}:${data.aws_caller_identity.current.account_id}:function:${var.prefix_name}-${var.lambda_send_name}-lambda",
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
