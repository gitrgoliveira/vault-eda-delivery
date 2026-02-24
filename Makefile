.PHONY: help install-vault start-vault stop-vault status-vault run-rulebook run-rulebook-bg stop-rulebook test-events clean setup-env compile-deps build-collection publish-collection release-collection install-java check-java

# Default target
help:
	@echo "Available targets:"
	@echo "  install-java     - Install Java/OpenJDK (required for ansible-rulebook)"
	@echo "  check-java       - Check if Java is installed"
	@echo "  setup-env        - Set up environment and install dependencies"
	@echo "  compile-deps     - Compile requirements.in to requirements.txt"
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
	@echo "  make install-java  # First install Java"
	@echo "  make setup-env     # Then setup environment"
	@echo "  export VAULT_ADDR=http://127.0.0.1:8200 VAULT_TOKEN=myroot"
	@echo "  make start-vault && make run-rulebook-bg && make test-events"

# Check if Java is installed
check-java:
	@echo "Checking Java installation..."
	@if command -v java >/dev/null 2>&1; then \
		echo "✓ Java is installed"; \
		java -version 2>&1 | head -1; \
	else \
		echo "✗ Java is NOT installed"; \
		echo "Run 'make install-java' to install it"; \
		exit 1; \
	fi
	@echo "Checking Maven installation..."
	@if command -v mvn >/dev/null 2>&1; then \
		echo "✓ Maven is installed"; \
		mvn -version 2>&1 | head -1; \
	else \
		echo "✗ Maven is NOT installed (required for jpy build)"; \
		echo "Run 'make install-java' to install it"; \
		exit 1; \
	fi

# Install Java/OpenJDK via Homebrew
install-java:
	@echo "Installing Java/OpenJDK and Maven..."
	@if ! command -v brew >/dev/null 2>&1; then \
		echo "ERROR: Homebrew not found. Install from https://brew.sh"; \
		exit 1; \
	fi
	@echo "Installing OpenJDK via Homebrew..."
	brew install openjdk
	@echo "Installing Maven via Homebrew..."
	brew install maven
	@echo "Linking OpenJDK to system Java directories..."
	sudo ln -sfn $$(brew --prefix)/opt/openjdk/libexec/openjdk.jdk /Library/Java/JavaVirtualMachines/openjdk.jdk || true
	@echo "✓ Java and Maven installation complete!"
	@echo "Verifying installation..."
	@java -version 2>&1 | head -1
	@mvn -version 2>&1 | head -1

# Set up Python environment and dependencies
setup-env:
	@echo "Setting up environment..."
	@echo "Checking for Java installation (required for drools-jpy)..."
	@if ! command -v java >/dev/null 2>&1; then \
		echo ""; \
		echo "ERROR: Java not found. ansible-rulebook requires Java for drools-jpy."; \
		echo "Run 'make install-java' to install Java and Maven"; \
		exit 1; \
	fi
	@echo "Checking for Maven installation (required for jpy build)..."
	@if ! command -v mvn >/dev/null 2>&1; then \
		echo ""; \
		echo "ERROR: Maven not found. jpy (required by drools-jpy) needs Maven to build."; \
		echo "Run 'make install-java' to install Java and Maven"; \
		exit 1; \
	fi
	@echo "✓ Java and Maven found"
	python3 -m venv .venv
	@if [ -d "/opt/homebrew/opt/openjdk" ]; then \
		echo "OpenJDK found, configuring Java environment..."; \
		export PATH="/opt/homebrew/opt/openjdk/bin:$$PATH" && \
		export JAVA_HOME="/opt/homebrew/opt/openjdk/libexec/openjdk.jdk/Contents/Home" && \
		export DYLD_LIBRARY_PATH="$$JAVA_HOME/lib/server:$$DYLD_LIBRARY_PATH" && \
		source .venv/bin/activate && pip install -r requirements.txt; \
	else \
		echo "Configuring system Java environment..."; \
		export JAVA_HOME=$$(java -XshowSettings:properties -version 2>&1 | grep 'java.home' | awk '{print $$3}') && \
		export DYLD_LIBRARY_PATH="$$JAVA_HOME/lib/server:$$DYLD_LIBRARY_PATH" && \
		source .venv/bin/activate && pip install -r requirements.txt; \
	fi
	@echo "Environment setup complete!"

# Compile requirements.in to requirements.txt using pip-compile
# NOTE: This requires Java and Maven to resolve drools-jpy dependencies.
# If you don't have them installed, run 'make install-java' first.
compile-deps:
	@echo "Compiling requirements.in to requirements.txt..."
	@echo ""
	@echo "⚠️  WARNING: This requires Java + Maven to be installed"
	@echo "    Run 'make check-java' to verify or 'make install-java' to install"
	@echo ""
	@if ! command -v java >/dev/null 2>&1 || ! command -v mvn >/dev/null 2>&1; then \
		echo "ERROR: Java and/or Maven not found."; \
		echo ""; \
		echo "The 'jpy' package (required by drools-jpy) needs Java + Maven to compile."; \
		echo ""; \
		echo "SOLUTION:"; \
		echo "  1. Run: make install-java"; \
		echo "  2. Then: make compile-deps"; \
		echo ""; \
		echo "OR manually install:"; \
		echo "  brew install openjdk maven"; \
		echo ""; \
		exit 1; \
	fi
	@if [ ! -d ".venv-compile" ]; then \
		echo "Creating temporary venv for compilation..."; \
		python3 -m venv .venv-compile; \
	fi
	@export PATH="/opt/homebrew/opt/openjdk/bin:$$PATH" && \
	export JAVA_HOME="/opt/homebrew/opt/openjdk/libexec/openjdk.jdk/Contents/Home" && \
	source .venv-compile/bin/activate && \
	pip install --quiet --upgrade pip pip-tools && \
	pip-compile --no-emit-index-url --resolver=backtracking --upgrade --output-file=requirements.txt requirements.in
	@rm -rf .venv-compile
	@echo "✓ Dependencies compiled successfully!"

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
		ansible-rulebook -i inventory.yml -r rulebooks/vault-eda-rulebook.yaml --env-vars VAULT_ADDR,VAULT_TOKEN --verbose > rulebook.log 2>&1 & \
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
	@rm -rf .venv/ .venv-*/
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
	@cd collections/ansible_collections/gitrgoliveira/vault_eda && \
	rm -f gitrgoliveira-vault_eda-*.tar.gz && \
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
	@cd collections/ansible_collections/gitrgoliveira/vault_eda && \
	COLLECTION_FILE=$$(ls gitrgoliveira-vault_eda-*.tar.gz 2>/dev/null | head -1) && \
	if [ -z "$$COLLECTION_FILE" ]; then \
		echo "Error: No collection file found. Run 'make build-collection' first."; \
		exit 1; \
	fi && \
	echo "Publishing $$COLLECTION_FILE..." && \
	ansible-galaxy collection publish $$COLLECTION_FILE --api-key $(GALAXY_API_KEY)
	@echo "Collection published successfully!"

release-collection: build-collection publish-collection
	@echo "Collection release complete!"
