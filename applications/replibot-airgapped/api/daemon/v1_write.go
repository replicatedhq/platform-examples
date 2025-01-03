package daemon

import (
	"github.com/gin-gonic/gin"
	"github.com/replicatedhq/replibot/api/handlers/replv1/example"
	"github.com/replicatedhq/replibot/api/middlewares"
)

func addRoutersWriteV1(parent *gin.RouterGroup) *gin.RouterGroup {
	internalWriteGroupV1 := parent.Group("/v1")
	internalWriteGroupV1.Use(middlewares.RequiresAuthTokens())
	internalWriteGroupV1.POST("/echo", example.Echo)

	return internalWriteGroupV1
}
