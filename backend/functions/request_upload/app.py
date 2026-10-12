import json
import os
import uuid
from urllib.parse import quote

import boto3
from botocore.config import Config

BUCKET = os.environ["BUCKET_NAME"]
MAX_BYTES = 100 * 1024 * 1024
EXPIRES_SECONDS = 5 * 60
MAX_NAME_LENGTH = 255

# boto3 signs presigned POSTs with SigV2 unless told otherwise.
s3 = boto3.client("s3", config=Config(signature_version="s3v4"))


def respond(status, payload):
    return {
        "statusCode": status,
        "headers": {"Content-Type": "application/json"},
        "body": json.dumps(payload),
    }


def get_user_id(event):
    # Identity comes from the Cognito authorizer, not the request body.
    return event.get("requestContext", {}).get("authorizer", {}).get("claims", {}).get("sub")


def get_file_name(event):
    try:
        data = json.loads(event.get("body"))
    except (TypeError, ValueError):
        return None

    if not isinstance(data, dict):
        return None

    name = data.get("fileName")
    if not isinstance(name, str):
        return None

    name = name.strip()
    if not name or len(name) > MAX_NAME_LENGTH:
        return None

    return name


def lambda_handler(event, context):
    user_id = get_user_id(event)
    if user_id is None:
        return respond(401, {"error": "unauthorized"})

    file_name = get_file_name(event)
    if file_name is None:
        return respond(400, {"error": "fileName is required (1-255 characters)"})

    file_id = str(uuid.uuid4())
    key = f"{user_id}/{file_id}"
    encoded_name = quote(file_name, safe="")

    try:
        ticket = s3.generate_presigned_post(
            Bucket=BUCKET,
            Key=key,
            Fields={"x-amz-meta-filename": encoded_name},
            Conditions=[
                ["content-length-range", 1, MAX_BYTES],
                {"x-amz-meta-filename": encoded_name},
            ],
            ExpiresIn=EXPIRES_SECONDS,
        )
    except Exception:
        print(f"upload ticket failed: user={user_id} file={file_id}")
        return respond(500, {"error": "could not create upload"})

    print(f"upload ticket issued: user={user_id} file={file_id}")
    return respond(200, {
        "fileId": file_id,
        "url": ticket["url"],
        "fields": ticket["fields"],
        "expiresIn": EXPIRES_SECONDS,
    })
