#! /bin/bash

# For catching errors
set -euo pipefail

# Following script is supposed to be run inside the Docker container after building the ONNX Runtime C++ shared library with CUDA 12.8 support.

# ------------------------------------------
# The following section creates a .deb package for the ONNX Runtime C++ shared library with CUDA 12.8 support.
# ------------------------------------------

ONNXRUNTIME_VERSION=1.24.2

cd /onnxruntime/build/Release
mkdir -p /tmp/deb-pkg/usr/local
mkdir -p /tmp/deb-pkg/DEBIAN
cmake --install . --prefix /tmp/deb-pkg/usr/local

cat > /tmp/deb-pkg/DEBIAN/control << EOF
Package: onnxruntime-cuda
Version: ${ONNXRUNTIME_VERSION}
Section: devel
Priority: optional
Architecture: amd64
Description: ONNX Runtime C++ shared library with CUDA 12.8 support. Built using Docker image nvidia/cuda:12.8.1-cudnn-devel-ubuntu20.04.
EOF

# To call `ldconfig` after installation/removal of the package, we can create `postinst` and `postrm` scripts in the DEBIAN directory of the package.
cat > /tmp/deb-pkg/DEBIAN/postinst << 'EOF'
#!/bin/sh
set -e

ldconfig

exit 0
EOF

cat > /tmp/deb-pkg/DEBIAN/postrm << 'EOF'
#!/bin/sh
set -e

case "$1" in
	remove|purge)
		ldconfig
		;;
esac

exit 0
EOF

chmod 755 /tmp/deb-pkg/DEBIAN/postinst /tmp/deb-pkg/DEBIAN/postrm

cat /tmp/deb-pkg/DEBIAN/control

mkdir -p /output
dpkg-deb --build /tmp/deb-pkg /output/onnxruntime-linux-x64-cuda12.8-v${ONNXRUNTIME_VERSION}-more.deb

# To install the generated .deb package on a Debian-based system, use:
# sudo apt-get install ./onnxruntime-linux-x64-cuda12.8-v${ONNXRUNTIME_VERSION}-more.deb
# OR
# sudo dpkg -i onnxruntime-linux-x64-cuda12.8-v1.24.2-more.deb
# sudo apt-get -f install

# To uninstall the package:
# sudo apt-get remove onnxruntime-cuda
