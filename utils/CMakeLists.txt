# Build wpsim_dump utility
add_executable(wpsim_dump wpsim_dump.F90)

target_link_libraries(wpsim_dump PRIVATE ${PROJECT_NAME})

# Find the installed shared library relative to the executable.
if(APPLE)
  set_target_properties(wpsim_dump PROPERTIES
    INSTALL_RPATH "@loader_path/../${CMAKE_INSTALL_LIBDIR}"
  )
elseif(UNIX)
  set_target_properties(wpsim_dump PROPERTIES
    INSTALL_RPATH "$ORIGIN/../${CMAKE_INSTALL_LIBDIR}"
  )
endif()

# Install the executable to ${CMAKE_INSTALL_BINDIR} (normally bin/)
install(
  TARGETS wpsim_dump
  RUNTIME DESTINATION "${CMAKE_INSTALL_BINDIR}"
)