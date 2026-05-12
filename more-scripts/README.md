# Readme

### TL;DR

1. Specify `ONNXRUNTIME_VERSION` in the script `run_build_script.sh`
2. Run the scirpt `run_build_script.sh`
3. After 3 hours, get a `.deb` package in `more-scripts/onnxruntime-build-output`
4. Profit!

### Details

Use script `run_build_script.sh` to create a `.deb` package of Onnx runtime. \
The script builds it inside Docker container (present in this folder), then creates the `.deb` package and copies it to `./onnxruntime-build-output`.

Naming convention for the `.deb` package: \
`onnxruntime-linux-x64-cuda12.8-v${ONNXRUNTIME_VERSION}-more.deb` \
e.g. `onnxruntime-linux-x64-cuda12.8-v1.24.2-more.deb`

Current `Dockerfile` is built on Docker image: `nvidia/cuda:12.8.1-cudnn-devel-ubuntu20.04`

### Extras

In `more-scripts/experimental-scripts`, there are some experimentals scripts, used for the trial and error development e.g. on how to remove the previous installation of onnxruntime from the moresight Docker images, and verify its removal.

But they are not needed for the production version. The script `run_build_script.sh` is sufficient for building it.

### Tips:

If you want to experiment with Onnx builds, you can speed up the build process by compiling for just one (or very few) Cuda compute architechtures (e.g. `ENV CUDA_ARCHS="120-real"`), and disabling `--enable_lto` by comenting it out.
