#ifndef THEME_THEME_H
#define THEME_THEME_H

#include <memory>
#include <vector>

#include "defines.h"
#include "scope.h"

#include "json/json.h"

struct theme_t;
typedef std::shared_ptr<theme_t> theme_ptr;

struct color_info_t {
    color_info_t()
        : red(-1)
        , green(0)
        , blue(0)
        , alpha(1)
        , index(0)
    {
    }
    color_info_t(double red, double green, double blue, double alpha = 1)
        : red(red)
        , green(green)
        , blue(blue)
        , alpha(alpha)
        , index(0)
    {
    }

    bool is_blank() const { return red < 0; }
    bool is_opaque() const { return alpha == 1; };

    double red, green, blue, alpha;
    int index; // terminal color index (0-200)

    static int set_term_color_count(int count);
    static int nearest_color_index(int red, int green, int blue);
};

enum bool_t {
    bool_true,
    bool_false,
    bool_unset
};

struct style_t {

    style_t(std::string const& fontName,
        float fontSize,
        color_info_t foreground,
        color_info_t background,
        color_info_t caret,
        color_info_t selection,
        bool_t bold,
        bool_t italic,
        bool_t underlined,
        bool_t strikethrough,
        bool_t misspelled)
        : font_name(fontName)
        , font_size(fontSize)
        , foreground(foreground)
        , background(background)
        , caret(caret)
        , selection(selection)
        , bold(bold)
        , italic(italic)
        , underlined(underlined)
        , strikethrough(strikethrough)
        , misspelled(misspelled)
    {
    }

    style_t(scope::selector_t const& scopeSelector = scope::selector_t(),
        std::string const& fontName = NULL_STR, float fontSize = -1)
        : scope_selector(scopeSelector)
        , font_name(fontName)
        , font_size(fontSize)
        , bold(bool_unset)
        , italic(bool_unset)
        , underlined(bool_unset)
        , strikethrough(bool_unset)
        , misspelled(bool_unset)
    {
    }

    style_t& operator+=(style_t const& rhs);

    scope::selector_t scope_selector;

    std::string font_name;
    float font_size;
    color_info_t foreground;
    color_info_t background;
    color_info_t caret;
    color_info_t selection;
    color_info_t invisibles;
    bool_t bold;
    bool_t italic;
    bool_t underlined;
    bool_t strikethrough;
    bool_t misspelled;
};

struct theme_t {
    theme_t(Json::Value const& json, std::string const& fontName = NULL_STR,
        float fontSize = 12);

    std::string const& font_name() const;
    float font_size() const;
    color_info_t foreground() const;
    color_info_t background(std::string const& fileType = NULL_STR) const;

    style_t const& styles_for_scope(scope::scope_t const& scope);

    std::string theme_color_string(std::string const& name);
    void theme_color(std::string const& name, color_info_t& color);

    std::map<int, color_info_t> colorIndices;

private:
    struct shared_styles_t {

        shared_styles_t(Json::Value const& themeItem);

        ~shared_styles_t();
        void setup_styles(Json::Value const& themeItem);
        static style_t parse_styles(Json::Value const& item,
            std::string scope_selector);

        std::vector<style_t> _styles;

        color_info_t _foreground;
        color_info_t _background;
    };

    typedef std::shared_ptr<shared_styles_t> shared_styles_ptr;
    shared_styles_ptr find_shared_styles(Json::Value const& themeItem);
    shared_styles_ptr _styles;

    void setup_global_style(Json::Value const& themeItem);

    std::string _font_name;
    float _font_size;

    std::map<size_t, style_t> _cache;
    // mutable google::dense_hash_map<scope::scope_t, styles_t> _cache;

    Json::Value bundle;
};

theme_ptr parse_theme(Json::Value& json);

#endif