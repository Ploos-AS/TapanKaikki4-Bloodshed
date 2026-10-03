#include <vector>
#include <time.h>
#include <string.h>
#include <stdlib.h>
#include <stdio.h>

#include "CGameApp.h"
#include "common/CMath.h"

#include "CGameGraphicsInterface.h"
#include "CMessageBoard.h"
#include "CGraphicsFader.h"
#include "CSoundPlayer.h"
#include "CGameSystem.h"
#include "CGameData.h"
#include "timer.h"
#include "CWebVersionChecker.h"
#include "CEventFilter.h"
#include "CGUIEffectData.h"
#include "common/CDrawArea.h"
#include "common/CEventHandler.h"

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
	if (amiga_m3_write_marker("PROGDIR:save", name))
		return;
	(void)amiga_m3_write_marker("SYS:save", name);
}
#else
static void amiga_m3_marker(const char*) {}
#endif

CGameApp::CGameApp(const char* aIcon, const char* aCaption)
{
	LOG0("TK Init Started\n------------------\n");
	// Setup SDL
	if (SDL_InitSubSystem(SDL_INIT_TIMER)<0)
	{
		error("Unable to init SDL subsystem: %s\n", SDL_GetError());
	}

	// Setup Random Generator
	srand((unsigned int)time(NULL)); 

	iDebugStartLevel=0;
	iActive=0;

	LOG0("Initializing CMath\n");
	CMath::Static();
	LOG0("Initializing CSoundPlayer\n");
	iSoundPlayer= new CSoundPlayer;
	LOG0("Initializing CMessageBoard\n");
	iMBoard  = new CMessageBoard;
	LOG0("Initializing CNetworkDevice\n");
	iNetwork = new CNetworkDevice;
	LOG0("Initializing COptions\n");
	iOptions = new COptions(iSoundPlayer);
	LOG0("Initializing CGameData\n");
	iGameData= new CGameData(iOptions, this); 
	LOG0("Initializing CGameGraphicsInterface\n");
	iGGI     = new CGameGraphicsInterface(iOptions, iGameData, iMBoard,aIcon,aCaption);
	iGGI->AddObserver( this );
	LOG0("Initializing CEventHandler\n");
	iEventHandler= new CEventHandler(iGGI->GD());
	LOG0("Initializing CEventFilter\n");
	iEventFilter= new CEventFilter(this);
	iEventHandler->AddEventHandler(iEventFilter);

	/* Must be init after options! */
	LOG0("Starting timer\n");
	
	startTimer();
	LOG0("Initializing CGameSystem\n");
	iGS=new CGameSystem(this);
	LOG0("Initializing CGameState\n");
	iState = new CGameState(this);

	LOG0("Initializing CGUIEffectData\n");
	iEffectData = new CGUIEffectData();
	iFullUpdate = true;

	// Start internet version checking!
	LOG0("Initializing CWebVersionChecker\n");
	iWVC	 = new CWebVersionChecker(iMBoard,iNetwork,iOptions);

	if (iOptions->Data().iWebVersionCheckingEnabled)
	{
		LOG0("Starting CWebVersionChecker\n");
		iWVC->Start();
	}
	else
		LOG0("Starting CWebVersionChecker...skipped!\n");

	if (!iSoundPlayer->Initialized())
		iMBoard->AddMessage("Sound system initialization FAILED!");
}

CGameApp::~CGameApp() 
{
	stopTimer();

	iWVC->Kill();
	delete iWVC;

	delete iEffectData;
	delete iState;
	delete iEventHandler;
	delete iEventFilter;
	delete iOptions;
	delete iSoundPlayer;
	delete iGameData;
	delete iMBoard;
	delete iNetwork;
	delete iGS;
	delete iGGI;

	CMath::Destroy();
}

void CGameApp::Loop()
{
	bool draw;

	ASSERT(iState);
	iState->Start();

	LOG0("Entering the game loop\n");

	while (iState->MainState()!=CState::EMainStateConfirmedQuit)
	{
		CDrawArea updatedArea;
		CDrawArea dirtyArea;

		if (!iEffectData->iEnabled)
		{
			iMBoard->Run(dirtyArea);

			if (iState->First() || iFullUpdate)
			{
				dirtyArea.Combine(iGGI->DrawBuffer()->Rect());
				iFullUpdate = false;
			}

			try
			{
				draw = iState->RunFrame();
				if (draw||dirtyArea.Size()>0)
					iState->Draw(dirtyArea,updatedArea);
			}
			catch ( CGameException& exception )
			{
				if ( iState->State().iMainState == CState::EMainStateGame )
				{
					iMBoard->AddMessage("Game threw exception:");
					iMBoard->AddMessage( exception.what() );
					iState->SetState( CState( CState::EMainStateMenu, 0 ) );
				}
				else throw;
			}
			
			iMBoard->Draw(iGGI,updatedArea);
			iGGI->GD()->ShowBuf(iGGI->DrawBuffer(),updatedArea);
		}
		else
		{
			if (TimerCounter>iEffectData->iStarted+iEffectData->iDuration)
			{
				if (iEffectData->iFadeIn)
					iGGI->GD()->SetPalette(*iEffectData->iPalette,256);
				else
					iGGI->GD()->SetPalette(*iEffectData->iPalette,0);

				iEffectData->iEnabled = false;
				restoreTimer();

				try
				{
					if (iEffectData->iStateTransition)
						iState->SetState(iEffectData->iNextState);
				}
				catch ( CGameException& exception )
				{
					if ( iState->State().iMainState == CState::EMainStateGame || 
						iEffectData->iNextState.iMainState == CState::EMainStateGame)
					{
						iMBoard->AddMessage("Game threw exception:");
						iMBoard->AddMessage( exception.what() );
						iState->SetState( CState( CState::EMainStateMenu, 0 ) );
					}
					else throw;
				}

				iGGI->GD()->ShowBuf(iGGI->DrawBuffer());
			}
			else
			{
				(iGGI->Fader()->*iEffectData->iFaderMethod)
					(
						*iGGI->DrawBuffer(), 
						*iGGI->PostProBuffer(),
						*iEffectData->iPalette,
						iEffectData->iStarted,
						iEffectData->iDuration
					);
				iGGI->GD()->ShowBuf(iGGI->PostProBuffer());
			}
		}

		if ( !iActive )
			SDL_Delay( 10 );
		if (iEventHandler->HandleEvents()==1)
		{
			return;
		}
	}

	LOG0("Getting out of game loop...\n");
}

