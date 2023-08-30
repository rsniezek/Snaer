include(cmake/SystemLink.cmake)
include(cmake/LibFuzzer.cmake)
include(CMakeDependentOption)
include(CheckCXXCompilerFlag)


macro(Snaer_supports_sanitizers)
  if((CMAKE_CXX_COMPILER_ID MATCHES ".*Clang.*" OR CMAKE_CXX_COMPILER_ID MATCHES ".*GNU.*") AND NOT WIN32)
    set(SUPPORTS_UBSAN ON)
  else()
    set(SUPPORTS_UBSAN OFF)
  endif()

  if((CMAKE_CXX_COMPILER_ID MATCHES ".*Clang.*" OR CMAKE_CXX_COMPILER_ID MATCHES ".*GNU.*") AND WIN32)
    set(SUPPORTS_ASAN OFF)
  else()
    set(SUPPORTS_ASAN ON)
  endif()
endmacro()

macro(Snaer_setup_options)
  option(Snaer_ENABLE_HARDENING "Enable hardening" ON)
  option(Snaer_ENABLE_COVERAGE "Enable coverage reporting" OFF)
  cmake_dependent_option(
    Snaer_ENABLE_GLOBAL_HARDENING
    "Attempt to push hardening options to built dependencies"
    ON
    Snaer_ENABLE_HARDENING
    OFF)

  Snaer_supports_sanitizers()

  if(NOT PROJECT_IS_TOP_LEVEL OR Snaer_PACKAGING_MAINTAINER_MODE)
    option(Snaer_ENABLE_IPO "Enable IPO/LTO" OFF)
    option(Snaer_WARNINGS_AS_ERRORS "Treat Warnings As Errors" OFF)
    option(Snaer_ENABLE_USER_LINKER "Enable user-selected linker" OFF)
    option(Snaer_ENABLE_SANITIZER_ADDRESS "Enable address sanitizer" OFF)
    option(Snaer_ENABLE_SANITIZER_LEAK "Enable leak sanitizer" OFF)
    option(Snaer_ENABLE_SANITIZER_UNDEFINED "Enable undefined sanitizer" OFF)
    option(Snaer_ENABLE_SANITIZER_THREAD "Enable thread sanitizer" OFF)
    option(Snaer_ENABLE_SANITIZER_MEMORY "Enable memory sanitizer" OFF)
    option(Snaer_ENABLE_UNITY_BUILD "Enable unity builds" OFF)
    option(Snaer_ENABLE_CLANG_TIDY "Enable clang-tidy" OFF)
    option(Snaer_ENABLE_CPPCHECK "Enable cpp-check analysis" OFF)
    option(Snaer_ENABLE_PCH "Enable precompiled headers" OFF)
    option(Snaer_ENABLE_CACHE "Enable ccache" OFF)
  else()
    option(Snaer_ENABLE_IPO "Enable IPO/LTO" ON)
    option(Snaer_WARNINGS_AS_ERRORS "Treat Warnings As Errors" ON)
    option(Snaer_ENABLE_USER_LINKER "Enable user-selected linker" OFF)
    option(Snaer_ENABLE_SANITIZER_ADDRESS "Enable address sanitizer" ${SUPPORTS_ASAN})
    option(Snaer_ENABLE_SANITIZER_LEAK "Enable leak sanitizer" OFF)
    option(Snaer_ENABLE_SANITIZER_UNDEFINED "Enable undefined sanitizer" ${SUPPORTS_UBSAN})
    option(Snaer_ENABLE_SANITIZER_THREAD "Enable thread sanitizer" OFF)
    option(Snaer_ENABLE_SANITIZER_MEMORY "Enable memory sanitizer" OFF)
    option(Snaer_ENABLE_UNITY_BUILD "Enable unity builds" OFF)
    option(Snaer_ENABLE_CLANG_TIDY "Enable clang-tidy" ON)
    option(Snaer_ENABLE_CPPCHECK "Enable cpp-check analysis" ON)
    option(Snaer_ENABLE_PCH "Enable precompiled headers" OFF)
    option(Snaer_ENABLE_CACHE "Enable ccache" ON)
  endif()

  if(NOT PROJECT_IS_TOP_LEVEL)
    mark_as_advanced(
      Snaer_ENABLE_IPO
      Snaer_WARNINGS_AS_ERRORS
      Snaer_ENABLE_USER_LINKER
      Snaer_ENABLE_SANITIZER_ADDRESS
      Snaer_ENABLE_SANITIZER_LEAK
      Snaer_ENABLE_SANITIZER_UNDEFINED
      Snaer_ENABLE_SANITIZER_THREAD
      Snaer_ENABLE_SANITIZER_MEMORY
      Snaer_ENABLE_UNITY_BUILD
      Snaer_ENABLE_CLANG_TIDY
      Snaer_ENABLE_CPPCHECK
      Snaer_ENABLE_COVERAGE
      Snaer_ENABLE_PCH
      Snaer_ENABLE_CACHE)
  endif()

  Snaer_check_libfuzzer_support(LIBFUZZER_SUPPORTED)
  if(LIBFUZZER_SUPPORTED AND (Snaer_ENABLE_SANITIZER_ADDRESS OR Snaer_ENABLE_SANITIZER_THREAD OR Snaer_ENABLE_SANITIZER_UNDEFINED))
    set(DEFAULT_FUZZER ON)
  else()
    set(DEFAULT_FUZZER OFF)
  endif()

  option(Snaer_BUILD_FUZZ_TESTS "Enable fuzz testing executable" ${DEFAULT_FUZZER})

