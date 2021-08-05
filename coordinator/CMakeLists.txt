#############################################
# Copyright (c) Gaia Platform LLC
# All rights reserved.
#############################################

cmake_minimum_required(VERSION 3.16)

# Set the project name.
project(coordinator CXX)

set(CMAKE_CXX_STANDARD 17)
set(GAIA_COMPILE_FLAGS "-c -Wall -Wextra -ggdb")
set(GAIA_LINK_FLAGS "-ggdb -pthread")

# Enable AddressSanitizer in debug mode.
if(ENABLE_ASAN AND (CMAKE_BUILD_TYPE STREQUAL "Debug"))
  set(GAIA_COMPILE_FLAGS "${GAIA_COMPILE_FLAGS} -fsanitize=address -fno-omit-frame-pointer")
  set(GAIA_LINK_FLAGS "${GAIA_LINK_FLAGS} -fsanitize=address")
endif()

include("/opt/gaia/cmake/gaia.cmake")
set(GAIA_INC "/opt/gaia/include")
set(GAIA_LIB "/usr/local/lib/libgaia.so")
set(COORDINATOR_DDL ${PROJECT_SOURCE_DIR}/src/coordinator.ddl)
set(COORDINATOR_RULESET ${PROJECT_SOURCE_DIR}/src/coordinator.ruleset)

# --- Generate EDC from DDL---
process_schema(
  DDL_FILE ${COORDINATOR_DDL}
  OUTPUT_FOLDER ${PROJECT_BINARY_DIR})

# -- Translate ruleset into CPP --
translate_ruleset(
  RULESET_FILE ${COORDINATOR_RULESET}
  OUTPUT_FOLDER ${PROJECT_BINARY_DIR}
  CLANG_PARAMS
    -I ${PROJECT_SOURCE_DIR}/include
    -I ${GENERATED_OUTPUTS}
  DEPENDS generate_coordinator_headers)

add_library(gaia SHARED IMPORTED GLOBAL)
set_target_properties(gaia PROPERTIES IMPORTED_LOCATION ${GAIA_LIB})

add_executable(coordinator
  src/coordinator.cpp
  ${PROJECT_BINARY_DIR}/coordinator_ruleset.cpp
)

find_package(aws-crt-cpp REQUIRED)

add_dependencies(coordinator translate_coordinator_ruleset)
set_target_properties(coordinator PROPERTIES COMPILE_FLAGS "${GAIA_COMPILE_FLAGS}")
set_target_properties(coordinator PROPERTIES LINK_FLAGS "${GAIA_LINK_FLAGS}")
target_include_directories(coordinator
  PUBLIC
    ${PROJECT_SOURCE_DIR}/include
  PRIVATE
    ${GAIA_INC} ${PROJECT_BINARY_DIR}
)
target_link_libraries(coordinator PRIVATE AWS::aws-crt-cpp gaia rt pthread)
