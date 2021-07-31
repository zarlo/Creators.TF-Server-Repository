#pragma semicolon 1
#pragma tabsize 0

#define PLUGIN_AUTHOR "Creators.TF Team"
#define PLUGIN_VERSION "0.01"

#include <sourcemod>
#include <sdktools>
#include <tf2>
#include <tf2_stocks>
#include <clientprefs>
#include <sdkhooks>
#include <basecomm>
#include <loghelper>
#include <tf2attributes>

#include "rca/enums.sp"

Handle g_hDB;
char g_sMap[32];
int Players[MAXPLAYERS + 1][PlayerDataEnum];
bool p_InRespawn[MAXPLAYERS + 1];
int g_PlayerLoadout[MAXPLAYERS + 1][EquipSlotsEnum];
int DEBUG;

Handle g_hSdkEquipWearable;

int g_RessuplyLocked[MAXPLAYERS + 1];
//new g_PlayerOffset[MAXPLAYERS + 1];

#include "rca/stocks.sp"
#include "rca/weapons.sp"
#include "rca/pets.sp"
#include "rca/playermodel.sp"
//#include "rca/emotes.sp"
#include "rca/contracts.sp"
#include "rca/events.sp"
#include "rca/exp.sp"

#include "rca/backpack.sp"


public Plugin myinfo = 
{
	name = "Creators.TF Economy",
	author = PLUGIN_AUTHOR,
	description = "",
	version = PLUGIN_VERSION,
	url = ""
};

public void OnPluginStart()
{
	
	Handle hGameConf = LoadGameConfigFile("tf2items.randomizer");

	if (hGameConf != null)
	{
		StartPrepSDKCall(SDKCall_Player);
		PrepSDKCall_SetFromConf(hGameConf, SDKConf_Virtual, "CTFPlayer::EquipWearable");
		PrepSDKCall_AddParameter(SDKType_CBaseEntity, SDKPass_Pointer);
		g_hSdkEquipWearable = EndPrepSDKCall();

		CloseHandle(hGameConf);
	}
	
	#if defined isDEBUG
	DEBUG = 1;
	#endif
	// ****************
	// COMMANDS
	// ****************
	
	//RegConsoleCmd("sm_test", clTest);
	RegConsoleCmd("sm_pack", cPack);
	RegConsoleCmd("sm_view", cView);
	RegConsoleCmd("sm_equip", cEquip);
	RegConsoleCmd("sm_holster", cHolster);
	RegConsoleCmd("sm_confdel", cConfDel);
	RegConsoleCmd("sm_shop", cStore);
	RegConsoleCmd("sm_store", cStore);
	RegConsoleCmd("sm_contract", cQuest);
	RegConsoleCmd("sm_quest", cQuest);
	//RegConsoleCmd("sm_hud", cHud);
	
	//RegConsoleCmd("sm_collect", cEvent_HWN2019_Items);
	RegConsoleCmd("sm_hud", cHud);
	
	RegAdminCmd("sm_reloadcache", cCache, ADMFLAG_ROOT);
	RegAdminCmd("sm_setquest", cSetQuest, ADMFLAG_ROOT);
	RegAdminCmd("sm_giveitem", cGiveItem, ADMFLAG_ROOT);
	RegAdminCmd("sm_givexp", cGiveExp, ADMFLAG_ROOT);
	RegAdminCmd("sm_givemc", cGiveCredit, ADMFLAG_ROOT);
	
	RegConsoleCmd("say", Command_Say);
	RegConsoleCmd("say_team", Command_SayTeam);
	
	// ****************
	// HOOKS
	// ****************
    HookEvent("player_death", evPlayerDeath);
    HookEvent("post_inventory_application", evPlayerSpawn);
    HookEvent("npc_hurt", evNPCHurt,EventHookMode_Pre);
	HookEvent("teamplay_point_captured", evPointCaptured);
	HookEvent("teamplay_round_start", evRoundStart);
	HookEvent("teamplay_round_win", evRoundEnd);
	HookEvent("killed_capping_player", evKilledCapturing);
	HookEvent("teamplay_win_panel", evWinPanel);
	HookEvent("flagstatus_update", evFlagStatus);
	HookEvent("player_team", evPlayerTeam);
	HookEvent("player_score_changed", evPlayerScore);
	HookEvent("object_destroyed", evObjectDestroyed);
	HookEvent("teamplay_flag_event", evFlagEvent);
	
	RegConsoleCmd("sm_del", cDel);
	RegConsoleCmd("sm_mydata", cMyData);
	// ****************
	// DATABASE
	// ****************
	new String:Error[70];
	g_hDB = SQL_Connect("creatorstf", true, Error, sizeof(Error));
	
	if(g_hDB == INVALID_HANDLE)
	{
		CloseHandle(g_hDB);
	}else{
		SQL_FastQuery(g_hDB, "SET NAMES \"UTF8\"");  
		PrintToServer("[ PACK ] Connection to store database successful");
		LoadItemConfig();
		for (new i = 1; i <= MaxClients; i++)
	    {
	        if (!AreClientCookiesCached(i))
	        {
	            continue;
	        }
	        Players[i][bLogged] = false;
	        AuthenticatePlayer(i);
	    }
	}
	// ****************
	// TIMERS
	// ****************
	
	CreateTimer(60.0, Timer_Broadcast,_,TIMER_REPEAT);
	CreateTimer(1.0, Timer_ShowEquippedText,_,TIMER_REPEAT);
	CreateTimer(0.5, Timer_UpdateHUD, _, TIMER_REPEAT);
	CreateTimer(0.5, Timer_UpdateContractHUD, _, TIMER_REPEAT);
	
	// ****************
	// CON VARS
	// ****************
	g_cvExpPeriod = CreateConVar("sm_exp_period", "120.0", "Period of distributing random amount of exp to player");
	g_cvUnusualChance = CreateConVar("sm_unusual_chance", "100");
	g_cvExpMult = CreateConVar("sm_exp_multiplier", "1.0");
	g_cvCreditMult = CreateConVar("sm_credit_multiplier", "1.0");
	g_cvDonatorMult = CreateConVar("sm_exp_donator_multiplier", "2.0");
	g_tExpTimer = CreateTimer(GetConVarFloat(g_cvExpPeriod), Timer_ExpRandomGain, _, TIMER_REPEAT);
	g_cvExpDropMin = CreateConVar("sm_exp_drop_min", "1");
	g_cvExpDropMax = CreateConVar("sm_exp_drop_max", "5");
	
	g_cvWeaponsBlue = CreateConVar("sm_weapons_blue", "1");
	g_cvWeaponsRed = CreateConVar("sm_weapons_red", "1");
	g_cvPets = CreateConVar("sm_pets", "1");
	HookConVarChange(g_cvExpPeriod, g_cvHookExpPeriod);
	
	//AddNormalSoundHook(NormalSHook:Event_HWN2019_HitHook);
}

