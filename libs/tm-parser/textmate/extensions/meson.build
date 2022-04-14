extensions_files = [
    'utf8.cpp',
    'util.cpp',
    'tinyxml2.cpp',
    'extension.cpp'
]

    extensions_lib
    = static_library('extensions', extensions_files, dependencies
                     : [ jsoncpp_dep, onigmo_dep, scopes_dep, parser_dep, theme_dep ])

        extensions
    = executable('extensions', extensions_files, 'main.cpp', dependencies
                 : [ jsoncpp_dep, onigmo_dep, scopes_dep, parser_dep, theme_dep ])
