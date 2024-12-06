SHELL := /bin/bash
PROJECT_NAME ?= api

export GOPRIVATE=github.com/replicatedhq/vandoor
export GO111MODULE=on
export CGO_ENABLED=0
export GITHUB_SHA ?= local
export VERSION ?= $(GITHUB_SHA)
export BUILD_VERSION ?= $(GITHUB_SHA)
DATE = `date -u +"%Y-%m-%dT%H:%M:%SZ"`
BUILDFLAGS = -tags "netgo containers_image_ostree_stub exclude_graphdriver_devicemapper exclude_graphdriver_btrfs containers_image_openpgp" -installsuffix netgo

.PHONY: swagger-spec
swagger-spec:
	set -e
	mkdir -p ./spec/v1

	swagger generate spec -o ./spec/v1/api-v1.json --scan-models
	swagger validate ./spec/v1/api-v1.json

.PHONY: clean
clean:
	rm -f ./bin/api

.PHONY: build
build:
	mkdir -p bin
	go build -v ${BUILDFLAGS} \
	  -o bin/api .

.PHONY: install
install:
	go install

.PHONY: run
run:
	./bin/api -d

.PHONY: okteto-dev
okteto-dev:
    ## We download all go modules, instead of putting them in the container. This will
    ## use the PVC that everyone has, and will build a cache.
    ##
    ## We also run `make build` here because the initial compilation is slow and
    ## this enabled `okteto up` to do all of the long-running stuff and give the user
    ## a pretty good env right after
	@go mod download -x
	@make build
	@printf "\n\n To build and run admin-api, run: \n\n   # make build run\n\n"

.PHONY: deps
deps:
	go mod download

.PHONY: test
test:
	go test -v ./...


LOG_LEVEL ?= debug

.PHONY: debug-build
debug-build:
	go build \
		${BUILDFLAGS} \
		${LDFLAGS} \
		-gcflags="all=-N -l" \
		-o bin/api-debug \
		.
	@echo built bin/api-debug

.PHONY: debug
debug: debug-build
	LOG_LEVEL=$(LOG_LEVEL) dlv --listen=:2345 --headless=true --api-version=2 exec ./bin/api-debug