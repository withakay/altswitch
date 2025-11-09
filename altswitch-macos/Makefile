# Makefile for AltSwitch macOS Application
# Provides build, test, and run targets for development workflow

# Project Configuration
PROJECT_NAME = AltSwitch
SCHEME = AltSwitch
WORKSPACE = AltSwitch.xcodeproj
CONFIGURATION_DEBUG = Debug
CONFIGURATION_RELEASE = Release

# Build Directories
BUILD_DIR = build
DERIVED_DATA_DIR = $(BUILD_DIR)/DerivedData
PRODUCTS_DIR = $(DERIVED_DATA_DIR)/Build/Products
DEBUG_BUILD_DIR = $(PRODUCTS_DIR)/Debug
RELEASE_BUILD_DIR = $(PRODUCTS_DIR)/Release
DIST_DIR = dist
DIST_APP_PATH = $(DIST_DIR)/$(APP_NAME)

# Test Configuration
TEST_DESTINATION = 'platform=macOS'
UNIT_TEST_TARGET = AltSwitchTests
UI_TEST_TARGET = AltSwitchUITests

# App Bundle
APP_NAME = $(PROJECT_NAME).app
DEBUG_APP_PATH = $(DEBUG_BUILD_DIR)/$(APP_NAME)
RELEASE_APP_PATH = $(RELEASE_BUILD_DIR)/$(APP_NAME)

# Tools
XCODEBUILD = xcodebuild
OPEN = open

# Default target
.DEFAULT_GOAL := help

# PHONY targets (not actual files)
.PHONY: help clean build build-debug build-release test test-unit test-ui test-performance \
        run run-debug run-release install archive analyze format lint coverage \
        setup deps check-deps check-tools bootstrap

##@ Development Commands

