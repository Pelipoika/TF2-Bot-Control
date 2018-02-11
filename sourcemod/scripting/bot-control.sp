#include <sdktools>
#include <sdkhooks>
#include <tf2>
#include <tf2_stocks>
#include <tf2items>
#include <morecolors>
#include <tf2attributes>
#include <steamworks>
#include <dhooks>
#include <bot-control>

#pragma newdecls required

enum ParticleAttachment
{
	PATTACH_ABSORIGIN = 0,			// Create at absorigin, but don't follow
	PATTACH_ABSORIGIN_FOLLOW,		// Create at absorigin, and update to follow the entity
	PATTACH_CUSTOMORIGIN,			// Create at a custom origin, but don't follow
	PATTACH_POINT,					// Create on attachment point, but don't follow
	PATTACH_POINT_FOLLOW,			// Create on attachment point, and update to follow the entity
	PATTACH_WORLDORIGIN,			// Used for control points that don't attach to an entity
	PATTACH_ROOTBONE_FOLLOW,		// Create at the root bone of the entity, and update to follow
	MAX_PATTACH_TYPES,
};

enum AttributeType
{
	NONE                    = 0,
	REMOVEONDEATH           = (1 << 0),
	AGGRESSIVE              = (1 << 1),
	SUPPRESSFIRE            = (1 << 3),
	DISABLEDODGE            = (1 << 4),
	BECOMESPECTATORONDEATH  = (1 << 5),
	RETAINBUILDINGS         = (1 << 7),
	SPAWNWITHFULLCHARGE     = (1 << 8),
	ALWAYSCRIT              = (1 << 9),
	IGNOREENEMIES           = (1 << 10),
	HOLDFIREUNTILFULLRELOAD = (1 << 11),
	ALWAYSFIREWEAPON        = (1 << 13),
	TELEPORTTOHINT          = (1 << 14),
	MINIBOSS                = (1 << 15),
	USEBOSSHEALTHBAR        = (1 << 16),
	IGNOREFLAG              = (1 << 17),
	AUTOJUMP                = (1 << 18),
	AIRCHARGEONLY           = (1 << 19),
	VACCINATORBULLETS       = (1 << 20),
	VACCINATORBLAST         = (1 << 21),
	VACCINATORFIRE          = (1 << 22),
	BULLETIMMUNE            = (1 << 23),
	BLASTIMMUNE             = (1 << 24),
	FIREIMMUNE              = (1 << 25),
	PARACHUTE               = (1 << 26),
	PROJECTILESHIELD        = (1 << 27),
};

enum MissionType
{
	NOMISSION         = 0,
	UNKNOWN           = 1,
	DESTROY_SENTRIES  = 2,
	SNIPER            = 3,
	SPY               = 4,
	ENGINEER          = 5,
	REPROGRAMMED      = 6,
};

enum WeaponRestriction
{
	UNRESTRICTED  = 0,
	MELEEONLY     = (1 << 0),
	PRIMARYONLY   = (1 << 1),
	SECONDARYONLY = (1 << 2),
};

enum
{
	INSTRUCTION_LEADER,
	INSTRUCTION_MULTIPLE
};

#define EF_BONEMERGE			0x001 	// Performs bone merge on client side
#define	EF_BRIGHTLIGHT 			0x002	// DLIGHT centered at entity origin
#define	EF_DIMLIGHT 			0x004	// player flashlight
#define	EF_NOINTERP				0x008	// don't interpolate the next frame
#define	EF_NOSHADOW				0x010	// Don't cast no shadow
#define	EF_NODRAW				0x020	// don't draw entity
#define	EF_NORECEIVESHADOW		0x040	// Don't receive no shadow
#define	EF_BONEMERGE_FASTCULL	0x080	// For use with EF_BONEMERGE. If this is set, then it places this ent's origin at its
										// parent and uses the parent's bbox + the max extents of the aiment.
										// Otherwise, it sets up the parent's bones every frame to figure out where to place
										// the aiment, which is inefficient because it'll setup the parent's bones even if
										// the parent is not in the PVS.
#define	EF_ITEM_BLINK			0x100	// blink an item so that the user notices it.
#define	EF_PARENT_ANIMATES		0x200	// always assume that the parent entity is animating

#define NUM_ENT_ENTRIES			(1 << 12)
#define ENT_ENTRY_MASK			(NUM_ENT_ENTRIES - 1)

#define BUSTER_SND_LOOP			"mvm/sentrybuster/mvm_sentrybuster_loop.wav"
#define GIANTSCOUT_SND_LOOP		"mvm/giant_scout/giant_scout_loop.wav"
#define GIANTSOLDIER_SND_LOOP	"mvm/giant_soldier/giant_soldier_loop.wav"
#define GIANTPYRO_SND_LOOP		"mvm/giant_pyro/giant_pyro_loop.wav"
#define GIANTDEMOMAN_SND_LOOP	"mvm/giant_demoman/giant_demoman_loop.wav"
#define GIANTHEAVY_SND_LOOP		")mvm/giant_heavy/giant_heavy_loop.wav"
#define BOMB_UPGRADE			"#*mvm/mvm_warning.wav"
#define SOUND_DEPLOY_SMALL		"mvm/mvm_deploy_small.wav"
#define SOUND_DEPLOY_GIANT		"mvm/mvm_deploy_giant.wav"
#define SOUND_TELEPORT_DELIVER	")mvm/mvm_tele_deliver.wav"

#define FL_EDICT_FULLCHECK	(0<<0)  // call ShouldTransmit() each time, this is a fake flag
#define FL_EDICT_ALWAYS		(1<<3)	// always transmit this entity
#define FL_EDICT_DONTSEND	(1<<4)	// don't transmit this entity
#define FL_EDICT_PVSCHECK	(1<<5)	// always transmit entity, but cull against PVS

Handle g_hHudInfo;
Handle g_hHudReload;

//SDKCalls
Handle g_hSdkEquipWearable;
Handle g_hSDKPlaySpecificSequence;
Handle g_hSDKDispatchParticleEffect;
Handle g_hSDKSetMission;
Handle g_hSDKGetSquadLeader;
Handle g_hSDKGetMaxClip;
Handle g_hSDKPickup;
Handle g_hSDKRemoveObject;
Handle g_hSDKHasTag;
Handle g_hSDKWorldSpaceCenter;
Handle g_hSDKLeaveSquad;
Handle g_hSDKPostInventoryApplication;

//DHooks
Handle g_hIsValidTarget;
Handle g_hCTFPlayerShouldGib;
Handle g_hShouldTransmit;
Handle g_hCFilterTFBotHasTag;

//Offsets
int g_iOffsetWeaponRestrictions;
int g_iOffsetSquad;
int g_iOffsetBotAttribs;
int g_iOffsetAutoJumpMin;
int g_iOffsetAutoJumpMax;
int g_iOffsetMissionBot;
int g_iOffsetSupportLimited;

int g_iCondSourceOffs = -1;
int COND_SOURCE_OFFS = 8;
int COND_SOURCE_SIZE = 20;

int g_imSharedOffs;

//Players bot & player data
int g_iPlayersBot[MAXPLAYERS+1];
int g_iPlayerAttributes[MAXPLAYERS+1];
float g_flAutoJumpMin[MAXPLAYERS+1];
float g_flAutoJumpMax[MAXPLAYERS+1];
float g_flNextJumpTime[MAXPLAYERS+1];
float g_flControlEndTime[MAXPLAYERS+1];
float g_flCooldownEndTime[MAXPLAYERS+1];
float g_flNextInstructionTime[MAXPLAYERS+1];
bool g_bControllingBot[MAXPLAYERS+1];
bool g_bReloadingBarrage[MAXPLAYERS+1];
bool g_bSkipInventory[MAXPLAYERS+1];
bool g_bCanPlayAsBot[MAXPLAYERS+1];
bool g_bRandomlyChooseBot[MAXPLAYERS+1];
bool g_bBlockRagdoll;	//Stolen from Stop that Tank

//Controlled bot data
bool g_bIsControlled[MAXPLAYERS+1];
int g_iController[MAXPLAYERS+1];

//Bot data
bool g_bIsSentryBuster[MAXPLAYERS+1];
bool g_bDeploying[MAXPLAYERS+1];
float g_flSpawnTime[MAXPLAYERS+1];

//Bomb data
int g_iFlagCarrierUpgradeLevel[MAXPLAYERS+1];
float g_flBombDeployTime[MAXPLAYERS+1];
float g_flNextBombUpgradeTime[MAXPLAYERS+1];

//+map  workshop/601600702

#define PLUGIN_VERSION "1.0"

public Plugin myinfo = 
{
	name = "[TF2] MvM Bot Control",
	author = "Pelipoika",
	description = "",
	version = PLUGIN_VERSION,
	url = "http://www.sourcemod.net/plugins.php?author=Pelipoika&search=1"
};

public void OnPluginStart()
{
	Handle hConf = LoadGameConfigFile("bot-control");
	
	//This entity is used to get an entitys center position
	StartPrepSDKCall(SDKCall_Entity);
	PrepSDKCall_SetFromConf(hConf, SDKConf_Virtual, "CBaseEntity::WorldSpaceCenter");
	PrepSDKCall_SetReturnInfo(SDKType_Vector, SDKPass_ByRef);
	if ((g_hSDKWorldSpaceCenter = EndPrepSDKCall()) == null) SetFailState("Failed to create SDKCall for CBaseEntity::WorldSpaceCenter offset!");
	
	//This call is used to equip items on clients
	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetFromConf(hConf, SDKConf_Virtual, "CTFPlayer::EquipWearable");
	PrepSDKCall_AddParameter(SDKType_CBaseEntity, SDKPass_Pointer);	//tf_wearable
	if ((g_hSdkEquipWearable = EndPrepSDKCall()) == null) SetFailState("Failed to create SDKCall for CTFBot::EquipWearable offset!"); 

	//This call is used to set the deploy animation on the robots with the bomb
	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetFromConf(hConf, SDKConf_Signature, "CTFPlayer::PlaySpecificSequence");
	PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);		//Sequence name
	if ((g_hSDKPlaySpecificSequence = EndPrepSDKCall()) == null) SetFailState("Failed to create SDKCall for CTFPlayer::PlaySpecificSequence signature!");

	//This call is used to remove an objects owner
	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetFromConf(hConf, SDKConf_Signature, "CTFPlayer::RemoveObject");
	PrepSDKCall_AddParameter(SDKType_CBaseEntity, SDKPass_Pointer);	//CBaseObject
	if ((g_hSDKRemoveObject = EndPrepSDKCall()) == null) SetFailState("Failed To create SDKCall for CTFPlayer::RemoveObject signature");

	//This call is used to (hopefully) fix wearable issues.
	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetFromConf(hConf, SDKConf_Signature, "CTFPlayer::PostInventoryApplication");
	if ((g_hSDKPostInventoryApplication = EndPrepSDKCall()) == null) SetFailState("Failed To create SDKCall for CTFPlayer::PostInventoryApplication signature");
	
	//This call is used to make sentry busters behave nicely
	StartPrepSDKCall(SDKCall_Player); 
	PrepSDKCall_SetFromConf(hConf, SDKConf_Signature, "CTFBot::SetMission");
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);	//MissionType
	PrepSDKCall_AddParameter(SDKType_Bool, SDKPass_Plain);			//StartSound
	if ((g_hSDKSetMission = EndPrepSDKCall()) == null) SetFailState("Failed to create SDKCall for CTFBot::SetMission signature!"); 
	
	//This call is used to get a bots tag
	StartPrepSDKCall(SDKCall_Player); 
	PrepSDKCall_SetFromConf(hConf, SDKConf_Signature, "CTFBot::HasTag");
	PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);	//Tag
	PrepSDKCall_SetReturnInfo(SDKType_Bool, SDKPass_Plain);
	if ((g_hSDKHasTag = EndPrepSDKCall()) == null) SetFailState("Failed to create SDKCall for CTFBot::HasTag signature!"); 
	
	//This call will make a bot leave their squad
	StartPrepSDKCall(SDKCall_Player); 
	PrepSDKCall_SetFromConf(hConf, SDKConf_Signature, "CTFBot::LeaveSquad");
	if ((g_hSDKLeaveSquad = EndPrepSDKCall()) == null) SetFailState("Failed to create SDKCall for CTFBot::LeaveSquad signature!"); 
	
	//This call is used to retrieve the leader of a squad
	StartPrepSDKCall(SDKCall_Raw);
	PrepSDKCall_SetFromConf(hConf, SDKConf_Signature, "CTFBotSquad::GetLeader");
	PrepSDKCall_SetReturnInfo(SDKType_CBasePlayer, SDKPass_Pointer);
	if ((g_hSDKGetSquadLeader = EndPrepSDKCall()) == null) SetFailState("Failed to create SDKCall for CTFBotSquad::GetLeader signature!");

	//This call will play a particle effect
	StartPrepSDKCall(SDKCall_Static);
	PrepSDKCall_SetFromConf(hConf, SDKConf_Signature, "DispatchParticleEffect");
	PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);		//pszParticleName
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);	//iAttachType
	PrepSDKCall_AddParameter(SDKType_CBaseEntity, SDKPass_Pointer);	//pEntity
	PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);		//pszAttachmentName
	PrepSDKCall_AddParameter(SDKType_Bool, SDKPass_Plain);			//bResetAllParticlesOnEntity 
	if ((g_hSDKDispatchParticleEffect = EndPrepSDKCall()) == null) SetFailState("Failed to create SDKCall for DispatchParticleEffect signature!");

	//This call gets the maximum clip 1 of a weapon
	StartPrepSDKCall(SDKCall_Entity);
	PrepSDKCall_SetFromConf(hConf, SDKConf_Virtual, "CTFWeaponBase::GetMaxClip1");
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);	//Clip
	if ((g_hSDKGetMaxClip = EndPrepSDKCall()) == null) SetFailState("Failed to create SDKCall for CTFWeaponBase::GetMaxClip1 offset!");
	
	//This call forces a player to pickup the intel
	StartPrepSDKCall(SDKCall_Entity);
	PrepSDKCall_SetFromConf(hConf, SDKConf_Virtual, "CCaptureFlag::PickUp");
	PrepSDKCall_AddParameter(SDKType_CBasePlayer, SDKPass_Pointer);	//CCaptureFlag
	PrepSDKCall_AddParameter(SDKType_Bool, SDKPass_Plain);			//silent pickup? or maybe it doesnt exist im not sure.
	if ((g_hSDKPickup = EndPrepSDKCall()) == null) SetFailState("Failed to create SDKCall for CCaptureFlag::PickUp offset!");
	
	// Member: m_bViewingCYOAPDA (offset 9100)
	
	//m_nWeaponRestrict 9580
	if(LookupOffset(g_iOffsetWeaponRestrictions, "CTFPlayer", "m_bViewingCYOAPDA"))	g_iOffsetWeaponRestrictions += GameConfGetOffset(hConf, "m_nWeaponRestrict");
	//m_nBotAttrs 9584
	if(LookupOffset(g_iOffsetBotAttribs,         "CTFPlayer", "m_bViewingCYOAPDA"))	g_iOffsetBotAttribs         += GameConfGetOffset(hConf, "m_nBotAttrs");	
	//m_flAutoJumpMin 9932
	if(LookupOffset(g_iOffsetAutoJumpMin,        "CTFPlayer", "m_bViewingCYOAPDA"))	g_iOffsetAutoJumpMin        += GameConfGetOffset(hConf, "m_flAutoJumpMin");
	//m_flAutoJumpMax 9936
	if(LookupOffset(g_iOffsetAutoJumpMax,        "CTFPlayer", "m_bViewingCYOAPDA"))	g_iOffsetAutoJumpMax        += GameConfGetOffset(hConf, "m_flAutoJumpMax");
	
	if(LookupOffset(g_iOffsetMissionBot,         "CTFPlayer", "m_nCurrency"))		g_iOffsetMissionBot         -= GameConfGetOffset(hConf, "m_bMissionBot");
	if(LookupOffset(g_iOffsetSupportLimited,     "CTFPlayer", "m_nCurrency"))		g_iOffsetSupportLimited     -= GameConfGetOffset(hConf, "m_bSupportLimited");
	
	PrintToServer("m_bViewingCYOAPDA = %i", FindSendPropInfo("CTFPlayer", "m_bViewingCYOAPDA"));
	
	g_iOffsetSquad = g_iOffsetWeaponRestrictions + GameConfGetOffset(hConf, "m_Squad");
	
	int iOffset = GameConfGetOffset(hConf, "CTFPlayer::ShouldGib");
	if(iOffset == -1) SetFailState("Failed to get offset of CTFBot::ShouldGib");
	g_hCTFPlayerShouldGib = DHookCreate(iOffset, HookType_Entity, ReturnType_Bool, ThisPointer_CBaseEntity, CTFPlayer_ShouldGib);
	DHookAddParam(g_hCTFPlayerShouldGib, HookParamType_ObjectPtr, -1, DHookPass_ByRef);
	
	iOffset = GameConfGetOffset(hConf, "CBaseEntity::ShouldTransmit");
	if(iOffset == -1) SetFailState("Failed to get offset of CBaseEntity::ShouldTransmit");
	g_hShouldTransmit = DHookCreate(iOffset, HookType_Entity, ReturnType_Int, ThisPointer_CBaseEntity, Hook_EntityShouldTransmit);
	DHookAddParam(g_hShouldTransmit, HookParamType_ObjectPtr);
	
	iOffset = GameConfGetOffset(hConf, "CTFPlayer::IsValidObserverTarget");	
	if(iOffset == -1) SetFailState("Failed to get offset of CTFPlayer::IsValidObserverTarget");
	g_hIsValidTarget = DHookCreate(iOffset, HookType_Entity, ReturnType_Bool, ThisPointer_CBaseEntity, IsValidTarget);
	DHookAddParam(g_hIsValidTarget, HookParamType_CBaseEntity);
	
	iOffset = GameConfGetOffset(hConf, "CFilterTFBotHasTag::PassesFilterImpl");	
	if(iOffset == -1) SetFailState("Failed to get offset of CFilterTFBotHasTag::PassesFilterImpl");
	g_hCFilterTFBotHasTag = DHookCreate(iOffset, HookType_Entity, ReturnType_Bool, ThisPointer_CBaseEntity, CFilterTFBotHasTag);
	DHookAddParam(g_hCFilterTFBotHasTag, HookParamType_CBaseEntity);	//Entity index of the entity using the filter
	DHookAddParam(g_hCFilterTFBotHasTag, HookParamType_CBaseEntity);	//Entity index that triggered the filter
	
	//Credits to Psychonic
	int offset = FindSendPropInfo("CTFPlayer", "m_Shared");
	if (offset == -1) SetFailState("Cannot find m_Shared on CTFPlayer.");
	g_iCondSourceOffs = offset + COND_SOURCE_OFFS;
	g_imSharedOffs = offset;
	
	delete hConf;
	
	int iEnt = -1;
	while ((iEnt = FindEntityByClassname(iEnt, "*")) != -1)
	{
		char sClassName[64];
		GetEntityClassname(iEnt, sClassName, sizeof(sClassName));
		
		OnEntityCreated(iEnt, sClassName);
	}
	
	g_hHudInfo = CreateHudSynchronizer();
	g_hHudReload = CreateHudSynchronizer();
	
	SteamWorks_SetGameDescription(":: Bot Control ::");

	AddCommandListener(Listener_Voice,      "voicemenu");
	AddCommandListener(Listener_Jointeam,   "jointeam");
	AddCommandListener(Listener_Jointeam,   "spectate");
	AddCommandListener(Listener_Block,      "autoteam");
	AddCommandListener(Listener_Block,      "kill");
	AddCommandListener(Listener_Block,      "explode");
	AddCommandListener(Listener_Build,      "build");
	AddCommandListener(Listener_ChoseHuman, "tournament_player_readystate");

	HookEvent("teamplay_flag_event",  Event_FlagEvent);
	HookEvent("player_team",          Event_PlayerTeam,  EventHookMode_Pre);
	HookEvent("player_death",         Event_PlayerDeath, EventHookMode_Pre);
	HookEvent("player_spawn",         Event_PlayerSpawn);
	HookEvent("player_builtobject",   Event_BuildObject);
	HookEvent("teamplay_round_start", Event_ResetBots);
	HookEvent("mvm_wave_complete",    Event_ResetBots);
	HookEvent("player_sapped_object", Event_SappedObject);
	
	//For idiots like AREK
	RegConsoleCmd("sm_joinred",    Command_JoinRed);
	
	RegConsoleCmd("sm_joinblue",   Command_ToggleRandomPicker);
	RegConsoleCmd("sm_joinblu",    Command_ToggleRandomPicker);
	RegConsoleCmd("sm_joinbrobot", Command_ToggleRandomPicker);
	RegConsoleCmd("sm_robot",      Command_ToggleRandomPicker);
	RegConsoleCmd("sm_randombot",  Command_ToggleRandomPicker);
	RegConsoleCmd("sm_randomrobot",  Command_ToggleRandomPicker);
	
	RegConsoleCmd("sm_debugbot",   Command_Debug);
	
	for(int client = 1; client <= MaxClients; client++)
		if(IsClientInGame(client))
			OnClientPutInServer(client);
}

