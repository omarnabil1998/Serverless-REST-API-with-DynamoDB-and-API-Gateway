resource "aws_iam_role" "lambda_role" {
  name = "${var.project_name}-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "lambda_s3_full" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}

resource "aws_iam_role_policy_attachment" "lambda_dynamodb_full" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonDynamoDBFullAccess"
}

resource "aws_lambda_function" "upload" {
  function_name = "${var.project_name}-upload"
  role          = aws_iam_role.lambda_role.arn
  handler       = "upload.handler"
  runtime       = "python3.10"

  filename         = "${path.module}/lambdas/upload.zip"
  source_code_hash = filebase64sha256("${path.module}/lambdas/upload.zip")

  environment {
    variables = {
      BUCKET_NAME = aws_s3_bucket.images.bucket
      TABLE_NAME      = aws_dynamodb_table.image_metadata.name
    }
  }
}

resource "aws_lambda_function" "processor" {
  function_name = "${var.project_name}-processor"
  role          = aws_iam_role.lambda_role.arn
  handler       = "processor.handler"
  runtime       = "python3.10"

  filename         = "${path.module}/lambdas/processor.zip"
  source_code_hash = filebase64sha256("${path.module}/lambdas/processor.zip")

  environment {
    variables = {
      BUCKET_NAME = aws_s3_bucket.images.bucket
      TABLE_NAME      = aws_dynamodb_table.image_metadata.name
    }
  }
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