public void OnMapStart()
{
	GetCurrentMap(g_sMap, 32);
	LoadItemConfig();
	HookRespawns();
}

public Action Timer_Broadcast(Handle timer, any data)
{
	PrintToChatAll(g_Broadcast[GetRandomInt(0, sizeof(g_Broadcast) - 1)]);
	return Plugin_Continue;
}


public void OnPluginEnd()
{
	for (new i = 1; i <= MaxClients; i++){
		Pets_KillPet(i);
	}
}

// ****************
// ON PLAYER SPAWNED
// ****************

public Action Timer_PostPlayerSpawn(Handle timer, any client)
{
	if (DEBUG == 1)PrintToServer("Timer_PostPlayerSpawn");
    if (g_RessuplyLocked[client])return Plugin_Handled;
    
    if (IsPlayerSpectator(client))return Plugin_Handled;
    
    CreateTimer(0.3, Timer_DisableCooldown, client);
    
	for (new i = 0; i < 4; i++){
		int iWep = GetPlayerWeaponSlot(client, i);
		if(IsValidEdict(iWep)) {
			g_WeaponID[GetPlayerWeaponSlot(client, i)] = 0;
			g_WeaponAttributes[iWep][i] = 0;
		}
	} 
    
    g_RessuplyLocked[client] = true;
    p_InRespawn[client] = true;
    
	for (new i = 1; i < _:EquipSlotsEnum; i++) {
		if (g_PlayerLoadout[client][i] > 0){
			Pack_EquipItem(client, g_PlayerLoadout[client][i], false, true);
		}
	}
	return Plugin_Continue;
}

