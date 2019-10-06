resource "aws_api_gateway_rest_api" "api" {
  name = "sudoku"
}

resource "aws_api_gateway_deployment" "deployment" {
  rest_api_id       = "${aws_api_gateway_rest_api.api.id}"
  stage_description = "${md5(file("lambda-findpuzzle.tf"))}-${md5(file("lambda-solvepuzzle.tf"))}-${md5(file("lambda-signer.tf"))}"
}

resource "aws_api_gateway_stage" "stage" {
  stage_name    = "sudoku"
  rest_api_id   = "${aws_api_gateway_rest_api.api.id}"
  deployment_id = "${aws_api_gateway_deployment.deployment.id}"
}
