scopes_files = [
    'scope.cpp',
    'types.cpp',
    'parse.cpp',
    'match.cpp'
]

    scopes_lib
    = static_library('scopes', scopes_files, dependencies
                     : [ jsoncpp_dep, onigmo_dep ])

        scopes
    = executable('scopes', scopes_files, 'main.cpp', dependencies
                 : [ jsoncpp_dep, onigmo_dep ])

        scopes_dep
    = declare_dependency(include_directories
                         : [scopes_inc], link_with
                         : scopes_lib)