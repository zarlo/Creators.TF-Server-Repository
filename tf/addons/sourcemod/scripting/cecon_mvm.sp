#include <steamtools>

#pragma semicolon 1
#pragma newdecls required
#pragma dynamic 1048576

#include <sdktools>
#include <sdkhooks>
#include <cecon>
#include <cecon_items>
#include <cecon_http>
#include <tf2_stocks>
#include <tf2motd>
#include <regex>

#define TF_TEAM_UNASSIGNED 0
#define TF_TEAM_SPECTATOR 1
#define TF_TEAM_INVADERS 3
#define TF_TEAM_DEFENDERS 2

public Plugin myinfo =
{
	name = "Creators.TF - Mann vs Machines",
	author = "Creators.TF Team",
	description = "Creators.TF - Mann vs Machines",
	version = "1.03",
	url = "https://creators.tf"
};

ConVar ce_mvm_show_game_time;
ConVar ce_mvm_restart_on_changelevel_from_mvm;
ConVar ce_mvm_switch_to_pubs_timer;

Handle m_hBackToPubs;

int m_iCurrentWave;
int m_iLastPlayerCount;

float m_flWaveStartTime;
int m_iTotalTime;
int m_iSuccessTime;
int m_iWaveTime;

bool m_bWaitForGameRestart;
bool m_bWeJustFailed;

char m_sLastTourLootHash[128];
/*
Regex dhooksRegex;
Regex sigRegex;
Regex numbersRegex;
*/
enum struct CEItemBaseIndex
{
	int m_iItemDefinitionIndex;
	int m_iBaseItemIndex;
}
ArrayList m_hItemIndexes;

public void OnPluginStart()
{
	ce_mvm_show_game_time = CreateConVar("ce_mvm_show_game_time", "1", "Enables game time summary to be shown in chat");
	ce_mvm_switch_to_pubs_timer = CreateConVar("ce_mvm_switch_to_pubs_timer", "-1", "Switch to pubs after this amount of time.");

	HookEvent("mvm_begin_wave", mvm_begin_wave);
	HookEvent("mvm_wave_complete", mvm_wave_complete);
	HookEvent("mvm_wave_failed", mvm_wave_failed);
	HookEvent("mvm_mission_complete", mvm_mission_complete);

	HookEvent("teamplay_round_win", teamplay_round_win);
	HookEvent("teamplay_round_start", teamplay_round_start);

	HookEvent("player_changeclass", player_changeclass);

	// In a local build of the economy, the users will not be able to update
	// their wave progress or see tour loot.
#if !defined LOCAL_BUILD
	RegConsoleCmd("sm_loot", cLoot, "Opens the latest Tour Loot page");
#endif


	RegAdminCmd("ce_mvm_set_wave_time", cSetWave, ADMFLAG_ROOT);

	// SigSegv extension workaround.
	AddCommandListener(cChangelevel, "changelevel");
	ce_mvm_restart_on_changelevel_from_mvm = CreateConVar("ce_mvm_restart_on_changelevel_from_mvm", "0");
}

public Action cChangelevel(int client, const char[] command, int args)
{
	// Don't do anything if we're not playing MvM.
	if (!TF2MvM_IsPlayingMvM())return Plugin_Continue;

	// We can opt out of this feature.
	if (!ce_mvm_restart_on_changelevel_from_mvm.BoolValue)return Plugin_Continue;

	char sNeedle[PLATFORM_MAX_PATH];
	GetCmdArg(1, sNeedle, sizeof(sNeedle));

	if(FindMap(sNeedle, sNeedle, sizeof(sNeedle)) != FindMap_NotFound)
	{
		if(StrContains(sNeedle, "mvm_") != 0)
		{
			LogMessage("We're switching back to pub maps, restart the server...");
			// Stop the server.
			ServerCommand("quit");
			return Plugin_Handled;
		}
	}

	return Plugin_Continue;
}

public void CEcon_OnSchemaUpdated(KeyValues hSchema)
{
	ParseEconomySchema(hSchema);
}

