FROM golang:1.23-alpine AS builder
WORKDIR /build
COPY app/go.mod ./
RUN go mod download
COPY app/ ./
RUN CGO_ENABLED=0 GOOS=linux go build -ldflags="-s -w" -o /license-validation .

FROM alpine:3.20
RUN apk --no-cache add ca-certificates
COPY --from=builder /license-validation /usr/local/bin/license-validation
USER 65534:65534
EXPOSE 8080
ENTRYPOINT ["license-validation"]
