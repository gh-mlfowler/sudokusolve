resource "random_string" "solvepuzzle" {
  length  = 8
  special = false
}

data "archive_file" "solvepuzzle" {
  type        = "zip"
  output_path = "${path.module}/.files/solvepuzzle-${random_string.solvepuzzle.result}.zip"
  source_dir  = "${path.module}/.files/solvepuzzle"
}

resource "aws_s3_bucket_object" "solvepuzzle" {
  bucket = "${aws_s3_bucket.code.id}"
  key    = "solvepuzzle-${data.archive_file.solvepuzzle.output_base64sha256}.zip"
  source = "${data.archive_file.solvepuzzle.output_path}"
}

resource "aws_iam_role" "solvepuzzle" {
  name               = "solvepuzzle-assume"
  assume_role_policy = "${data.aws_iam_policy_document.solvepuzzle_assume.json}"
}

data "aws_iam_policy_document" "solvepuzzle_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_policy" "solvepuzzle" {
  name   = "solvepuzzle"
  policy = "${data.aws_iam_policy_document.solvepuzzle.json}"
}

resource "aws_iam_policy_attachment" "solvepuzzle" {
  name       = "solvepuzzle"
  roles      = ["${aws_iam_role.solvepuzzle.name}"]
  policy_arn = "${aws_iam_policy.solvepuzzle.arn}"
}

data "aws_iam_policy_document" "solvepuzzle" {
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

resource "aws_lambda_function" "solvepuzzle" {
  function_name = "solvepuzzle"
  description   = "Solve Sudoku puzzle from input"
  role          = "${aws_iam_role.solvepuzzle.arn}"
  handler       = "solvepuzzle"
  runtime       = "go1.x"
  timeout       = 300
  s3_bucket     = "${aws_s3_bucket.code.id}"
  s3_key        = "${aws_s3_bucket_object.solvepuzzle.id}"
}

resource "aws_api_gateway_resource" "solvepuzzle" {
  path_part   = "solve"
  parent_id   = "${aws_api_gateway_rest_api.api.root_resource_id}"
  rest_api_id = "${aws_api_gateway_rest_api.api.id}"
}

resource "aws_api_gateway_method" "solvepuzzle" {
  rest_api_id   = "${aws_api_gateway_rest_api.api.id}"
  resource_id   = "${aws_api_gateway_resource.solvepuzzle.id}"
  http_method   = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_method_response" "solvepuzzle" {
  rest_api_id = "${aws_api_gateway_rest_api.api.id}"
  resource_id = "${aws_api_gateway_resource.solvepuzzle.id}"
  http_method = "${aws_api_gateway_method.solvepuzzle.http_method}"
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin" = true
  }
}

resource "aws_api_gateway_integration" "solvepuzzle" {
  rest_api_id             = "${aws_api_gateway_rest_api.api.id}"
  resource_id             = "${aws_api_gateway_resource.solvepuzzle.id}"
  http_method             = "${aws_api_gateway_method.solvepuzzle.http_method}"
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = "arn:aws:apigateway:${var.aws_region}:lambda:path/2015-03-31/functions/${aws_lambda_function.solvepuzzle.arn}/invocations"
}

resource "aws_api_gateway_integration_response" "solvepuzzle" {
  rest_api_id = "${aws_api_gateway_rest_api.api.id}"
  resource_id = "${aws_api_gateway_resource.solvepuzzle.id}"
  http_method = "${aws_api_gateway_method.solvepuzzle.http_method}"
  status_code = "${aws_api_gateway_method_response.solvepuzzle.status_code}"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin" = "'*'"
  }
}

resource "aws_api_gateway_method" "solvepuzzle_opt" {
  rest_api_id   = "${aws_api_gateway_rest_api.api.id}"
  resource_id   = "${aws_api_gateway_resource.solvepuzzle.id}"
  http_method   = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_method_response" "solvepuzzle_opt" {
  rest_api_id = "${aws_api_gateway_rest_api.api.id}"
  resource_id = "${aws_api_gateway_resource.solvepuzzle.id}"
  http_method = "${aws_api_gateway_method.solvepuzzle_opt.http_method}"
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

resource "aws_api_gateway_integration" "solvepuzzle_opt" {
  rest_api_id = "${aws_api_gateway_rest_api.api.id}"
  resource_id = "${aws_api_gateway_resource.solvepuzzle.id}"
  http_method = "${aws_api_gateway_method.solvepuzzle_opt.http_method}"
  type        = "MOCK"

  request_templates {
    "application/json" = <<EOF
{ "statusCode": 200 }
EOF
  }
}

resource "aws_api_gateway_integration_response" "solvepuzzle_opt" {
  rest_api_id = "${aws_api_gateway_rest_api.api.id}"
  resource_id = "${aws_api_gateway_resource.solvepuzzle.id}"
  http_method = "${aws_api_gateway_method.solvepuzzle_opt.http_method}"
  status_code = "${aws_api_gateway_method_response.solvepuzzle_opt.status_code}"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'*'"
    "method.response.header.Access-Control-Allow-Methods" = "'OPTIONS,POST,GET'"
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
  }
}

resource "aws_lambda_permission" "solvepuzzle" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = "${aws_lambda_function.solvepuzzle.function_name}"
  principal     = "apigateway.amazonaws.com"

  # More: http://docs.aws.amazon.com/apigateway/latest/developerguide/api-gateway-control-access-using-iam-policies-to-invoke-api.html
  source_arn = "arn:aws:execute-api:${var.aws_region}:${data.aws_caller_identity.current.account_id}:${aws_api_gateway_rest_api.api.id}/*/${aws_api_gateway_method.solvepuzzle.http_method}${aws_api_gateway_resource.solvepuzzle.path}"
}
