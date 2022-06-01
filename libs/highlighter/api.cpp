#include "extension.h"
#include "grammar.h"
#include "parse.h"
#include "reader.h"
#include "theme.h"
#include "textmate.h"

#include <fstream>
#include <iostream>
#include <string>
#include <time.h>
#include <pthread.h>

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

#define MAX_STYLED_SPANS 512
#define MAX_BUFFER_LENGTH (1024 * 4)

static textstyle_t textstyle_buffer[MAX_STYLED_SPANS];
static char text_buffer[MAX_BUFFER_LENGTH];

EXPORT void initialize(char *extensionsPath) {
  Textmate::initialize(extensionsPath);
}

EXPORT
rgba_t theme_color(char *scope) {
  return theme_color_from_scope_fg_bg(scope);
}

EXPORT
theme_info_t theme_info() {
  return Textmate::theme_info();
}

EXPORT int load_theme(char *path) {
  return Textmate::load_theme(path);
}

EXPORT int load_icons(char *path) {
  return Textmate::load_icons(path);
}

EXPORT int load_language(char *path) {
  return Textmate::load_language(path);
}

class Block : public block_data_t {
public:
  Block() : block_data_t(), blockId(0), nextId(0)
  {}

  std::string text;
  int blockId;
  int nextId;
};

class Document {
public:
  Document() : documentId(0), tree(0), rebuild(false) {}

  ~Document() {
    if (tree) {
      ts_tree_delete(tree);
    }
  }

  int documentId;
  bool rebuild;
  std::string path;
  std::string contents;
  std::map<size_t, std::shared_ptr<Block>> blocks;
  TSTree *tree;

  std::shared_ptr<Block> start;
};

std::map<size_t, std::shared_ptr<Document>> documents;

void walk_tree(TSTreeCursor *cursor, int depth, int line,
               std::vector<TSNode> *nodes) {
  TSNode node = ts_tree_cursor_current_node(cursor);
  int start = ts_node_start_byte(node);
  int end = ts_node_end_byte(node);

  const char *type = ts_node_type(node);
  TSPoint startPoint = ts_node_start_point(node);
  TSPoint endPoint = ts_node_end_point(node);
  if (line != -1 && (line < startPoint.row || line > endPoint.row)) {
    return;
  }

  if (startPoint.row == line || endPoint.row == line) {
    // for(int i=0; i<depth; i++) {
    //   printf(" ");
    // }
    printf("(%d,%d) (%d,%d) [ %s ]\n", startPoint.row, startPoint.column, endPoint.row, endPoint.column, type);
    if (nodes != NULL) {
      nodes->push_back(node);
    }
  }

  if (!ts_tree_cursor_goto_first_child(cursor)) {
    return;
  }

  do {
    walk_tree(cursor, depth + 1, line, nodes);
  } while (ts_tree_cursor_goto_next_sibling(cursor));
}

void build_tree(const char *buffer, int len, Document *doc) {
  TSParser *parser = ts_parser_new();
  if (!ts_parser_set_language(parser, LANGUAGE())) {
    fprintf(stderr, "Invalid language\n");
  }

  TSTree *tree = ts_parser_parse_string(parser, NULL, buffer, len);

  TSNode root_node = ts_tree_root_node(tree);
  TSTreeCursor cursor = ts_tree_cursor_new(root_node);

  doc->tree = tree;
  // ts_tree_delete(tree);
  ts_parser_delete(parser);
}

void rebuild_tree(Document *doc) {
  std::shared_ptr<Block> block = doc->start;
  doc->contents = "";
  while (block) {
    doc->contents += block->text;
    doc->contents += "\n";
    if (block->nextId == 0)
      break;
    // printf(">>%s\n", block->text.c_str());
    block = doc->blocks[block->nextId];
  }
  // printf(">%s\n", contents.c_str());

  TSParser *parser = ts_parser_new();
  if (!ts_parser_set_language(parser, LANGUAGE())) {
    fprintf(stderr, "Invalid language\n");
  }

  if (doc->tree) {
    ts_tree_delete(doc->tree);
  }

  TSTree *tree =
      ts_parser_parse_string(parser, NULL, doc->contents.c_str(), doc->contents.size());
  doc->contents = "";

  TSNode root_node = ts_tree_root_node(tree);
  TSTreeCursor cursor = ts_tree_cursor_new(root_node);
  // walk_tree(&cursor, 0, -1, NULL);

  doc->tree = tree;
  doc->rebuild = false;

  // ts_tree_delete(tree);
  ts_parser_delete(parser);
}

