MAKEFLAGS += --warn-undefined-variables --no-print-directory
SHELL := bash
.SHELLFLAGS := -eu -o pipefail -c
.DEFAULT_GOAL := all
.DELETE_ON_ERROR:
.SUFFIXES:

ifndef AWS_DEFAULT_PROFILE
$(error AWS_DEFAULT_PROFILE is not set)
endif

REGION=eu-west-1

export AWS_DEFAULT_REGION=$(REGION)

TFPLAN_FILE=/tmp/sudoku-$(REGION)-tf.plan

.PHONY: all
all: clean init fmt validate plan

.PHONY: clean
clean:
	rm -fr .terraform/*zip

.PHONY: init
init:
	@terraform init

.PHONY: fmt
fmt:
	@terraform fmt

.PHONY: validate
validate:
	@terraform validate

.PHONY: plan
plan: init lambda
	@terraform taint -allow-missing aws_api_gateway_stage.stage
	@terraform taint -allow-missing aws_api_gateway_deployment.deployment
	@terraform plan \
		-refresh=true \
		-out=$(TFPLAN_FILE)

.PHONY: lambda
lambda: findpuzzle solvepuzzle signer

.PHONY: findpuzzle
findpuzzle:
	mkdir -p .files/findpuzzle
	go build lambdas/findpuzzle/findpuzzle.go
	mv findpuzzle .files/findpuzzle

.PHONY: solvepuzzle
solvepuzzle:
	mkdir -p .files/solvepuzzle
	go build lambdas/solvepuzzle/solvepuzzle.go
	mv solvepuzzle .files/solvepuzzle

.PHONY: signer
signer:
	mkdir -p .files/signer
	go build lambdas/signer/signer.go
	mv signer .files/signer

.PHONY: apply
apply:
	@terraform apply $(TFPLAN_FILE) || true
	@rm -f $(TFPLAN_FILE)

.PHONY: output
output: init
	@terraform output

.PHONY: show
show: init
	@terraform show
