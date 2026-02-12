.PHONY: build run test clean

build:
	CGO_ENABLED=1 go build -o bin/xyidactyl-agent ./cmd/agent

run: build
	AGENT_UUID=test-uuid \
	AGENT_SECRET=test-secret-must-be-at-least-16-chars-long \
	PANEL_URL=http://localhost \
	PANEL_API_KEY=test-key \
	CONTROL_FILE_PATH=./test_control.json \
	DATA_DIR=./test_data \
	PUSH_PROVIDER=dev \
	./bin/xyidactyl-agent

test:
	go test -v ./...

clean:
	rm -rf bin/ test_data/

docker-build:
	docker build -f docker/Dockerfile -t xyidactyl-agent .