public void OnAllPluginsLoaded()
{
	ParseEconomySchema(CEcon_GetEconomySchema());
}

public void ParseEconomySchema(KeyValues hSchema)
{
	delete m_hItemIndexes;
	if (hSchema == null)return;
	m_hItemIndexes = new ArrayList(sizeof(CEItemBaseIndex));

	if(hSchema.JumpToKey("Items"))
	{
		if(hSchema.GotoFirstSubKey())
		{
			do {
				int iBaseIndex = hSchema.GetNum("item_index", -1);
				if(iBaseIndex > -1)
				{
					char sName[11];
					hSchema.GetSectionName(sName, sizeof(sName));

					CEItemBaseIndex xRecord;

					xRecord.m_iItemDefinitionIndex = StringToInt(sName);
					xRecord.m_iBaseItemIndex = iBaseIndex;

					m_hItemIndexes.PushArray(xRecord);
				}

			} while (hSchema.GotoNextKey());
		}
	}

	// Make sure we do that every time
	hSchema.Rewind();

}

public int GetDefinitionBaseIndex(int defid)
{
	if (m_hItemIndexes == null)return -1;

	for (int i = 0; i < m_hItemIndexes.Length; i++)
	{
		CEItemBaseIndex xRecord;
		m_hItemIndexes.GetArray(i, xRecord);
		if (xRecord.m_iItemDefinitionIndex != defid)continue;
		return xRecord.m_iBaseItemIndex;
	}

	return -1;
}

public void PrintGameStats()
{
	if (!ce_mvm_show_game_time.BoolValue)return;

	char sTimer[32];
	int iMissionTime = GetTotalMissionTime();
	TimeToStopwatchTimer(iMissionTime, sTimer, sizeof(sTimer));
	PrintToChatAll("\x01Total time spent in mission: \x03%s", sTimer);

	int iSuccessTime = GetTotalSuccessTime();
	int iPercentage = RoundToFloor(float(iSuccessTime) / float(iMissionTime) * 100.0);
	if (iPercentage < 0)iPercentage = 0;
	TimeToStopwatchTimer(iSuccessTime, sTimer, sizeof(sTimer));
	PrintToChatAll("\x01Total success time in mission: \x03%s (%d%%)", sTimer, iPercentage);

	int iWaveTime = GetTotalWaveTime();
	TimeToStopwatchTimer(iWaveTime, sTimer, sizeof(sTimer));
	PrintToChatAll("\x01Time spent on Wave %d: \x03%s", m_iCurrentWave, sTimer);
}

public Action teamplay_round_start(Handle hEvent, const char[] szName, bool bDontBroadcast)
{
	// This is usually fired after we lost a round.
	if(m_bWeJustFailed)
	{
		OnDefendersLost();
		m_bWeJustFailed = false;
	}

	m_bWaitForGameRestart = false;
	UpdateSteamGameName();
}

public void ProcessTime(int time, bool success)
{
	AddTimeToTotalWaveTime(time);
	AddTimeToTotalTime(time);
	if(success)
	{
		AddTimeToSuccessTime(time);
	}
}

public Action teamplay_round_win(Handle hEvent, const char[] szName, bool bDontBroadcast)
{
	// This is usually fired when we lose.
	if (!TF2MvM_IsPlayingMvM())return Plugin_Continue;
	int iTeam = GetEventInt(hEvent, "team");

	if(iTeam == TF_TEAM_INVADERS)
	{
		m_bWeJustFailed = true;
	}
	UpdateSteamGameName();

	return Plugin_Continue;
}

public void OnDefendersWon()
{
	int time = GetCurrentWaveTime();
	ProcessTime(time, true);
	PrintGameStats();
	ClearWaveStartTime();
	UpdateSteamGameName();
	
	SendUniqueEventToEngaged("TF_MVM_STAT_WAVE_WIN", 1);
	SendUniqueEventToEngaged("TF_MVM_STAT_WAVE_ATTEMPT", 1);
}

