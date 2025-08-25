import boto3
import os
import tempfile
from PIL import Image, ImageDraw, ImageFont
from datetime import datetime

s3 = boto3.client("s3")
dynamodb = boto3.resource("dynamodb")

BUCKET_NAME = os.environ["BUCKET_NAME"]
TABLE_NAME = os.environ["TABLE_NAME"]

def lambda_handler(event, context):
    table = dynamodb.Table(TABLE_NAME)

    for record in event["Records"]:
        s3_key = record["s3"]["object"]["key"]

        if not s3_key.startswith("original/"):
            continue

        image_id = s3_key.split("/")[-1].split(".")[0]
        processed_key = f"processed/{image_id}.jpg"

        with tempfile.NamedTemporaryFile() as tmp_file:
            s3.download_file(BUCKET_NAME, s3_key, tmp_file.name)
            
            img = Image.open(tmp_file.name)
            img = img.resize((400, 400))

            draw = ImageDraw.Draw(img)
            draw.text((10, 10), "Watermark", fill=(255, 0, 0))

            processed_path = f"/tmp/{image_id}_processed.jpg"
            img.save(processed_path)

            s3.upload_file(processed_path, BUCKET_NAME, processed_key)

        table.update_item(
            Key={"image_id": image_id},
            UpdateExpression="SET #s = :s, s3_key_processed = :p, processed_at = :t",
            ExpressionAttributeNames={"#s": "status"},
            ExpressionAttributeValues={
                ":s": "processed",
                ":p": processed_key,
                ":t": datetime.utcnow().isoformat()
            }
        )
