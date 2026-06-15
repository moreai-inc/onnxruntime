#! /bin/bash

# -------------------------------------------
# This script removes the ONNX Runtime C++ shared library and related files from the system.
# Use this to remove Onnx runtime from a Docker image (if needed)
# -------------------------------------------

sudo rm -f /usr/local/lib/libonnxruntime*.so*
sudo rm -rf /usr/local/include/onnxruntime
sudo rm -rf /usr/local/lib/cmake/onnxruntime
sudo rm -f /usr/local/bin/onnx*
sudo rm -f /usr/local/lib/pkgconfig/libonnxruntime.pc

sudo ldconfig

# Confirm that the ONNX Runtime C++ shared library and related files have been removed
find /usr/local -type f -name "*onnxruntime*"
find /usr/local -type d -name "*onnxruntime*"
