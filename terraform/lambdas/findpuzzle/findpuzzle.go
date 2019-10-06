package main

import (
	"encoding/json"
	"fmt"
	"github.com/aws/aws-lambda-go/events"
	"github.com/aws/aws-lambda-go/lambda"
	"github.com/aws/aws-sdk-go/aws"
	"log"
	"net/http"
	"strconv"

	"github.com/aws/aws-sdk-go/aws/session"
	"github.com/aws/aws-sdk-go/service/rekognition"
)

var rkog = rekognition.New(session.New(), aws.NewConfig())

type Digit struct {
	Value int
	Top float64
	Left float64
}

type request struct {
	Bucket string
	Key string
}

type puzzle struct {
	Rows []string
}

func HandleRequest(req events.APIGatewayProxyRequest) (events.APIGatewayProxyResponse, error) {

	var r request
	err := json.Unmarshal([]byte(req.Body), &r)
	if err != nil {
		log.Printf("unmarshal: %v", err)
		return events.APIGatewayProxyResponse{
			StatusCode: http.StatusInternalServerError,
			Body:       http.StatusText(http.StatusInternalServerError),
		}, nil
	}

	obj := &rekognition.S3Object{
		Bucket: aws.String(r.Bucket),
		Name: aws.String(r.Key),
	}

	image := &rekognition.Image{
		S3Object: obj,
	}

	request := &rekognition.DetectTextInput{
		Image: image,
	}

	response, err := rkog.DetectText(request)
	if err != nil {
		log.Printf("s3 detect text: %v", err)
		return events.APIGatewayProxyResponse{
			StatusCode: http.StatusInternalServerError,
			Body:       http.StatusText(http.StatusInternalServerError),
		}, nil
	}

	var digits []Digit
	var minTop = float64(1)
	var maxTop = float64(0)
	var minLeft = float64(1)
	var maxLeft = float64(0)

	for _, detect := range response.TextDetections {
		switch *detect.Type {
		case rekognition.TextTypesWord:
			var numbers []int
			var text = *detect.DetectedText

			for i := 0; i < len(text); i++ {
				if num, err := strconv.Atoi(text[i:i+1]); err == nil {
					numbers = append(numbers, num)
				}
			}

			if len(numbers) == 0 {
				continue
			}

			if *detect.Geometry.BoundingBox.Left < minLeft {
				minLeft = *detect.Geometry.BoundingBox.Left
			}

			if *detect.Geometry.BoundingBox.Left + *detect.Geometry.BoundingBox.Width > maxLeft {
				maxLeft = *detect.Geometry.BoundingBox.Left + *detect.Geometry.BoundingBox.Width
			}

			if *detect.Geometry.BoundingBox.Top < minTop {
				minTop = *detect.Geometry.BoundingBox.Top
			}

			if *detect.Geometry.BoundingBox.Top + *detect.Geometry.BoundingBox.Height > maxTop {
				maxTop = *detect.Geometry.BoundingBox.Top + *detect.Geometry.BoundingBox.Height
			}

			width := (*detect.Geometry.BoundingBox.Width) / float64(len(numbers))
			for pos, num := range numbers {
				digit := Digit{
					Value: num,
					Top: *detect.Geometry.BoundingBox.Top,
					Left: *detect.Geometry.BoundingBox.Left + (float64(pos) * width),
				}

				digits = append(digits, digit)
			}
		}
	}

	var grid [9][9]int
	var width = (maxLeft - minLeft) / 9
	var height = (maxTop - minTop) / 9

	for _, digit := range digits {
		top := digit.Top + (height/4)
		left := digit.Left + (width/4)

		for i := 0; i < 9; i++ {
			if minTop + (float64(i)*height) < top && top < minTop + (float64(i+1)*height) {
				for j := 0; j < 9; j++ {
					if minLeft + (float64(j)*width) < left && left < minLeft + (float64(j+1)*width) {
						grid[i][j] = digit.Value
						break;
					}
				}
				break;
			}
		}
	}

	var rows []string

	for i := 0; i < 9; i++ {
		var row = ""
		for j := 0; j < 9; j++ {
			row = fmt.Sprintf("%s%d", row, grid[i][j])
		}

		log.Print(row)
		rows = append(rows, row)
	}

	puzzle := puzzle{
		Rows: rows,
	}

	js, err := json.Marshal(puzzle)
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

	return resp,nil
}

func main() {
	lambda.Start(HandleRequest)
}