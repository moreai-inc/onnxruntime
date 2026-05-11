#! /bin/bash

# Following script is supposed to be run inside the Docker container after building the ONNX Runtime C++ shared library with CUDA 12.8 support.

# ------------------------------------------
# This script packages ONNX Runtime C++ shared library built with CUDA 12.8 support
# into a .tar.gz file.
# ------------------------------------------

cd /onnxruntime/build/Release
mkdir -p /tmp/onnxruntime-pkg
cmake --install . --prefix /tmp/onnxruntime-pkg
mkdir -p /output
cd /tmp/onnxruntime-pkg
tar -czvf /output/onnxruntime-linux-x64-cuda12.8-v${ONNXRUNTIME_VERSION}.tar.gz .