public Action evPlayerSpawn(Handle hEvent, const char[] szName, bool bDontBroadcast)
{
    int client = GetClientOfUserId(GetEventInt(hEvent, "userid"));
    if (client < 1)return Plugin_Continue;
    Players[client][iKillstreak] = 0;
    CreateTimer(0.1, Timer_PostPlayerSpawn, client);
	if (DEBUG == 1)PrintToServer("evPlayerSpawn - Timer_PostPlayerSpawn created");
	
	SetVariantString("");
	AcceptEntityInput(client, "SetCustomModel");
	
	for (new i = 0; i < _:PlayerCounters; i++)
	{
		g_PlayerCounters[client][i] = 0;
	}
    
	return Plugin_Continue;
}

// ****************
// COOLDOWN RESSUPLY DISABLE TIMER
// ****************

public Action Timer_DisableCooldown(Handle timer, any client)
{
	if (DEBUG == 1)PrintToServer("Timer_DisableCooldown - cooldown disabled");
	g_RessuplyLocked[client] = false;
}

// ****************
// RESPAWN ON TOUCH 
// ****************

public OnRespawnRoomStartTouch( iSpawnRoom, iClient )
	if( 0 < iClient <= MaxClients )
	{
		p_InRespawn[iClient] = true;
	}
	
// ****************
// RESPAWN ON END TOUCH 
// ****************

public OnRespawnRoomEndTouch( iSpawnRoom, iClient )
	if( 0 < iClient <= MaxClients )
	{
		p_InRespawn[iClient] = false;
	}
	
// ****************
// HOOK ALL RESPAWNS 
// ****************

public HookRespawns()
{
	int room;
	while((room=FindEntityByClassname(room, "func_respawnroom"))!=INVALID_ENT_REFERENCE)
	{
		HookRespawn(room);
	}
	if (DEBUG == 1)PrintToServer("HookRespawns - respawns hooked");
}

// ****************
// ON ENT CREATED 
// ****************

public void OnEntityCreated(entity, const char[] classname)
{
	if (StrEqual(classname, "func_respawnroom"))HookRespawn(entity);
	if (StrEqual(classname, "tf_dropped_weapon"))
	{
		if (DEBUG == 1)PrintToServer("OnEntityCreated - blocked weapon from drop");
		SDKHook(entity, SDKHook_SpawnPost, BlockPhysicsGunDrop);
	}
}

// ****************
// HOOK RESPAWN ROOM 
// ****************

public HookRespawn(room){
	if (DEBUG == 1)PrintToServer("HookRespawn - room hooked");
	SDKHook( room, SDKHook_StartTouchPost, OnRespawnRoomStartTouch );
	SDKHook( room, SDKHook_EndTouchPost, OnRespawnRoomEndTouch );
}

public bool OnClientConnect(client)
{
	Players[client][bLogged] = false;
	return true;
}

public OnClientPostAdminCheck(client)
{
	if (DEBUG == 1)PrintToServer("OnClientPostAdminCheck");
	Players[client][bLogged] = false;
	AuthenticatePlayer(client);
}

public OnClientDisconnect(int client)
{
	if(Players[client][bLogged]){
		char szAuth[256];
		GetClientAuthId(client,AuthId_SteamID64, szAuth, sizeof(szAuth));
		char query[200];
		Format(query, 200, "UPDATE `tf_users` SET `credit` = %d, `exp` = %d WHERE `steamid` = \'%s\'" ,Players[client][iCredit],Players[client][iExp],szAuth);
		SQL_FastQuery(g_hDB, query);
	}
}