public void OnDefendersLost()
{
	int time = GetCurrentWaveTime();
	ProcessTime(time, false);
	PrintGameStats();
	ClearWaveStartTime();
	UpdateSteamGameName();
	
	SendUniqueEventToEngaged("TF_MVM_STAT_WAVE_LOSS", 1);
	SendUniqueEventToEngaged("TF_MVM_STAT_WAVE_ATTEMPT", 1);
}

public void SetWaveStartTime()
{
	m_flWaveStartTime = GetEngineTime();
}

public void ClearWaveStartTime()
{
	m_flWaveStartTime = 0.0;
}

public int GetCurrentWaveTime()
{
	if (m_flWaveStartTime == 0.0)return 0;
	return RoundToFloor(GetEngineTime() - m_flWaveStartTime);
}

public void AddTimeToTotalWaveTime(int time)
{
	m_iWaveTime += time;
}

public void AddTimeToTotalTime(int time)
{
	m_iTotalTime += time;
}

public void AddTimeToSuccessTime(int time)
{
	m_iSuccessTime += time;
}

public int GetTotalSuccessTime()
{
	return m_iSuccessTime;
}

public int GetTotalWaveTime()
{
	return m_iWaveTime;
}

public int GetTotalMissionTime()
{
	return m_iTotalTime;
}

public void ResetStats()
{
	PrintToChatAll("Game Restarted. Resetting stats...");
	m_iSuccessTime = 0;
	m_iWaveTime = 0;
	m_iTotalTime = 0;
	ClearWaveStartTime();

	UpdateSteamGameName();
}

public Action mvm_begin_wave(Handle hEvent, const char[] szName, bool bDontBroadcast)
{
	int iWave = GetEventInt(hEvent, "wave_index");
	int iRealWave = iWave + 1;

	if(iRealWave != m_iCurrentWave)
	{
		m_iWaveTime = 0;
	}

	// Let's start with 1 and not zero.
	m_iCurrentWave = iRealWave;
	SetWaveStartTime();
	UpdateSteamGameName();
}

public Action player_changeclass(Event hEvent, const char[] szName, bool bDontBroadcast)
{
	UpdateSteamGameName();
}

public Action mvm_mission_complete(Handle hEvent, const char[] szName, bool bDontBroadcast)
{
	UpdateSteamGameName();

	CreateTimer(10.0, Timer_RestartMvMGame);
}

public Action mvm_wave_complete(Handle hEvent, const char[] szName, bool bDontBroadcast)
{
	// int iAdvanced = GetEventInt(hEvent, "advanced");
	// PrintToChatAll("mvm_wave_complete (advanced %d)", iAdvanced);

	OnDefendersWon();

	int iWave = m_iCurrentWave;
	int iTime = GetTotalWaveTime();
	SendWaveCompletionTime(iWave, iTime);
	UpdateSteamGameName();
}

public Action mvm_wave_failed(Handle hEvent, const char[] szName, bool bDontBroadcast)
{
	if(m_bWaitForGameRestart)
	{
		m_bWaitForGameRestart = false;
		ResetStats();
	} else {
		m_bWaitForGameRestart = true;
	}
	UpdateSteamGameName();
}

public void OnMvMGameStart()
{
	// Someone joined the game.
	strcopy(m_sLastTourLootHash, sizeof(m_sLastTourLootHash), "");
	ResetStats();
	UpdateSteamGameName();
}

public void OnMvMGameEnd()
{
	// Everyone left the game.
	strcopy(m_sLastTourLootHash, sizeof(m_sLastTourLootHash), "");
	ResetStats();

	if(TF2MvM_IsPlayingMvM())
	{
		ScheduleServerRestart();
	}
	UpdateSteamGameName();
}

public Action OnLevelInit(const char[] mapName, char mapEntities[2097152])
{
	// Not perfect but simplest way to do at this stage of map loading
	if (strncmp(mapName, "mvm_", 4) == 0)
	{
		LoadSigsegvExtension();
	}
}

