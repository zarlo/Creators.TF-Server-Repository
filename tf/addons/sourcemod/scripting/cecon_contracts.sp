//============= Copyright Amper Software, All rights reserved. ============//
//
// Purpose: Contracts handler for Creators.TF Economy.
//
//=========================================================================//

#include <steamtools>

#pragma semicolon 1
#pragma tabsize 0
#pragma newdecls required

#include <cecon_http>
#include <cecon_items>
#include <cecon>
#include <tf2>
#include <tf2_stocks>
#include <tf_econ_data>
#include <clientprefs>
#include <cecon_contracts>

#define TF_MAXPLAYERS 34

#define QUEST_HUD_REFRESH_RATE 0.5
#define QUEST_PANEL_MAX_CHARS 30
#define BACKEND_QUEST_UPDATE_INTERVAL 20.0 // Every 20 seconds.
#define BACKEND_QUEST_UPDATE_LIMIT 10 // Dont allow more than 10 quests to be updated at the same time.

#define CHAR_FULL "█"
#define CHAR_PROGRESS "▓"
#define CHAR_EMPTY "▒"

public Plugin myinfo =
{
	name = "Creators.TF Economy - Contracts Handler",
	author = "Creators.TF Team",
	description = "Creators.TF Economy Contracts Handler",
	version = "1.0",
	url = "https://creators.tf"
}

ArrayList m_hQuestDefinitions;
ArrayList m_hObjectiveDefinitions;
ArrayList m_hHooksDefinitions;
ArrayList m_hBackgroundQuests;

ArrayList m_hFriends[MAXPLAYERS + 1];
ArrayList m_hProgress[MAXPLAYERS + 1];

char m_sPlayerSteamID64[TF_MAXPLAYERS][22];

bool m_bWaitingForFriends[MAXPLAYERS + 1];
bool m_bWaitingForProgress[MAXPLAYERS + 1];

CEQuestDefinition m_xActiveQuestStruct[MAXPLAYERS + 1];

int m_iLastUniqueEvent[MAXPLAYERS + 1];
bool m_bIsObjectiveMarked[MAXPLAYERS + 1][MAX_OBJECTIVES + 1];

ConVar ce_quest_friend_sharing_enabled;
ConVar ce_quest_background_enabled;
ConVar ce_quest_debug;

public void OnPluginStart()
{
	RegServerCmd("ce_quest_dump", cDump, "");
	RegServerCmd("ce_quest_activate", cQuestActivate, "");

	RegConsoleCmd("sm_q", cQuestPanel);
	RegConsoleCmd("sm_quest", cQuestPanel);
	RegConsoleCmd("sm_contract", cQuestPanel);
	
	//ce_contracts_log = CreateConVar("ce_contracts_log", "0");
	//ce_contracts_log_contract_filter = CreateConVar("ce_contracts_log_contract_filter", "");

	CreateTimer(QUEST_HUD_REFRESH_RATE, Timer_HudRefresh, _, TIMER_REPEAT);
	CreateTimer(BACKEND_QUEST_UPDATE_INTERVAL, Timer_QuestUpdateInterval, _, TIMER_REPEAT);

	HookEvent("teamplay_round_win", teamplay_round_win);

	ce_quest_friend_sharing_enabled = CreateConVar("ce_quest_friend_sharing_enabled", "1", "Enabled \"Friendly Fire\" feature, that allows to share progress with friends.");
	ce_quest_background_enabled = CreateConVar("ce_quest_background_enabled", "1", "Enable background quests to track themselves.");
	ce_quest_debug = CreateConVar("ce_quest_debug", "0", "Debug quests.");

}

public Action cQuestPanel(int client, int args)
{
	ClientShowQuestPanel(client);
	return Plugin_Handled;
}

public void ClientShowQuestPanel(int client)
{
	CEQuestDefinition xQuest;
	if(GetClientActiveQuest(client, xQuest))
	{
		Menu hMenu = new Menu(mQuestMenu);
		char sQuest[128];

		CEQuestClientProgress xProgress;
		GetClientQuestProgress(client, xQuest, xProgress);

		CEQuestObjectiveDefinition xPrimary;
		GetQuestObjectiveByIndex(xQuest, 0, xPrimary);

		Format(sQuest, sizeof(sQuest), "%s [%d/%d]\n ", xQuest.m_sName, xProgress.m_iProgress[0], xPrimary.m_iLimit);
		hMenu.SetTitle(sQuest);

		for (int i = 0; i < xQuest.m_iObjectivesCount; i++)
		{
			CEQuestObjectiveDefinition xObjective;
			GetQuestObjectiveByIndex(xQuest, i, xObjective);

			char sItem[512];

			int iLimit = xObjective.m_iLimit;
			int iPoints = xObjective.m_iPoints;
			int iProgress = xProgress.m_iProgress[i];

			Format(sItem, sizeof(sItem), "%s: %d%s", xObjective.m_sName, iPoints, xQuest.m_sPostfix);

			if(i > 0 && iLimit > 0)
			{
				Format(sItem, sizeof(sItem), "[%d/%d] %s", iProgress, iLimit, sItem);
			}

			if(i == 0)
			{
				char sProgress[128];
				int iFilled = RoundToCeil(float(iProgress) / float(iLimit) * QUEST_PANEL_MAX_CHARS);

				for (int j = 1; j <= QUEST_PANEL_MAX_CHARS; j++)
				{
					if (j <= iFilled)
					{
						StrCat(sProgress, sizeof(sProgress), CHAR_FULL);
					} else if(j == iFilled + 1 && iFilled > 0)
					{
						StrCat(sProgress, sizeof(sProgress), CHAR_PROGRESS);

					} else {
						StrCat(sProgress, sizeof(sProgress), CHAR_EMPTY);
					}
				}

				Format(sItem, sizeof(sItem), "%s\n%s\n ", sItem, sProgress, iProgress, iLimit);
			}

			hMenu.AddItem("", sItem);
		}

		hMenu.ExitButton = true;
		hMenu.Display(client, 60);

		delete hMenu;
	} else {
		PrintToChat(client, "\x01Go to \x03Creators.TF\x01 website and select a contract you want to complete in \x03Contracker \x01tab.");
	}
}

public int mQuestMenu(Menu menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_End)
	{
		delete menu;
	}
}

public Action cQuestActivate(int args)
{
	char sArg1[MAX_NAME_LENGTH], sArg2[11];
	GetCmdArg(1, sArg1, sizeof(sArg1));
	GetCmdArg(2, sArg2, sizeof(sArg2));

	int iTarget = FindTargetBySteamID64(sArg1);
	if (!IsClientValid(iTarget))return Plugin_Handled;

	int iQuest = StringToInt(sArg2);

	SetClientActiveQuestByIndex(iTarget, iQuest);
	return Plugin_Handled;
}

public void OnAllPluginsLoaded()
{
	ParseEconomyConfig(CEcon_GetEconomySchema());
	OnLateLoad();
}

public void OnMapStart()
{
	ParseEconomyConfig(CEcon_GetEconomySchema());
	OnLateLoad();
}

public void CEcon_OnSchemaUpdated(KeyValues hSchema)
{
	ParseEconomyConfig(hSchema);
}

int GetWeaponSlotFromName(const char [] slot)
{
	if (StrEqual(slot, "primary"))
	{
		return TFWeaponSlot_Primary;
	}
	
	else if (StrEqual(slot, "secondary"))
	{
		return TFWeaponSlot_Secondary;
	}
	
	else if (StrEqual(slot, "melee"))
	{
		return TFWeaponSlot_Melee;
	}
	
	else if (StrEqual(slot, "grenade"))
	{
		return TFWeaponSlot_Grenade;
	}
	
	else if (StrEqual(slot, "building"))
	{
		return TFWeaponSlot_Building;
	}
	
	else if (StrEqual(slot, "pda"))
	{
		return TFWeaponSlot_PDA;
	}

	else {
		return -1;
	}
}

