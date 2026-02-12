# syntax=docker/dockerfile:1

# =============================================================================
# Apache Tomcat Containerized Build with BuildKit Caching
# =============================================================================
# This Dockerfile provides a reproducible build environment for Apache Tomcat.
# It matches the CI environment (Java 21, ubuntu-latest, Ant 1.10.2+) and
# supports both quick builds and full test runs.
#
# Requirements:
#   - Docker with BuildKit enabled (Docker 18.09+)
#   - Set DOCKER_BUILDKIT=1 environment variable (or use docker buildx)
# =============================================================================

# =============================================================================
# Stage 1: Builder Base - Install build tools
# =============================================================================
# Use ubuntu-latest to match CI environment (GitHub Actions uses ubuntu-latest + Zulu JDK)
FROM ubuntu:latest AS builder-base

# Set locale to match CI environment
ENV LC_ALL=en_US.UTF-8
ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US:en

# Install Apache Ant (matching CI requirements - 1.10.2+)
ENV ANT_VERSION=1.10.15
ENV ANT_HOME=/opt/ant
ENV JAVA_HOME=/usr/lib/jvm/zulu21

# Use BuildKit cache mounts for apt cache to speed up package installation
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt-get update && \
    apt-get install -y --no-install-recommends \
        wget \
        ca-certificates \
        gnupg \
        software-properties-common && \
    # Add Azul Zulu repository and install JDK 21 (matching GitHub Actions with distribution: zulu)
    wget -qO - https://repos.azul.com/azul-repo.key | gpg --dearmor -o /usr/share/keyrings/azul.gpg && \
    echo "deb [signed-by=/usr/share/keyrings/azul.gpg] https://repos.azul.com/zulu/deb stable main" > /etc/apt/sources.list.d/zulu.list && \
    apt-get update && \
    apt-get install -y --no-install-recommends zulu21-jdk && \
    # Install Apache Ant
    mkdir -p ${ANT_HOME} && \
    wget -q https://archive.apache.org/dist/ant/binaries/apache-ant-${ANT_VERSION}-bin.tar.gz && \
    tar -xzf apache-ant-${ANT_VERSION}-bin.tar.gz -C ${ANT_HOME} --strip-components=1 && \
    rm apache-ant-${ANT_VERSION}-bin.tar.gz

ENV PATH="${JAVA_HOME}/bin:${ANT_HOME}/bin:${PATH}"

# Verify installation
RUN java -version && ant -version

# Create directory structure and set permissions for UID 1000
WORKDIR /workspace
RUN mkdir -p /workspace/tomcat-build-libs && \
    chown -R 1000:1000 /workspace

# Run as non-root user (UID 1000 matches typical host user)
USER 1000

# Set HOME so ${user.home} resolves correctly in build.properties
ENV HOME=/workspace

# =============================================================================
# Stage 2: Dependency Downloader - Pre-download and cache all dependencies
# =============================================================================
FROM builder-base AS dependency-cache

# Copy only dependency-related files for better layer caching
COPY --chown=1000:1000 build.properties.default ./
COPY --chown=1000:1000 build.xml ./
COPY --chown=1000:1000 res/ ./res/

# Download all dependencies using BuildKit cache mount
# Note: Uses build.properties.default with base.path=${user.home}/tomcat-build-libs
# The cache persists across builds, dramatically speeding up subsequent builds
# The sharing=locked mode allows concurrent builds to share the cache safely
RUN --mount=type=cache,target=/workspace/tomcat-build-libs,uid=1000,gid=1000,sharing=locked \
    ant -noinput download-dist || true

# =============================================================================
# Stage 3: Builder - Full build environment
# =============================================================================
FROM dependency-cache AS builder

# Copy remaining source files
COPY --chown=1000:1000 . .

# Default command: build only (no tests)
# Note: docker-compose.yml overrides this with specific commands for each service
CMD ["ant", "-noinput", "deploy"]
