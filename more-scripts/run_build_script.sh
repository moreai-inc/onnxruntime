#!/bin/bash

# Build ONNX Runtime Docker image and generate .deb package

set -euo pipefail

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
ONNXRUNTIME_VERSION=$(grep -oP 'set\(VERSION_NUMBER\s+"\K[^"]+' "${REPO_ROOT}/cmake/version_number.cmake")
# OUTPUT_DIR is computed after argument parsing so that --version is reflected in the path
OUTPUT_DIR=""
BUILD_TS="$(date +%Y%m%d-%H%M%S)"
DOCKERFILE_PATH="${SCRIPT_DIR}/Dockerfile"

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --version)
            ONNXRUNTIME_VERSION="$2"
            shift 2
            ;;
        --output-dir)
            OUTPUT_DIR="$2"
            shift 2
            ;;
        --help|-h)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --version VERSION        ONNX Runtime version to build (default: from cmake/version_number.cmake)"
            echo "  --output-dir PATH        Output directory for .deb package (default: more-scripts/onnxruntime-build-output/<version>/<timestamp>)"
            echo "  --help                   Show this help message"
            echo ""
            echo "Examples:"
            echo "  $0"
            echo "  $0 --version 1.25.0 --output-dir /tmp/build-output"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Run '$0 --help' for usage information"
            exit 1
            ;;
    esac
done

# Default output dir (computed here so --version is reflected in the path).
# Anchored to more-scripts/ so it matches the .dockerignore exclusion and stays
# out of the Docker build context regardless of the current working directory.
OUTPUT_DIR="${OUTPUT_DIR:-${SCRIPT_DIR}/onnxruntime-build-output/${ONNXRUNTIME_VERSION}/${BUILD_TS}}"

# Validate Dockerfile exists
if [ ! -f "$DOCKERFILE_PATH" ]; then
    echo "Error: Dockerfile not found at $DOCKERFILE_PATH"
    exit 1
fi

# Create output directory
echo "Creating output directory: $OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR"
OUTPUT_DIR_ABS="$(cd "$OUTPUT_DIR" && pwd)"

# Set up logging
LOG_FILE="${OUTPUT_DIR_ABS}/build.log"

# Print build configuration
echo ""
echo "=========================================="
echo "ONNX Runtime Docker Build Configuration"
echo "=========================================="
echo "Version:            $ONNXRUNTIME_VERSION"
echo "Dockerfile:         $DOCKERFILE_PATH"
echo "Output directory:   $OUTPUT_DIR_ABS"
echo "Log file:           $LOG_FILE"
echo "=========================================="
echo ""

# Ensure submodules are initialized before copying into Docker image
echo "Initializing git submodules..."
git -C "$REPO_ROOT" submodule update --init --recursive

# Build Docker image with logging
echo "Building Docker image with ONNX Runtime v${ONNXRUNTIME_VERSION}..."
echo "Log output: $LOG_FILE"
echo ""

# Generate unique image tag based on version (Docker tags don't allow '+')
IMAGE_TAG="onnxruntime:v${ONNXRUNTIME_VERSION//+/-}"
echo "Using Docker image tag: $IMAGE_TAG"

# Enable BuildKit so the ccache --mount=type=cache in the Dockerfile works
export DOCKER_BUILDKIT=1

docker build \
    --build-arg ONNXRUNTIME_VERSION="${ONNXRUNTIME_VERSION}" \
    --progress=plain \
    -t "$IMAGE_TAG" \
    -f "$DOCKERFILE_PATH" \
    "$REPO_ROOT" 2>&1 | tee "$LOG_FILE"

BUILD_STATUS=${PIPESTATUS[0]}

echo ""
echo "=========================================="
if [ $BUILD_STATUS -eq 0 ]; then
    echo "Build completed successfully!"
    echo "Extracting .deb package from container..."
    echo "=========================================="
    echo ""

    # Run container to copy .deb file to mounted volume
    docker run --rm \
        -v "${OUTPUT_DIR_ABS}:/output" \
        "$IMAGE_TAG" \
        sh -c "cp /deb-output/*.deb /output/ && chown $(id -u):$(id -g) /output/*.deb && ls -lh /output/*.deb"

    EXTRACT_STATUS=$?
    if [ $EXTRACT_STATUS -ne 0 ]; then
        echo "Warning: Failed to extract .deb file from container"
        exit 1
    fi

else
    echo "Build failed with status code: $BUILD_STATUS"
    echo "Check log file for details: $LOG_FILE"
    exit $BUILD_STATUS
fi
echo "=========================================="
echo ""

# Check for generated .deb package
if ls "$OUTPUT_DIR_ABS"/*.deb 1> /dev/null 2>&1; then
    echo "Generated .deb package(s):"
    ls -lh "$OUTPUT_DIR_ABS"/*.deb
    echo ""
    # echo "To install the package on a Debian-based system:"
    # echo "  sudo apt-get install ./$(basename $(ls -t $OUTPUT_DIR_ABS/*.deb | head -1))"
else
    echo "Warning: No .deb package found in $OUTPUT_DIR_ABS"
    exit 1
fi
