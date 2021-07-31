#pragma semicolon 1
#pragma newdecls required
#pragma tabsize 0

public Plugin myinfo =
{
	name = "Creators.TF Matchmaking",
	author = "Creators.TF Team",
	description = "Matchmaking.",
	version = "1.0",
	url = "https://creators.tf"
}

#define MM_MAPCHANGE_COOLDOWN 300.0

char m_sAutoloadPopfile[PLATFORM_MAX_PATH];
ArrayList m_hMapList;
int m_iMapListSerial;

float m_flNextMatchmakingChange;

public void OnPluginStart()
{
	RegServerCmd("ce_mm_empty_change_map", ce_mm_empty_change_map);
	RegServerCmd("ce_mm_empty_change_popfile", ce_mm_empty_change_popfile);

	m_hMapList = new ArrayList(ByteCountToCells(PLATFORM_MAX_PATH));
}

public void OnMapStart()
{
	SetMatchmakingCooldown();
}

public void SetMatchmakingCooldown()
{
	m_flNextMatchmakingChange = GetEngineTime() + MM_MAPCHANGE_COOLDOWN;
}

public void OnConfigsExecuted()
{
	LoadRememberedPopFile();

	if(ReadMapList(m_hMapList, m_iMapListSerial, "quickplay", MAPLIST_FLAG_CLEARARRAY | MAPLIST_FLAG_MAPSFOLDER) == INVALID_HANDLE)
	{
		if(m_iMapListSerial == -1)
		{
			LogError("Error loading Quickplay map rotation.");
		}
	}
	for (int i = 0; i < m_hMapList.Length; i++)
	{
		char map[128];
		m_hMapList.GetString(i, map, sizeof(map));
		if (StrContains(map, "workshop") != -1)
		{
			GetMapDisplayName(map, map, sizeof map);
		}
		m_hMapList.SetString(i, map);
	}
}

public Action ce_mm_empty_change_map(int args)
{
	if (!CanQuickplaySwitchMaps())return Plugin_Handled;

	char sQuery[PLATFORM_MAX_PATH], sMap[PLATFORM_MAX_PATH];
	GetCmdArg(1, sQuery, sizeof(sQuery));

	ArrayList hCandidates = new ArrayList(ByteCountToCells(PLATFORM_MAX_PATH));

	// Trying to find a map with this popfile.
	for (int i = 0; i < m_hMapList.Length; i++)
	{
		char buffer[PLATFORM_MAX_PATH];
		m_hMapList.GetString(i, buffer, sizeof(buffer));
		int len = strlen(sQuery);

		if (strncmp(buffer, sQuery, len) == 0)
		{
			hCandidates.PushString(buffer);
		}
	}

	if(hCandidates.Length > 0)
	{
		LogMessage("Choosing between %d matching candidates:", hCandidates.Length);
		int iIndex = GetRandomInt(0, hCandidates.Length - 1);

		hCandidates.GetString(iIndex, sMap, sizeof(sMap));
		LogMessage("| Rolled number: %d (%s)", iIndex, sMap);
	} else {
		LogMessage("Zero candidates found.");
	}

	delete hCandidates;


	if(!StrEqual(sMap, ""))
	{
		char sCurr[PLATFORM_MAX_PATH];
		GetCurrentMap(sCurr, sizeof(sCurr));
		if (StrContains(sCurr, "workshop") != -1)
		{
			GetMapDisplayName(sCurr, sCurr, sizeof sCurr);
		}

		if(!StrEqual(sCurr, sMap))
		{
			ServerCommand("changelevel %s", sMap);
		}
	}

	return Plugin_Handled;
}

//------------------------------------------------------------------------
// Purpose: ce_mm_empty_change_popfile command.
//------------------------------------------------------------------------
public Action ce_mm_empty_change_popfile(int args)
{
	if (!CanQuickplaySwitchMaps())return Plugin_Handled;

	// Getting popfile name.
	char sPopFile[PLATFORM_MAX_PATH];
	GetCmdArg(1, sPopFile, sizeof(sPopFile));

	char sMap[PLATFORM_MAX_PATH];

	// Trying to find a map with this popfile.
	for (int i = 0; i < m_hMapList.Length; i++)
	{
		char buffer[PLATFORM_MAX_PATH];
		m_hMapList.GetString(i, buffer, sizeof(buffer));
		int len = strlen(buffer);

		if (strncmp(sPopFile, buffer, len) == 0)
		{
			strcopy(sMap, sizeof(sMap), buffer);
			break;
		}
	}

	if(!StrEqual(sMap, ""))
	{
		strcopy(m_sAutoloadPopfile, sizeof(m_sAutoloadPopfile), sPopFile);

		char sCurr[PLATFORM_MAX_PATH];
		GetCurrentMap(sCurr, sizeof(sCurr));
		if (StrContains(sCurr, "workshop") != -1)
		{
			GetMapDisplayName(sCurr, sCurr, sizeof sCurr);
		}

		if(StrEqual(sCurr, sMap))
		{
			LoadRememberedPopFile();
		} else {
			ServerCommand("changelevel %s", sMap);
		}
	}
	return Plugin_Handled;
}

public void LoadRememberedPopFile()
{
	if (!StrEqual(m_sAutoloadPopfile, ""))
	{
		LogMessage("Setting mission: %s", m_sAutoloadPopfile);
		ServerCommand("tf_mvm_popfile %s", m_sAutoloadPopfile);

		strcopy(m_sAutoloadPopfile, sizeof(m_sAutoloadPopfile), "");
		SetMatchmakingCooldown();
	}
}

public bool CanQuickplaySwitchMaps()
{
	if(m_flNextMatchmakingChange > GetEngineTime()) return false;
	return IsServerEmpty();
}

public bool IsServerEmpty()
{
	return GetConnectedPlayersCount() == 0;
}

public int GetConnectedPlayersCount()
{
	int count;
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientConnected(i))continue;
		if (IsClientSourceTV(i))continue;
		if (IsFakeClient(i))continue;

		count++;
	}
	return count;
}
