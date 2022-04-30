#include "extension.h"
#include "grammar.h"
#include "parse.h"
#include "reader.h"
#include "theme.h"

#include <time.h>
#include <iostream>
#include <fstream>
#include <string>

#define SKIP_PARSE_THRESHOLD 500

#ifdef WIN64
#define EXPORT __declspec(dllexport)
#else
#define EXPORT                                                                 \
  extern "C" __attribute__((visibility("default"))) __attribute__((used))
#endif

extern "C" {
#include <tree_sitter/api.h>
const TSLanguage *tree_sitter_javascript(void);
const TSLanguage *tree_sitter_c(void);
#define LANGUAGE tree_sitter_c
}

#include <iostream>
#include <string>

#define TIMER_BEGIN                                                            \
  clock_t start, end;                                                          \
  double cpu_time_used;                                                        \
  start = clock();

#define TIMER_END                                                              \
  end = clock();                                                               \
  cpu_time_used = ((double)(end - start)) / CLOCKS_PER_SEC;

#define MAX_STYLED_SPANS 512
#define MAX_BUFFER_LENGTH (1024 * 4)

#define SCOPE_COMMENT (1 << 1)
#define SCOPE_COMMENT_BLOCK (1 << 2)
#define SCOPE_STRING (1 << 3)
#define SCOPE_BRACKET (1 << 4)
#define SCOPE_BRACKET_CURLY (1 << 4)
#define SCOPE_BRACKET_ROUND (1 << 5)
#define SCOPE_BRACKET_SQUARE (1 << 6)
#define SCOPE_BEGIN (1 << 7)
#define SCOPE_END (1 << 8)
#define SCOPE_TAG (1 << 9)
#define SCOPE_VARIABLE (1 << 10)
#define SCOPE_CONSTANT (1 << 11)
#define SCOPE_KEYWORD (1 << 12)
#define SCOPE_ENTITY (1 << 13)
#define SCOPE_ENTITY_CLASS (1 << 14)
#define SCOPE_ENTITY_FUNCTION (1 << 15)

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
  int32_t flags;
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
  std::string scope;
};

inline bool color_is_set(rgba_t clr) {
  return clr.r >= 0 && (clr.r != 0 || clr.g != 0 || clr.b != 0 || clr.a != 0);
}

inline textstyle_t construct_style(std::vector<span_info_t> &spans, int index) {
  textstyle_t res = {
      index, 1, 0, 0, 0, 0, 0, 0, 0, 0, false, false, false, false,
  };

  int32_t start;
  int32_t length;
  int32_t flags;
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

  for (auto span : spans) {
    if (index >= span.start && index < span.start + span.length) {
      if (!color_is_set({res.r, res.g, res.b, 0}) && color_is_set(span.fg)) {
        res.r = span.fg.r;
        res.g = span.fg.g;
        res.b = span.fg.b;
      }
      res.italic = res.italic || span.italic;

      if (span.scope.find("comment.block") == 0) {
        res.flags = res.flags | SCOPE_COMMENT_BLOCK;
      }
      if (span.scope.find("comment.line") == 0) {
        res.flags = res.flags | SCOPE_COMMENT;
      }
      if (span.scope.find("string.quoted") == 0) {
        res.flags = res.flags | SCOPE_STRING;
      }

      if (index == span.start) {
        if (span.scope.find(".bracket") != -1) {
          res.flags = res.flags | SCOPE_BRACKET;
          if (span.scope.find(".begin") != -1) {
            res.flags = res.flags | SCOPE_BEGIN;
          }
          if (span.scope.find(".end") != -1) {
            res.flags = res.flags | SCOPE_END;
          }
        }
        if (span.scope.find("variable") != -1) {
          res.flags = res.flags | SCOPE_VARIABLE;
        }
        if (span.scope.find("constant") != -1) {
          res.flags = res.flags | SCOPE_CONSTANT;
        }
        if (span.scope.find("keyword") != -1) {
          res.flags = res.flags | SCOPE_KEYWORD;
        }
        if (span.scope.find("entity") != -1) {
          res.flags = res.flags | SCOPE_ENTITY;
          if (span.scope.find("entity.name.class") != -1) {
            res.flags = res.flags | SCOPE_ENTITY_CLASS;
          }
          if (span.scope.find("entity.name.function") != -1) {
            res.flags = res.flags | SCOPE_ENTITY_FUNCTION;
          }
        }
      }
    }
  }
  return res;
}