public void TF2_OnWaitingForPlayersEnd()
{
	if(!TF2_IsMvM())
		SetFailState("[Bot Control] Disabling for non mvm map");
}

public Action Command_JoinRed(int client, int args)
{
	if(client > 0 && client <= MaxClients && IsClientInGame(client))
	{
		FakeClientCommand(client, "autoteam");
	}
	
	return Plugin_Handled;
}

public Action Command_ToggleRandomPicker(int client, int args)
{
	if(client <= 0 || client > MaxClients)
		return Plugin_Handled;
		
	if(!IsClientInGame(client))
		return Plugin_Handled;
		
	//Count player bots.
	int iRobotCount = 0;
	for(int i = 1; i <= MaxClients; i++)
	{
		if(!IsClientInGame(i))
			continue;
			
		if(IsFakeClient(i))
			continue;
		
		if(TF2_GetClientTeam(i) == TFTeam_Blue 
		|| TF2_GetClientTeam(i) == TFTeam_Spectator)
			iRobotCount++;
	}
	
	if(iRobotCount >= 4 && !CheckCommandAccess(client, "sm_admin", ADMFLAG_ROOT, true) || !g_bCanPlayAsBot[client])
	{
		CPrintToChat(client, "{red}Robots are full.");
		return Plugin_Handled;
	}
	
	if(!g_bRandomlyChooseBot[client])
	{			
		CPrintToChat(client, "{arcana}We will now automatically choose a bot for you when one is available! Type !randombot again to stop playing as random bots");
		g_bRandomlyChooseBot[client] = true;
	}
	else
	{
		CPrintToChat(client, "{arcana}Random bot choosing is now {red}OFF");
		g_bRandomlyChooseBot[client] = false;
	}
	
	if(TF2_GetClientTeam(client) != TFTeam_Spectator 
	&& TF2_GetClientTeam(client) != TFTeam_Blue)
	{
		TF2_ChangeClientTeam(client, TFTeam_Spectator);
	}
	
	return Plugin_Handled;
}

public void OnMapStart()
{
	PrecacheSound(SOUND_DEPLOY_SMALL);
	PrecacheSound(SOUND_DEPLOY_GIANT);
	PrecacheSound(BOMB_UPGRADE);
	PrecacheSound(BUSTER_SND_LOOP);
	PrecacheSound(SOUND_TELEPORT_DELIVER);
}

public void OnClientPutInServer(int client)
{
	g_iPlayersBot[client] = -1;
	g_bControllingBot[client] = false;	
	g_bIsControlled[client] = false;
	g_iController[client] = -1;
	g_bIsSentryBuster[client] = false;
	g_bSkipInventory[client] = false;
	g_bCanPlayAsBot[client] = true;
	
	g_flCooldownEndTime[client] = -1.0;
	g_flControlEndTime[client] = -1.0;
	g_flSpawnTime[client] = -1.0;
	
	g_flNextJumpTime[client] = 0.0;
	g_flAutoJumpMin[client] = 0.0;
	g_flAutoJumpMax[client] = 0.0;
	g_bReloadingBarrage[client] = false;
	g_iPlayerAttributes[client] = 0;
	
	g_iFlagCarrierUpgradeLevel[client] = 0;
	g_flNextBombUpgradeTime[client] = -1.0;
	g_bDeploying[client] = false;
	g_flBombDeployTime[client] = -1.0;
	
	DHookEntity(g_hCTFPlayerShouldGib, true, client);
	DHookEntity(g_hIsValidTarget,      true, client);
	
	SDKHook(client, SDKHook_SetTransmit, Hook_SpyTransmit);
}

public Action Command_Debug(int client, int args)
{
	if(client > 0 && IsClientInGame(client))
	{
		int iTarget = client;
		
		if (TF2_GetClientTeam(client) == TFTeam_Spectator)
		{
			int iObserved = GetEntPropEnt(client, Prop_Data, "m_hObserverTarget");
			if(iObserved > 0 && iObserved <= MaxClients && IsClientInGame(iObserved))
			{
				iTarget = iObserved;
			}
		}
		
		PrintToConsole(client, "\n----- \"%N\" #%i (%i) --------", iTarget, GetClientUserId(iTarget), iTarget);
		
		PrintToConsole(client, "IsFakeClient = %i", IsFakeClient(iTarget));
		
		PrintToConsole(client, "g_iPlayersBot = %i", GetClientOfUserId(g_iPlayersBot[iTarget]));
		PrintToConsole(client, "g_bControllingBot = %i", g_bControllingBot[iTarget]);
		PrintToConsole(client, "g_bIsControlled = %i", g_bIsControlled[iTarget]);
		PrintToConsole(client, "g_iController = %i", GetClientOfUserId(g_iController[iTarget]));
		PrintToConsole(client, "g_bIsSentryBuster = %i", g_bIsSentryBuster[iTarget]);
		PrintToConsole(client, "g_bSkipInventory = %i", g_bSkipInventory[iTarget]);
		PrintToConsole(client, "g_bCanPlayAsBot = %i", g_bCanPlayAsBot[iTarget]);
		
		PrintToConsole(client, "g_flCooldownEndTime = %f", g_flCooldownEndTime[iTarget]);
		PrintToConsole(client, "g_flControlEndTime = %f", g_flControlEndTime[iTarget]);
		PrintToConsole(client, "g_flSpawnTime = %f", g_flSpawnTime[iTarget]);
		
		PrintToConsole(client, "g_flNextJumpTime = %f", g_flNextJumpTime[iTarget]);
		PrintToConsole(client, "g_flAutoJumpMin = %f", g_flAutoJumpMin[iTarget]);
		PrintToConsole(client, "g_flAutoJumpMax = %f", g_flAutoJumpMax[iTarget]);
		PrintToConsole(client, "g_bReloadingBarrage = %i", g_bReloadingBarrage[iTarget]);
		PrintToConsole(client, "g_iPlayerAttributes = %i", g_iPlayerAttributes[iTarget]);
		
		Menu g_hMenuAttributes = new Menu(MenuAttributeHandler);
		g_hMenuAttributes.SetTitle("Bot Attributes\n ");
		g_hMenuAttributes.AddItem("1",  IsAttributeSet(iTarget, AGGRESSIVE)              ? "✅ AGGRESSIVE"              : "AGGRESSIVE");
		g_hMenuAttributes.AddItem("2",  IsAttributeSet(iTarget, SUPPRESSFIRE)            ? "✅ SUPPRESSFIRE"            : "SUPPRESSFIRE");
		g_hMenuAttributes.AddItem("3",  IsAttributeSet(iTarget, DISABLEDODGE)            ? "✅ DISABLEDODGE"            : "DISABLEDODGE");
		g_hMenuAttributes.AddItem("4",  IsAttributeSet(iTarget, RETAINBUILDINGS)         ? "✅ RETAINBUILDINGS"         : "RETAINBUILDINGS");
		g_hMenuAttributes.AddItem("5",  IsAttributeSet(iTarget, SPAWNWITHFULLCHARGE)     ? "✅ SPAWNWITHFULLCHARGE"     : "SPAWNWITHFULLCHARGE");
		g_hMenuAttributes.AddItem("6",  IsAttributeSet(iTarget, ALWAYSCRIT)              ? "✅ ALWAYSCRIT"              : "ALWAYSCRIT");
		g_hMenuAttributes.AddItem("7",  IsAttributeSet(iTarget, IGNOREENEMIES)           ? "✅ IGNOREENEMIES"           : "IGNOREENEMIES");
		g_hMenuAttributes.AddItem("8",  IsAttributeSet(iTarget, HOLDFIREUNTILFULLRELOAD) ? "✅ HOLDFIREUNTILFULLRELOAD" : "HOLDFIREUNTILFULLRELOAD");
		g_hMenuAttributes.AddItem("9",  IsAttributeSet(iTarget, ALWAYSFIREWEAPON)        ? "✅ ALWAYSFIREWEAPON"        : "ALWAYSFIREWEAPON");
		g_hMenuAttributes.AddItem("10", IsAttributeSet(iTarget, TELEPORTTOHINT)          ? "✅ TELEPORTTOHINT"          : "TELEPORTTOHINT");
		g_hMenuAttributes.AddItem("11", IsAttributeSet(iTarget, MINIBOSS)                ? "✅ MINIBOSS"                : "MINIBOSS");
		g_hMenuAttributes.AddItem("12", IsAttributeSet(iTarget, USEBOSSHEALTHBAR)        ? "✅ USEBOSSHEALTHBAR"        : "USEBOSSHEALTHBAR");
		g_hMenuAttributes.AddItem("13", IsAttributeSet(iTarget, IGNOREFLAG)              ? "✅ IGNOREFLAG"              : "IGNOREFLAG");
		g_hMenuAttributes.AddItem("14", IsAttributeSet(iTarget, AUTOJUMP)                ? "✅ AUTOJUMP"                : "AUTOJUMP");
		g_hMenuAttributes.AddItem("15", IsAttributeSet(iTarget, AIRCHARGEONLY)           ? "✅ AIRCHARGEONLY"           : "AIRCHARGEONLY");
		g_hMenuAttributes.AddItem("16", IsAttributeSet(iTarget, VACCINATORBULLETS)       ? "✅ VACCINATORBULLETS"       : "VACCINATORBULLETS");
		g_hMenuAttributes.AddItem("17", IsAttributeSet(iTarget, VACCINATORBLAST)         ? "✅ VACCINATORBLAST"         : "VACCINATORBLAST");
		g_hMenuAttributes.AddItem("18", IsAttributeSet(iTarget, VACCINATORFIRE)          ? "✅ VACCINATORFIRE"          : "VACCINATORFIRE");
		g_hMenuAttributes.AddItem("19", IsAttributeSet(iTarget, BULLETIMMUNE)            ? "✅ BULLETIMMUNE"            : "BULLETIMMUNE");
		g_hMenuAttributes.AddItem("20", IsAttributeSet(iTarget, BLASTIMMUNE)             ? "✅ BLASTIMMUNE"             : "BLASTIMMUNE");
		g_hMenuAttributes.AddItem("21", IsAttributeSet(iTarget, FIREIMMUNE)              ? "✅ FIREIMMUNE"              : "FIREIMMUNE");
		g_hMenuAttributes.AddItem("22", IsAttributeSet(iTarget, PARACHUTE)               ? "✅ PARACHUTE"               : "PARACHUTE");
		g_hMenuAttributes.AddItem("23", IsAttributeSet(iTarget, PROJECTILESHIELD)        ? "✅ PROJECTILESHIELD"        : "PROJECTILESHIELD");
		g_hMenuAttributes.Display(client, MENU_TIME_FOREVER);
		
		PrintToConsole(client, "------------------------ END ---------------------\n");
	}
	
	return Plugin_Handled;
}

stock bool IsAttributeSet(int client, AttributeType iAttrib)
{
	if(g_iPlayerAttributes[client] & view_as<int>(iAttrib))
		return true;
		
	return false;
}

public int MenuAttributeHandler(Menu menu, MenuAction action, int param1, int param2)
{
	if(action == MenuAction_End)
	{
		delete menu;
	}
}

public MRESReturn CFilterTFBotHasTag(int iFilter, Handle hReturn, Handle hParams)
{
	if(!GameRules_GetProp("m_bPlayingMannVsMachine") || DHookIsNullParam(hParams, 2))
		return MRES_Ignored;

	int iEntity = DHookGetParam(hParams, 1);
	int iOther  = DHookGetParam(hParams, 2);
	
	if(iOther <= 0 || iOther > MaxClients)
		return MRES_Ignored;
	
	//Don't care about real bots
	if(IsFakeClient(iOther))
		return MRES_Ignored;
	
	//Don't care about players not controlling a bot
	if(!g_bControllingBot[iOther])
		return MRES_Ignored;
	
	int iBot = GetClientOfUserId(g_iPlayersBot[iOther]);
	if(iBot <= 0)
		return MRES_Ignored;
	
	char strTags[PLATFORM_MAX_PATH]; 
	GetEntPropString(iFilter, Prop_Data, "m_iszTags", strTags, PLATFORM_MAX_PATH);
	bool bNegated = !!GetEntProp(iFilter, Prop_Data, "m_bNegated");
//	bool bRequireAllTags = !!GetEntProp(iFilter, Prop_Data, "m_bRequireAllTags");	//Don't know of a map that uses this.
	
	bool bResult = TF2_HasTag(iBot, strTags);
	if(bNegated)
		bResult = !bResult;
	
	char iEntityClassname[64];
	GetEntityClassname(iEntity, iEntityClassname, sizeof(iEntityClassname));
	
	//We don't care about you
	if(StrEqual(iEntityClassname, "func_nav_prerequisite"))
		return MRES_Ignored;
	
	//These work the opposite way
	if(StrEqual(iEntityClassname, "trigger_add_tf_player_condition"))
		bResult = !bResult;
	
//	PrintToServer("Filter %i on entity %s asks: HasTag %N %s ? %s", iFilter, iEntityClassname, iBot, strTags, bResult ? "Yes" : "No");
	
	DHookSetReturn(hReturn, bResult);
	return MRES_Supercede;
}

public MRESReturn IsValidTarget(int pThis, Handle hReturn, Handle hParams)
{
	if(!GameRules_GetProp("m_bPlayingMannVsMachine") || DHookIsNullParam(hParams, 1))
		return MRES_Ignored;
	
	int iTarget = DHookGetParam(hParams, 1);
	if(iTarget <= 0 || iTarget > MaxClients)
		return MRES_Ignored;
	
	if(!IsClientInGame(pThis) || !IsClientInGame(iTarget))
		return MRES_Ignored;
		
	if(!IsPlayerAlive(iTarget) || !IsFakeClient(pThis))
		return MRES_Ignored;
		
	if(g_bIsControlled[iTarget])
	{
		DHookSetReturn(hReturn, false);	
		return MRES_Supercede;
	}

	return MRES_Ignored;
}

