# Slackbot
This is a silly simple karma slackbot KOTS app delivered as Helm chart which
uses a Postgres backend to store karma scores.

It is written in Go deployed as part of a Replicated Embedded Cluster to serve
as a demo for the Replicated platform.

The slackbot obtains the slack tokens from Kubernetes secrets.

