#include "textmate.h"

#include "extension.h"
#include "grammar.h"
#include "parse.h"
#include "reader.h"
#include "theme.h"
#include "util.h"

#include <time.h>
#define SKIP_PARSE_THRESHOLD 500

#include <iostream>
#include <string>

#define MAX_STYLED_SPANS 512
#define MAX_BUFFER_LENGTH (1024 * 4)

inline bool color_is_set(rgba_t clr) {
  return clr.r >= 0 && (clr.r != 0 || clr.g != 0 || clr.b != 0 || clr.a != 0);
}

inline textstyle_t construct_style(std::vector<span_info_t> &spans, int16_t index) {
  textstyle_t res = {
      index, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, false, false, false, false,
  };

  memset(&res, 0, sizeof(textstyle_t));
  res.start = index;
  res.length = 1;

  // int16_t start;
  // int16_t length;
  // int16_t flags;
  // int16_t r;
  // int16_t g;
  // int16_t b;
  // int16_t a;
  // int16_t bg_r;
  // int16_t bg_g;
  // int16_t bg_b;
  // int16_t bg_a;
  // int8_t caret;
  // bool bold;
  // bool italic;
  // bool underline;
  // bool strike;

  for (auto span : spans) {
    if (index >= span.start && index < span.start + span.length) {
      if (!color_is_set({res.r, res.g, res.b, 0}) && color_is_set(span.fg)) {
        res.r = span.fg.r;
        res.g = span.fg.g;
        res.b = span.fg.b;
        res.a = span.fg.a;
      }
      res.italic = res.italic || span.italic;

      if (span.scope.find("comment.block") == 0) {
        res.flags = res.flags | SCOPE_COMMENT_BLOCK;
      }
      if (span.scope.find("string.quoted") == 0) {
        res.flags = res.flags | SCOPE_STRING;
      }
    }
  }
  return res;
}

inline bool textstyles_equal(textstyle_t &first, textstyle_t &second) {
  return first.italic == second.italic && first.bold == second.bold &&
        first.strike == second.strike && first.underline == second.underline &&
         first.r == second.r &&
         first.g == second.g &&
         first.b == second.b &&
         first.a == second.a &&
         first.bg_r == second.bg_r &&
         first.bg_g == second.bg_g &&
         first.bg_b == second.bg_b &&
         first.bg_a == second.bg_a &&
         first.caret == second.caret &&
         first.flags == second.flags;
}

static extension_list extensions;
static std::vector<theme_ptr> themes;
static icon_theme_ptr icons;
static std::vector<language_info_ptr> languages;

static textstyle_t textstyle_buffer[MAX_STYLED_SPANS];
static char text_buffer[MAX_BUFFER_LENGTH];

block_data_t _previous_block_data;

int current_theme_id = 0;
theme_ptr current_theme() { return themes[current_theme_id]; }
theme_ptr Textmate::theme() { return themes[current_theme_id]; }

int current_language_id = 0;
language_info_ptr Textmate::language() { return languages[current_language_id]; }

void Textmate::initialize(std::string path) {
  load_extensions(path, extensions);
  // for(auto ext : extensions) {
  //     printf("%s\n", ext.name.c_str());
  // }
}

