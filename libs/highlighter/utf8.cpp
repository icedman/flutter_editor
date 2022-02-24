#include "utf8.h"

// Ⱥ Ⱥ Ⱥ Ⱥ

const char* utf8_to_codepoint(const char* p, unsigned* dst)
{
    unsigned res, n;
    switch (*p & 0xf0) {
    case 0xf0:
        res = *p & 0x07;
        n = 3;
        break;
    case 0xe0:
        res = *p & 0x0f;
        n = 2;
        break;
    case 0xd0:
    case 0xc0:
        res = *p & 0x1f;
        n = 1;
        break;
    default:
        res = *p;
        n = 0;
        break;
    }
    while (n--) {
        res = (res << 6) | (*(++p) & 0x3f);
    }
    *dst = res;
    return p + 1;
}

int codepoint_to_utf8(uint32_t utf, char* out)
{
    if (utf <= 0x7F) {
        // Plain ASCII
        out[0] = (char)utf;
        out[1] = 0;
        return 1;
    } else if (utf <= 0x07FF) {
        // 2-byte unicode
        out[0] = (char)(((utf >> 6) & 0x1F) | 0xC0);
        out[1] = (char)(((utf >> 0) & 0x3F) | 0x80);
        out[2] = 0;
        return 2;
    } else if (utf <= 0xFFFF) {
        // 3-byte unicode
        out[0] = (char)(((utf >> 12) & 0x0F) | 0xE0);
        out[1] = (char)(((utf >> 6) & 0x3F) | 0x80);
        out[2] = (char)(((utf >> 0) & 0x3F) | 0x80);
        out[3] = 0;
        return 3;
    } else if (utf <= 0x10FFFF) {
        // 4-byte unicode
        out[0] = (char)(((utf >> 18) & 0x07) | 0xF0);
        out[1] = (char)(((utf >> 12) & 0x3F) | 0x80);
        out[2] = (char)(((utf >> 6) & 0x3F) | 0x80);
        out[3] = (char)(((utf >> 0) & 0x3F) | 0x80);
        out[4] = 0;
        return 4;
    } else {
        // error - use replacement character
        out[0] = (char)0xEF;
        out[1] = (char)0xBF;
        out[2] = (char)0xBD;
        out[3] = 0;
        return 0;
    }
}

std::string wstring_to_utf8string(std::wstring text)
{
    std::string res;
    for (auto c : text) {
        char tmp[5];
        codepoint_to_utf8(c, (char*)tmp);
        res += tmp;
    }
    return res;
}

std::wstring utf8string_to_wstring(std::string text)
{
    std::wstring res;
    char* p = (char*)text.c_str();
    while (*p) {
        unsigned cp;
        p = (char*)utf8_to_codepoint(p, &cp);
        res += (wchar_t)cp;
    }

    return res;
}

std::string utf8_substr(std::string& text, size_t pos, size_t len)
{
    if (len == 0) {
        return "";
    }

    char* t = (char*)text.c_str();
    char* p = t;
    char* s = 0;
    char* e = 0;
    unsigned cp;

    size_t idx = 0;
    while (*p) {
        unsigned cp;
        if (idx == pos) {
            s = p;
        }
        p = (char*)utf8_to_codepoint(p, &cp);
        idx++;
        if (idx == pos + len) {
            e = p;
        }

        if (s && e)
            break;
    }

    if (!s)
        s = p;
    if (!e)
        e = p;

    if (s - t >= text.length())
        return "";
    return text.substr(s - t, e - s);
}

std::string utf8_insert(std::string& text, size_t pos, std::string& str)
{
    char* t = (char*)text.c_str();
    char* p = t;
    char* s = 0;
    unsigned cp;

    size_t idx = 0;
    while (*p) {
        unsigned cp;
        if (idx == pos) {
            s = p;
        }
        p = (char*)utf8_to_codepoint(p, &cp);
        idx++;
        if (s)
            break;
    }

    if (!s)
        s = p;
    return text.insert(s - t, str);
}

std::string utf8_erase(std::string& text, size_t pos, size_t len)
{
    char* t = (char*)text.c_str();
    char* p = t;
    char* s = 0;
    char* e = 0;
    unsigned cp;

    size_t idx = 0;
    while (*p) {
        unsigned cp;
        if (idx == pos) {
            s = p;
        }
        p = (char*)utf8_to_codepoint(p, &cp);
        idx++;
        if (idx == pos + len) {
            e = p;
        }

        if (s && e)
            break;
    }

    if (!s)
        s = p;
    if (!e)
        e = p;
    return text.erase(s - t, e - s);
}

size_t utf8_clength(char* text)
{
    char* p = (char*)text;
    size_t idx = 0;
    while (*p) {
        unsigned cp;
        p = (char*)utf8_to_codepoint(p, &cp);
        idx++;
    }
    return idx;
}

size_t utf8_length(std::string& text)
{
    return utf8_clength((char*)text.c_str());
}