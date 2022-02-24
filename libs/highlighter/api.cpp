#include "grammar.h"
#include "parse.h"
#include "reader.h"
#include "theme.h"
#include "extension.h"

#ifdef WIN64
#define EXPORT __declspec(dllexport)
#else
#define EXPORT extern "C" __attribute__((visibility("default"))) __attribute__((used))
#endif

#include <string>
#include <iostream>

#define MAX_STYLED_SPANS 512

struct theme_color_t {
    int8_t r;
    int8_t g;
    int8_t b;
};

struct theme_info_t {
    int8_t fg_r;
    int8_t fg_g;
    int8_t fg_b;
    int8_t bg_r;
    int8_t bg_g;
    int8_t bg_b;
    int8_t sel_r;
    int8_t sel_g;
    int8_t sel_b;
    // theme_color_t fg;
    // theme_color_t bg;
    // theme_color_t sel;
};

struct textstyle_t {
    int32_t start;
    int32_t length;
    int8_t r;
    int8_t g;
    int8_t b;
    int8_t bg_r;
    int8_t bg_g;
    int8_t bg_b;
    int8_t caret;
    bool bold;
    bool italic;
    bool underline;
    bool strike;
    bool tab;
};

struct rgba_t {
    int r;
    int g;
    int b;
    int a;
};

struct span_info_t {
    int start;
    int length;
    rgba_t fg;
    rgba_t bg;
    bool bold;
    bool italic;
    bool underline;
    // block_state_e state;
    std::string scope;
};

inline bool color_is_set(rgba_t clr)
{
    return clr.r >= 0 && (clr.r != 0 || clr.g != 0 || clr.b != 0 || clr.a != 0);
}

inline textstyle_t construct_style(std::vector<span_info_t>& spans, int index)
{
    textstyle_t res = {
        index,
        1,
        0, 0, 0,
        0, 0, 0,
        0,
        false,
        false,
        false,
        false,
        false
    };

    for (auto span : spans) {
        if (index >= span.start && index < span.start + span.length) {
            if (!color_is_set({ res.r, res.g, res.b, 0 }) && color_is_set(span.fg)) {
                res.r = span.fg.r;
                res.g = span.fg.g;
                res.b = span.fg.b;
            }
            res.italic = res.italic || span.italic;
        }
    }
    return res;
}

inline bool textstyles_equal(textstyle_t& first, textstyle_t& second)
{
    return first.italic == second.italic && first.underline == second.underline && first.r == second.r && first.g == second.g && first.b == second.b && first.bg_r == second.bg_r && first.bg_g == second.bg_g && first.bg_b == second.bg_b && first.caret == second.caret && !first.tab && !second.tab;
}

extension_list extensions;
std::vector<theme_ptr> themes;
std::vector<language_info_ptr> languages;

static textstyle_t textstyle_buffer[MAX_STYLED_SPANS];

theme_ptr current_theme()
{
    return themes[0];
}

EXPORT void init_highlighter()
{
    load_extensions("/home/iceman/.editor/extensions/", extensions);
    // for(auto ext : extensions) {
    //     printf("%s\n", ext.name.c_str());
    // }
}

EXPORT int load_theme(char* path)
{
    theme_ptr theme = theme_from_name(path, extensions);
    if (theme != nullptr) {
        themes.emplace_back(theme);
        return themes.size()-1;
    }
    return 0;
}

EXPORT int load_language(char* path)
{
    language_info_ptr lange = language_from_file(path, extensions);
    if (lange != nullptr) {
        languages.emplace_back(lange);
        return languages.size()-1;
    }
    return 0;
}

theme_color_t theme_color_from_scope_fg_bg(char* scope, bool fore = true)
{
    theme_color_t res = { -1, 0, 0 };
    if (current_theme()) {
        style_t scoped = current_theme()->styles_for_scope(scope);
        color_info_t sclr = scoped.foreground;
        if (!fore) {
            sclr = scoped.background;
        }
        res.r = sclr.red * 255;
        res.g = sclr.green * 255;
        res.b = sclr.blue * 255;
        if (sclr.red == -1) {
            color_info_t clr;
            current_theme()->theme_color(scope, clr);
            if (clr.red == -1) {
                current_theme()->theme_color(fore ? "editor.foreground" : "editor.background", clr);
            }
            if (clr.red == -1) {
                current_theme()->theme_color(fore ? "foreground" : "background", clr);
            }
            clr.red *= 255;
            clr.green *= 255;
            clr.blue *= 255;
            res.r = clr.red;
            res.g = clr.green;
            res.b = clr.blue;
        }
    }
    return res;
}

EXPORT
theme_color_t
theme_color_from_scope(char* scope)
{
    return theme_color_from_scope_fg_bg(scope);
}

