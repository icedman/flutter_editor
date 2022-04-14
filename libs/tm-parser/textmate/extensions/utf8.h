#ifndef UTF8_H
#define UTF8_H

#include <string>

const char* utf8_to_codepoint(const char* p, unsigned* dst);
int codepoint_to_utf8(uint32_t utf, char* out);
std::string wstring_to_utf8string(std::wstring text);
std::wstring utf8string_to_wstring(std::string text);

std::string utf8_insert(std::string& text, size_t pos, std::string& str);
std::string utf8_erase(std::string& text, size_t pos,
    size_t len = std::string::npos);
std::string utf8_substr(std::string& text, size_t pos,
    size_t len = std::string::npos);
size_t utf8_length(std::string& text);
size_t utf8_clength(char* text);

#endif // UTF8_H
