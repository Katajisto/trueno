#ifdef WIN32
#define __EXPORT __declspec(dllexport)
#else
#define __EXPORT
#endif

#define extern extern __EXPORT

#include "stb_vorbis.c"
