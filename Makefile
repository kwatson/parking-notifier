.PHONY: build help push

help: ## Help
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

.DEFAULT_GOAL := help

build: ## Build Image
	@docker build -t ghcr.io/kwatson/parking-notifier:latest .

push: ## Deploy newly crated image
	@docker push ghcr.io/kwatson/parking-notifier:latest
