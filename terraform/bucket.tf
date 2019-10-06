resource "aws_s3_bucket" "code" {
  bucket = "${var.bucket_prefix}-code-${var.aws_region}"
  region = "${var.aws_region}"
}

resource "aws_s3_bucket" "images" {
  bucket = "${var.bucket_prefix}-images-${var.aws_region}"
  region = "${var.aws_region}"

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["PUT"]
    allowed_origins = ["*"]
    expose_headers  = ["ETag"]
    max_age_seconds = 300
  }
}
