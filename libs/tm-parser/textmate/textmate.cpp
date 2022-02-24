#include "textmate.h"

#include "grammar.h"
#include "parse.h"
#include "reader.h"
#include "theme.h"

#include <iostream>

static tm_color_t _colors[64];
static int _color_count = 0;

struct tm_state_t {
    int id;
};

struct tm_grammar_t {
    parse::grammar_ptr _grammar;
};

struct tm_theme_t {
    theme_ptr _theme;
};

void tm_init(struct tm_t* tm)
{
    tm->grammar = (struct tm_grammar_t*)calloc(1, sizeof(struct tm_grammar_t));
    tm->theme = (struct tm_theme_t*)calloc(1, sizeof(struct tm_theme_t));
}

void tm_free(struct tm_t* tm)
{
    free(tm->grammar);
    free(tm->theme);
}

void tm_load_grammar(struct tm_t* tm, char* filename)
{
    Json::Value json = parse::loadJson(filename);
    tm->grammar->_grammar = parse::parse_grammar(json);
}

void tm_load_theme(struct tm_t* tm, char* filename)
{
    Json::Value json = parse::loadJson(filename);
    tm->theme->_theme = parse_theme(json);
}

tm_color_t to_color(color_info_t c, theme_ptr theme = 0)
{
    tm_color_t tc = { c.red * 255, c.green * 255, c.blue * 255, 0 };
    if (theme) {
        tc.index = color_info_t::nearest_color_index(tc.r, tc.g, tc.b);
    }
    return tc;
}

tm_color_t* tm_theme_colors(struct tm_t* tm)
{
    color_info_t bg;
    color_info_t fg;
    color_info_t clr;

    theme_ptr theme = tm->theme->_theme;
    theme->theme_color("editor.foreground", clr);
    if (!clr.is_blank()) {
        fg = clr;
        fg.index = -1;
    }
    theme->theme_color("editor.background", clr);
    if (!clr.is_blank()) {
        bg = clr;
        bg.index = -1;
    }

    int idx = 0;
    _colors[idx++] = to_color(fg);
    _colors[idx++] = to_color(bg);

    auto it = theme->colorIndices.begin();
    while (it != theme->colorIndices.end()) {
        color_info_t fg = it->second;
        fg.red = fg.red <= 1 ? fg.red * 255 : fg.red;
        fg.green = fg.green <= 1 ? fg.green * 255 : fg.green;
        fg.blue = fg.blue <= 1 ? fg.blue * 255 : fg.blue;
        fg.index = it->second.index;
        _colors[idx++] = to_color(fg);
        it++;
    }

    return 0;
}

int tm_theme_color_count(struct tm_t* tm)
{
    if (_color_count == 0) {
        tm_theme_colors(tm);
    }
    return _color_count;
}

void dump_tokens(std::map<size_t, scope::scope_t>& scopes)
{
    FILE* fp = fopen("./out.txt", "w");
    std::map<size_t, scope::scope_t>::iterator it = scopes.begin();
    while (it != scopes.end()) {
        size_t n = it->first;
        scope::scope_t scope = it->second;
        fprintf(fp, "%s\n", to_s(scope).c_str());
        it++;
    }
    fclose(fp);
}

tm_parser_state_t tm_parse_line(struct tm_t* tm, char const* first, char const* last, tm_parser_state_t state)
{
    parse::stack_ptr parser_state;

    if (state.size == 0) {
        parser_state = tm->grammar->_grammar->seed();
    } else {
        // parser_state = ... unserialize from state
    }

    std::map<size_t, scope::scope_t> scopes;
    parser_state = parse::parse(first, last, parser_state, scopes, true);

    dump_tokens(scopes);

    tm_parser_state_t res = tm_create_state();

    // serialize to state
    return res;
}

tm_parser_state_t tm_create_state()
{
    tm_parser_state_t state;
    state.data = 0;
    state.size = 0;
    state.spans = 0;
    return state;
}

void tm_free_state(tm_parser_state_t& state)
{
    if (state.data) {
        free(state.data);
    }

    if (state.spans) {
        tm_text_span_t* ts = state.spans;
        while (ts) {
            tm_text_span_t* next = ts->next;
            free(ts);
            ts = next;
        }
    }

    state.data = 0;
    state.size = 0;
    state.spans = 0;
}