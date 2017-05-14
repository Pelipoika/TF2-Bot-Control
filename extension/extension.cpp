#include "extension.h"
#include "iplayerinfo.h"

#define TEAM_ANY -2

CBotControl g_BotControl;
SMEXT_LINK(&g_BotControl);

IGameConfig *g_pGameConf = NULL;

CDetour *g_RealizeSpyDetour = NULL;
CDetour *g_CollectPlayers_CTFBot = NULL;
CDetour *g_AddFollower = NULL;
CDetour *g_SelectPatient = NULL;
CDetour *g_AllowedToHealTarget = NULL;

IForward *g_pForwardAllowedToHealTarget = NULL;
IForward *g_pForwardSelectPatient = NULL;

class CTFPlayer;
class CTFBot;

DETOUR_DECL_MEMBER1(RealizeSpy, int, CTFPlayer *, player)
{
	return 0;
}

DETOUR_DECL_STATIC4(CollectPlayers_CTFBot, int, CUtlVector<CTFBot *> *, playerVector, int, team, bool, isAlive, bool, shouldAppend)
{
	if (!shouldAppend) 
	{
		playerVector->RemoveAll();
	}
	
	for (int i = 1; i <= playerhelpers->GetMaxClients(); ++i) 
	{
		IGamePlayer *pPlayer = playerhelpers->GetGamePlayer(i);

		if (!pPlayer->IsConnected())
			continue;

		if (!pPlayer->IsInGame()) 
			continue;

		IPlayerInfo *pInfo = pPlayer->GetPlayerInfo();
		if (!pInfo)
			continue;

		if (!pInfo->IsPlayer())                                   continue;
		if (team != TEAM_ANY && pInfo->GetTeamIndex() != team)    continue;
		if (isAlive && !pInfo->IsDead())                          continue;
		
		/* actually confirm that they're a Bot */
		if(pPlayer->IsFakeClient())
		{
			CTFBot *bot = (CTFBot *)gamehelpers->ReferenceToEntity(pPlayer->GetIndex());
			playerVector->AddToTail(bot);
		}
	}
	
	return playerVector->Count();
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

DETOUR_DECL_MEMBER2(SelectPatient, int, CTFBot*, bot, CTFPlayer*, player)
{
	cell_t iBot    = gamehelpers->EntityToBCompatRef((CBaseEntity *)(bot));
	cell_t iPlayer = gamehelpers->EntityToBCompatRef((CBaseEntity *)(player));

	int iReturn            = DETOUR_MEMBER_CALL(SelectPatient)(bot, player);
	cell_t iOriginalTarget = gamehelpers->EntityToBCompatRef((CBaseEntity *)(iReturn));

//	g_pSM->LogMessage(myself, "CTFBotMedicHeal::SelectPatient medic %d old_patient %d, new_patient = %d", iBot, iPlayer, iOriginalTarget);

	if (g_pForwardSelectPatient != NULL)
	{
		g_pForwardSelectPatient->PushCell(iBot);	//medic
		g_pForwardSelectPatient->PushCell(iPlayer);	//old_patient

		cell_t iOriginalTargetReturn = iOriginalTarget;
		g_pForwardSelectPatient->PushCellByRef(&iOriginalTargetReturn); //new_patient

		cell_t result = 0;
		g_pForwardSelectPatient->Execute(&result);

		if (result > Pl_Continue)
		{
			//Convert given result to pointer
			CBaseEntity * pEntity = gamehelpers->ReferenceToEntity(iOriginalTargetReturn);
			cell_t iMyBRef = reinterpret_cast<cell_t>(pEntity);

			return iMyBRef;
		}		
	}

	return iReturn;
}

DETOUR_DECL_MEMBER1(AllowedToHealTarget, bool, CBaseEntity*, pEntity)
{
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
				
				g_pForwardAllowedToHealTarget->PushCell(iHealTarget);
				
				cell_t bOriginalResult = 0;
				g_pForwardAllowedToHealTarget->PushCellByRef(&bOriginalResult);
				
				cell_t action = Pl_Continue;
				g_pForwardAllowedToHealTarget->Execute(&action);
				
				if(action != Pl_Continue)
					return (bOriginalResult != 0);
			}
		}
	}
	return DETOUR_MEMBER_CALL(AllowedToHealTarget)(pEntity);
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
	
	g_CollectPlayers_CTFBot = DETOUR_CREATE_STATIC(CollectPlayers_CTFBot, "CollectPlayers<CTFBot>");
	if(g_CollectPlayers_CTFBot != NULL)
	{
		g_CollectPlayers_CTFBot->EnableDetour();
		g_pSM->LogMessage(myself, "CollectPlayers<CTFBot> detour enabled.");
	}
	
	g_AddFollower = DETOUR_CREATE_MEMBER(AddFollower, "CCaptureFlag::AddFollower");
	if(g_AddFollower != NULL)
	{
		g_AddFollower->EnableDetour();
		g_pSM->LogMessage(myself, "CCaptureFlag::AddFollower detour enabled.");
	}
	
	g_SelectPatient = DETOUR_CREATE_MEMBER(SelectPatient, "CTFBotMedicHeal::SelectPatient");
	if(g_SelectPatient != NULL)
	{
		g_SelectPatient->EnableDetour();
		g_pSM->LogMessage(myself, "CTFBotSquad::SelectPatient detour enabled.");
	}
	
	g_AllowedToHealTarget = DETOUR_CREATE_MEMBER(AllowedToHealTarget, "CWeaponMedigun::AllowedToHealTarget");
	if(g_AllowedToHealTarget != NULL)
	{
		g_AllowedToHealTarget->EnableDetour();
		g_pSM->LogMessage(myself, "CWeaponMedigun::AllowedToHealTarget detour enabled.");
	}
	
	//Forwards
	g_pForwardSelectPatient = forwards->CreateForward("CTFBotMedicHeal_SelectPatient", ET_Event, 3, NULL, Param_Cell, Param_Cell, Param_CellByRef);
	g_pForwardAllowedToHealTarget = forwards->CreateForward("CWeaponMedigun_IsAllowedToHealTarget", ET_Event, 3, NULL, Param_Cell, Param_Cell, Param_CellByRef);
	
	return true;
}

void CBotControl::SDK_OnUnload()
{
	gameconfs->CloseGameConfigFile(g_pGameConf);
	
	if(g_RealizeSpyDetour != NULL) g_RealizeSpyDetour->Destroy();
	if(g_CollectPlayers_CTFBot != NULL) g_CollectPlayers_CTFBot->Destroy();
	if(g_AddFollower != NULL) g_AddFollower->Destroy();
	if(g_SelectPatient != NULL) g_SelectPatient->Destroy();
	if(g_AllowedToHealTarget != NULL) g_AllowedToHealTarget->Destroy();
	
	if(g_pForwardAllowedToHealTarget != NULL) forwards->ReleaseForward(g_pForwardAllowedToHealTarget);
	if(g_pForwardSelectPatient != NULL) forwards->ReleaseForward(g_pForwardSelectPatient);
}