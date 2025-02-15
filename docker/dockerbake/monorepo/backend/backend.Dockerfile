# Define the argument with a default value
ARG GO_VERSION=1.21
FROM golang:${GO_VERSION}

# Set working directory
WORKDIR /app
COPY . .
RUN go build -o app
CMD ["./app"]