rgba_t theme_color_from_scope_fg_bg(char *scope, bool fore) {
  rgba_t res = {-1, 0, 0, 0};
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

rgba_t theme_color(char *scope) { return theme_color_from_scope_fg_bg(scope); }

theme_info_t themeInfo;
int themeInfoId = -1;

int Textmate::set_theme(int id)
{
  current_theme_id = id;
  return id;
}

std::vector<list_item_t> Textmate::theme_extensions()
{
  std::vector<list_item_t> res;
  for(auto ext : extensions) {
      if (!ext.hasThemes)
          continue;
      Json::Value themes = ext.package["contributes"]["themes"];
      for (int i = 0; i < themes.size(); i++) {
            list_item_t item = {
                .name = ext.package["id"].asString(),
                .description = ext.package["description"].asString(),
                .value = ext.path + "/" + themes[i]["path"].asString()
            };

            if (item.name == "") {
                item.name = themes[i]["label"].asString();
            }
            if (item.name == "") {
                item.name = themes[i]["themeLabel"].asString();
            }
            if (item.name == "") {
                item.name = themes[i]["id"].asString();
            }

            item.name = package_string(ext, item.name);
            item.description = package_string(ext, item.description);

            if (ext.publisher.length()) {
                item.description += "\npublisher: ";
                item.description += ext.publisher;
            }

            res.push_back(item);
      }
  }
  return res;
}

std::vector<list_item_t> Textmate::grammar_extensions()
{
  std::vector<list_item_t> res;
  for(auto ext : extensions) {
      if (!ext.hasGrammars)
          continue;

        Json::Value contribs = ext.package["contributes"];
        if (!contribs.isMember("languages") || !contribs.isMember("grammars")) {
            continue;
        }
        Json::Value langs = contribs["languages"];
        for (int i = 0; i < langs.size(); i++) {
            Json::Value lang = langs[i];
            if (!lang.isMember("id")) {
                continue;
            }

            if (lang.isMember("extensions")) {
                Json::Value exts = lang["extensions"];
                for (int j = 0; j < exts.size(); j++) {
                    Json::Value ex = exts[j];
                    list_item_t item = {
                        .name = lang["id"].asString(),
                        .description = ext.package["description"].asString(),
                        .value = ex.asString()
                    };
                    res.push_back(item);
                    break;

                }
            }

        }
  }
  return res;
}

theme_info_t Textmate::theme_info() {
  char _default[32] = "default";
  theme_info_t info;
  color_info_t fallback;

  {
    rgba_t tc = theme_color_from_scope_fg_bg(_default);
    fallback.red = (float)tc.r / 255;
    fallback.green = (float)tc.g / 255;
    fallback.blue = (float)tc.b / 255;
  }

  color_info_t fg;
  if (current_theme()) {
    current_theme()->theme_color("editor.foreground", fg);
    if (fg.is_blank()) {
      current_theme()->theme_color("foreground", fg);
    }
    if (fg.is_blank()) {
      fg = fallback;
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
      rgba_t tc = theme_color_from_scope_fg_bg(_default, false);
      bg.red = (float)tc.r / 255;
      bg.green = (float)tc.g / 255;
      bg.blue = (float)tc.b / 255;
    }
  }

  bg.red *= 255;
  bg.green *= 255;
  bg.blue *= 255;

  color_info_t sel;
  if (current_theme()) {
    current_theme()->theme_color("editor.selectionBackground", sel);
  }
  sel.red *= 255;
  sel.green *= 255;
  sel.blue *= 255;

  color_info_t cmt;
  if (current_theme()) {
    // current_theme()->theme_color("comment", cmt);
    style_t style = current_theme()->styles_for_scope("comment");
    cmt = style.foreground;
    if (cmt.is_blank()) {
      cmt = fallback;   
    }
  }

  cmt.red *= 255;
  cmt.green *= 255;
  cmt.blue *= 255;


  color_info_t fn;
  if (current_theme()) {
    // current_theme()->theme_color("comment", fn);
    style_t style = current_theme()->styles_for_scope("entity.name.function");
    fn = style.foreground;
    if (fn.is_blank()) {
      fn = fallback;
    }
  }

  fn.red *= 255;
  fn.green *= 255;
  fn.blue *= 255;

  color_info_t kw;
  if (current_theme()) {
    // current_theme()->theme_color("comment", kw);
    style_t style = current_theme()->styles_for_scope("keyword");
    kw = style.foreground;
    if (kw.is_blank()) {
      kw = fallback;
    }
  }

  kw.red *= 255;
  kw.green *= 255;
  kw.blue *= 255;

  color_info_t var;
  if (current_theme()) {
    // current_theme()->theme_color("comment", var);
    style_t style = current_theme()->styles_for_scope("variable");
    var = style.foreground;
    if (var.is_blank()) {
      var = fallback;
    }
  }

  var.red *= 255;
  var.green *= 255;
  var.blue *= 255;

  color_info_t typ;
  if (current_theme()) {
    // current_theme()->theme_color("comment", var);
    style_t style = current_theme()->styles_for_scope("type");
    typ = style.foreground;
    if (typ.is_blank()) {
      typ = fallback;
    }
  }

  typ.red *= 255;
  typ.green *= 255;
  typ.blue *= 255;

  color_info_t strct;
  if (current_theme()) {
    // current_theme()->theme_color("comment", var);
    style_t style = current_theme()->styles_for_scope("type");
    strct = style.foreground;
    if (strct.is_blank()) {
      strct = fallback;
    }
  }

  strct.red *= 255;
  strct.green *= 255;
  strct.blue *= 255;
  
  color_info_t ctrl;
  if (current_theme()) {
    // current_theme()->theme_color("comment", var);
    style_t style = current_theme()->styles_for_scope("control");
    ctrl = style.foreground;
    if (strct.is_blank()) {
      ctrl = fallback;
    }
  }

  strct.red *= 255;
  strct.green *= 255;
  strct.blue *= 255;
  info.fg_r = fg.red;
  info.fg_g = fg.green;
  info.fg_b = fg.blue;
  info.fg_a = color_info_t::nearest_color_index(fg.red, fg.green, fg.blue);
  info.bg_r = bg.red;
  info.bg_g = bg.green;
  info.bg_b = bg.blue;
  info.bg_a = color_info_t::nearest_color_index(bg.red, bg.green, bg.blue);
  info.sel_r = sel.red;
  info.sel_g = sel.green;
  info.sel_b = sel.blue;
  info.sel_a = color_info_t::nearest_color_index(sel.red, sel.green, sel.blue);
  info.cmt_r = cmt.red;
  info.cmt_g = cmt.green;
  info.cmt_b = cmt.blue;
  info.cmt_a = color_info_t::nearest_color_index(cmt.red, cmt.green, cmt.blue);
  info.fn_r = fn.red;
  info.fn_g = fn.green;
  info.fn_b = fn.blue;
  info.fn_a = color_info_t::nearest_color_index(fn.red, fn.green, fn.blue);
  info.kw_r = kw.red;
  info.kw_g = kw.green;
  info.kw_b = kw.blue;
  info.kw_a = color_info_t::nearest_color_index(kw.red, kw.green, kw.blue);
  info.var_r = var.red;
  info.var_g = var.green;
  info.var_b = var.blue;
  info.var_a = color_info_t::nearest_color_index(var.red, var.green, var.blue);
  info.type_r = var.red;
  info.type_g = var.green;
  info.type_b = var.blue;
  info.type_a = color_info_t::nearest_color_index(typ.red, typ.green, typ.blue);
  info.struct_r = var.red;
  info.struct_g = var.green;
  info.struct_b = var.blue;
  info.struct_a = color_info_t::nearest_color_index(strct.red, strct.green, strct.blue);
  info.ctrl_r = ctrl.red;
  info.ctrl_g = ctrl.green;
  info.ctrl_b = ctrl.blue;
  info.ctrl_a = color_info_t::nearest_color_index(ctrl.red, ctrl.green, ctrl.blue);
  
  // why does this happen?
  if (info.sel_r < 0 && info.sel_g < 0 && info.sel_b < 0) {
    info.sel_r *= -1;
    info.sel_g *= -1;
    info.sel_b *= -1;
  }

  return info;
}

int Textmate::load_theme(std::string path) {
  theme_ptr theme = theme_from_name(path, extensions);
  if (theme != NULL) {
    #ifdef DISABLE_RESOURCE_CACHING
    themes.clear();
    #endif
    themes.emplace_back(theme);
    set_theme(themes.size() - 1);
    return current_theme_id;
  }
  return 0;
}

int Textmate::load_icons(std::string path) {
  icons = icon_theme_from_name(path, extensions);
  return 0;
}

int Textmate::load_language(std::string path) {
  _previous_block_data.parser_state = NULL;
  language_info_ptr lang = language_from_file(path, extensions);
  if (lang && !lang->grammar->document().isMember("patterns")) {
    log("invalid language");
    return -1;
  }

  // log(">%s", lang->grammar->document()["scopeName"].asString().c_str());

  if (lang != NULL) {
    #ifdef DISABLE_RESOURCE_CACHING
    languages.clear();
    #endif
    languages.emplace_back(lang);
    return languages.size() - 1;
  }
  return 0;
}

int Textmate::set_language(int id)
{
  current_language_id = id;
  return id;
}

int Textmate::load_theme_data(const char* data)
{
  theme_ptr theme = theme_from_name("", extensions, "", data);
  if (theme != NULL) {
    #ifdef DISABLE_RESOURCE_CACHING
    themes.clear();
    #endif
    themes.emplace_back(theme);
    set_theme(themes.size() - 1);
    return current_theme_id;
  }
  return 0;
}

int Textmate::load_language_data(const char* data)
{
  _previous_block_data.parser_state = NULL;
  language_info_ptr lang = language_from_file("", extensions, data);
  if (lang && !lang->grammar->document().isMember("patterns")) {
    log("invalid language");
    return -1;
  }
  if (lang != NULL) {
    #ifdef DISABLE_RESOURCE_CACHING
    languages.clear();
    #endif
    languages.emplace_back(lang);
    return languages.size() - 1;
  }
  return 0;
}

language_info_ptr Textmate::language_info(int id) { return languages[id]; }

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

block_data_t* Textmate::previous_block_data()
{
  return &_previous_block_data;
}

std::vector<textstyle_t>
Textmate::run_highlighter(char *_text, language_info_ptr lang, theme_ptr theme,
                          block_data_t *block, block_data_t *prev_block,
                          block_data_t *next_block, std::vector<span_info_t> *span_infos) {

  std::vector<textstyle_t> textstyle_buffer;

  if (strlen(_text) > SKIP_PARSE_THRESHOLD) {
    return textstyle_buffer;
  }

  // printf("hl %x %s\n", block, _text);

  parse::grammar_ptr gm = lang->grammar;
  themeInfo = theme_info();

  std::map<size_t, scope::scope_t> scopes;

  std::string str = _text;
  str += "\n";

  const char *text = str.c_str();

  size_t l = str.length();
  const char *first = text;
  const char *last = first + l;

  parse::stack_ptr parser_state;
  if (block != NULL && prev_block != NULL) {
    parser_state = prev_block->parser_state;
    block->prev_comment_block = prev_block->comment_block;
    block->prev_string_block = prev_block->string_block;
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

  if (block) {
    block->parser_state = parser_state;
    block->dirty = false;
  }

  std::map<size_t, scope::scope_t>::iterator it = scopes.begin();
  size_t n = 0;

  std::vector<span_info_t> spans;

  while (it != scopes.end()) {
    n = it->first;
    scope::scope_t scope = it->second;
    std::string scopeName(scope);
    style_t style = theme->styles_for_scope(scopeName);

    scopeName = scope.back();
    // printf(">%s %d\n", scopeName.c_str());

    span_info_t span = {.start = (int16_t)n,
                        .length = (int16_t)(l - n),
                        .fg =
                            {
                                (int16_t)(255 * style.foreground.red),
                                (int16_t)(255 * style.foreground.green),
                                (int16_t)(255 * style.foreground.blue),
                                (int16_t)style.foreground.index,
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
    
  if (span_infos) {
    span_infos->clear();
    for(auto &s : spans) {
      span_infos->push_back(s);
    }
  }

  int idx = 0;
  for (int i = 0; i < l && i < MAX_STYLED_SPANS; i++) {
    textstyle_t _ts = construct_style(spans, i);
    textstyle_t *prev = NULL;
    if (textstyle_buffer.size() > 0) {
      prev = &textstyle_buffer[textstyle_buffer.size()-1];
    }

    if (!color_is_set({_ts.r, _ts.g, _ts.b, 0})) {
      if (_ts.r + _ts.g + _ts.b == 0) {
        _ts.r = themeInfo.fg_r;
        _ts.g = themeInfo.fg_g;
        _ts.b = themeInfo.fg_b;
        _ts.a = themeInfo.fg_a;
      }
    }

    if (prev != NULL && (textstyles_equal(_ts, *prev))) {
      prev->length++;
    } else {
      textstyle_buffer.push_back(_ts);
    }
  }

  if (!block) return textstyle_buffer;
  
  idx = textstyle_buffer.size();
  if (idx > 0) {
    block->comment_block =
        (textstyle_buffer[idx - 1].flags & SCOPE_COMMENT_BLOCK);
    block->string_block = (textstyle_buffer[idx - 1].flags & SCOPE_STRING);
  }

  if (next_block) {
    if (next_block->prev_string_block != block->string_block ||
        next_block->prev_comment_block != block->comment_block) {
      next_block->make_dirty();
    }
  }

  _previous_block_data.parser_state = parser_state;
  return textstyle_buffer;
}

char* Textmate::language_definition(int langId) {
  language_info_ptr lang = languages[langId];
  std::ostringstream ss;
  ss << lang->definition;
  strcpy(text_buffer, ss.str().c_str());
  return text_buffer;
}

char* Textmate::icon_for_filename(char *filename) {
  icon_t icon = icon_for_file(icons, filename, extensions);
  strcpy(text_buffer, icon.path.c_str());
  return text_buffer;
}

bool Textmate::has_running_threads() {
  return parse::grammar_t::running_threads > 0;
}

void Textmate::shutdown()
{
  extensions.clear();
  themes.clear();
  languages.clear(); 
  icons = nullptr;
}

void block_data_t::make_dirty() {
  dirty = true;
}

void doc_data_t::add_block_at(int line)
{
  blocks.insert(blocks.begin() + line, std::make_shared<block_data_t>());
}

void doc_data_t::remove_block_at(int line)
{
  blocks.erase(blocks.begin() + line);
}

void doc_data_t::make_dirty()
{
  for(auto b : blocks) {
    b->make_dirty();
  }
}

block_data_ptr doc_data_t::block_at(int line)
{
  int idx = 0;
  while (line >= blocks.size()) {
    blocks.push_back(std::make_shared<block_data_t>());
    if (idx++ > 100) break;
  }

  if (line >= 0 && line < blocks.size()) {
    return blocks[line];
  }
  return nullptr;
}

block_data_ptr doc_data_t::previous_block(int line)
{
  return block_at(line-1);
}

block_data_ptr doc_data_t::next_block(int line)
{
  return block_at(line+1);
}

