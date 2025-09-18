.PHONY: help install-vault start-vault stop-vault status-vault run-rulebook run-rulebook-bg stop-rulebook test-events clean setup-env build-collection publish-collection release-collection

# Default target
help:
	@echo "Available targets:"
	@echo "  setup-env        - Set up environment and install dependencies"
	@echo "  start-vault      - Start Vault in dev mode"
	@echo "  stop-vault       - Stop Vault server"
	@echo "  status-vault     - Check Vault server status"
	@echo "  run-rulebook     - Run the Vault EDA rulebook (foreground)"
	@echo "  run-rulebook-bg  - Run the Vault EDA rulebook (background)"
	@echo "  stop-rulebook    - Stop background rulebook"
	@echo "  test-events      - Generate test events to trigger rulebook"
	@echo "  clean            - Stop Vault and clean up"
	@echo "  build-collection - Build the Ansible collection"
	@echo "  publish-collection - Publish collection to Ansible Galaxy"
	@echo "  release-collection - Build and publish collection"
	@echo ""
	@echo "Environment Variables:"
	@echo "  VAULT_ADDR       - Vault server URL (default: http://127.0.0.1:8200)"
	@echo "  VAULT_TOKEN      - Vault authentication token (default: myroot)"
	@echo ""
	@echo "Quick start:"
	@echo "  export VAULT_ADDR=http://127.0.0.1:8200 VAULT_TOKEN=myroot"
	@echo "  make setup-env && make start-vault && make run-rulebook-bg && make test-events"

# Set up Python environment and dependencies
setup-env:
	@echo "Setting up environment..."
	python3 -m venv .venv
	source .venv/bin/activate && pip install -r requirements.txt
	@echo "Environment setup complete!"

# Start Vault in dev mode
start-vault:
	@echo "Starting Vault in dev mode..."
	@if pgrep -f "vault server" > /dev/null; then \
		echo "Vault is already running"; \
	else \
		vault server -dev -dev-root-token-id=myroot -dev-listen-address=127.0.0.1:8200 > vault.log 2>&1 & \
		echo $$! > vault.pid; \
		sleep 3; \
		echo "Vault started with PID $$(cat vault.pid)"; \
		echo "Root token: myroot"; \
		echo "Vault Address: http://127.0.0.1:8200"; \
		export VAULT_ADDR=http://127.0.0.1:8200; \
		export VAULT_TOKEN=myroot; \
		vault kv put secret/test data=hello || true; \
		echo "Vault is ready!"; \
	fi

# Stop Vault server
stop-vault:
	@echo "Stopping Vault server..."
	@if [ -f vault.pid ]; then \
		kill $$(cat vault.pid) 2>/dev/null || true; \
		rm -f vault.pid; \
		echo "Vault stopped"; \
	else \
		pkill -f "vault server" || true; \
		echo "Vault process killed"; \
	fi

# Check Vault status
status-vault:
	@if pgrep -f "vault server" > /dev/null; then \
		echo "Vault is running"; \
		export VAULT_ADDR=http://127.0.0.1:8200; \
		export VAULT_TOKEN=myroot; \
		vault status || true; \
	else \
		echo "Vault is not running"; \
	fi

# Run the rulebook
run-rulebook:
	@echo "Running Vault EDA rulebook..."
	@export PATH="/opt/homebrew/opt/openjdk/bin:$$PATH" && \
	export JAVA_HOME="/opt/homebrew/opt/openjdk/libexec/openjdk.jdk/Contents/Home" && \
	export DYLD_LIBRARY_PATH="$$JAVA_HOME/lib/server:$$DYLD_LIBRARY_PATH" && \
	export VAULT_ADDR=$${VAULT_ADDR:-http://127.0.0.1:8200} && \
	export VAULT_TOKEN=$${VAULT_TOKEN:-myroot} && \
	source .venv/bin/activate && \
	ansible-rulebook -i inventory.yml -r vault-eda-rulebook.yaml --env-vars VAULT_ADDR,VAULT_TOKEN --verbose

# Run the rulebook in background
run-rulebook-bg:
	@echo "Starting Vault EDA rulebook in background..."
	@if pgrep -f "ansible-rulebook" > /dev/null; then \
		echo "Rulebook is already running"; \
	else \
		export PATH="/opt/homebrew/opt/openjdk/bin:$$PATH" && \
		export JAVA_HOME="/opt/homebrew/opt/openjdk/libexec/openjdk.jdk/Contents/Home" && \
		export DYLD_LIBRARY_PATH="$$JAVA_HOME/lib/server:$$DYLD_LIBRARY_PATH" && \
		export VAULT_ADDR=$${VAULT_ADDR:-http://127.0.0.1:8200} && \
		export VAULT_TOKEN=$${VAULT_TOKEN:-myroot} && \
		source .venv/bin/activate && \
		ansible-rulebook -i inventory.yml -r vault-eda-rulebook.yaml --env-vars VAULT_ADDR,VAULT_TOKEN --verbose > rulebook.log 2>&1 & \
		echo $$! > rulebook.pid; \
		sleep 3; \
		echo "Rulebook started with PID $$(cat rulebook.pid)"; \
		echo "Logs: tail -f rulebook.log"; \
	fi

# Stop background rulebook
stop-rulebook:
	@echo "Stopping rulebook..."
	@if [ -f rulebook.pid ]; then \
		kill $$(cat rulebook.pid) 2>/dev/null || true; \
		rm -f rulebook.pid; \
		echo "Rulebook stopped"; \
	else \
		pkill -f "ansible-rulebook" || true; \
		echo "Rulebook process killed"; \
	fi

# Generate test events
test-events:
	@echo "Generating test events..."
	@./scripts/generate-vault-events.sh

# Clean up everything
clean: stop-vault stop-rulebook
	@echo "Cleaning up..."
	@rm -rf .venv/
	@rm -f vault.log vault.pid rulebook.log rulebook.pid
	@echo "Cleanup complete!"

# Development workflow
dev: setup-env start-vault
	@echo "Development environment ready!"
	@echo "In another terminal, run: make run-rulebook"
	@echo "To generate events, run: make test-events"

# Collection build and release targets
build-collection:
	@echo "Building Ansible collection..."
	@cd collections/ansible_collections/gitrgoliveira/vault && \
	rm -f gitrgoliveira-vault-*.tar.gz && \
	ansible-galaxy collection build
	@echo "Collection built successfully!"

publish-collection:
	@echo "Publishing collection to Ansible Galaxy..."
	@if [ -z "$(GALAXY_API_KEY)" ]; then \
		echo "Error: GALAXY_API_KEY environment variable not set"; \
		echo "Get your API key from: https://galaxy.ansible.com/me/preferences"; \
		echo "Then run: export GALAXY_API_KEY=your_api_key_here"; \
		exit 1; \
	fi
	@cd collections/ansible_collections/gitrgoliveira/vault && \
	COLLECTION_FILE=$$(ls gitrgoliveira-vault-*.tar.gz 2>/dev/null | head -1) && \
	if [ -z "$$COLLECTION_FILE" ]; then \
		echo "Error: No collection file found. Run 'make build-collection' first."; \
		exit 1; \
	fi && \
	echo "Publishing $$COLLECTION_FILE..." && \
	ansible-galaxy collection publish $$COLLECTION_FILE --api-key $(GALAXY_API_KEY)
	@echo "Collection published successfully!"

release-collection: build-collection publish-collection
	@echo "Collection release complete!"
