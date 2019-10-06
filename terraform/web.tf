resource "aws_s3_bucket" "site" {
  bucket = "${var.bucket_prefix}-site-${var.aws_region}"
  region = "${var.aws_region}"
}

data "template_file" "index" {
  template = "${file("../html/index.html")}"

  vars = {
    apigateway_url = "${aws_api_gateway_stage.stage.invoke_url}"
  }
}

resource "aws_s3_bucket_object" "index" {
  key           = "index.html"
  content       = "${data.template_file.index.rendered}"
  etag          = "${md5(file("../html/index.html"))}"
  bucket        = "${aws_s3_bucket.site.id}"
  content_type  = "text/html"
  force_destroy = true
}

resource "aws_s3_bucket_object" "logo" {
  key           = "claranet.png"
  source        = "../html/claranet.png"
  etag          = "${md5(file("../html/claranet.png"))}"
  bucket        = "${aws_s3_bucket.site.id}"
  content_type  = "image/png"
  force_destroy = true
}

resource "aws_iam_role" "web" {
  name               = "web-assume"
  assume_role_policy = "${data.aws_iam_policy_document.web_assume.json}"
}

data "aws_iam_policy_document" "web_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["apigateway.amazonaws.com"]
    }
  }
}

resource "aws_iam_policy" "web" {
  name   = "web"
  policy = "${data.aws_iam_policy_document.web.json}"
}

resource "aws_iam_policy_attachment" "web" {
  name       = "web"
  roles      = ["${aws_iam_role.web.name}"]
  policy_arn = "${aws_iam_policy.web.arn}"
}

data "aws_iam_policy_document" "web" {
  statement {
    sid = "S3"

    actions = [
      "s3:Get*",
      "s3:List*",
    ]

    resources = [
      "arn:aws:s3:::${aws_s3_bucket.site.id}/*",
    ]
  }
}

resource "aws_api_gateway_resource" "web" {
  path_part   = "{item+}"
  parent_id   = "${aws_api_gateway_rest_api.api.root_resource_id}"
  rest_api_id = "${aws_api_gateway_rest_api.api.id}"
}

resource "aws_api_gateway_method" "web" {
  rest_api_id   = "${aws_api_gateway_rest_api.api.id}"
  resource_id   = "${aws_api_gateway_resource.web.id}"
  http_method   = "GET"
  authorization = "NONE"

  request_parameters = {
    "method.request.path.item" = true
  }
}

resource "aws_api_gateway_integration" "web" {
  rest_api_id             = "${aws_api_gateway_rest_api.api.id}"
  resource_id             = "${aws_api_gateway_resource.web.id}"
  http_method             = "${aws_api_gateway_method.web.http_method}"
  integration_http_method = "GET"
  type                    = "AWS"
  uri                     = "arn:aws:apigateway:${var.aws_region}:s3:path/${aws_s3_bucket.site.id}/{item}"
  credentials             = "${aws_iam_role.web.arn}"
  passthrough_behavior    = "WHEN_NO_MATCH"

  request_parameters = {
    "integration.request.path.item" = "method.request.path.item"
  }
}

resource "aws_api_gateway_method_response" "200" {
  rest_api_id = "${aws_api_gateway_rest_api.api.id}"
  resource_id = "${aws_api_gateway_resource.web.id}"
  http_method = "${aws_api_gateway_method.web.http_method}"
  status_code = "200"

  response_parameters = {
    "method.response.header.Content-Length" = true
    "method.response.header.Content-Type"   = true
  }

  response_models {
    "application/json" = "Empty"
  }
}

resource "aws_api_gateway_method_response" "400" {
  rest_api_id = "${aws_api_gateway_rest_api.api.id}"
  resource_id = "${aws_api_gateway_resource.web.id}"
  http_method = "${aws_api_gateway_method.web.http_method}"
  status_code = "400"
}

resource "aws_api_gateway_method_response" "500" {
  rest_api_id = "${aws_api_gateway_rest_api.api.id}"
  resource_id = "${aws_api_gateway_resource.web.id}"
  http_method = "${aws_api_gateway_method.web.http_method}"
  status_code = "500"
}

resource "aws_api_gateway_integration_response" "200IntegrationResponse" {
  rest_api_id = "${aws_api_gateway_rest_api.api.id}"
  resource_id = "${aws_api_gateway_resource.web.id}"
  http_method = "${aws_api_gateway_method.web.http_method}"
  status_code = "${aws_api_gateway_method_response.200.status_code}"

  response_parameters = {
    "method.response.header.Content-Length" = "integration.response.header.Content-Length"
    "method.response.header.Content-Type"   = "integration.response.header.Content-Type"
  }
}

resource "aws_api_gateway_integration_response" "400IntegrationResponse" {
  rest_api_id       = "${aws_api_gateway_rest_api.api.id}"
  resource_id       = "${aws_api_gateway_resource.web.id}"
  http_method       = "${aws_api_gateway_method.web.http_method}"
  status_code       = "${aws_api_gateway_method_response.400.status_code}"
  selection_pattern = "4\\d{2}"
}

resource "aws_api_gateway_integration_response" "500IntegrationResponse" {
  rest_api_id       = "${aws_api_gateway_rest_api.api.id}"
  resource_id       = "${aws_api_gateway_resource.web.id}"
  http_method       = "${aws_api_gateway_method.web.http_method}"
  status_code       = "${aws_api_gateway_method_response.500.status_code}"
  selection_pattern = "5\\d{2}"
}
