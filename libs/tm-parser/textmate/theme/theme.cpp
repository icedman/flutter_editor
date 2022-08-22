#include "theme.h"
#include "colors.h"
#include "util.h"

#include <iostream>

static theme_t* current_parsed_theme = 0;
static std::map<int, color_info_t> trueColors;

static int termColorCount = 256;
static color_t* termColors = (color_t*)termColors256;

int nearest_color(int r, int g, int b)
{
    color_info_t c(r, g, b, 255);

    int idx = -1;
    long d = 0;
    for (int i = 0; i < termColorCount; i++) {
        const color_t clr = termColors[i];
        int rr = r - clr.r;
        int gg = g - clr.g;
        int bb = b - clr.b;
        long dd = (rr * rr) + (gg * gg) + (bb * bb);
        if (idx == -1 || d > dd) {
            d = dd;
            idx = i;
        }
    }

    return idx;
}

int color_info_t::set_term_color_count(int count)
{
    termColorCount = count == 8 ? 8 : 256;
    termColors = count == 8 ? (color_t*)termColors8 : (color_t*)termColors256;
    return termColorCount;
}

int color_info_t::nearest_color_index(int red, int green, int blue)
{
    return nearest_color(red, green, blue);
}

/*
https://code.visualstudio.com/api/references/theme-color
*/

std::string scope_pop_child(std::string string)
{
    std::string res;

    const char* start = string.c_str();
    const char* end = start + string.length();

    std::string str;
    while (end != start) {
        char c = *end;
        if (c == '.') {
            break;
        }
        end--;
    }

    if (start != end) {
        res.assign(start, end - start);
    }

    return res;
}

static void get_settings_string(Json::Value const& item, std::string& target)
{
    if (!item.isString()) {
        return;
    }
    target = item.asString();
}

static void get_settings_float(Json::Value const& item, float* target)
{
    if (!item.isString()) {
        return;
    }
    *target = parse_float(item.asString().c_str());
}

static void get_settings_color(Json::Value const& item, color_info_t* target)
{
    if (!item.isString()) {
        return;
    }
    uint32_t color;
    float rgba[4];

    parse_color(item.asString().c_str(), &color);
    color_to_rgba(rgba, color);

    target->red = rgba[0];
    target->green = rgba[1];
    target->blue = rgba[2];
    target->alpha = rgba[3];
    target->index = nearest_color(target->red * 255, target->green * 255, target->blue * 255);

    if (current_parsed_theme) {
        if (current_parsed_theme->colorIndices.find(target->index) == current_parsed_theme->colorIndices.end()) {
            color_info_t clr;
            clr.red = target->red;
            clr.green = target->green;
            clr.blue = target->blue;
            clr.alpha = target->alpha;
            clr.index = target->index;
            current_parsed_theme->colorIndices.emplace(target->index, clr);
        }
    }

    // std::cout<<item.asString()<<std::endl;
}

static style_t parse_style(Json::Value const& settings)
{
    style_t res;
    get_settings_string(settings["fontName"], res.font_name);
    get_settings_float(settings["fontSize"], &res.font_size);
    get_settings_color(settings["foreground"], &res.foreground);
    get_settings_color(settings["background"], &res.background);
    get_settings_color(settings["caret"], &res.caret);
    get_settings_color(settings["selection"], &res.selection);
    get_settings_color(settings["invisibles"], &res.invisibles);
    return res;
}

theme_t::shared_styles_t::shared_styles_t(Json::Value const& themeItem)
{
    setup_styles(themeItem);
}

theme_t::shared_styles_t::~shared_styles_t() {}

static bool color_is_dark(color_info_t& color)
{
    return 0.30 * color.red + 0.59 * color.green + 0.11 * color.blue < 0.5;
}

void theme_t::shared_styles_t::setup_styles(Json::Value const& themeItem)
{
    _styles.clear();

    Json::Value settings;
    if (themeItem.isMember("settings")) {
        settings = themeItem["settings"];
    } else {
        settings = themeItem["tokenColors"];
    }
    for (int i = 0; i < settings.size(); i++) {
        Json::Value item = settings[i];

        if (item.isMember("scope")) {
            item["scope"] = "default";
            // continue;
        }

        Json::Value scope = settings[i]["scope"];

        // std::cout << item << std::endl;

        if (scope.isString()) {
            _styles.push_back(parse_styles(item, scope.asString()));
        } else if (scope.isArray()) {
            for (int j = 0; j < scope.size(); j++) {
                _styles.push_back(parse_styles(item, scope[j].asString()));
            }
        }
    }

    // find global background/foreground
    // We assume that the first style is the unscoped root style

    if (!_styles.empty()) {
        _foreground = _styles[0].foreground;
        _background = _styles[0].background;
    }
}

style_t theme_t::shared_styles_t::parse_styles(Json::Value const& item,
    std::string scope_selector)
{
    style_t res;

    Json::Value settings = item["settings"];

    if (!item.isObject()) {
        return res;
    }

    // std::cout << "parsing styles" << std::endl;

    res = parse_style(settings);
    res.scope_selector = scope_selector;

    // bool flag;
    // res.misspelled = plist::get_key_path(plist, "settings.misspelled", flag) ?
    // (flag ? bool_true : bool_false) : bool_unset;

    if (settings.isMember("fontStyle")) {
        std::string fontStyle = settings["fontStyle"].asString();

        bool hasPlain = fontStyle.find("plain") != std::string::npos;
        bool hasBold = fontStyle.find("bold") != std::string::npos;
        bool hasItalic = fontStyle.find("italic") != std::string::npos;
        bool hasUnderline = fontStyle.find("underline") != std::string::npos;
        bool hasStrikethrough = fontStyle.find("strikethrough") != std::string::npos;

        res.bold = hasBold ? bool_true : (hasPlain ? bool_false : bool_unset);
        res.italic = hasItalic ? bool_true : (hasPlain ? bool_false : bool_unset);
        res.underlined = hasUnderline ? bool_true : (hasPlain ? bool_false : bool_unset);
        res.strikethrough = hasStrikethrough ? bool_true : (hasPlain ? bool_false : bool_unset);
    }

    return res;
}

