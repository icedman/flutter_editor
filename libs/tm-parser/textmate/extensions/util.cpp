#define _POSIX_C_SOURCE 200809L
#include <ctype.h>
#include <dirent.h>
#include <stdarg.h>
#include <stdbool.h>
#include <string.h>

#ifndef WIN64
#include <strings.h>
#endif

#ifdef __ANDROID__

#else
#ifdef WIN64
#include "utf8.h"
#include <shlobj.h>
#else
#include <wordexp.h>
#endif
#endif

#include "util.h"

// #define ENABLE_LOG
#define LOG_FILE "./ashlar.log"
static bool log_initialized = false;

std::vector<std::string> split_path(const std::string& str,
    const std::set<char> delimiters)
{
    std::vector<std::string> result;

    char const* pch = str.c_str();
    char const* start = pch;
    for (; *pch; ++pch) {
        if (delimiters.find(*pch) != delimiters.end()) {
            if (start != pch) {
                std::string str(start, pch);
                result.push_back(str);
            } else {
                result.push_back("");
            }
            start = pch + 1;
        }
    }
    result.push_back(start);

    return result;
}

std::vector<size_t> split_path_to_indices(const std::string& str,
    const std::set<char> delimiters)
{
    std::vector<size_t> result;

    char const* s = str.c_str();
    char const* ws = s;
    char const* pch = s;
    for (; *pch; ++pch) {
        if (delimiters.find(*pch) != delimiters.end()) {
            if (ws < pch) {
                result.push_back(ws - s);
            }
            ws = pch + 1;
        }
    }
    result.push_back(ws - s);

    return result;
}

std::vector<std::string> enumerate_dir(const std::string path)
{
    // std::cout << path << std::endl;

    std::vector<std::string> res;
    DIR* dir;
    struct dirent* ent;
    if ((dir = opendir(path.c_str())) != NULL) {
        while ((ent = readdir(dir)) != NULL) {
            std::string fullPath = path;
            fullPath += ent->d_name;
            res.push_back(fullPath);
        }
        closedir(dir);
    }

    return res;
}

char* join_args(char** argv, int argc)
{
    // if (!sway_assert(argc > 0, "argc should be positive")) {
    //     return NULL;
    // }
    int len = 0, i;
    for (i = 0; i < argc; ++i) {
        len += strlen(argv[i]) + 1;
    }
    char* res = (char*)malloc(len);
    len = 0;
    for (i = 0; i < argc; ++i) {
        strcpy(res + len, argv[i]);
        len += strlen(argv[i]);
        res[len++] = ' ';
    }
    res[len - 1] = '\0';
    return res;
}

bool expand_path(char** path)
{
#ifdef __ANDROID__
    // std::string home = getenv("/sdcard");

    // std::string tmp = *path;
    // if (tmp.length() && tmp[0] == '~') {
    //     tmp = home + tmp.substr(1);
    // } else {
    //     return true;
    // }

    // *path = (char*)realloc(*path, tmp.length() + 1);
    // strcpy(*path, tmp.c_str());

    return true;
#else
#ifdef WIN64
    std::string home = getenv("USERPROFILE");

    std::string tmp = *path;
    if (tmp.length() && tmp[0] == '~') {
        tmp = home + tmp.substr(1);
    } else {
        return true;
    }

    *path = (char*)realloc(*path, tmp.length() + 1);
    strcpy(*path, tmp.c_str());

#else

#ifdef IOS
    printf("Warning: implement expand path\n");
#else
    wordexp_t p = { 0 };
    while (strstr(*path, "  ")) {
        *path = (char*)realloc(*path, strlen(*path) + 2);
        char* ptr = strstr(*path, "  ") + 1;
        memmove(ptr + 1, ptr, strlen(ptr) + 1);
        *ptr = '\\';
    }
    if (wordexp(*path, &p, 0) != 0 || p.we_wordv[0] == NULL) {
        wordfree(&p);
        return false;
    }
    free(*path);
    *path = join_args(p.we_wordv, p.we_wordc);
    wordfree(&p);
#endif

#endif
#endif
    return true;
}

void initLog()
{
#ifdef ENABLE_LOG
    FILE* log_file = fopen(LOG_FILE, "w");
    if (log_file) {
        fclose(log_file);
    }
#endif
    log_initialized = true;
}

