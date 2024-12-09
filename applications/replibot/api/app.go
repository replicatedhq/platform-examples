package main

import (
	golog "log"

	"math/rand"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/aws/aws-sdk-go/aws"
	"github.com/aws/aws-sdk-go/aws/session"
	"github.com/replicatedhq/replibot/api/daemon"
	"github.com/replicatedhq/replibot/api/param"
)

func main() {

	// bugsnag.Configure(bugsnag.Configuration{AppVersion: os.Getenv("RELEASE_VERSION")})

	// Start the server
	go daemon.Run()

	rand.Seed(time.Now().UTC().UnixNano())

	sess := session.New(
		aws.NewConfig().
			WithCredentialsChainVerboseErrors(true),
	)

	if err := param.Init(sess); err != nil {
		golog.Fatalf("Failed to initialize params: %v", err)
	}

	// log.Init(&log.LogOptions{
	// 	BugsnagKey: param.Get().BugsnagKey,
	// }, nil, nil)

	term := make(chan os.Signal, 1)
	signal.Notify(term, syscall.SIGINT, syscall.SIGTERM)
	<-term
}
