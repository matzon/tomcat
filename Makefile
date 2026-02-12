# =============================================================================
# Apache Tomcat Containerized Build - Makefile
# =============================================================================
# This Makefile provides a simple interface for building Apache Tomcat using
# Docker containers. It supports local development and testing.
#
# Quick start:
#   make build          - Build Tomcat (output to ./output/build/)
#   make test           - Build Tomcat and run tests
#   make clean          - Clean build artifacts
#   make docker-rebuild - Rebuild Docker images
# =============================================================================

.PHONY: help build test clean docker-rebuild

# Default target
.DEFAULT_GOAL := help

# Enable BuildKit for improved caching and performance
export DOCKER_BUILDKIT=1
export COMPOSE_DOCKER_CLI_BUILD=1

# Note: docker-compose.yml defaults to UID=1000 GID=1000 (typical first user)
# If your host user has a different UID, export UID and GID before running make:
#   export UID=$(id -u) GID=$(id -g) && make build

# Colors for output
GREEN  := \033[0;32m
YELLOW := \033[1;33m
BLUE   := \033[0;34m
NC     := \033[0m # No Color

# =============================================================================
# Main Targets
# =============================================================================

## help: Show this help message
help:
	@echo "$(BLUE)Apache Tomcat Containerized Build$(NC)"
	@echo "===================================="
	@echo ""
	@echo "$(GREEN)Usage:$(NC)"
	@echo "  make build          - Build Tomcat (output to ./output/build/)"
	@echo "  make test           - Build Tomcat and run tests"
	@echo "  make clean          - Clean build artifacts"
	@echo "  make docker-rebuild - Rebuild Docker images (use after Dockerfile changes)"
	@echo ""
	@echo "$(GREEN)Output Locations:$(NC)"
	@echo "  Build artifacts:    ./output/build/"
	@echo "  Test results:       ./output/build/logs/"

## build: Build Tomcat (using docker compose with volume mount)
build:
	@echo "$(GREEN)[INFO]$(NC) Building Tomcat (output to ./output/build/)"
	@docker compose run --rm tomcat-build
	@echo "$(GREEN)[SUCCESS]$(NC) Build complete! Artifacts in ./output/build/"
	@echo ""
	@echo "To run the built Tomcat:"
	@echo "  ./output/build/bin/catalina.sh run"

## test: Build Tomcat and run tests (auto-detects physical CPU cores for parallelization)
test:
	@NPROC=$$(grep '^core id' /proc/cpuinfo 2>/dev/null | sort -u | wc -l || sysctl -n hw.physicalcpu 2>/dev/null || echo 2); \
	echo "$(GREEN)[INFO]$(NC) Building Tomcat and running tests ($$NPROC parallel threads)"; \
	docker compose run --rm -e TEST_THREADS=$$NPROC tomcat-test
	@echo "$(GREEN)[SUCCESS]$(NC) Tests complete! Results in ./output/build/logs/"
	@echo ""
	@echo "To view test results:"
	@echo "  ls -la ./output/build/logs/"

## clean: Clean build artifacts
clean:
	@echo "$(GREEN)[INFO]$(NC) Cleaning build artifacts"
	@if [ -d output ] && [ ! -w output ]; then \
		echo "$(YELLOW)[WARN]$(NC) output/ directory is not writable (owned by root?)"; \
		echo "$(YELLOW)[WARN]$(NC) Attempting to fix with sudo..."; \
		sudo rm -rf output/ || { echo "$(RED)[ERROR]$(NC) Failed to remove output/. Run: sudo rm -rf output/"; exit 1; }; \
	else \
		rm -rf output/; \
	fi
	@echo "$(GREEN)[SUCCESS]$(NC) Clean complete!"


## docker-rebuild: Rebuild Docker images (use after Dockerfile changes)
docker-rebuild:
	@echo "$(GREEN)[INFO]$(NC) Rebuilding Docker images"
	@docker compose build --no-cache
	@echo "$(GREEN)[SUCCESS]$(NC) Docker images rebuilt!"