endmacro()

macro(Snaer_global_options)
  if(Snaer_ENABLE_IPO)
    include(cmake/InterproceduralOptimization.cmake)
    Snaer_enable_ipo()
  endif()

  Snaer_supports_sanitizers()

  if(Snaer_ENABLE_HARDENING AND Snaer_ENABLE_GLOBAL_HARDENING)
    include(cmake/Hardening.cmake)
    if(NOT SUPPORTS_UBSAN 
       OR Snaer_ENABLE_SANITIZER_UNDEFINED
       OR Snaer_ENABLE_SANITIZER_ADDRESS
       OR Snaer_ENABLE_SANITIZER_THREAD
       OR Snaer_ENABLE_SANITIZER_LEAK)
      set(ENABLE_UBSAN_MINIMAL_RUNTIME FALSE)
    else()
      set(ENABLE_UBSAN_MINIMAL_RUNTIME TRUE)
    endif()
    message("${Snaer_ENABLE_HARDENING} ${ENABLE_UBSAN_MINIMAL_RUNTIME} ${Snaer_ENABLE_SANITIZER_UNDEFINED}")
    Snaer_enable_hardening(Snaer_options ON ${ENABLE_UBSAN_MINIMAL_RUNTIME})
  endif()
endmacro()

macro(Snaer_local_options)
  if(PROJECT_IS_TOP_LEVEL)
    include(cmake/StandardProjectSettings.cmake)
  endif()

  add_library(Snaer_warnings INTERFACE)
  add_library(Snaer_options INTERFACE)

  include(cmake/CompilerWarnings.cmake)
  Snaer_set_project_warnings(
    Snaer_warnings
    ${Snaer_WARNINGS_AS_ERRORS}
    ""
    ""
    ""
    "")

  if(Snaer_ENABLE_USER_LINKER)
    include(cmake/Linker.cmake)
    configure_linker(Snaer_options)
  endif()

  include(cmake/Sanitizers.cmake)
  Snaer_enable_sanitizers(
    Snaer_options
    ${Snaer_ENABLE_SANITIZER_ADDRESS}
    ${Snaer_ENABLE_SANITIZER_LEAK}
    ${Snaer_ENABLE_SANITIZER_UNDEFINED}
    ${Snaer_ENABLE_SANITIZER_THREAD}
    ${Snaer_ENABLE_SANITIZER_MEMORY})

  set_target_properties(Snaer_options PROPERTIES UNITY_BUILD ${Snaer_ENABLE_UNITY_BUILD})

  if(Snaer_ENABLE_PCH)
    target_precompile_headers(
      Snaer_options
      INTERFACE
      <vector>
      <string>
      <utility>)
  endif()

  if(Snaer_ENABLE_CACHE)
    include(cmake/Cache.cmake)
    Snaer_enable_cache()
  endif()

  include(cmake/StaticAnalyzers.cmake)
  if(Snaer_ENABLE_CLANG_TIDY)
    Snaer_enable_clang_tidy(Snaer_options ${Snaer_WARNINGS_AS_ERRORS})
  endif()

  if(Snaer_ENABLE_CPPCHECK)
    Snaer_enable_cppcheck(${Snaer_WARNINGS_AS_ERRORS} "" # override cppcheck options
    )
  endif()

  if(Snaer_ENABLE_COVERAGE)
    include(cmake/Tests.cmake)
    Snaer_enable_coverage(Snaer_options)
  endif()

  if(Snaer_WARNINGS_AS_ERRORS)
    check_cxx_compiler_flag("-Wl,--fatal-warnings" LINKER_FATAL_WARNINGS)
    if(LINKER_FATAL_WARNINGS)
      # This is not working consistently, so disabling for now
      # target_link_options(Snaer_options INTERFACE -Wl,--fatal-warnings)
    endif()
  endif()

  if(Snaer_ENABLE_HARDENING AND NOT Snaer_ENABLE_GLOBAL_HARDENING)
    include(cmake/Hardening.cmake)
    if(NOT SUPPORTS_UBSAN 
       OR Snaer_ENABLE_SANITIZER_UNDEFINED
       OR Snaer_ENABLE_SANITIZER_ADDRESS
       OR Snaer_ENABLE_SANITIZER_THREAD
       OR Snaer_ENABLE_SANITIZER_LEAK)
      set(ENABLE_UBSAN_MINIMAL_RUNTIME FALSE)
    else()
      set(ENABLE_UBSAN_MINIMAL_RUNTIME TRUE)
    endif()
    Snaer_enable_hardening(Snaer_options OFF ${ENABLE_UBSAN_MINIMAL_RUNTIME})
  endif()

endmacro()