EXPORT
void create_document(int documentId, char *path) {
  if (documents[documentId] == NULL) {
    documents[documentId] = std::make_shared<Document>();
    if (path != NULL) {
      documents[documentId]->path = path;
    }
  }
}

EXPORT
void run_tree_sitter(int documentId, char *path) {
  if (documents[documentId] == NULL) {
    documents[documentId] = std::make_shared<Document>();
  }

  if (strlen(path) > 0) {
    std::ifstream t(path);
    std::stringstream buffer;
    buffer << t.rdbuf();
    build_tree(buffer.str().c_str(), buffer.str().length(),
               documents[documentId].get());
    documents[documentId]->rebuild = false;
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
    create_document(documentId, NULL);
  }
  if (documents[documentId]->blocks[blockId] == NULL) {
    documents[documentId]->blocks[blockId] = std::make_shared<Block>();
  }

  if (documents[documentId]->blocks[blockId]->text != text) {
    // printf(">>[%s]\n[%s]\n",
    // documents[documentId]->blocks[blockId]->text.c_str(), text);
    documents[documentId]->blocks[blockId]->text = text;
    documents[documentId]->rebuild = true;
  }
  if (line == 0) {
    documents[documentId]->start = documents[documentId]->blocks[blockId];
  }
}

EXPORT
textstyle_t *run_highlighter(char *_text, int langId, int themeId, int document,
                             int blockId, int line, int previousBlockId,
                             int nextBlockId) {
  // end marker
  textstyle_buffer[0].start = 0;
  textstyle_buffer[0].length = 0;

  set_block(document, blockId, line, _text);

  block_data_t *block = documents[document]->blocks[blockId].get();
  block_data_t *previous_block = documents[document]->blocks[previousBlockId].get();
  block_data_t *next_block = documents[document]->blocks[nextBlockId].get();

  std::string tmp = _text;
  std::vector<textstyle_t> res = Textmate::run_highlighter(_text, 
      Textmate::language_info(langId),
      Textmate::theme(),
      block,
      previous_block,
      next_block
      );

  int idx = 0;
  for(auto r : res) {
    memcpy(&textstyle_buffer[idx], &r, sizeof(textstyle_t));
    // printf(">%d %d %d\n", textstyle_buffer[idx].r, textstyle_buffer[idx].g, textstyle_buffer[idx].b);
    idx++;
    textstyle_buffer[idx].start = 0;
    textstyle_buffer[idx].length = 0;
  }

  #if 0
  if (strlen(_text) > SKIP_PARSE_THRESHOLD) {
    return textstyle_buffer;
  }

  if (parse::grammar_t::running_threads > 0) {
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

  std::map<size_t, scope::scope_t> scopes;
  std::string str = _text;
  str += "\n";

  set_block(document, block, line, _text);
  std::vector<TSNode> tree_nodes;

  /*
  if (documents[document]->tree) {
    documents[document]->blocks[block]->nextId = next_block;
    if (documents[document]->blocks[previous_block] != NULL) {
      documents[document]->blocks[previous_block]->nextId = block;
    }

    if (documents[document]->rebuild) {
      rebuild_tree(documents[document].get());
    }

    TSNode root_node = ts_tree_root_node(documents[document]->tree);
    TSTreeCursor cursor = ts_tree_cursor_new(root_node);
    walk_tree(&cursor, 0, line, &tree_nodes);
  }
  */

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

  /*
  for(auto node : tree_nodes)
  {
    const char *type = ts_node_type(node);
    TSPoint startPoint = ts_node_start_point(node);
    TSPoint endPoint = ts_node_end_point(node);

    if (startPoint.row != endPoint.row) continue;

    std::string scopeName = type;

    // printf(">%d %d\n", startPoint.row, startPoint.column);
    if (scopeName == "identifier") {
      scopeName = "variable";
    } else {
      continue;
    }

    style_t style = theme->styles_for_scope(scopeName);
    span_info_t span = {.start = (int)startPoint.column,
                        .length = (int)(endPoint.column - startPoint.column),
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
    spans.push_back(span);
  }
  */

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

  #endif
  
  return textstyle_buffer;
}

EXPORT
char *language_definition(int langId) {
  return Textmate::language_definition(langId);
}

EXPORT
char *icon_for_filename(char *filename) {
  return Textmate::icon_for_filename(filename);
}

EXPORT
int has_running_threads()
{
  return Textmate::has_running_threads();
}