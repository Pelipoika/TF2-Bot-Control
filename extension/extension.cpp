#include "extension.h"
#include <CDetour/detours.h>

CRealizeSpyFixer g_RealizeSpyFixer;
SMEXT_LINK(&g_RealizeSpyFixer);

IGameConfig *g_pGameConf = NULL;

CDetour *g_RealizeSpyDetour = NULL;
CDetour *g_GetEventChangeAttributes = NULL;

class CTFPlayer;

DETOUR_DECL_MEMBER1(RealizeSpy, int, CTFPlayer *, player)
{
	return 0;
	
	return DETOUR_MEMBER_CALL(RealizeSpy)(player);
}

DETOUR_DECL_MEMBER2(GetEventChangeAttributes, int, CTFPlayer *, player, char const*, attribute)
{
	int index = gamehelpers->EntityToBCompatRef(reinterpret_cast<CBaseEntity *>(this));
	
	g_pSM->LogMessage(myself, "CTFBot::GetEventChangeAttributes");
	
	if(index > 0 && index <= playerhelpers->GetMaxClients())
	{
		IGamePlayer *pPlayer = playerhelpers->GetGamePlayer(index);
		if(pPlayer->IsConnected() && pPlayer->IsInGame() && !pPlayer->IsFakeClient())
		{
			g_pSM->LogMessage(myself, "CTFBot::GetEventChangeAttributes NOT BOT");
			return 0;
		}
	}
	
	return DETOUR_MEMBER_CALL(GetEventChangeAttributes)(player, attribute);
}

bool CRealizeSpyFixer::SDK_OnLoad(char *error, size_t maxlength, bool late)
{
	if (!gameconfs->LoadGameConfigFile("bot-control", &g_pGameConf, error, maxlength)) return false;
	
	CDetourManager::Init(g_pSM->GetScriptingEngine(), g_pGameConf);
	
	if((g_RealizeSpyDetour = DETOUR_CREATE_MEMBER(RealizeSpy, "CTFBot::RealizeSpy")) != NULL)
	{
		g_RealizeSpyDetour->EnableDetour();
		g_pSM->LogMessage(myself, "CTFBot::RealizeSpy detour enabled.");
	}
	
	if((g_GetEventChangeAttributes = DETOUR_CREATE_MEMBER(GetEventChangeAttributes, "CTFBot::GetEventChangeAttributes")) != NULL)
	{
		g_GetEventChangeAttributes->EnableDetour();
		g_pSM->LogMessage(myself, "CTFBot::GetEventChangeAttributes detour enabled.");
	}
	
	return true;
}

void CRealizeSpyFixer::SDK_OnUnload()
{
	gameconfs->CloseGameConfigFile(g_pGameConf);
	
	if(g_RealizeSpyDetour != NULL) g_RealizeSpyDetour->Destroy();
	if(g_GetEventChangeAttributes != NULL) g_GetEventChangeAttributes->Destroy();
}
