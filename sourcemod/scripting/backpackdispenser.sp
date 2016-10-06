#include <sdktools>
#include <sdkhooks>
#include <tf2>
#include <tf2_stocks>

#pragma newdecls required

#define DISPENSER_BLUEPRINT	"models/buildables/dispenser_blueprint.mdl"

int g_CarriedDispenser[MAXPLAYERS+1];

Handle g_hSDKMakeCarriedObject;

public Plugin myinfo = 
{
	name = "[TF2] Backpack Dispenser",
	author = "Pelipoika",
	description = "Engineers can carry their dispensers on their backs",
	version = "1.0",
	url = "http://www.sourcemod.net/plugins.php?author=Pelipoika&search=1"
};

public void OnPluginStart()
{
	Handle hConfig = LoadGameConfigFile("tf2.backpackdispenser");
	
	StartPrepSDKCall(SDKCall_Entity);
	PrepSDKCall_SetFromConf(hConfig, SDKConf_Virtual, "CBaseObject::MakeCarriedObject");
	PrepSDKCall_AddParameter(SDKType_CBasePlayer, SDKPass_Pointer); //Player
	if ((g_hSDKMakeCarriedObject = EndPrepSDKCall()) == INVALID_HANDLE) SetFailState("Failed To create SDKCall for CBaseObject::MakeCarriedObject offset");
	
	delete hConfig;
	
	HookEvent("player_death", Event_PlayerDeath);
	
	for(int i = 1; i <= MaxClients; i++)
		if(IsClientInGame(i))
			OnClientPutInServer(i);
}

public void OnClientPutInServer(int client)
{
	g_CarriedDispenser[client] = INVALID_ENT_REFERENCE;
}

public void OnEntityDestroyed(int iEntity)
{
	if(IsValidEntity(iEntity))
	{
		char classname[64];
		GetEntityClassname(iEntity, classname, sizeof(classname));
		
		if(StrEqual(classname, "obj_dispenser"))
		{
			int builder = GetEntPropEnt(iEntity, Prop_Send, "m_hBuilder");
			if(builder > 0 && builder <= MaxClients && IsClientInGame(builder))
			{
				if(g_CarriedDispenser[builder] != INVALID_ENT_REFERENCE)
				{
					int Dispenser = EntRefToEntIndex(g_CarriedDispenser[builder]);

					int iLink = GetEntPropEnt(Dispenser, Prop_Send, "m_hEffectEntity");
					if(IsValidEntity(iLink))
					{
						AcceptEntityInput(iLink, "ClearParent");
						AcceptEntityInput(iLink, "Kill");
					}
					
					g_CarriedDispenser[builder] = INVALID_ENT_REFERENCE;
					
					TF2_RemoveCondition(builder, TFCond_MarkedForDeath);
				}
			}
		}
	}
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon, int &subtype, int &cmdnum, int &tickcount, int &seed, int mouse[2])
{
	if (client > 0 && client <= MaxClients && IsClientInGame(client) && TF2_GetPlayerClass(client) == TFClass_Engineer)
	{
		//When playing MvM we don't want blue engineers to be able to carry dispensers
		if(GameRules_GetProp("m_bPlayingMannVsMachine") && TF2_GetClientTeam(client) != TFTeam_Red)
			return Plugin_Changed;
	
		if(g_CarriedDispenser[client] == INVALID_ENT_REFERENCE)
		{
			if(buttons & IN_RELOAD && GetEntProp(client, Prop_Send, "m_bCarryingObject") != 1)
			{
				int iAim = GetClientAimTarget(client, false)
				if(IsValidEntity(iAim))
				{
					char strClass[64];
					GetEntityClassname(iAim, strClass, sizeof(strClass));
					if(StrEqual(strClass, "obj_dispenser") && IsBuilder(iAim, client))
					{
						EquipDispenser(client, iAim);
					}
				}
			}
		}
		else if(g_CarriedDispenser[client] != INVALID_ENT_REFERENCE)
		{
			if((buttons & IN_RELOAD && buttons & IN_ATTACK2) && GetEntProp(client, Prop_Send, "m_bCarryingObject") == 0 && g_CarriedDispenser[client] != INVALID_ENT_REFERENCE)
			{
				UnequipDispenser(client);
			}
		}
		
		return Plugin_Changed;
	}
	
	return Plugin_Continue;
}

public Action Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	
	if(client > 0 && client <= MaxClients && IsClientInGame(client) && g_CarriedDispenser[client] != INVALID_ENT_REFERENCE)
	{
		DestroyDispenser(client);
	}
}