void CGameApp::StartFadeIn( const CPalette& aPalette )
{
	iEffectData->iStarted=TimerCounter;
	iEffectData->iDuration=KTimerFreq/2;
	iEffectData->iPalette=&aPalette;

	iEffectData->iStateTransition=false;
	iEffectData->iFadeIn = true;
	iEffectData->iEnabled = true;

	iEffectData->iFaderMethod = &CGraphicsFader::FadeIn;
	saveTimer();
}

void CGameApp::StartFadeIn(CGameData::TPaletteNo aPal)
{
	StartFadeIn( *iGameData->Palette(aPal) );
}

void CGameApp::StartFadeOut(CState aNextState)
{
	iEffectData->iFaderMethod = &CGraphicsFader::FadeOut;
	iEffectData->iStarted=TimerCounter;
	iEffectData->iDuration=KTimerFreq/2;
	iGGI->GD()->GetPalette(iEffectData->iSparePalette);
	iEffectData->iPalette=&iEffectData->iSparePalette;
	iEffectData->iNextState=aNextState;
	iEffectData->iStateTransition=true;
	iEffectData->iFadeIn = false;
	iEffectData->iEnabled = true;

	saveTimer();
}

void CGameApp::StartZoomOut(CState aNextState)
{
	iEffectData->iFaderMethod = &CGraphicsFader::FadeZoomOut;
	iEffectData->iEnabled = true;
	iEffectData->iFadeIn = false;
	iEffectData->iStarted=TimerCounter;
	iEffectData->iDuration=KTimerFreq/2;
	iGGI->GD()->GetPalette(iEffectData->iSparePalette);
	iEffectData->iPalette=&iEffectData->iSparePalette;
	iEffectData->iNextState=aNextState;
	iEffectData->iStateTransition=true;
	iEffectData->iEnabled = true;

	saveTimer();
}

CGameState* CGameApp::State()
{
	return iState;
};

CEventHandler* CGameApp::EventHandler()
{ 
	return iEventHandler;
}

CGameGraphicsInterface* CGameApp::GGI()
{ 
	return iGGI;
}

CSoundPlayer* CGameApp::SoundPlayer()
{
	return iSoundPlayer;
}

CMessageBoard* CGameApp::MessageBoard()
{
	return iMBoard;
}

IGameSubStateController* CGameApp::GameSystem()
{ 
	return iGS;
}

CGameData* CGameApp::GameData()
{ 
	return iGameData;
}

COptions* CGameApp::Options()
{
	return iOptions;
}

CNetworkDevice* CGameApp::NetworkDevice()
{
	return iNetwork;
}

void CGameApp::Run(int argc,char *argv[])
{
	LOG0("TK Game Started\n------------------\n");
	int extra = 0;

	for(int a=1; a<argc; a++) 
	{
		int b=0;
		char *tmp=strdup(argv[a]);
		strupr(tmp);
		
		if((tmp[0]=='-')||(tmp[0]=='/'))
		switch(tmp[1]) 
		{
			case '1': extra |= SDL_HWACCEL;
					break;

			case '2': extra |= SDL_HWSURFACE;
					break;

			case 'W':iOptions->Data().iFullScreen=0; 
					 break;

			case 'L':b=atoi(argv[++a]);
					 if(b>0) iDebugStartLevel=b - 1;
					 break;

			default:
					error("Unknown commandline parameter!?!\n");
					break;
		}
		free(tmp);
	}
	
	iGGI->SetExtraFlags( extra );
	iGGI->SetMenuMode();
	amiga_m3_marker("m3-menu-mode-ok.txt");
	iEventHandler->ResetStack();

	LOG0("Starting game loop\n");
	amiga_m3_marker("m3-loop-entered.txt");
	Loop();
}

void CGameApp::GraphicsModeChanged()
{
	iFullUpdate = true;
}

int CGameApp::DebugStartLevel()
{
	return iDebugStartLevel;
}

void CGameApp::SetFullScreenUpdate(bool aBool)
{
	iFullUpdate = aBool;
}

void CGameApp::SetActive( bool aActive )
{
	iActive = aActive;
}

#ifdef _DEBUG
void CGameApp::SelfTest()
{
	DEBUG0("Running Self Tests\n");
	CRect<int>::SelfTest();
	CDrawArea::SelfTest();
}

#endif
