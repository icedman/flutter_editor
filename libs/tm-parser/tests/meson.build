test_files = [
    'main.cpp',
]

executable(
    'tests',
    test_files,
    include_directories: [ parser_inc, scopes_inc, theme_inc ],
    dependencies: [ jsoncpp_dep, parser_dep, scopes_dep, theme_dep, onigmo_dep ]
)
