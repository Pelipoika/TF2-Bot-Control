#include "extension.h"
#include <CDetour/detours.h>

CRealizeSpyFixer g_RealizeSpyFixer;
SMEXT_LINK(&g_RealizeSpyFixer);

IGameConfig *g_pGameConf = NULL;

CDetour *g_RealizeSpyDetour = NULL;
CDetour *g_GetEventChangeAttributes = NULL;
CDetour *g_AddFollower = NULL;

class CTFPlayer;

DETOUR_DECL_MEMBER1(RealizeSpy, int, CTFPlayer *, player)
{
	return 0;
}

DETOUR_DECL_MEMBER1(GetEventChangeAttributes, int, char const*, attribute)
{
	int index = gamehelpers->EntityToBCompatRef(reinterpret_cast<CBaseEntity *>(this));

	if(index > 0 && index <= playerhelpers->GetMaxClients())
	{
		IGamePlayer *pPlayer = playerhelpers->GetGamePlayer(index);
		if(pPlayer->IsConnected() && pPlayer->IsInGame() && !pPlayer->IsFakeClient())
		{
			return 0;
		}
	}
	
	return DETOUR_MEMBER_CALL(GetEventChangeAttributes)(attribute);
}

DETOUR_DECL_MEMBER1(AddFollower, int, CTFPlayer*, player)
{
	int index = gamehelpers->EntityToBCompatRef(reinterpret_cast<CBaseEntity *>(player));

	if(index > 0 && index <= playerhelpers->GetMaxClients())
	{
		IGamePlayer *pPlayer = playerhelpers->GetGamePlayer(index);
		if(pPlayer->IsConnected() && pPlayer->IsInGame() && !pPlayer->IsFakeClient())
		{
			return 0;
		}
	}
	
	return DETOUR_MEMBER_CALL(AddFollower)(player);
}

bool CRealizeSpyFixer::SDK_OnLoad(char *error, size_t maxlength, bool late)
{
	if (!gameconfs->LoadGameConfigFile("bot-control", &g_pGameConf, error, maxlength)) return false;
	
	CDetourManager::Init(g_pSM->GetScriptingEngine(), g_pGameConf);
	
	g_RealizeSpyDetour = DETOUR_CREATE_MEMBER(RealizeSpy, "CTFBot::RealizeSpy");
	if(g_RealizeSpyDetour != NULL)
	{
		g_RealizeSpyDetour->EnableDetour();
		g_pSM->LogMessage(myself, "CTFBot::RealizeSpy detour enabled.");
	}
	
	g_GetEventChangeAttributes = DETOUR_CREATE_MEMBER(GetEventChangeAttributes, "CTFBot::GetEventChangeAttributes");
	if(g_GetEventChangeAttributes != NULL)
	{
		g_GetEventChangeAttributes->EnableDetour();
		g_pSM->LogMessage(myself, "CTFBot::GetEventChangeAttributes detour enabled.");
	}
	
	g_AddFollower = DETOUR_CREATE_MEMBER(AddFollower, "CCaptureFlag::AddFollower");
	if(g_AddFollower != NULL)
	{
		g_AddFollower->EnableDetour();
		g_pSM->LogMessage(myself, "CCaptureFlag::AddFollower detour enabled.");
	}
	
	return true;
}

void CRealizeSpyFixer::SDK_OnUnload()
{
	gameconfs->CloseGameConfigFile(g_pGameConf);
	
	if(g_RealizeSpyDetour != NULL) g_RealizeSpyDetour->Destroy();
	if(g_GetEventChangeAttributes != NULL) g_GetEventChangeAttributes->Destroy();
	if(g_AddFollower != NULL) g_AddFollower->Destroy();
}