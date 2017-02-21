#include "extension.h"

CBotControl g_BotControl;
SMEXT_LINK(&g_BotControl);

IGameConfig *g_pGameConf = NULL;

CDetour *g_RealizeSpyDetour = NULL;
CDetour *g_GetEventChangeAttributes = NULL;
CDetour *g_AddFollower = NULL;
CDetour *g_GetSquadLeader = NULL;
CDetour *g_AllowedToHealTarget = NULL;

IForward *g_pForwardGetSquadLeader = NULL;
IForward *g_pForwardAllowedToHealTarget = NULL;

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

DETOUR_DECL_MEMBER0(GetSquadLeader, CTFPlayer*)
{
	CTFPlayer *pPlayer = DETOUR_MEMBER_CALL(GetSquadLeader)();
	
	if(g_pForwardGetSquadLeader != NULL)
	{
		g_pForwardGetSquadLeader->PushCell((cell_t)(this));
		
		cell_t client = gamehelpers->EntityToBCompatRef(reinterpret_cast<CBaseEntity*>(pPlayer));
		g_pForwardGetSquadLeader->PushCellByRef(&client);
		
		cell_t action = Pl_Continue;
		g_pForwardGetSquadLeader->Execute(&action);

		if(action != Pl_Continue)
		{
			pPlayer = reinterpret_cast<CTFPlayer*>(playerhelpers->GetGamePlayer(client));
			return pPlayer;
		}
	}
	return pPlayer;
}

DETOUR_DECL_MEMBER1(AllowedToHealTarget, bool, CBaseEntity*, pEntity)
{
	bool bResult = DETOUR_MEMBER_CALL(AllowedToHealTarget)(pEntity);
	
	if(g_pForwardAllowedToHealTarget != NULL)
	{
		cell_t iMedigun = gamehelpers->EntityToBCompatRef(reinterpret_cast<CBaseEntity*>(this));
		cell_t iHealTarget = gamehelpers->EntityToBCompatRef(reinterpret_cast<CBaseEntity*>(pEntity));
		
		if(iHealTarget > 0 && iHealTarget <= playerhelpers->GetMaxClients())
		{
			IGamePlayer *pPlayer = playerhelpers->GetGamePlayer(iHealTarget);
			if(pPlayer->IsConnected() && pPlayer->IsInGame())
			{
				g_pForwardAllowedToHealTarget->PushCell(iMedigun);
				
				g_pForwardAllowedToHealTarget->PushCellByRef(&iHealTarget);
				
				cell_t bOriginalResult = (bResult != 0);
				g_pForwardAllowedToHealTarget->PushCellByRef(&bOriginalResult);
				
				cell_t action = Pl_Continue;
				g_pForwardAllowedToHealTarget->Execute(&action);
				
				if(action != Pl_Continue)
					bResult = (bOriginalResult != 0);
			}
		}
	}
	return bResult;
}

bool CBotControl::SDK_OnLoad(char *error, size_t maxlength, bool late)
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
	
	g_GetSquadLeader = DETOUR_CREATE_MEMBER(GetSquadLeader, "CTFBotSquad::GetLeader");
	if(g_GetSquadLeader != NULL)
	{
		g_GetSquadLeader->EnableDetour();
		g_pSM->LogMessage(myself, "CTFBotSquad::GetLeader detour enabled.");
	}
	
	g_AllowedToHealTarget = DETOUR_CREATE_MEMBER(AllowedToHealTarget, "CWeaponMedigun::AllowedToHealTarget");
	if(g_AllowedToHealTarget != NULL)
	{
		g_AllowedToHealTarget->EnableDetour();
		g_pSM->LogMessage(myself, "CWeaponMedigun::AllowedToHealTarget detour enabled.");
	}
	
	//Forwards
	g_pForwardGetSquadLeader = forwards->CreateForward("CTFBotSquad_OnGetLeader", ET_Event, 2, NULL, Param_Cell, Param_CellByRef);
	g_pForwardAllowedToHealTarget = forwards->CreateForward("CWeaponMedigun_IsAllowedToHealTarget", ET_Event, 3, NULL, Param_Cell, Param_CellByRef, Param_CellByRef);
	
	return true;
}

void CBotControl::SDK_OnUnload()
{
	gameconfs->CloseGameConfigFile(g_pGameConf);
	
	if(g_RealizeSpyDetour != NULL) g_RealizeSpyDetour->Destroy();
	if(g_GetEventChangeAttributes != NULL) g_GetEventChangeAttributes->Destroy();
	if(g_AddFollower != NULL) g_AddFollower->Destroy();
	if(g_GetSquadLeader != NULL) g_GetSquadLeader->Destroy();
	if(g_AllowedToHealTarget != NULL) g_AllowedToHealTarget->Destroy();
	
	if(g_pForwardGetSquadLeader != NULL) forwards->ReleaseForward(g_pForwardGetSquadLeader);
	if(g_pForwardAllowedToHealTarget != NULL) forwards->ReleaseForward(g_pForwardAllowedToHealTarget);
}