#ifndef EXTENSION_H
#define EXTENSION_H

#include "grammar.h"
#include "json/json.h"
#include "reader.h"
#include "theme.h"

struct grammar_info_t {
    std::string language;
    std::string scopeName;
    std::string path;
};

struct extension_t {
    std::string id;
    std::string publisher;
    std::string name;
    std::string path;
    std::string base_path;
    std::string nlsPath;
    Json::Value package;
    Json::Value nls;

    bool hasThemes;
    bool hasIcons;
    bool hasGrammars;
    bool hasCommands;
    bool addToHistory;
    bool nlsLoaded;

    std::vector<grammar_info_t> grammars;
};

struct language_info_t {
    std::string id;
    std::string blockCommentStart;
    std::string blockCommentEnd;
    std::string lineComment;

    bool brackets;
    std::vector<std::string> bracketOpen;
    std::vector<std::string> bracketClose;

    bool hasCurly;
    bool hasRound;
    bool hasSquare;

    bool pairs;
    std::vector<std::string> pairOpen;
    std::vector<std::string> pairClose;

    parse::grammar_ptr grammar;

    Json::Value definition;
};

struct icon_theme_t {
    std::string path;
    std::string icons_path;
    Json::Value definition;
};

struct icon_t {
    std::string path;
    std::string character;
    int r;
    int g;
    int b;
    bool svg;
};

typedef std::shared_ptr<language_info_t> language_info_ptr;
typedef std::shared_ptr<icon_theme_t> icon_theme_ptr;

bool is_extension_available(const std::string id);
void reset_extension_cache();

void load_settings(const std::string path, Json::Value& settings);
void load_extensions(const std::string path,
    std::vector<struct extension_t>& extensions);

Json::Value load_plist_or_json(std::string path);

icon_theme_ptr
icon_theme_from_name(const std::string path,
    std::vector<struct extension_t>& extensions);
theme_ptr theme_from_name(const std::string path,
    std::vector<struct extension_t>& extensions,
    std::string uiTheme = "",
    const char* data = NULL);
language_info_ptr
language_from_file(const std::string path,
    std::vector<struct extension_t>& extensions,
    const char* data = NULL);

icon_t icon_for_file(icon_theme_ptr icons, std::string file,
    std::vector<struct extension_t>& extensions);
icon_t icon_for_folder(icon_theme_ptr icons, std::string folder,
    std::vector<struct extension_t>& extensions);

bool color_is_dark(color_info_t& color);
bool theme_is_dark(theme_ptr theme);

std::string package_string(struct extension_t& extension, std::string str);

typedef std::vector<extension_t> extension_list;

#endif // EXTENSION_H