public void ParseEconomyConfig(KeyValues kv)
{
	FlushQuestDefinitions();
	m_hQuestDefinitions = 		new ArrayList(sizeof(CEQuestDefinition));
	m_hObjectiveDefinitions = 	new ArrayList(sizeof(CEQuestObjectiveDefinition));
	m_hHooksDefinitions = 		new ArrayList(sizeof(CEQuestObjectiveHookDefinition));
	m_hBackgroundQuests = 		new ArrayList();

	if (kv == null)return;

	if(kv.JumpToKey("Contracker/Quests", false))
	{
		if(kv.GotoFirstSubKey())
		{
			do {
				int iQuestWorldIndex = m_hQuestDefinitions.Length;

				char sSectionName[11];
				kv.GetSectionName(sSectionName, sizeof(sSectionName));

				CEQuestDefinition xQuest;
				xQuest.m_iIndex = StringToInt(sSectionName);

				xQuest.m_bBackground = kv.GetNum("background", 0) == 1;
				xQuest.m_bDisableEventSharing = kv.GetNum("send_friends", 1) == 1;

				if(xQuest.m_bBackground)
				{
					m_hBackgroundQuests.Push(iQuestWorldIndex);
				}

				kv.GetString("name", xQuest.m_sName, sizeof(xQuest.m_sName));
				kv.GetString("postfix", xQuest.m_sPostfix, sizeof(xQuest.m_sPostfix), "CP");

				// Map Restrictions
				kv.GetString("restrictions/map", xQuest.m_sRestrictedToMap, sizeof(xQuest.m_sRestrictedToMap));
				kv.GetString("restrictions/map_s", xQuest.m_sStrictRestrictedToMap, sizeof(xQuest.m_sStrictRestrictedToMap));

				// Weapon Restriction
				kv.GetString("restrictions/weapon", xQuest.m_sRestrictedToItemName, sizeof(xQuest.m_sRestrictedToItemName));
				kv.GetString("restrictions/weapon_classname", xQuest.m_sRestrictedToClassname, sizeof(xQuest.m_sRestrictedToClassname));

				// Weapon Slot Restriction
				char sRestrictedToWeaponSlot[64];
				kv.GetString("restrictions/weapon_slot", sRestrictedToWeaponSlot, sizeof(sRestrictedToWeaponSlot));
				xQuest.m_nRestrictedToWeaponSlot = GetWeaponSlotFromName(sRestrictedToWeaponSlot);

				// Item Classname Restriction
				kv.GetString("restrictions/item_classname", xQuest.m_sRestrictedToItemClassname, sizeof(xQuest.m_sRestrictedToItemClassname));
				kv.GetString("restrictions/item", xQuest.m_sRestrictedToItemItemName, sizeof(xQuest.m_sRestrictedToItemItemName));

				// TF2 Class Restriction
				char sTFClassName[64];
				kv.GetString("restrictions/class", sTFClassName, sizeof(sTFClassName));
				xQuest.m_nRestrictedToClass = TF2_GetClass(sTFClassName);

				if(kv.JumpToKey("objectives", false))
				{
					if(kv.GotoFirstSubKey())
					{
						do {
							int iObjectiveLocalIndex = xQuest.m_iObjectivesCount;
							int iObjectiveWorldIndex = m_hObjectiveDefinitions.Length;
							xQuest.m_Objectives[iObjectiveLocalIndex] = iObjectiveWorldIndex;
							xQuest.m_iObjectivesCount++;

							CEQuestObjectiveDefinition xObjective;
							xObjective.m_iIndex = iObjectiveLocalIndex;
							xObjective.m_iQuestIndex = iQuestWorldIndex;

							kv.GetString("name", xObjective.m_sName, sizeof(xObjective.m_sName));

							xObjective.m_iLimit = kv.GetNum("limit", 100);
							xObjective.m_iPoints = kv.GetNum("points", 0);
							xObjective.m_iEnd = kv.GetNum("end", 0);

							// Weapon Restriction
							kv.GetString("restrictions/weapon", xObjective.m_sRestrictedToItemName, sizeof(xObjective.m_sRestrictedToItemName));
							kv.GetString("restrictions/weapon_classname", xObjective.m_sRestrictedToClassname, sizeof(xObjective.m_sRestrictedToClassname));

							// Weapon Slot Restriction
							kv.GetString("restrictions/weapon_slot", sRestrictedToWeaponSlot, sizeof(sRestrictedToWeaponSlot));
							xObjective.m_nRestrictedToWeaponSlot = GetWeaponSlotFromName(sRestrictedToWeaponSlot);

							// Item Restriction
							kv.GetString("restrictions/item_classname", xObjective.m_sRestrictedToItemClassname, sizeof(xObjective.m_sRestrictedToItemClassname));
							kv.GetString("restrictions/item", xQuest.m_sRestrictedToItemItemName, sizeof(xQuest.m_sRestrictedToItemItemName));

							if(kv.JumpToKey("hooks", false))
							{
								if(kv.GotoFirstSubKey())
								{
									do {

										int iHookLocalIndex = xObjective.m_iHooksCount;
										int iHookWorldIndex = m_hHooksDefinitions.Length;
										xObjective.m_Hooks[iHookLocalIndex] = iHookWorldIndex;
										xObjective.m_iHooksCount++;

										char sAction[16];
										kv.GetString("action", sAction, sizeof(sAction));

										CEQuestActions nAction;
										if (StrEqual(sAction, "increment"))nAction = CEQuestAction_Increment;
										else if (StrEqual(sAction, "reset"))nAction = CEQuestAction_Reset;
										else if (StrEqual(sAction, "subtract"))nAction = CEQuestAction_Subtract;
										else if (StrEqual(sAction, "set"))nAction = CEQuestAction_Set;
										else nAction = CEQuestAction_Singlefire;

										CEQuestObjectiveHookDefinition xHook;
										xHook.m_iIndex = iHookLocalIndex;
										xHook.m_iObjectiveIndex = iObjectiveWorldIndex;
										xHook.m_iQuestIndex = iQuestWorldIndex;
										xHook.m_Action = nAction;
										xHook.m_flDelay = kv.GetFloat("delay", 0.0);
										xHook.m_flSubtractIn = kv.GetFloat("subtract_in", 0.0);

										kv.GetString("event", xHook.m_sEvent, sizeof(xHook.m_sEvent));

										char sEvent[64];
										Format(sEvent, sizeof(sEvent), "%s;", xHook.m_sEvent);

										if(StrContains(xQuest.m_sAggregatedEvents, sEvent) == -1)
										{
											Format(xQuest.m_sAggregatedEvents, sizeof(xQuest.m_sAggregatedEvents), "%s%s", xQuest.m_sAggregatedEvents, sEvent);
										}

										m_hHooksDefinitions.PushArray(xHook);

									} while (kv.GotoNextKey());
									kv.GoBack();
								}
								kv.GoBack();
							}

							m_hObjectiveDefinitions.PushArray(xObjective);

						} while (kv.GotoNextKey());
						kv.GoBack();
					}
					kv.GoBack();
				}

				m_hQuestDefinitions.PushArray(xQuest);

			} while (kv.GotoNextKey());
		}
	}
	kv.Rewind();
}

