#include "CGameApp.h"
#include "CSplash.h"

#include "common/files.h"

#include <stdio.h>

int abnormal_exit=1;

#ifdef AMIGA
static bool amiga_m3_write_marker(const char* base, const char* name)
{
	char path[192];
	int n = snprintf(path, sizeof(path), "%s/%s", base, name);
	if (n <= 0 || n >= (int)sizeof(path))
		return false;

	FILE* f = fopen(path, "w");
	if (!f)
		return false;

	fputs("1\n", f);
	fclose(f);
	return true;
}

static void amiga_m3_marker(const char* name)
{
	/*
	 * PROGDIR: is the correct installed-layout target.  AROS/libnix under
	 * FS-UAE has historically varied in how PROGDIR: is exposed through stdio,
	 * so the CI runtime gate also accepts the equivalent SYS:save location.
	 */
	if (amiga_m3_write_marker("PROGDIR:save", name))
		return;
	(void)amiga_m3_write_marker("SYS:save", name);
}
#else
static void amiga_m3_marker(const char*) {}
#endif

void ExitHandler()
{
	if (abnormal_exit)
	{
		logwrite("Abnormal exit\n");
#ifdef _DEBUG
		_asm { int 3h }
#endif
	}
}

// TODO: CONFIGFILE
const std::string KIconFile="tk.ico";
const char* KWindowCaption="Tapan Kaikki Bloodshed";

int main(int argc,char *argv[]) 
{
	CGameApp* GGameApp = NULL;
	atexit(ExitHandler);

	/* Record entry before touching the data-directory path. */
	amiga_m3_marker("m3-main-started.txt");
	chdir(getdatapath(".").c_str());

	try
	{
		// TODO: CONFIGFILE
		CSplash::ShowSplash("efps/splash.bmp",KIconFile.c_str(),KWindowCaption);
		amiga_m3_marker("m3-splash-ok.txt");
		GGameApp = new CGameApp(KIconFile.c_str(),KWindowCaption);
		amiga_m3_marker("m3-app-ok.txt");
#ifdef _DEBUG
		GGameApp->SelfTest();
#endif
		GGameApp->Run(argc,argv);
		delete GGameApp;
	}
	catch (CCriticalException& e)
	{
		error("CCriticalException: %s",e.what());
	}
	catch (CFailureException& e)
	{
		error("CFailureException: %s",e.what());
	}
	catch (CGameException& e)
	{
		error("CGameException: %s",e.what());
	}
	catch (std::exception& e)
	{
		error("std::exception: %s",e.what());
	}
	
	abnormal_exit=0;
	return 0;
}
