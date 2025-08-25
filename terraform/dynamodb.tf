resource "aws_dynamodb_table" "image_metadata" {
  name         = "${var.project_name}-image_metadata"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "image_id"

  attribute {
    name = "image_id"
    type = "S"
  }
}