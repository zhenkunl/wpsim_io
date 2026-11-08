cmake_minimum_required(VERSION 3.20)

project(wpsim_io
  VERSION 1.0.0
  LANGUAGES Fortran
)

if(NOT CMAKE_BUILD_TYPE)
  set(CMAKE_BUILD_TYPE "Release" CACHE STRING "Build type" FORCE)
endif()

include(GNUInstallDirs)
include(CTest)
include(cmake/compilers.cmake)
include(cmake/install.cmake)

# --------------------------------------------------
# Build options
# --------------------------------------------------
option(BUILD_SHARED_LIBS "Whether shared libraries should be built" TRUE)

# Collect source of the project
add_subdirectory("src")
add_subdirectory("utils")

if(BUILD_TESTING)
  add_subdirectory("examples")
endif()