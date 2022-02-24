#include "json/json.h"
#include "reader.h"
#include "scope.h"
#include "theme.h"

#include <iostream>

void dump_color(color_info_t clr)
{
    std::cout << " r:" << (int)(clr.red * 255)
              << " g:" << (int)(clr.green * 255)
              << " b:" << (int)(clr.blue * 255);
}

int main(int argc, char** argv)
{
    // std::cout << "theme!" << std::endl;

    // Json::Value root = parse::loadJson("test-cases/themes/light_vs.json");
    Json::Value root = parse::loadJson("editor/dracula.json");
    // std::cout << root << std::endl;

    theme_ptr theme = parse_theme(root);

    // scope::scope_t scope1("comment.block.c");
    // style_t s1 = theme->styles_for_scope(scope1);
    // std::cout << s1.foreground.red << ","
    //           << s1.foreground.green << ","
    //           << s1.foreground.blue
    //           << std::endl;

    // scope::scope_t scope2("punctuation.whitespace.function.leading.c");
    // style_t s2 = theme->styles_for_scope(scope2);

    // std::cout << s2.foreground.red << ","
    //           << s2.foreground.green << ","
    //           << s2.foreground.blue
    //           << std::endl;

    scope::scope_t scope3("variable.parameter.probably.c");
    // scope::scope_t scope3("variable.parameter");
    style_t s3 = theme->styles_for_scope(scope3);

    std::cout << "??" << (s3.italic) << std::endl;
    dump_color(s3.foreground);
    std::cout << std::endl;

    return 0;
}