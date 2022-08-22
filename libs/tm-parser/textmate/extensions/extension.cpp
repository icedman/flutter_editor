#include "extension.h"

#include <algorithm>
#include <fstream>
#include <iostream>
#include <string>

#include "parse.h"
#include "theme.h"
#include "tinyxml2.h"
#include "util.h"

#include "themes.h"

const char* defaultTheme = THEME_MONOKAI;

static std::map<std::string, struct extension_t> mappedExtensions;

static bool file_exists(const char* path)
{
    bool exists = false;
    FILE* fp = fopen(path, "r");
    if (fp) {
        exists = true;
        fclose(fp);
    }
    return exists;
}

#ifndef DISABLE_PLIST_GRAMMARS
void parseXMLElement(Json::Value& target, tinyxml2::XMLElement* element);
void parseXMLElementArray(Json::Value& target, tinyxml2::XMLElement* element);

void parseXMLElementArray(Json::Value& target, tinyxml2::XMLElement* element)
{
    if (!element)
        return;
    tinyxml2::XMLElement* pChild = element->FirstChildElement();
    int idx = 0;
    while (pChild) {
        std::string name = pChild->Name();
        if (name == "string") {
            target[idx++] = pChild->GetText();
        }
        if (name == "dict") {
            Json::Value val;
            parseXMLElement(val, pChild);
            target[idx++] = val;
        }
        if (name == "array") {
            Json::Value val;
            parseXMLElementArray(val, pChild);
            target[idx++] = val;
        }
        pChild = pChild->NextSiblingElement();
    }
}

void parseXMLElement(Json::Value& target, tinyxml2::XMLElement* element)
{
    if (!element)
        return;
    tinyxml2::XMLElement* pChild = element->FirstChildElement();

    std::string key = "";
    while (pChild) {
        std::string name = pChild->Name();
        if (name == "key") {
            key = pChild->GetText();
        }
        if (name == "string") {
            std::string v = pChild->GetText();
            target[key.c_str()] = v.c_str();
        }
        if (name == "dict") {
            Json::Value val;
            parseXMLElement(val, pChild);
            target[key.c_str()] = val;
        }
        if (name == "array") {
            Json::Value val;
            parseXMLElementArray(val, pChild);
            target[key.c_str()] = val;
        }
        pChild = pChild->NextSiblingElement();
    }
}
#endif

// std::string convertTMLanguagetoJSON(const char *path) {
Json::Value load_plist_or_json(std::string path)
{
    if (path.find(".json") != std::string::npos) {
        return parse::loadJson(path.c_str());
    }
    Json::Value result;

    #ifndef DISABLE_PLIST_GRAMMARS
    tinyxml2::XMLDocument doc;
    doc.LoadFile(path.c_str());
    tinyxml2::XMLElement* pRoot = doc.RootElement();
    if (pRoot == nullptr)
        return result;

    parseXMLElement(result, pRoot->FirstChildElement());
    #endif
    return result;
}

bool is_extension_available(const std::string id)
{
    // printf(">find %s\n", id.c_str());
    return mappedExtensions.find(id) != mappedExtensions.end();
}

void reset_extension_cache() { mappedExtensions.clear(); }

