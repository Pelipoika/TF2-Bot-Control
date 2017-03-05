#include "extension.h"

CBotControl g_BotControl;
SMEXT_LINK(&g_BotControl);

IGameConfig *g_pGameConf = NULL;

CDetour *g_RealizeSpyDetour = NULL;
CDetour *g_GetEventChangeAttributes = NULL;
CDetour *g_AddFollower = NULL;
CDetour *g_SelectPatient = NULL;
CDetour *g_AllowedToHealTarget = NULL;

IForward *g_pForwardShouldSquadLeaderWaitForFormation = NULL;
IForward *g_pForwardAllowedToHealTarget = NULL;
IForward *g_pForwardSelectPatient = NULL;

class CTFPlayer;
class CTFBot;

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
	if(g_GetEventChangeAttributes != NULL) g_GetEventChangeAttributes->Destroy();
	if(g_AddFollower != NULL) g_AddFollower->Destroy();
	if(g_SelectPatient != NULL) g_SelectPatient->Destroy();
	if(g_AllowedToHealTarget != NULL) g_AllowedToHealTarget->Destroy();
	
	if(g_pForwardShouldSquadLeaderWaitForFormation != NULL) forwards->ReleaseForward(g_pForwardShouldSquadLeaderWaitForFormation);
	if(g_pForwardAllowedToHealTarget != NULL) forwards->ReleaseForward(g_pForwardAllowedToHealTarget);
	if(g_pForwardSelectPatient != NULL) forwards->ReleaseForward(g_pForwardSelectPatient);
}