public Action cDump(int args)
{
	LogMessage("Dumping precached data");

	char name[128];
	
	GetCmdArg(1, name, 128);

	for (int i = 0; i < m_hQuestDefinitions.Length; i++)
	{

		CEQuestDefinition xQuest;
		GetQuestByIndex(i, xQuest);
		
		if (!StrEqual(xQuest.m_sName, name))
			continue;

		LogMessage("CEQuestDefinition");
		LogMessage("{");
		LogMessage("  m_iIndex = %d", xQuest.m_iIndex);
		LogMessage("  m_sName = %d", xQuest.m_sName);
		LogMessage("  m_bBackground = %d", xQuest.m_bBackground);
		LogMessage("  m_iObjectivesCount = %d", xQuest.m_iObjectivesCount);
		LogMessage("  m_sRestrictedToMap = \"%s\"", xQuest.m_sRestrictedToMap);
		LogMessage("  m_sStrictRestrictedToMap = \"%s\"", xQuest.m_sStrictRestrictedToMap);
		LogMessage("  m_sAggregatedEvents = \"%s\"", xQuest.m_sAggregatedEvents );
		LogMessage("  m_nRestrictedToClass = %d", xQuest.m_nRestrictedToClass);
		LogMessage("  m_sRestrictedToItemName = \"%s\"", xQuest.m_sRestrictedToItemName);
		LogMessage("  m_sRestrictedToClassname = \"%s\"", xQuest.m_sRestrictedToClassname);
		LogMessage("  m_nRestrictedToWeaponSlot = \"%d\"", xQuest.m_nRestrictedToWeaponSlot);
		LogMessage("  m_sRestrictedToItemClassname = \"%s\"", xQuest.m_sRestrictedToItemClassname);
		LogMessage("  m_Objectives =");
		LogMessage("  [");

		for (int j = 0; j < xQuest.m_iObjectivesCount; j++)
		{
			CEQuestObjectiveDefinition xObjective;
			if(GetQuestObjectiveByIndex(xQuest, j, xObjective))
			{
				LogMessage("    %d => CEQuestObjectiveDefinition", j);
				LogMessage("    {");
				LogMessage("      m_iIndex = %d", xObjective.m_iIndex);
				LogMessage("      m_iQuestIndex = %d", xObjective.m_iQuestIndex);
				LogMessage("      m_sName = \"%s\"", xObjective.m_sName);
				LogMessage("      m_iPoints = %d", xObjective.m_iPoints);
				LogMessage("      m_iLimit = %d", xObjective.m_iLimit);
				LogMessage("      m_iEnd = %d", xObjective.m_iEnd);
				LogMessage("      m_iHooksCount = %d", xObjective.m_iHooksCount);
				LogMessage("      m_sRestrictedToItemName = \"%s\"", xObjective.m_sRestrictedToItemName);
				LogMessage("      m_sRestrictedToClassname = \"%s\"", xObjective.m_sRestrictedToClassname);
				LogMessage("      m_nRestrictedToWeaponSlot = \"%d\"", xObjective.m_nRestrictedToWeaponSlot);
				LogMessage("      m_sRestrictedToItemClassname = \"%s\"", xObjective.m_sRestrictedToItemClassname);
				LogMessage("      m_Hooks =");
				LogMessage("      [");

				for (int k = 0; k < xObjective.m_iHooksCount; k++)
				{
					CEQuestObjectiveHookDefinition xHook;
					if(GetObjectiveHookByIndex(xObjective, k, xHook))
					{
						LogMessage("        %d => CEQuestObjectiveHookDefinition", k);
						LogMessage("        {");
						LogMessage("          m_iIndex = %d", xHook.m_iIndex);
						LogMessage("          m_iObjectiveIndex = %d", xHook.m_iObjectiveIndex);
						LogMessage("          m_iQuestIndex = %d", xHook.m_iQuestIndex);
						LogMessage("          m_flDelay = %f", xHook.m_flDelay);
						LogMessage("          m_flSubtractIn = %f", xHook.m_flSubtractIn);

						LogMessage("          m_sEvent = \"%s\"", xHook.m_sEvent);
						LogMessage("          m_Action = %d", xHook.m_Action);
						LogMessage("        }");
					}
				}
				LogMessage("      ]");
				LogMessage("    }");
			}
		}

		LogMessage("  ]");
		LogMessage("}");

	}

	LogMessage("");
	LogMessage("CEQuestDefinition Count: %d", m_hQuestDefinitions.Length);
	LogMessage("CEQuestObjectiveDefinition Count: %d", m_hObjectiveDefinitions.Length);
	LogMessage("CEQuestObjectiveHookDefinition Count: %d", m_hHooksDefinitions.Length);
}

public void FlushQuestDefinitions()
{
	delete m_hQuestDefinitions;
	delete m_hObjectiveDefinitions;
	delete m_hHooksDefinitions;
	delete m_hBackgroundQuests;
}

public bool GetQuestByIndex(int index, CEQuestDefinition xStruct)
{
	if (m_hQuestDefinitions == null)return false;
	if (index >= m_hQuestDefinitions.Length)return false;
	if (index < 0)return false;

	m_hQuestDefinitions.GetArray(index, xStruct);
	return true;
}

public bool GetObjectiveByIndex(int index, CEQuestObjectiveDefinition xStruct)
{
	if (m_hObjectiveDefinitions == null)return false;
	if (index >= m_hObjectiveDefinitions.Length)return false;
	if (index < 0)return false;

	m_hObjectiveDefinitions.GetArray(index, xStruct);
	return true;
}

public bool GetHookByIndex(int index, CEQuestObjectiveHookDefinition xStruct)
{
	if (m_hHooksDefinitions == null)return false;
	if (index >= m_hHooksDefinitions.Length)return false;
	if (index < 0)return false;

	m_hHooksDefinitions.GetArray(index, xStruct);
	return true;
}

public bool GetQuestObjectiveByIndex(CEQuestDefinition xQuest, int index, CEQuestObjectiveDefinition xStruct)
{
	if (index < 0)return false;

	if (index >= xQuest.m_iObjectivesCount)return false;
	int iWorldIndex = xQuest.m_Objectives[index];

	GetObjectiveByIndex(iWorldIndex, xStruct);
	return true;
}

public bool GetObjectiveHookByIndex(CEQuestObjectiveDefinition xObjective, int index, CEQuestObjectiveHookDefinition xStruct)
{
	if (index < 0)return false;

	if (index >= xObjective.m_iHooksCount)return false;
	int iWorldIndex = xObjective.m_Hooks[index];

	GetHookByIndex(iWorldIndex, xStruct);
	return true;
}

public bool GetQuestByDefIndex(int defid, CEQuestDefinition xBuffer)
{
	if (m_hQuestDefinitions == null)return false;

	for (int i = 0; i < m_hQuestDefinitions.Length; i++)
	{
		CEQuestDefinition xStruct;
		m_hQuestDefinitions.GetArray(i, xStruct);

		if(xStruct.m_iIndex == defid)
		{
			xBuffer = xStruct;
			return true;
		}
	}

	return false;
}

public bool GetQuestByObjective(CEQuestObjectiveDefinition xObjective, CEQuestDefinition xBuffer)
{
	return GetQuestByIndex(xObjective.m_iQuestIndex, xBuffer);
}

public bool GetObjectiveByHook(CEQuestObjectiveHookDefinition xHook, CEQuestObjectiveDefinition xBuffer)
{
	return GetObjectiveByIndex(xHook.m_iObjectiveIndex, xBuffer);
}

public void RequestClientSteamFriends(int client)
{
	if (!IsClientReady(client))return;
	if (m_bWaitingForFriends[client])return;

	char sSteamID64[64];
	GetClientAuthId(client, AuthId_SteamID64, sSteamID64, sizeof(sSteamID64));

	HTTPRequestHandle httpRequest = CEconHTTP_CreateBaseHTTPRequest("/api/ISteamInterface/GUserFriends", HTTPMethod_GET);
	Steam_SetHTTPRequestGetOrPostParameter(httpRequest, "steamid", sSteamID64);

	Steam_SendHTTPRequest(httpRequest, RequestClientSteamFriends_Callback, client);
	return;
}

public void RequestClientSteamFriends_Callback(HTTPRequestHandle request, bool success, HTTPStatusCode code, any client)
{
	// We are not processing bots.
	if (!IsClientReady(client))return;

	// If request was not succesful, return.
	if (!success)return;
	if (code != HTTPStatusCode_OK)return;

	// Getting response size.
	int size = Steam_GetHTTPResponseBodySize(request);
	char[] content = new char[size + 1];

	// Getting actual response content body.
	Steam_GetHTTPResponseBodyData(request, content, size);
	Steam_ReleaseHTTPRequest(request);

	KeyValues Response = new KeyValues("Response");

	// ======================== //
	// Parsing loadout response.

	// If we fail to import content return.
	if (!Response.ImportFromString(content))return;

	delete m_hFriends[client];
	m_hFriends[client] = new ArrayList(ByteCountToCells(64));

	if(Response.JumpToKey("friends"))
	{
		if(Response.GotoFirstSubKey(false))
		{
			do {

				char sSteamID[64];
				Response.GetString(NULL_STRING, sSteamID, sizeof(sSteamID));
				m_hFriends[client].PushString(sSteamID);

			} while (Response.GotoNextKey(false));
		}
	}

	// Make a Callback.

	delete Response;
}

public void RequestClientContractProgress(int client)
{
	if (!IsClientReady(client))return;
	if (m_bWaitingForProgress[client])return;

	char sSteamID64[64];
	GetClientAuthId(client, AuthId_SteamID64, sSteamID64, sizeof(sSteamID64));

	HTTPRequestHandle httpRequest = CEconHTTP_CreateBaseHTTPRequest("/api/IEconomySDK/UserQuests", HTTPMethod_GET);
	Steam_SetHTTPRequestGetOrPostParameter(httpRequest, "get", "progress");
	Steam_SetHTTPRequestGetOrPostParameter(httpRequest, "steamid", sSteamID64);

	Steam_SendHTTPRequest(httpRequest, RequestClientContractProgress_Callback, client);
	
	if (ce_quest_debug.BoolValue) PrintToServer("Sent Progress Request for %N", client);
	return;
}

