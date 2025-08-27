resource "aws_iam_role" "upload_lambda_role" {
  name = "upload-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy" "upload_lambda_policy" {
  name = "upload-lambda-policy"
  role = aws_iam_role.upload_lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["s3:PutObject"]
        Resource = "${aws_s3_bucket.images.arn}/original/*"
      },
      {
        Effect   = "Allow"
        Action   = ["dynamodb:PutItem"]
        Resource = aws_dynamodb_table.image_metadata.arn
      },
      {
        Effect   = "Allow"
        Action   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = "arn:aws:logs:*:*:*"
      }
    ]
  })
}

resource "aws_iam_role" "processor_lambda_role" {
  name = "processor-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy" "processor_lambda_policy" {
  name = "processor-lambda-policy"
  role = aws_iam_role.processor_lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["s3:GetObject"]
        Resource = "${aws_s3_bucket.images.arn}/original/*"
      },
      {
        Effect   = "Allow"
        Action   = ["s3:PutObject"]
        Resource = "${aws_s3_bucket.images.arn}/processed/*"
      },
      {
        Effect   = "Allow"
        Action   = ["dynamodb:PutItem","dynamodb:UpdateItem"]
        Resource = aws_dynamodb_table.image_metadata.arn
      },
      {
        Effect   = "Allow"
        Action   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = "arn:aws:logs:*:*:*"
      }
    ]
  })
}

resource "aws_lambda_function" "upload" {
  function_name = "${var.project_name}-upload"
  role          = aws_iam_role.upload_lambda_role.arn
  handler       = "upload_lambda.lambda_handler"
  runtime       = "python3.12"

  filename         = archive_file.upload_lambda_zip.output_path
  source_code_hash = archive_file.upload_lambda_zip.output_base64sha256

  environment {
    variables = {
      BUCKET_NAME = aws_s3_bucket.images.bucket
      TABLE_NAME  = aws_dynamodb_table.image_metadata.name
    }
  }
}

resource "aws_lambda_function" "processor" {
  function_name = "${var.project_name}-processor"
  role          = aws_iam_role.processor_lambda_role.arn
  handler       = "process_lambda.lambda_handler"
  runtime       = "python3.12"

  filename         = archive_file.process_lambda_zip.output_path
  source_code_hash = archive_file.process_lambda_zip.output_base64sha256

  environment {
    variables = {
      BUCKET_NAME = aws_s3_bucket.images.bucket
      TABLE_NAME  = aws_dynamodb_table.image_metadata.name
    }
  }
}

resource "archive_file" "upload_lambda_zip" {
  type        = "zip"
  source_file = "${path.module}/../lambda/upload_lambda.py"
  output_path = "${path.module}/../lambda/upload_lambda.zip"
}

resource "archive_file" "process_lambda_zip" {
  type        = "zip"
  source_dir  = "${path.module}/../lambda/process/"
  output_path = "${path.module}/../lambda/process_lambda.zip"
}

resource "aws_s3_bucket_notification" "originals_notify" {
  bucket = aws_s3_bucket.images.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.processor.arn
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = "original/"
  }

  depends_on = [aws_lambda_permission.allow_s3_invoke]
}

resource "aws_lambda_permission" "allow_s3_invoke" {
  statement_id  = "AllowS3Invoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.processor.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.images.arn
}