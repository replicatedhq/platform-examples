package middlewares

import (
	"bytes"
	"crypto/hmac"
	"crypto/sha256"
	"encoding/hex"
	"fmt"
	"io"
	"net/http"
	"strconv"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/replicatedcom/saaskit/log"
	"github.com/replicatedhq/replibot/api/param"
)

func RequiresAuthTokens() gin.HandlerFunc {
	return func(c *gin.Context) {
		internalToken := c.GetHeader("X-Replicated-InternalToken")
		slackSignature := c.GetHeader("X-Slack-Signature")
		slackTimestamp := c.GetHeader("X-Slack-Request-Timestamp")

		if internalToken == "" && (slackSignature == "" || slackTimestamp == "") {
			c.AbortWithStatus(http.StatusUnauthorized)
			return
		}

		// validate internal token if present
		if internalToken != "" {
			if internalToken != param.Get().InternalAuthToken {
				c.AbortWithStatus(http.StatusUnauthorized)
				return
			}
			// valid token found, continue
			c.Next()
			return
		}

		// validate slack signature
		// https://api.slack.com/authentication/verifying-requests-from-slack#validating-a-request

		// 1. Grab Slack signing secret
		signingSecret := param.Get().SlackSigningSecret
		if signingSecret == "" {
			log.Errorf("Slack signing secret not found in SSM or environment")
			c.AbortWithStatus(http.StatusInternalServerError)
			return
		}

		// 2. Extract timestamp
		// prevent relay attack
		timestamp, err := strconv.ParseInt(slackTimestamp, 10, 64)
		if err != nil || time.Since(time.Unix(timestamp, 0)) > 5*time.Minute {
			c.AbortWithStatus(http.StatusUnauthorized)
			return
		}

		// 3. Concatenate the version number, the timestamp, and the request body together
		body, err := io.ReadAll(c.Request.Body)
		if err != nil {
			c.AbortWithStatus(http.StatusInternalServerError)
			return
		}
		c.Request.Body = io.NopCloser(bytes.NewReader(body))
		baseString := fmt.Sprintf("v0:%s:%s", slackTimestamp, string(body))

		// 4. Hash the resulting string, using the signing secret as a key, and taking the hex digest of the hash.
		mac := hmac.New(sha256.New, []byte(signingSecret))
		mac.Write([]byte(baseString))
		expectedMAC := "v0=" + hex.EncodeToString(mac.Sum(nil))

		// 5. Compare the resulting signature to the header on the request.
		if !hmac.Equal([]byte(slackSignature), []byte(expectedMAC)) {
			c.AbortWithStatus(http.StatusUnauthorized)
			return
		}

		// phew!
		c.Next()
	}
}
