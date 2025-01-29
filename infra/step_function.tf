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
      "ResultPath": "$.LogInputResult",
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
        "UpdateExpression": "SET #status = :status, frame_rate = if_not_exists(frame_rate, :frame_rate), video_url = if_not_exists(video_url, :video_url)",
        "ExpressionAttributeNames": { "#status": "status" },
        "ExpressionAttributeValues": {
          ":status": { "S": "UPLOAD_STARTED" },
          ":frame_rate": { "N.$": "$.body.frame_rate" },
          ":video_url": { "S.$": "$.body.video_url" }
        }
      },
      "Next": "Upload"
    },

    "Upload": {
      "Type": "Task",
      "Resource": "arn:aws:lambda:${var.aws_region}:${data.aws_caller_identity.current.account_id}:function:${var.prefix_name}-${var.lambda_upload_name}-lambda",
      "Parameters": {
        "body": {
          "user_name": "$.body.user_name",
          "email": "$.body.email",
          "video_id": "$.body.video_id",
          "video_url": "$.body.video_url"
        }
      },
      "ResultPath": "$.UploadResult",
      "Retry": [
        { "ErrorEquals": ["States.ALL"], "IntervalSeconds": 2, "MaxAttempts": 3, "BackoffRate": 2 }
      ],
      "Catch": [ { "ErrorEquals": ["States.ALL"], "Next": "HandleFailure" } ],
      "Next": "UpdateStatusToProcessingStarted"
    },

    "UpdateStatusToProcessingStarted": {
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
        "ExpressionAttributeValues": { ":status": { "S": "PROCESSING_STARTED" } }
      },
      "Next": "Processing"
    },

    "Processing": {
      "Type": "Task",
      "Resource": "arn:aws:lambda:${var.aws_region}:${data.aws_caller_identity.current.account_id}:function:${var.prefix_name}-${var.lambda_processing_name}-lambda",
      "Parameters": {
        "body": {
          "user_name": "$.body.user_name",
          "email": "$.body.email",
          "video_id": "$.body.video_id",
          "frame_rate": "$.body.frame_rate"
        }
      },
      "ResultPath": "$.ProcessingResult",
      "Retry": [
        { "ErrorEquals": ["States.ALL"], "IntervalSeconds": 2, "MaxAttempts": 3, "BackoffRate": 2 }
      ],
      "Catch": [ { "ErrorEquals": ["States.ALL"], "Next": "HandleFailure" } ],
      "Next": "UpdateStatusToProcessingCompleted"
    },

    "UpdateStatusToProcessingCompleted": {
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
        "ExpressionAttributeValues": { ":status": { "S": "PROCESSING_COMPLETED" } }
      },
      "Next": "UpdateStatusToSendStarted"
    },

    "UpdateStatusToSendStarted": {
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
        "ExpressionAttributeValues": { ":status": { "S": "SEND_STARTED" } }
      },
      "Next": "Send"
    },

    "Send": {
      "Type": "Task",
      "Resource": "arn:aws:lambda:${var.aws_region}:${data.aws_caller_identity.current.account_id}:function:${var.prefix_name}-${var.lambda_send_name}-lambda",
      "Parameters": {
        "body": {
          "email": "$.body.email",
          "frame_url": "$.ProcessingResult.body.frame_url"
        }
      },
      "ResultPath": "$.SendResult",
      "Retry": [
        { "ErrorEquals": ["States.ALL"], "IntervalSeconds": 2, "MaxAttempts": 3, "BackoffRate": 2 }
      ],
      "Catch": [ { "ErrorEquals": ["States.ALL"], "Next": "HandleFailure" } ],
      "Next": "UpdateStatusToSendCompleted"
    },

    "UpdateStatusToSendCompleted": {
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
        "ExpressionAttributeValues": { ":status": { "S": "SEND_COMPLETED" } }
      },
      "End": true
    },

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
                  "video_id": { "S.$": "$.body.video_id" },
                  "user_name": { "S.$": "$.body.user_name" }
                },
                "UpdateExpression": "SET #status = :status",
                "ExpressionAttributeNames": { "#status": "status" },
                "ExpressionAttributeValues": { ":status": { "S": "FAILED" } }
              },
              "End": true
            }
          }
        },
        {
          "StartAt": "SendFailureNotification",
          "States": {
            "SendFailureNotification": {
              "Type": "Task",
              "Resource": "arn:aws:lambda:${var.aws_region}:${data.aws_caller_identity.current.account_id}:function:${var.prefix_name}-${var.lambda_send_name}-lambda",
              "Parameters": {
                "body": {
                  "email": "$.body.email",
                  "frame_url": "",
                  "error": true
                }
              },
              "End": true
            }
          }
        }
      ],
      "End": true
    }
  }
}
EOF

  depends_on = [ aws_iam_role.step_function_role ]
}
