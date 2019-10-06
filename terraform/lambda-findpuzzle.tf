resource "random_string" "findpuzzle" {
  length  = 8
  special = false
}

data "archive_file" "findpuzzle" {
  type        = "zip"
  output_path = "${path.module}/.files/findpuzzle-${random_string.findpuzzle.result}.zip"
  source_dir  = "${path.module}/.files/findpuzzle"
}

resource "aws_s3_bucket_object" "findpuzzle" {
  bucket = "${aws_s3_bucket.code.id}"
  key    = "findpuzzle-${data.archive_file.findpuzzle.output_base64sha256}.zip"
  source = "${data.archive_file.findpuzzle.output_path}"
}

resource "aws_iam_role" "findpuzzle" {
  name               = "findpuzzle-assume"
  assume_role_policy = "${data.aws_iam_policy_document.findpuzzle_assume.json}"
}

data "aws_iam_policy_document" "findpuzzle_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_policy" "findpuzzle" {
  name   = "findpuzzle"
  policy = "${data.aws_iam_policy_document.findpuzzle.json}"
}

resource "aws_iam_policy_attachment" "findpuzzle" {
  name       = "findpuzzle"
  roles      = ["${aws_iam_role.findpuzzle.name}"]
  policy_arn = "${aws_iam_policy.findpuzzle.arn}"
}

data "aws_iam_policy_document" "findpuzzle" {
  statement {
    sid = "Rekognition"

    actions = [
      "rekognition:DetectText",
    ]

    resources = [
      "*",
    ]
  }

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

resource "aws_lambda_function" "findpuzzle" {
  function_name = "findpuzzle"
  description   = "Find Sudoku puzzle from image"
  role          = "${aws_iam_role.findpuzzle.arn}"
  handler       = "findpuzzle"
  runtime       = "go1.x"
  timeout       = 300
  s3_bucket     = "${aws_s3_bucket.code.id}"
  s3_key        = "${aws_s3_bucket_object.findpuzzle.id}"
}

resource "aws_api_gateway_resource" "findpuzzle" {
  path_part   = "find"
  parent_id   = "${aws_api_gateway_rest_api.api.root_resource_id}"
  rest_api_id = "${aws_api_gateway_rest_api.api.id}"
}

resource "aws_api_gateway_method" "findpuzzle" {
  rest_api_id   = "${aws_api_gateway_rest_api.api.id}"
  resource_id   = "${aws_api_gateway_resource.findpuzzle.id}"
  http_method   = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_method_response" "findpuzzle" {
  rest_api_id = "${aws_api_gateway_rest_api.api.id}"
  resource_id = "${aws_api_gateway_resource.findpuzzle.id}"
  http_method = "${aws_api_gateway_method.findpuzzle.http_method}"
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin" = true
  }
}

resource "aws_api_gateway_integration" "findpuzzle" {
  rest_api_id             = "${aws_api_gateway_rest_api.api.id}"
  resource_id             = "${aws_api_gateway_resource.findpuzzle.id}"
  http_method             = "${aws_api_gateway_method.findpuzzle.http_method}"
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = "arn:aws:apigateway:${var.aws_region}:lambda:path/2015-03-31/functions/${aws_lambda_function.findpuzzle.arn}/invocations"
}

resource "aws_api_gateway_integration_response" "findpuzzle" {
  rest_api_id = "${aws_api_gateway_rest_api.api.id}"
  resource_id = "${aws_api_gateway_resource.findpuzzle.id}"
  http_method = "${aws_api_gateway_method.findpuzzle.http_method}"
  status_code = "${aws_api_gateway_method_response.findpuzzle.status_code}"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin" = "'*'"
  }
}

resource "aws_api_gateway_method" "findpuzzle_opt" {
  rest_api_id   = "${aws_api_gateway_rest_api.api.id}"
  resource_id   = "${aws_api_gateway_resource.findpuzzle.id}"
  http_method   = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_method_response" "findpuzzle_opt" {
  rest_api_id = "${aws_api_gateway_rest_api.api.id}"
  resource_id = "${aws_api_gateway_resource.findpuzzle.id}"
  http_method = "${aws_api_gateway_method.findpuzzle_opt.http_method}"
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

resource "aws_api_gateway_integration" "findpuzzle_opt" {
  rest_api_id = "${aws_api_gateway_rest_api.api.id}"
  resource_id = "${aws_api_gateway_resource.findpuzzle.id}"
  http_method = "${aws_api_gateway_method.findpuzzle_opt.http_method}"
  type        = "MOCK"

  request_templates {
    "application/json" = <<EOF
{ "statusCode": 200 }
EOF
  }
}

resource "aws_api_gateway_integration_response" "findpuzzle_opt" {
  rest_api_id = "${aws_api_gateway_rest_api.api.id}"
  resource_id = "${aws_api_gateway_resource.findpuzzle.id}"
  http_method = "${aws_api_gateway_method.findpuzzle_opt.http_method}"
  status_code = "${aws_api_gateway_method_response.findpuzzle_opt.status_code}"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'*'"
    "method.response.header.Access-Control-Allow-Methods" = "'OPTIONS,POST,GET'"
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
  }
}

resource "aws_lambda_permission" "findpuzzle" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = "${aws_lambda_function.findpuzzle.function_name}"
  principal     = "apigateway.amazonaws.com"

  # More: http://docs.aws.amazon.com/apigateway/latest/developerguide/api-gateway-control-access-using-iam-policies-to-invoke-api.html
  source_arn = "arn:aws:execute-api:${var.aws_region}:${data.aws_caller_identity.current.account_id}:${aws_api_gateway_rest_api.api.id}/*/${aws_api_gateway_method.findpuzzle.http_method}${aws_api_gateway_resource.findpuzzle.path}"
}
