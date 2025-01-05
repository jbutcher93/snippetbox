FROM golang:1.22.2 AS builder

WORKDIR /app

COPY go.mod go.sum ./

RUN go mod download

COPY cmd/web/*.go ./cmd/web/

COPY internal/ ./internal/

COPY ui/ ./ui/

RUN mkdir tls

RUN openssl req -newkey rsa:4096 -x509 -sha256 -days 365 -nodes -out tls/cert.pem -keyout tls/key.pem -subj "/C=US/ST=CA/L=SF/O=MyCompany/CN=localhost"

RUN CGO_ENABLED=0 GOOS=linux go build -o web ./cmd/web

CMD ["./web"]