void load_extensions(const std::string _path,
    std::vector<struct extension_t>& extensions)
{
    char* cpath = (char*)malloc(_path.length() + 1 * sizeof(char));
    strcpy(cpath, _path.c_str());
    expand_path((char**)(&cpath));

    const std::string path(cpath);
    free(cpath);

    // Json::Value contribs;
    log("loading extensions in %s\n", path.c_str());
    // std::vector<std::string> filter = { "themes", "iconThemes", "languages" };

    for (const auto& extensionPath : enumerate_dir(path)) {
        std::string package = extensionPath + "/package.json";
        std::string packageNLS = extensionPath + "/package.nls.json";

        // log("extension: %s\n", package.c_str());

        struct extension_t ex = { .id = "",
            .publisher = "",
            .path = extensionPath,
            .hasThemes = false,
            .hasIcons = false,
            .hasGrammars = false,
            .hasCommands = false,
            .addToHistory = false };

        ex.nlsPath = packageNLS;
        ex.nlsLoaded = false;
        ex.package = parse::loadJson(package);
        if (!ex.package.isObject()) {
            continue;
        }
        ex.name = ex.package["name"].asString();

        std::string publisher;
        if (ex.package.isMember("publisher")) {
            publisher = ex.package["publisher"].asString();
            ex.id = publisher;
            ex.id += ".";
            ex.id += ex.package["name"].asString();
        }

        log("%s\n", ex.id.c_str());

        if (ex.package.isMember("__metadata") && ex.package["__metadata"].isMember("publisherDisplayName")) {
            publisher = ex.package["__metadata"]["publisherDisplayName"].asString();
        }
        if (publisher.length() > 0) {
            publisher = package_string(ex, publisher);
            ex.publisher = publisher;
        }

        bool append = false;
        if (ex.package.isMember("contributes")) {
            if (ex.package["contributes"].isMember("themes")) {
                ex.hasThemes = true;
            }
            if (ex.package["contributes"].isMember("iconThemes")) {
                ex.hasIcons = true;
            }
            if (ex.package["contributes"].isMember("languages")) {
                ex.hasGrammars = true;
            }
            if (ex.hasThemes || ex.hasIcons || ex.hasGrammars) {
                append = true;
            }

            // extract grammar infos
            if (ex.hasGrammars) {
                Json::Value grammars = ex.package["contributes"]["grammars"];
                if (grammars.isArray()) {
                    for (int i = 0; i < grammars.size(); i++) {
                        grammar_info_t gi;
                        if (grammars[i].isMember("language") && grammars[i].isMember("scopeName") && grammars[i].isMember("path")) {
                            gi.language = grammars[i]["language"].asString();
                            gi.scopeName = grammars[i]["scopeName"].asString();
                            gi.path = extensionPath + "/" + grammars[i]["path"].asString();
                            ex.grammars.push_back(gi);
                        }
                    }
                }
            }
        }

        if (append) {
            if (ex.package["name"].asString() == "meson") {
                log(ex.package["name"].asString().c_str());
                log("extensions path %s", ex.path.c_str());
            }
            #ifndef DISABLE_RESOURCE_CACHING
            mappedExtensions.emplace(ex.id, ex);
            #endif
            // extensions.emplace_back(ex);
        } else {
            // printf(">exclude %s\n", ex.path.c_str());
        }
    }

    extensions.clear();
    for (auto it = mappedExtensions.begin(); it != mappedExtensions.end(); it++) {
        extensions.emplace_back(it->second);
    }

    // std::cout << contribs;
    parse::set_extensions(&extensions);
}

static bool load_language_configuration(const std::string path,
    language_info_ptr lang)
{
    Json::Value root = parse::loadJson(path);
    if (root.empty()) {
        log("unable to load configuration file %s", path.c_str());
        return false;
    }

    lang->definition = root;

    if (root.isMember("comments")) {
        Json::Value comments = root["comments"];

        if (comments.isMember("lineComment")) {
            lang->lineComment = comments["lineComment"].asString();
        }

        if (comments.isMember("blockComment")) {
            Json::Value blockComment = comments["blockComment"];
            if (blockComment.isArray() && blockComment.size() == 2) {
                std::string beginComment = comments["blockComment"][0].asString();
                std::string endComment = comments["blockComment"][1].asString();
                if (beginComment.length() && endComment.length()) {
                    lang->blockCommentStart = beginComment;
                    lang->blockCommentEnd = endComment;
                }
            }
        }
    }

    if (root.isMember("brackets")) {
        Json::Value brackets = root["brackets"];
        if (brackets.isArray()) {
            for (int i = 0; i < brackets.size(); i++) {
                Json::Value pair = brackets[i];
                if (pair.isArray() && pair.size() == 2) {
                    if (pair[0].isString() && pair[1].isString()) {
                        lang->bracketOpen.push_back(pair[0].asString());
                        lang->bracketClose.push_back(pair[1].asString());
                    }
                }
            }
            lang->brackets = lang->bracketOpen.size();
            lang->hasCurly = false;
            lang->hasRound = false;
            lang->hasSquare = false;
            for (auto& b : lang->bracketOpen) {
                lang->hasCurly |= (b == "{");
                lang->hasRound |= (b == "(");
                lang->hasSquare |= (b == "[");
            }
        }
    }

    if (root.isMember("autoClosingPairs")) {
        Json::Value pairs = root["autoClosingPairs"];
        if (pairs.isArray()) {
            for (int i = 0; i < pairs.size(); i++) {
                Json::Value pair = pairs[i];
                if (pair.isObject()) {
                    if (pair.isMember("open") && pair.isMember("close")) {
                        lang->pairOpen.push_back(pair["open"].asString());
                        lang->pairClose.push_back(pair["close"].asString());
                    }
                }
            }
            lang->pairs = lang->pairOpen.size();
        }
    }

    return true;
}

