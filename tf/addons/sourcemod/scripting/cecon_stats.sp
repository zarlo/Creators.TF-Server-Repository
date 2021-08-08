//============= Copyright Amper Software, All rights reserved. ============//
//
// Purpose: Stats handler for Creators.TF Economy.
//
//=========================================================================//

#include <steamtools>

#pragma semicolon 1
#pragma tabsize 0
#pragma newdecls required

#include <cecon_http>
#include <cecon>

#define BACKEND_STAT_UPDATE_INTERVAL 20.0
#define BACKEND_STAT_UPDATE_LIMIT 10 // Dont allow more than 10 quests to be updated at the same time.

public Plugin myinfo =
{
	name = "Creators.TF Economy - Stats Handler",
	author = "Creators.TF Team",
	description = "Creators.TF Economy Stats Handler",
	version = "1.0",
	url = "https://creators.tf"
}

enum struct CEPlayerStat
{
	int m_iIndex;
	char m_sEvent[128];
}

ArrayList m_hStatDefinitions;

//ArrayList m_hProgress[MAXPLAYERS + 1];
//bool m_bWaitingForProgress[MAXPLAYERS + 1];

public void OnPluginStart()
{
	RegServerCmd("ce_stats_dump", cDump, "");

	// In a local build of the economy, the users wont have their stats
	// updated on the database using HTTP requests.
#if !defined LOCAL_BUILD
	CreateTimer(BACKEND_STAT_UPDATE_INTERVAL, Timer_StatUpdateInterval, _, TIMER_REPEAT);
#endif

}

public void OnAllPluginsLoaded()
{
	ParseEconomyConfig(CEcon_GetEconomySchema());
}

public void CEcon_OnSchemaUpdated(KeyValues hSchema)
{
	ParseEconomyConfig(hSchema);
}

public void ParseEconomyConfig(KeyValues kv)
{
	delete m_hStatDefinitions;
	if (kv == null)return;

	m_hStatDefinitions = new ArrayList(sizeof(CEPlayerStat));

	if(kv.JumpToKey("Stats", false))
	{
		if(kv.GotoFirstSubKey())
		{
			do {
				char sEvent[128];
				kv.GetString("event", sEvent, sizeof(sEvent));
				if (StrEqual(sEvent, ""))continue;
				
				char sSectionName[11];
				kv.GetSectionName(sSectionName, sizeof(sSectionName));

				CEPlayerStat xStat;
				xStat.m_iIndex = StringToInt(sSectionName);
				strcopy(xStat.m_sEvent, sizeof(xStat.m_sEvent), sEvent);

				m_hStatDefinitions.PushArray(xStat);

			} while (kv.GotoNextKey());
		}
	}
	kv.Rewind();
}

