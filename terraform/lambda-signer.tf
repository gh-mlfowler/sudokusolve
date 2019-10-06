resource "random_string" "sign" {
  length  = 8
  special = false
}

data "archive_file" "sign" {
  type        = "zip"
  output_path = "${path.module}/.files/signer-${random_string.sign.result}.zip"
  source_dir  = "${path.module}/.files/signer"
}

resource "aws_s3_bucket_object" "sign" {
  bucket = "${aws_s3_bucket.code.id}"
  key    = "sign-${data.archive_file.sign.output_base64sha256}.zip"
  source = "${data.archive_file.sign.output_path}"
}

resource "aws_iam_role" "sign" {
  name               = "sign-assume"
  assume_role_policy = "${data.aws_iam_policy_document.sign_assume.json}"
}

data "aws_iam_policy_document" "sign_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_policy" "sign" {
  name   = "sign"
  policy = "${data.aws_iam_policy_document.sign.json}"
}

resource "aws_iam_policy_attachment" "sign" {
  name       = "sign"
  roles      = ["${aws_iam_role.sign.name}"]
  policy_arn = "${aws_iam_policy.sign.arn}"
}

data "aws_iam_policy_document" "sign" {
  statement {
    sid = "S3Buckets"

    actions = [
      "s3:GetBucketLocation",
      "s3:ListBucket",
      "s3:ListAllMyBuckets",
      "s3:GetBucketAcl",
    ]

    resources = [
      "*",
    ]
  }

  statement {
    sid = "S3ImagesBucket"

    actions = [
      "s3:*Object",
    ]

    resources = [
      "${aws_s3_bucket.images.arn}/*",
    ]
  }

  statement {
    effect = "Allow"
    sid    = "CloudWatchLogs"

    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]

    resources = [
      "*",
    ]
  }
}

resource "aws_lambda_function" "sign" {
  function_name = "signer"
  description   = "S3 Signer for image uploads"
  role          = "${aws_iam_role.sign.arn}"
  handler       = "signer"
  runtime       = "go1.x"
  timeout       = 300
  s3_bucket     = "${aws_s3_bucket.code.id}"
  s3_key        = "${aws_s3_bucket_object.sign.id}"

  environment {
    variables = {
      BUCKET = "${aws_s3_bucket.images.id}"
    }
  }
}

resource "aws_api_gateway_resource" "sign" {
  path_part   = "signer"
  parent_id   = "${aws_api_gateway_rest_api.api.root_resource_id}"
  rest_api_id = "${aws_api_gateway_rest_api.api.id}"
}

resource "aws_api_gateway_method" "sign" {
  rest_api_id   = "${aws_api_gateway_rest_api.api.id}"
  resource_id   = "${aws_api_gateway_resource.sign.id}"
  http_method   = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_method_response" "sign" {
  rest_api_id = "${aws_api_gateway_rest_api.api.id}"
  resource_id = "${aws_api_gateway_resource.sign.id}"
  http_method = "${aws_api_gateway_method.sign.http_method}"
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin" = true
  }
}

resource "aws_api_gateway_integration" "sign" {
  rest_api_id             = "${aws_api_gateway_rest_api.api.id}"
  resource_id             = "${aws_api_gateway_resource.sign.id}"
  http_method             = "${aws_api_gateway_method.sign.http_method}"
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = "arn:aws:apigateway:${var.aws_region}:lambda:path/2015-03-31/functions/${aws_lambda_function.sign.arn}/invocations"
}

resource "aws_api_gateway_integration_response" "sign" {
  rest_api_id = "${aws_api_gateway_rest_api.api.id}"
  resource_id = "${aws_api_gateway_resource.sign.id}"
  http_method = "${aws_api_gateway_method.sign.http_method}"
  status_code = "${aws_api_gateway_method_response.sign.status_code}"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin" = "'*'"
  }
}

resource "aws_api_gateway_method" "sign_opt" {
  rest_api_id   = "${aws_api_gateway_rest_api.api.id}"
  resource_id   = "${aws_api_gateway_resource.sign.id}"
  http_method   = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_method_response" "sign_opt" {
  rest_api_id = "${aws_api_gateway_rest_api.api.id}"
  resource_id = "${aws_api_gateway_resource.sign.id}"
  http_method = "${aws_api_gateway_method.sign_opt.http_method}"
  status_code = "200"

  response_models {
    "application/json" = "Empty"
  }

  response_parameters {
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
    "method.response.header.Access-Control-Allow-Origin"  = true
  }
}

resource "aws_api_gateway_integration" "sign_opt" {
  rest_api_id = "${aws_api_gateway_rest_api.api.id}"
  resource_id = "${aws_api_gateway_resource.sign.id}"
  http_method = "${aws_api_gateway_method.sign_opt.http_method}"
  type        = "MOCK"

  request_templates {
    "application/json" = <<EOF
{ "statusCode": 200 }
EOF
  }
}

resource "aws_api_gateway_integration_response" "sign_opt" {
  rest_api_id = "${aws_api_gateway_rest_api.api.id}"
  resource_id = "${aws_api_gateway_resource.sign.id}"
  http_method = "${aws_api_gateway_method.sign_opt.http_method}"
  status_code = "${aws_api_gateway_method_response.sign_opt.status_code}"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'*'"
    "method.response.header.Access-Control-Allow-Methods" = "'OPTIONS,POST,GET'"
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
  }
}

resource "aws_lambda_permission" "sign" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = "${aws_lambda_function.sign.function_name}"
  principal     = "apigateway.amazonaws.com"

  # More: http://docs.aws.amazon.com/apigateway/latest/developerguide/api-gateway-control-access-using-iam-policies-to-invoke-api.html
  source_arn = "arn:aws:execute-api:${var.aws_region}:${data.aws_caller_identity.current.account_id}:${aws_api_gateway_rest_api.api.id}/*/${aws_api_gateway_method.sign.http_method}${aws_api_gateway_resource.sign.path}"
}