public void RequestClientContractProgress_Callback(HTTPRequestHandle request, bool success, HTTPStatusCode code, any client)
{
	// PrintToChatAll("RequestClientContractProgress_Callback() %d", code);
	// We are not processing bots.
	if (!IsClientReady(client))return;
	if (ce_quest_debug.BoolValue) PrintToServer("Client ready: %N", client);

	// If request was not succesful, return.
	if (!success)return;
	if (ce_quest_debug.BoolValue) PrintToServer("Success: %N", client);
	if (code != HTTPStatusCode_OK)return;
	if (ce_quest_debug.BoolValue) PrintToServer("HTTPStatusCode_OK: %N", client);

	// Getting response size.
	int size = Steam_GetHTTPResponseBodySize(request);
	if(size < 0)return;
	if (ce_quest_debug.BoolValue) PrintToServer("Size > 0: %N", client);

	char[] content = new char[size + 1];

	// Getting actual response content body.
	Steam_GetHTTPResponseBodyData(request, content, size);
	Steam_ReleaseHTTPRequest(request);

	KeyValues Response = new KeyValues("Response");

	// ======================== //
	// Parsing loadout response.

	// If we fail to import content return.
	if (!Response.ImportFromString(content))return;
	if (ce_quest_debug.BoolValue) PrintToServer("Passed import for %N", client);

	delete m_hProgress[client];
	m_hProgress[client] = new ArrayList(sizeof(CEQuestClientProgress));

	int iActive = Response.GetNum("activated");

	if(Response.JumpToKey("progress"))
	{
		if(Response.GotoFirstSubKey())
		{
			do {

				char sSectionName[11];
				Response.GetSectionName(sSectionName, sizeof(sSectionName));

				int iIndex = StringToInt(sSectionName);

				CEQuestClientProgress xProgress;
				xProgress.m_iClient = client;
				xProgress.m_iQuest = iIndex;

				if(Response.GotoFirstSubKey(false))
				{
					do {

						Response.GetSectionName(sSectionName, sizeof(sSectionName));
						iIndex = StringToInt(sSectionName);

						if (iIndex < 0 || iIndex >= MAX_OBJECTIVES)continue;
						xProgress.m_iProgress[iIndex] = Response.GetNum(NULL_STRING);

					} while (Response.GotoNextKey(false));

					Response.GoBack();
				}

				UpdateClientQuestProgress(client, xProgress);

			} while (Response.GotoNextKey());
		}
	}

	SetClientActiveQuestByIndex(client, iActive);

	// TODO: Make a forward call.

	delete Response;
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

public void OnLateLoad()
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientReady(i))continue;

		PrepareClientData(i);
	}
}

public void OnClientPostAdminCheck(int client)
{
	FlushClientData(client);
	PrepareClientData(client);
}

public void OnClientDisconnect(int client)
{
	FlushClientData(client);
}

public void PrepareClientData(int client)
{
	if (ce_quest_debug.BoolValue) PrintToServer("PrepareClientData %N", client);
	if (!IsFakeClient(client))
	{
		GetClientAuthId(client, AuthId_SteamID64, m_sPlayerSteamID64[client], sizeof(m_sPlayerSteamID64[]));
	}
	
	RequestClientSteamFriends(client);
	RequestClientContractProgress(client);
}

public void FlushClientData(int client)
{
	delete m_hFriends[client];
	delete m_hProgress[client];

	m_bWaitingForProgress[client] = false;
	m_bWaitingForFriends[client] = false;

	m_xActiveQuestStruct[client].m_iIndex = 0;
	m_iLastUniqueEvent[client] = 0;

	m_sPlayerSteamID64[client] = "";
}

public void UpdateClientQuestProgress(int client, CEQuestClientProgress xProgress)
{
	if(m_hProgress[client] == null)
	{
		m_hProgress[client] = new ArrayList(sizeof(CEQuestClientProgress));
	}

	for (int i = 0; i < m_hProgress[client].Length; i++)
	{
		CEQuestClientProgress xStruct;
		m_hProgress[client].GetArray(i, xStruct);

		if(xStruct.m_iQuest == xProgress.m_iQuest)
		{
			m_hProgress[client].Erase(i);
			i--;
		}
	}

	m_hProgress[client].PushArray(xProgress);
}

public bool GetClientQuestProgress(int client, CEQuestDefinition xQuest, CEQuestClientProgress xBuffer)
{
	xBuffer.m_iClient = client;
	xBuffer.m_iQuest = xQuest.m_iIndex;

	if (m_hProgress[client] == null)return false;

	for (int i = 0; i < m_hProgress[client].Length; i++)
	{
		CEQuestClientProgress xStruct;
		m_hProgress[client].GetArray(i, xStruct);

		if(xStruct.m_iQuest == xQuest.m_iIndex)
		{
			xBuffer = xStruct;
			return true;
		}
	}

	return false;
}

public bool IsClientProgressLoaded(int client)
{
	return m_hProgress[client] != null;
}

public void SetClientActiveQuestByIndex(int client, int quest)
{
	// We can't change contract if we didn't load progress yet.
	if (!IsClientProgressLoaded(client))return;
	if (ce_quest_debug.BoolValue) PrintToServer("Client Progress was loaded: %N", client);
	// We don't reactivate the quest if it's already active.
	if (m_xActiveQuestStruct[client].m_iIndex == quest)return;
	if (ce_quest_debug.BoolValue) PrintToServer("Contract wasn't a reactivate: %N", client);

	if(quest == 0)
	{
		m_xActiveQuestStruct[client].m_iIndex = 0;
		if (ce_quest_debug.BoolValue) PrintToServer("quest == 0: %N", client);
	} else {
		CEQuestDefinition xQuest;
		if (ce_quest_debug.BoolValue) PrintToServer("quest != 0: %N", client);
		if(GetQuestByDefIndex(quest, xQuest))
		{
			if (ce_quest_debug.BoolValue) PrintToServer("GotQuestByDefIndex: %N", client);
			// We can't activate background quests.
			if (xQuest.m_bBackground)return;
			if (ce_quest_debug.BoolValue) PrintToServer("Contract wasn't a background quest: %N", client);

			m_xActiveQuestStruct[client] = xQuest;

			// Print a warning saying that normal contracts on MVM won't register.
			if (GameRules_GetProp("m_bPlayingMannVsMachine") != 0 && !IsQuestActive(xQuest))
			{
				PrintToChat(client, "\x05WARNING:\x03 Normal Creators.TF Contracts will \x05not\x03 work on \x05Mann vs Machine\x03 servers.");
				PrintToChat(client, "\x03To complete them, you can join a \x05Creators.TF Pub\x03 server at \x05creators.tf/servers/creatorstf");
			}
			else
			{
				PrintToChat(client, "\x03You have activated '\x05%s\x03' contract. Type \x05!quest \x03or \x05!contract \x03to view current completion progress.", xQuest.m_sName);
				PrintToChat(client, "\x03You can change your contract on \x05creators.tf \x03in \x05ConTracker \x03tab.");
			}
			

			char sDecodeSound[64];
			strcopy(sDecodeSound, sizeof(sDecodeSound), "Quest.Decode");
			if(StrEqual(xQuest.m_sPostfix, "MP"))
			{
				Format(sDecodeSound, sizeof(sDecodeSound), "%sHalloween", sDecodeSound);
			}

			ClientCommand(client, "playgamesound %s", sDecodeSound);
		}
	}
}

public bool GetClientActiveQuest(int client, CEQuestDefinition xBuffer)
{
	if (!IsClientReady(client))return false;
	if (m_xActiveQuestStruct[client].m_iIndex <= 0)return false;

	xBuffer = m_xActiveQuestStruct[client];
	return true;
}