Action LoadFirstMission(Handle handle)
{
	int popmgr = FindEntityByClassname(-1, "info_populator");
	DispatchSpawn(popmgr);
	UpdateSteamGameName();
}

public void OnMapStart()
{

	if (TF2MvM_IsPlayingMvM())
	{
		LoadSigsegvExtension();
		RequestFrame(RF_RecalculatePlayerCount);

		ScheduleServerRestart();
		UpdateSteamGameName();
		CreateTimer(1.0, LoadFirstMission);
	}
}

public void ScheduleServerRestart()
{
	if(ce_mvm_switch_to_pubs_timer.IntValue < 0) return;

	if(m_hBackToPubs != INVALID_HANDLE)
	{
		KillTimer(m_hBackToPubs);
		m_hBackToPubs = INVALID_HANDLE;
	}

	m_hBackToPubs = CreateTimer(ce_mvm_switch_to_pubs_timer.FloatValue, Timer_BackToPubs);
}

public Action Timer_BackToPubs(Handle timer, any data)
{
	m_hBackToPubs = INVALID_HANDLE;

	if(TF2MvM_IsPlayingMvM())
	{
		if(GetRealClientCount() == 0)
		{
			LogMessage("Noone was on the server for %d seconds. Switching back to pubs.", ce_mvm_switch_to_pubs_timer.IntValue);
			// Noose is on the server.
			ServerCommand("quit");
		}
	}
}

public void LoadSigsegvExtension()
{
	// unload comp fixes, the only plugin that uses dhooks - this takes at least a frame
	//ServerCommand("sm plugins unload external/tf2-comp-fixes.smx");
	//ServerExecute();

	// Update true sigsegv extension file from update file
	LoadSigsegvForReal();
}

Action LoadSigsegvForReal()
{
	ServerCommand("sm exts load sigsegv.ext.2.tf2");
	ServerExecute();
	ServerCommand("exec sigsegv_mvm_convars");
	ServerExecute();
}

public bool TF2MvM_IsPlayingMvM()
{
	return (GameRules_GetProp("m_bPlayingMannVsMachine") != 0);
}

/**
*	Purpose: 	ce_mvm_force_loot command.
*/
public Action cSetWave(int client, int args)
{
	char sArg[11];
	GetCmdArg(1, sArg, sizeof(sArg));
	int iWave = StringToInt(sArg);

	GetCmdArg(2, sArg, sizeof(sArg));
	int iTime = StringToInt(sArg);

	SendWaveCompletionTime(iWave, iTime);

	return Plugin_Handled;
}

/**
*	Purpose: 	ce_mvm_equip_itemname command.
*/
public Action SIG_OnGiveCustomItem(int client, const char[] itemname)
{
	CEItem xItem;
	if(CEconItems_CreateNamedItem(xItem, itemname, 6, null))
	{
		CEconItems_GiveItemToClient(client, xItem);
	}

	return Plugin_Handled;
}

/**
*	Purpose: 	ce_mvm_get_itemdef_id command.
*/
public Action SIG_GetCustomItemID(const char[] itemname, int classindex, int& base_item_id)
{
	if (!StrEqual(itemname, ""))
	{
		CEItemDefinition xDef;
		if(CEconItems_GetItemDefinitionByName(itemname, xDef))
		{
			base_item_id = GetDefinitionBaseIndex(xDef.m_iIndex);
			return Plugin_Handled;
		}
	}

	return Plugin_Handled;
}

/**
*	Purpose: 	ce_mvm_set_attribute command.
*/
public Action SIG_SetCustomAttribute(int entity, const char[] attrib, const char[] value)
{
	CEconItems_SetEntityAttributeString(entity, attrib, value);

	return Plugin_Handled;
}

public bool IsClientReady(int client)
{
	if (!IsClientValid(client))return false;
	if (IsFakeClient(client))return false;
	return true;
}

