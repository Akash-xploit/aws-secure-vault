import os
from datetime import datetime, timezone
from urllib.parse import unquote, unquote_plus

import boto3

TABLE = os.environ["TABLE_NAME"]

s3 = boto3.client("s3")
dynamodb = boto3.client("dynamodb")


def lambda_handler(event, context):
    for record in event["Records"]:
        bucket = record["s3"]["bucket"]["name"]
        # Keys in S3 events are URL-encoded.
        key = unquote_plus(record["s3"]["object"]["key"])
        size = record["s3"]["object"]["size"]

        parts = key.split("/")
        if len(parts) != 2:
            print(f"skipping unexpected key: {key}")
            continue
        owner_id, file_id = parts

        # x-amz-meta-filename comes back as "filename".
        head = s3.head_object(Bucket=bucket, Key=key)
        file_name = unquote(head["Metadata"].get("filename", "unknown"))

        # A reused ticket must not overwrite the existing row.
        try:
            dynamodb.put_item(
                TableName=TABLE,
                Item={
                    "ownerId": {"S": owner_id},
                    "fileId": {"S": file_id},
                    "fileName": {"S": file_name},
                    "sizeBytes": {"N": str(size)},
                    "uploadedAt": {"S": datetime.now(timezone.utc).isoformat()},
                },
                ConditionExpression="attribute_not_exists(fileId)",
            )
        except dynamodb.exceptions.ConditionalCheckFailedException:
            print(f"duplicate upload ignored: owner={owner_id} file={file_id}")
            continue

        print(f"file recorded: owner={owner_id} file={file_id}")
