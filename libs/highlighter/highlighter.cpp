#include "extension.h"
#include "grammar.h"
#include "parse.h"
#include "reader.h"
#include "theme.h"

#include <fstream>
#include <iostream>
#include <string>
#include <time.h>
#include <pthread.h>

#include "api.h"

#define SKIP_PARSE_THRESHOLD 500
#define MAX_STYLED_SPANS 512
#define MAX_BUFFER_LENGTH (1024 * 4)

static textstyle_t textstyle_buffer[MAX_STYLED_SPANS];
static char text_buffer[MAX_BUFFER_LENGTH];

EXPORT
void set_block(int documentId, int blockId, int line, char *text);

Document::Document() : documentId(0), tree(0), rebuild(false) {}

Document::~Document() {
    if (tree) {
      ts_tree_delete(tree);
    }
  }


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

EXPORT
textstyle_t *run_highlighter(char *_text, int langId, int themeId, int documentId,
                             int blockId, int line, int previousBlockId,
                             int nextBlockId) {
  // end marker
  textstyle_buffer[0].start = 0;
  textstyle_buffer[0].length = 0;

  set_block(documentId, blockId, line, _text);

  block_data_t *block = get_document(documentId)->blocks[blockId].get();
  block_data_t *previous_block = get_document(documentId)->blocks[previousBlockId].get();
  block_data_t *next_block = get_document(documentId)->blocks[nextBlockId].get();

  // printf("line %d\n", line);

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
    textstyle_buffer[idx] = r;
    // memcpy(&textstyle_buffer[idx], &r, sizeof(textstyle_t));
    // printf(">(%d-%d) %d %d %d\n",
    //     textstyle_buffer[idx].start,
    //     textstyle_buffer[idx].length,
    //     textstyle_buffer[idx].r,
    //     textstyle_buffer[idx].g,
    //     textstyle_buffer[idx].b);
    idx++;
    if (idx + 1 == MAX_STYLED_SPANS) break;
  }
  textstyle_buffer[idx].start = 0;
  textstyle_buffer[idx].length = 0;

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
