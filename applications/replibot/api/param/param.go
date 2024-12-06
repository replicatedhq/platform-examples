package param

import (
	"os"

	"github.com/aws/aws-sdk-go/aws/session"
)

var params *Params

var paramLookup = map[string]string{
	"BUGSNAG_KEY":           "/bugsnag/api_key",
	"GITHUB_COLLAB_TOKEN":   "/vendor_api/github_collab_token",
	"OPENAI_TOKEN":          "/replibot/openai_token",
	"ENTITLEMENTS_ENDPOINT": "/replicated/entitlements_endpoint",
	"INTERNAL_AUTH_TOKEN":   "/replibot/internal_auth_token",
	"SLACK_SIGNING_SECRET":  "/replibot/slack_signing_secret",
}

type Params struct {
	BugsnagKey           string
	GitHubCollabToken    string
	OpenAIToken          string
	EntitlementsEndpoint string
	InternalAuthToken    string
	SlackSigningSecret   string
	AllowedSlackChannels string
}

func Get() Params {
	if params == nil {
		panic("params not initialized")
	}
	return *params
}

func Init(sess *session.Session) error {

	params = &Params{
		// BugsnagKey: paramsMap["BUGSNAG_KEY"],
		// GitHubCollabToken:    paramsMap["GITHUB_COLLAB_TOKEN"],
		// OpenAIToken:          paramsMap["OPENAI_TOKEN"],
		// EntitlementsEndpoint: paramsMap["ENTITLEMENTS_ENDPOINT"],
		// InternalAuthToken:    paramsMap["INTERNAL_AUTH_TOKEN"],
		// SlackSigningSecret:   paramsMap["SLACK_SIGNING_SECRET"],
		AllowedSlackChannels: os.Getenv("ALLOWED_CHANNELS"),
	}

	return nil
}