public MRESReturn CTFPlayer_ShouldGib(int pThis, Handle hReturn, Handle hParams)
{
	if(GameRules_GetProp("m_bPlayingMannVsMachine") && !DHookIsNullParam(hParams, 1) && TF2_GetClientTeam(pThis) == TFTeam_Blue)
	{
		bool is_miniboss = view_as<bool>(GetEntProp(pThis, Prop_Send, "m_bIsMiniBoss"));
		float m_flModelScale = GetEntPropFloat(pThis, Prop_Send, "m_flModelScale");
		
		if(is_miniboss || m_flModelScale > 1.0)
		{
			DHookSetReturn(hReturn, true);
			return MRES_Supercede;
		}
		
		bool is_engie  = (TF2_GetPlayerClass(pThis) == TFClass_Engineer);
		bool is_medic  = (TF2_GetPlayerClass(pThis) == TFClass_Medic);
		bool is_sniper = (TF2_GetPlayerClass(pThis) == TFClass_Sniper);
		bool is_spy    = (TF2_GetPlayerClass(pThis) == TFClass_Spy);
		
		if (is_engie || is_medic || is_sniper || is_spy) {
			DHookSetReturn(hReturn, false);
			return MRES_Supercede;
		}
	}
	
	return MRES_Ignored;
}

public MRESReturn Hook_EntityShouldTransmit(int pThis, Handle hReturn, Handle hParams)
{
	if(GameRules_GetProp("m_bPlayingMannVsMachine"))
	{
		int Object = pThis;
		if(IsValidEntity(Object))
		{
			bool bCarried = (GetEntProp(Object, Prop_Send, "m_bCarried") || GetEntProp(Object, Prop_Send, "m_bPlacing"));
			if(bCarried)	//Let game decide
				return MRES_Ignored;
			
			DHookSetReturn(hReturn, FL_EDICT_ALWAYS);
			
			return MRES_Supercede;
		}
	}
	
	return MRES_Ignored;
}

public void OnClientDisconnect(int client)
{
	if(client <= 0 || client > MaxClients || !IsClientInGame(client))
		return;

	TF2_RestoreBot(client);
	g_bRandomlyChooseBot[client] = false;
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if(StrEqual(classname, "item_currencypack_custom"))
	{
		SDKHook(entity, SDKHook_SpawnPost, OnCurrencySpawnPost);
	}
	else if(StrEqual(classname, "func_respawnroom"))
	{
		SDKHook(entity, SDKHook_StartTouch, OnSpawnStartTouch);
		SDKHook(entity, SDKHook_EndTouch, OnSpawnEndTouch);
	}
	else if(StrEqual(classname, "func_capturezone"))
	{
		SDKHook(entity, SDKHook_StartTouch, OnHatchStartTouch);
		SDKHook(entity, SDKHook_EndTouch, OnHatchEndTouch);
	}
	else if(StrEqual(classname, "item_teamflag"))
	{
	//	SDKHook(entity, SDKHook_StartTouch, OnFlagStartTouch);
		SDKHook(entity, SDKHook_StartTouch, OnFlagTouch);
		SDKHook(entity, SDKHook_Touch, OnFlagTouch);
	}
	else if(g_bBlockRagdoll && StrEqual(classname, "tf_ragdoll"))
	{
		AcceptEntityInput(entity, "Kill");
		g_bBlockRagdoll = false;
	}
	else if(StrEqual(classname, "obj_teleporter"))
	{
		SDKHook(entity, SDKHook_SetTransmit, Hook_TeleporterTransmit);
	}
	else if(StrEqual(classname, "filter_tf_bot_has_tag"))
	{
		DHookEntity(g_hCFilterTFBotHasTag, true, entity);
	}
}

void Frame_SentryVision_Create(int iRef)
{
	int iSentry = EntRefToEntIndex(iRef);
	if (iSentry > MaxClients && view_as<TFTeam>(GetEntProp(iSentry, Prop_Send, "m_iTeamNum")) == TFTeam_Red)
	{
		//Create sentry-vision glow
		int iGlow = CreateEntityByName("tf_taunt_prop");
		if(iGlow > MaxClients)
		{
			//Make the sentry always transmit
			DHookEntity(g_hShouldTransmit, true, iSentry);
		
			float flModelScale = GetEntPropFloat(iSentry, Prop_Send, "m_flModelScale");
			SetEntProp(iGlow, Prop_Send, "m_nModelIndex", GetEntProp(iSentry, Prop_Send, "m_nModelIndex"));

			char model[PLATFORM_MAX_PATH];
			GetEntPropString(iSentry, Prop_Data, "m_ModelName", model, sizeof(model));
			SetEntityModel(iGlow, model);

			DispatchSpawn(iGlow);
			ActivateEntity(iGlow);

			SetEntityRenderMode(iGlow, RENDER_TRANSCOLOR);
			SetEntityRenderColor(iGlow, 0, 0, 0, 0);
			SetEntProp(iGlow, Prop_Send, "m_bGlowEnabled", true);
			SetEntPropFloat(iGlow, Prop_Send, "m_flModelScale", flModelScale);
			
			int iFlags = GetEntProp(iGlow, Prop_Send, "m_fEffects");
			SetEntProp(iGlow, Prop_Send, "m_fEffects", iFlags|EF_BONEMERGE|EF_NOSHADOW|EF_NORECEIVESHADOW);

			SetVariantString("!activator");
			AcceptEntityInput(iGlow, "SetParent", iSentry);
			
			SDKHook(iGlow, SDKHook_SetTransmit, SentryVision_OnThink);
		}
	}
}

public Action SentryVision_OnThink(int iSentryGlow, int iClient)
{
	//Who's my parent?
	int iParent = GetEntPropEnt(iSentryGlow, Prop_Send, "moveparent");
	if (iParent > MaxClients)//Safe check to know if I'm parented to the sentry and NOT carried! We don't want to put the glow on the blueprint!
	{
		bool bCarried = (GetEntProp(iParent, Prop_Send, "m_bCarried") || GetEntProp(iParent, Prop_Send, "m_bPlacing"));
		if (bCarried)//The sentry is carried, set my parent to the engie!
			iParent = GetEntPropEnt(iParent, Prop_Send, "m_hBuilder");
	}
	else if (0 < iParent <= MaxClients)//My parent is the engie.
	{
		static int iRefCarriedObjects[MAXPLAYERS+1];//Last carried object by the engie.
		
		bool bCarrying = view_as<bool>(GetEntProp(iParent, Prop_Send, "m_bCarryingObject"));
		if (bCarrying)
		{
			int iCarriedObject = GetEntPropEnt(iParent, Prop_Send, "m_hCarriedObject");
			if (iCarriedObject > MaxClients) //Save the building's index object, very important so we don't blindy loop across every sentry guns once it's placed, and end up setting 2 glows on the same sentry (i.e 2 glows on an engie's mini-sentry)
				iRefCarriedObjects[iParent] = EntIndexToEntRef(iCarriedObject);
			else
				AcceptEntityInput(iSentryGlow, "Kill");
		}
		else //The sentry is no longer carried but I'm still parented to the player, move my parent to the sentry.
		{
			int iSentry = EntRefToEntIndex(iRefCarriedObjects[iParent]);
			if (iSentry > MaxClients)
				iParent = iSentry;
			else //The sentry has been destroyed, kill our glow
				AcceptEntityInput(iSentryGlow,"Kill");
		}
	}
	
	//Keep my model and parent infos up to date.
	if (0 < iParent <= MaxClients || iParent > MaxClients)
	{
		int iOldParent = GetEntPropEnt(iSentryGlow, Prop_Send, "moveparent");
		
		if (iParent != iOldParent)
		{
			//Unparent me from my old parent.
			AcceptEntityInput(iSentryGlow,"ClearParent");
			
			float flParentPos[3];
			GetEntPropVector(iParent, Prop_Data, "m_vecAbsOrigin", flParentPos);
			TeleportEntity(iSentryGlow, flParentPos, NULL_VECTOR, NULL_VECTOR);
			
			//Parent me to the new entity.
			SetVariantString("!activator");
			AcceptEntityInput(iSentryGlow, "SetParent", iParent);
		}
		
		if (GetEntProp(iSentryGlow, Prop_Send, "m_nModelIndex") != GetEntProp(iParent, Prop_Send, "m_nModelIndex"))
		{
			//Update my model.
			char strModelSentry[PLATFORM_MAX_PATH];
			GetEntPropString(iParent, Prop_Data, "m_ModelName", strModelSentry, sizeof(strModelSentry));
			
			if (strModelSentry[0] != '\0')
			{
				SetEntityModel(iSentryGlow, strModelSentry);
				SetEntProp(iSentryGlow, Prop_Send, "m_nModelIndex", GetEntProp(iParent, Prop_Send, "m_nModelIndex"));
			}
		}
		if (GetEntPropFloat(iSentryGlow, Prop_Send, "m_flModelScale") != GetEntPropFloat(iParent, Prop_Send, "m_flModelScale")) //If the engie/sentry has been resized by another plugin, fix our glow.
			SetEntPropFloat(iSentryGlow, Prop_Send, "m_flModelScale", GetEntPropFloat(iParent, Prop_Send, "m_flModelScale"));
	}
	else //I don't have any parent, how de fuk is glow still alive? Safe check, kill.
		AcceptEntityInput(iSentryGlow, "Kill");

	if (0 < iClient <= MaxClients && IsClientInGame(iClient) && g_bIsSentryBuster[iClient]) 
		return Plugin_Continue;//Allow the sentry buster to see the glow.
		
	return Plugin_Handled;//Do not allow other players to see it.
}

public Action Event_SappedObject(Event event, const char[] name, bool dontBroadcast)
{
	int spy = GetClientOfUserId(event.GetInt("userid"));
	TFObjectType iObject = view_as<TFObjectType>(event.GetInt("object"));
	int iSapper = event.GetInt("sapperid");
	
	if(iObject == TFObject_Teleporter && spy > 0 && spy <= MaxClients && IsClientInGame(spy) && TF2_GetClientTeam(spy) == TFTeam_Blue)
	{
		AcceptEntityInput(iSapper, "Kill");
	}
}

public Action OnFlagTouch(int iEntity, int iOther)
{
	//If its not a client we don't care
	if(iOther <= 0 || iOther > MaxClients)
		return Plugin_Continue;
	
	//Only care about blues
	if(TF2_GetClientTeam(iOther) != TFTeam_Blue)
		return Plugin_Handled
	
	//Controlled bots should never be able to pickup bomb
	if(g_bIsControlled[iOther])
	{
	//	PrintToServer("%N was denied pickup: g_bIsControlled", iOther);
		return Plugin_Handled;
	}
	
	//Gatebots ignore bombs and only capture gates
	if(TF2_HasTag(iOther, "bot_gatebot"))
	{
	//	PrintToServer("%N was denied pickup: bot_gatebot", iOther);
		return Plugin_Handled;
	}
	
	//Sentry busters bust sentries not mann co
	if(g_bIsSentryBuster[iOther])
	{
	//	PrintToServer("%N was denied pickup: g_bIsSentryBuster", iOther);
		return Plugin_Handled;
	}
	
	if (g_bControllingBot[iOther])
	{
		int iBot = GetClientOfUserId(g_iPlayersBot[iOther]);
		if (iBot > 0 && iBot <= MaxClients && TF2_GetBotSquad(iBot) != Address_Null)
		{
			int iLeader = TF2_GetBotSquadLeader(iBot);
			if (iLeader != iOther)
			{
			//	PrintToServer("%N was denied pickup: iLeader != iOther", iOther);
				return Plugin_Handled;
			}
		}
	}
	
//	PrintToServer("Flag pickup allowed for %N", iOther);
	
	return Plugin_Continue;
}

public Action OnHatchStartTouch(int iEntity, int client)
{
	if(!(client > 0 && client <= MaxClients && !IsFakeClient(client)))
		return Plugin_Continue;
		
	if(!TF2_HasBomb(client))
		return Plugin_Handled;
		
	if(g_bDeploying[client])
		return Plugin_Continue;
	
	if(TF2_IsPlayerInCondition(client, TFCond_Charging)) TF2_RemoveCondition(client, TFCond_Charging);
	if(TF2_IsPlayerInCondition(client, TFCond_Taunting)) TF2_RemoveCondition(client, TFCond_Taunting);
	
	if(TF2_IsGiant(client))
		EmitSoundToAll(SOUND_DEPLOY_GIANT);
	else
		EmitSoundToAll(SOUND_DEPLOY_SMALL);
	
	BroadcastSoundToTeam(TFTeam_Spectator, "Announcer.MVM_Bomb_Alert_Deploying");
	
	TF2_PlayAnimation(client, "primary_deploybomb");			
	RequestFrame(DisableAnim, GetClientUserId(client));	
	
	SetVariantInt(1);
	AcceptEntityInput(client, "SetForcedTauntCam");
	
	g_flBombDeployTime[client] = GetGameTime() + GetConVarFloat(FindConVar("tf_deploying_bomb_time")) + 0.5;
	g_bDeploying[client] = true;
	
	return Plugin_Continue;
}

public void DisableAnim(int userid)
{
	static int iCount = 0;

	int client = GetClientOfUserId(userid)
	if(client > 0)
	{
		if(iCount > 6)
		{
			float vecClientPos[3], vecTargetPos[3];
			GetClientAbsOrigin(client, vecClientPos);
			
			vecTargetPos = TF2_GetBombHatchPosition();
			
			float v[3], ang[3];
			SubtractVectors(vecTargetPos, vecClientPos, v);
			NormalizeVector(v, v);
			GetVectorAngles(v, ang);
			
			ang[0] = 0.0;
			
			SetVariantString("1");
			AcceptEntityInput(client, "SetCustomModelRotates");
			
			SetEntProp(client, Prop_Send, "m_bUseClassAnimations", 0);
			
			char strVec[16];
			Format(strVec, sizeof(strVec), "0 %f 0", ang[1]);
			
			SetVariantString(strVec);
			AcceptEntityInput(client, "SetCustomModelRotation");
			
			iCount = 0;
		}
		else
		{
			TF2_PlayAnimation(client, "primary_deploybomb");			
			RequestFrame(DisableAnim, userid);
			iCount++;
		}
	}
}

public Action OnHatchEndTouch(int iEntity, int client)
{
	if(client > 0 && client <= MaxClients && !IsFakeClient(client) && TF2_HasBomb(client))
	{
		SetVariantString("1");
		AcceptEntityInput(client, "SetCustomModelRotates");
		
		SetEntProp(client, Prop_Send, "m_bUseClassAnimations", 1);
		
		SetVariantInt(0);
		AcceptEntityInput(client, "SetForcedTauntCam");
		
		g_flBombDeployTime[client] = -1.0;
		g_bDeploying[client] = false;
	}
}

public Action OnSpawnStartTouch(int iEntity, int iOther)
{
	int iTeam = GetEntProp(iEntity, Prop_Send, "m_iTeamNum");

	if(iTeam == view_as<int>(TFTeam_Blue) && iOther > 0 && iOther <= MaxClients && GetClientTeam(iOther) == iTeam && !IsFakeClient(iOther))
	{
		TF2_AddCondition(iOther, TFCond_UberchargedHidden);
		if (TF2_HasBomb(iOther))
			RequestFrame(UpdateBombHud, GetClientUserId(iOther));
	}
}

public Action OnSpawnEndTouch(int iEntity, int iOther)
{
	int iTeam = GetEntProp(iEntity, Prop_Send, "m_iTeamNum");

	if(iTeam == view_as<int>(TFTeam_Blue) && iOther > 0 && iOther <= MaxClients && GetClientTeam(iOther) == iTeam && !IsFakeClient(iOther))
	{
		TF2_RemoveCondition(iOther, TFCond_UberchargedHidden);
		
		if (TF2_HasBomb(iOther))
		{
			switch(g_iFlagCarrierUpgradeLevel[iOther])
			{
				case 0: g_flNextBombUpgradeTime[iOther] = GetGameTime() + GetConVarFloat(FindConVar("tf_mvm_bot_flag_carrier_interval_to_1st_upgrade")); 
				case 1: g_flNextBombUpgradeTime[iOther] = GetGameTime() + GetConVarFloat(FindConVar("tf_mvm_bot_flag_carrier_interval_to_2nd_upgrade")); 
				case 2: g_flNextBombUpgradeTime[iOther] = GetGameTime() + GetConVarFloat(FindConVar("tf_mvm_bot_flag_carrier_interval_to_3rd_upgrade"));
			}
			
			UpdateBombHud(GetClientUserId(iOther)); //The bomb hud needs to be updated BEFORE we add again the TFCond_UberchargedHidden condition
		}
		
		TF2_AddCondition(iOther, TFCond_UberchargedHidden, 1.0);
	}
}

public void TF2_OnConditionAdded(int client, TFCond cond)
{
	if(IsFakeClient(client))
	{
		if (g_bIsControlled[client] && GetEntPropEnt(client, Prop_Send, "moveparent") != -1)
			TF2_RemoveCondition(client, cond);
		
		return;
	}

	if(cond == view_as<TFCond>(114))
	{
		TF2_RemoveCondition(client, view_as<TFCond>(114));
	}
}