public bool IsQuestActive(CEQuestDefinition xQuest)
{
	// Checking what is the current map.
	char sMap[64];
	GetCurrentMap(sMap, sizeof(sMap));
	if (StrContains(sMap, "workshop") != -1)
	{
		GetMapDisplayName(sMap, sMap, sizeof sMap);
	}

	if (!StrEqual(xQuest.m_sRestrictedToMap, "") && StrContains(sMap, xQuest.m_sRestrictedToMap) == -1)return false;
	if (!StrEqual(xQuest.m_sStrictRestrictedToMap, "") && !StrEqual(xQuest.m_sStrictRestrictedToMap, sMap))return false;

	// If we're in MvM, we're only counting background contracts.
	if (GameRules_GetProp("m_bPlayingMannVsMachine") != 0)
	{
		if (!xQuest.m_bBackground)return false;
	}

	return true;
}

public Action Timer_HudRefresh(Handle timer, any data)
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientReady(i))continue;

		CEQuestDefinition xQuest;
		if(GetClientActiveQuest(i, xQuest))
		{
			CEQuestClientProgress xProgress;
			GetClientQuestProgress(i, xQuest, xProgress);

			char sText[256];
			Format(sText, sizeof(sText), "%s: \n", xQuest.m_sName);

			if(IsQuestActive(xQuest))
			{
				for (int j = 0; j < xQuest.m_iObjectivesCount; j++)
				{
					CEQuestObjectiveDefinition xObjective;
					if(GetQuestObjectiveByIndex(xQuest, j, xObjective))
					{
						int iLimit = xObjective.m_iLimit;
						int iProgress = xProgress.m_iProgress[j];

						if(j == 0)
						{
							Format(sText, sizeof(sText), "%s%d/%d%s \n", sText, iProgress, iLimit, xQuest.m_sPostfix);
						} else {
							if (iLimit == 0)continue;
							Format(sText, sizeof(sText), "%s[%d/%d] ", sText, iProgress, iLimit);
						}
					}
				}
			} else {
				Format(sText, sizeof(sText), "%s- Inactive - ", sText);
			}

			bool bByMe = xProgress.m_iSource == i;
			bool bByFriend = !bByMe && IsClientValid(xProgress.m_iSource);

			if(bByFriend)
			{
				Format(sText, sizeof(sText), "%s\n%N ", sText, xProgress.m_iSource);
				SetHudTextParams(1.0, -1.0, QUEST_HUD_REFRESH_RATE + 0.1, 50, 200, 50, 255);

			} else {

				if(bByMe)
				{
					SetHudTextParams(1.0, -1.0, QUEST_HUD_REFRESH_RATE + 0.1, 255, 200, 50, 255);
				} else {
					SetHudTextParams(1.0, -1.0, QUEST_HUD_REFRESH_RATE + 0.1, 255, 255, 255, 255);
				}
				Format(sText, sizeof(sText), "%s\n", sText);
			}

			ShowHudText(i, -1, sText);

			if (xProgress.m_iSource > 0)
			{
				xProgress.m_iSource = 0;
				UpdateClientQuestProgress(i, xProgress);
			}
		}
	}
}

public bool IsCorrectClass(int client, TFClassType tfClass)
{
	//------------------------------------------------
	// TF2 Player Class restriction.
	if (tfClass != TFClass_Unknown)
	{
		if(TF2_GetPlayerClass(client) == tfClass)
		{
			return true;
		}
		else
		{
			return false;
		}
	}
	else
	{
		return true;
	}
	
}

public bool IsCorrectWeaponSlot(int client, int nWeaponSlotRestriction)
{
	int iLastWeapon = CEcon_GetLastUsedWeapon(client);

	//------------------------------------------------
	// Checking wepaon slot.
	// This quest is restricted to a certain weapon slot.
	if(nWeaponSlotRestriction != -1)
	{
		// If entity does not exist, return false.
		if (!IsValidEntity(iLastWeapon))return false;

		if (GetPlayerWeaponSlot(client, nWeaponSlotRestriction) == iLastWeapon) {
			return true;
		}
		return false;
	}
	else
	{
		return true;
	}
	
}

public bool IsCorrectWeaponItemIndexName(int client, const char[] sWeaponIndexNameRestriction)
{
	int iLastWeapon = CEcon_GetLastUsedWeapon(client);
	
	//------------------------------------------------
	// Item Name restriction.
	// This quest is restricted to a specific item, check by name.
	if(!StrEqual(sWeaponIndexNameRestriction, ""))
	{
		// We are 100% sure that if we expect an item name, and target
		// entity is not valid, we need to return false.
		if (!IsValidEntity(iLastWeapon)) return false;

		// Check if this entity was created by custom economy.
		if (CEconItems_IsEntityCustomEconItem(iLastWeapon))
		{
			// Getting entity item struct.
			CEItem xItem;
			if(CEconItems_GetEntityItemStruct(iLastWeapon, xItem))
			{
				// Getting item definition of this item.
				CEItemDefinition xDef;
				if(CEconItems_GetItemDefinitionByIndex(xItem.m_iItemDefinitionIndex, xDef))
				{
					// Comparing expected name with what definition has.
					if (StrEqual(xDef.m_sName, sWeaponIndexNameRestriction))
					{
						// If they match, this check has passed.
						return true;
					}
				}
				return false;
			}
		} else {
			// If this is not a custom econ item, check native TF2 item name.
			int iDefIndex = GetEntProp(iLastWeapon, Prop_Send, "m_iItemDefinitionIndex");

			// Getting item schema name.
			char sName[64];
			if(TF2Econ_GetItemName(iDefIndex, sName, sizeof(sName)))
			{
				// Comparing schema name and expected name.
				if (StrEqual(sName, sWeaponIndexNameRestriction))
				{
					// If match, this check has passed.
					return true;
				}
			}
		}
		return false;
	}
	else
	{
		return true;
	}
}

public bool IsCorrectWeaponClassname(int client, const char[] sWeaponClassname)
{
	int iLastWeapon = CEcon_GetLastUsedWeapon(client);
	
	//------------------------------------------------
	// Checking entity classname.

	// This quest is restricted to a specific class name.
	if(!StrEqual(sWeaponClassname, ""))
	{
		// If entity does not exist, return false.
		if (!IsValidEntity(iLastWeapon))return false;

		// Allow up to 4 classnames delimeted by commas
		char buffers[4][64];
		ExplodeString(sWeaponClassname, ",", buffers, 4, 64);
		
		char sClassname[64];
		GetEntityClassname(iLastWeapon, sClassname, sizeof(sClassname));

		for (int i = 0; i < 4; i++) {
			if(StrEqual(sClassname, buffers[i]))
			{
				return true;
			}
		}
		return false;
	}
	else
	{
		return true;
	}
}

public bool IsCorrectItemClassname(int client, const char[] sItemClassname)
{
	//------------------------------------------------
	// Checking entity classname.

	// This quest is restricted to a specific class name.
	if(!StrEqual(sItemClassname, ""))
	{
		int next = GetEntPropEnt(client, Prop_Data, "m_hMoveChild");
		while (next != -1)
		{
			int iEdict = next;
			next = GetEntPropEnt(iEdict, Prop_Data, "m_hMovePeer");

			char sClassname[64];
			GetEntityClassname(iEdict, sClassname, sizeof(sClassname));

			if(StrEqual(sClassname, sItemClassname))
			{
				return true;
			}
		}
		return false;
	}
	return true;
}

public bool IsCorrectItemItemIndexName(int client, const char[] sItemIndexNameRestriction)
{
	//------------------------------------------------
	// Item Name restriction.
	// This quest is restricted to a specific item, check by name.
	if(!StrEqual(sItemIndexNameRestriction, ""))
	{
		int next = GetEntPropEnt(client, Prop_Data, "m_hMoveChild");
		while (next != -1)
		{
			int iEdict = next;
			next = GetEntPropEnt(iEdict, Prop_Data, "m_hMovePeer");
			// Check if this entity was created by custom economy.
			if (CEconItems_IsEntityCustomEconItem(iEdict))
			{
				// Getting entity item struct.
				CEItem xItem;
				if(CEconItems_GetEntityItemStruct(iEdict, xItem))
				{
					// Getting item definition of this item.
					CEItemDefinition xDef;
					if(CEconItems_GetItemDefinitionByIndex(xItem.m_iItemDefinitionIndex, xDef))
					{
						// Comparing expected name with what definition has.
						if (StrEqual(xDef.m_sName, sItemIndexNameRestriction))
						{
							// If they match, this check has passed.
							return true;
						}
					}
					continue;
				}
			} else {
				// If this is not a custom econ item, check native TF2 item name.
				int iDefIndex = GetEntProp(iEdict, Prop_Send, "m_iItemDefinitionIndex");

				// Getting item schema name.
				char sName[64];
				if(TF2Econ_GetItemName(iDefIndex, sName, sizeof(sName)))
				{
					// Comparing schema name and expected name.
					if (StrEqual(sName, sItemIndexNameRestriction))
					{
						// If match, this check has passed.
						return true;
					}
				}
			}
		}
		return false;
	}
	return true;
}

