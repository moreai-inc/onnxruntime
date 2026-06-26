# Take Image Name from Build Command
# Accommodate for Build Architecture
# For Example:
#   amd64: nvidia/cuda:12.9.2-devel-ubuntu22.04 <--- Default
#   arm64: nvcr.io/nvidia/l4t-base:r36.2.0

ARG BASE_IMG=nvidia/cuda:12.9.2-cudnn-devel-ubuntu20.04
FROM ${BASE_IMG}
ARG BUILDARCH
ARG ONNXRUNTIME_VERSION=1.24.2

# necessary to prevent interactivity in apt commands
ARG DEBIAN_FRONTEND=noninteractive

USER root

# Setup build context pre-reqs
RUN set -ex;                        \
    apt-get update;                 \
    apt-get install -y              \
        libgl1-mesa-dev             \
        libusb-1.0-0-dev;           \
    rm -rf /var/lib/apt/lists/*;

# ONNX Install: The following 4 steps are required prior to installing ONNX:
#  - Install pre-requisites for Python 3.10
#  - Install Python 3.10 (by building from source)
#  - Compiling and installing binutils
#  - Installing psutils (for multi-threaded build)
# These libraries are required to compile Python 3.10 and binutils 2.40
RUN apt-get update && apt-get install -y \
    build-essential \
    libssl-dev \
    zlib1g-dev \
    libncurses5-dev \
    libncursesw5-dev \
    libreadline-dev \
    libsqlite3-dev \
    libgdbm-dev \
    libdb5.3-dev \
    libbz2-dev \
    libexpat1-dev \
    liblzma-dev \
    libffi-dev \
    uuid-dev \
    texinfo bison flex libgmp-dev libmpfr-dev libmpc-dev \
    && rm -rf /var/lib/apt/lists/*

RUN apt-get update && apt-get install -y \
    git \
    wget \
    curl \
    gpg \
    lsb-release \
    ninja-build \
    python3-pip \
    libcurl4-openssl-dev \
    && rm -rf /var/lib/apt/lists/*

# Install cmake
RUN set -ex;                                                                                              \
    curl -fsSL  'https://apt.kitware.com/keys/kitware-archive-latest.asc' |                               \
    gpg --dearmor - | tee /usr/share/keyrings/kitware-archive-keyring.gpg;                                \
    sh -c 'echo "deb [signed-by=/usr/share/keyrings/kitware-archive-keyring.gpg]                          \
      https://apt.kitware.com/ubuntu/ $(lsb_release -sc) main" >                                          \
      /etc/apt/sources.list.d/kitware.list';                                                              \
    apt-get update -y;                                                                                    \
    rm /usr/share/keyrings/kitware-archive-keyring.gpg;                                                   \
    apt-get install -y kitware-archive-keyring;                                                           \
    apt-get install -y cmake="3.31.7-0kitware1ubuntu*" cmake-data="3.31.7-0kitware1ubuntu*";              \
    cmake --version

# Update GCC only if the system version is older than 13
RUN set -ex; \
    apt-get update && apt-get install -y software-properties-common; \
    # Get the version of the default gcc package available in repos
    SYS_GCC_VER=$(apt-cache policy gcc | grep Candidate | awk '{print $2}' | cut -d: -f2 | cut -d. -f1); SYS_GCC_VER=${SYS_GCC_VER:-0}; \
    if [ "$SYS_GCC_VER" -lt 13 ]; then \
        echo "System GCC is version $SYS_GCC_VER. Upgrading to GCC 13 via PPA..."; \
        add-apt-repository -y ppa:ubuntu-toolchain-r/test; \
        apt-get update; \
        apt-get install -y gcc-13 g++-13; \
        update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-13 13;                                \
        update-alternatives --set gcc /usr/bin/gcc-13; \
        update-alternatives --install /usr/bin/g++ g++ /usr/bin/g++-13 13;                                \
        update-alternatives --set g++ /usr/bin/g++-13; \
    else \
        echo "System GCC is already version $SYS_GCC_VER or newer. Skipping PPA."; \
        apt-get install -y gcc g++; \
    fi

# Build Python 3.10 from source only on Ubuntu 20.04 (later versions have it in their repos)
# --enable-optimizations makes the build slower but the resulting Python 10-20% faster
# 'altinstall' installs as 'python3.10', not overwriting the system 'python3'
RUN . /etc/os-release && \
    if [ "$VERSION_ID" = "20.04" ]; then \
        echo "Ubuntu 20.04 detected! Building specific components..." && \
        cd /tmp && \
        wget --progress=dot:mega https://www.python.org/ftp/python/3.10.13/Python-3.10.13.tgz && \
        tar -xzf Python-3.10.13.tgz && \
        cd Python-3.10.13 && \
        ./configure --quiet --enable-optimizations && \
        make -s -j$(nproc) && \
        make -s altinstall > /dev/null && \
        cd /tmp && \
        rm -rf Python-3.10.13 Python-3.10.13.tgz && \
        python3.10 --version; \
    else \
        echo "Non-Ubuntu 20.04 detected! Skipping Python build..." && \
        python3 --version || true; \
    fi

# Update binutils to 2.40 (Required for building ONNX Runtime),
# ... for both Ubuntu 20.04 and 22.04, as the default binutils versions (2.34 and 2.38 respectively) are too old to compile ONNX Runtime v1.24.2
RUN cd /tmp && \
    wget --progress=dot:mega https://ftp.gnu.org/gnu/binutils/binutils-2.40.tar.bz2 && \
    tar -xjf binutils-2.40.tar.bz2 && cd binutils-2.40 && \
    ./configure --quiet --prefix=/opt/binutils-2.40 --disable-werror && \
    make -s -j$(nproc) && make -s install > /dev/null && \
    rm -rf /tmp/binutils*

RUN . /etc/os-release && \
    if [ "$VERSION_ID" = "20.04" ]; then PYTHON=python3.10; else PYTHON=python3; fi && \
    $PYTHON -m pip install psutil

RUN apt-get update && apt-get install -y \
    dpkg-dev \
    unzip \
    && rm -rf /var/lib/apt/lists/*

# Override CCCL headers and cmake configs to fix CCCL_PP_SPLICE_WITH bug (NVIDIA/cccl#4972)
# affecting nvcc -arch=all builds with CUDA 12.9.x
# Uses the *installation* archive (headers + CMake configs), NOT the source tree, so that both
# nvcc AND find_package(CCCL) report the new version. Portable to x86_64 and aarch64.
ENV CCCL_VERSION=3.3.3
RUN set -ex; \
    wget --progress=dot:mega -O /tmp/cccl.zip "https://github.com/NVIDIA/cccl/releases/download/v${CCCL_VERSION}/cccl-v${CCCL_VERSION}.zip"; \
    unzip -q /tmp/cccl.zip -d /tmp/cccl; \
    rm -rf /usr/local/cuda/include/thrust \
           /usr/local/cuda/include/cub \
           /usr/local/cuda/include/cuda \
           /usr/local/cuda/include/nv; \
    cp -r /tmp/cccl/cccl-v${CCCL_VERSION}/include/thrust /usr/local/cuda/include/; \
    cp -r /tmp/cccl/cccl-v${CCCL_VERSION}/include/cub    /usr/local/cuda/include/; \
    cp -r /tmp/cccl/cccl-v${CCCL_VERSION}/include/cuda   /usr/local/cuda/include/; \
    cp -r /tmp/cccl/cccl-v${CCCL_VERSION}/include/nv     /usr/local/cuda/include/; \
    rm -rf /usr/local/cuda/lib64/cmake/cccl \
           /usr/local/cuda/lib64/cmake/cub \
           /usr/local/cuda/lib64/cmake/libcudacxx \
           /usr/local/cuda/lib64/cmake/thrust; \
    cp -r /tmp/cccl/cccl-v${CCCL_VERSION}/lib/cmake/cccl       /usr/local/cuda/lib64/cmake/; \
    cp -r /tmp/cccl/cccl-v${CCCL_VERSION}/lib/cmake/cub        /usr/local/cuda/lib64/cmake/; \
    cp -r /tmp/cccl/cccl-v${CCCL_VERSION}/lib/cmake/libcudacxx /usr/local/cuda/lib64/cmake/; \
    cp -r /tmp/cccl/cccl-v${CCCL_VERSION}/lib/cmake/thrust     /usr/local/cuda/lib64/cmake/; \
    rm -rf /tmp/cccl.zip /tmp/cccl;

# Build ONNX Runtime from source with CUDA support for Blackwell architecture (50-series or SM 12.0)
# IMPORTANT: SM_101 is for Jetson Thor, in Cuda 12.8. But it was later changed to SM_110 in Cuda 13.0
ENV CUDA_ARCHS="50-real;\
52-real;\
53-real;\
60-real;\
61-real;\
62-real;\
70-real;\
72-real;\
75-real;\
80-real;\
86-real;\
87-real;\
89-real;\
90-real;\
100-real;\
101-real;\
120-real;\
120-virtual"
# ENV CUDA_ARCHS="120-real"

# Copy local fork into the image
COPY . /onnxruntime

RUN . /etc/os-release && \
    if [ "$VERSION_ID" = "20.04" ]; then PYTHON=python3.10; else PYTHON=python3; fi && \
    cd /onnxruntime && \
    $PYTHON /onnxruntime/tools/ci_build/build.py \
    --build_dir build \
    --config Release \
    --build_shared_lib \
    --enable_lto \
    --parallel 8 \
    --skip_tests \
    --skip_submodule_sync \
    --use_cuda \
    --cuda_version 12.9 \
    --cuda_home /usr/local/cuda \
    --cudnn_home /usr/local/cuda \
    --cmake_extra_defines \
        "CMAKE_DISABLE_FIND_PACKAGE_flatbuffers=ON" \
        "CMAKE_DISABLE_FIND_PACKAGE_Flatbuffers=ON" \
        "CMAKE_CUDA_ARCHITECTURES=${CUDA_ARCHS}" \
        "onnxruntime_USE_FPA_INTB_GEMM=OFF" \
        "CMAKE_AR=/opt/binutils-2.40/bin/ar" \
        "CMAKE_RANLIB=/opt/binutils-2.40/bin/ranlib" \
        "CMAKE_LINKER=/opt/binutils-2.40/bin/ld" \
        "CMAKE_NM=/opt/binutils-2.40/bin/nm" \
        "CMAKE_OBJCOPY=/opt/binutils-2.40/bin/objcopy" \
        "CMAKE_OBJDUMP=/opt/binutils-2.40/bin/objdump" \
        "CMAKE_STRIP=/opt/binutils-2.40/bin/strip" \
        "CMAKE_C_FLAGS=-B/opt/binutils-2.40/bin/" \
        "CMAKE_CXX_FLAGS=-B/opt/binutils-2.40/bin/" \
        "CMAKE_ASM_FLAGS=-B/opt/binutils-2.40/bin/" \
        "CMAKE_CUDA_FLAGS=-Xcompiler -B/opt/binutils-2.40/bin/" \
    --allow_running_as_root

# ============================================================================
# NEW LAYER: Create .deb package via CPack (preserves build layers above)
# ============================================================================

RUN mkdir -p /deb-output && \
    cd /onnxruntime/build/Release && \
    cpack -G DEB && \
    mv *.deb /deb-output/ && \
    ls -lh /deb-output/*.deb
