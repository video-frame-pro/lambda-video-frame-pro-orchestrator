resource "aws_sfn_state_machine" "step_function" {
  name     = "${var.prefix_name}-${var.step_function_name}"
  role_arn = aws_iam_role.step_function_role.arn

  definition = <<EOF
{
  "Comment": "Step Function for video processing with retries, logs, and consistent error handling",
  "StartAt": "LogInput",
  "States": {
    "LogInput": {
      "Type": "Pass",
      "ResultPath": "$.LogInputResult",
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
          "video_id": {
            "S.$": "$.video_id"
          },
          "user_name": {
            "S.$": "$.user_name"
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
      "ResultPath": "$.UpdateStatusToUploadStartedResult",
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
          "Next": "UpdateStatusToFailed"
        }
      ],
      "Next": "Upload"
    },
    "Upload": {
      "Type": "Task",
      "Resource": "arn:aws:lambda:${var.aws_region}:${data.aws_caller_identity.current.account_id}:function:${var.prefix_name}-${var.lambda_upload_name}-lambda",
      "ResultPath": "$.UploadResult",
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
          "Next": "UpdateStatusToFailed"
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
          "video_id": {
            "S.$": "$.video_id"
          },
          "user_name": {
            "S.$": "$.user_name"
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
      "ResultPath": "$.UpdateStatusToUploadCompletedResult",
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
          "Next": "UpdateStatusToFailed"
        }
      ],
      "Next": "UpdateStatusToProcessingStarted"
    },
    "UpdateStatusToProcessingStarted": {
      "Type": "Task",
      "Resource": "arn:aws:states:::dynamodb:updateItem",
      "Parameters": {
        "TableName": "${var.dynamo_table_name}",
        "Key": {
          "video_id": {
            "S.$": "$.video_id"
          },
          "user_name": {
            "S.$": "$.user_name"
          }
        },
        "UpdateExpression": "SET #status = :status",
        "ExpressionAttributeNames": {
          "#status": "status"
        },
        "ExpressionAttributeValues": {
          ":status": {
            "S": "PROCESSING_STARTED"
          }
        }
      },
      "ResultPath": "$.UpdateStatusToProcessingStartedResult",
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
          "Next": "UpdateStatusToFailed"
        }
      ],
      "Next": "Processing"
    },
    "Processing": {
      "Type": "Task",
      "Resource": "arn:aws:lambda:${var.aws_region}:${data.aws_caller_identity.current.account_id}:function:${var.prefix_name}-${var.lambda_processing_name}-lambda",
      "ResultPath": "$.ProcessingResult",
      "Retry": [
        {
          "ErrorEquals": ["Lambda.ServiceException", "Lambda.AWSLambdaException"],
          "IntervalSeconds": 2,
          "MaxAttempts": 3,
          "BackoffRate": 2
        }
      ],
      "Catch": [
        {
          "ErrorEquals": ["States.ALL"],
          "ResultPath": "$.error",
          "Next": "UpdateStatusToFailed"
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
          "video_id": {
            "S.$": "$.video_id"
          },
          "user_name": {
            "S.$": "$.user_name"
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
      "ResultPath": "$.UpdateStatusToProcessingCompletedResult",
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
          "Next": "UpdateStatusToFailed"
        }
      ],
      "Next": "UpdateStatusToSendStarted"
    },
    "UpdateStatusToSendStarted": {
      "Type": "Task",
      "Resource": "arn:aws:states:::dynamodb:updateItem",
      "Parameters": {
        "TableName": "${var.dynamo_table_name}",
        "Key": {
          "video_id": {
            "S.$": "$.video_id"
          },
          "user_name": {
            "S.$": "$.user_name"
          }
        },
        "UpdateExpression": "SET #status = :status",
        "ExpressionAttributeNames": {
          "#status": "status"
        },
        "ExpressionAttributeValues": {
          ":status": {
            "S": "SEND_STARTED"
          }
        }
      },
      "ResultPath": "$.UpdateStatusToSendStartedResult",
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
          "Next": "UpdateStatusToFailed"
        }
      ],
      "Next": "Send"
    },
    "Send": {
      "Type": "Task",
      "Resource": "arn:aws:lambda:${var.aws_region}:${data.aws_caller_identity.current.account_id}:function:${var.prefix_name}-${var.lambda_send_name}-lambda",
      "ResultPath": "$.SendResult",
      "Retry": [
        {
          "ErrorEquals": ["Lambda.ServiceException", "Lambda.AWSLambdaException"],
          "IntervalSeconds": 2,
          "MaxAttempts": 3,
          "BackoffRate": 2
        }
      ],
      "Catch": [
        {
          "ErrorEquals": ["States.ALL"],
          "ResultPath": "$.error",
          "Next": "UpdateStatusToFailed"
        }
      ],
      "Next": "UpdateStatusToSendCompleted"
    },
    "UpdateStatusToSendCompleted": {
      "Type": "Task",
      "Resource": "arn:aws:states:::dynamodb:updateItem",
      "Parameters": {
        "TableName": "${var.dynamo_table_name}",
        "Key": {
          "video_id": {
            "S.$": "$.video_id"
          },
          "user_name": {
            "S.$": "$.user_name"
          }
        },
        "UpdateExpression": "SET #status = :status",
        "ExpressionAttributeNames": {
          "#status": "status"
        },
        "ExpressionAttributeValues": {
          ":status": {
            "S": "SEND_COMPLETED"
          }
        }
      },
      "ResultPath": "$.UpdateStatusToSendCompletedResult",
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
          "Next": "UpdateStatusToFailed"
        }
      ],
      "End": true
    },
    "UpdateStatusToFailed": {
      "Type": "Task",
      "Resource": "arn:aws:states:::dynamodb:updateItem",
      "Parameters": {
        "TableName": "${var.dynamo_table_name}",
        "Key": {
          "video_id": {
            "S.$": "$.video_id"
          },
          "user_name": {
            "S.$": "$.user_name"
          }
        },
        "UpdateExpression": "SET #status = :status",
        "ExpressionAttributeNames": {
          "#status": "status"
        },
        "ExpressionAttributeValues": {
          ":status": {
            "S": "FAILED"
          }
        }
      },
      "ResultPath": "$.UpdateFailedStatusResult",
      "Next": "LogError"
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
