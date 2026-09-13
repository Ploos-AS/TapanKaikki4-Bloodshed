#include <stdio.h>

#include <dirent.h>
#include <sys/stat.h>

#include <ctype.h>
#include <stdlib.h>
#include <string.h>

#include <algorithm>
#include <string>
#include <vector>

#include "lists.h"
#include "common/error.h"
#include "common/CLevel.h"

namespace
{
	bool is_forbidden(const char *name)
	{
		for (int a=0; a<KForbiddenFileAmount; ++a)
			if (strcasecmp(name, KForbiddenFiles[a]) == 0)
				return true;
		return false;
	}

	bool join_path(char *out, size_t out_size, const char *dir, const char *name)
	{
		return snprintf(out, out_size, "%s/%s", dir, name) > 0;
	}

	bool is_directory(const char *path)
	{
		struct stat info;
		return stat(path, &info) == 0 && S_ISDIR(info.st_mode);
	}

	bool is_regular_file(const char *path)
	{
		struct stat info;
		return stat(path, &info) == 0 && S_ISREG(info.st_mode);
	}

	bool is_normal_level_name(const char *name)
	{
		const char *tmp = name;
		while (*tmp)
		{
			if (!strcasecmp(tmp, ".lev"))
				return true;
			++tmp;
		}
		return false;
	}

	bool is_episode_level_name(const char *name)
	{
		if (strncasecmp(name, "level", 5) != 0)
			return false;

		const char *tmp = name + 5;
		if (!isdigit((unsigned char)*tmp++))
			return false;
		if (*tmp == 0)
			return false;

		while (*tmp)
		{
			if (*tmp == '.')
				return !strcasecmp(tmp + 1, "lev");
			if (!isdigit((unsigned char)*tmp))
				return false;
			++tmp;
		}
		return false;
	}

	bool case_less(const std::string &a, const std::string &b)
	{
		return strcasecmp(a.c_str(), b.c_str()) < 0;
	}

	bool level_less(const std::string &a, const std::string &b)
	{
		return atoi(a.c_str() + 5) < atoi(b.c_str() + 5);
	}

	bool list_entries(const char *dirname, std::vector<std::string> &entries)
	{
		DIR *dir = opendir(dirname);
		if (!dir)
			return false;

		for (dirent *entry = readdir(dir); entry; entry = readdir(dir))
		{
			if (!strcmp(entry->d_name, ".") || !strcmp(entry->d_name, ".."))
				continue;
			entries.push_back(entry->d_name);
		}

		closedir(dir);
		return true;
	}
}

void CEpisode::ListFiles(const char *filenames)
{
	Reset();
	iDirName = strdup(filenames);

	std::vector<std::string> entries;
	ASSERT(list_entries(filenames, entries));

	std::vector<std::string> levels;
	char path[FILENAME_MAX];
	for (std::vector<std::string>::const_iterator it = entries.begin(); it != entries.end(); ++it)
	{
		ASSERT(join_path(path, sizeof(path), filenames, it->c_str()));
		if (is_regular_file(path) && is_episode_level_name(it->c_str()))
			levels.push_back(*it);
	}
	std::sort(levels.begin(), levels.end(), level_less);

	for (std::vector<std::string>::const_iterator it = levels.begin(); it != levels.end(); ++it)
	{
		ASSERT(join_path(path, sizeof(path), filenames, it->c_str()));
		char *level_name = CLevel::ReadLevelName(path);
		ASSERT(level_name);
		if (*level_name)
			iLevelnames.push_back(level_name);
		else
			iLevelnames.push_back(strdup(it->c_str()));
		iFilenames.push_back(strdup(path));
	}
}

void CEpisodeList::ListFiles(const char *dirnames)
{
	CEpisode *epi = new CDeathMatchEpisode();
	epi->ListFiles(dirnames);
	if (epi->Amount() > 0)
	{
		epi->iName = strdup("Deathmatch");
		iDMEpisodes.push_back(epi);
	}
	else
		delete epi;

	std::vector<std::string> entries;
	ASSERT(list_entries(dirnames, entries));
	std::sort(entries.begin(), entries.end(), case_less);

	char path[FILENAME_MAX];
	for (std::vector<std::string>::const_iterator it = entries.begin(); it != entries.end(); ++it)
	{
		if (is_forbidden(it->c_str()))
			continue;

		ASSERT(join_path(path, sizeof(path), dirnames, it->c_str()));
		if (!is_directory(path))
			continue;

		epi = new CEpisode();
		epi->ListFiles(path);
		if (epi->Amount() > 0)
		{
			epi->iName = strdup(it->c_str());
			iEpisodes.push_back(epi);
			iDMEpisodes.push_back(epi);
		}
		else
			delete epi;
	}
}

void CEpisodeList::Sort()
{
	int a, b;
	CEpisode *tmp;
	for (a=1; a<(int)iEpisodes.size()-1; ++a)
		for (b=a; b<(int)iEpisodes.size(); ++b)
			if (strcasecmp(iEpisodes[a]->Name(), iEpisodes[b]->Name()) > 0)
			{
				tmp = iEpisodes[a];
				iEpisodes[a] = iEpisodes[b];
				iEpisodes[b] = tmp;
			}
}

void CDeathMatchEpisode::ListFiles(const char *filenames)
{
	Reset();
	iDirName = strdup(filenames);

	std::vector<std::string> entries;
	ASSERT(list_entries(filenames, entries));
	std::sort(entries.begin(), entries.end(), case_less);

	char path[FILENAME_MAX];
	for (std::vector<std::string>::const_iterator it = entries.begin(); it != entries.end(); ++it)
	{
		if (is_forbidden(it->c_str()) || !is_normal_level_name(it->c_str()))
			continue;

		ASSERT(join_path(path, sizeof(path), filenames, it->c_str()));
		if (!is_regular_file(path))
			continue;

		char *level_name = CLevel::ReadLevelName(path);
		ASSERT(level_name);
		if (*level_name)
			iLevelnames.push_back(level_name);
		else
			iLevelnames.push_back(strdup(it->c_str()));
		iFilenames.push_back(strdup(path));
	}
}

void CMusicThemeList::LoadThemes()
{
	std::vector<std::string> entries;
	if (!list_entries("music", entries))
		return;
	std::sort(entries.begin(), entries.end(), case_less);

	char path[FILENAME_MAX];
	for (std::vector<std::string>::const_iterator it = entries.begin(); it != entries.end(); ++it)
	{
		if (is_forbidden(it->c_str()))
			continue;
		ASSERT(join_path(path, sizeof(path), "music", it->c_str()));
		if (is_directory(path))
			iMusicThemes.push_back(strdup(it->c_str()));
	}
}