public bool IsClientValid(int client)
{
	if (client <= 0 || client > MaxClients)return false;
	if (!IsClientInGame(client))return false;
	if (!IsClientAuthorized(client))return false;
	return true;
}

public void OnClientPutInServer(int client)
{
	if(!IsFakeClient(client))
	{
		RequestFrame(RF_RecalculatePlayerCount);
	}
}


public void OnClientDisconnect(int client)
{
	if(!IsFakeClient(client))
	{
		RequestFrame(RF_RecalculatePlayerCount);
	}
}

public void RF_RecalculatePlayerCount(any data)
{
	RecalculatePlayerCount();
}

public void RecalculatePlayerCount()
{
	if (!TF2MvM_IsPlayingMvM())return;

	int count = GetRealClientCount();
	int old = m_iLastPlayerCount;
	m_iLastPlayerCount = count;

	if(old == 0 && count > 0)
	{
		OnMvMGameStart();
	} else if(count == 0 && old > 0)
	{
		OnMvMGameEnd();
	}
}

public int GetRealClientCount()
{
	int count = 0;

	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && !IsFakeClient(i))
		{
			count++;
		}
	}

	return count;
}

public void TimeToStopwatchTimer(int time, char[] buffer, int size)
{
	char[] timer = new char[size + 1];

	int iForHours = time;
	int iSecsInHour = 60 * 60;
	int iHours = iForHours / iSecsInHour;
	if(iHours > 0)
	{
		Format(timer, size, "%d hr ", iHours);
	}

	int iSecInMins = 60;
	int iForMins = iForHours % iSecsInHour;
	int iMinutes = iForMins / iSecInMins;
	if(iMinutes > 0)
	{
		Format(timer, size, "%s%d min ", timer, iMinutes);
	}

	int iSeconds = iForMins % iSecInMins;
	Format(timer, size, "%s%d sec", timer, iSeconds);

	strcopy(buffer, size, timer);
}

public void GetPopFileName(char[] buffer, int length)
{
	char filename[256];

	int ObjectiveEntity = FindEntityByClassname(-1, "tf_objective_resource");
	GetEntPropString(ObjectiveEntity, Prop_Send, "m_iszMvMPopfileName", filename, sizeof(filename));

	char explode[6][256];
	int count = ExplodeString(filename, "/", explode, sizeof(explode), sizeof(explode[]));

	char name[256];
	strcopy(name, sizeof(name), explode[count - 1]);
	ReplaceString(name, sizeof(name), ".pop", "");

	strcopy(buffer, length, name);
}

public void SendWaveCompletionTime(int wave, int seconds)
{
	// In a local build of the economy, the users will not be able to update
	// their wave progress or see tour loot.
#if !defined LOCAL_BUILD
	char sPopFile[256];
	GetPopFileName(sPopFile, sizeof(sPopFile));

	HTTPRequestHandle hRequest = CEconHTTP_CreateBaseHTTPRequest("/api/IEconomySDK/UserMvMWaveProgress", HTTPMethod_POST);

	int iCount = 0;
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientEngaged(i))continue;

		char sSteamID[64];
		GetClientAuthId(i, AuthId_SteamID64, sSteamID, sizeof(sSteamID));

		char sKey[32];
		Format(sKey, sizeof(sKey), "steamids[%d]", iCount);
		Steam_SetHTTPRequestGetOrPostParameter(hRequest, sKey, sSteamID);

		Format(sKey, sizeof(sKey), "classes[%d]", iCount);
		char sClass[32];
		switch(TF2_GetPlayerClass(i))
		{
			case TFClass_Scout:strcopy(sClass, sizeof(sClass), "scout");
			case TFClass_Soldier:strcopy(sClass, sizeof(sClass), "soldier");
			case TFClass_Pyro:strcopy(sClass, sizeof(sClass), "pyro");
			case TFClass_DemoMan:strcopy(sClass, sizeof(sClass), "demo");
			case TFClass_Heavy:strcopy(sClass, sizeof(sClass), "heavy");
			case TFClass_Engineer:strcopy(sClass, sizeof(sClass), "engineer");
			case TFClass_Medic:strcopy(sClass, sizeof(sClass), "medic");
			case TFClass_Sniper:strcopy(sClass, sizeof(sClass), "sniper");
			case TFClass_Spy:strcopy(sClass, sizeof(sClass), "spy");
		}
		Steam_SetHTTPRequestGetOrPostParameter(hRequest, sKey, sClass);

		iCount++;
	}

	// Setting wave number.
	char sValue[64];
	IntToString(wave, sValue, sizeof(sValue));
	Steam_SetHTTPRequestGetOrPostParameter(hRequest, "wave", sValue);

	// Setting time number.
	IntToString(seconds, sValue, sizeof(sValue));
	Steam_SetHTTPRequestGetOrPostParameter(hRequest, "time", sValue);

	// Setting mission name.
	Steam_SetHTTPRequestGetOrPostParameter(hRequest, "mission", sPopFile);

	DataPack hPack = new DataPack();
	hPack.WriteCell(wave);
	hPack.WriteCell(seconds);
	hPack.Reset();

	Steam_SendHTTPRequest(hRequest, SendWaveCompletionTime_Callback, hPack);
