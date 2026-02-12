FROM golang:1.22-alpine AS builder

RUN apk add --no-cache gcc musl-dev sqlite-dev

WORKDIR /build
COPY go.mod ./
RUN go mod download

COPY . .
RUN CGO_ENABLED=1 GOOS=linux go build -o xyidactyl-agent ./cmd/agent

# --- Runtime ---
FROM alpine:3.19

RUN apk add --no-cache sqlite-libs ca-certificates
RUN adduser -D -u 1000 agent

WORKDIR /app
COPY --from=builder /build/xyidactyl-agent .
COPY docker/entrypoint.sh .
RUN chmod +x entrypoint.sh

RUN mkdir -p /control /data/logs && chown -R agent:agent /control /data /app

USER agent

# No EXPOSE — this agent has zero inbound networking

ENTRYPOINT ["./entrypoint.sh"]
