project(
    'textmate-parser',
    ['cpp'],
    version : '0.1',
    meson_version: '>=0.43.0',
    default_options : [
        'warning_level=3', 
        'cpp_std=c++14'
    ]
)

add_project_arguments(
    [
        '-Wno-unused-parameter',
        '-Wno-pedantic',
        '-Wno-sign-compare',
        '-Wno-write-strings'
    ],
    language: ['cpp']
)

jsoncpp_dep = dependency('jsoncpp', required: true)
onigmo_dep = dependency('onigmo', required: true)

cmplr = meson.get_compiler('cpp')

pwd = meson.current_source_dir()

textmate_inc = include_directories('textmate')

subdir('textmate')
subdir('tests')
subdir('tests-c')