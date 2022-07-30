cmake_minimum_required(VERSION 3.10)
project(editor LANGUAGES CXX C)

#string(APPEND CMAKE_CXX_FLAGS " -Wno-c++11-narrowing")
string(APPEND CMAKE_CXX_FLAGS " -std=gnu++11")
set (CMAKE_CXX_STANDARD 11)

if (CMAKE_SYSTEM_NAME STREQUAL "Android")
string(APPEND PRECOMPILED ${CMAKE_SOURCE_DIR}/../precompiled/android/${ANDROID_ABI})
else()
string(APPEND PRECOMPILED ${CMAKE_SOURCE_DIR}/../precompiled/linux)
endif()

add_definitions(-fPIC)

add_library(onigmolib
  SHARED 
    ./Onigmo/regcomp.c
    ./Onigmo/regexec.c
    ./Onigmo/regparse.c
    ./Onigmo/regsyntax.c
    ./Onigmo/st.c
    ./Onigmo/regenc.c
    ./Onigmo/regext.c
    ./Onigmo/regposerr.c
    ./Onigmo/regtrav.c
    ./Onigmo/regerror.c
    ./Onigmo/reggnu.c
    ./Onigmo/regposix.c
    ./Onigmo/regversion.c
    ./Onigmo/enc/ascii.c  
    ./Onigmo/enc/euc_kr.c
    ./Onigmo/enc/iso_8859_10.c
    ./Onigmo/enc/iso_8859_16.c
    ./Onigmo/enc/iso_8859_5.c
    ./Onigmo/enc/koi8_r.c
    ./Onigmo/enc/us_ascii.c
    ./Onigmo/enc/utf_8.c    
    ./Onigmo/enc/windows_1254.c
    ./Onigmo/enc/big5.c   
    ./Onigmo/enc/euc_tw.c
    ./Onigmo/enc/iso_8859_11.c
    ./Onigmo/enc/iso_8859_1.c
    ./Onigmo/enc/iso_8859_6.c
    ./Onigmo/enc/koi8_u.c
    ./Onigmo/enc/utf_16be.c
    ./Onigmo/enc/windows_1250.c
    ./Onigmo/enc/windows_1257.c
    ./Onigmo/enc/cp949.c  
    ./Onigmo/enc/gb18030.c
    ./Onigmo/enc/iso_8859_13.c
    ./Onigmo/enc/iso_8859_2.c
    ./Onigmo/enc/iso_8859_7.c
    ./Onigmo/enc/mktable.c 
    ./Onigmo/enc/utf_16le.c
    ./Onigmo/enc/windows_1251.c
    ./Onigmo/enc/windows_31j.c
    ./Onigmo/enc/emacs_mule.c
    #./Onigmo/enc/gb2312.c
    ./Onigmo/enc/iso_8859_14.c
    ./Onigmo/enc/iso_8859_3.c
    ./Onigmo/enc/iso_8859_8.c
    ./Onigmo/enc/shift_jis.c
    ./Onigmo/enc/utf_32be.c
    ./Onigmo/enc/windows_1252.c
    ./Onigmo/enc/euc_jp.c 
    ./Onigmo/enc/gbk.c 
    ./Onigmo/enc/iso_8859_15.c
    ./Onigmo/enc/iso_8859_4.c
    ./Onigmo/enc/iso_8859_9.c
    ./Onigmo/enc/unicode.c 
    ./Onigmo/enc/utf_32le.c
    ./Onigmo/enc/windows_1253.c
)

target_include_directories(onigmolib 
    PRIVATE
    ./Onigmo
    ./Onigmo/enc
    ./Onigmo/enc/unicode
)

