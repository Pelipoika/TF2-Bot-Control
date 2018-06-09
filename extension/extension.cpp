#include "extension.h"
#include "iplayerinfo.h"

CBotControl g_BotControl;
SMEXT_LINK(&g_BotControl);

IGameConfig *g_pGameConf = NULL;

CDetour *g_GetEventChangeAttributes = NULL;

DETOUR_DECL_MEMBER1(GetEventChangeAttributes, int, char const*, attribute)
{
	int index = gamehelpers->EntityToBCompatRef(reinterpret_cast<CBaseEntity *>(this));

	if (index > 0 && index <= playerhelpers->GetMaxClients())
	{
		IGamePlayer *pPlayer = playerhelpers->GetGamePlayer(index);
		if (pPlayer->IsConnected() && pPlayer->IsInGame() && !pPlayer->IsFakeClient())
		{
			return 0;
		}
	}

	return DETOUR_MEMBER_CALL(GetEventChangeAttributes)(attribute);
}

bool CBotControl::SDK_OnLoad(char *error, size_t maxlength, bool late)
{
	if (!gameconfs->LoadGameConfigFile("bot-control", &g_pGameConf, error, maxlength)) return false;
	
	CDetourManager::Init(g_pSM->GetScriptingEngine(), g_pGameConf);
	
	g_GetEventChangeAttributes = DETOUR_CREATE_MEMBER(GetEventChangeAttributes, "CTFBot::GetEventChangeAttributes");
	if (g_GetEventChangeAttributes != NULL)
	{
		g_GetEventChangeAttributes->EnableDetour();
		g_pSM->LogMessage(myself, "CTFBot::GetEventChangeAttributes detour enabled.");
	}

	return true;
}

void CBotControl::SDK_OnUnload()
{
	gameconfs->CloseGameConfigFile(g_pGameConf);

	if(g_GetEventChangeAttributes != NULL) g_GetEventChangeAttributes->Destroy();
}