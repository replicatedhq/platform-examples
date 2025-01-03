package handlers

import (
	"os"

	"github.com/gin-gonic/gin"
)

func GetHealthz(c *gin.Context) {
	c.JSON(200, gin.H{
		"status":  "ok",
		"version": os.Getenv("RELEASE_VERSION"),
	})
}