public void OnCurrencySpawnPost(int iCurrency)
{
	int iOwner = GetEntPropEnt(iCurrency, Prop_Send, "m_hOwnerEntity");	//The bot who dropped the money
	if(iOwner > 0 && iOwner <= MaxClients && g_bIsControlled[iOwner])
	{
		int iController = GetClientOfUserId(g_iController[iOwner]);	//The bot's controller player
		int iBot = GetClientOfUserId(g_iPlayersBot[iController]);	//The bot of the controller
		
		if(iBot > 0 && IsFakeClient(iBot) && iController > 0 && iBot == iOwner && g_bControllingBot[iController])
		{
			float flPos[3];
			GetClientAbsOrigin(iController, flPos);
			flPos[2] += 32.0;
			
			TeleportEntity(iCurrency, flPos, NULL_VECTOR, NULL_VECTOR);
		}
	}
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon, int &subtype, int &cmdnum, int &tickcount, int &seed, int mouse[2])
{
	if(IsFakeClient(client))
	{
		if(g_bIsControlled[client])
		{
			impulse = 0;
			buttons = 0;
			return Plugin_Changed;
		}
	
		return Plugin_Continue;
	}
	
	if(g_bControllingBot[client] && IsPlayerAlive(client) && (TF2_GetClientTeam(client) == TFTeam_Red || TF2_GetClientTeam(client) == TFTeam_Blue))
	{
		SetEntPropFloat(client, Prop_Send, "m_flCloakMeter", 100.0);
		
		if(g_iPlayerAttributes[client] & view_as<int>(AUTOJUMP))
		{
			if(g_flNextJumpTime[client] <= GetGameTime())
			{
				g_flNextJumpTime[client] = GetGameTime() + GetRandomFloat(g_flAutoJumpMin[client], g_flAutoJumpMax[client]);
				
				buttons |= IN_JUMP;
				SDKCall(g_hSDKDispatchParticleEffect, "rocketjump_smoke", PATTACH_POINT_FOLLOW, client, "foot_L", 0);
				SDKCall(g_hSDKDispatchParticleEffect, "rocketjump_smoke", PATTACH_POINT_FOLLOW, client, "foot_R", 0);
				
				return Plugin_Changed;
			}
			
			if(TF2_GetPlayerClass(client) == TFClass_DemoMan && g_iPlayerAttributes[client] & view_as<int>(AIRCHARGEONLY))
			{
				if(GetEntProp(client, Prop_Send, "m_bJumping"))
				{
					float flVelocity[3];
					GetEntPropVector(client, Prop_Data, "m_vecVelocity", flVelocity);
					
					if(flVelocity[2] <= 0.0)
					{
						buttons |= IN_ATTACK2;
					}
				}
				else
				{
					//AIR CHARGE ONLY
					buttons &= ~IN_ATTACK2;
				}
			}
		}
			
		int iActiveWeapon = GetEntPropEnt(client, Prop_Data, "m_hActiveWeapon");
		if(IsValidEntity(iActiveWeapon))
		{
			if(TF2_IsPlayerInCondition(client, TFCond_UberchargedHidden))
			{
				if (!(TF2_GetPlayerClass(client) == TFClass_Medic && GetPlayerWeaponSlot(client, TFWeaponSlot_Secondary) == iActiveWeapon))
				{
					//Allow medic to heal in spawn if they have their medigun out.
					SetEntPropFloat(client, Prop_Send, "m_flStealthNoAttackExpire", GetGameTime() + 0.5);
				}
				
				//Disallow crouching in spawn so when you lose control of your bot the bot wont spawn inside ground.
				buttons &= ~IN_DUCK;
			}
			
			if(g_iPlayerAttributes[client] & view_as<int>(HOLDFIREUNTILFULLRELOAD))
			{
				int iClip1 = GetEntProp(iActiveWeapon, Prop_Send, "m_iClip1");
				
				if(iClip1 <= 0)
				{
					g_bReloadingBarrage[client] = true;
					
					SetHudTextParams(-1.0, -0.55, 0.75, 255, 0, 0, 255, 0, 0.0, 0.0, 0.0);
					ShowSyncHudText(client, g_hHudReload, "RELOADING BARRAGE!");
				}
				else if(g_bReloadingBarrage[client])
				{
					int iMaxClip1 = SDKCall(g_hSDKGetMaxClip, iActiveWeapon);
					
					SetHudTextParams(-1.0, -0.55, 0.25, 255, 150, 0, 255, 0, 0.0, 0.0, 0.0);
					ShowSyncHudText(client, g_hHudReload, "RELOADING... (%i / %i)", iClip1, iMaxClip1);
					
					//Allows reloading even if the user is holding attack, although it looks weird on their screen.
					buttons &= ~IN_ATTACK;
					buttons &= ~IN_ATTACK2;
					SetEntPropFloat(client, Prop_Send, "m_flStealthNoAttackExpire", GetGameTime() + 0.25);
					
					if(iClip1 >= iMaxClip1)
					{
						SetHudTextParams(-1.0, -0.55, 1.75, 0, 255, 0, 255, 0, 0.0, 0.0, 0.0);
						ShowSyncHudText(client, g_hHudReload, "READY TO FIRE! (%i / %i)", iClip1, iMaxClip1);
					
						g_bReloadingBarrage[client] = false;
					}
				}
			}
			
			if(g_iPlayerAttributes[client] & view_as<int>(ALWAYSFIREWEAPON) && !g_bReloadingBarrage[client])
			{
				buttons |= IN_ATTACK;
			}
		}
	
		int iBot = GetClientOfUserId(g_iPlayersBot[client]);
		if(iBot > 0 && IsFakeClient(iBot))
		{
			SetHudTextParams(1.0, 0.0, 0.1, 88, 133, 162, 0, 0, 0.0, 0.0, 0.0);
			ShowSyncHudText(client, g_hHudInfo, "Playing as %N", iBot);
			SetEntPropFloat(iBot, Prop_Send, "m_flStealthNoAttackExpire", GetGameTime() + 0.5);//don't allow the bot to attack
			
			TF2_InstructPlayer(client);
			
			if(TF2_IsPlayerInCondition(client, TFCond_UberchargedHidden))
			{
				if(g_flControlEndTime[client] <= GetGameTime())
				{
					CPrintToChat(client, "{red}You have lost control of {blue}%N{red} and received a 30 second cooldown from playing as a robot for staying in spawn too long", iBot);
					
					g_bControllingBot[client] = false;
					g_bRandomlyChooseBot[client] = false;
					
					TF2_RestoreBot(client);
					TF2_ChangeClientTeam(client, TFTeam_Spectator);
					
					g_flCooldownEndTime[client] = GetGameTime() + 30.0;
					
					return Plugin_Continue;
				}
				else if(g_flControlEndTime[client] > GetGameTime())
				{
					float flTimeLeft = g_flControlEndTime[client] - GetGameTime();
					
					if(flTimeLeft <= 15.0)
					{
						SetHudTextParams(-1.0, -0.8, 0.1, 255, 0, 0, 0, 0, 0.0, 0.0, 0.0);
						ShowSyncHudText(client, g_hHudInfo, "You have %.0f seconds to leave spawn or you will lose control of your bot", flTimeLeft);
					}
				}
			}
			
			if(g_bIsSentryBuster[client] && GetEntPropEnt(client, Prop_Data, "m_hGroundEntity") != -1)
			{
				float flPos[3], flAng[3];
				GetClientAbsOrigin(client, flPos);
				GetClientEyeAngles(client, flAng);
			
				// Disable the use of the sentry buster's caber
				SetEntPropFloat(client, Prop_Send, "m_flStealthNoAttackExpire", GetGameTime() + 0.5);

				//Detonate buster if the player is pressing M1 or taunting
				if((buttons & IN_ATTACK || TF2_IsPlayerInCondition(client, TFCond_Taunting)) && !(g_iPlayerAttributes[client] & view_as<int>(ALWAYSFIREWEAPON)))
				{
					TF2_RestoreBot(client);
					TF2_ChangeClientTeam(client, TFTeam_Spectator);
				}
				
				//Sentry Buster: Check for engineers carrying buildings nearby.
				for(int i = 1; i <= MaxClients; i++)
				{
					if(i == client)
						continue;
				
					if(!IsClientInGame(i))
						continue;
						
					if(GetClientTeam(i) == GetClientTeam(client))
						continue;
				
					if(!GetEntProp(i, Prop_Send, "m_bCarryingObject"))
						continue;
						
					float iPos[3];
					GetClientAbsOrigin(i, iPos);
					
					float flDistance = GetVectorDistance(flPos, iPos);
					
					if(flDistance <= 100.0)
					{
						TF2_RestoreBot(client);
						TF2_ChangeClientTeam(client, TFTeam_Spectator);
					}
				}
			}
			else
				SetEntProp(iBot, Prop_Send, "m_iHealth", GetEntProp(client, Prop_Send, "m_iHealth"));
		}
		
		if(TF2_HasBomb(client))
		{
			if(g_bDeploying[client])
			{
				if(g_flBombDeployTime[client] <= GetGameTime())
				{
					if(iBot > 0 && IsFakeClient(iBot))
						CPrintToChatAll("{blue}%N{default} playing as {blue}%N{default} deployed the {unique}BOMB{default} with {red}%i HP!", client, iBot, GetEntProp(client, Prop_Send, "m_iHealth"));
					else
						CPrintToChatAll("{blue}%N{default} deployed the {unique}BOMB{default} with {red}%i HP!", client, GetEntProp(client, Prop_Send, "m_iHealth"));
					
					g_bBlockRagdoll = true;
					g_bDeploying[client] = false;
					
					TF2_RobotsWin();
					
					g_flCooldownEndTime[client] = GetGameTime() + 10.0;
					
					BroadcastSoundToTeam(TFTeam_Spectator, "Announcer.MVM_Robots_Planted");
				}
				
				buttons &= ~(IN_JUMP|IN_ATTACK|IN_ATTACK2|IN_ATTACK3);
				
				ScaleVector(vel, 0.0);
				
				return Plugin_Changed;
			}
		
			if(!TF2_IsPlayerInCondition(client, TFCond_Taunting) && !TF2_IsPlayerInCondition(client, TFCond_UberchargedHidden) && !g_bDeploying[client])
			{
				buttons &= ~IN_JUMP;
				
				if(!TF2_IsGiant(client))
				{
					if(g_iFlagCarrierUpgradeLevel[client] > 0)
					{
						float pPos[3];
						GetClientAbsOrigin(client, pPos);
						
						for(int i = 1; i <= MaxClients; i++)
						{
							if(i == client)
								continue;
						
							if(!IsClientInGame(i))
								continue;
								
							if(GetClientTeam(i) != GetClientTeam(client))
								continue;
							
							if(g_iFlagCarrierUpgradeLevel[client] < 1)
								continue;
								
							float iPos[3];
							GetClientAbsOrigin(i, iPos);
							
							float flDistance = GetVectorDistance(pPos, iPos);
							
							if(flDistance <= 450.0)
							{
								TF2_AddCondition(i, TFCond_DefenseBuffNoCritBlock, 0.125);
							}
						}
					}
					if(g_flNextBombUpgradeTime[client] <= GetGameTime() && g_iFlagCarrierUpgradeLevel[client] < 3 && GetEntPropEnt(client, Prop_Send, "m_hGroundEntity") != -1)	//Time to upgrade
					{
						FakeClientCommand(client, "taunt");
						
						if(TF2_IsPlayerInCondition(client, TFCond_Taunting))
						{
							g_iFlagCarrierUpgradeLevel[client]++;
							
							switch(g_iFlagCarrierUpgradeLevel[client])
							{
								case 1: 
								{
									g_flNextBombUpgradeTime[client] = GetGameTime() + GetConVarFloat(FindConVar("tf_mvm_bot_flag_carrier_interval_to_2nd_upgrade")); 
									TF2_AddCondition(client, TFCond_DefenseBuffNoCritBlock, TFCondDuration_Infinite);
									
									SDKCall(g_hSDKDispatchParticleEffect, "mvm_levelup1", PATTACH_POINT_FOLLOW, client, "head", 0);
								}
								case 2: 
								{
									g_flNextBombUpgradeTime[client] = GetGameTime() + GetConVarFloat(FindConVar("tf_mvm_bot_flag_carrier_interval_to_3rd_upgrade"));
									
									Address pRegen = TF2Attrib_GetByName(client, "health regen");
									float flRegen = 0.0;
									if(pRegen != Address_Null)
										flRegen = TF2Attrib_GetValue(pRegen);
									
									TF2Attrib_SetByName(client, "health regen", flRegen + 45.0);
									SDKCall(g_hSDKDispatchParticleEffect, "mvm_levelup2", PATTACH_POINT_FOLLOW, client, "head", 0);
								}
								case 3: 
								{
									TF2_AddCondition(client, TFCond_CritOnWin, TFCondDuration_Infinite);
									SDKCall(g_hSDKDispatchParticleEffect, "mvm_levelup3", PATTACH_POINT_FOLLOW, client, "head", 0);
								}
							}
							EmitSoundToAll(BOMB_UPGRADE, SOUND_FROM_WORLD, SNDCHAN_STATIC, SNDLEVEL_NONE, SND_NOFLAGS, 0.500, SNDPITCH_NORMAL);
							RequestFrame(UpdateBombHud, GetClientUserId(client));
						}
					}
				}
				else if (g_iFlagCarrierUpgradeLevel[client] != 4)
				{
					g_iFlagCarrierUpgradeLevel[client] = 4;
					RequestFrame(UpdateBombHud, GetClientUserId(client));
				}
			}				
		}
	}
	else
	{
		if(g_bRandomlyChooseBot[client] && TF2_GetClientTeam(client) == TFTeam_Spectator && !g_bControllingBot[client] && g_bCanPlayAsBot[client] && g_flCooldownEndTime[client] <= GetGameTime())
		{		
			int iPlayerarray[MAXPLAYERS+1];
			int iPlayercount;
			
			for(int i = 1; i <= MaxClients; i++)
			{
				if(!IsClientInGame(i))
					continue;
				
				if(!IsFakeClient(i))
				 	continue;
				 	
				if(!IsPlayerAlive(i))
					continue;
					
				if(TF2_GetClientTeam(i) != TFTeam_Blue)
					continue;
					
				if(g_bIsControlled[i])
					continue;
				
				if(TF2_IsPlayerInCondition(i, TFCond_MVMBotRadiowave) || TF2_IsPlayerInCondition(i, TFCond_Taunting))
					continue;
					
				if(GetEntProp(i, Prop_Data, "m_takedamage") != 0)
				{
					float flSpawnedAgo = GetGameTime() - g_flSpawnTime[i];
					if(TF2_GetPlayerClass(i) != TFClass_Spy && flSpawnedAgo >= 1.5) //Allow the bots some time to spawn
					{
						iPlayerarray[iPlayercount] = i;
						iPlayercount++;
					}
					else if(TF2_GetPlayerClass(i) == TFClass_Spy && flSpawnedAgo >= 5.0) //Spies need extra time to teleport
					{
						iPlayerarray[iPlayercount] = i;
						iPlayercount++;
					}
				}
			}
			
			if(iPlayercount)
			{
				int target = iPlayerarray[GetRandomInt(0, iPlayercount-1)];
				
				TF2_MirrorPlayer(target, client);
				CPrintToChatAll("{blue}%N{default} was auto-assigned to play as {blue}%N", client, target);
			}
		}
		
		int iObserved = GetEntPropEnt(client, Prop_Send, "m_hObserverTarget");
	
		if(TF2_ObservedIsValidClient(client))
		{
			SetHudTextParams(1.0, 0.0, 0.1, 126, 126, 126, 0, 0, 0.0, 0.0, 0.0);
			ShowSyncHudText(client, g_hHudInfo, "Call for MEDIC! to play as %N", iObserved);
		}
		else if(iObserved > 0 && iObserved <= MaxClients && IsFakeClient(iObserved))
		{
			if(GetEntProp(client, Prop_Send, "m_iObserverMode") == 4 || GetEntProp(client, Prop_Send, "m_iObserverMode") == 5)
			{
				SetHudTextParams(1.0, 0.0, 0.1, 255, 0, 0, 0, 0, 0.0, 0.0, 0.0);
				ShowSyncHudText(client, g_hHudInfo, "Cannot play as %N", iObserved);
			}
		}
	}
	
	return Plugin_Continue;
}

void TF2_InstructPlayer(int client)
{
 	//Instruction
	if (g_flNextInstructionTime[client] <= GetGameTime())
	{
		int iBot = GetClientOfUserId(g_iPlayersBot[client]);
		if(iBot <= 0)
			return;
	
		if (TF2_HasBomb(client))
		{
			float vecPos[3]; vecPos = TF2_GetBombHatchPosition();
			Annotate(vecPos, client, "Deploy the bomb!", INSTRUCTION_MULTIPLE, 6.0);
		}
		else
		{
			int iLeader = TF2_GetBotSquadLeader(iBot);
			if (iLeader > 0 && iLeader <= MaxClients && IsClientInGame(iLeader) && IsPlayerAlive(iLeader) && iLeader != client)
			{
				//In squad
				
				char sMessage[128];
				if (TF2_GetPlayerClass(client) == TFClass_Medic)
				{
					int iWepSecondary = GetPlayerWeaponSlot(client, TFWeaponSlot_Secondary);
					if (iWepSecondary > MaxClients && GetEntPropEnt(iWepSecondary, Prop_Send, "m_hHealingTarget") != iLeader)
						Format(sMessage, sizeof(sMessage), "Heal your squad leader!");
					else if (iWepSecondary == -1)
						Format(sMessage, sizeof(sMessage), "Protect your squad leader!");
				}
				else
					Format(sMessage, sizeof(sMessage), "Protect your squad leader!");
					
				if (!StrEqual(sMessage, ""))
					Annotate(NULL_VECTOR, client, sMessage, INSTRUCTION_LEADER, 6.0, iLeader);
			}
			else
			{
				//Not in squad
				
				//If they're a gatebot tell them to capture the next available gate.
				if(TF2_HasTag(iBot, "bot_gatebot"))
				{
					int iTrigger = -1;
					while ((iTrigger = FindEntityByClassname(iTrigger, "trigger_timer_door")) != -1)
					{
						char iszCapPointName[64];
						GetEntPropString(iTrigger, Prop_Data, "m_iszCapPointName", iszCapPointName, sizeof(iszCapPointName));
						
						bool bDisabled = !!GetEntProp(iTrigger, Prop_Data, "m_bDisabled");
						
						if(!bDisabled)
						{
							Annotate(WorldSpaceCenter(iTrigger), client, "Capture!", iTrigger, 8.0);
							break;
						}
					}
				}
				else
				{
					//Not a gatebot, Get Bomb
					int iBomb = -1;
					while ((iBomb = FindEntityByClassname(iBomb, "item_teamflag")) != -1)
					{
						//Ignore bombs not in play
						if(GetEntProp(iBomb, Prop_Send, "m_nFlagStatus") == 0)
							continue;
						
						//Ignore bombs not on our team
						if (GetEntProp(iBomb, Prop_Send, "m_iTeamNum") != view_as<int>(TFTeam_Blue))
							continue;
						
						int moveparent = GetEntPropEnt(iBomb, Prop_Send, "moveparent");
						if(moveparent != -1 && moveparent <= MaxClients)
						{
							Annotate(NULL_VECTOR, client, "Escort the bomb carrier!", iBomb, 6.0, moveparent);
						}
						else
						{
							Annotate(NULL_VECTOR, client, "Pickup the bomb!", iBomb, 6.0, iBomb);
						}
					}
				}
			}
		}
		
		g_flNextInstructionTime[client] = GetGameTime() + 30.0; //To-Do make cvar for this
	}
}

