# Solving Sudoku with AWS ML

This is a simple AWS tech demo that can solve Sudoku puzzles from webcam stills. This consists of a Terraform stack that creates an API Gateway which hosts a simple webpage for capturing and processing an image from a webcam. A series of Lambda functions are invoked, one for S3 signing to allow the upload of the image, one to invoke Rekognition to extract the text and a final one to solve the extracted puzzle.

## Usage

You will need [Terraform](https://www.terraform.io/) and [Go](https://golang.org/) installed. This was build and tested with:
```bash
$ terraform version
Terraform v0.11.13
+ provider.archive v1.2.2
+ provider.aws v2.29.0
+ provider.random v2.2.0
+ provider.template v2.1.2
$ go version
go version go1.12.8 linux/amd64
```

In order for Terraform to make changes to your AWS account, you will need to export [your AWS access keys](https://docs.aws.amazon.com/sdk-for-go/v1/developer-guide/setting-up.html).

```bash
export AWS_ACCESS_KEY_ID=*****
export AWS_SECRET_ACCESS_KEY=*****
export AWS_REGION=eu-west-1
```

To run Terraform, change your current working directory to the `terraform` folder and run `make`. You will be prompted to provide a unique bucket prefix. You will be shown a plan of the proposed AWS resources to be created.

```bash
$ cd terraform
$ make all
...
var.bucket_prefix
  Enter a value: sudoku
...
```

Should you wish to make changes to the code or infrastructure, you can create a file in the `terraform` folder named `terraform.tfvars` with the value you've used for `var.bucket_prefix` so that you don't need to enter it every time you plan.

```bash
echo 'bucket_prefix = "sudoku"' > terraform.tfvars
```

To create the resources shown in the plan you need to run `make apply`. Once completed, a URL will be displayed which is the HTML page in S3 accessible through API Gateway. The browser will ask permission to use an attached webcam and once granted, a still can be taken by pressing the camera icon as per the instructions on the web page.

```bash
$ make apply
...
Apply complete! Resources: x added, x changed, x destroyed.

Outputs:

webpage = https://xxxxxxxxxx.execute-api.region.amazonaws.com/sudoku/index.html
```