inline bool textstyles_equal(textstyle_t &first, textstyle_t &second) {
  if (first.flags & SCOPE_BEGIN || second.flags & SCOPE_BEGIN ||
      first.flags & SCOPE_END || second.flags & SCOPE_END)
    return false;
  return first.italic == second.italic && first.underline == second.underline &&
         first.r == second.r && first.g == second.g && first.b == second.b &&
         first.bg_r == second.bg_r && first.bg_g == second.bg_g &&
         first.bg_b == second.bg_b && first.caret == second.caret &&
         first.flags == second.flags;
}

static extension_list extensions;
static std::vector<theme_ptr> themes;
static icon_theme_ptr icons;
static std::vector<language_info_ptr> languages;

static textstyle_t textstyle_buffer[MAX_STYLED_SPANS];
static char text_buffer[MAX_BUFFER_LENGTH];

theme_ptr current_theme() { return themes[0]; }

EXPORT void initialize(char *extensionsPath) {
  load_extensions(extensionsPath, extensions);
  // for(auto ext : extensions) {
  //     printf("%s\n", ext.name.c_str());
  // }
}

theme_color_t theme_color_from_scope_fg_bg(char *scope, bool fore = true) {
  theme_color_t res = {-1, 0, 0};
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
        current_theme()->theme_color(
            fore ? "editor.foreground" : "editor.background", clr);
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
theme_color_t theme_color(char *scope) {
  return theme_color_from_scope_fg_bg(scope);
}

theme_info_t themeInfo;
int themeInfoId = -1;

EXPORT
theme_info_t theme_info() {
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

EXPORT int load_theme(char *path) {
  theme_ptr theme = theme_from_name(path, extensions);
  if (theme != NULL) {
    themes.emplace_back(theme);
    return themes.size() - 1;
  }
  return 0;
}

EXPORT int load_icons(char *path) {
  icons = icon_theme_from_name(path, extensions);
  return 0;
}

EXPORT int load_language(char *path) {
  language_info_ptr lange = language_from_file(path, extensions);
  if (lange != NULL) {
    languages.emplace_back(lange);
    return languages.size() - 1;
  }
  return 0;
}

void dump_tokens(std::map<size_t, scope::scope_t> &scopes) {
  std::map<size_t, scope::scope_t>::iterator it = scopes.begin();
  while (it != scopes.end()) {
    size_t n = it->first;
    scope::scope_t scope = it->second;
    std::cout << n << " size:" << scope.size()
              << " atoms:" << to_s(scope).c_str() << std::endl;

    it++;
  }
}

std::map<size_t, parse::stack_ptr> parser_states;
std::map<size_t, std::string> block_texts;

class Block {
public:
  Block() : blockId(0), parser_state(NULL), commentLine(false) {}

  // std::string text;
  int blockId;
  bool commentLine;
  parse::stack_ptr parser_state;
};

class Document {
public:
  Document() : tree(0) {}
  
  ~Document() {
    if (tree) {
      ts_tree_delete(tree);
    }
  }
  
  int documentId = 0;
  std::map<size_t, std::shared_ptr<Block>> blocks;
  TSTree *tree;
};

std::map<size_t, std::shared_ptr<Document>> documents;

void dump_tree(TSNode node, int depth, int line) {
  int count = ts_node_child_count(node);
  // char *str = ts_node_string(node);
  int start = ts_node_start_byte(node);
  int end = ts_node_end_byte(node);  
  // const char* str = ts_node_string(node);
  
  const char* type = ts_node_type(node);
  TSPoint startPoint = ts_node_start_point(node);
  TSPoint endPoint = ts_node_end_point(node);
  if (line != -1 && (line < startPoint.row || line > endPoint.row)) {
    return;
  }

  for(int i=0; i<depth; i++) {
    printf(" ");
  }
  printf("(%d,%d) (%d,%d) [ %s ]\n", startPoint.row, startPoint.column, endPoint.row, endPoint.column, type);
  
  for(int i=0; i<count; i++) {
    TSNode child = ts_node_child(node, i);
    dump_tree(child, depth + 1, line);
  }
}

void build_tree(const char* buffer, int len, Document* doc) {
  TSParser *parser = ts_parser_new();
  if (!ts_parser_set_language(parser, LANGUAGE())) {
    fprintf(stderr, "Invalid language\n");
  }

  TSTree *tree =
      ts_parser_parse_string(parser, NULL, buffer, len);

  // TSNode root_node = ts_tree_root_node(tree);
  // dump_tree(root_node, 0, -1);

  doc->tree = tree;
  // ts_tree_delete(tree);
  ts_parser_delete(parser);
}

EXPORT
void create_document(int documentId, char *path) {
  if (documents[documentId] == NULL) {
    documents[documentId] = std::make_shared<Document>();
  }

  if (strlen(path) > 0) {
    printf(">>>%s\n", path);
    std::ifstream t(path);
    std::stringstream buffer;
    buffer << t.rdbuf();
    build_tree(buffer.str().c_str(), buffer.str().length(), documents[documentId].get());
  }
}

EXPORT
void destroy_document(int documentId) { documents[documentId] = NULL; }

EXPORT
void add_block(int documentId, int blockId, int line) {
  if (documents[documentId] == NULL) {
    return;
  }
  if (documents[documentId]->blocks[blockId] == NULL) {
    documents[documentId]->blocks[blockId] = std::make_shared<Block>();
  }
}

EXPORT
void remove_block(int documentId, int blockId, int line) {
  if (documents[documentId] == NULL) {
    return;
  }
  documents[documentId]->blocks[blockId] = NULL;
}

EXPORT
void set_block(int documentId, int blockId, int line, char *text) {
  if (documents[documentId] == NULL) {
    return;
  }
  if (documents[documentId]->blocks[blockId] == NULL) {
    return;
  }
  // documents[documentId]->blocks[blockId]->text = text;
}

EXPORT
textstyle_t *run_highlighter(char *_text, int langId, int themeId, int document,
                             int block, int line, int previous_block, int next_block) {
  // end marker
  textstyle_buffer[0].start = 0;
  textstyle_buffer[0].length = 0;
  if (strlen(_text) > SKIP_PARSE_THRESHOLD) {
    return textstyle_buffer;
  }

  // printf("hl %d %s\n", block, _text);

  theme_ptr theme = themes[themeId];
  language_info_ptr lang = languages[langId];
  parse::grammar_ptr gm = lang->grammar;

  if (themeInfoId != themeId) {
    themeInfo = theme_info();
    themeInfoId = themeId;
  }

  create_document(document, "");

  std::map<size_t, scope::scope_t> scopes;

  std::string str = _text;
  str += "\n";

  const char *text = str.c_str();

  size_t l = str.length();
  const char *first = text;
  const char *last = first + l;

  parse::stack_ptr parser_state;
  if (documents[document]->blocks[previous_block] != NULL &&
      !documents[document]->blocks[previous_block]->commentLine) {
    parser_state = documents[document]->blocks[previous_block]->parser_state;
  }

  bool firstLine = false;
  if (parser_state == NULL) {
    parser_state = gm->seed();
    firstLine = true;
  }
  

  if (documents[document]->tree) {
    TSNode root_node = ts_tree_root_node(documents[document]->tree);
    dump_tree(root_node, 0, line);
  }

  // TIMER_BEGIN
  parser_state = parse::parse(first, last, parser_state, scopes, firstLine);
  // TIMER_END

  // if ((cpu_time_used > 0.01)) {
  // printf(">>%f %s", cpu_time_used, text);
  // printf("%s\n", text);
  // dump_tokens(scopes);
  // }

  add_block(document, block, 0);
  documents[document]->blocks[block]->parser_state = parser_state;
  documents[document]->blocks[block]->commentLine = false;
  // documents[document]->blocks[block]->text = _text;

  std::map<size_t, scope::scope_t>::iterator it = scopes.begin();
  size_t n = 0;

  std::vector<span_info_t> spans;

  while (it != scopes.end()) {
    n = it->first;
    scope::scope_t scope = it->second;
    std::string scopeName(scope);
    style_t style = theme->styles_for_scope(scopeName);

    scopeName = scope.back();
    // printf(">%s\n", scopeName.c_str());

    span_info_t span = {.start = (int)n,
                        .length = (int)(l - n),
                        .fg =
                            {
                                (int)(255 * style.foreground.red),
                                (int)(255 * style.foreground.green),
                                (int)(255 * style.foreground.blue),
                                0,
                            },
                        .bg = {0, 0, 0, 0},
                        .bold = style.bold == bool_true,
                        .italic = style.italic == bool_true,
                        .underline = style.underlined == bool_true,
                        // .state = state,
                        .scope = scopeName};

    if (spans.size() > 0) {
      span_info_t &prevSpan = spans.front();
      prevSpan.length = n - prevSpan.start;
    }

    spans.push_back(span);
    it++;
  }

  {
    span_info_t *prev = NULL;
    for (auto &s : spans) {
      if (prev) {
        prev->length = s.start - prev->start;
      }
      prev = &s;
    }
  }

  int idx = 0;
  textstyle_t *prev = NULL;

  for (int i = 0; i < l && i < MAX_STYLED_SPANS; i++) {
    textstyle_buffer[idx] = construct_style(spans, i);
    textstyle_t *ts = &textstyle_buffer[idx];

    // brackets hack - use language info
    if (ts->flags & SCOPE_BRACKET &&
        (lang->hasCurly || lang->hasRound || lang->hasSquare)) {
      ts->flags &= ~SCOPE_BRACKET;
    }
    if (!(ts->flags & SCOPE_COMMENT || ts->flags & SCOPE_COMMENT_BLOCK ||
          ts->flags & SCOPE_STRING)) { //&&
      // (!(ts->flags & SCOPE_BRACKET_CURLY) &&
      //   !(ts->flags & SCOPE_BRACKET_ROUND) &&
      //   !(ts->flags & SCOPE_BRACKET_SQUARE))) {

      char ch = _text[ts->start];

      // #define _P() printf(">%c %d %d %d\n", ch, lang->hasCurly,
      // lang->hasRound, lang->hasSquare);

      if (lang->hasCurly && ch == '{') {
        ts->flags =
            ts->flags | SCOPE_BRACKET | SCOPE_BRACKET_CURLY | SCOPE_BEGIN;
      }
      if (lang->hasRound && ch == '(') {
        ts->flags =
            ts->flags | SCOPE_BRACKET | SCOPE_BRACKET_ROUND | SCOPE_BEGIN;
      }
      if (lang->hasSquare && ch == '[') {
        ts->flags =
            ts->flags | SCOPE_BRACKET | SCOPE_BRACKET_SQUARE | SCOPE_BEGIN;
      }
      if (lang->hasCurly && ch == '}') {
        ts->flags = ts->flags | SCOPE_BRACKET | SCOPE_BRACKET_CURLY | SCOPE_END;
      }
      if (lang->hasRound && ch == ')') {
        ts->flags = ts->flags | SCOPE_BRACKET | SCOPE_BRACKET_ROUND | SCOPE_END;
      }
      if (lang->hasSquare && ch == ']') {
        ts->flags =
            ts->flags | SCOPE_BRACKET | SCOPE_BRACKET_SQUARE | SCOPE_END;
      }
    }

    if (!color_is_set({ts->r, ts->g, ts->b, 0})) {
      if (ts->r + ts->g + ts->b == 0) {
        ts->r = themeInfo.fg_r;
        ts->g = themeInfo.fg_g;
        ts->b = themeInfo.fg_b;
      }
    }

    if (i > 0 &&
        textstyles_equal(textstyle_buffer[idx], textstyle_buffer[idx - 1])) {
      textstyle_buffer[idx - 1].length++;
      idx--;
    }

    idx++;
  }

  textstyle_buffer[idx].start = 0;
  textstyle_buffer[idx].length = 0;

  if (idx > 0) {
    documents[document]->blocks[block]->commentLine =
        (textstyle_buffer[idx - 1].flags & SCOPE_COMMENT);
  }

  return textstyle_buffer;
}

EXPORT
char *language_definition(int langId) {
  language_info_ptr lang = languages[langId];
  std::ostringstream ss;
  ss << lang->definition;
  strcpy(text_buffer, ss.str().c_str());
  return text_buffer;
}

EXPORT
char *icon_for_filename(char *filename) {
  icon_t icon = icon_for_file(icons, filename, extensions);
  strcpy(text_buffer, icon.path.c_str());
  return text_buffer;
}
