import json
import base64
import boto3
import uuid
import os
from datetime import datetime

s3 = boto3.client("s3")
dynamodb = boto3.resource("dynamodb")

BUCKET_NAME = os.environ["BUCKET_NAME"]
TABLE_NAME = os.environ["TABLE_NAME"]

def lambda_handler(event, context):
    body = base64.b64decode(event["body"])
    
    image_id = str(uuid.uuid4())
    key = f"original/{image_id}.jpg"

    s3.put_object(Bucket=BUCKET_NAME, Key=key, Body=body)

    table = dynamodb.Table(TABLE_NAME)
    table.put_item(Item={
        "image_id": image_id,
        "status": "uploaded",
        "s3_key_original": key,
        "created_at": datetime.utcnow().isoformat()
    })

    return {
        "statusCode": 200,
        "body": json.dumps({"message": "Upload successful", "image_id": image_id}),
    }