#endif
}

// In a local build of the economy, the users will not be able to update
// their wave progress or see tour loot.
#if !defined LOCAL_BUILD
public void SendWaveCompletionTime_Callback(HTTPRequestHandle request, bool success, HTTPStatusCode code, any pack)
{
	DataPack hPack = pack;

	if(!success || code != HTTPStatusCode_OK)
	{

		LogMessage("Updating wave information failed. Try again in a bit.");
		CreateTimer(5.0, Timer_SendWaveAgain, hPack);

		return;
	}

	delete hPack;

	// Getting response size.
	int size = Steam_GetHTTPResponseBodySize(request);
	char[] content = new char[size + 1];

	Steam_GetHTTPResponseBodyData(request, content, size);
	Steam_ReleaseHTTPRequest(request);

	PrintToServer(content);

	KeyValues Response = new KeyValues("Response");

	// If we fail to import content return.
	if (!Response.ImportFromString(content))return;
	Response.GetString("hash", m_sLastTourLootHash, sizeof(m_sLastTourLootHash));
	delete Response;

	if(!StrEqual(m_sLastTourLootHash, ""))
	{
		OpenTourLootMsgToAll();
	}
}

public Action Timer_SendWaveAgain(Handle timer, any data)
{
	DataPack hPack = data;

	int wave = hPack.ReadCell();
	int time = hPack.ReadCell();
	delete hPack;

	SendWaveCompletionTime(wave, time);
}

public void OpenTourLootMsgToAll()
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientReady(i))continue;

		OpenLastTourLootMsg(i);
	}
}

public void OpenLastTourLootMsg(int client)
{
	ClientCommand(client, "playgamesound ui/hint.wav");
	Menu menu = new Menu(Menu_QuickSwitch);
	menu.SetTitle("Your Loot for completing\nthis mission is available.\nWould you like to see it?.");
	menu.AddItem("yes", "Open it.");
	menu.AddItem("no", "Nah.");

	menu.ExitButton = false;
	menu.Display(client, 20);
}

public int Menu_QuickSwitch(Menu menu, MenuAction action, int client, int param2)
{
	if (action == MenuAction_Select)
	{
		char info[32];
		menu.GetItem(param2, info, sizeof(info));
		if(StrEqual(info, "yes"))
		{
			OpenLastTourLootPage(client);
		} else {
			PrintToChat(client, "\x01* Type \x03!loot \x01in chat to reopen the tour loot preview.");
		}
	} else if (action == MenuAction_End)
	{
		delete menu;
	}
}