EXPORT
theme_info_t
theme_info()
{
    char _default[32] = "default";
    theme_info_t info;
    color_info_t fg;
    if (current_theme()) {
        current_theme()->theme_color("editor.foreground", fg);
        if (fg.is_blank()) {
            current_theme()->theme_color("foreground", fg);
        }
        if (fg.is_blank()) {
            theme_color_t tc = theme_color_from_scope_fg_bg(_default);
            fg.red = (float)tc.r / 255;
            fg.green = (float)tc.g / 255;
            fg.blue = (float)tc.b / 255;
        }
    }

    fg.red *= 255;
    fg.green *= 255;
    fg.blue *= 255;

    color_info_t bg;
    if (current_theme()) {
        current_theme()->theme_color("editor.background", bg);
        if (bg.is_blank()) {
            current_theme()->theme_color("background", bg);
        }
        if (bg.is_blank()) {
            theme_color_t tc = theme_color_from_scope_fg_bg(_default, false);
            bg.red = (float)tc.r / 255;
            bg.green = (float)tc.g / 255;
            bg.blue = (float)tc.b / 255;
        }
    }

    bg.red *= 255;
    bg.green *= 255;
    bg.blue *= 255;

    color_info_t sel;
    if (current_theme())
        current_theme()->theme_color("editor.selectionBackground", sel);
    sel.red *= 255;
    sel.green *= 255;
    sel.blue *= 255;

    info.fg_r = fg.red;
    info.fg_g = fg.green;
    info.fg_b = fg.blue;
    info.bg_r = bg.red;
    info.bg_g = bg.green;
    info.bg_b = bg.blue;
    info.sel_r = sel.red;
    info.sel_g = sel.green;
    info.sel_b = sel.blue;

    // why does this happen?
    if (info.sel_r < 0 && info.sel_g < 0 && info.sel_b < 0) {
        info.sel_r *= -1;
        info.sel_g *= -1;
        info.sel_b *= -1;
    }
    return info;
}

void dump_tokens(std::map<size_t, scope::scope_t>& scopes)
{
    std::map<size_t, scope::scope_t>::iterator it = scopes.begin();
    while (it != scopes.end()) {
        size_t n = it->first;
        scope::scope_t scope = it->second;
        std::cout << n << " size:" << scope.size() << " atoms:"
                  << to_s(scope).c_str()
                  << std::endl;

        it++;
    }
}

parse::stack_ptr parser_state;

EXPORT
textstyle_t* run_highlighter(char *_text, int langId, int themeId, int block, int previous_block, int next_block)
{
    theme_ptr theme = themes[themeId];
    parse::grammar_ptr gm = languages[langId]->grammar;
    // parse::stack_ptr parser_state;
    std::map<size_t, scope::scope_t> scopes;

    // end marker
    textstyle_buffer[0].start = 0;
    textstyle_buffer[0].length = 0;

    std::string str = _text;
    const char *text = str.c_str();

    size_t l = str.length();
    const char* first = text;
    const char* last = first + l;

    parse::stack_ptr stack;

    bool firstLine = false;
    if (parser_state == nullptr) {
        parser_state = gm->seed();
        firstLine = true;
    }
    parser_state = parse::parse(first, last, parser_state, scopes, firstLine);

    std::map<size_t, scope::scope_t>::iterator it = scopes.begin();
    size_t n = 0;

    theme_info_t thm = theme_info();

    // printf("hl %d %d %d \n", block->lineNumber, block->length(), scopes.size());

    std::vector<span_info_t> spans;

    while (it != scopes.end()) {
        n = it->first;
        scope::scope_t scope = it->second;
        std::string scopeName(scope);
        style_t s = theme->styles_for_scope(scopeName);

        style_t style = theme->styles_for_scope(scopeName);
        span_info_t span = {
            .start = (int)n,
            .length = (int)(l - n),
            .fg = {
                (int)(255 * style.foreground.red),
                (int)(255 * style.foreground.green),
                (int)(255 * style.foreground.blue),
                0,
            },
            .bg = { 0, 0, 0, 0 },
            .bold = style.bold == bool_true,
            .italic = style.italic == bool_true,
            .underline = false,
            // .state = state,
            .scope = scopeName
        };

        if (spans.size() > 0) {
            span_info_t& prevSpan = spans.front();
            prevSpan.length = n - prevSpan.start;
        }

        spans.push_back(span);
        it++;
    }

    {
        span_info_t* prev = NULL;
        for (auto& s : spans) {
            if (prev) {
                prev->length = s.start - prev->start;
            }
            prev = &s;
        }
    }

    int idx = 0;
    textstyle_t* prev = NULL;

    for (int i = 0; i < l && i < MAX_STYLED_SPANS; i++) {
        textstyle_buffer[idx] = construct_style(spans, i);
        textstyle_t* ts = &textstyle_buffer[idx];

        if (!color_is_set({ ts->r, ts->g, ts->b, 0 })) {
            if (ts->r + ts->g + ts->b == 0) {
                ts->r = thm.fg_r;
                ts->g = thm.fg_g;
                ts->b = thm.fg_b;
            }
        }

        if (i > 0 && textstyles_equal(textstyle_buffer[idx], textstyle_buffer[idx - 1])) {
            textstyle_buffer[idx - 1].length++;
            idx--;
        }

        idx++;
    }

    // printf(">>%d\n", idx);

    textstyle_buffer[idx].start = 0;
    textstyle_buffer[idx].length = 0;
    return textstyle_buffer;
}