public bool CanClientTriggerQuest(int client, CEQuestDefinition xQuest)
{
	if (!IsClientValid(client)) return false;
	if (!IsQuestActive(xQuest)) return false;
	if (!IsCorrectClass(client, xQuest.m_nRestrictedToClass)) return false;
	if (!IsCorrectWeaponSlot(client, xQuest.m_nRestrictedToWeaponSlot))return false;
	if (!IsCorrectWeaponItemIndexName(client, xQuest.m_sRestrictedToItemName))return false;
	if (!IsCorrectWeaponClassname(client, xQuest.m_sRestrictedToClassname))return false;
	if (!IsCorrectItemClassname(client, xQuest.m_sRestrictedToItemClassname))return false;
	if (!IsCorrectItemItemIndexName(client, xQuest.m_sRestrictedToItemItemName))return false;
	return true;
}

public bool CanClientTriggerObjective(int client, CEQuestObjectiveDefinition xObjective)
{
	if (!IsCorrectWeaponSlot(client, xObjective.m_nRestrictedToWeaponSlot))return false;
	if (!IsCorrectWeaponItemIndexName(client, xObjective.m_sRestrictedToItemName))return false;
	if (!IsCorrectWeaponClassname(client, xObjective.m_sRestrictedToClassname))return false;
	if (!IsCorrectItemClassname(client, xObjective.m_sRestrictedToItemClassname))return false;
	if (!IsCorrectItemItemIndexName(client, xObjective.m_sRestrictedToItemItemName))return false;
	return true;
}

public bool HasClientCompletedObjective(int client, CEQuestObjectiveDefinition xObjective)
{
	if (xObjective.m_iLimit <= 0)return false;


	CEQuestDefinition xQuest;
	if(GetQuestByObjective(xObjective, xQuest))
	{
		CEQuestClientProgress xProgress;
		GetClientQuestProgress(client, xQuest, xProgress);

		return xProgress.m_iProgress[xObjective.m_iIndex] >= xObjective.m_iLimit;
	}
	return false;
}

public void CEcon_OnClientEvent(int client, const char[] event, int add, int unique)
{
	if (!IsClientReady(client))return;

	IterateAndTickleClientQuests(client, client, event, add, unique);

	SendEventToFriends(client, event, add, unique);
}

public void IterateAndTickleClientQuests(int client, int source, const char[] event, int add, int unique)
{
	CEQuestDefinition xQuest;
	if(GetClientActiveQuest(client, xQuest))
	{
		TickleClientQuestObjectives(client, xQuest, source, event, add, unique);
	}

	if(ce_quest_background_enabled.BoolValue)
	{
		DataPack hPack = new DataPack();
		hPack.WriteCell(client);
		hPack.WriteCell(source);
		hPack.WriteString(event);
		hPack.WriteCell(add);
		hPack.WriteCell(unique);
		hPack.Reset();
	
		RequestFrame(RF_BackgroundQuests, hPack);
	}
}

public void RF_BackgroundQuests(any pack)
{
	DataPack hPack = pack;
	int client = hPack.ReadCell();
	int source = hPack.ReadCell();
	char event[128];
	hPack.ReadString(event, sizeof(event));
	int add = hPack.ReadCell();
	int unique = hPack.ReadCell();
	delete hPack;

	if(m_hBackgroundQuests != null)
	{
		for (int i = 0; i < m_hBackgroundQuests.Length; i++)
		{
			int iIndex = m_hBackgroundQuests.Get(i);

			CEQuestDefinition xQuest;
			if(GetQuestByIndex(iIndex, xQuest))
			{
				TickleClientQuestObjectives(client, xQuest, source, event, add, unique);
			}
		}
	}
}

public void SendEventToFriends(int client, const char[] event, int add, int unique)
{
	// If we disabled friend sharing, dont exec this function.
	if (!ce_quest_friend_sharing_enabled.BoolValue)return;
	if (!IsClientReady(client))return;

	for (int i = 1; i <= MaxClients; i++)
	{
		if(IsClientReady(i))
		{
			if(GetClientTeam(client) == GetClientTeam(i))
			{
				if(AreClientsFriends(client, i))
				{
					IterateAndTickleClientQuests(i, client, event, add, unique);
				}
			}
		}
	}
}

public void TickleClientQuestObjectives(int client, CEQuestDefinition xQuest, int source, const char[] event, int add, int unique)
{
	// Optimization concern: first check the aggregated list of events,
	// before we start calculating everything else.
	if (!QuestIsListeningForEvent(xQuest, event))return;

	// Some quests have friendly fire disabled. If so, only only accept events from ourselves.
	if(xQuest.m_bDisableEventSharing && client != source) return;

	// Don't allow background quests to be processed using friendly fire.
	if(xQuest.m_bBackground && client != source) return;

	if (!CanClientTriggerQuest(client, xQuest))return;

	bool bShouldResetObjectiveMark = false;

	if (m_iLastUniqueEvent[client] == 0)		bShouldResetObjectiveMark = true;
	if (m_iLastUniqueEvent[client] != unique)	bShouldResetObjectiveMark = true;

	// Event is new, unmark all events.
	if (bShouldResetObjectiveMark)
	{
		for (int i = 0; i < MAX_OBJECTIVES; i++)
		{
			m_bIsObjectiveMarked[client][i] = false;
		}
	}

	m_iLastUniqueEvent[client] = unique;
	
	for (int i = 0; i < xQuest.m_iObjectivesCount; i++)
	{
		// Only works with background
		if(!xQuest.m_bBackground)
		{
			if (m_bIsObjectiveMarked[client][i])continue;
		}

		CEQuestObjectiveDefinition xObjective;
		if(GetQuestObjectiveByIndex(xQuest, i, xObjective))
		{
			if (!CanClientTriggerObjective(client, xObjective))continue;

			for (int j = 0; j < xObjective.m_iHooksCount; j++)
			{
				CEQuestClientProgress xProgress;
				GetClientQuestProgress(client, xQuest, xProgress);

				CEQuestObjectiveHookDefinition xHook;
				if(GetObjectiveHookByIndex(xObjective, j, xHook))
				{
					if (StrEqual(xHook.m_sEvent, ""))continue;
					if (!StrEqual(xHook.m_sEvent, event))continue;

					m_bIsObjectiveMarked[client][i] = true;
					
					if (HasClientCompletedObjective(client, xObjective))continue;
					

					DataPack pack = new DataPack();
					pack.WriteCell(client);
					pack.WriteCell(xQuest.m_iIndex);
					pack.WriteCell(i);
					pack.WriteCell(j);
					pack.WriteCell(add);
					pack.WriteCell(source);
					pack.Reset();

					float flDelay = xHook.m_flDelay;

					if(flDelay <= 0.0)
					{
						RequestFrame(RF_TriggerClientObjectiveHook, pack);
					} else {
						CreateTimer(flDelay, Timer_TriggerClientObjectiveHook, pack);
					}
				}
			}
		}
	}
}

public void RF_TriggerClientObjectiveHook(any data)
{
	DataPack pack = data;
	int client = pack.ReadCell();
	int quest = pack.ReadCell();
	int objective = pack.ReadCell();
	int hook = pack.ReadCell();
	int add = pack.ReadCell();
	int source = pack.ReadCell();
	delete pack;

	TriggerClientObjectiveHook(client, quest, objective, hook, add, source);
}

public Action Timer_TriggerClientObjectiveHook(Handle timer, any data)
{
	DataPack pack = data;
	int client = pack.ReadCell();
	int quest = pack.ReadCell();
	int objective = pack.ReadCell();
	int hook = pack.ReadCell();
	int add = pack.ReadCell();
	int source = pack.ReadCell();
	delete pack;

	TriggerClientObjectiveHook(client, quest, objective, hook, add, source);
}