public void OpenLastTourLootPage(int client)
{
	if (StrEqual(m_sLastTourLootHash, ""))return;

	char sSteamID[64];
	GetClientAuthId(client, AuthId_SteamID64, sSteamID, sizeof(sSteamID));

	char url[PLATFORM_MAX_PATH];
	Format(url, sizeof(url), "/tourloot?hash=%s&steamid=%s", m_sLastTourLootHash, sSteamID);
	CEconHTTP_CreateAbsoluteBackendURL(url, url, sizeof(url));

	TF2Motd_OpenURL(client, url, "\x01* Please set \x03cl_disablehtmlmotd 0 \x01in your console and type \x03!loot \x01in chat to see the loot.");

	PrintToChat(client, "\x01* Type \x03!loot \x01in chat to reopen the tour loot preview.");
}

public void OpenTourLootLoadingPage(int client)
{
	char url[PLATFORM_MAX_PATH];
	Format(url, sizeof(url), "/tourloot");
	CEconHTTP_CreateAbsoluteBackendURL(url, url, sizeof(url));

	TF2Motd_OpenURL(client, url, "\x01* Please set \x03cl_disablehtmlmotd 0 \x01in your console and type \x03!loot \x01in chat to see the loot.");
}

public Action cLoot(int client, int args)
{
	UpdateSteamGameName();
	OpenLastTourLootPage(client);
	return Plugin_Handled;
}
#endif

//-------------------------------------------------------------------
// Purpose: Returns true if client is a not a bot and also has a
// non-spectator team.
//-------------------------------------------------------------------
public bool IsClientEngaged(int client)
{
	if (!IsClientReady(client))return false;

	int nTeam = GetClientTeam(client);
	if (nTeam == TF_TEAM_UNASSIGNED)return false;
	if (nTeam == TF_TEAM_SPECTATOR)return false;

	return true;
}

public void UpdateSteamGameName()
{
	RequestFrame(RF_UpdateSteamGameName);
}

public void RF_UpdateSteamGameName(any data)
{
	if(TF2MvM_IsPlayingMvM())
	{
		char sRound[16];
		switch(GameRules_GetRoundState())
		{
			case RoundState_Init,
			RoundState_Pregame,
			RoundState_StartGame,
			RoundState_Preround,
			RoundState_BetweenRounds:
			{
				strcopy(sRound, sizeof(sRound), "Setup");
			}


			case RoundState_RoundRunning,
			RoundState_TeamWin:
			{
				strcopy(sRound, sizeof(sRound), "In-Wave");
			}

			case RoundState_Restart,
			RoundState_Stalemate,
			RoundState_GameOver,
			RoundState_Bonus:
			{
				strcopy(sRound, sizeof(sRound), "Game Over");
			}
		}

		int iResource = FindEntityByClassname(-1, "tf_objective_resource");
		int iCurrentWave = GetEntProp(iResource, Prop_Send, "m_nMannVsMachineWaveCount");
		int iMaxWaves = GetEntProp(iResource, Prop_Send, "m_nMannVsMachineMaxWaveCount");

		char sTeamComp[16];
		for (int i = 1; i <= MaxClients; i++)
		{
			if (!IsClientEngaged(i))continue;
			TFClassType nClass = TF2_GetPlayerClass(i);

			int iClass = view_as<int>(nClass);
			Format(sTeamComp, sizeof(sTeamComp), "%s%d", sTeamComp, iClass);
		}

		char sGame[64];
		Format(sGame, sizeof(sGame), "Team Fortress (Wave %d/%d :: %s :: %s)", iCurrentWave, iMaxWaves, sRound, sTeamComp);

		Steam_SetGameDescription(sGame);
	} else {
		Steam_SetGameDescription("Team Fortress");
	}
}

public Action MvM_RestartGame()
{
	char sPopFile[256];
	GetPopFileName(sPopFile, sizeof(sPopFile));

	ServerCommand("tf_mvm_popfile %s", sPopFile);
}

public Action Timer_RestartMvMGame(Handle timer, any data)
{
	MvM_RestartGame();
}

public void SendUniqueEventToEngaged(const char[] event, int add)
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientEngaged(i))continue;
		
		CEcon_SendEventToClientUnique(i, event, add);
	}
}
