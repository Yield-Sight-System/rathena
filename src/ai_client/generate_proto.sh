#!/bin/bash
# Generate C++ code from Protocol Buffers definition
# This script generates both the protobuf and gRPC C++ code

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROTO_DIR="${SCRIPT_DIR}/protos"
GENERATED_DIR="${SCRIPT_DIR}/generated"
PROTO_FILE="ai_service.proto"

echo "Generating C++ code from ${PROTO_FILE}..."

# Create generated directory if it doesn't exist
mkdir -p "${GENERATED_DIR}"

# Check if protoc is available
if ! command -v protoc &> /dev/null; then
    echo "ERROR: protoc (Protocol Buffers compiler) not found"
    echo "Please install protobuf-compiler:"
    echo "  Ubuntu/Debian: sudo apt-get install protobuf-compiler libprotobuf-dev"
    echo "  Fedora/RHEL: sudo dnf install protobuf-compiler protobuf-devel"
    echo "  Arch: sudo pacman -S protobuf"
    exit 1
fi

# Check if grpc_cpp_plugin is available
if ! command -v grpc_cpp_plugin &> /dev/null; then
    echo "ERROR: grpc_cpp_plugin not found"
    echo "Please install gRPC C++ plugin:"
    echo "  Ubuntu/Debian: sudo apt-get install libgrpc++-dev protobuf-compiler-grpc"
    echo "  Or build from source: https://grpc.io/docs/languages/cpp/quickstart/"
    exit 1
fi

# Get the gRPC plugin path
GRPC_CPP_PLUGIN=$(which grpc_cpp_plugin)

# Generate C++ protobuf code
echo "Generating protobuf C++ code..."
protoc --cpp_out="${GENERATED_DIR}" \
       -I="${PROTO_DIR}" \
       "${PROTO_DIR}/${PROTO_FILE}"

# Generate gRPC C++ code
echo "Generating gRPC C++ code..."
protoc --grpc_out="${GENERATED_DIR}" \
       --plugin=protoc-gen-grpc="${GRPC_CPP_PLUGIN}" \
       -I="${PROTO_DIR}" \
       "${PROTO_DIR}/${PROTO_FILE}"

echo "Generated files:"
ls -lh "${GENERATED_DIR}"

echo ""
echo "Code generation complete!"
echo "Generated files are in: ${GENERATED_DIR}"
