
#
# setup and static libraries
#

set(RA_INCLUDE_DIRS ${CMAKE_CURRENT_SOURCE_DIR} CACHE PATH
	"rathena include directory"
)
mark_as_advanced( RA_INCLUDE_DIRS )



add_subdirectory( common )
if( HAVE_common )
	option( BUILD_SERVERS "build server executables" ON )
else()
	message( STATUS "Disabled server targets (requires common)" )
endif()

# AI Client library (optional, for AI Sidecar integration)
option( BUILD_AI_CLIENT "build AI client library for gRPC integration" ON )
if( BUILD_AI_CLIENT )
	add_subdirectory( ai_client )
endif()


#
# targets
#
add_subdirectory( login )
add_subdirectory( char )
add_subdirectory( map )
add_subdirectory( web )
add_subdirectory( tool )

