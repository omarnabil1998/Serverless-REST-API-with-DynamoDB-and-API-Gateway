output "api_endpoint" {
  value = aws_apigatewayv2_stage.default.invoke_url
}

output "bucket_name" {
  value = aws_s3_bucket.images.bucket
}

output "dynamodb_table" {
  value = aws_dynamodb_table.metadata.name
}
