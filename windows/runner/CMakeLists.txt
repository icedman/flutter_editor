cmake_minimum_required(VERSION 3.14)
project(runner LANGUAGES CXX C)

add_executable(${BINARY_NAME} WIN32
  "flutter_window.cpp"
  "main.cpp"
  "utils.cpp"
  "win32_window.cpp"
  "${FLUTTER_MANAGED_DIR}/generated_plugin_registrant.cc"
  "Runner.rc"
  "runner.exe.manifest"
)
apply_standard_settings(${BINARY_NAME})
target_compile_definitions(${BINARY_NAME} PRIVATE "NOMINMAX")
target_link_libraries(${BINARY_NAME} PRIVATE flutter flutter_wrapper_app)
target_include_directories(${BINARY_NAME} PRIVATE "${CMAKE_SOURCE_DIR}")
add_dependencies(${BINARY_NAME} flutter_assemble)

string(APPEND CMAKE_CXX_FLAGS " -D_WIN64 -DWIN64")
string(APPEND CMAKE_C_FLAGS " -D_WIN64 -DWIN64")
string(APPEND CMAKE_CXX_FLAGS " -std=gnu++11")
set (CMAKE_CXX_STANDARD 20)

add_library(editor_api
  SHARED
    ../../libs/tm-parser/textmate/parser/grammar.cpp
    ../../libs/tm-parser/textmate/parser/parser.cpp
    ../../libs/tm-parser/textmate/parser/pattern.cpp
    ../../libs/tm-parser/textmate/parser/reader.cpp
    ../../libs/tm-parser/textmate/scopes/match.cpp
    ../../libs/tm-parser/textmate/scopes/parse.cpp
    ../../libs/tm-parser/textmate/scopes/scope.cpp
    ../../libs/tm-parser/textmate/scopes/types.cpp
    ../../libs/tm-parser/textmate/theme/theme.cpp
    ../../libs/tm-parser/textmate/theme/util.cpp
    ../../libs/tm-parser/textmate/extensions/util.cpp
    ../../libs/tm-parser/textmate/extensions/utf8.cpp
    ../../libs/tm-parser/textmate/extensions/extension.cpp
    ../../libs/tinyxml2/tinyxml2.cpp
    ../../libs/jsoncpp/dist/jsoncpp.cpp
    ../../libs/highlighter/api.cpp
    ../../libs/highlighter.def
)

target_include_directories(editor_api 
    PRIVATE
    ../Onigmo
    ../dirent/include
    ../../libs/jsoncpp/dist
    ../../libs/tinyxml2
    ../../libs/tm-parser/textmate/parser
    ../../libs/tm-parser/textmate/scopes
    ../../libs/tm-parser/textmate/theme
    ../../libs/tm-parser/textmate/extensions
    ../../libs/highlighter
)

set_target_properties(editor_api PROPERTIES
  BUILD_WITH_INSTALL_RPATH 1 INSTALL_RPATH "$ORIGIN")

target_link_libraries(editor_api PRIVATE onigmo)
target_link_directories(editor_api PRIVATE ../Onigmo/build_x86)