public Action cDump(int args)
{
	LogMessage("Dumping precached data");
	for (int i = 0; i < m_hStatDefinitions.Length; i++)
	{
		CEPlayerStat xStat;
		m_hStatDefinitions.GetArray(i, xStat);

		LogMessage("CEPlayerStat");
		LogMessage("{");
		LogMessage("  m_iIndex = %d", xStat.m_iIndex);
		LogMessage("  m_sEvent = \"%s\"", xStat.m_sEvent);
	}

	LogMessage("");
	LogMessage("CEPlayerStat Count: %d", m_hStatDefinitions.Length);
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

public void CEcon_OnClientEvent(int client, const char[] event, int add, int unique)
{
	if (!IsClientReady(client))return;

	IterateAndTickleClientStats(client, event, add, unique);
}

public void IterateAndTickleClientStats(int client, const char[] event, int add, int unique)
{
	for (int i = 0; i < m_hStatDefinitions.Length; i++)
	{
		CEPlayerStat xStat;
		m_hStatDefinitions.GetArray(i, xStat);
		
		if(StrEqual(xStat.m_sEvent, event))
		{	
			// In a local build of the economy, the users wont have their stats
			// updated on the database using HTTP requests.
#if !defined LOCAL_BUILD
			AddQuestUpdateBatch(client, xStat.m_iIndex, add);
#endif
		}
	}
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

// In a local build of the economy, the users wont have their stats
// updated on the database using HTTP requests.
#if !defined LOCAL_BUILD

enum struct CEStatUpdateBatch
{
	char m_sSteamID[64];
	int m_iIndex;
	int m_iDelta;
}
ArrayList m_StatUpdateBatches;

public void AddQuestUpdateBatch(int client, int stat, int points)
{
	if(m_StatUpdateBatches == null)
	{
		m_StatUpdateBatches = new ArrayList(sizeof(CEStatUpdateBatch));
	}

	char sSteamID[64];
	GetClientAuthId(client, AuthId_SteamID64, sSteamID, sizeof(sSteamID));
	
	int iOldValue = 0;

	for (int i = 0; i < m_StatUpdateBatches.Length; i++)
	{
		CEStatUpdateBatch xBatch;
		m_StatUpdateBatches.GetArray(i, xBatch);

		if (!StrEqual(xBatch.m_sSteamID, sSteamID))continue;
		if (xBatch.m_iIndex != stat)continue;

		iOldValue = xBatch.m_iDelta;
		m_StatUpdateBatches.Erase(i);
		i--;
	}

	CEStatUpdateBatch xBatch;
	strcopy(xBatch.m_sSteamID, sizeof(xBatch.m_sSteamID), sSteamID);
	xBatch.m_iIndex 	= stat;
	xBatch.m_iDelta 	= iOldValue + points;
	m_StatUpdateBatches.PushArray(xBatch);
}

public Action Timer_StatUpdateInterval(Handle timer, any data)
{
	if (m_StatUpdateBatches == null)return;
	if (m_StatUpdateBatches.Length == 0)return;

	HTTPRequestHandle hRequest = CEconHTTP_CreateBaseHTTPRequest("/api/IEconomySDK/UserStats", HTTPMethod_POST);
	
	int iCount = 0;

	for (int i = 0; i < m_StatUpdateBatches.Length; i++)
	{
		if (iCount >= BACKEND_STAT_UPDATE_LIMIT)break;
		
		CEStatUpdateBatch xBatch;
		m_StatUpdateBatches.GetArray(i, xBatch);

		char sKey[128];
		Format(sKey, sizeof(sKey), "stats[%s][%d]", xBatch.m_sSteamID, xBatch.m_iIndex);

		char sValue[11];
		IntToString(xBatch.m_iDelta, sValue, sizeof(sValue));

		Steam_SetHTTPRequestGetOrPostParameter(hRequest, sKey, sValue);
		m_StatUpdateBatches.Erase(i);
		i--;
		iCount++;
	}
	
	LogMessage("Sending a batch of %d stats. (%d left in the queue.)", iCount, m_StatUpdateBatches.Length);

	Steam_SendHTTPRequest(hRequest, StatUpdate_Callback);
	
	if(m_StatUpdateBatches.Length == 0)
	{
		delete m_StatUpdateBatches;
	}
}

public void StatUpdate_Callback(HTTPRequestHandle request, bool success, HTTPStatusCode code)
{
	LogMessage("[INFO] Stats Batch updated with code %d", code);
	Steam_ReleaseHTTPRequest(request);

	// Cool, we've updated everything.
}
#endif

public Action teamplay_round_win(Event event, const char[] name, bool dontBroadcast)
{
	// Update progress immediately when round ends.
	// Players usually will look up their progress after they've done playing the game.
	// And it'll be frustrating to see their progress not being updated immediately.
	
	// In a local build of the economy, the users wont have their stats
	// updated on the database using HTTP requests.
#if !defined LOCAL_BUILD
	CreateTimer(0.1, Timer_StatUpdateInterval);
#endif
}