language_info_ptr
language_from_file(const std::string path,
    std::vector<struct extension_t>& extensions,
    const char* data)
{
    static std::map<std::string, language_info_ptr> cache;
    language_info_ptr lang = std::make_shared<language_info_t>();

    std::set<char> delims = { '/', '\\' };
    std::vector<std::string> spath = split_path(path, delims);
    std::string fileName = spath.back();

    std::set<char> delims_file = { '.' };
    std::vector<std::string> sfile = split_path(fileName, delims_file);

    std::string suffix = ".";
    suffix += sfile.back();

    log("%s file: %s suffix: %s", path.c_str(), fileName.c_str(), suffix.c_str());

    auto it = cache.find(suffix);
    if (it != cache.end()) {
        return it->second;
    }

    // check cache
    struct extension_t resolvedExtension;
    std::string resolvedLanguage;
    Json::Value resolvedGrammars;
    Json::Value resolvedConfiguration;

    for (auto& ext : extensions) {
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

            if (!lang.isMember("file")) {
            }

            bool found = false;
            // if (lang.isMember("filenames")) {
            //     Json::Value fns = lang["filenames"];
            //     for (int j = 0; j < fns.size(); j++) {
            //         Json::Value fn = fns[j];
            //         if (fn.asString() == fileName) {
            //             resolvedExtension = ext;
            //             resolvedLanguage = lang["id"].asString();
            //             resolvedGrammars = contribs["grammars"];
            //             found = true;
            //             break;
            //         }
            //     }
            // }

            if (!found && lang.isMember("extensions")) {
                Json::Value exts = lang["extensions"];
                for (int j = 0; j < exts.size(); j++) {
                    Json::Value ex = exts[j];

                    if (ex.asString() == suffix) {
                        resolvedExtension = ext;
                        resolvedLanguage = lang["id"].asString();
                        resolvedGrammars = contribs["grammars"];

                        // log("resolved %s", resolvedLanguage.c_str());
                        // log("resolved path %s", ext.path.c_str());
                        found = true;
                        break;
                    }
                }
            }

            if (found) {
                if (lang.isMember("configuration")) {
                    resolvedConfiguration = lang["configuration"];
                }
                ext.addToHistory = true;
                break;
            }
        }

        if (!resolvedLanguage.empty())
            break;
    }

    std::string scopeName = "source.";
    scopeName += resolvedLanguage;
    log("scopeName: %s", scopeName.c_str());

    if (!resolvedLanguage.empty()) {

        for (int i = 0; i < resolvedGrammars.size(); i++) {
            Json::Value g = resolvedGrammars[resolvedGrammars.size() - 1 - i];
            bool foundGrammar = false;

            if (g.isMember("language") && g["language"].asString().compare(resolvedLanguage) == 0) {
                foundGrammar = true;
            }

            if (foundGrammar) {
                std::string path = resolvedExtension.path + "/" + g["path"].asString();

                log("grammar: %s\n", path.c_str());
                log("grammar: %s", path.c_str());
                log("extension: %s", resolvedExtension.path.c_str());

                lang->grammar = parse::parse_grammar(load_plist_or_json(path));
                lang->id = resolvedLanguage;

                // language configuration
                if (!resolvedConfiguration.empty()) {
                    path = resolvedExtension.path + "/" + resolvedConfiguration.asString();
                } else {
                    path = resolvedExtension.path + "/language-configuration.json";
                }

                load_language_configuration(path, lang);

                log("language configuration: %s", path.c_str());
                // std::cout << "langauge matched" << lang->id << std::endl;
                // std::cout << path << std::endl;

                // don't cache..? causes problem with highlighter thread
                #ifndef DISABLE_RESOURCE_CACHING
                cache.emplace(suffix, lang);
                #endif

                return lang;
            }
        }
    }

    if (!lang->grammar) {
        Json::Value empty;

        if (data != NULL) {
            Json::Reader reader;
            reader.parse(data, empty);
        }

        empty["scopeName"] = suffix;
        lang->id = suffix;
        lang->grammar = parse::parse_grammar(empty);
    }

    // if (suffix != ".") {
    //     cache.emplace(suffix, lang);
    // }
    return lang;
}

