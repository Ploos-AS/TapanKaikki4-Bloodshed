#ifndef __UNIX_H
#define __UNIX_H

#ifdef __APPLE__
#define __unix__
#endif

#if defined(__unix__) || defined(AMIGA)

#ifndef EXPORT
#define EXPORT
#endif

#ifdef AMIGA
#define NORETURN __attribute__((noreturn))
#else
#define NORETURN
#endif

/* Some functions and names that differ on windows and other platforms */
#define EF_STAT stat
#define EF_SNPRINTF snprintf
#define EF_GETCWD getcwd
#ifndef AMIGA
#define EF_SDLWINDOW info.x11.window /* window in SDL_SysWMinfo structure */
#endif

#define DIR_SEPARATOR '/'

#ifdef DEBUG
#  define EF_DEBUG 1
#else
#  define EF_DEBUG 0
#endif

#include <ctype.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>
#include <algorithm>
using std::min;
using std::max;

inline void ChangeDir(const char* str)
{
	chdir(str);
}

#ifdef AMIGA
inline char* strcasestr(const char *haystack, const char *needle)
{
	if (!*needle)
		return const_cast<char*>(haystack);

	for (const char *h = haystack; *h; ++h)
	{
		const char *hp = h;
		const char *np = needle;
		while (*hp && *np &&
		       tolower((unsigned char)*hp) == tolower((unsigned char)*np))
		{
			++hp;
			++np;
		}
		if (!*np)
			return const_cast<char*>(h);
	}
	return 0;
}

inline char *strset(char *buf,char fill)
{
	int len=strlen(buf);
	for (int a=0;a<len;a++)
		buf[a]=fill;
	return buf;
}
#else
inline char* strupr(char *buf)
{
	int len=strlen(buf);
	
	for (int a=0;a<len;a++)
	{
		buf[a]=toupper(buf[a]);
	}
	return buf;
}

inline char* strlwr(char *buf)
{
	int len=strlen(buf);
	
	for (int a=0;a<len;a++)
	{
		buf[a]=tolower(buf[a]);
	}	
	return buf;
}

inline char *strset(char *buf,char fill)
{
	int len=strlen(buf);
	
	for (int a=0;a<len;a++)
	{
		buf[a]=fill;
	}	
	return buf;
}
#endif

#endif // __unix__ || AMIGA

#endif // __UNIX_H