theme_t::theme_t(Json::Value const& themeItem, std::string const& fontName,
    float fontSize)
    : _font_name(fontName)
    , _font_size(fontSize)
{
    current_parsed_theme = this;
    _styles = find_shared_styles(themeItem);

    setup_global_style(themeItem);
    _cache.clear();

    bundle = themeItem;

    // _cache.set_empty_key(scope::scope_t{});
}

std::string theme_t::theme_color_string(std::string const& name)
{
    if (bundle.isMember("colors")) {
        Json::Value colors = bundle["colors"];
        return colors[name].asString();
    }
    return "";
}

void theme_t::theme_color(std::string const& name, color_info_t& color)
{
    if (bundle.isMember("colors")) {
        Json::Value colors = bundle["colors"];
        current_parsed_theme = this;
        get_settings_color(colors[name], &color);
    } else {
        color.red = -1;
        color.green = 0;
        color.blue = -0;
    }
}

void theme_t::setup_global_style(Json::Value const& themeItem)
{
    // unscoped settings
    if (!themeItem.isMember("settings")) {
        return;
    }

    Json::Value settings = themeItem["settings"];
    for (int i = 0; i < settings.size(); i++) {
        Json::Value item = settings[i];
        if (!item.isMember("scope")) {
            style_t res = parse_style(item);
            if (!res.foreground.is_blank()) {
            }
        }
    }
}

color_info_t theme_t::foreground() const
{
    return _styles->_foreground;
}

color_info_t theme_t::background(std::string const& fileType) const
{
    return _styles->_background;
}

theme_t::shared_styles_ptr
theme_t::find_shared_styles(Json::Value const& themeItem)
{
    shared_styles_ptr res = std::make_shared<shared_styles_t>(themeItem);
    return res;

    // static std::map<std::string, theme_t::shared_styles_ptr> Cache;
    // std::string const& uuid = themeItem["scope"].asString();
    // auto theme = Cache.find(uuid);
    // if (theme == Cache.end())
    //     theme = Cache.emplace(uuid, std::make_shared<shared_styles_t>(themeItem)).first;
    // return theme->second;
}

// ==============
// = Public API =
// ==============

theme_ptr parse_theme(Json::Value& themeItem)
{
    // std::cout << themeItem << std::endl;
    static std::map<std::string, theme_ptr> Cache;
    std::string const& uuid = themeItem["uuid"].asString();

    // printf("theme uuid: %s\n", uuid.c_str());

    // if (uuid == "") {
    //     return std::make_shared<theme_t>(themeItem);
    // }

    auto theme = Cache.find(uuid);
    if (theme == Cache.end()) {
        theme_ptr _theme = std::make_shared<theme_t>(themeItem);
        theme = Cache.emplace(uuid, _theme).first;
    }

    return theme->second;
}

style_t const& theme_t::styles_for_scope(scope::scope_t const& scope)
{
    size_t hash = scope.hash();

    auto styles = _cache.find(hash);
    if (styles != _cache.end()) {
        return styles->second;
    }

    std::multimap<double, style_t> ordering;

    for (auto const& it : _styles->_styles) {
        double rank = 0;
        if (it.scope_selector.does_match(scope, &rank)) {
            // std::cout << to_s(it.scope_selector) << ":" << rank << std::endl;
            ordering.emplace(rank, it);
        }
    }

    style_t base(scope::selector_t(), _font_name, _font_size);
    for (auto const& it : ordering) {
        base += it.second;
    }

    // static style_t _res;
    style_t _res = style_t(
        base.font_name,
        base.font_size,
        base.foreground,
        base.background,
        base.caret,
        base.selection,
        base.bold,
        base.italic,
        base.underlined,
        base.strikethrough,
        base.misspelled);

    _cache.emplace(hash, _res);
    return _cache.find(hash)->second;
}

style_t& style_t::operator+=(style_t const& rhs)
{
    font_name = rhs.font_name != NULL_STR ? rhs.font_name : font_name;
    // font_size  = rhs.font_size > 0            ? rhs.font_size : font_size * fabs(rhs.font_size);

    foreground = rhs.foreground.is_blank() ? foreground : rhs.foreground;
    background = rhs.background.is_blank() ? background : rhs.background;
    // background = rhs.background.is_blank()    ? background : blend(background, rhs.background);
    caret = rhs.caret.is_blank() ? caret : rhs.caret;
    selection = rhs.selection.is_blank() ? selection : rhs.selection;
    invisibles = rhs.invisibles.is_blank() ? invisibles : rhs.invisibles;

    bold = rhs.bold == bool_unset ? bold : rhs.bold;
    italic = rhs.italic == bool_unset ? italic : rhs.italic;
    underlined = rhs.underlined == bool_unset ? underlined : rhs.underlined;
    strikethrough = rhs.strikethrough == bool_unset ? strikethrough : rhs.strikethrough;
    misspelled = rhs.misspelled == bool_unset ? misspelled : rhs.misspelled;
    return *this;
}
