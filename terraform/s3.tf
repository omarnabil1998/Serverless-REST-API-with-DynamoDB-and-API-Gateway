resource "aws_s3_bucket" "images" {
  bucket = "${var.project_name}-images"
}