public void Event_FlagEvent(Event event, const char[] name, bool dontBroadcast)
{
	int client = event.GetInt("player");
	int eventtype = event.GetInt("eventtype");
	
	if(client <= 0 || client > MaxClients || !IsClientInGame(client))
		return;
	
	if(eventtype == TF_FLAGEVENT_DEFENDED)
		return;
	
	if(eventtype == TF_FLAGEVENT_PICKEDUP)
	{
		if(!IsFakeClient(client))
		{
			if(TF2_IsGiant(client))	//Giants have max flag level and cant receive buffs
			{
				g_iFlagCarrierUpgradeLevel[client] = 4;
				g_flNextBombUpgradeTime[client] = GetGameTime();
			}
			else if(g_iFlagCarrierUpgradeLevel[client] == 0)	//Start upgrading from the beginning
			{
				g_flNextBombUpgradeTime[client] = GetGameTime() + GetConVarFloat(FindConVar("tf_mvm_bot_flag_carrier_interval_to_1st_upgrade")); 
			}
			else if(!TF2_IsGiant(client))	//Add existing buffs
			{
				if(g_iFlagCarrierUpgradeLevel[client] >= 1) TF2_AddCondition(client, TFCond_DefenseBuffNoCritBlock, TFCondDuration_Infinite);
				if(g_iFlagCarrierUpgradeLevel[client] == 3) TF2_AddCondition(client, TFCond_CritOnWin, TFCondDuration_Infinite);
			}
			
			RequestFrame(UpdateBombHud, GetClientUserId(client));
		}
	}
	else
	{
		if(!IsFakeClient(client))
		{
			TF2_RemoveCondition(client, TFCond_DefenseBuffNoCritBlock);
			TF2_RemoveCondition(client, TFCond_CritOnWin);
			
			Address pRegen = TF2Attrib_GetByName(client, "health regen");
			float flRegen = 0.0;
			if(pRegen != Address_Null)
			{
				flRegen = TF2Attrib_GetValue(pRegen);
				
				if(flRegen > 45.0)
				{
					TF2Attrib_SetValue(pRegen, flRegen - 45.0);
					TF2Attrib_ClearCache(client);
				}
				else
				{
					TF2Attrib_RemoveByName(client, "health regen");
				}
			}
		}
		
		g_iFlagCarrierUpgradeLevel[client] = 0;
		g_flNextBombUpgradeTime[client] = GetGameTime();
	}
}

stock float[] TF2_GetBombHatchPosition()
{
	float flOrigin[3];

	int iHole = -1;	
	while ((iHole = FindEntityByClassname(iHole, "func_capturezone")) != -1)
	{
		flOrigin = WorldSpaceCenter(iHole);
		break;
	}
	
	return flOrigin;
}

public void UpdateBombHud(int userid)
{
	int client = GetClientOfUserId(userid)
	if(client <= 0)
		return;
		
	int iResource = FindEntityByClassname(-1, "tf_objective_resource");
	SetEntProp(iResource,      Prop_Send, "m_nFlagCarrierUpgradeLevel", g_iFlagCarrierUpgradeLevel[client]);
	SetEntPropFloat(iResource, Prop_Send, "m_flMvMBaseBombUpgradeTime", (TF2_IsPlayerInCondition(client, TFCond_UberchargedHidden)) ? -1.0 : GetGameTime());
	SetEntPropFloat(iResource, Prop_Send, "m_flMvMNextBombUpgradeTime", (TF2_IsPlayerInCondition(client, TFCond_UberchargedHidden)) ? -1.0 : g_flNextBombUpgradeTime[client]);	
}

public void Event_ResetBots(Event event, const char[] name, bool dontBroadcast)
{
	for(int client = 1; client <= MaxClients; client++)
	{
		if(!IsClientInGame(client))
			continue;
			
		g_bCanPlayAsBot[client] = true;
	
		if(IsFakeClient(client) || !g_bControllingBot[client])
			continue;
			
		ForcePlayerSuicide(client);
	}
}

float flLastTeleSoundTime;

public void Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	
	if(client <= 0 || client > MaxClients || !IsClientInGame(client))
		return;

	g_flSpawnTime[client] = GetGameTime();

	if(!IsFakeClient(client))
	{
		if(g_bSkipInventory[client])
		{
			TF2_RestoreBot(client);
			TF2_ChangeClientTeam(client, TFTeam_Spectator);

			g_bSkipInventory[client] = false;
		}
	}
	
	if(TF2_GetClientTeam(client) == TFTeam_Blue && TF2_GetPlayerClass(client) != TFClass_Spy)
	{
		//Accessing m_nBotAttribs on players is dangerous.
		int iBotAttrs = IsFakeClient(client) ? GetEntData(client, g_iOffsetBotAttribs) : g_iPlayerAttributes[client];
		if(!(iBotAttrs & view_as<int>(TELEPORTTOHINT)))
		{
			int iTele = TF2_FindTeleNearestToBombHole();
			if(IsValidEntity(iTele))
			{
				float flPos[3];
				GetEntPropVector(iTele, Prop_Send, "m_vecOrigin", flPos);
				
				flPos[2] += 15.0;
				//Bots need to be teleported to player teleporters
				//Players need to be teleported to all teleporters
				
				TF2_RemoveCondition(client, TFCond_UberchargedHidden);
				TF2_AddCondition(client, TFCond_UberchargedCanteen, 5.0);
				TF2_AddCondition(client, TFCond_UberchargeFading, 5.0);
				
				int iBuilder = EntRefToEntIndex(GetEntPropEnt(iTele, Prop_Send, "m_hBuilder"));
				if(iBuilder > 0 && iBuilder <= MaxClients && IsClientInGame(iBuilder) && IsFakeClient(client) && !IsFakeClient(iBuilder))
				{
					TeleportEntity(client, flPos, NULL_VECTOR, NULL_VECTOR);
					
					//Anti ear rape
					float flSpawnedAgo = GetGameTime() - flLastTeleSoundTime;
					if(flSpawnedAgo >= 1.0)
					{
						EmitSoundToAll(SOUND_TELEPORT_DELIVER, iTele, SNDCHAN_STATIC, 150, _, 1.0);
					}
					
					flLastTeleSoundTime = GetGameTime();
				}
			}
		}
	}
}

public Action Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));

	SetEntProp(client, Prop_Send, "m_bUseBossHealthBar", 0);
	TF2_StopSounds(client);
	
	if(!IsFakeClient(client) && g_bControllingBot[client])
	{
		int iBot = GetClientOfUserId(g_iPlayersBot[client]);
		
		if(iBot > 0 && IsFakeClient(iBot))
		{
			if(g_bIsSentryBuster[client])
			{
				TF2_DetonateBuster(client);
				TF2_ClearBot(client);
				TF2_ChangeClientTeam(client, TFTeam_Spectator);
			}
			else
			{
				int attacker = GetClientOfUserId(event.GetInt("attacker"));
				TF2_KillBot(client, (0 < attacker <= MaxClients && TF2_GetPlayerClass(attacker) == TFClass_Sniper) ? attacker : -1);
			}
		}
	}
	
	if(IsFakeClient(client) && g_bIsControlled[client])
	{
		dontBroadcast = true;
		g_bBlockRagdoll = true;
		
		return Plugin_Changed;
	}
	
	g_bIsControlled[client] = false;
	g_iController[client] = -1;
	
	return Plugin_Continue;
}

public Action Event_PlayerTeam(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	TFTeam iTeam = view_as<TFTeam>(event.GetInt("team"));
	TFTeam iOldTeam = view_as<TFTeam>(event.GetInt("oldteam"));
	
	if(iTeam == TFTeam_Spectator)
	{	
		if(g_bControllingBot[client])
		{
			TF2_RestoreBot(client);
			TF2_ChangeClientTeam(client, TFTeam_Spectator);	
			TF2_RespawnPlayer(client);	//No gibs / ragdoll
			
			g_flCooldownEndTime[client] = GetGameTime() + 10.0;
		}
	}
	
	//Don't show joining spectator from blue team or joining blue team
	if(!IsFakeClient(client))
	{
		SetEntProp(client, Prop_Data, "m_bPredictWeapons", true);
	
		if(iOldTeam == TFTeam_Blue || iTeam == TFTeam_Blue)
		{
			event.SetInt("silent", 1);
			
			return Plugin_Changed;
		}
	}
	
	return Plugin_Continue;
}

public Action Event_BuildObject(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	
	if(!IsFakeClient(client) && g_bControllingBot[client] && TF2_GetPlayerClass(client) == TFClass_Engineer)
	{
		TFObjectType TFObject = view_as<TFObjectType>(event.GetInt("object"));
		int iEnt = event.GetInt("index");
		
		if(TFObject == TFObject_Teleporter)
		{
			SetEntProp(iEnt, Prop_Send, "m_iUpgradeMetalRequired", -5000);
			
			int iHealth = GetEntProp(iEnt, Prop_Send, "m_iMaxHealth") * GetConVarInt(FindConVar("tf_bot_engineer_building_health_multiplier"));
			
			SetEntProp(iEnt, Prop_Data, "m_iMaxHealth", iHealth);
			SetVariantInt(iHealth);
			AcceptEntityInput(iEnt, "SetHealth");
			
			SDKHook(iEnt, SDKHook_GetMaxHealth, OnObjectThink);
		}
		else
		{
			DispatchKeyValue(iEnt, "defaultupgrade", "2");
		}
	}
	
	if (IsClientInGame(client) && TF2_GetPlayerClass(client) == TFClass_Engineer && TF2_GetClientTeam(client) == TFTeam_Red)
	{
		TFObjectType TFObject = view_as<TFObjectType>(event.GetInt("object"));
		
		if (TFObject == TFObject_Sentry)
		{
			int iEnt = event.GetInt("index");
			RequestFrame(Frame_SentryVision_Create, EntIndexToEntRef(iEnt));
		}
	}
	
	return Plugin_Continue;
}

public Action OnObjectThink(int iEnt)
{
	TFObjectType TFObject = TF2_GetObjectType(iEnt);
	float flPercentageConstructed = GetEntPropFloat(iEnt, Prop_Send, "m_flPercentageConstructed");
	
	if(flPercentageConstructed == 1.0)
	{
		if(TFObject == TFObject_Teleporter)
		{
			AddParticle(iEnt, "teleporter_mvm_bot_persist");
			SDKUnhook(iEnt, SDKHook_GetMaxHealth, OnObjectThink);
		}
	}
}

public Action Listener_ChoseHuman(int client, char[] command, int args)
{
	if(!IsClientInGame(client) || !g_bCanPlayAsBot[client] || !IsPlayerAlive(client))
		return Plugin_Continue;
		
	if(TF2_GetClientTeam(client) != TFTeam_Red)
		return Plugin_Continue;
		
	char strArg1[8];
	GetCmdArg(1, strArg1, sizeof(strArg1));
	
	//Player pressed F4
	if(StringToInt(strArg1) == 1)
		g_bCanPlayAsBot[client] = false;
	
	return Plugin_Continue;
}

public Action Listener_Build(int client, char[] command, int args)
{
	if(IsClientInGame(client) && g_bControllingBot[client] && IsPlayerAlive(client))
	{
		if(TF2_GetClientTeam(client) == TFTeam_Blue && TF2_GetPlayerClass(client) == TFClass_Engineer)
		{
			char strArg1[8], strArg2[8];
			GetCmdArg(1, strArg1, sizeof(strArg1));
			GetCmdArg(2, strArg2, sizeof(strArg2));
			
			TFObjectType objType = view_as<TFObjectType>(StringToInt(strArg1));
			TFObjectMode objMode = view_as<TFObjectMode>(StringToInt(strArg2));
			int iCount = TF2_GetObjectCount(client, objType);
			
			if(iCount >= 1)
				return Plugin_Handled;
			
			if(objType == TFObject_Teleporter && objMode == TFObjectMode_Entrance)
				return Plugin_Handled;
		}
	}
	
	return Plugin_Continue;
}

//Detours
public Action CTFBotMedicHeal_SelectPatient(int actor, int old_patient, int &desiredPatient)
{
//	PrintToChatAll("actor %i old_patient %i desiredPatient %i", actor, old_patient, desiredPatient);
	
	Address MedicsBotsSquad = TF2_GetBotSquad(actor);
	if(MedicsBotsSquad != Address_Null)
	{	
		int iLeader = SDKCall(g_hSDKGetSquadLeader, MedicsBotsSquad);
		int iLeader2 = TF2_GetBotSquadLeader(actor);
		
		desiredPatient = iLeader;
		
		if(iLeader2 > 0)
			desiredPatient = iLeader2;
		
	//	PrintToChatAll("iLeader = %i, iLeader2 = %i", iLeader, iLeader2);
		
		return Plugin_Changed;
	}

	return Plugin_Continue;
}

public Action CWeaponMedigun_IsAllowedToHealTarget(int iMedigun, int iHealTarget, bool& bResult)
{
	int iOwner = GetEntPropEnt(iMedigun, Prop_Send, "m_hOwnerEntity");
	if (iOwner > 0 && iOwner <= MaxClients && IsClientInGame(iOwner))
	{
		if (IsFakeClient(iOwner) && g_bIsControlled[iOwner])
		{
			bResult = false;//Don't allow a controlled bot to heal
			return Plugin_Changed;
		}
		
		if (IsFakeClient(iOwner)) 
			return Plugin_Continue;
			
		if (!g_bControllingBot[iOwner]) 
			return Plugin_Continue;
		
		int iBot = GetClientOfUserId(g_iPlayersBot[iOwner]);
		if (iBot > 0 && iBot <= MaxClients && IsPlayerAlive(iBot))
		{
			int iLeader = TF2_GetBotSquadLeader(iBot);
			if (iLeader > 0 && iLeader <= MaxClients && IsClientInGame(iLeader) && IsPlayerAlive(iLeader) && iLeader != iBot)//If the player is controlling the leader then no need to restrict his heal target
			{
				bResult = (iHealTarget == iLeader);
				return Plugin_Changed;
			}
		}
	}
	
	return Plugin_Continue;
}

stock int TF2_GetObjectCount(int client, TFObjectType type)
{
	int iObject = -1, iCount = 0;
	while ((iObject = FindEntityByClassname(iObject, "obj_*")) != -1)
	{
		TFObjectType iObjType = TF2_GetObjectType(iObject);
		if(GetEntPropEnt(iObject, Prop_Send, "m_hBuilder") == client && iObjType == type)
		{
			iCount++;
		}
	}
	
	return iCount;
}

public Action Listener_Jointeam(int client, char[] command, int args)
{
	int iRobotCount = 0;
	
	for(int i = 1; i <= MaxClients; i++)
		if(IsClientInGame(i) && !IsFakeClient(i))
			if(TF2_GetClientTeam(i) == TFTeam_Blue || TF2_GetClientTeam(i) == TFTeam_Spectator)
				iRobotCount++;
				
	if(iRobotCount < 4 || CheckCommandAccess(client, "sm_admin", ADMFLAG_ROOT, true))
	{
		if(TF2_GetClientTeam(client) != TFTeam_Spectator)
		{
			if(!g_bCanPlayAsBot[client])
			{
				CPrintToChat(client, "{red}You pressed F4 and now have to stay for this wave");
				return Plugin_Handled;
			}
			else if(TF2_GetClientTeam(client) == TFTeam_Blue && g_bControllingBot[client])
			{
				TF2_RestoreBot(client);
				
				g_flCooldownEndTime[client] = GetGameTime() + 10.0;
			}
		}
	}
	else
	{
		PrintCenterText(client, "Joining Spectators would unbalance the teams!");
		return Plugin_Handled;
	}
	
	return Plugin_Continue;
}

public Action Listener_Block(int client, char[] command, int args) 
{
	if(IsClientInGame(client) && TF2_GetClientTeam(client) == TFTeam_Blue && TF2_GetClientTeam(client) != TFTeam_Spectator)
	{		
		if(!g_bIsSentryBuster[client])
		{
			TF2_RestoreBot(client);
			TF2_ChangeClientTeam(client, TFTeam_Spectator);	
			TF2_RespawnPlayer(client);	//No gibs / ragdoll
			
			g_flCooldownEndTime[client] = GetGameTime() + 10.0;
		}
		else if(g_bIsSentryBuster[client] && GetEntPropEnt(client, Prop_Data, "m_hGroundEntity") != -1)
		{
			TF2_RestoreBot(client);
			TF2_RespawnPlayer(client);	//No gibs / ragdoll
			TF2_ChangeClientTeam(client, TFTeam_Spectator);
			
			g_flCooldownEndTime[client] = GetGameTime() + 10.0;
		}
	}
	
	return Plugin_Continue;
}

