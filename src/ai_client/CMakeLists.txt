#
# AI Client Library - gRPC client for AI Sidecar integration
#

message( STATUS "Configuring AI Client library" )

# Find required packages
find_package(Protobuf REQUIRED)
find_package(gRPC CONFIG)

# Check if gRPC was found
if(NOT gRPC_FOUND)
    message(STATUS "gRPC not found via CONFIG, trying PkgConfig...")
    find_package(PkgConfig REQUIRED)
    pkg_check_modules(GRPC REQUIRED grpc++)
    if(GRPC_FOUND)
        message(STATUS "Found gRPC via PkgConfig")
        set(gRPC_FOUND TRUE)
    else()
        message(FATAL_ERROR "gRPC not found. Please install gRPC and protobuf:\n"
                           "  Ubuntu/Debian: sudo apt-get install libgrpc++-dev libprotobuf-dev protobuf-compiler-grpc\n"
                           "  Or build from source: https://grpc.io/docs/languages/cpp/quickstart/")
    endif()
endif()

# Find grpc_cpp_plugin
find_program(GRPC_CPP_PLUGIN grpc_cpp_plugin)
if(NOT GRPC_CPP_PLUGIN)
    message(FATAL_ERROR "grpc_cpp_plugin not found")
endif()

# Proto file paths
set(PROTO_DIR "${CMAKE_CURRENT_SOURCE_DIR}/protos")
set(GENERATED_DIR "${CMAKE_CURRENT_SOURCE_DIR}/generated")
set(PROTO_FILE "${PROTO_DIR}/ai_service.proto")

# Create generated directory
file(MAKE_DIRECTORY ${GENERATED_DIR})

# Generated files
set(PROTO_SRCS "${GENERATED_DIR}/ai_service.pb.cc")
set(PROTO_HDRS "${GENERATED_DIR}/ai_service.pb.h")
set(GRPC_SRCS "${GENERATED_DIR}/ai_service.grpc.pb.cc")
set(GRPC_HDRS "${GENERATED_DIR}/ai_service.grpc.pb.h")

# Custom command to generate C++ code from proto file
add_custom_command(
    OUTPUT ${PROTO_SRCS} ${PROTO_HDRS} ${GRPC_SRCS} ${GRPC_HDRS}
    COMMAND ${Protobuf_PROTOC_EXECUTABLE}
    ARGS --cpp_out=${GENERATED_DIR}
         --grpc_out=${GENERATED_DIR}
         --plugin=protoc-gen-grpc=${GRPC_CPP_PLUGIN}
         -I=${PROTO_DIR}
         ${PROTO_FILE}
    DEPENDS ${PROTO_FILE}
    COMMENT "Generating C++ code from ${PROTO_FILE}"
    VERBATIM
)

# AI Client source files
set( AI_CLIENT_SOURCES
    ai_client.cpp
    ${PROTO_SRCS}
    ${GRPC_SRCS}
)

set( AI_CLIENT_HEADERS
    ai_client.hpp
    ${PROTO_HDRS}
    ${GRPC_HDRS}
)

# Create AI Client static library
add_library( ai_client STATIC ${AI_CLIENT_SOURCES} ${AI_CLIENT_HEADERS} )

# Include directories
target_include_directories( ai_client PUBLIC
    ${CMAKE_CURRENT_SOURCE_DIR}
    ${GENERATED_DIR}
    ${Protobuf_INCLUDE_DIRS}
    ${GRPC_INCLUDE_DIRS}
)

# Link libraries
if(TARGET gRPC::grpc++)
    # Modern CMake target
    target_link_libraries( ai_client PUBLIC
        gRPC::grpc++
        protobuf::libprotobuf
    )
else()
    # Fallback for older CMake or PkgConfig
    target_link_libraries( ai_client PUBLIC
        ${GRPC_LIBRARIES}
        ${Protobuf_LIBRARIES}
    )
endif()

# Set compile features
target_compile_features( ai_client PUBLIC cxx_std_17 )

# Add definitions
target_compile_definitions( ai_client PRIVATE
    ${GLOBAL_DEFINITIONS}
)

# Set output name
set_target_properties( ai_client PROPERTIES
    OUTPUT_NAME "ai_client"
    POSITION_INDEPENDENT_CODE ON
)

# Install rules (optional)
if( INSTALL_COMPONENT_DEVELOPMENT )
    install( TARGETS ai_client
        DESTINATION "lib"
        COMPONENT Development_base )
    install( FILES ${AI_CLIENT_HEADERS}
        DESTINATION "include/ai_client"
        COMPONENT Development_base )
endif()

message( STATUS "AI Client library configured successfully" )
message( STATUS "  Proto file: ${PROTO_FILE}" )
message( STATUS "  Generated dir: ${GENERATED_DIR}" )
message( STATUS "  gRPC plugin: ${GRPC_CPP_PLUGIN}" )

# Test client executable (optional)
option( BUILD_AI_TEST_CLIENT "build AI client test executable" ON )
if( BUILD_AI_TEST_CLIENT )
    add_executable( test_ai_client test_client.cpp )
    target_link_libraries( test_ai_client ai_client )
    target_include_directories( test_ai_client PRIVATE ${CMAKE_CURRENT_SOURCE_DIR} )
    
    if( INSTALL_COMPONENT_DEVELOPMENT )
        install( TARGETS test_ai_client
            DESTINATION "."
            COMPONENT Development_base )
    endif()
    
    message( STATUS "AI Client test program configured" )
endif()

# Export for use by other targets
set( HAVE_AI_CLIENT ON  CACHE BOOL "AI Client library is available" )
mark_as_advanced( HAVE_AI_CLIENT )
