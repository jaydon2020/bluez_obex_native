cmake_minimum_required(VERSION 3.10)
project(bluez_obex_native_library VERSION 0.0.1 LANGUAGES C CXX)

set(CMAKE_CXX_STANDARD 23)
set(CMAKE_CXX_EXTENSIONS OFF)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

set(BUILD_SHARED_LIBS OFF CACHE BOOL "" FORCE)
set(SDBUSCPP_BUILD_CODEGEN OFF CACHE BOOL "" FORCE)
set(SDBUSCPP_BUILD_DOCS OFF CACHE BOOL "" FORCE)
set(SDBUSCPP_BUILD_EXAMPLES OFF CACHE BOOL "" FORCE)
set(SDBUSCPP_BUILD_TESTS OFF CACHE BOOL "" FORCE)
set(SDBUSCPP_INSTALL OFF CACHE BOOL "" FORCE)
set(CMAKE_POSITION_INDEPENDENT_CODE ON)
add_subdirectory(third_party/sdbus-cpp EXCLUDE_FROM_ALL)

add_library(bluez_obex_native_core STATIC
  src/bluez_obex_client.cpp
  src/bluez_obex_native.c
  src/dart_api_dl.c
  src/obex_client.cpp
  src/obex_object_manager.cpp
)

target_include_directories(bluez_obex_native_core
  PUBLIC include
)

target_compile_definitions(bluez_obex_native_core
  PUBLIC DART_SHARED_LIB
)

target_link_libraries(bluez_obex_native_core
  PUBLIC sdbus-c++ pthread
)

set_target_properties(bluez_obex_native_core PROPERTIES
  POSITION_INDEPENDENT_CODE ON
  LINKER_LANGUAGE CXX
)

add_library(bluez_obex_native SHARED
  src/bluez_obex_client.cpp
  src/bluez_obex_native.c
  src/dart_api_dl.c
  src/obex_client.cpp
  src/obex_object_manager.cpp
)

target_include_directories(bluez_obex_native
  PRIVATE include
)

target_compile_definitions(bluez_obex_native
  PUBLIC DART_SHARED_LIB
)

target_link_libraries(bluez_obex_native
  PRIVATE sdbus-c++ pthread
)

set_target_properties(bluez_obex_native PROPERTIES
  C_VISIBILITY_PRESET hidden
  CXX_VISIBILITY_PRESET hidden
  VISIBILITY_INLINES_HIDDEN YES
  LINKER_LANGUAGE CXX
  PUBLIC_HEADER include/bluez_obex_native.h
  OUTPUT_NAME "bluez_obex_native"
)

if(UNIX AND NOT APPLE)
  target_link_options(bluez_obex_native PRIVATE "-Wl,--exclude-libs,ALL")
endif()

if(ANDROID)
  # Support Android 15 16k page size.
  target_link_options(bluez_obex_native PRIVATE "-Wl,-z,max-page-size=16384")
endif()

include(CTest)
if(BUILD_TESTING)
  add_subdirectory(test)
endif()
