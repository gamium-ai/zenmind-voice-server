APP_NAME := voice-server
BIN_DIR := bin
BIN_PATH := $(BIN_DIR)/$(APP_NAME)
VERSION ?= $(shell cat VERSION 2>/dev/null)
ARCH ?=
RELEASE_TARGETS ?=
RELEASE_TARGET_MATRIX ?=
PROGRAM_TARGETS ?= $(RELEASE_TARGETS)
PROGRAM_TARGET_MATRIX ?= $(RELEASE_TARGET_MATRIX)
LDFLAGS := -X main.buildVersion=$(VERSION)
FRONTEND_DIR := frontend
FRONTEND_UI_DIR := internal/httpapi/ui

.PHONY: build run test frontend-install frontend-dev frontend-build frontend-build-embed release clean

build: frontend-build-embed
	mkdir -p $(BIN_DIR)
	go build -ldflags "$(LDFLAGS)" -o $(BIN_PATH) ./cmd/voice-server

run: frontend-build-embed
	go run -ldflags "$(LDFLAGS)" ./cmd/voice-server

test:
	go test ./...

frontend-install:
	cd $(FRONTEND_DIR) && npm ci

frontend-dev: frontend-install
	cd $(FRONTEND_DIR) && npm run dev

frontend-build: frontend-install
	cd $(FRONTEND_DIR) && npm run build

frontend-build-embed: frontend-build
	mkdir -p $(FRONTEND_UI_DIR)
	find $(FRONTEND_UI_DIR) -mindepth 1 ! -name '.gitkeep' ! -name 'placeholder.txt' -exec rm -rf {} +
	cp -R $(FRONTEND_DIR)/dist/. $(FRONTEND_UI_DIR)/

release:
	VERSION=$(VERSION) ARCH=$(ARCH) PROGRAM_TARGETS=$(PROGRAM_TARGETS) PROGRAM_TARGET_MATRIX=$(PROGRAM_TARGET_MATRIX) RELEASE_TARGETS=$(RELEASE_TARGETS) RELEASE_TARGET_MATRIX=$(RELEASE_TARGET_MATRIX) bash scripts/release.sh

clean:
	rm -f $(BIN_PATH)
	find $(FRONTEND_UI_DIR) -mindepth 1 ! -name '.gitkeep' ! -name 'placeholder.txt' -exec rm -rf {} +
