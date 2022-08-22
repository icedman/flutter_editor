#ifndef TEXTMATE_H
#define TEXTMATE_H

#include "theme.h"
#include "parse.h"
#include <string>
#include <vector>

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

struct block_data_t {
  block_data_t()
      : parser_state(nullptr), comment_block(false), prev_comment_block(false),
        string_block(false), prev_string_block(false), dirty(true) {}
  ~block_data_t() {}

  parse::stack_ptr parser_state;
  bool comment_block;
  bool prev_comment_block;
  bool string_block;
  bool prev_string_block;
  bool dirty;

  virtual void make_dirty();
};

typedef std::shared_ptr<block_data_t> block_data_ptr;
typedef std::vector<block_data_ptr> block_data_list;

struct doc_data_t {
  block_data_list blocks;

  block_data_ptr block_at(int line);
  block_data_ptr previous_block(int line);
  block_data_ptr next_block(int line);
  void add_block_at(int line);
  void remove_block_at(int line);
  void make_dirty();
};

typedef std::shared_ptr<doc_data_t> doc_data_ptr;

struct rgba_t {
  int16_t r;
  int16_t g;
  int16_t b;
  int16_t a;
};

struct theme_info_t {
  int16_t fg_r;
  int16_t fg_g;
  int16_t fg_b;
  int16_t fg_a;
  int16_t bg_r;
  int16_t bg_g;
  int16_t bg_b;
  int16_t bg_a;
  int16_t sel_r;
  int16_t sel_g;
  int16_t sel_b;
  int16_t sel_a;
  int16_t cmt_r;
  int16_t cmt_g;
  int16_t cmt_b;
  int16_t cmt_a;
  int16_t fn_r;
  int16_t fn_g;
  int16_t fn_b;
  int16_t fn_a;
  int16_t kw_r;
  int16_t kw_g;
  int16_t kw_b;
  int16_t kw_a;
  int16_t var_r;
  int16_t var_g;
  int16_t var_b;
  int16_t var_a;
  int16_t type_r;
  int16_t type_g;
  int16_t type_b;
  int16_t type_a;
  int16_t struct_r;
  int16_t struct_g;
  int16_t struct_b;
  int16_t struct_a;
  int16_t ctrl_r;
  int16_t ctrl_g;
  int16_t ctrl_b;
  int16_t ctrl_a;
};

struct textstyle_t {
  int16_t start;
  int16_t length;
  int16_t flags;
  int16_t r;
  int16_t g;
  int16_t b;
  int16_t a;
  int16_t bg_r;
  int16_t bg_g;
  int16_t bg_b;
  int16_t bg_a;
  int8_t caret;
  bool bold;
  bool italic;
  bool underline;
  bool strike;
};

struct span_info_t {
  int16_t start;
  int16_t length;
  rgba_t fg;
  rgba_t bg;
  bool bold;
  bool italic;
  bool underline;
  std::string scope;
};

struct list_item_t {
  std::string name;
  std::string description;
  std::string icon;
  std::string value;
};

struct Textmate {
  static void initialize(std::string path);
  static int load_theme(std::string path);
  static int load_language(std::string path);
  static int load_theme_data(const char* theme);
  static int load_language_data(const char* grammar);
  static int load_icons(std::string path);
  static language_info_ptr language_info(int id = 0);
  static language_info_ptr language();
  static int set_language(int id);
  static std::vector<textstyle_t>
  run_highlighter(char *_text, language_info_ptr lang, theme_ptr theme,
                  block_data_t *block = NULL, block_data_t *prev = NULL,
                  block_data_t *next = NULL, std::vector<span_info_t> *span_infos = NULL);
  static block_data_t* previous_block_data();
  static theme_info_t theme_info();
  static theme_ptr theme();
  static int set_theme(int id);
  static std::vector<list_item_t> theme_extensions();
  static std::vector<list_item_t> grammar_extensions();
  static bool has_running_threads();

  static char* language_definition(int langId);
  static char* icon_for_filename(char *filename);

  static void shutdown();
};

rgba_t theme_color_from_scope_fg_bg(char *scope, bool fore = true);

#endif // TEXTMATE_H
