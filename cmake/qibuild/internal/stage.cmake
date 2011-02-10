
# Generate CMake code and put the result in res.
# For instance:
#  set(FOO bar)
#  set(SPAM eggs)
#
#  _qi_gen_code_from_vars(res FOO SPAM)
# Causes res to contain:
#
#  set(FOO "bar")
#  mark_as_advanced(FOO)
#  set(SPAM "eggs")
#  mark_as_advanced(SPAM)

include(CMakeParseArguments)
set(QI_SDK_INCLUDE "include")

function(_qi_gen_code_from_vars res)
  set(_in
"
set(@_name@ \"@_value@\" CACHE STRING \"\" FORCE)
mark_as_advanced(@_name@)
")
  set(_res "")
  foreach(_arg ${ARGN})
    set(_name ${_arg})
    set(_value ${${_arg}})
    string(CONFIGURE ${_in} _to_add @ONLY)
    set(_res ${_res}${_to_add})
  endforeach()
  set(${res} ${_res} PARENT_SCOPE)
endfunction()


function(_qi_gen_header_code_redist res)
  # The generated file will be installed in:
  # root_dir/share/cmake/${_target}/${_target}-config.cmake,
  # so we can find root_dir from the location of the generated file...
  set(_header
"
# This is an autogenerated file. Do not edit

get_filename_component(_cur_dir \${CMAKE_CURRENT_LIST_FILE} PATH)
set(_root_dir \"\${_cur_dir}/../../../\")
get_filename_component(ROOT_DIR \${_root_dir} ABSOLUTE)

"
  )
  set(_res "${_header}")
  set(${res} ${_res} PARENT_SCOPE)
endfunction()

function(_qi_gen_find_lib_code_redist res target)
  string(TOUPPER ${target} _U_target)
  set(_res
"
find_library(${_U_target}_DEBUG_LIBRARY ${target}_d)
find_library(${_U_target}_LIBRARY       ${target})
if (${_U_target}_DEBUG_LIBRARY)
  set(${_U_target}_LIBRARIES optimized:\${${_U_target}_LIBRARY};debug:\${${_U_target}_DEBUG_LIBRARY})
else()
  set(${_U_target}_LIBRARIES \${${_U_target}_LIBRARY})
endif()
")
  set(${res} ${_res} PARENT_SCOPE)
endfunction()


function(_qi_gen_find_lib_code_sdk res target)
  string(TOUPPER ${target} _U_target)
  get_target_property(_tdebug ${target} "LOCATION_DEBUG")
  get_target_property(_topti ${target}  "LOCATION_RELEASE")
  string(REGEX REPLACE ".dll$" ".lib" _tdebug "${_tdebug}")
  string(REGEX REPLACE ".dll$" ".lib" _topti "${_topti}")
  set(${_U_target}_LIBRARIES "optimized;${_topti};debug;${_tdebug}")
  _qi_gen_code_from_vars(_res ${_U_target}_LIBRARIES)
  set(${res} ${_res} PARENT_SCOPE)
endfunction()


# Here we have a list of relative paths, we want
# to write a variable with these paths preprend with
# ${ROOT_DIR}/include, the root include dir of the
# installed SDK.
function(_qi_gen_inc_dir_code_redist res target)
  string(TOUPPER ${target} _U_target)
  set(_relative_inc_dirs)
  if(${_U_target}_INCLUDE_DIRS)
    set(_relative_inc_dirs ${${_U_target}_INCLUDE_DIRS})
  else()
    get_directory_property(_inc_dirs INCLUDE_DIRECTORIES)
    # set this directories relative to CMAKE_CURRENT_SOURCE_DIR:
    foreach(_inc_dir ${_inc_dirs})
      file(RELATIVE_PATH _rel_inc_dir ${_inc_dir} ${CMAKE_CURRENT_SOURCE_DIR})
      if(NOT _rel_inc_dir)
        set(_rel_inc_dir ".")
      endif()
      list(APPEND _relative_inc_dirs ${_rel_inc_dir})
    endforeach()
  endif()
  # Preprend include dirs with ${ROOT_DIR}:
  set(_to_write)
  foreach(_inc_dir ${_relative_inc_dirs})
    list(APPEND _to_write "\${ROOT_DIR}/${QI_SDK_INCLUDE}/${_inc_dir}")
  endforeach()

  set(${_U_target}_INCLUDE_DIRS ${_to_write})
  _qi_gen_code_from_vars(_res ${_U_target}_INCLUDE_DIRS)
  set(${res} ${_res} PARENT_SCOPE)
endfunction()


# Here we have a list of relative paths, we want to write
# the absolute paths in CMAKE_BINARY_DIR/sdk/cmake/target-config.cmake
function(_qi_gen_inc_dir_code_sdk res target)
  string(TOUPPER ${target} _U_target)
  if(NOT ${_U_target}_INCLUDE_DIRS)
    get_directory_property(_inc_dirs INCLUDE_DIRECTORIES)
    set(${_U_target}_INCLUDE_DIRS ${_inc_dirs})
  endif()

  _qi_gen_code_from_vars(_res ${_U_target}_INCLUDE_DIRS)

  set(${res} ${_res} PARENT_SCOPE)
endfunction()

# Generate CMake code to be put in a
# ${target}-config.cmake, ready to be installed
function(_qi_gen_code_lib_redist res target)
  string(TOUPPER ${target} _U_target)
  set(_res "")

  # Header:
  _qi_gen_header_code_redist(_header ${target})
  set(_res ${_header})

  ## INCLUDE_DIRS:
  _qi_gen_inc_dir_code_redist(_inc ${target})
  set(_res "${_res} ${_inc}")

  # DEPENDS, DEFINITIONS:
  _qi_gen_code_from_vars(_defs
    ${_U_target}_DEPENDS
    ${_U_target}_DEFINITIONS)
  set(_res "${_res} ${_defs}")

  # Find libs:
  _qi_gen_find_lib_code_redist(_find_libs ${target})
  set(_res "${_res} ${_find_libs}")

  # FindPackageHandleStandardArgs:
  set(_call_fphsa
"
include(FindPackageHandleStandardArgs)
FIND_PACKAGE_HANDLE_STANDARD_ARGS(${_U_target} DEFAULT_MSG
  ${_U_target}_LIBRARIES
  ${_U_target}_INCLUDE_DIRS
)
")

  set(_res "${_res} ${_call_fphsa}")

  set(${res} ${_res} PARENT_SCOPE)
endfunction()


# Generate CMake code to be put in a
# ${target}-config.cmake, ready to be included
# by other projects from the build dir
function(_qi_gen_code_lib_sdk res target)
  string(TOUPPER ${target} _U_target)
  set(_res
  "# Autogenerated file.
# Do not edit.
# Do not change location.
")
  _qi_gen_inc_dir_code_sdk(_inc ${target})
  set(_res "${_res} ${_inc}")

  _qi_gen_find_lib_code_sdk(_lib ${target})
  set(_res "${_res} ${_lib}")

  _qi_gen_code_from_vars(_defs
    ${_U_target}_DEPENDS
    ${_U_target}_DEFINITIONS
  )
  set(_res "${_res} ${_defs}")
  set(${res} ${_res} PARENT_SCOPE)
endfunction()



# Usage:
# _qi_set_vars target
#
# accepted group of flags:
#  DEPENDS
#  DEFINITIONS
#  INCLUDE_DIRS
# (those will be guessed if not given:
# target_DEPENDS <- filled by qi_use_lib
# target_INCLUDE_DIRS <- using get_direcotry_properties()
# target_DEFINITIONS <- definitions are never guessed,
# use stage_lib(foo DEFINITIONS "-DSPAM=EGGS") if you need this.
function(_qi_set_vars target)
  string(TOUPPER ${target} _U_target)
  cmake_parse_arguments(ARG ""
    ""
    "DEPENDS;DEFINITIONS;INCLUDE_DIRS"
    ${ARGN})
  if(ARG_DEPENDS)
    set(${_U_target}_DEPENDS ${ARG_DEPENDS} PARENT_SCOPE)
  endif()

  if(ARG_DEFINITIONS)
    string(REPLACE "\"" "\\\""  _defs ${ARG_DEFINITIONS})
    set(${_U_target}_DEFINITIONS ${_defs} PARENT_SCOPE)
  endif()

  if(ARG_INCLUDE_DIRS)
    set(${_U_target}_INCLUDE_DIRS ${ARG_INCLUDE_DIRS} PARENT_SCOPE)
  endif()
endfunction()


function(_qi_stage_lib target ${ARGN})
  _qi_set_vars(${target} ${ARGN})

  _qi_gen_code_lib_redist(_redist ${target})
  set(_redist_file "${CMAKE_BINARY_DIR}/${QI_SDK_CMAKE_MODULES}/sdk/${target}-config.cmake")
  file(WRITE "${_redist_file}" ${_redist})
  qi_install_cmake(${target} ${_redist_file})

  _qi_gen_code_lib_sdk(_sdk ${target})
  set(_sdk_file "${QI_SDK_DIR}/${QI_SDK_CMAKE_MODULES}/${target}-config.cmake")
  file(WRITE "${_sdk_file}" "${_sdk}")
endfunction()
