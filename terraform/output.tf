output "webpage" {
  value = "${aws_api_gateway_stage.stage.invoke_url}/index.html"
}