stock void EquipDispenser(int client, int target)
{
	float dPos[3], bPos[3];
	GetEntPropVector(target, Prop_Send, "m_vecOrigin", dPos);
	GetClientAbsOrigin(client, bPos);
	
	if(GetVectorDistance(dPos, bPos) <= 125.0 && IsValidBuilding(target))
	{	
		int trigger = -1;
		while ((trigger = FindEntityByClassname(trigger, "dispenser_touch_trigger")) != -1)
		{
			if(IsValidEntity(trigger))
			{
				int ownerentity = GetEntPropEnt(trigger, Prop_Send, "m_hOwnerEntity");
				if(ownerentity == target)
				{
					SetVariantString("!activator");
					AcceptEntityInput(trigger, "SetParent", target);
				}
			}
		}

		int iLink = CreateLink(client);
		
		SetVariantString("!activator");
		AcceptEntityInput(target, "SetParent", iLink); 
		
		SetVariantString("flag"); 
		AcceptEntityInput(target, "SetParentAttachment", iLink); 

		SetEntPropEnt(target, Prop_Send, "m_hEffectEntity", iLink);
		
		float pPos[3], pAng[3];

		pPos[0] += 30.0;	//This moves it up/down
		pPos[1] += 40.0;
		
		pAng[0] += 180.0;
		pAng[1] -= 90.0;
		pAng[2] += 90.0;

		SetEntPropVector(target, Prop_Send, "m_vecOrigin", pPos);
		SetEntPropVector(target, Prop_Send, "m_angRotation", pAng);
		
		SetEntProp(target, Prop_Send, "m_usSolidFlags", 2);
		
		TF2_AddCondition(client, TFCond_MarkedForDeath, -1.0);
		
		g_CarriedDispenser[client] = EntIndexToEntRef(target);
	}
}

stock void UnequipDispenser(int client)
{
	int Dispenser = EntRefToEntIndex(g_CarriedDispenser[client]);
	if(Dispenser != INVALID_ENT_REFERENCE)
	{
		int iBuilder = GetPlayerWeaponSlot(client, view_as<int>(TFWeaponSlot_PDA));
		
		SDKCall(g_hSDKMakeCarriedObject, Dispenser, client);

		SetEntPropEnt(iBuilder, Prop_Send, "m_hObjectBeingBuilt", Dispenser); 
		SetEntProp(iBuilder, Prop_Send, "m_iBuildState", 2); 

		SetEntProp(Dispenser, Prop_Send, "m_bCarried", 1); 
		SetEntProp(Dispenser, Prop_Send, "m_bPlacing", 1); 
		SetEntProp(Dispenser, Prop_Send, "m_bCarryDeploy", 0);
		SetEntProp(Dispenser, Prop_Send, "m_iDesiredBuildRotations", 0);
		SetEntProp(Dispenser, Prop_Send, "m_iUpgradeLevel", 1);

		SetEntityModel(Dispenser, DISPENSER_BLUEPRINT); 

		SetEntPropEnt(client, Prop_Send, "m_hActiveWeapon", iBuilder); 

		int iLink = GetEntPropEnt(Dispenser, Prop_Send, "m_hEffectEntity");
		if(IsValidEntity(iLink))
		{
			AcceptEntityInput(Dispenser, "ClearParent");
			AcceptEntityInput(iLink, "ClearParent");
			AcceptEntityInput(iLink, "Kill");
			
			TF2_RemoveCondition(client, TFCond_MarkedForDeath);
		}

		g_CarriedDispenser[client] = INVALID_ENT_REFERENCE;
	}
}

stock void DestroyDispenser(int client)
{
	int Dispenser = EntRefToEntIndex(g_CarriedDispenser[client]);
	if(Dispenser != INVALID_ENT_REFERENCE)
	{
		int iLink = GetEntPropEnt(Dispenser, Prop_Send, "m_hEffectEntity");
		if(IsValidEntity(iLink))
		{
			AcceptEntityInput(iLink, "ClearParent");
			AcceptEntityInput(iLink, "Kill");
		
			SetVariantInt(5000);
			AcceptEntityInput(Dispenser, "RemoveHealth");
			
			TF2_RemoveCondition(client, TFCond_MarkedForDeath);
			
			g_CarriedDispenser[client] = INVALID_ENT_REFERENCE;
		}
	}
}

stock int CreateLink(int iClient)
{
	int iLink = CreateEntityByName("tf_taunt_prop");
	DispatchKeyValue(iLink, "targetname", "DispenserLink");
	DispatchSpawn(iLink); 
	
	char strModel[PLATFORM_MAX_PATH];
	GetEntPropString(iClient, Prop_Data, "m_ModelName", strModel, PLATFORM_MAX_PATH);
	
	SetEntityModel(iLink, strModel);
	
	SetEntProp(iLink, Prop_Send, "m_fEffects", 16|64);
	
	SetVariantString("!activator"); 
	AcceptEntityInput(iLink, "SetParent", iClient); 
	
	SetVariantString("flag");
	AcceptEntityInput(iLink, "SetParentAttachment", iClient);
	
	return iLink;
}

stock bool IsValidBuilding(int iBuilding)
{
	if (IsValidEntity(iBuilding))
	{
		if (GetEntProp(iBuilding, Prop_Send, "m_bPlacing") == 0
		 && GetEntProp(iBuilding, Prop_Send, "m_bCarried") == 0
		 && GetEntProp(iBuilding, Prop_Send, "m_bCarryDeploy") == 0)
			return true;
	}
	
	return false;
}

stock bool IsBuilder(int iBuilding, int iClient)
{
	return (GetEntPropEnt(iBuilding, Prop_Send, "m_hBuilder") == iClient);
}