public AuthenticatePlayer(client){
	// Connecting to Eco
	
	
	if (!IsClientInGame(client))return;
	if (IsFakeClient(client))return;
	SDKHook(client, SDKHook_WeaponSwitchPost, OnWeaponSwitch);
	
	p_InRespawn[client] = false;
	g_HideHud[client] = false;
	
	char szAuth[256];
	GetClientAuthId(client,AuthId_SteamID64, szAuth, sizeof(szAuth));
	char query[300];	
	Format(query, 300, "SELECT * FROM `tf_users` WHERE `steamid` = \'%s\'",szAuth);
	
	Handle queryH = SQL_Query(g_hDB, query);
	
	if(SQL_GetRowCount(queryH) == 0)
	{
		if (DEBUG == 1)PrintToServer("AuthenticatePlayer - no data for %N", client);
		// Ah shit, user isn't registered. Here we go again.
		char token[32];
		Generate_UserToken(token);
		
		Format(query, 300, "INSERT INTO `tf_users` (`steamid`, `queried`) VALUES ('%s',1)",szAuth);
		SQL_FastQuery(g_hDB, query);
		
		Players[client][iUID] = 0;
		Format(Players[client][sSteamID], 32, szAuth);
		Format(Players[client][sLoadout], 512, "");
		Players[client][iExp] = 0;
		Players[client][iCredit] = 0;
		Players[client][iContract] = 0;
		Players[client][bLogged] = true;
		
	}else{
		if (DEBUG == 1)PrintToServer("AuthenticatePlayer - data gained for %N", client);
		if(SQL_FetchRow(queryH)){
			Players[client][iUID] = SQL_FetchInt(queryH, 0);
			SQL_FetchString(queryH, 1, Players[client][sSteamID], 32);
			SQL_FetchString(queryH, 16, Players[client][sLoadout], 512);
			Players[client][iExp] = SQL_FetchInt(queryH, 19);
			Players[client][iCredit] = SQL_FetchInt(queryH, 20);
			Pack_ParseLoadoutString(Players[client][sLoadout], client);
			Contracts_LoadClient(client, SQL_FetchInt(queryH, 21));
			Players[client][bLogged] = true;
		}
	}	
	//Event_HWN2019_LoadData(client);
	
	int hat = EquipWearable(client, "models/player/items/spy/spy_ttg_max.mdl", false);
	GetEntProp(hat, Prop_Send, "m_iItemDefinitionIndex", 640);
	TF2Attrib_SetByDefIndex(hat, 134, 9.0);
	
	CloseHandle(queryH);
}

// ************
// COMMANDS
// ************

public Action cMyData(int client, int args){
	PrintToChat(client, "Your UID: %d", Players[client][iUID]);
	PrintToChat(client, "Your SteamID: %s", Players[client][sSteamID]);
	//PrintToChat(client, "Your Token: %s", Players[client][sToken]);
	PrintToChat(client, "Your SExp: %d", Players[client][iExp]);
	PrintToChat(client, "Your Total Exp: %d", GetClientExp(client));
	PrintToChat(client, "Your Level Exp: %d", GetClientLevel(client));
	PrintToChat(client, "Your Credit: %d", Players[client][iCredit]);
	
	return Plugin_Handled;
}
public Action cCache(int client, int args){
	LoadItemConfig();
	return Plugin_Handled;
}