add_library(editor_api
  SHARED
    ./tm-parser/textmate/textmate.cpp
    ./tm-parser/textmate/parser/grammar.cpp
    ./tm-parser/textmate/parser/parser.cpp
    ./tm-parser/textmate/parser/pattern.cpp
    ./tm-parser/textmate/parser/reader.cpp
    ./tm-parser/textmate/scopes/match.cpp
    ./tm-parser/textmate/scopes/parse.cpp
    ./tm-parser/textmate/scopes/scope.cpp
    ./tm-parser/textmate/scopes/types.cpp
    ./tm-parser/textmate/theme/theme.cpp
    ./tm-parser/textmate/theme/util.cpp
    ./tm-parser/textmate/extensions/util.cpp
    ./tm-parser/textmate/extensions/utf8.cpp
    ./tm-parser/textmate/extensions/extension.cpp
    ./tm-parser/textmate/resources/grammars.cpp
    ./tm-parser/textmate/resources/themes.cpp
    ./tinyxml2/tinyxml2.cpp
    ./jsoncpp/dist/jsoncpp.cpp
    ./highlighter/api.cpp
    ./highlighter/highlighter.cpp
    ./highlighter/treesitter.cpp
    ./highlighter/git.cpp
    ./highlighter/ssh.cpp
)

target_include_directories(editor_api 
    PRIVATE
    ./Onigmo
    ./jsoncpp/dist
    ./tinyxml2
    ./tm-parser/textmate/
    ./tm-parser/textmate/parser
    ./tm-parser/textmate/scopes
    ./tm-parser/textmate/theme
    ./tm-parser/textmate/extensions
    ./tm-parser/textmate/resources
    ./tree-sitter/lib/include
    ./highlighter
    ${PRECOMPILED}/libgit2/include
    ${PRECOMPILED}/libssh2/include
)

#########################
# libgit2 libssh2
#########################

if (DEFINED ENV{ENABLE_TREESITTER})
add_library(treesitter
  SHARED
  ./tree-sitter/lib/src/alloc.c
  ./tree-sitter/lib/src/get_changed_ranges.c
  ./tree-sitter/lib/src/language.c
  ./tree-sitter/lib/src/lexer.c
  ./tree-sitter/lib/src/node.c
  ./tree-sitter/lib/src/parser.c
  ./tree-sitter/lib/src/query.c
  ./tree-sitter/lib/src/stack.c
  ./tree-sitter/lib/src/subtree.c
  ./tree-sitter/lib/src/tree.c
  ./tree-sitter/lib/src/tree_cursor.c
  ./tree-sitter-grammars/tree-sitter-javascript/src/parser.c
  ./tree-sitter-grammars/tree-sitter-javascript/src/scanner.c
  ./tree-sitter-grammars/tree-sitter-c/src/parser.c
)

target_include_directories(treesitter 
    PRIVATE
    ./tree-sitter/lib/include
    ./tree-sitter/lib/src
)
endif()

#########################
# libgit2 libssh2
#########################

add_library(ssl
        STATIC
        IMPORTED)

set_target_properties(ssl
        PROPERTIES IMPORTED_LOCATION
        ${PRECOMPILED}/openssl/ssl/libssl.a)

add_library(crypto
        STATIC
        IMPORTED)

set_target_properties(crypto
        PROPERTIES IMPORTED_LOCATION
        ${PRECOMPILED}/openssl/crypto/libcrypto.a)

add_library(ssh2
        STATIC
        IMPORTED)

set_target_properties(ssh2
        PROPERTIES IMPORTED_LOCATION
        ${PRECOMPILED}/libssh2/libssh2.a)

add_library(git2
        STATIC
        IMPORTED)

set_target_properties(git2
        PROPERTIES IMPORTED_LOCATION
        ${PRECOMPILED}/libgit2/libgit2.a)

set_target_properties(editor_api PROPERTIES
  BUILD_WITH_INSTALL_RPATH 1 INSTALL_RPATH "$ORIGIN")

target_link_libraries(editor_api PRIVATE onigmolib)

if (DEFINED ENV{ENABLE_TREESITTER})
target_link_libraries(editor_api PRIVATE treesitter)
endif()

if (DEFINED ENV{ENABLE_GIT})
add_definitions(-DENABLE_GIT=1)
endif()

if (DEFINED ENV{ENABLE_SSH})
add_definitions(-DENABLE_SSH=1)
endif()

if (DEFINED ENV{ENABLE_GIT} OR DEFINED ENV{ENABLE_SSH})
target_link_libraries(editor_api PRIVATE git2 ssl crypto ssh2)
endif()
