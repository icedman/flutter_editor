#include "textmate.h"

#include <string.h>

int main(int argc, char** argv)
{
    struct tm_t tm;

    tm_init(&tm);
    tm_load_grammar(&tm, "extensions/cpp/syntaxes/c.tmLanguage.json");
    tm_load_theme(&tm, "test-cases/themes/light_vs.json");

    char* test = "int main(int argc, char** argv)";
    char* first = test;
    char* last = first + strlen(test);

    tm_parser_state_t first_state = tm_create_state();
    tm_parser_state_t next_state = tm_parse_line(&tm, first, last, first_state);

    tm_free_state(first_state);
    tm_free_state(next_state);

    tm_free(&tm);
    return 0;
}