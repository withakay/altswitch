# MacWindowSwitch Makefile

# Configuration
SWIFT := swift
BINARY_NAME := mac-window-switch
BUILD_DIR := .build
RELEASE_BUILD_DIR := $(BUILD_DIR)/release
DEBUG_BUILD_DIR := $(BUILD_DIR)/debug
INSTALL_PREFIX := /usr/local
INSTALL_BIN_DIR := $(INSTALL_PREFIX)/bin

# Build flags
SWIFT_BUILD_FLAGS := --configuration debug
SWIFT_RELEASE_FLAGS := --configuration release -Xswiftc -O

.PHONY: all build release test clean run install uninstall format docs help

# Default target - show help
all: help

# Build the project in debug mode
build:
	@echo "Building MacWindowSwitch (debug)..."
	$(SWIFT) build $(SWIFT_BUILD_FLAGS)

# Build the project in release mode
release:
	@echo "Building MacWindowSwitch (release)..."
	$(SWIFT) build $(SWIFT_RELEASE_FLAGS)

# Run tests
test:
	@echo "Running tests..."
	$(SWIFT) test

# Clean build artifacts
clean:
	@echo "Cleaning build artifacts..."
	$(SWIFT) package clean
	rm -rf $(BUILD_DIR)

# Run the CLI tool (debug)
run: build
	@echo "Running $(BINARY_NAME)..."
	$(DEBUG_BUILD_DIR)/$(BINARY_NAME)

# Run the CLI tool with arguments (use: make run-args ARGS="--help")
run-args: build
	@echo "Running $(BINARY_NAME) $(ARGS)..."
	$(DEBUG_BUILD_DIR)/$(BINARY_NAME) $(ARGS)

# Install the release binary
install: release
	@echo "Installing $(BINARY_NAME) to $(INSTALL_BIN_DIR)..."
	@mkdir -p $(INSTALL_BIN_DIR)
	install -m 755 $(RELEASE_BUILD_DIR)/$(BINARY_NAME) $(INSTALL_BIN_DIR)/$(BINARY_NAME)
	@echo "Installation complete. Run '$(BINARY_NAME)' from anywhere."

# Uninstall the binary
uninstall:
	@echo "Uninstalling $(BINARY_NAME)..."
	rm -f $(INSTALL_BIN_DIR)/$(BINARY_NAME)
	@echo "Uninstallation complete."

# Format code using swift-format (if installed)
format:
	@if command -v swift-format >/dev/null 2>&1; then \
		echo "Formatting Swift code..."; \
		find Sources Tests -name "*.swift" -exec swift-format -i {} \; ; \
		echo "Format complete."; \
	else \
		echo "swift-format not found. Install it with: brew install swift-format"; \
		exit 1; \
	fi

# Generate documentation using swift-docc (if available)
docs:
	@if command -v xcrun >/dev/null 2>&1 && xcrun --find docc >/dev/null 2>&1; then \
		echo "Generating documentation..."; \
		$(SWIFT) package generate-documentation; \
		echo "Documentation generated."; \
	else \
		echo "swift-docc not found. Documentation generation requires Xcode."; \
		exit 1; \
	fi

# Update dependencies
update:
	@echo "Updating package dependencies..."
	$(SWIFT) package update

# Resolve dependencies
resolve:
	@echo "Resolving package dependencies..."
	$(SWIFT) package resolve

# Show package info
info:
	@echo "Package information:"
	@$(SWIFT) package describe

# Run the Python script for listing windows
list-windows:
	@echo "Running window list script..."
	python3 scripts/list-windows.py

# Run MacWindowDiscovery debug app for listing windows
run-debug-app:
	@if [ -f ../packages/MacWindowDiscovery/.build/debug/mac-window-discovery-debug ]; then \
		echo "Running MacWindowDiscovery debug app..."; \
		../packages/MacWindowDiscovery/.build/debug/mac-window-discovery-debug; \
	else \
		echo "Error: MacWindowDiscovery debug app not found"; \
		echo "Build it first: cd ../packages/MacWindowDiscovery && swift build"; \
		exit 1; \
	fi

# Interactively activate a window
activate-window: build
	@./scripts/activate-window.sh

# Activate a window with extended wait time (for debugging)
activate-window-debug: build
	@./scripts/activate-window-debug.sh

# Help target
help:
	@echo "MacWindowSwitch - Available Make Targets"
	@echo ""
	@echo "Build Targets:"
	@echo "  make build          - Build the project in debug mode"
	@echo "  make release        - Build the project in release mode"
	@echo "  make clean          - Clean build artifacts"
	@echo ""
	@echo "Development:"
	@echo "  make test           - Run tests"
	@echo "  make run            - Run the CLI tool (debug)"
	@echo "  make run-args ARGS='...' - Run CLI with arguments"
	@echo "  make format         - Format Swift code (requires swift-format)"
	@echo "  make docs           - Generate documentation"
	@echo ""
	@echo "Installation:"
	@echo "  make install        - Install release binary to $(INSTALL_BIN_DIR)"
	@echo "  make uninstall      - Remove installed binary"
	@echo ""
	@echo "Dependencies:"
	@echo "  make update         - Update package dependencies"
	@echo "  make resolve        - Resolve package dependencies"
	@echo "  make info           - Show package information"
	@echo ""
	@echo "Utilities:"
	@echo "  make run-debug-app  - Run MacWindowDiscovery to list windows"
	@echo "  make list-windows   - Run the window list Python script"
	@echo "  make activate-window - Interactively activate a window by ID"
	@echo "  make help           - Show this help message"