help: ## Display this help message
	@echo "AltSwitch Development Makefile"
	@echo "=============================="
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make \033[36m<target>\033[0m\n"} /^[a-zA-Z_0-9-]+:.*?##/ { printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2 } /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } ' $(MAKEFILE_LIST)

##@ Build Targets

build: build-debug ## Build debug version (default)

build-debug: check-tools ## Build debug version of AltSwitch
	@echo "🔨 Building AltSwitch (Debug)..."
	$(XCODEBUILD) \
		-scheme $(SCHEME) \
		-configuration $(CONFIGURATION_DEBUG) \
		-derivedDataPath $(DERIVED_DATA_DIR) \
		build
	@echo "✅ Debug build completed: $(DEBUG_BUILD_DIR)/$(APP_NAME)"

build-release: check-tools ## Build release version of AltSwitch
	@echo "🔨 Building AltSwitch (Release)..."
	$(XCODEBUILD) \
		-scheme $(SCHEME) \
		-configuration $(CONFIGURATION_RELEASE) \
		-derivedDataPath $(DERIVED_DATA_DIR) \
		build
	@echo "✅ Release build completed: $(RELEASE_BUILD_DIR)/$(APP_NAME)"
	@mkdir -p $(DIST_DIR)
	@rm -rf $(DIST_APP_PATH)
	cp -R $(RELEASE_BUILD_DIR)/$(APP_NAME) $(DIST_DIR)/
	@echo "📦 Copied release app to $(DIST_APP_PATH)"

archive: check-tools ## Create release archive for distribution
	@echo "📦 Creating archive..."
	$(XCODEBUILD) \
		-scheme $(SCHEME) \
		-configuration $(CONFIGURATION_RELEASE) \
		-derivedDataPath $(DERIVED_DATA_DIR) \
		-archivePath $(BUILD_DIR)/$(PROJECT_NAME).xcarchive \
		archive
	@echo "✅ Archive created: $(BUILD_DIR)/$(PROJECT_NAME).xcarchive"

##@ Test Targets

test: test-unit ## Run all tests (default to unit tests)

test-unit: check-tools ## Run unit tests with Swift Testing framework
	@echo "🧪 Running unit tests..."
	$(XCODEBUILD) test \
		-scheme $(SCHEME) \
		-destination $(TEST_DESTINATION) \
		-only-testing:$(UNIT_TEST_TARGET) \
		-derivedDataPath $(DERIVED_DATA_DIR) \
		-quiet
	@echo "✅ Unit tests completed"

test-ui: check-tools ## Run UI tests
	@echo "🧪 Running UI tests..."
	$(XCODEBUILD) test \
		-scheme $(SCHEME) \
		-destination $(TEST_DESTINATION) \
		-only-testing:$(UI_TEST_TARGET) \
		-derivedDataPath $(DERIVED_DATA_DIR) \
		-quiet
	@echo "✅ UI tests completed"

test-performance: check-tools ## Run performance tests only
	@echo "🧪 Running performance tests..."
	$(XCODEBUILD) test \
		-scheme $(SCHEME) \
		-destination $(TEST_DESTINATION) \
		-only-testing:$(UNIT_TEST_TARGET)/HotkeyPerformanceTests \
		-derivedDataPath $(DERIVED_DATA_DIR) \
		-quiet
	@echo "✅ Performance tests completed"

test-all: check-tools ## Run all test suites (unit + UI)
	@echo "🧪 Running all tests..."
	$(XCODEBUILD) test \
		-scheme $(SCHEME) \
		-destination $(TEST_DESTINATION) \
		-derivedDataPath $(DERIVED_DATA_DIR) \
		-quiet
	@echo "✅ All tests completed"

test-verbose: check-tools ## Run unit tests with verbose output
	@echo "🧪 Running unit tests (verbose)..."
	$(XCODEBUILD) test \
		-scheme $(SCHEME) \
		-destination $(TEST_DESTINATION) \
		-only-testing:$(UNIT_TEST_TARGET) \
		-derivedDataPath $(DERIVED_DATA_DIR)

coverage: check-tools ## Generate test coverage report
	@echo "📊 Generating test coverage report..."
	$(XCODEBUILD) test \
		-scheme $(SCHEME) \
		-destination $(TEST_DESTINATION) \
		-enableCodeCoverage YES \
		-derivedDataPath $(DERIVED_DATA_DIR) \
		-resultBundlePath $(BUILD_DIR)/TestResults.xcresult \
		-quiet
	@echo "📊 Coverage report generated: $(BUILD_DIR)/TestResults.xcresult"
	@echo "View with: xcrun xccov view --report $(BUILD_DIR)/TestResults.xcresult"

##@ Run Targets

run: run-debug ## Run debug version (default)

run-debug: build-debug ## Build and run debug version
	@echo "🚀 Launching AltSwitch (Debug)..."
	$(OPEN) $(DEBUG_BUILD_DIR)/$(APP_NAME)

run-release: build-release ## Build and run release version
	@echo "🚀 Launching AltSwitch (Release)..."
	$(OPEN) $(RELEASE_BUILD_DIR)/$(APP_NAME)

install: build-release ## Install release version to /Applications
	@echo "📱 Installing AltSwitch to /Applications..."
	@if [ -d "/Applications/$(APP_NAME)" ]; then \
		echo "⚠️  Removing existing installation..."; \
		rm -rf "/Applications/$(APP_NAME)"; \
	fi
	cp -R $(RELEASE_BUILD_DIR)/$(APP_NAME) /Applications/
	@echo "✅ AltSwitch installed to /Applications"

##@ Development Tools

analyze: check-tools ## Run static analyzer
	@echo "🔍 Running static analysis..."
	$(XCODEBUILD) analyze \
		-scheme $(SCHEME) \
		-configuration $(CONFIGURATION_DEBUG) \
		-derivedDataPath $(DERIVED_DATA_DIR) \
		-quiet
	@echo "✅ Static analysis completed"

format: check-swift-format ## Format Swift code
	@echo "🎨 Formatting Swift code..."
	@if command -v swift-format >/dev/null 2>&1; then \
		find . -name "*.swift" -not -path "./build/*" -not -path "./.build/*" | \
		xargs swift-format -i; \
		echo "✅ Swift code formatted"; \
	else \
		echo "❌ swift-format not found. Install with: brew install swift-format"; \
		exit 1; \
	fi

lint: check-swiftlint ## Lint Swift code
	@echo "🔍 Linting Swift code..."
	@if command -v swiftlint >/dev/null 2>&1; then \
		swiftlint lint; \
		echo "✅ Swift code linted"; \
	else \
		echo "❌ swiftlint not found. Install with: brew install swiftlint"; \
		exit 1; \
	fi

##@ Project Management

setup: deps bootstrap ## Complete project setup

deps: check-deps ## Install development dependencies
	@echo "📦 Installing development dependencies..."
	@if ! command -v brew >/dev/null 2>&1; then \
		echo "❌ Homebrew not found. Please install: https://brew.sh"; \
		exit 1; \
	fi
	@echo "Installing swift-format..."
	@brew list swift-format >/dev/null 2>&1 || brew install swift-format
	@echo "Installing swiftlint..."
	@brew list swiftlint >/dev/null 2>&1 || brew install swiftlint
	@echo "✅ Dependencies installed"

bootstrap: check-tools ## Bootstrap project (resolve packages, prepare build)
	@echo "🔧 Bootstrapping project..."
	$(XCODEBUILD) \
		-resolvePackageDependencies \
		-scheme $(SCHEME)
	@mkdir -p $(BUILD_DIR)
	@echo "✅ Project bootstrapped"

clean: ## Clean build artifacts and derived data
	@echo "🧹 Cleaning build artifacts..."
	rm -rf $(BUILD_DIR)
	rm -rf $(DERIVED_DATA_DIR)
	$(XCODEBUILD) clean \
		-scheme $(SCHEME) \
		-configuration $(CONFIGURATION_DEBUG) \
		-quiet >/dev/null 2>&1 || true
	$(XCODEBUILD) clean \
		-scheme $(SCHEME) \
		-configuration $(CONFIGURATION_RELEASE) \
		-quiet >/dev/null 2>&1 || true
	@echo "✅ Clean completed"

clean-deep: clean ## Deep clean including package cache and derived data
	@echo "🧹 Deep cleaning..."
	rm -rf ~/Library/Developer/Xcode/DerivedData/AltSwitch-*
	rm -rf .build
	@echo "✅ Deep clean completed"

##@ Utility Targets

check-tools: ## Verify required development tools
	@echo "🔧 Checking development tools..."
	@command -v xcodebuild >/dev/null 2>&1 || { echo "❌ xcodebuild not found"; exit 1; }
	@command -v xcrun >/dev/null 2>&1 || { echo "❌ xcrun not found"; exit 1; }
	@echo "✅ Development tools verified"

check-deps: ## Check for optional dependencies
	@echo "🔧 Checking optional dependencies..."
	@if ! command -v brew >/dev/null 2>&1; then \
		echo "⚠️  Homebrew not found (recommended for dependency management)"; \
	fi

check-swift-format: ## Check if swift-format is available
	@command -v swift-format >/dev/null 2>&1 || { echo "⚠️  swift-format not found. Install with: brew install swift-format"; }

check-swiftlint: ## Check if swiftlint is available
	@command -v swiftlint >/dev/null 2>&1 || { echo "⚠️  swiftlint not found. Install with: brew install swiftlint"; }

info: ## Display project information
	@echo "AltSwitch Project Information"
	@echo "============================"
	@echo "Project: $(PROJECT_NAME)"
	@echo "Scheme: $(SCHEME)"
	@echo "Workspace: $(WORKSPACE)"
	@echo "Build Directory: $(BUILD_DIR)"
	@echo ""
	@echo "Configurations:"
	@echo "  Debug: $(CONFIGURATION_DEBUG)"
	@echo "  Release: $(CONFIGURATION_RELEASE)"
	@echo ""
	@echo "Test Targets:"
	@echo "  Unit Tests: $(UNIT_TEST_TARGET)"
	@echo "  UI Tests: $(UI_TEST_TARGET)"
	@echo ""
	@echo "App Bundles:"
	@echo "  Debug: $(DEBUG_APP_PATH)"
	@echo "  Release: $(RELEASE_APP_PATH)"

##@ Quick Development Workflow

dev: clean build-debug test-unit ## Clean, build debug, and run unit tests
	@echo "🚀 Development build and test completed"

ci: clean build-release test-all analyze ## Full CI pipeline (clean, build, test, analyze)
	@echo "🎯 CI pipeline completed successfully"

quick: build-debug run-debug ## Quick build and run for development

release: clean build-release test-all ## Prepare release build with full testing
	@echo "🎉 Release build completed and tested"

##@ Documentation

docs: ## Generate and open documentation
	@echo "📚 This target is reserved for future documentation generation"
	@echo "For now, see:"
	@echo "  - README.md for project overview"
	@echo "  - CHANGELOG.md for version history"
	@echo "  - CLAUDE.md for development guidelines"

# Debug target to show variables
debug-vars: ## Show Makefile variables (for debugging)
	@echo "Debug Variables:"
	@echo "PROJECT_NAME = $(PROJECT_NAME)"
	@echo "SCHEME = $(SCHEME)"
	@echo "WORKSPACE = $(WORKSPACE)"
	@echo "BUILD_DIR = $(BUILD_DIR)"
	@echo "DEBUG_APP_PATH = $(DEBUG_APP_PATH)"
	@echo "RELEASE_APP_PATH = $(RELEASE_APP_PATH)"