stock LoadItemConfig()
{
	if (DEBUG == 1)PrintToServer("LoadItemConfig - started loading");
	new String:loc[96];
	BuildPath(Path_SM, loc, 96, "configs/items.cfg");
	new Handle:kv = CreateKeyValues("Items");
	FileToKeyValues(kv,loc);
	KvGetString(kv,"BaseChatColor",g_BaseChatColor,7);
	// Parsing Contract Conditions
	
	if(KvJumpToKey(kv,"Quests",false))
	{
		if(KvJumpToKey(kv,"conditions",false))
		{
			for(new i = 0;i<_:QuestConds;i++){
				new String:Index[11];
				IntToString(i,Index,sizeof(Index));
				KvGetString(kv, Index, g_QuestConditions[i], 32, "");
			}
		}
		KvGoBack(kv);
	}
	KvGoBack(kv);
	// Parsing Unusuals
	
	if (DEBUG == 1)PrintToServer("LoadItemConfig - loading unusuals");
	if(KvJumpToKey(kv,"Unusuals",false))
	{
		for(new i = 1;i<MAXUNUSUALS;i++){
			new String:Index[11];
			IntToString(i,Index,sizeof(Index));
			if(KvJumpToKey(kv,Index,false)){
				g_Unusual[i][iIndex] = i;
				KvGetString(kv,"name",g_Unusual[i][sName],32);
				KvGetString(kv,"system",g_Unusual[i][sSystem],64);
				g_Unusual[i][iDef] = KvGetNum(kv, "index", 0);
				g_Unusual[i][iType] = KvGetNum(kv, "type", 0);
				
			}
			KvGoBack(kv);
		}
	}
	KvGoBack(kv);
	// Parsing Qualities
	
	if (DEBUG == 1)PrintToServer("LoadItemConfig - loading qualities");
	if(KvJumpToKey(kv,"Qualities",false))
	{
		for(new i = 1;i<MAXQUALITIES;i++){
			new String:Index[11];
			IntToString(i,Index,sizeof(Index));
			if(KvJumpToKey(kv,Index,false)){
				g_Quality[i][iIndex] = i;
				KvGetString(kv,"name",g_Quality[i][sName],16);
				KvGetString(kv,"color",g_Quality[i][sColor],7);
				g_Quality[i][iColor][0] = KvGetNum(kv, "red", 255);
				g_Quality[i][iColor][1] = KvGetNum(kv, "green", 255);
				g_Quality[i][iColor][2] = KvGetNum(kv, "blue", 255);
			}
			KvGoBack(kv);
		}
	}
	KvGoBack(kv);
	// Parsing Attributes
	
	if (DEBUG == 1)PrintToServer("LoadItemConfig - loading attributes");
	if(KvJumpToKey(kv,"Attributes",false))
	{
		for(new i = 1;i<MAXATTRIBUTES;i++){
			new String:Index[11];
			IntToString(i,Index,sizeof(Index));
			if(KvJumpToKey(kv,Index,false)){
				g_Attributes[i][iIndex] = i;
				g_Attributes[i][iGroup] = KvGetNum(kv,"value_to",0);
				KvGetString(kv,"name",g_Attributes[i][sName],64);
				KvGetString(kv,"desc",g_Attributes[i][sDesc],128);
				g_Attributes[i][bHidden] = KvGetNum(kv, "hidden", 0) == 1 ? true:false;
			}
			KvGoBack(kv);
		}
	}
	KvGoBack(kv);
	// Parsing Attributes Groups
	
	if (DEBUG == 1)PrintToServer("LoadItemConfig - loading attr groups");
	if(KvJumpToKey(kv,"Attr_Groups",false))
	{
		for(new i = 1;i<MAXATTRGROUPS;i++){
			new String:Index[11];
			IntToString(i,Index,sizeof(Index));
			if(KvJumpToKey(kv,Index,false)){
				new String:testfor[32];
				KvGetString(kv, "use", testfor, 32);
				if(StrEqual(testfor,"unusual_names")){
					g_CustomAttrGroupUse[i] = _:USE_UNUSUAL_NAMES;
				}else if(StrEqual(testfor,"items_names")){
					g_CustomAttrGroupUse[i] = _:USE_ITEM_NAMES;
				}else for(new j = 1;j<MAXAGROUPVALUES;j++){
					g_CustomAttrGroupUse[i] = 0;
					IntToString(j,Index,sizeof(Index));
					KvGetString(kv,Index,g_AttrGroupValues[i][j],64,"invalid");
				}
			}
			KvGoBack(kv);
		}
	}
	KvGoBack(kv);
	// Parsing Collections
	
	if (DEBUG == 1)PrintToServer("LoadItemConfig - loading collections");
	if(KvJumpToKey(kv,"Collections",false))
	{
		for(new i = 1;i<MAXCOLLECTIONS;i++){
			new String:Index[11];
			IntToString(i,Index,sizeof(Index));
			if(KvJumpToKey(kv,Index,false)){
				Handle hCollection = CreateArray();
				for (new j = 1; j < MAXAGROUPVALUES;j++)
				{
					char sJx[11];
					IntToString(j, sJx, 11);
					int iDefIndex = KvGetNum(kv, sJx);
					if (iDefIndex > 0)PushArrayCell(hCollection, iDefIndex);
				}
				g_Collections[i] = hCollection;
				
			}
			KvGoBack(kv);
		}
	}
	KvGoBack(kv);
	
	if (DEBUG == 1)PrintToServer("LoadItemConfig - loading items");
	// Parsing Items
	if(KvJumpToKey(kv,"List",false))
	{
		for(new i = 1;i<MAXITEMS;i++){
			new String:Index[11];
			IntToString(i,Index,sizeof(Index));
			if(KvJumpToKey(kv,Index,false)){
				Items[i][iDef] = i;
				KvGetString(kv,"name",Items[i][sName],64);
				KvGetString(kv,"desc",Items[i][sDesc],1024);
				KvGetString(kv,"attribs",Items[i][AttribsCustom],128);
				Items[i][iUType] = KvGetNum(kv, "utype", 0);
				for(new j = 1;j<=64;j++){
					new String:sDownloadIndex[16];
					Format(sDownloadIndex,sizeof(sDownloadIndex),"download_%d",j);
					new String:addr[255];
					KvGetString(kv,sDownloadIndex,addr,255,"0");
					if (StrEqual(addr, "0"))break;
					AddFileToDownloadsTable(addr);
				}
				for(new j = 1;j<=64;j++){
					new String:sDownloadIndex[16];
					Format(sDownloadIndex,sizeof(sDownloadIndex),"dl_dir_%d",j);
					new String:addr[255];
					KvGetString(kv,sDownloadIndex,addr,255,"0");
					if (StrEqual(addr, "0"))break;
					ReadFileFolder(addr);
				}
				new String:itemtype[32];
				new String:buffer[11];
				KvGetString(kv,"type",itemtype,32);
				if(StrEqual(itemtype,"weapon"))
				{
					Items[i][iType] = _:TYPE_WEAPON;
					KvGetString(kv,"attribs_tf2",Weapons[i][AttribsTF2],128);
					KvGetString(kv,"classname",Weapons[i][sClassName],32);
					
					KvGetString(kv,"class",buffer,11,"0");
					new class = StringToInt(buffer);
					Weapons[i][iClass] = class;
					
					KvGetString(kv,"defid",buffer,11,"0");
					Weapons[i][iDef] = StringToInt(buffer);
					
					KvGetString(kv,"maxammo",buffer,11,"0");
					Weapons[i][iMaxAmmo] = StringToInt(buffer);
					
					KvGetString(kv,"slot",buffer,11,"0");
					Weapons[i][iSlot] = StringToInt(buffer);
					KvGetString(kv,"worldmodel",Weapons[i][sWorldModel],512,"");
					KvGetString(kv,"viewmodel",Weapons[i][sViewModel],512,Weapons[i][sWorldModel]);
					
					Items[i][iSlot] = GetSlotForMulticlass(class, Weapons[i][iSlot]);
				}
				if(StrEqual(itemtype,"pet"))
				{
					Items[i][iType] = _:TYPE_PET;
					Items[i][iSlot] = _:SLOT_MULTI_PET;
					KvGetString(kv,"model",Pets[i][sModelPath],128);
					KvGetString(kv,"idleseq",Pets[i][sIdleSequence],32);
					KvGetString(kv,"walkseq",Pets[i][sWalkSequence],32);
					KvGetString(kv,"jumpseq",Pets[i][sJumpSequence],32);
					Pets[i][flModelScale] = KvGetFloat(kv, "scale", 1.0);
					Pets[i][offPos][0] = KvGetFloat(kv, "opx", 0.0);
					Pets[i][offPos][1] = KvGetFloat(kv, "opy", 0.0);
					Pets[i][offPos][2] = KvGetFloat(kv, "opz", 0.0);
					Pets[i][offRot][0] = KvGetFloat(kv, "orx", 0.0);
					Pets[i][offRot][1] = KvGetFloat(kv, "ory", 0.0);
					Pets[i][offRot][2] = KvGetFloat(kv, "orz", 0.0);
					Pets[i][offParticle][0] = KvGetFloat(kv, "oux", 0.0);
					Pets[i][offParticle][1] = KvGetFloat(kv, "ouy", 0.0);
					Pets[i][offParticle][2] = KvGetFloat(kv, "ouz", 0.0);
					PrecacheModel(Pets[i][sModelPath]);
				}
				/*
				if(StrEqual(itemtype,"emote"))
				{
					Items[i][iType] = _:TYPE_EMOTE;
					KvGetString(kv,"code",Emotes[i][sCode],128);
					KvGetString(kv,"material",Emotes[i][sMaterial],128);
					PrecacheModel(Emotes[i][sMaterial]);
				}*/
				if(StrEqual(itemtype,"tool"))
				{
					Items[i][iType] = _:TYPE_TOOL;
					//PrecacheModel(Emotes[i][sMaterial]);
				}
				if(StrEqual(itemtype,"playermodel"))
				{
					Items[i][iType] = _:TYPE_PLAYERMODEL;
					int class = Playermodels[i][iClass] = KvGetNum(kv, "class", 0);
					Items[i][iSlot] = GetSlotForMulticlass(class, 4);
					KvGetString(kv,"model",Playermodels[i][sPath],64);
					PrecacheModel(Playermodels[i][sPath]);
				}
				KvGoBack(kv);
			}
		}
		KvGoBack(kv);
	}
}


