resource "aws_sfn_state_machine" "step_function" {
  name     = "${var.prefix_name}-${var.step_function_name}"
  role_arn = aws_iam_role.step_function_role.arn

  definition = <<EOF
  {
  "Comment": "Step Function for video processing with retries, logging, and consistent error handling",
  "StartAt": "LogInput",
  "States": {
    "LogInput": {
      "Type": "Pass",
      "Parameters": {
        "Message": "Step Function started",
        "Details.$": "$"
      },
      "ResultPath": "$.LogInputResult",
      "Next": "WaitBeforeProcessing"
    },
    "WaitBeforeProcessing": {
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
          "video_id": { "S.$": "$.body.video_id" },
          "user_name": { "S.$": "$.body.user_name" }
        },
        "UpdateExpression": "SET #status = :status",
        "ExpressionAttributeNames": { "#status": "status" },
        "ExpressionAttributeValues": { ":status": { "S": "UPLOAD_STARTED" } }
      },
      "ResultPath": "$.LogUploadStarted",
      "Next": "Upload"
    },
    "Upload": {
      "Type": "Task",
      "Resource": "arn:aws:lambda:${var.aws_region}:${data.aws_caller_identity.current.account_id}:function:${var.prefix_name}-${var.lambda_upload_name}-lambda",
      "Parameters": {
        "body": {
          "user_name.$": "$.body.user_name",
          "email.$": "$.body.email",
          "video_id.$": "$.body.video_id",
          "video_url.$": "$.body.video_url"
        }
      },
      "ResultPath": "$.UploadResult",
      "Retry": [{ "ErrorEquals": ["States.ALL"], "IntervalSeconds": 2, "MaxAttempts": 3, "BackoffRate": 2 }],
      "Catch": [{ "ErrorEquals": ["States.ALL"], "Next": "HandleFailure" }],
      "Next": "CheckUploadStatus"
    },
    "CheckUploadStatus": {
      "Type": "Choice",
      "Choices": [
        {
          "Variable": "$.UploadResult.statusCode",
          "NumericEquals": 200,
          "Next": "UpdateStatusToProcessingStarted"
        }
      ],
      "Default": "HandleFailure"
    },
    "UpdateStatusToProcessingStarted": {
      "Type": "Task",
      "Resource": "arn:aws:states:::dynamodb:updateItem",
      "Parameters": {
        "TableName": "${var.dynamo_table_name}",
        "Key": {
          "video_id.$": "$.body.video_id",
          "user_name.$": "$.body.user_name"
        },
        "UpdateExpression": "SET #status = :status",
        "ExpressionAttributeNames": { "#status": "status" },
        "ExpressionAttributeValues": { ":status": { "S": "PROCESSING_STARTED" } }
      },
      "ResultPath": "$.LogProcessingStarted",
      "Next": "Processing"
    },
    "Processing": {
      "Type": "Task",
      "Resource": "arn:aws:lambda:${var.aws_region}:${data.aws_caller_identity.current.account_id}:function:${var.prefix_name}-${var.lambda_processing_name}-lambda",
      "Parameters": {
        "body": {
          "user_name.$": "$.body.user_name",
          "email.$": "$.body.email",
          "video_id.$": "$.body.video_id",
          "frame_rate.$": "$.body.frame_rate"
        }
      },
      "ResultPath": "$.ProcessingResult",
      "Retry": [{ "ErrorEquals": ["States.ALL"], "IntervalSeconds": 2, "MaxAttempts": 3, "BackoffRate": 2 }],
      "Catch": [{ "ErrorEquals": ["States.ALL"], "Next": "HandleFailure" }],
      "Next": "CheckProcessingStatus"
    },
    "CheckProcessingStatus": {
      "Type": "Choice",
      "Choices": [
        {
          "Variable": "$.ProcessingResult.statusCode",
          "NumericEquals": 200,
          "Next": "UpdateStatusToProcessingCompleted"
        }
      ],
      "Default": "HandleFailure"
    },
    "UpdateStatusToProcessingCompleted": {
      "Type": "Task",
      "Resource": "arn:aws:states:::dynamodb:updateItem",
      "Parameters": {
        "TableName": "${var.dynamo_table_name}",
        "Key": {
          "video_id.$": "$.body.video_id",
          "user_name.$": "$.body.user_name"
        },
        "UpdateExpression": "SET #status = :status",
        "ExpressionAttributeNames": { "#status": "status" },
        "ExpressionAttributeValues": { ":status": { "S": "PROCESSING_COMPLETED" } }
      },
      "ResultPath": "$.LogProcessingCompleted",
      "Next": "Send"
    },
    "Send": {
      "Type": "Task",
      "Resource": "arn:aws:lambda:${var.aws_region}:${data.aws_caller_identity.current.account_id}:function:${var.prefix_name}-${var.lambda_send_name}-lambda",
      "Parameters": {
        "body": {
          "email.$": "$.body.email",
          "frame_url.$": "$.ProcessingResult.body.frame_url"
        }
      },
      "ResultPath": "$.SendResult",
      "Retry": [{ "ErrorEquals": ["States.ALL"], "IntervalSeconds": 2, "MaxAttempts": 3, "BackoffRate": 2 }],
      "Catch": [{ "ErrorEquals": ["States.ALL"], "Next": "HandleFailure" }],
      "Next": "CheckSendStatus"
    },
    "CheckSendStatus": {
      "Type": "Choice",
      "Choices": [
        {
          "Variable": "$.SendResult.statusCode",
          "NumericEquals": 200,
          "Next": "UpdateStatusToSendCompleted"
        }
      ],
      "Default": "HandleFailure"
    },
    "UpdateStatusToSendCompleted": {
      "Type": "Task",
      "Resource": "arn:aws:states:::dynamodb:updateItem",
      "Parameters": {
        "TableName": "${var.dynamo_table_name}",
        "Key": {
          "video_id.$": "$.body.video_id",
          "user_name.$": "$.body.user_name"
        },
        "UpdateExpression": "SET #status = :status",
        "ExpressionAttributeNames": { "#status": "status" },
        "ExpressionAttributeValues": { ":status": { "S": "SEND_COMPLETED" } }
      },
      "ResultPath": "$.LogSendCompleted",
      "Next": "SuccessState"
    },
    "SuccessState": { "Type": "Succeed" },
    "HandleFailure": {
      "Type": "Parallel",
      "Branches": [
        {
          "StartAt": "UpdateStatusToFailed",
          "States": {
            "UpdateStatusToFailed": {
              "Type": "Task",
              "Resource": "arn:aws:states:::dynamodb:updateItem",
              "Parameters": {
                "TableName": "${var.dynamo_table_name}",
                "Key": {
                  "video_id.$": "$.body.video_id",
                  "user_name.$": "$.body.user_name"
                },
                "UpdateExpression": "SET #status = :status",
                "ExpressionAttributeNames": { "#status": "status" },
                "ExpressionAttributeValues": { ":status": { "S": "FAILED" } }
              },
              "End": true
            }
          }
        }
      ],
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
  depends_on = [ aws_iam_role.step_function_role ]
}
