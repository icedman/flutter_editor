#ifndef PARSE_DEFINES_H
#define PARSE_DEFINES_H

#include <string>

#ifdef WIN64
#include <BaseTsd.h>
#define ssize_t SSIZE_T
#endif

#ifndef SIZE_T_MAX
#define SIZE_T_MAX SIZE_MAX
#endif

#ifndef NULL_STR
#define NULL_STR ""
#endif

#ifndef nullptr
#define nullptr 0
#endif

#endif