public Action:Command_Say(client, args)
{
	if(BaseComm_IsClientGagged(client)){
		return Plugin_Handled;
	}
    
	new String:newText[1024];

	decl String:text[192];
	decl String:nick[192];

	new String:szAuth[256];
	GetClientAuthId(client,AuthId_SteamID64, szAuth, sizeof(szAuth));

	GetClientName(client, nick, sizeof(nick));
	GetCmdArgString(text, sizeof(text));
	StripQuotes(text);
	LogPlayerEvent(client, "say", text);

	if(strncmp(text, "/", 1) == 0 || strncmp(text, "@", 1) == 0 ){
		return Plugin_Handled;
	}

	if(strncmp(text, "!", 1) != 0)
	{
		//Emotes_HookSay(client, text);
	}

	Format(newText, 1024, "\x07FFFFFF :  \x07e8e4c7%s", text);



	if(GetClientTeam(client) == 0 || GetClientTeam(client) == 1){
		Format(newText, 1024, "\x07FFFFFF*SPEC* %s%s",nick, newText);
	}else{
		if(IsPlayerAlive(client)){
			Format(newText, 1024, "\x07%s%s%s", TeamColors[GetClientTeam(client)], nick, newText);
		}else{
			Format(newText, 1024, "\x07FFFFFF*DEAD*\x07%s %s%s", TeamColors[GetClientTeam(client)], nick, newText);
		}
	}
	
	if (GetUserFlagBits(client) & ADMFLAG_ROOT == ADMFLAG_ROOT)
	{
		Format(newText, 1024, "\x0757db3d[R] %s", newText);
	}else if(GetUserFlagBits(client) & ADMFLAG_CUSTOM3 == ADMFLAG_CUSTOM3){
		Format(newText, 1024, "\x07f4cb42[A] %s", newText);
	}else if(GetUserFlagBits(client) & ADMFLAG_CUSTOM2 == ADMFLAG_CUSTOM2){
		Format(newText, 1024, "\x074156f4[M] %s", newText);
	}else if(GetUserFlagBits(client) & ADMFLAG_CUSTOM1 == ADMFLAG_CUSTOM1){
		Format(newText, 1024, "\x077d4071[V] %s", newText);
	}

	PrintToChatAll("%s", newText);
	return Plugin_Handled;
}