void log(const char* format, ...)
{
#ifdef ENABLE_LOG
    if (!log_initialized) {
        initLog();
    }

    static char string[1024] = "";

    va_list args;
    va_start(args, format);
    vsnprintf(string, 1024, format, args);
    va_end(args);

    FILE* log_file = fopen(LOG_FILE, "a");
    if (!log_file) {
        return;
    }
    char* token = strtok(string, "\n");
    while (token != NULL) {
        fprintf(log_file, "%s", token);
        fprintf(log_file, "\n");
        token = strtok(NULL, "\n");
    }
    fclose(log_file);
#endif
}

#define NK_INT8 int8_t
#define NK_UINT8 uint8_t
#define NK_INT16 int16_t
#define NK_UINT16 uint16_t
#define NK_INT32 int32_t
#define NK_UINT32 uint32_t
#define NK_SIZE_TYPE uintptr_t
#define NK_POINTER_TYPE uintptr_t

typedef NK_INT8 nk_char;
typedef NK_UINT8 nk_uchar;
typedef NK_UINT8 nk_byte;
typedef NK_INT16 nk_short;
typedef NK_UINT16 nk_ushort;
typedef NK_INT32 nk_int;
typedef NK_UINT32 nk_uint;
typedef NK_SIZE_TYPE nk_size;
typedef NK_POINTER_TYPE nk_ptr;

typedef nk_uint nk_hash;
typedef nk_uint nk_flags;
typedef nk_uint nk_rune;

nk_hash nk_murmur_hash(const void* key, int len, nk_hash seed)
{
    /* 32-Bit MurmurHash3: https://code.google.com/p/smhasher/wiki/MurmurHash3*/
#define NK_ROTL(x, r) ((x) << (r) | ((x) >> (32 - r)))

    nk_uint h1 = seed;
    nk_uint k1;
    const nk_byte* data = (const nk_byte*)key;
    const nk_byte* keyptr = data;
    nk_byte* k1ptr;
    const int bsize = sizeof(k1);
    const int nblocks = len / 4;

    const nk_uint c1 = 0xcc9e2d51;
    const nk_uint c2 = 0x1b873593;
    const nk_byte* tail;
    int i;

    /* body */
    if (!key)
        return 0;
    for (i = 0; i < nblocks; ++i, keyptr += bsize) {
        k1ptr = (nk_byte*)&k1;
        k1ptr[0] = keyptr[0];
        k1ptr[1] = keyptr[1];
        k1ptr[2] = keyptr[2];
        k1ptr[3] = keyptr[3];

        k1 *= c1;
        k1 = NK_ROTL(k1, 15);
        k1 *= c2;

        h1 ^= k1;
        h1 = NK_ROTL(h1, 13);
        h1 = h1 * 5 + 0xe6546b64;
    }

    /* tail */
    tail = (const nk_byte*)(data + nblocks * 4);
    k1 = 0;
    switch (len & 3) {
    case 3:
        k1 ^= (nk_uint)(tail[2] << 16); /* fallthrough */
    case 2:
        k1 ^= (nk_uint)(tail[1] << 8u); /* fallthrough */
    case 1:
        k1 ^= tail[0];
        k1 *= c1;
        k1 = NK_ROTL(k1, 15);
        k1 *= c2;
        h1 ^= k1;
        break;
    default:
        break;
    }

    /* finalization */
    h1 ^= (nk_uint)len;
    /* fmix32 */
    h1 ^= h1 >> 16;
    h1 *= 0x85ebca6b;
    h1 ^= h1 >> 13;
    h1 *= 0xc2b2ae35;
    h1 ^= h1 >> 16;

#undef NK_ROTL
    return h1;
}

unsigned int murmur_hash(const void* key, int len, unsigned int seed)
{
    return nk_murmur_hash(key, len, seed);
}

unsigned hash_combine(int lhs, int rhs)
{
    // lhs ^= rhs + 0x9e3779b9 + (lhs << 6) + (lhs >> 2);
    // return lhs;
    return lhs ^ rhs;
}

std::string join(std::vector<std::string> ss, char c)
{
    std::string res;
    res += c;
    for (auto s : ss) {
        if (res.length()) {
            res += c;
        }
        res += s;
    }
    return res;
}

std::vector<std::string> split(const std::string& s, char seperator)
{
    std::set<char> delims = { seperator };
    return split_path(s, delims);
}

std::string clean_path(std::string fullPath)
{
    size_t pos = 0;
    for (int i = 0; i < 3; i++) {
        pos = fullPath.find("//");
        if (pos != std::string::npos) {
            fullPath.replace(fullPath.begin() + pos, fullPath.begin() + pos + 2, "/");
            continue;
        }
        break;
    }
    return fullPath;
}