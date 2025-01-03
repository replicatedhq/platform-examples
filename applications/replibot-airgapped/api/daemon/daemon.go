package daemon

import (
	"fmt"
	"net/http"
	"os"
	"strings"

	"github.com/gin-gonic/gin"
	"github.com/replicatedhq/replibot/api/handlers"
)

type Daemon struct {
	r             *gin.Engine
	baseGroup     *gin.RouterGroup
	unauthedGroup *gin.RouterGroup
}

func Run() {
	// go http.ListenAndServe("0.0.0.0:8080", nil)

	d := Daemon{
		r: gin.New(),
	}

	if err := d.setupGin(); err != nil {
		fmt.Println("Failed to setup Gin: %w", err)
		return
	}

	if err := d.addRoutesV1(); err != nil {
		panic(err)
	}

	err := d.setCustomMetrics()
	if err != nil {
		fmt.Println("Failed to set custom metrics: %w", err)
	}

	err = d.r.Run(":3000")
	fmt.Println("Server exited unexpectedly: %w", err)
}

func (d *Daemon) setupGin() error {
	d.r.GET("/healthz", handlers.GetHealthz)
	d.baseGroup = d.r.Group("/api")

	d.unauthedGroup = d.baseGroup.Group("/")
	return nil
}

func (d *Daemon) setCustomMetrics() error {
	// Send POST request to /metrics endpoint with json payload
	installID := os.Getenv("INSTALLED_INSTANCE_ID")

	resp, err := http.Post("http://replicated:3000/api/v1/app/custom-metrics", "application/json", strings.NewReader(`{"data":{"installed_instance_id":"`+installID+`"}}`))
	if err != nil {
		return err
	}
	defer resp.Body.Close()
	return nil
}