icon_theme_ptr
icon_theme_from_name(const std::string path,
    std::vector<struct extension_t>& extensions)
{
    icon_theme_ptr icons = std::make_shared<icon_theme_t>();

    std::string theme_path = path;
    std::string icons_path;
    bool found = false;

    for (auto& ext : extensions) {
        if (!ext.hasIcons)
            continue;
        Json::Value contribs = ext.package["contributes"];
        // if (!contribs.isMember("iconThemes")) {
        //     continue;
        // }

        Json::Value themes = contribs["iconThemes"];
        for (int i = 0; i < themes.size(); i++) {
            Json::Value theme = themes[i];
            if (theme["id"].asString() == theme_path || theme["label"].asString() == theme_path) {
                theme_path = ext.path + "/" + theme["path"].asString();
                icons_path = theme_path;

                std::set<char> delims = { '/', '\\' };
                std::vector<std::string> spath = split_path(icons_path, delims);
                if (spath.size() > 0) {
                    spath.pop_back();
                }
                icons_path = join(spath, '/');

                icons->path = ext.path;
                found = true;
                break;
            }
        }

        if (found) {
            ext.addToHistory = true;
            break;
        }
    }

    if (!found) {
        return icons;
    }

    Json::Value json = parse::loadJson(theme_path);
    icons->icons_path = icons_path;

    // if (json.isMember("fonts")) {
    //     Json::Value fonts = json["fonts"];
    //     Json::Value font = fonts[0];
    //     Json::Value family = font["id"];
    //     Json::Value src = font["src"][0];
    //     Json::Value src_path = src["path"];
    //     std::string real_font_path = icons_path + '/' + src_path.asString();
    //     printf("%s\n", real_font_path.c_str());
    // }

    icons->definition = json;
    return icons;
}

theme_ptr theme_from_name(const std::string path,
    std::vector<struct extension_t>& extensions,
    std::string uiTheme,
    const char* data)
{
    std::string theme_path = path;
    std::string ext_path = path;
    bool found = false;

    log("finding theme %s", theme_path.c_str());

    // theme_path =
    // "C:\\Users\\iceman\\.editor\\extensions\\dracula-theme.theme-dracula-2.24.0\\theme\\dracula-soft.json";

    if (!file_exists(theme_path.c_str())) {
        for (auto& ext : extensions) {
            if (!ext.hasThemes)
                continue;
            Json::Value contribs = ext.package["contributes"];

            Json::Value themes = contribs["themes"];
            for (int i = 0; i < themes.size(); i++) {
                Json::Value theme = themes[i];

                std::string theme_ui;
                if (theme.isMember("uiTheme")) {
                    theme_ui = theme["uiTheme"].asString();
                }

                // log("theme %s\n", theme["id"].asString().c_str());
                    
                if (theme["id"].asString() == theme_path || theme["label"].asString() == theme_path) {
                    theme_path = ext.path + "/" + theme["path"].asString();
                    if (theme.isMember("uiTheme") && uiTheme != "" && theme["uiTheme"].asString() != uiTheme) {
                        continue;
                    }

                    log("theme: %s [%s]\n", ext.path.c_str(), theme_path.c_str());
                    ext_path = ext.path;
                    found = true;
                    break;
                }
            }

            if (found) {
                // ext.addToHistory = true;
                break;
            }
        }
    }

    Json::Value themeItem = parse::loadJson(theme_path);

    if (!themeItem.isMember("colors") && !themeItem.isMember("tokenColors")) {
        Json::Reader reader;
        if (data == NULL) {
            reader.parse(defaultTheme, themeItem);
        } else {
            reader.parse(data, themeItem);
        }
        if (themeItem.isMember("name")) {
            uiTheme = themeItem["name"].asString();
        }
    }

    // std::cout << themeItem << std::endl;

    themeItem["uuid"] = theme_path + "::" + uiTheme;

    // include
    if (themeItem.isMember("include")) {
        std::vector<std::string> ff = split(theme_path, '/');
        if (ff.size())
            ff.pop_back();
        std::string filename = join(ff, '/');
        filename += "/" + themeItem["include"].asString();
#if 1
        Json::Value inc = parse::loadJson(filename);
        std::cout << inc << std::endl;
        if (inc.isMember("colors")) {
            if (!themeItem.isMember("colors")) {
                themeItem["colors"] = inc["colors"];
            } else {
                std::vector<std::string> keys = inc["colors"].getMemberNames();
                for (auto k : keys) {
                    themeItem["colors"][k] = inc["colors"][k];
                }
            }
        }
        if (inc.isMember("tokenColors")) {
            if (!themeItem.isMember("tokenColors")) {
                themeItem["tokenColors"] = inc["tokenColors"];
            } else {
                for (auto k : inc["tokenColors"]) {
                    themeItem["tokenColors"].append(k);
                }
            }
        }
#endif
    }

    theme_ptr theme = parse_theme(themeItem);
    return theme;
}

