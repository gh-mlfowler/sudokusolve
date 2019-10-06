package main

import (
	"encoding/json"
	"github.com/aws/aws-lambda-go/events"
	"github.com/aws/aws-lambda-go/lambda"
	"github.com/aws/aws-sdk-go/aws"
	"github.com/aws/aws-sdk-go/aws/session"
	"github.com/aws/aws-sdk-go/service/s3"
	"github.com/google/uuid"
	"log"
	"net/http"
	"os"
	"time"
)

var s3api = s3.New(session.New(), aws.NewConfig())

type Signed struct {
	Uri string
	Bucket string
	Key string
}

func HandleRequest(req events.APIGatewayProxyRequest) (events.APIGatewayProxyResponse, error) {

	var bucket = os.Getenv("BUCKET")

	key, err := uuid.NewUUID()
	if err != nil {
		log.Printf("uuid generation: %v", err)
		return events.APIGatewayProxyResponse{
			StatusCode: http.StatusInternalServerError,
			Body:       http.StatusText(http.StatusInternalServerError),
		}, nil
	}

	log.Printf("Signing request for bucket '%s' with key '%s'", bucket, key)

	put := &s3.PutObjectInput{
		Bucket: aws.String(bucket),
		Key: aws.String(key.String()),
	}

	sign,_ := s3api.PutObjectRequest(put)
	uri, err := sign.Presign(5 * time.Minute)

	log.Printf("New key '%s' for signed URL: %v", key.String(), uri)

	signed := Signed{
		Uri: uri,
		Bucket: bucket,
		Key: key.String(),
	}

	js, err := json.Marshal(signed)
	if err != nil {
		log.Printf("marhsalling json: %v", err)
		return events.APIGatewayProxyResponse{
			StatusCode: http.StatusInternalServerError,
			Body:       http.StatusText(http.StatusInternalServerError),
		}, nil
	}

	log.Printf("%s", js)

	resp := events.APIGatewayProxyResponse{
		StatusCode: http.StatusOK,
		Body:       string(js),
		Headers: make(map[string]string),
	}

	resp.Headers["Access-Control-Allow-Origin"] = "*"

	return resp, nil
}

func main() {
	lambda.Start(HandleRequest)
}