theme_files = [
    'theme.cpp',
    'stringop.cpp',
    'util.cpp'
]

    theme_lib
    = static_library('theme', theme_files, include_directories
                     : [ theme_inc, scopes_inc, parser_inc ], dependencies
                     : [ jsoncpp_dep, onigmo_dep, scopes_dep, parser_dep ])

        theme
    = executable('theme', theme_files, 'main.cpp', include_directories
                 : [ theme_inc, scopes_inc, parser_inc ], dependencies
                 : [ jsoncpp_dep, onigmo_dep, scopes_dep, parser_dep ])

        theme_dep
    = declare_dependency(include_directories
                         : [ theme_inc, scopes_inc ], link_with
                         : theme_lib)