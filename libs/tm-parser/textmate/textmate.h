#ifndef TEXTMATE_H
#define TEXTMATE_H

struct tm_t {
    struct tm_grammar_t* grammar;
    struct tm_theme_t* theme;
};

struct tm_text_span_t {
    int start;
    int length;
    int color;
    struct tm_text_span_t* next;
};

struct tm_parser_state_t {
    int size;
    char* data;
    tm_text_span_t* spans;
};

struct tm_color_t {
    int r, g, b;
    int index;
};

#ifndef IMPORT_TEXTMATE
extern "C" {
#endif

void tm_init(struct tm_t* tm);
void tm_free(struct tm_t* tm);

void tm_load_theme(struct tm_t* tm, char* filename);
tm_color_t* tm_theme_colors(struct tm_t* tm);
int tm_theme_color_count(struct tm_t* tm);

void tm_load_grammar(struct tm_t* tm, char* filename);
tm_parser_state_t tm_parse_line(struct tm_t* tm, char const* first, char const* last, tm_parser_state_t state);
tm_parser_state_t tm_create_state();
void tm_free_state(tm_parser_state_t& state);

#ifndef IMPORT_TEXTMATE
}
#endif

#endif // TEXTMATE_H
