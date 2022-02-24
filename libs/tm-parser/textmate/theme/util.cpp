#include "util.h"
#include "rgb.h"

#define _POSIX_C_SOURCE 200809L

#include <ctype.h>
#include <fcntl.h>
#include <float.h>
#include <math.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#ifndef WIN64
#include <strings.h>
#else
#define strcasecmp stricmp
#endif

uint32_t make_color(int r, int g, int b)
{
    return (r << 24) | (g << 16) | (b << 8) | 0xff;
}

int wrap(int i, int max) { return ((i % max) + max) % max; }

bool parse_color_name(const char* spec, uint32_t* color)
{
    for (int i = 0;; i++) {
        colorEntry* e = &colorTable[i];
        if (!e->name) {
            break;
        }
        if (strcmp(e->name, spec) == 0) {
            *color = make_color(e->r, e->g, e->b);
            return true;
        }
    }
    return false;
}

char* rpad(char* dest, const char* src, const char pad, const size_t sz)
{
    memset(dest, pad, sz);
    dest[sz] = 0x0;
    int l = strlen(src);
    if (l > 3)
        l = 3;
    memcpy(dest, src, l);
    return dest;
}

bool parse_color_rgb(const char* spec, uint32_t* color)
{
    char* token = strtok((char*)spec, ":");

    // rgb:
    if (!token)
        return false;
    token = strtok(NULL, "/");

    char red[8] = "";
    char green[8] = "";
    char blue[8] = "";
    // char alpha[8] = "";

    // red
    if (!token)
        return false;
    rpad(red, token, token[0], 2);
    token = strtok(NULL, "/");

    // green
    if (!token)
        return false;
    rpad(green, token, token[0], 2);
    token = strtok(NULL, "/");

    // blue
    if (!token)
        return false;
    rpad(blue, token, token[0], 2);

    // alpha
    // if (!token) return false;
    // rpad(alpha, token, token[0], 2);

    *color = make_color((strtol(red, NULL, 16)), (strtol(green, NULL, 16)),
        (strtol(blue, NULL, 16)));
    return true;
}

bool parse_color(const char* color, uint32_t* result)
{
    if (parse_color_rgb(color, result)) {
        return true;
    }

    if (parse_color_name(color, result)) {
        return true;
    }

    if (color[0] == '#') {
        ++color;
    }
    int len = strlen(color);
    if ((len != 6 && len != 8) || !isxdigit(color[0]) || !isxdigit(color[1])) {
        return false;
    }
    char* ptr;
    uint32_t parsed = strtoul(color, &ptr, 16);
    if (*ptr != '\0') {
        return false;
    }
    *result = len == 6 ? ((parsed << 8) | 0xFF) : parsed;

    // float rgba[4];
    // color_to_rgba(rgba, *result);
    // printf("parse color %s [%f,%f,%f]\n", color, rgba[0],rgba[1],rgba[2]);
    return true;
}

void color_to_rgba(float dest[4], uint32_t color)
{
    dest[0] = ((color >> 24) & 0xff) / 255.0;
    dest[1] = ((color >> 16) & 0xff) / 255.0;
    dest[2] = ((color >> 8) & 0xff) / 255.0;
    dest[3] = (color & 0xff) / 255.0;
}

bool parse_boolean(const char* boolean, bool current)
{
    if (strcasecmp(boolean, "1") == 0 || strcasecmp(boolean, "yes") == 0 || strcasecmp(boolean, "on") == 0 || strcasecmp(boolean, "true") == 0 || strcasecmp(boolean, "enable") == 0 || strcasecmp(boolean, "enabled") == 0 || strcasecmp(boolean, "active") == 0) {
        return true;
    } else if (strcasecmp(boolean, "toggle") == 0) {
        return !current;
    }
    // All other values are false to match i3
    return false;
}

float parse_float(const char* value)
{
    // errno = 0;
    char* end;
    float flt = strtof(value, &end);
    if (*end) { // } || errno) {
        // sway_log(SWAY_DEBUG, "Invalid float value '%s', defaulting to NAN",
        // value);
        return NAN;
    }
    return flt;
}
