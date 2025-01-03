package example

import (
	"net/http"

	"github.com/gin-gonic/gin"
)

// EchoResponse is the response for the echo route.
// swagger:response EchoResponse
type EchoResponse struct {
	// Message to be echoed back.
	// Required: true
	// In: body
	Body string `json:"body"`
}

// swagger:parameters Echo
type EchoParams struct {
	// in:body
	Body EchoBody
}

// EchoBody defines the structure of the request body.
type EchoBody struct {
	// Name of the app that is to be created.
	// Required: true
	Name string `json:"name"`
}

// JSON serializes the EchoResponse.Body as JSON into the response body.
func (r *EchoResponse) JSON(c *gin.Context) {
	c.JSON(http.StatusCreated, r.Body)
}

// Echo defines the handler for echoing back the request.
func Echo(c *gin.Context) {
	// swagger:route POST /echo Echo
	//
	// Echo back the request.
	//
	//     Consumes:
	//     - application/json
	//
	//     Produces:
	//     - application/json
	//
	//     Schemes: https
	//
	//     Security:
	//       api_key:
	//
	//     Responses:
	//       200: EchoResponse
	//       400: responseErrBadRequest
	//       401: responseErrUnauthorized
	//       403: responseErrForbidden

	// ctx := c.Request.Context()

	var request EchoParams
	if err := c.Bind(&request.Body); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	response := EchoResponse{Body: request.Body.Name}
	response.JSON(c)
}
