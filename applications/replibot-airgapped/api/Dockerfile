# Stage 1: Build stage
FROM golang:1.22 AS build

# Set the working directory
WORKDIR /app

# Copy and download dependencies
COPY go.mod go.sum ./
RUN go mod download

# Copy the source code
COPY . .

RUN make build

EXPOSE 3000

ENTRYPOINT ["bin/api", "-d"]