public void TriggerClientObjectiveHook(int client, int quest_defid, int objective, int hook, int add, int source)
{
	CEQuestDefinition xQuest;
	if (!GetQuestByDefIndex(quest_defid, xQuest))return;

	CEQuestObjectiveDefinition xObjective;
	if (!GetQuestObjectiveByIndex(xQuest, objective, xObjective))return;

	CEQuestObjectiveHookDefinition xHook;
	if (!GetObjectiveHookByIndex(xObjective, hook, xHook))return;

	CEQuestClientProgress xProgress;
	GetClientQuestProgress(client, xQuest, xProgress);

	switch(xHook.m_Action)
	{
		// Just straight up fires the event.
		case CEQuestAction_Singlefire:
		{
			AddPointsToClientObjective(client, xObjective, add * xObjective.m_iPoints, source, false);
		}

		// Increments the internal objective variable by `add`.
		case CEQuestAction_Increment:
		{
			if(xObjective.m_iEnd > 0)
			{
				int iToSubtract = add;

				int iPrevValue = xProgress.m_iVariable[objective];
				xProgress.m_iVariable[objective] += add;

				int iToAdd = 0;
				while(xProgress.m_iVariable[objective] >= xObjective.m_iEnd)
				{
					xProgress.m_iVariable[objective] -= xObjective.m_iEnd;
					iToAdd += xObjective.m_iPoints;
					iToSubtract -= xObjective.m_iEnd;
				}

				// We only run update quest progress if we're really sure,
				// that variables have changed.
				if(iPrevValue != xProgress.m_iVariable[objective])
				{
					UpdateClientQuestProgress(client, xProgress);
				}

				if(iToAdd > 0)
				{
					AddPointsToClientObjective(client, xObjective, iToAdd, source, false);
				}

				if(xHook.m_flSubtractIn > 0.0 && iToSubtract > 0)
				{
					DataPack pack = new DataPack();
					pack.WriteCell(client);
					pack.WriteCell(quest_defid);
					pack.WriteCell(objective);
					pack.WriteCell(iToSubtract);
					pack.Reset();

					CreateTimer(xHook.m_flSubtractIn, Timer_QuestObjectiveHookSubtractIn_Delayed, pack);
				}
			}
		}

		// Resets the internal objective value back to zero.
		case CEQuestAction_Reset:
		{
			// We only update values if we're really sure that something
			// has changed.
			if(xProgress.m_iVariable[objective] != 0)
			{
				xProgress.m_iVariable[objective] = 0;
				UpdateClientQuestProgress(client, xProgress);
			}
		}

		// Subtracts the internal var by `var`.
		case CEQuestAction_Subtract:
		{
			int iPrevValue = xProgress.m_iVariable[objective];
			xProgress.m_iVariable[objective] -= add;

			// We only run update quest progress if we're really sure,
			// that variables have changed.
			if(iPrevValue != xProgress.m_iVariable[objective])
			{
				UpdateClientQuestProgress(client, xProgress);
			}
		}
	}
}

public Action Timer_QuestObjectiveHookSubtractIn_Delayed(Handle timer, any data)
{
	DataPack pack = data;

	int client = pack.ReadCell();
	int quest_defid = pack.ReadCell();
	int objective = pack.ReadCell();
	int subtract = pack.ReadCell();
	delete pack;

	if (subtract <= 0)return Plugin_Handled;

	CEQuestDefinition xQuest;
	if (!GetQuestByDefIndex(quest_defid, xQuest))return Plugin_Handled;

	CEQuestClientProgress xProgress;
	UpdateClientQuestProgress(client, xProgress);

	xProgress.m_iVariable[objective] -= subtract;

	UpdateClientQuestProgress(client, xProgress);
	return Plugin_Handled;
}

public bool AddPointsToClientObjective(int client, CEQuestObjectiveDefinition xObjective, int points, int source, bool silent)
{
	CEQuestDefinition xQuest;
	if(GetQuestByObjective(xObjective, xQuest))
	{
		int iObjectiveIndex = xObjective.m_iIndex;

		// First, let's check if our current objective is not completed.
		// We can't do anything if out current objective is already completed.
		if (HasClientCompletedObjective(client, xObjective))return;

		// At this point, we are sure that some points will be added regardless.
		int iPointsToAdd = 0;
		int iLimit = xObjective.m_iLimit;

		// If we're adding points to a bonus objective, we add just one
		// point to the bonus objective and the rest goes to the primary one.
		if(iObjectiveIndex > 0)
		{
			bool bShouldMutePrimary = true;

			// By default, if we're triggering a bonus objective, we are muting
			// primary points change because we don't want sounds to overlay each other.
			// However, if the limit of our objective is set to zero, that means we can't
			// possibly increase it, because we're always clamped to zero.
			// So in this case, let the primary objective handle the sound. It should always
			// have a limit.
			if (iLimit == 0)bShouldMutePrimary = false;

			CEQuestObjectiveDefinition xPrimary;
			if(GetQuestObjectiveByIndex(xQuest, 0, xPrimary))
			{
				// True if something changed.
				AddPointsToClientObjective(client, xPrimary, points, source, bShouldMutePrimary);
			}
			iPointsToAdd = 1;
		} else {
			// Otherwise, we're already primary.
			// Let's add the full amount.

			iPointsToAdd = points;
		}

		if(iPointsToAdd > 0 && iLimit > 0)
		{

			CEQuestClientProgress xProgress;
			GetClientQuestProgress(client, xQuest, xProgress);

			int iBefore = xProgress.m_iProgress[iObjectiveIndex];
			bool bChanged, bIsCompleted;
			int iDifference;

			// Increasing progress for current objective.

			xProgress.m_iProgress[iObjectiveIndex] = MIN(iLimit, iBefore + iPointsToAdd);
			int iAfter = xProgress.m_iProgress[iObjectiveIndex];
			iDifference = iAfter - iBefore;

			if(iDifference > 0)
			{
				bChanged = true;
				bIsCompleted = iBefore < iLimit && iAfter >= iLimit;
			}

			if(bChanged)
			{

				xProgress.m_iSource = source;
				UpdateClientQuestProgress(client, xProgress);

				// Queue backend update.
				
				// In a local build of the economy, the users will see contract progress
				// go up on their HUD to test if event logic works, but those events
				// will never be sent to the backend as they don't have access to an
				// API key, leaving them in a "read-only" state.
#if !defined LOCAL_BUILD
				AddQuestUpdateBatch(client, xQuest.m_iIndex, iObjectiveIndex, iAfter);
#endif
				bool bIsHalloween = StrEqual(xQuest.m_sPostfix, "MP");
				
				if(xQuest.m_bBackground)
				{
					// TODO: Contract hud enabled check
					PrintHintText(client, "[%d/%d] %s (%s) +%d%s", xProgress.m_iProgress[iObjectiveIndex], iLimit, xObjective.m_sName, xQuest.m_sName, xObjective.m_iPoints, xQuest.m_sPostfix);
					PrintToConsole(client, "* [%d/%d] %s (%s) +%d%s", xProgress.m_iProgress[iObjectiveIndex], iLimit, xObjective.m_sName, xQuest.m_sName, xObjective.m_iPoints, xQuest.m_sPostfix);
				}

				// ------------------------ //
				// SOUND					//

				if(!silent && !xQuest.m_bBackground)
				{
					char sSound[128];
					Format(sSound, sizeof(sSound), "Quest.StatusTick");

					char sLevel[24];
					switch(iObjectiveIndex)
					{
						case 0:strcopy(sLevel, sizeof(sLevel), "Novice");
						case 1:strcopy(sLevel, sizeof(sLevel), "Advanced");
						default:strcopy(sLevel, sizeof(sLevel), "Expert");
					}

					// Only play "Compelted" music, if we've completed primary objective.
					if(bIsCompleted && iObjectiveIndex == 0)
					{
						if(bIsHalloween)
						{
							Format(sSound, sizeof(sSound), "%sCompleteHalloween", sSound);
						} else {
							Format(sSound, sizeof(sSound), "%s%sComplete", sSound, sLevel);
						}
					} else {
						Format(sSound, sizeof(sSound), "%s%s", sSound, sLevel);

						if(client != source)
						{
							Format(sSound, sizeof(sSound), "%sFriend", sSound);
						}
					}

					ClientCommand(client, "playgamesound %s", sSound);
				}

				// -------------------------------- //
				// MESSAGE							//

				// Sending message in chat if user completes objective.
				if(bIsCompleted)
				{
					if(iObjectiveIndex == 0)
					{
						if(bIsHalloween)
						{
				 			PrintToChatAll("\x03%N \x01has completed the primary objective for their \x03%s\x01 Merasmission!", client, xQuest.m_sName);
						} else {
				 			PrintToChatAll("\x03%N \x01has completed the primary objective for their \x03%s\x01 contract!", client, xQuest.m_sName);
						}
					} else {
						if(bIsHalloween)
						{
				  			PrintToChatAll("\x03%N \x01has completed an incredibly scary bonus objective for their \x03%s\x01 Merasmission!", client, xQuest.m_sName);
						} else {
				  			PrintToChatAll("\x03%N \x01has completed an incredibly difficult bonus objective for their \x03%s\x01 contract!", client, xQuest.m_sName);
						}
					}
				}
			}
		}

	}
}

