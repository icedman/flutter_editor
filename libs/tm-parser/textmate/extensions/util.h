#ifndef UTIL_H
#define UTIL_H

#include <set>
#include <string>
#include <vector>

std::vector<size_t> split_path_to_indices(const std::string& str,
    const std::set<char> delimiters);
std::vector<std::string> split_path(const std::string& str,
    const std::set<char> delimiters);
std::vector<std::string> enumerate_dir(const std::string path);

bool expand_path(char** path);

void initLog();
void log(const char* format, ...);

unsigned int murmur_hash(const void* key, int len, unsigned int seed);
unsigned int hash_combine(int lhs, int rhs);

std::string join(std::vector<std::string> ss, char c);
std::vector<std::string> split(const std::string& s, char seperator);
std::string clean_path(std::string fullPath);

#include <stdbool.h>
#include <stdint.h>

// #include <wayland-server-protocol.h>

/**
 * Wrap i into the range [0, max[
 */
int wrap(int i, int max);

/**
 * Given a string that represents an RGB(A) color, result will be set to a
 * uint32_t version of the color, as long as it is valid. If it is invalid,
 * then false will be returned and result will be untouched.
 */
bool parse_color(const char* color, uint32_t* result);

void color_to_rgba(float dest[4], uint32_t color);

/**
 * Given a string that represents a boolean, return the boolean value. This
 * function also takes in the current boolean value to support toggling. If
 * toggling is not desired, pass in true for current so that toggling values
 * get parsed as not true.
 */
bool parse_boolean(const char* boolean, bool current);

/**
 * Given a string that represents a floating point value, return a float.
 * Returns NAN on error.
 */
float parse_float(const char* value);

#endif // UTIL_H