parser_files = [
    'grammar.cpp',
    'reader.cpp',
    'pattern.cpp',
    'parser.cpp'
]

    parser_lib
    = static_library('parser', parser_files, dependencies
                     : [ jsoncpp_dep, onigmo_dep, scopes_dep ])

        parser
    = executable('parser', parser_files, 'main.cpp', dependencies
                 : [ jsoncpp_dep, onigmo_dep, scopes_dep ])

        parser_dep
    = declare_dependency(include_directories
                         : [ parser_inc, scopes_inc, extension_inc ], link_with
                         : parser_lib)