std::string to_utf8(uint32_t cp)
{
    // https://stackoverflow.com/questions/28534221/c-convert-asii-escaped-unicode-string-into-utf8-string/47734595.

    std::string result;

    int count;
    if (cp <= 0x007F)
        count = 1;
    else if (cp <= 0x07FF)
        count = 2;
    else if (cp <= 0xFFFF)
        count = 3;
    else if (cp <= 0x10FFFF)
        count = 4;
    else
        return result; // or throw an exception

    result.resize(count);

    if (count > 1) {
        for (int i = count - 1; i > 0; --i) {
            result[i] = (char)(0x80 | (cp & 0x3F));
            cp >>= 6;
        }

        for (int i = 0; i < count; ++i)
            cp |= (1 << (7 - i));
    }

    result[0] = (char)cp;

    return result;
}

std::string wstring_convert(std::string str)
{
    std::string::size_type startIdx = 0;
    do {
        startIdx = str.find("x\\", startIdx);
        if (startIdx == std::string::npos)
            break;
        std::string::size_type endIdx = str.length();
        // str.find_first_not_of("0123456789abcdefABCDEF", startIdx+2);
        if (endIdx == std::string::npos)
            break;
        std::string tmpStr = str.substr(startIdx + 2, endIdx - (startIdx + 2));
        std::istringstream iss(tmpStr);

        uint32_t cp;
        if (iss >> std::hex >> cp) {
            std::string utf8 = to_utf8(cp);
            str.replace(startIdx, 2 + tmpStr.length(), utf8);
            startIdx += utf8.length();
        } else
            startIdx += 2;
    } while (true);

    return str;
}

