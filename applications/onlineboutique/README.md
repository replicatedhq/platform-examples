# Onlineboutique

Demo replicated app for the google [onlineboutique](https://github.com/GoogleCloudPlatform/microservices-demo) microservices demo

The purpose of this app is to demonstrate porting an existing established helm chart into a replicated release.

# Currently implimented: 

- Initial set of helm values mapped to config options
- Config dependant status informers
- Embedded Cluster
- Replicated SDK included


# TODO: 

This is a work in progress, and there are several outstanding tasks:

- Complete integration of helm values into replicated config options
- Use Replicated Proxy for images
- Ingress and TLS
- Custom metrics
- Build pipelines