public Action Listener_Voice(int client, char[] command, int args) 
{
	if(IsClientInGame(client) && TF2_GetClientTeam(client) == TFTeam_Spectator && TF2_ObservedIsValidClient(client) && !g_bControllingBot[client] && g_bCanPlayAsBot[client])
	{
		char arguments[4];
		GetCmdArgString(arguments, sizeof(arguments));
		
		if (StrEqual(arguments, "0 0"))
		{
			if(g_flCooldownEndTime[client] <= GetGameTime())
			{
				int iObserved = GetEntPropEnt(client, Prop_Send, "m_hObserverTarget");
				
				TF2_MirrorPlayer(iObserved, client);
				
				CPrintToChatAll("{blue}%N{default} is now playing as {blue}%N", client, iObserved);
			}
			else
			{
				float flTimeLeft = g_flCooldownEndTime[client] - GetGameTime();
				
				CPrintToChat(client, "{red}Cannot play as a bot for %.0f more seconds", flTimeLeft);
			}
		}
	}

	return Plugin_Continue;
}

public Action Hook_TeleporterTransmit(int entity, int other)
{
	//Bots don't go after teleportes to destroy them so neither should player bots.
	TFTeam iTeam = view_as<TFTeam>(GetEntProp(entity, Prop_Send, "m_iTeamNum"));
	
	if(other > 0 && other <= MaxClients && IsClientInGame(other) && !IsFakeClient(other))
	{
		if(iTeam == TFTeam_Red && TF2_GetClientTeam(other) == TFTeam_Blue)
		{
			return Plugin_Handled;	//Don't Transmit
		}
	}

	return Plugin_Continue;	//Transmit
}

public Action Hook_SpyTransmit(int entity, int other)
{
	//Bots don't know where players are when they are disguised so neither should player bots.
	if(other <= 0 || entity == other || other > MaxClients)
		return Plugin_Continue;
	
	if(!IsClientInGame(other))
		return Plugin_Continue;
	
	//Ignore bots
	if(IsFakeClient(other))
		return Plugin_Continue;
	
	//Ignore everything but spies
	if(TF2_GetPlayerClass(entity) != TFClass_Spy)
		return Plugin_Continue;
	
	//Always transmit blue spies
	if(TF2_GetClientTeam(other) != TFTeam_Blue)
		return Plugin_Continue;
	
	if(!ShouldSpyTransmit(entity))
	{
		return Plugin_Handled;	//Don't Transmit
	}

	return Plugin_Continue;	//Transmit
}

stock bool ShouldSpyTransmit(int client)
{
	// Players who are burning/jarated/bleeding, or who are cloaked and bump into something, are not ignored
	if(TF2_IsPlayerInCondition(client, TFCond_CloakFlicker)
	|| TF2_IsPlayerInCondition(client, TFCond_Bleeding)	
	|| TF2_IsPlayerInCondition(client, TFCond_Jarated)
	|| TF2_IsPlayerInCondition(client, TFCond_Milked)
	|| TF2_IsPlayerInCondition(client, TFCond_OnFire)
	|| TF2_IsPlayerInCondition(client, TFCond_Gas)) {
		return true;
	}
	
	// Spies are only ignored when more than 75% cloaked
	if(IsStealthed(client)) {
		return (GetPercentInvisible(client) <= 0.75);
	}
	
	// Spies who are not fully disguised are not ignored
	if(!TF2_IsPlayerInCondition(client, TFCond_Disguised) 
	|| TF2_IsPlayerInCondition(client, TFCond_Disguising)) {
		return true;
	}
	
	return false;
}

stock bool IsStealthed(int client)
{
	if(TF2_IsPlayerInCondition(client, TFCond_Cloaked))
		return true;
	
	if(TF2_IsPlayerInCondition(client, TFCond_Stealthed))
		return true;
		
	return TF2_IsPlayerInCondition(client, TFCond_StealthedUserBuffFade);
}

stock float GetPercentInvisible(int client)
{
	//m_shared = 6560

	int offset = g_imSharedOffs + (81 * 4);
	return GetEntDataFloat(client, offset);
}

stock void TF2_RestoreBot(int client)
{
	int iBot = GetClientOfUserId(g_iPlayersBot[client]);
	if(iBot > 0 && IsFakeClient(iBot))
	{
		if(TF2_HasBomb(client))
		{
			int iBomb = TF2_DropBomb(client);
			
			if(IsValidEntity(iBomb))
			{
				DataPack pack;
				CreateDataTimer(0.1, Timer_RestoreBot, pack);//Wait a frame or two before forcing the bot to pickup the bomb, if we don't the bot will be invisible!
				pack.WriteCell(EntIndexToEntRef(iBomb));
				pack.WriteCell(GetClientUserId(iBot));
			}
		}
		
		if(TF2_GetPlayerClass(iBot) == TFClass_Engineer)
		{
			TF2_TakeOverBuildings(client, iBot);
		}
		
		if(g_bIsSentryBuster[client])
		{
			TF2_DetonateBuster(client);
		}
		
		//Copy medigun data
		if(TF2_GetPlayerClass(iBot) == TFClass_Medic)
		{
			int tMedigun = GetPlayerWeaponSlot(client, view_as<int>(TFWeaponSlot_Secondary));
			int pMedigun = GetPlayerWeaponSlot(iBot, view_as<int>(TFWeaponSlot_Secondary));
			
			if(IsValidEntity(tMedigun) && IsValidEntity(pMedigun) 
			&& EntityClassEquals(tMedigun, "tf_weapon_medigun")
			&& EntityClassEquals(pMedigun, "tf_weapon_medigun"))
			{
				SetEntPropFloat(pMedigun, Prop_Send, "m_flChargeLevel",	GetEntPropFloat(tMedigun, Prop_Send, "m_flChargeLevel"));	
				SetEntPropEnt(pMedigun, Prop_Send, "m_hHealingTarget",	GetEntPropEnt(tMedigun, Prop_Send, "m_hHealingTarget"));
				SetEntProp(pMedigun, Prop_Send, "m_nChargeResistType",	GetEntProp(tMedigun, Prop_Send, "m_nChargeResistType"));	
				SetEntProp(pMedigun, Prop_Send, "m_bAttacking",			GetEntProp(tMedigun, Prop_Send, "m_bAttacking"));	
				SetEntProp(pMedigun, Prop_Send, "m_bHealing",			GetEntProp(tMedigun, Prop_Send, "m_bHealing"));	
				SetEntProp(pMedigun, Prop_Send, "m_bChargeRelease",		GetEntProp(tMedigun, Prop_Send, "m_bChargeRelease"));	
			}
		}
		
		//Mirror conditions
		for (int cond = 0; cond <= view_as<int>(TFCond_SpawnOutline); ++cond)
		{
			if(cond == 5 || cond == 9 || cond == 51)
				continue;
			
			if (!TF2_IsPlayerInCondition(client, view_as<TFCond>(cond)))
				continue;
			
			Address tmp = view_as<Address>(LoadFromAddress(GetEntityAddress(client) + view_as<Address>(g_iCondSourceOffs), NumberType_Int32));
			Address addr = view_as<Address>(view_as<int>(tmp) + (cond * COND_SOURCE_SIZE) + (2 * 4));
			int value = LoadFromAddress(addr, NumberType_Int32);
			
			addr = view_as<Address>(view_as<int>(tmp) + (cond * COND_SOURCE_SIZE) + (3 * 4));
			int provider = LoadFromAddress(addr, NumberType_Int32) & ENT_ENTRY_MASK;
			
			//Only mirror conditions that don't last "forever"
			if(value > 0.0)
			{
				TF2_AddCondition(iBot, view_as<TFCond>(cond), view_as<float>(value), (provider > 0 && provider <= MaxClients) ? provider : 0);
			}
		}
	
		float flPos[3], flAng[3], flVelocity[3];
		GetClientAbsOrigin(client, flPos);
		GetClientEyeAngles(client, flAng);
		GetEntPropVector(client, Prop_Data, "m_vecVelocity", flVelocity);
		
		SetEntityMoveType(iBot, MOVETYPE_WALK);
		TeleportEntity(iBot, flPos, flAng, flVelocity);
		
		OnClientPutInServer(iBot);
		
		g_bBlockRagdoll = true;
		g_flSpawnTime[iBot] = GetGameTime();
	}

	TF2_ClearBot(client);
}

public Action Timer_RestoreBot(Handle timer, DataPack pack)
{
	pack.Reset();
	int iBomb = EntRefToEntIndex(pack.ReadCell());
	int iBot = GetClientOfUserId(pack.ReadCell());
	
	if (IsValidEntity(iBomb) && iBot > 0 && iBot <= MaxClients && IsPlayerAlive(iBot))
		TF2_PickupBomb(iBot, iBomb);
}

stock void TF2_ClearBot(int client, bool bKill = false)
{
	TF2_SetFakeClient(client, false);
	TF2_StopSounds(client);
	TF2_DropBomb(client);
	
	if(bKill)
	{
		TF2_KillBot(client);
	}
	
	SetEntProp(client, Prop_Send, "m_bIsABot", 0);
	SetEntProp(client, Prop_Send, "m_nBotSkill", 0);
	SetEntProp(client, Prop_Send, "m_bIsMiniBoss", 0);
	
	SetVariantString("");
	AcceptEntityInput(client, "SetCustomModel");
	
	TF2Attrib_RemoveAll(client);
	TF2Attrib_ClearCache(client);
	
	OnClientPutInServer(client);
}

stock void TF2_KillBot(int client, int attacker = -1)
{
	int iBot = GetClientOfUserId(g_iPlayersBot[client]);
	if(iBot > 0 && IsFakeClient(iBot))
	{
		if (attacker == -1) attacker = iBot;
		
		SetEntityMoveType(iBot, MOVETYPE_WALK);
		
		TF2_RemoveAllConditions(iBot);
		
		int iWeapon = iBot;
		
		if (attacker != iBot)
		{
			if (0 < attacker <= MaxClients)
			{
				//If the bot was controlled, and killed by a red sniper, this will fix the money not being auto-distribued.
				iWeapon = GetEntPropEnt(attacker, Prop_Send, "m_hActiveWeapon");
				
				if (iWeapon <= 0) 
					iWeapon = attacker
			}
		}
		
		SDKHooks_TakeDamage(iBot, iWeapon, attacker, 99999999.0, _, iWeapon);
		
		SetEntProp(iBot, Prop_Send, "m_bUseBossHealthBar", 0);
		SetEntProp(iBot, Prop_Send, "m_bIsMiniBoss", 0);
		
		g_bIsControlled[iBot] = false;
		g_iController[iBot] = -1;
		
		OnClientPutInServer(iBot);
	}
}

