## Readme

`Dockerfile` is used to build `onnxruntime`. \
The compiled files are at `/onnxruntime/build/Release`. \
Dockerfile is built Docker image `nvidia/cuda:12.8.1-cudnn-devel-ubuntu20.04` \
Use script `create_deb_package.sh` from inside the Docker container to create the debian pacakge.

### TODO:
Streamline above process.