public Action:Command_SayTeam(client, args)
{
	if(BaseComm_IsClientGagged(client)){
		return Plugin_Handled;
	}
    
	new String:newText[1024];

	decl String:text[192];
	decl String:nick[192];

	new String:szAuth[256];
	GetClientAuthId(client,AuthId_SteamID64, szAuth, sizeof(szAuth));

	GetClientName(client, nick, sizeof(nick));
	GetCmdArgString(text, sizeof(text));
	StripQuotes(text);
	LogPlayerEvent(client, "say_team", text);

	if(strncmp(text, "/", 1) == 0 || strncmp(text, "@", 1) == 0 ){
		return Plugin_Handled;
	}

	Format(newText, 1024, "\x07FFFFFF :  \x07e8e4c7%s", text);

	if(GetClientTeam(client) == 0 || GetClientTeam(client) == 1){
		Format(newText, 1024, "\x07FFFFFF(SPEC) %s%s",nick, newText);
	}else{
		if(IsPlayerAlive(client)){
			Format(newText, 1024, "\x07FFFFFF(TEAM) \x07%s%s%s", TeamColors[GetClientTeam(client)], nick, newText);
		}else{
			Format(newText, 1024, "\x07FFFFFF*DEAD* (TEAM)\x07%s %s%s", TeamColors[GetClientTeam(client)], nick, newText);
		}
	}
	
	if (GetUserFlagBits(client) & ADMFLAG_ROOT == ADMFLAG_ROOT)
	{
		Format(newText, 1024, "\x0757db3d[R] %s", newText);
	}else if(GetUserFlagBits(client) & ADMFLAG_CUSTOM3 == ADMFLAG_CUSTOM3){
		Format(newText, 1024, "\x07f4cb42[A] %s", newText);
	}else if(GetUserFlagBits(client) & ADMFLAG_CUSTOM2 == ADMFLAG_CUSTOM2){
		Format(newText, 1024, "\x074156f4[M] %s", newText);
	}else if(GetUserFlagBits(client) & ADMFLAG_CUSTOM1 == ADMFLAG_CUSTOM1){
		Format(newText, 1024, "\x077d4071[V] %s", newText);
	}
	for(new i = 1; i < MaxClients; i++){
		if(IsValidEntity(i)){
		if(IsClientInGame(i)){
			if(GetClientTeam(i) == GetClientTeam(client)){
				PrintToChat(i,"%s", newText);
			}
		}
		}
	}
	return Plugin_Handled;
}