icon_t icon_for_file(icon_theme_ptr icons, std::string filename,
    std::vector<struct extension_t>& _extensions)
{
    icon_t res;
    res.path = "";
    if (!icons) {
        return res;
    }

    std::set<char> delims = { '.' };
    std::vector<std::string> spath = split_path(filename, delims);

    std::string _suffix = spath.back();
    std::string cacheId = _suffix;

    static std::map<std::string, icon_t> cache;

    Json::Value definitions = icons->definition["iconDefinitions"];
    Json::Value fileExtensions = icons->definition["fileExtensions"];
    Json::Value fonts = icons->definition["fonts"];

    std::string file;
    std::string folder;

    if (icons->definition.isMember("file")) {
        file = icons->definition["file"].asString();
    }
    if (icons->definition.isMember("folder")) {
        folder = icons->definition["folder"].asString();
    }

    if (definitions.isMember(_suffix)) {
        Json::Value iconDef = definitions[_suffix];
        if (iconDef.isMember("iconPath")) {
            res.path = icons->icons_path + "/" + iconDef["iconPath"].asString();
            res.svg = true;
            #ifndef DISABLE_RESOURCE_CACHING
            cache.emplace(_suffix, res);
            #endif
            return res;
        }
    }

    std::string iconName;

    // printf("finding icon %s\n", _suffix.c_str());

    auto it = cache.find(filename);
    if (it != cache.end()) {
        // return it->second;
    }

    Json::Value fileNames = icons->definition["fileNames"];
    std::string fn = filename;
    std::transform(fn.begin(), fn.end(), fn.begin(),
        [](unsigned char c) { return std::tolower(c); });
    // printf(">[%s] [%s]\n", iconName.c_str(), fn.c_str());
    if (!iconName.length() && fileNames.isMember(fn)) {
        iconName = fileNames[fn].asString();
        cacheId = filename;
        // printf("fileNames %s\n", iconName.c_str());
    }

    if (!iconName.length()) {
        it = cache.find(_suffix);
        if (it != cache.end()) {
            return it->second;
        }
    }

    Json::Value extensions = icons->definition["fileExtensions"];
    if (!iconName.length() && extensions.isMember(_suffix)) {
        iconName = extensions[_suffix].asString();
        cacheId = _suffix;
        // printf("extensions %s\n", iconName.c_str());
    }

    if (!iconName.length()) {
        Json::Value languageIds = icons->definition["languageIds"];
        std::string _fileName = "file." + _suffix;
        language_info_ptr lang = language_from_file(_fileName.c_str(), _extensions);
        if (lang) {
            if (languageIds.isMember(lang->id)) {
                iconName = languageIds[lang->id].asString();
            }
        }

        if (!iconName.length()) {
            if (languageIds.isMember(_suffix)) {
                iconName = languageIds[_suffix].asString();
            }
        }
    }

    if (!definitions.isMember(iconName)) {
        iconName = file;
    }

    // if (!iconName.length()) {
    //     iconName = file;
    // }

    if (definitions.isMember(iconName)) {
        Json::Value iconDef = definitions[iconName];

        if (iconDef.isMember("iconPath")) {
            res.path = icons->icons_path + "/" + iconDef["iconPath"].asString();
            if (file_exists(res.path.c_str())) {
                res.svg = true;
                #ifndef DISABLE_RESOURCE_CACHING
                cache.emplace(cacheId, res);
                #endif
                return res;
            }
        }

        if (iconDef.isMember("fontCharacter")) {
            res.character = iconDef["fontCharacter"].asString();
            std::string fontId = iconDef["fontId"].asString();

            for (int i = 0; i < fonts.size(); i++) {
                Json::Value font = fonts[i];
                if (!font.isMember("id"))
                    continue;

                std::string id = font["id"].asString();
                if (id == fontId && font.isMember("src") && font["src"].size()) {
                    Json::Value src = font["src"][0]["path"];
                    res.path = icons->icons_path + "/" + src.asString();
                    res.path += ";";

                    std::string fontCharacter = "x";
                    fontCharacter += res.character;
                    fontCharacter += "x";
                    fontCharacter = wstring_convert(fontCharacter);
                    res.path += fontCharacter;

                    res.svg = false;
                    break;
                }
            }
        }

        return res;
    }

    // printf("not found %s\n", filename.c_str());
    return res;
}

icon_t icon_for_folder(icon_theme_ptr icons, std::string folder,
    std::vector<struct extension_t>& _extensions)
{
    icon_t res;
    return res;
}

bool theme_is_dark(theme_ptr theme)
{
    color_info_t clr;
    theme->theme_color("editor.background", clr);
    return color_is_dark(clr);
}

bool color_is_dark(color_info_t& color)
{
    return 0.30 * color.red + 0.59 * color.green + 0.11 * color.blue < 0.5;
}

std::string package_string(struct extension_t& extension, std::string str)
{
    if (!extension.nlsLoaded) {
        extension.nls = parse::loadJson(extension.nlsPath);
    }

    if (str.length() > 2 && str[0] == '%') {
        std::string _str = std::string(str.c_str() + 1, str.length() - 2);
        // printf(">%s\n", _str.c_str());
        if (extension.nls.isMember(_str)) {
            return extension.nls[_str].asString();
        }
    }

    return str;
}