public bool AreClientsFriends(int client, int target)
{
	// Check if users are friends

	// Players are not friends to themselves
	if (client == target)
		return false;

	bool bFriends = false;

	if(m_hFriends[client] != null)
	{
		if(m_hFriends[client].FindString(m_sPlayerSteamID64[target]) != -1)
		{
			return true;
		}
	}

	if(!bFriends)
	{
		if(m_hFriends[target] != null)
		{
			if(m_hFriends[target].FindString(m_sPlayerSteamID64[client]) != -1)
			{
				return true;
			}
		}
	}

	return false;
}


public int FindTargetBySteamID64(const char[] steamid)
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && IsClientAuthorized(i))
		{
			char szAuth[256];
			GetClientAuthId(i, AuthId_SteamID64, szAuth, sizeof(szAuth));
			if (StrEqual(szAuth, steamid))return i;
		}
	}
	return -1;
}

public int MAX(int iNum1, int iNum2)
{
	if (iNum1 > iNum2)return iNum1;
	if (iNum2 > iNum1)return iNum2;
	return iNum1;
}

public int MIN(int iNum1, int iNum2)
{
	if (iNum1 < iNum2)return iNum1;
	if (iNum2 < iNum1)return iNum2;
	return iNum1;
}
// In a local build of the economy, the users will see contract progress
// go up on their HUD to test if event logic works, but those events
// will never be sent to the backend as they don't have access to an
// API key, leaving them in a "read-only" state.
#if !defined LOCAL_BUILD

enum struct CEQuestUpdateBatch
{
	char m_sSteamID[64];
	int m_iQuest;

	int m_iObjective;
	int m_iPoints;
}

bool m_bIsUpdatingBatch;
bool m_bWasUpdatedWhileUpdating;

ArrayList m_QuestUpdateBatches;

public void AddQuestUpdateBatch(int client, int quest, int objective, int points)
{
	if(m_QuestUpdateBatches == null)
	{
		m_QuestUpdateBatches = new ArrayList(sizeof(CEQuestUpdateBatch));
	}

	char sSteamID[64];
	GetClientAuthId(client, AuthId_SteamID64, sSteamID, sizeof(sSteamID));

	for (int i = 0; i < m_QuestUpdateBatches.Length; i++)
	{
		CEQuestUpdateBatch xBatch;
		m_QuestUpdateBatches.GetArray(i, xBatch);

		if (!StrEqual(xBatch.m_sSteamID, sSteamID))continue;
		if (xBatch.m_iQuest != quest)continue;
		if (xBatch.m_iObjective != objective)continue;

		m_QuestUpdateBatches.Erase(i);
		i--;
	}

	CEQuestUpdateBatch xBatch;
	strcopy(xBatch.m_sSteamID, sizeof(xBatch.m_sSteamID), sSteamID);
	xBatch.m_iQuest 	= quest;
	xBatch.m_iObjective = objective;
	xBatch.m_iPoints 	= points;
	m_QuestUpdateBatches.PushArray(xBatch);
	
	if (m_bIsUpdatingBatch)m_bWasUpdatedWhileUpdating = true;

}
#endif

public Action Timer_QuestUpdateInterval(Handle timer, any data)
{
	// In a local build of the economy, the users will see contract progress
	// go up on their HUD to test if event logic works, but those events
	// will never be sent to the backend as they don't have access to an
	// API key, leaving them in a "read-only" state.
#if defined LOCAL_BUILD
	return;
#else
	if (m_QuestUpdateBatches == null)return;
	if (m_QuestUpdateBatches.Length == 0)return;

	HTTPRequestHandle hRequest = CEconHTTP_CreateBaseHTTPRequest("/api/IEconomySDK/UserQuests", HTTPMethod_POST);
	
	int iCount = 0;

	for (int i = 0; i < m_QuestUpdateBatches.Length; i++)
	{
		if (iCount >= BACKEND_QUEST_UPDATE_LIMIT)break;
		
		CEQuestUpdateBatch xBatch;
		m_QuestUpdateBatches.GetArray(i, xBatch);

		char sKey[128];
		Format(sKey, sizeof(sKey), "quests[%s][%d][%d]", xBatch.m_sSteamID, xBatch.m_iQuest, xBatch.m_iObjective);

		char sValue[11];
		IntToString(xBatch.m_iPoints, sValue, sizeof(sValue));

		Steam_SetHTTPRequestGetOrPostParameter(hRequest, sKey, sValue);
		iCount++;
	}
	
	LogMessage("Sending a batch of %d quests. (%d left in the queue.)", iCount, m_QuestUpdateBatches.Length);

	Steam_SendHTTPRequest(hRequest, QuestUpdate_Callback, iCount);
	m_bIsUpdatingBatch = true;
#endif
}

public void QuestUpdate_Callback(HTTPRequestHandle request, bool success, HTTPStatusCode code, any count)
{
	// In a local build of the economy, the users will see contract progress
	// go up on their HUD to test if event logic works, but those events
	// will never be sent to the backend as they don't have access to an
	// API key, leaving them in a "read-only" state.
#if defined LOCAL_BUILD
	return;
#else
	m_bIsUpdatingBatch = false;
	bool bUpdated = m_bWasUpdatedWhileUpdating;
	m_bWasUpdatedWhileUpdating = false;
	
	Steam_ReleaseHTTPRequest(request);
	int iCount = count;

	// If request was not succesful, return.
	if (!success || code != HTTPStatusCode_OK)
	{
		LogMessage("Sending batch request returned with %d error. Try to send the next time. (Buffer remaining: %d, Batches affected: %d)", code, m_QuestUpdateBatches.Length, iCount);
		return;
	}
	
	if (m_QuestUpdateBatches == null)return;

	// Cool, we've updated everything.
	
	// If nothing has changed while we're making the request, remove the N batches at the bottom of the list.
	if(!bUpdated)
	{
		// Remove the batch updates that we just 
		for (int i = 0; i < iCount; i++)
		{
			if (i >= m_QuestUpdateBatches.Length)break;
			
			m_QuestUpdateBatches.Erase(i);
			i--;
			iCount--;
		}
	} else {	
		LogMessage("Batch order has been updated while request was made. We are not sure if we can remove them now.");
	}
	
	LogMessage("Succesfully updated %d batches. %d left in the queue.", count, m_QuestUpdateBatches.Length);
	
	// If it's empty - delete it.
	if(m_QuestUpdateBatches.Length == 0)
	{
		delete m_QuestUpdateBatches;
	}
#endif
}

public Action teamplay_round_win(Event event, const char[] name, bool dontBroadcast)
{
	// In a local build of the economy, the users will see contract progress
	// go up on their HUD to test if event logic works, but those events
	// will never be sent to the backend as they don't have access to an
	// API key, leaving them in a "read-only" state.
#if defined LOCAL_BUILD
	return;
#else
	// Update progress immediately when round ends.
	// Players usually will look up their progress after they've done playing the game.
	// And it'll be frustrating to see their progress not being updated immediately.
	CreateTimer(0.1, Timer_QuestUpdateInterval);
#endif
}

public bool QuestIsListeningForEvent(CEQuestDefinition xQuest, const char[] event)
{
	char sEvent[64];
	Format(sEvent, sizeof(sEvent), "%s;", event);

	return StrContains(xQuest.m_sAggregatedEvents, sEvent, false) != -1;
}