stock void TF2_MirrorPlayer(int iTarget, int client)
{
	float flPos[3], flAng[3];
	GetClientAbsOrigin(iTarget, flPos);
	GetClientEyeAngles(iTarget, flAng);
	flAng[2] = 0.0;

	//Set up player
	TF2_SetFakeClient(client, true);
	TF2_ChangeClientTeam(client, TF2_GetClientTeam(iTarget));
	TF2_SetFakeClient(client, false);
	TF2_SetPlayerClass(client, TF2_GetPlayerClass(iTarget));
	TF2_RespawnPlayer(client);
	TF2_RegeneratePlayer(client);
	TF2_RemoveAllWearables(client);
	TF2Attrib_RemoveAll(client);
	TF2Attrib_ClearCache(client);
	TF2_SetFakeClient(client, true);
	
	//New hot technology
	g_flControlEndTime[client]      = GetGameTime() + 35.0;
	g_flNextInstructionTime[client] = GetGameTime() + 3.0;
	
	//Set HP
	SetEntProp(client, Prop_Send, "m_iHealth", GetEntProp(iTarget, Prop_Send, "m_iHealth"));
	
	//Set Model
	char strModel[PLATFORM_MAX_PATH];
	GetEntPropString(iTarget, Prop_Data, "m_ModelName", strModel, PLATFORM_MAX_PATH);
	SetVariantString(strModel);
	AcceptEntityInput(client, "SetCustomModel");
	SetEntProp(client, Prop_Send, "m_bUseClassAnimations", 1);

	//Set ModelScale
	char strScale[8];
	FloatToString(GetEntPropFloat(iTarget, Prop_Send, "m_flModelScale"), strScale, sizeof(strScale));
	SetVariantString(strScale);
	AcceptEntityInput(client, "SetModelScale");
	
	//Is target sentry buster?
	if(StrContains(strModel, "bot_sentry_buster.mdl") != -1)
	{
		SDKCall(g_hSDKSetMission, iTarget, NOMISSION, 0);
		
		g_bIsSentryBuster[client] = true;
		
		TF2Attrib_SetByName(client, "cannot pick up intelligence", 1.0);
		
		//A little delay
		SetEntPropFloat(client, Prop_Send, "m_flStealthNoAttackExpire", GetGameTime() + 1.25);
	}
	
	//Get & Set some props
	SetEntPropFloat(client, Prop_Send, "m_flRageMeter",	GetEntPropFloat(iTarget, Prop_Send, "m_flRageMeter"));
	SetEntProp(client, Prop_Send, "m_nNumHealers",	    GetEntProp(iTarget, Prop_Send, "m_nNumHealers"));
	SetEntProp(client, Prop_Send, "m_bIsABot",			GetEntProp(iTarget, Prop_Send, "m_bIsABot"));
	SetEntProp(client, Prop_Send, "m_nBotSkill",		GetEntProp(iTarget, Prop_Send, "m_nBotSkill"));
	SetEntProp(client, Prop_Send, "m_bIsMiniBoss",		GetEntProp(iTarget, Prop_Send, "m_bIsMiniBoss"));
	SetEntProp(client, Prop_Data, "m_bloodColor", 		GetEntProp(iTarget, Prop_Data, "m_bloodColor"));
	
	//Set gatebot on player if target is gatebot
	if(TF2_HasTag(iTarget, "bot_gatebot"))
	{
		TF2Attrib_SetByName(client, "cannot pick up intelligence", 1.0);
	}
	
	//Engineers cant carry buildings		
	if(TF2_GetPlayerClass(iTarget) == TFClass_Engineer)		
	{		
		TF2_TakeOverBuildings(iTarget, client);		
		TF2Attrib_SetByName(client, "cannot pick up buildings", 1.0);		
	}
	
	if(TF2_GetPlayerClass(iTarget) == TFClass_Sniper)
	{
		//Unzooms the sniper so the laser wont bug out
		TF2_AddCondition(iTarget, TFCond_Taunting, 5.0);
	}
	
	//Start the engines		
	if(TF2_IsGiant(iTarget))		
	{		
		if(g_bIsSentryBuster[client]) 		
		{		
			EmitSoundToAll(BUSTER_SND_LOOP, client, SNDCHAN_STATIC, SNDLEVEL_TRAIN, _, 1.0);		
		}		
		else		
		{			
			switch(TF2_GetPlayerClass(iTarget))		
			{		
				case TFClass_Scout:		EmitSoundToAll(GIANTSCOUT_SND_LOOP,	  client, SNDCHAN_STATIC, SNDLEVEL_SCREAMING, _, 0.3);		
				case TFClass_Soldier:	EmitSoundToAll(GIANTSOLDIER_SND_LOOP, client, SNDCHAN_STATIC, SNDLEVEL_MINIBIKE, _, 0.7);		
				case TFClass_DemoMan:	EmitSoundToAll(GIANTDEMOMAN_SND_LOOP, client, SNDCHAN_STATIC, SNDLEVEL_MINIBIKE, _, 0.7);		
				case TFClass_Heavy:		EmitSoundToAll(GIANTHEAVY_SND_LOOP,	  client, SNDCHAN_STATIC, SNDLEVEL_MINIBIKE, _, 0.8);		
				case TFClass_Pyro:		EmitSoundToAll(GIANTPYRO_SND_LOOP,	  client, SNDCHAN_STATIC, SNDLEVEL_MINIBIKE, _, 0.8);		
			}		
		}		
	}
	
	TF2_RemoveAllConditions(client);
	
	//Fix some bugs...	
	TF2_RemoveCondition(client, TFCond_Zoomed);		
	TF2_RemoveCondition(client, TFCond_Slowed);
	
	//Mirror conditions
	for (int cond = 0; cond <= view_as<int>(TFCond_SpawnOutline); ++cond)
	{
		if(cond == 5 || cond == 9 || cond == 51)
			continue;
		
		if (!TF2_IsPlayerInCondition(iTarget, view_as<TFCond>(cond)))
			continue;
		
		Address tmp = view_as<Address>(LoadFromAddress(GetEntityAddress(iTarget) + view_as<Address>(g_iCondSourceOffs), NumberType_Int32));
		Address addr = view_as<Address>(view_as<int>(tmp) + (cond * COND_SOURCE_SIZE) + (2 * 4));
		int value = LoadFromAddress(addr, NumberType_Int32);
		
		addr = view_as<Address>(view_as<int>(tmp) + (cond * COND_SOURCE_SIZE) + (3 * 4));
		int provider = LoadFromAddress(addr, NumberType_Int32) & ENT_ENTRY_MASK;
		
		//Only mirror conditions that don't last "forever"
		if(value > 0.0)
		{
			TF2_AddCondition(client, view_as<TFCond>(cond), view_as<float>(value), (provider > 0 && provider <= MaxClients) ? provider : 0);
		}
	}
	
	Address TargetSquad = TF2_GetBotSquad(iTarget);
	if(TargetSquad != Address_Null)
	{	
		int iLeader = SDKCall(g_hSDKGetSquadLeader, TargetSquad);
	
		//Everyone but medics leave the targets squad
		for (int i = 1; i <= MaxClients; i++)
		{
			if(!IsClientInGame(i) || !IsFakeClient(i) || i == iTarget || i == iLeader)
				continue;
				
			if(TF2_GetPlayerClass(i) != TFClass_Medic)
			{
				Address BotSquad = TF2_GetBotSquad(i);
				if(BotSquad == Address_Null)
					continue;
				
				if(BotSquad == TargetSquad)
				{					
					SDKCall(g_hSDKLeaveSquad, i);
				//	PrintToChatAll("Bye %N", i);
				}
			}
		}
	}
	
	float flJumpMin = GetEntDataFloat(iTarget, g_iOffsetAutoJumpMin);
	float flJumpMax = GetEntDataFloat(iTarget, g_iOffsetAutoJumpMax);
	int iBotAttrs = GetEntData(iTarget, g_iOffsetBotAttribs);
	
	g_flAutoJumpMin[client]		= flJumpMin;
	g_flAutoJumpMax[client]		= flJumpMax;
	g_iPlayerAttributes[client]	= iBotAttrs;
	
	//Fixes client visuals.
	if(iBotAttrs & view_as<int>(ALWAYSFIREWEAPON))	SetEntProp(client, Prop_Data, "m_bPredictWeapons", false);
	if(iBotAttrs & view_as<int>(IGNOREFLAG))		TF2Attrib_SetByName(client, "cannot pick up intelligence", 1.0);
	if(iBotAttrs & view_as<int>(ALWAYSCRIT))		TF2_AddCondition(client, TFCond_CritOnFlagCapture);
	if(iBotAttrs & view_as<int>(BULLETIMMUNE))		TF2_AddCondition(client, TFCond_BulletImmune);
	if(iBotAttrs & view_as<int>(BLASTIMMUNE))		TF2_AddCondition(client, TFCond_BlastImmune);
	if(iBotAttrs & view_as<int>(FIREIMMUNE))		TF2_AddCondition(client, TFCond_FireImmune);
	
//	SetEntData(client, g_iOffsetBotAttribs, iBotAttrs, true);	//It does stuff, trust me.
	SetEntData(client, g_iOffsetMissionBot, 	1, _, true);	//Makes player death not decrement wave bot count
	SetEntData(client, g_iOffsetSupportLimited, 0, _, true);	//Makes player death not decrement wave bot count
	
	//Teleport player to bots position
	float flVelocity[3];
	GetEntPropVector(iTarget, Prop_Data, "m_vecVelocity", flVelocity);
	
	SetEntityMoveType(iTarget, MOVETYPE_NONE);
	TeleportEntity(client, flPos, flAng, flVelocity);
	TeleportEntity(iTarget, view_as<float>({0.0, 0.0, 9999.0}), NULL_VECTOR, NULL_VECTOR);
	
	g_iPlayersBot[client] 		= GetClientUserId(iTarget);
	g_iController[iTarget]		= GetClientUserId(client);
	g_bControllingBot[client]	= true;
	g_bIsControlled[iTarget]	= true;
	g_bSkipInventory[client]	= true;
	
	// Delay a frame or two to replace the players weapons.
	CreateTimer(0.1, Timer_ReplaceWeapons, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
}

public Action Timer_ReplaceWeapons(Handle hTimer, any iUserId)
{
	//Check to see if the player is valid and is still controlling bot.
	int client = GetClientOfUserId(iUserId);
	if(client <= 0 || client > MaxClients || !IsClientInGame(client))
		return Plugin_Handled;
	
	if(!g_bControllingBot[client])
		return Plugin_Handled;
		
	if(!IsPlayerAlive(client))
		return Plugin_Handled;
	
	int iBot = GetClientOfUserId(g_iPlayersBot[client]);
	if(iBot <= 0)
		return Plugin_Handled;
		
	if(!IsPlayerAlive(iBot))
		return Plugin_Handled;
	
	TF2_MirrorItems(iBot, client);
	
	if(TF2_HasBomb(iBot))
	{
		int iBomb = TF2_DropBomb(iBot);
		if(IsValidEntity(iBomb))
			TF2_PickupBomb(client, iBomb);
		
		//Copy bomb carrier upgrade level
		int iResource = FindEntityByClassname(-1, "tf_objective_resource");
		g_iFlagCarrierUpgradeLevel[client] = GetEntProp(iResource, Prop_Send, "m_nFlagCarrierUpgradeLevel");
		g_flNextBombUpgradeTime[client]    = GetEntPropFloat(iResource, Prop_Send, "m_flMvMNextBombUpgradeTime");	
	}
	
	//Copy medigun data
	if(TF2_GetPlayerClass(iBot) == TFClass_Medic)
	{
		int tMedigun = GetPlayerWeaponSlot(iBot, view_as<int>(TFWeaponSlot_Secondary));
		int pMedigun = GetPlayerWeaponSlot(client, view_as<int>(TFWeaponSlot_Secondary));
		
		if(IsValidEntity(tMedigun) && IsValidEntity(pMedigun) 
		&& EntityClassEquals(tMedigun, "tf_weapon_medigun")
		&& EntityClassEquals(pMedigun, "tf_weapon_medigun"))
		{
			SetEntPropFloat(pMedigun, Prop_Send, "m_flChargeLevel",	GetEntPropFloat(tMedigun, Prop_Send, "m_flChargeLevel"));	
			SetEntPropEnt(pMedigun, Prop_Send, "m_hHealingTarget",	GetEntPropEnt(tMedigun, Prop_Send, "m_hHealingTarget"));
			SetEntProp(pMedigun, Prop_Send, "m_nChargeResistType",	GetEntProp(tMedigun, Prop_Send, "m_nChargeResistType"));	
			SetEntProp(pMedigun, Prop_Send, "m_bAttacking",			GetEntProp(tMedigun, Prop_Send, "m_bAttacking"));	
			SetEntProp(pMedigun, Prop_Send, "m_bHealing",			GetEntProp(tMedigun, Prop_Send, "m_bHealing"));	
			SetEntProp(pMedigun, Prop_Send, "m_bChargeRelease",		GetEntProp(tMedigun, Prop_Send, "m_bChargeRelease"));	
			
			//Because
			SetEntPropFloat(tMedigun, Prop_Send, "m_flChargeLevel",	0.0);   //Hide the medigun effect
			SetEntPropEnt(tMedigun,   Prop_Send, "m_hHealingTarget", -1);   //Remove the medigun beam
			SetEntProp(tMedigun,      Prop_Send, "m_bHealing", 0);	
		}
	}
	
	//Disguise after we have received our disguise items.
	if(TF2_GetPlayerClass(iBot) == TFClass_Spy)
	{
		int iDisguiseClass	= GetEntProp(iBot, Prop_Send, "m_nDisguiseClass");
		int iDisguiseTarget = GetEntProp(iBot, Prop_Send, "m_iDisguiseTargetIndex");
		
		if(iDisguiseTarget > 0 && iDisguiseTarget <= MaxClients && IsClientInGame(iDisguiseTarget) && iDisguiseClass > 0)
		{
			TF2_DisguisePlayer(client, TFTeam_Red, view_as<TFClassType>(iDisguiseClass), iDisguiseTarget);
		}
		else if(iDisguiseClass > 0)
		{
			TF2_DisguisePlayer(client, TFTeam_Red, view_as<TFClassType>(iDisguiseClass));
		}
	}

	return Plugin_Handled;
}

stock bool EntityClassEquals(int entity, const char[] class)
{
	char glass[64];
	GetEntityClassname(entity, glass, sizeof(glass));
	
	return (StrEqual(glass, class, false));
}

stock void TF2_MirrorItems(int iTarget, int client)
{
	int iAttribList[16];
	float flAttribValues[16];
	Address aAttr;
	
	int iWeaponRestriction = GetEntData(iTarget, g_iOffsetWeaponRestrictions);

	if(iWeaponRestriction == view_as<int>(UNRESTRICTED))
	{
		for (int w = 0; w <= view_as<int>(TFWeaponSlot_PDA); w++)
		{
			int iEntity = GetPlayerWeaponSlot(iTarget, w);
		
			if(IsValidEntity(iEntity))
			{
				char strClass[64];
				GetEntityClassname(iEntity, strClass, sizeof(strClass));
				
				int iDefIndex = GetEntProp(iEntity, Prop_Send, "m_iItemDefinitionIndex");
			
				int iCount = TF2Attrib_ListDefIndices(iEntity, iAttribList);
				if (iCount > 0)
				{
					for (int i = 0; i < iCount; i++)
					{
						aAttr = TF2Attrib_GetByDefIndex(iEntity, iAttribList[i]);
						flAttribValues[i] = TF2Attrib_GetValue(aAttr);
					}
				}
				
				GiveItem(client, iDefIndex, strClass, iCount, iAttribList, flAttribValues, GetEntPropEnt(iTarget, Prop_Data, "m_hActiveWeapon") == iEntity ? true : false);
			}
		}
	}
	else
	{
		//Mirror unrestricted weapon + utility weapons
	
		int iEntity = -1;
		
		switch(iWeaponRestriction)
		{
			case PRIMARYONLY:	iEntity = GetPlayerWeaponSlot(iTarget, view_as<int>(TFWeaponSlot_Primary));
			case SECONDARYONLY:	iEntity = GetPlayerWeaponSlot(iTarget, view_as<int>(TFWeaponSlot_Secondary));
			case MELEEONLY:		iEntity = GetPlayerWeaponSlot(iTarget, view_as<int>(TFWeaponSlot_Melee));
		}
		
		if(IsValidEntity(iEntity))
		{
			char strClass[64];
			GetEntityClassname(iEntity, strClass, sizeof(strClass));
			
			int iDefIndex = GetEntProp(iEntity, Prop_Send, "m_iItemDefinitionIndex");
		
			int iCount = TF2Attrib_ListDefIndices(iEntity, iAttribList);
			if (iCount > 0)
			{
				for (int i = 0; i < iCount; i++)
				{
					aAttr = TF2Attrib_GetByDefIndex(iEntity, iAttribList[i]);
					flAttribValues[i] = TF2Attrib_GetValue(aAttr);
				}
			}
			
			GiveItem(client, iDefIndex, strClass, iCount, iAttribList, flAttribValues, GetEntPropEnt(iTarget, Prop_Data, "m_hActiveWeapon") == iEntity ? true : false);
		}
		
		//Always mirror the "utility" weapons
		for (int w = view_as<int>(TFWeaponSlot_Grenade); w <= view_as<int>(TFWeaponSlot_PDA); w++)
		{
			iEntity = GetPlayerWeaponSlot(iTarget, w);
		
			if(IsValidEntity(iEntity))
			{
				char strClass[64];
				GetEntityClassname(iEntity, strClass, sizeof(strClass));
				
				int iDefIndex = GetEntProp(iEntity, Prop_Send, "m_iItemDefinitionIndex");
			
				int iCount = TF2Attrib_ListDefIndices(iEntity, iAttribList);
				if (iCount > 0)
				{
					for (int i = 0; i < iCount; i++)
					{
						aAttr = TF2Attrib_GetByDefIndex(iEntity, iAttribList[i]);
						flAttribValues[i] = TF2Attrib_GetValue(aAttr);
					}
				}
				
				GiveItem(client, iDefIndex, strClass, iCount, iAttribList, flAttribValues, GetEntPropEnt(iTarget, Prop_Data, "m_hActiveWeapon") == iEntity ? true : false);
			}
		}
	}

	//Mirror wearables
	int iWearable = -1;
	while ((iWearable = FindEntityByClassname(iWearable, "tf_wearable*")) != -1)
	{
		if(!GetEntProp(iWearable, Prop_Send, "m_bDisguiseWearable") && GetEntPropEnt(iWearable, Prop_Send, "m_hOwnerEntity") == iTarget)
		{
			char strClass[64];
			GetEntityClassname(iWearable, strClass, sizeof(strClass));
			
			int iDefIndex = GetEntProp(iWearable, Prop_Send, "m_iItemDefinitionIndex");
		
			int iCount = TF2Attrib_ListDefIndices(iWearable, iAttribList);
			if (iCount > 0)
			{
				for (int i = 0; i < iCount; i++)
				{
					aAttr = TF2Attrib_GetByDefIndex(iWearable, iAttribList[i]);
					flAttribValues[i] = TF2Attrib_GetValue(aAttr);
				}
			}
			
			GiveItem(client, iDefIndex, strClass, iCount, iAttribList, flAttribValues, false);
		}
	}

	//Mirror player attributes
	int iCount = TF2Attrib_ListDefIndices(iTarget, iAttribList);
	if (iCount > 0)
	{
		for (int i = 0; i < iCount; i++)
		{
			aAttr = TF2Attrib_GetByDefIndex(iTarget, iAttribList[i]);
			flAttribValues[i] = TF2Attrib_GetValue(aAttr);

			TF2Attrib_SetByDefIndex(client, iAttribList[i], flAttribValues[i]);
		}
	}
	
	Handle msg = StartMessageOne("PlayerLoadoutUpdated", client, USERMSG_RELIABLE|USERMSG_BLOCKHOOKS);
	BfWriteByte(msg, client);
	if (msg != null) EndMessage();
	
	msg = StartMessageOne("PlayerPickupWeapon", client, USERMSG_RELIABLE|USERMSG_BLOCKHOOKS);
	if (msg != null) EndMessage();
	
	//Finally.
	SDKCall(g_hSDKPostInventoryApplication, client);
}

stock void TF2_RemoveAllWearables(int client)
{
	TF2_RemoveAllWeapons(client);
	
	int wearable = -1;
	while ((wearable = FindEntityByClassname(wearable, "tf_wearable*")) != -1)
		if (client == GetEntPropEnt(wearable, Prop_Data, "m_hOwnerEntity"))
			TF2_RemoveWearable(client, wearable);
	
	while ((wearable = FindEntityByClassname(wearable, "vgui_screen")) != -1)
		if (client == GetEntPropEnt(wearable, Prop_Data, "m_hOwnerEntity"))
			AcceptEntityInput(wearable, "Kill");

	while ((wearable = FindEntityByClassname(wearable, "tf_powerup_bottle")) != -1)
		if (client == GetEntPropEnt(wearable, Prop_Data, "m_hOwnerEntity"))
			TF2_RemoveWearable(client, wearable);

	while ((wearable = FindEntityByClassname(wearable, "tf_weapon_spellbook")) != -1)
		if (client == GetEntPropEnt(wearable, Prop_Data, "m_hOwnerEntity"))
			TF2_RemoveWearable(client, wearable);
}

stock void TF2_SetObserved(int client, int iObserved, int iObserveMode = -1)
{
	SetEntPropEnt(client, Prop_Send, "m_hObserverTarget", iObserved);
	
	if(iObserveMode != -1)
		SetEntProp(client, Prop_Send, "m_iObserverMode", iObserveMode);
}

stock bool TF2_IsGiant(int client)
{
	return view_as<bool>(GetEntProp(client, Prop_Send, "m_bIsMiniBoss"));
}

stock bool TF2_HasBomb(int client)
{
	int iBomb = GetEntPropEnt(client, Prop_Send, "m_hItem");
	
	if(iBomb != INVALID_ENT_REFERENCE && GetEntPropEnt(iBomb, Prop_Send, "moveparent") == client)
	{
		return true;
	}
	
	return false;
}

stock int TF2_DropBomb(int client)
{
	int iBomb = GetEntPropEnt(client, Prop_Send, "m_hItem");
	
	if(iBomb != INVALID_ENT_REFERENCE && GetEntPropEnt(iBomb, Prop_Send, "moveparent") == client)
	{
		AcceptEntityInput(iBomb, "ForceDrop");
		
	//	PrintToChatAll("TF2_DropBomb %N %i", client, iBomb);
	}
	
	return iBomb;
}

stock void TF2_PickupBomb(int iClient, int iFlag)
{
//	PrintToChatAll("TF2_PickupBomb %N %i", iClient, iFlag);
	if (!IsFakeClient(iClient)) 
		TF2_SetFakeClient(iClient, false);
	
	SDKCall(g_hSDKPickup, iFlag, iClient, true);	
	
	DataPack pack = new DataPack();
	pack.WriteCell(EntIndexToEntRef(iFlag));
	pack.WriteCell(GetClientUserId(iClient));
	
	RequestFrame(Frame_TF2_PickupBomb, pack);
}

//Gets a bots tag and does checking for real bots
stock bool TF2_HasTag(int client, const char[] tag)
{
	if(IsFakeClient(client))
	{
		return SDKCall(g_hSDKHasTag, client, tag);
	}
	else
	{
		int iBot = GetClientOfUserId(g_iPlayersBot[client]);
		if(iBot > 0)
		{
			return SDKCall(g_hSDKHasTag, iBot, tag);
		}
	}
	
	return false;
}

stock float[] WorldSpaceCenter(int entity)
{
	float vecPos[3];
	SDKCall(g_hSDKWorldSpaceCenter, entity, vecPos);
	
	return vecPos;
}

public void Frame_TF2_PickupBomb(DataPack pack)
{
	pack.Reset();
	int iFlag = EntRefToEntIndex(pack.ReadCell());
	int iClient = GetClientOfUserId(pack.ReadCell());
	
	if(!IsPlayerAlive(iClient))
		return;
	
	if (IsValidEntity(iFlag) && GetEntPropEnt(iFlag, Prop_Send, "moveparent") == iClient && iClient > 0 && iClient <= MaxClients)
	{
		SetEntPropEnt(iClient, Prop_Send, "m_hItem", iFlag);
		if (!IsFakeClient(iClient)) TF2_SetFakeClient(iClient, true);
	}
}

stock void TF2_RobotsWin()
{
	int iEnt = -1;
	while ((iEnt = FindEntityByClassname(iEnt, "logic_relay")) != -1)
	{
		char strName[32];
		GetEntPropString(iEnt, Prop_Data, "m_iName", strName, sizeof(strName));
		
		if(StrEqual(strName, "boss_deploy_relay", false))
		{
			AcceptEntityInput(iEnt, "Trigger");
		}
	}
}

stock void TF2_StopSounds(int client)
{
	StopSound(client, SNDCHAN_STATIC, GIANTSCOUT_SND_LOOP);
	StopSound(client, SNDCHAN_STATIC, GIANTSOLDIER_SND_LOOP);
	StopSound(client, SNDCHAN_STATIC, GIANTPYRO_SND_LOOP);
	StopSound(client, SNDCHAN_STATIC, GIANTDEMOMAN_SND_LOOP);
	StopSound(client, SNDCHAN_STATIC, GIANTHEAVY_SND_LOOP);
	StopSound(client, SNDCHAN_STATIC, BUSTER_SND_LOOP);
}

stock void TF2_SetFakeClient(int client, bool bOn)
{
	int iEFlags = GetEntityFlags(client);

	if(bOn)
		SetEntityFlags(client, iEFlags | FL_FAKECLIENT);
	else
		SetEntityFlags(client, iEFlags &~ FL_FAKECLIENT);
}

stock void TF2_RemoveAllConditions(int client)
{
	for (int cond = 0; cond <= view_as<int>(TFCond_RuneAgility); ++cond)
		TF2_RemoveCondition(client, view_as<TFCond>(cond));
}

stock bool TF2_ObservedIsValidClient(int observer)
{
	if(GetEntProp(observer, Prop_Send, "m_iObserverMode") == 4 || GetEntProp(observer, Prop_Send, "m_iObserverMode") == 5)
	{
		int iObserved = GetEntPropEnt(observer, Prop_Send, "m_hObserverTarget");
	
		if(iObserved > 0 && iObserved <= MaxClients && IsClientInGame(iObserved) && IsFakeClient(iObserved) && IsPlayerAlive(iObserved) && !g_bIsControlled[iObserved])
		{
			if(!TF2_IsPlayerInCondition(iObserved, TFCond_MVMBotRadiowave) && !TF2_IsPlayerInCondition(iObserved, TFCond_Taunting))
			{
				if(GetEntProp(iObserved, Prop_Data, "m_takedamage") != 0)
				{
					float flSpawnedAgo = GetGameTime() - g_flSpawnTime[iObserved];
					if(TF2_GetPlayerClass(iObserved) != TFClass_Spy && flSpawnedAgo >= 1.5) //Allow the bots some time to spawn
					{
						return true;
					}
					else if(TF2_GetPlayerClass(iObserved) == TFClass_Spy && flSpawnedAgo >= 5.0) //Spies need extra time to teleport
					{
						return true;
					}
				}
			}
		}
	}
	
	return false;
}

stock int TF2_FindNearestHint(int client, const char[] strHint = "bot_hint_engineer_nest")
{
	//bot_hint_teleporter_exit
	//bot_hint_engineer_nest
	//bot_hint_sentrygun
	
	float flBestDistance = 999999.0;

	float flOrigin[3];
	GetClientAbsOrigin(client, flOrigin);

	int iBestEntity = -1;

	int iEnt = -1;
	while ((iEnt = FindEntityByClassname(iEnt, strHint)) != -1)
	{
		float flPos[3];
		GetEntPropVector(iEnt, Prop_Data, "m_vecOrigin", flPos);
		
		float flDistance = GetVectorDistance(flOrigin, flPos);
		if(flDistance <= flBestDistance)
		{
			flBestDistance = flDistance;
			iBestEntity = iEnt;
		}
	}
	
	return iBestEntity;
}

stock void TF2_DetonateBuster(int client)
{
	if(g_bRandomlyChooseBot[client])
		g_flCooldownEndTime[client] = GetGameTime() + 5.0;

	int iBot = GetClientOfUserId(g_iPlayersBot[client]);
	
	if(iBot > 0 && IsFakeClient(iBot))
	{
		TF2_StopSounds(client);
	
		float flPos[3], flAng[3], flVelocity[3];
		GetClientAbsOrigin(client, flPos);
		GetClientEyeAngles(client, flAng);
		GetEntPropVector(client, Prop_Data, "m_vecVelocity", flVelocity);
	
		SetEntityMoveType(iBot, MOVETYPE_WALK);
		TeleportEntity(iBot, flPos, flAng, flVelocity);
		
		SDKCall(g_hSDKSetMission, iBot, DESTROY_SENTRIES, 1);	
		
		SetEntProp(iBot, Prop_Send, "m_iHealth", 1);
		SetEntPropEnt(client, Prop_Send, "m_hObserverTarget", iBot);
		
	//	g_bIsControlled[iBot] = false;	//Let's the user spectate the busters detonation, was a terrible idea.
	}
}

stock int TF2_FindTeleNearestToBombHole()
{
	float flOrigin[3]; flOrigin = TF2_GetBombHatchPosition();
	
	float flBestDistance = 999999.0;
	
	int iBestEntity = -1;
	
	int iEnt = -1;
	while ((iEnt = FindEntityByClassname(iEnt, "obj_teleporter")) != -1)
	{
		if(GetEntProp(iEnt, Prop_Send, "m_iTeamNum") == view_as<int>(TFTeam_Blue)
		&& !GetEntProp(iEnt, Prop_Send, "m_bHasSapper") && !GetEntProp(iEnt, Prop_Send, "m_bBuilding") 
		&& !GetEntProp(iEnt, Prop_Send, "m_bPlacing") && !GetEntProp(iEnt, Prop_Send, "m_bDisabled"))
		{
			float flPos[3];
			GetEntPropVector(iEnt, Prop_Data, "m_vecOrigin", flPos);
			
			float flDistance = GetVectorDistance(flOrigin, flPos);
			if(flDistance <= flBestDistance)
			{
				flBestDistance = flDistance;
				iBestEntity = iEnt;
			}
		}
	}
	
	return iBestEntity;
}

stock Address TF2_GetBotSquad(int iBot)
{
	if (iBot > 0 && iBot <= MaxClients && IsFakeClient(iBot))
		return view_as<Address>(GetEntData(iBot, g_iOffsetSquad));
	
	return Address_Null;
}

stock int TF2_GetSquadLeader(Address pSquad)
{
	int iLeader = SDKCall(g_hSDKGetSquadLeader, pSquad);
	if (iLeader > 0 && iLeader <= MaxClients && IsFakeClient(iLeader) && g_bIsControlled[iLeader])
		return GetClientOfUserId(g_iController[iLeader]);
	
	return iLeader;
}

stock int TF2_GetBotSquadLeader(int iBot)
{
	Address pSquad = TF2_GetBotSquad(iBot);
	if (pSquad != Address_Null)
		return TF2_GetSquadLeader(pSquad);
	
	return -1;
}

stock void TF2_PlayAnimation(int client, const char[] sAnim)
{
	SDKCall(g_hSDKPlaySpecificSequence, client, sAnim);
}

stock void TF2_TakeOverBuildings(int client, int newClient)
{
	int obj = -1;
	while ((obj = FindEntityByClassname(obj, "obj_*")) != -1)
	{
		if(IsValidBuilding(obj))
		{
			int iBuilder = GetEntPropEnt(obj, Prop_Send, "m_hBuilder");
			if(iBuilder == client)
			{
				DispatchKeyValue(obj, "SolidToPlayer", "0");
				SetBuilder(obj, newClient);
			}
		}
	}
}

stock void SetBuilder(int obj, int client)
{
	int iBuilder = GetEntPropEnt(obj, Prop_Send, "m_hBuilder");

	if(iBuilder > 0 && iBuilder <= MaxClients && IsClientInGame(iBuilder))
		SDKCall(g_hSDKRemoveObject, iBuilder, obj);
	
	SetEntPropEnt(obj, Prop_Send, "m_hBuilder", -1);
	AcceptEntityInput(obj, "SetBuilder", client);
	SetEntPropEnt(obj, Prop_Send, "m_hBuilder", client);
	
	SetVariantString("3");
	AcceptEntityInput(obj, "SetTeam");
}

stock bool IsValidBuilding(int iBuilding)
{
	if (IsValidEntity(iBuilding))
	{
		if (GetEntProp(iBuilding, Prop_Send, "m_bPlacing") == 0
		 && GetEntProp(iBuilding, Prop_Send, "m_bCarried") == 0)
			return true;
	}
	
	return false;
}

stock void BroadcastSoundToTeam(TFTeam team, const char[] strSound)
{
	//PrintToChatAll("Broadcasting %s..", strSound);
	switch(team)
	{
		case TFTeam_Red, TFTeam_Blue: 
		{
			for(int i = 1; i <= MaxClients; i++) 
			{
				if(IsClientInGame(i) && !IsFakeClient(i) && TF2_GetClientTeam(i) == team) 
				{
					ClientCommand(i, "playgamesound %s", strSound);
				}
			}
		}
		default: 
		{
			for(int i = 1; i <= MaxClients; i++) 
			{
				if(IsClientInGame(i) && !IsFakeClient(i)) 
				{
					ClientCommand(i, "playgamesound %s", strSound);
				}
			}
		}
	}
}

public void GiveItem(int client, int DefIndex, char[] ItemClass, int iAttribCount, int iAttribList[16], float flAttribValues[16], bool bSetActive)
{
	Handle TF2Item;
	if (StrEqual(ItemClass, "saxxy", false) || StrEqual(ItemClass, "tf_weapon_shotgun", false))
		TF2Item = TF2Items_CreateItem(OVERRIDE_ALL|PRESERVE_ATTRIBUTES);
	else
		TF2Item = TF2Items_CreateItem(OVERRIDE_ALL|FORCE_GENERATION|PRESERVE_ATTRIBUTES);
	
	char ItemClassTrans[64];
	/*bool bChanged = */
	TranslateWeaponEntForClass(ItemClass, TF2_GetPlayerClass(client), ItemClassTrans, sizeof(ItemClassTrans));
//	PrintToServer("GiveItem %s changed %s", ItemClassTrans, bChanged ? "yes" : "no");
	
	bool IsWeapon = StrContains(ItemClassTrans, "tf_weapon") != -1;
	
	TF2Items_SetClassname(TF2Item, ItemClassTrans);
	TF2Items_SetItemIndex(TF2Item, DefIndex);
	TF2Items_SetLevel(TF2Item, 100);

	if (iAttribCount > 0)
	{
		for (int i = 0; i < iAttribCount; i++)
		{
			if(i < 20)
			{
				TF2Items_SetAttribute(TF2Item, i, iAttribList[i], flAttribValues[i]);
			}
		}
	}
	
	TF2Items_SetNumAttributes(TF2Item, iAttribCount);
	
	int ItemEntity = TF2Items_GiveNamedItem(client, TF2Item);
	delete TF2Item;

	if(IsValidEntity(ItemEntity))
	{
		if(StrEqual(ItemClassTrans, "tf_weapon_builder") || StrEqual(ItemClassTrans, "tf_weapon_sapper"))
		{
			if(TF2_GetPlayerClass(client) == TFClass_Spy)
			{
				SetEntProp(ItemEntity, Prop_Send, "m_aBuildableObjectTypes", 1, _, 0);
				SetEntProp(ItemEntity, Prop_Send, "m_aBuildableObjectTypes", 1, _, 1);
				SetEntProp(ItemEntity, Prop_Send, "m_aBuildableObjectTypes", 1, _, 2);
				SetEntProp(ItemEntity, Prop_Send, "m_aBuildableObjectTypes", 0, _, 3);
				
				SetEntProp(ItemEntity, Prop_Send, "m_iObjectType", 3);
				SetEntProp(ItemEntity, Prop_Data, "m_iSubType", 3);
			}
			else
			{
				SetEntProp(ItemEntity, Prop_Send, "m_aBuildableObjectTypes", 1, _, 0);	//Dispenser
				SetEntProp(ItemEntity, Prop_Send, "m_aBuildableObjectTypes", 1, _, 1);	//Teleporter
				SetEntProp(ItemEntity, Prop_Send, "m_aBuildableObjectTypes", 1, _, 2);	//Sentry
			}
		}
	
		if (!IsWeapon)
			SDKCall(g_hSdkEquipWearable, client, ItemEntity);		
		else
			EquipPlayerWeapon(client, ItemEntity);
			
		if(bSetActive && IsWeapon)
		{
			FakeClientCommand(client, "use %s", ItemClassTrans);
			SetEntPropEnt(client, Prop_Send, "m_hActiveWeapon", ItemEntity);
		}
		
	//	PrintToConsole(client, "Index %i | iDefIndex %i | ItemClass %s", ItemEntity, DefIndex, ItemClassTrans);
	}
	else
	{
		LogError("Unable to GIVE item '%d' for %N. Skipping...", DefIndex, client);
		return;
	}
}

stock bool TranslateWeaponEntForClass(const char[] name, TFClassType class, char[] buffer, int maxlength)
{
	if (StrEqual(name, "tf_weapon_shotgun")) 
	{
		switch (class) 
		{
			case TFClass_Soldier:  {strcopy(buffer, maxlength, "tf_weapon_shotgun_soldier"); return true;}
			case TFClass_Pyro:     {strcopy(buffer, maxlength, "tf_weapon_shotgun_pyro");    return true;}
			case TFClass_Heavy:    {strcopy(buffer, maxlength, "tf_weapon_shotgun_hwg");     return true;}
			case TFClass_Engineer: {strcopy(buffer, maxlength, "tf_weapon_shotgun_primary"); return true;}
			default:               {strcopy(buffer, maxlength, "tf_weapon_shotgun_primary"); return true;}
		}
	}
	
	if (StrEqual(name, "tf_weapon_pistol")) 
	{
		switch (class) 
		{
			case TFClass_Scout:    {strcopy(buffer, maxlength, "tf_weapon_pistol_scout"); return true;}
			case TFClass_Engineer: {strcopy(buffer, maxlength, "tf_weapon_pistol");       return true;}
		}
	}
	
	if (StrEqual(name, "tf_weapon_shovel") || StrEqual(name, "tf_weapon_bottle")) 
	{
		switch (class) 
		{
			case TFClass_Soldier: {strcopy(buffer, maxlength, "tf_weapon_shovel"); return true;}
			case TFClass_DemoMan: {strcopy(buffer, maxlength, "tf_weapon_bottle"); return true;}
		}
	}
	
	if (StrEqual(name, "saxxy")) 
	{
		switch (class)
		{
			case TFClass_Scout:    {strcopy(buffer, maxlength, "tf_weapon_bat");     return true;}
			case TFClass_Soldier:  {strcopy(buffer, maxlength, "tf_weapon_shovel");  return true;}
			case TFClass_Pyro:     {strcopy(buffer, maxlength, "tf_weapon_fireaxe"); return true;}
			case TFClass_DemoMan:  {strcopy(buffer, maxlength, "tf_weapon_bottle");  return true;}
			case TFClass_Heavy:    {strcopy(buffer, maxlength, "tf_weapon_fireaxe"); return true;}
			case TFClass_Engineer: {strcopy(buffer, maxlength, "tf_weapon_wrench");  return true;}
			case TFClass_Medic:    {strcopy(buffer, maxlength, "tf_weapon_bonesaw"); return true;}
			case TFClass_Sniper:   {strcopy(buffer, maxlength, "tf_weapon_club");    return true;}
			case TFClass_Spy:      {strcopy(buffer, maxlength, "tf_weapon_knife");   return true;}
		}
	}
	
	if (StrEqual(name, "tf_weapon_throwable")) 
	{
		switch (class) 
		{
			case TFClass_Medic: {strcopy(buffer, maxlength, "tf_weapon_throwable_primary");   return true;}
			default:            {strcopy(buffer, maxlength, "tf_weapon_throwable_secondary"); return true;}
		}
	}
	
	if (StrEqual(name, "tf_weapon_parachute")) 
	{
		switch (class) 
		{
			case TFClass_Soldier: {strcopy(buffer, maxlength, "tf_weapon_parachute_secondary"); return true;}
			case TFClass_DemoMan: {strcopy(buffer, maxlength, "tf_weapon_parachute_primary");   return true;}
		}
	}
	
	if (StrEqual(name, "tf_weapon_revolver")) 
	{
		switch (class) 
		{
			case TFClass_Engineer: {strcopy(buffer, maxlength, "tf_weapon_revolver_secondary"); return true;}
		}
	}
	
	/* if not handled: return original entity name, not an empty string */
	strcopy(buffer, maxlength, name);
	
	return false;
}

stock void Annotate(float flPos[3], int client, char[] strMsg, int iOffset = 0, float flLifeTime = 8.0, int entitytofollow = -1)
{
	Event event = CreateEvent("show_annotation");
	if (event != null)
	{
		event.SetFloat("worldPosX", flPos[0]);
		event.SetFloat("worldPosY", flPos[1]);
		event.SetFloat("worldPosZ", flPos[2]);
		event.SetFloat("lifetime", flLifeTime);
		event.SetInt("id", client + 8720 + iOffset);
		if (entitytofollow != -1) event.SetInt("follow_entindex", entitytofollow);
		event.SetString("text", strMsg);
		event.SetString("play_sound", "vo/null.wav");
		event.SetString("show_effect", "1");
		event.SetString("show_distance", "1");
		event.SetInt("visibilityBitfield", 1 << client);
		event.Fire(false);
	}
}

stock void AddParticle(int iBuilding, const char[] strParticle)
{
	float flPos[3];
	GetEntPropVector(iBuilding, Prop_Send, "m_vecOrigin", flPos);

	int iParticle = CreateEntityByName("info_particle_system");
	DispatchKeyValueVector(iParticle, "origin", flPos);
	DispatchKeyValue(iParticle, "effect_name", strParticle); 
	DispatchSpawn(iParticle); 
	
	SetVariantString("!activator"); 
	AcceptEntityInput(iParticle, "SetParent", iBuilding); 
	ActivateEntity(iParticle); 
	
	AcceptEntityInput(iParticle, "start"); 
}

stock bool TF2_IsMvM()
{
	return view_as<bool>(GameRules_GetProp("m_bPlayingMannVsMachine"));
}

bool LookupOffset(int &iOffset, const char[] strClass, const char[] strProp)
{
	iOffset = FindSendPropInfo(strClass, strProp);
	if(iOffset <= 0)
	{
		LogMessage("Could not locate offset for %s::%s!", strClass, strProp);
		return false;
	}

	return true;
}