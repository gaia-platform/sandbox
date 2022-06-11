###################################################
# Copyright (c) Gaia Platform Authors
#
# Use of this source code is governed by the MIT
# license that can be found in the LICENSE.txt file
# or at https://opensource.org/licenses/MIT.
###################################################

cmake_minimum_required(VERSION 3.16)

# Set the project name.
project(coordinator)

set(CMAKE_CXX_STANDARD 17)

# We need pthreads support.
set(CMAKE_THREAD_PREFER_PTHREAD TRUE)
set(THREADS_PREFER_PTHREAD_FLAG TRUE)
find_package(Threads REQUIRED)

# Default compiler/linker flags.
add_compile_options(-c -Wall -Wextra)

# Debug build-specific options.
if(CMAKE_BUILD_TYPE STREQUAL "Debug")
  add_compile_options(-O0 -g3 -ggdb -fno-limit-debug-info -fno-omit-frame-pointer -fno-optimize-sibling-calls -ggnu-pubnames -gsplit-dwarf)
  if(SANITIZER STREQUAL "ASAN")
    add_compile_options(-fsanitize=address -fsanitize=undefined -fno-sanitize-recover=all)
    add_link_options(-fsanitize=address -fsanitize=undefined -fno-sanitize-recover=all)
  endif()
else()
  add_compile_options(-O3)
endif()

include("/opt/gaia/cmake/gaia.cmake")
set(COORDINATOR_DDL ${PROJECT_SOURCE_DIR}/src/coordinator.ddl)
set(COORDINATOR_RULESET ${PROJECT_SOURCE_DIR}/src/coordinator.ruleset)

# --- Generate EDC from DDL---
process_schema(
  DDL_FILE ${COORDINATOR_DDL}
  DATABASE_NAME coordinator
)

# -- Translate ruleset into CPP --
translate_ruleset(
  RULESET_FILE ${COORDINATOR_RULESET}
  DATABASE_NAME coordinator
  CLANG_PARAMS
    -I ${PROJECT_SOURCE_DIR}/include)

add_executable(coordinator
  src/coordinator.cpp
  src/utils.cpp
)

find_package(aws-crt-cpp REQUIRED)

target_add_gaia_generated_sources(coordinator)
add_dependencies(coordinator translate_coordinator_ruleset)
target_include_directories(coordinator
  PUBLIC
    ${PROJECT_SOURCE_DIR}/include
  PRIVATE
    ${GAIA_INC}
)
target_link_directories(coordinator PRIVATE ${GAIA_LIB_DIR})
target_link_libraries(coordinator PRIVATE AWS::aws-crt-cpp gaia rt Threads::Threads)
