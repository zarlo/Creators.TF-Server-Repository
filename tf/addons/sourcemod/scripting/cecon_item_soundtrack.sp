#pragma semicolon 1
#pragma newdecls required

#define MAX_SOUND_NAME 512
#define MAX_EVENT_NAME 32

#define PAYLOAD_STAGE_1_START 0.85
#define PAYLOAD_STAGE_2_START 0.93

enum struct Soundtrack_t
{
	int m_iDefIndex;

	char m_sWinMusic[512];
	char m_sLossMusic[512];

	int m_iEvents[16];
	int m_iEventsCount;

	ArrayList m_hEvents;
}

enum struct Sample_t
{
	char m_sSound[MAX_SOUND_NAME];

	int m_nIterations;
	int m_nCurrentIteration;

	int m_nMoveToSample;
	char m_sMoveToEvent[32];

	float m_flDuration;
	float m_flVolume;

	bool m_bPreserveSample;
}

enum struct Event_t
{
	char m_sStartHook[128];
	char m_sStopHook[128];

    char m_sID[32];

	bool m_bForceStart;
	bool m_bForceStop;

    bool m_bFireOnce;
    bool m_bSkipPost;

    int m_iPriority;

	int m_iPreSample;
	int m_iPostSample;

	int m_iSamples[32];
	int m_iSamplesCount;
}


#include <sdktools>
#include <cecon>
#include <cecon_items>

ArrayList m_hKitDefs;
ArrayList m_hEventDefs;
ArrayList m_hSampleDefs;

int m_iMusicKit[MAXPLAYERS + 1] =  { -1, ... };
int m_iNextEvent[MAXPLAYERS + 1];
int m_iCurrentEvent[MAXPLAYERS + 1];

char m_sActiveSound[MAXPLAYERS + 1][MAX_SOUND_NAME];

bool m_bIsPlaying[MAXPLAYERS + 1];
bool m_bShouldStop[MAXPLAYERS + 1];
bool m_bForceNextEvent[MAXPLAYERS + 1];
bool m_bQueuedSkipped[MAXPLAYERS + 1]; // Ignore queue even if there are more samples there.

Handle m_hTimer[MAXPLAYERS + 1];

int m_iQueueLength[MAXPLAYERS + 1];
int m_iQueuePointer[MAXPLAYERS + 1];
Sample_t m_hQueue[MAXPLAYERS + 1][32];
Sample_t m_hPreSample[MAXPLAYERS + 1];
Sample_t m_hPostSample[MAXPLAYERS + 1];

int m_nPayloadStage = 0;
int m_iRoundTime = 0;


public Plugin myinfo =
{
	name = "Creators.TF Economy - Music Kits Handler",
	author = "Creators.TF Team",
	description = "Creators.TF Economy Music Kits Handler",
	version = "1.00",
	url = "https://creators.tf"
};

#define MVM_DANGER_CHECK_INTERVAL 0.5

public void OnPluginStart()
{
	HookEvent("teamplay_broadcast_audio", teamplay_broadcast_audio, EventHookMode_Pre);
	HookEvent("teamplay_round_start", teamplay_round_start, EventHookMode_Pre);
	HookEvent("teamplay_round_win", teamplay_round_win);
	HookEvent("teamplay_point_captured", teamplay_point_captured);
	HookEvent("mvm_wave_complete", mvm_wave_complete);

	CreateTimer(0.5, Timer_EscordProgressUpdate, _, TIMER_REPEAT);
	RegServerCmd("ce_soundtrack_setkit", cSetKit, "");
	RegServerCmd("ce_soundtrack_dump", cDump, "");

	HookEntityOutput("team_round_timer", "On30SecRemain", OnEntityOutput);
	HookEntityOutput("team_round_timer", "On1MinRemain", OnEntityOutput);

	AddNormalSoundHook(view_as<NormalSHook>(OnSoundHook));

	CreateTimer(MVM_DANGER_CHECK_INTERVAL, Timer_MvMDangerCheck, _, TIMER_REPEAT);
}

// MvM

bool m_bWasInDangerBefore = false;

float m_flBombCalmDownAfter;

#define MVM_BOMB_CALM_DELAY 10.0
#define MVM_BOMB_DANGER_RADIUS 1500.0
#define MVM_BOMB_CRITICAL_RADIUS 500.0

public Action Timer_MvMDangerCheck(Handle timer, any data)
{
	if(TF2MvM_IsPlayingMvM())
	{
		bool bIsCritical = false;
		bool bDanger = MvM_IsInDanger(bIsCritical);

		if(bDanger != m_bWasInDangerBefore)
		{
			if(bDanger)
			{
				if(bIsCritical)
				{
					MvM_EnableCriticalMode();
				} else {
					MvM_EnableDangerMode();
				}
			} else {
				MvM_DisableDangerMode();
			}
		}
	}
}

public bool TF2MvM_IsPlayingMvM()
{
	return (GameRules_GetProp("m_bPlayingMannVsMachine") != 0);
}

#define TF_FLAGINFO_STOLEN (1 << 0)

public bool MvM_IsInDanger(bool &critical)
{
	critical = false;
	if (!TF2MvM_IsPlayingMvM())return false;

	float flTime = GetEngineTime();

	int iHatch = FindEntityByClassname(-1, "func_capturezone");
	if(iHatch > -1)
	{
		float vecPosHatch[3], vecPosHatchMins[3], vecPosHatchMaxs[3];
		GetEntPropVector(iHatch, Prop_Send, "m_vecMins", vecPosHatchMins);
		GetEntPropVector(iHatch, Prop_Send, "m_vecMaxs", vecPosHatchMaxs);

		for (int i = 0; i < 3; i++)vecPosHatch[i] = vecPosHatchMins[i] + (vecPosHatchMaxs[i] - vecPosHatchMins[i]) / 2;

		// Check if a tank is near the hatch.
		int iTank = -1;
		while((iTank = FindEntityByClassname(iTank, "tank_boss")) != -1)
		{
			float vecPosTank[3];
			GetEntPropVector(iTank, Prop_Send, "m_vecOrigin", vecPosTank);

			float flDistance = GetVectorDistance(vecPosHatch, vecPosTank, false);
			if(flDistance < MVM_BOMB_DANGER_RADIUS)
			{
				if(flDistance < MVM_BOMB_CRITICAL_RADIUS)
				{
					critical = true;
				}
				return true;
			}
		}

		// Check if bomb is near the hatch.
		int iFlag = -1;
		while((iFlag = FindEntityByClassname(iFlag, "item_teamflag")) != -1)
		{
			int iStatus = GetEntProp(iFlag, Prop_Send, "m_nFlagStatus");
			if(iStatus & TF_FLAGINFO_STOLEN)
			{
				int iOwner = GetEntPropEnt(iFlag, Prop_Send, "m_hOwnerEntity");
				if(iOwner > -1)
				{
					float vecPosFlag[3];
					GetClientAbsOrigin(iOwner, vecPosFlag);

					float flDistance = GetVectorDistance(vecPosHatch, vecPosFlag, false);
					if(flDistance < MVM_BOMB_DANGER_RADIUS)
					{
						if(flDistance < MVM_BOMB_CRITICAL_RADIUS)
						{
							critical = true;
						}
						m_flBombCalmDownAfter = flTime + MVM_BOMB_CALM_DELAY;
						return true;
					}
				}
			}
		}
	}

	if (m_flBombCalmDownAfter > flTime)return true;

	return false;
}

public void MvM_EnableDangerMode()
{
	//PrintToChatAll("Danger Mode");
	SendEventUniqueToAll("OST_MVM_BOMB_PROXIMITY_START", 1);
	m_bWasInDangerBefore = true;
}

public void MvM_EnableCriticalMode()
{
	//PrintToChatAll("Critical Mode");
	SendEventUniqueToAll("OST_MVM_BOMB_PROXIMITY_START_SKIP_INTRO", 1);
	m_bWasInDangerBefore = true;
}

public void MvM_DisableDangerMode()
{
	//PrintToChatAll("Safe Mode");
	SendEventUniqueToAll("OST_MVM_BOMB_PROXIMITY_STOP", 1);
	m_bWasInDangerBefore = false;
}

//---------------------------------------------------------------------------------------
// Purpose:	Fired when a sound if played.
//---------------------------------------------------------------------------------------
public Action OnSoundHook(int[] clients, int &numClients, char[] sample, int &entity, int &channel, float &volume, int &level, int &pitch, int &flags, char[] soundEntry, int &seed)
{
	if(StrEqual(sample, "mvm/mvm_tank_deploy.wav"))
	{
		for (int i = 1; i <= MaxClients; i++)
		{
			if(IsClientReady(i))
			{
				CEcon_SendEventToClientUnique(i, "OST_MVM_TANK_DEPLOY", 1);
			}
		}
	}

	if(StrEqual(sample, "mvm/mvm_tank_explode.wav"))
	{
		for (int i = 1; i <= MaxClients; i++)
		{
			if(IsClientReady(i))
			{
				CEcon_SendEventToClientUnique(i, "OST_MVM_TANK_DESTROYED", 1);
			}
		}
	}
	return Plugin_Continue;
}

public void SendEventUniqueToAll(const char[] event, int add)
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if(IsClientReady(i))
		{
			CEcon_SendEventToClientUnique(i, event, add);
		}
	}
}

public void CEcon_OnSchemaUpdated(KeyValues hSchema)
{
	ParseEconomySchema(hSchema);
}

public void OnAllPluginsLoaded()
{
	ParseEconomySchema(CEcon_GetEconomySchema());
}

public void FlushSchema()
{
	delete m_hKitDefs;
	delete m_hEventDefs;
	delete m_hSampleDefs;
}

public void ParseEconomySchema(KeyValues hConf)
{
	FlushSchema();

	m_hKitDefs = new ArrayList(sizeof(Soundtrack_t));
	m_hEventDefs = new ArrayList(sizeof(Event_t));
	m_hSampleDefs = new ArrayList(sizeof(Sample_t));

	if (hConf == null)return;

	if(hConf.JumpToKey("Items", false))
	{
		if(hConf.GotoFirstSubKey())
		{
			do {
				char sType[32];
				hConf.GetString("type", sType, sizeof(sType));
				if (!StrEqual(sType, "soundtrack"))continue;

				PrecacheSoundtrackKeyValues(hConf);
			} while (hConf.GotoNextKey());
		}
	}

	hConf.Rewind();
}

public void OnClientPostAdminCheck(int client)
{
	m_iMusicKit[client] = -1;
	BufferFlush(client);
}

public Action cDump(int args)
{
	LogMessage("Dumping precached data");
	for (int i = 0; i < m_hKitDefs.Length; i++)
	{
		Soundtrack_t hKit;
		GetKitByIndex(i, hKit);

		LogMessage("Soundtrack_t");
		LogMessage("{");
		LogMessage("  m_iDefIndex = %d", hKit.m_iDefIndex);
		LogMessage("  m_sWinMusic = \"%s\"", hKit.m_sWinMusic);
		LogMessage("  m_sLossMusic = \"%s\"", hKit.m_sLossMusic);
		LogMessage("  m_iEventsCount = %d", hKit.m_iEventsCount);
		LogMessage("  m_iEvents =");
		LogMessage("  [");

		for (int j = 0; j < hKit.m_iEventsCount; j++)
		{
			int iEventIndex = hKit.m_iEvents[j];

			Event_t hEvent;
			GetEventByIndex(iEventIndex, hEvent);
			LogMessage("    %d => Event_t (%d)", j, iEventIndex);
			LogMessage("    {");
			LogMessage("      m_sStartHook = \"%s\"", hEvent.m_sStartHook);
			LogMessage("      m_sStopHook = \"%s\"", hEvent.m_sStopHook);
			LogMessage("      m_sID = \"%s\"", hEvent.m_sID);

			LogMessage("      m_bForceStart = %s", hEvent.m_bForceStart ? "true" : "false");
			LogMessage("      m_bForceStop = %s", hEvent.m_bForceStop ? "true" : "false");
			LogMessage("      m_bFireOnce = %s", hEvent.m_bFireOnce ? "true" : "false");
			LogMessage("      m_bSkipPost = %s", hEvent.m_bSkipPost ? "true" : "false");

			LogMessage("      m_iPriority = %d", hEvent.m_iPriority);
			LogMessage("      m_iSamplesCount = %d", hEvent.m_iSamplesCount);
			LogMessage("      m_iSamples =");
			LogMessage("      [");

			for (int k = 0; k < hEvent.m_iSamplesCount; k++)
			{
				int iSampleIndex = hEvent.m_iSamples[k];

				Sample_t hSample;
				GetSampleByIndex(iSampleIndex, hSample);
				LogMessage("        %d => Sample_t (%d)", k, iSampleIndex);
				LogMessage("        {");
				LogMessage("          m_sSound = \"%s\"", hSample.m_sSound);
				LogMessage("          m_nIterations = %d", hSample.m_nIterations);
				LogMessage("          m_nCurrentIteration = %d", hSample.m_nCurrentIteration);
				LogMessage("          m_nMoveToSample = %d", hSample.m_nMoveToSample);
				LogMessage("          m_sMoveToEvent = \"%d\"", hSample.m_sMoveToEvent);
				LogMessage("          m_flDuration = %f", hSample.m_flDuration);
				LogMessage("          m_flVolume = %f", hSample.m_flVolume);
				LogMessage("          m_bPreserveSample = %s", hSample.m_bPreserveSample ? "true" : "false");
				LogMessage("        }");
			}

			LogMessage("      ]");
			LogMessage("    }");
		}

		LogMessage("  ]");
		LogMessage("}");

	}
	LogMessage("");
	LogMessage("Soundtrack_t Count: %d", m_hKitDefs.Length);
	LogMessage("Event_t Count: %d", m_hEventDefs.Length);
	LogMessage("Sample_t Count: %d", m_hSampleDefs.Length);
}

public Action cSetKit(int args)
{
	char sArg1[MAX_NAME_LENGTH], sArg2[11], sArg3[256];
	GetCmdArg(1, sArg1, sizeof(sArg1));
	GetCmdArg(2, sArg2, sizeof(sArg2));
	GetCmdArg(3, sArg3, sizeof(sArg3));

	int iTarget = FindTargetBySteamID(sArg1);
	if (!IsClientValid(iTarget))return Plugin_Handled;

	int iKit = StringToInt(sArg2);

	MusicKit_SetKit(iTarget, iKit, sArg3);
	return Plugin_Handled;
}

//--------------------------------------------------------------------
// Purpose: Update soundtrack for the client whos loadout was just
// updated.
//--------------------------------------------------------------------
public void CEconItems_OnClientLoadoutUpdated(int client)
{
	UpdateClientSountrack(client);
}

//--------------------------------------------------------------------
// Purpose: Read client's loadout and see what music kit they have
// equipped.
//--------------------------------------------------------------------
public void UpdateClientSountrack(int client)
{
	int iMusicKitDefIndex = -1;

	int iCount = CEconItems_GetClientLoadoutSize(client, CEconLoadoutClass_General);
	for (int i = 0; i <= iCount; i++)
	{
		CEItem xItem;
		if(CEconItems_GetClientItemFromLoadoutByIndex(client, CEconLoadoutClass_General, i, xItem))
		{
			iMusicKitDefIndex = xItem.m_iItemDefinitionIndex;
		}
	}

	int iKitID = GetKitIndexByDefID(iMusicKitDefIndex);

	if(iKitID != m_iMusicKit[client])
	{
		if(iKitID == -1)
		{
			PrintToChat(client, "\x01* Game soundtrack removed.");
		} else {

			CEItemDefinition xDef;
			if(CEconItems_GetItemDefinitionByIndex(iMusicKitDefIndex, xDef))
			{
				PrintToChat(client, "\x01* Game soundtrack set to: \x03%s", xDef.m_sName);
			}
		}

		m_iMusicKit[client] = iKitID;
		m_iCurrentEvent[client] = -1;
		m_iNextEvent[client] = -1;
		BufferFlush(client);
	}
}

public void MusicKit_SetKit(int client, int defid, char[] name)
{
	int iKitID = GetKitIndexByDefID(defid);

	if(iKitID != m_iMusicKit[client])
	{
		if(iKitID == -1)
		{
			PrintToChat(client, "\x01* Game soundtrack removed.", name);
		} else {
			PrintToChat(client, "\x01* Game soundtrack set to: %s", name);
		}
	}

	m_iMusicKit[client] = iKitID;
	m_iCurrentEvent[client] = -1;
	m_iNextEvent[client] = -1;
	BufferFlush(client);
}

public int PrecacheSoundtrackKeyValues(KeyValues hConf)
{
	// Getting Definition Index of the kit.
	char sIndex[11];
	hConf.GetSectionName(sIndex, sizeof(sIndex));
	int iDefIndex = StringToInt(sIndex);

	char sName[128];
	hConf.GetString("name", sName, sizeof(sName));

	int iIndex = m_hKitDefs.Length;
	Soundtrack_t hKit;
	hKit.m_iDefIndex = iDefIndex;

	if(hConf.JumpToKey("logic", false))
	{
		// Setting Win and Lose music.
		hConf.GetString("broadcast/win", hKit.m_sWinMusic, sizeof(hKit.m_sWinMusic));
		hConf.GetString("broadcast/loss", hKit.m_sLossMusic, sizeof(hKit.m_sLossMusic));

		if(hConf.JumpToKey("events", false))
		{
			if(hConf.GotoFirstSubKey())
			{
				do {
					int iEvent = PrecacheEventKeyValues(hConf);
					// Add to array.

					hKit.m_iEvents[hKit.m_iEventsCount] = iEvent;
					hKit.m_iEventsCount++;

				} while (hConf.GotoNextKey());
				hConf.GoBack();
			}
			hConf.GoBack();
		}
		hConf.GoBack();
	}

	m_hKitDefs.PushArray(hKit);

	return iIndex;
}

public int PrecacheEventKeyValues(KeyValues hConf)
{
	int iIndex = m_hEventDefs.Length;
	Event_t hEvent;

	hEvent.m_iPriority = hConf.GetNum("priority", 0);

	hEvent.m_bFireOnce = hConf.GetNum("fire_once") >= 1;
	hEvent.m_bForceStart = hConf.GetNum("force_start") >= 1;
	hEvent.m_bForceStop = hConf.GetNum("force_stop") >= 1;
	hEvent.m_bSkipPost = hConf.GetNum("skip_post") >= 1;

	hConf.GetString("start_hook", hEvent.m_sStartHook, sizeof(hEvent.m_sStartHook));
	hConf.GetString("stop_hook", hEvent.m_sStopHook, sizeof(hEvent.m_sStopHook));
	hConf.GetString("id", hEvent.m_sID, sizeof(hEvent.m_sID));

	hEvent.m_iPreSample = -1;
	hEvent.m_iPostSample = -1;

	if(hConf.JumpToKey("pre_sample", false))
	{
		hEvent.m_iPreSample = PrecacheSampleKeyValues(hConf);
		hConf.GoBack();
	}

	if(hConf.JumpToKey("post_sample", false))
	{
		hEvent.m_iPostSample = PrecacheSampleKeyValues(hConf);
		hConf.GoBack();
	}

	if(hConf.JumpToKey("samples", false))
	{
		if(hConf.GotoFirstSubKey())
		{
			do {
				int iSample = PrecacheSampleKeyValues(hConf);

				hEvent.m_iSamples[hEvent.m_iSamplesCount] = iSample;
				hEvent.m_iSamplesCount++;

			} while (hConf.GotoNextKey());
			hConf.GoBack();
		}
		hConf.GoBack();
	}

	m_hEventDefs.PushArray(hEvent);

	return iIndex;
}

public int PrecacheSampleKeyValues(KeyValues hConf)
{
	int iIndex = m_hSampleDefs.Length;
	Sample_t hSample;

	hSample.m_flDuration = hConf.GetFloat("duration");
	hSample.m_flVolume = hConf.GetFloat("volume");

	hConf.GetString("move_to_event", hSample.m_sMoveToEvent, sizeof(hSample.m_sMoveToEvent));
	hConf.GetString("sound", hSample.m_sSound, sizeof(hSample.m_sSound));

	if(!StrEqual(hSample.m_sSound, ""))
	{
		PrecacheSound(hSample.m_sSound);
	}

	hSample.m_nIterations = hConf.GetNum("iterations", 1);
	hSample.m_nMoveToSample = hConf.GetNum("move_to_sample", -1);

	hSample.m_bPreserveSample = hConf.GetNum("preserve_sample", 0) == 1;

	m_hSampleDefs.PushArray(hSample);

	return iIndex;
}

public Action teamplay_broadcast_audio(Event hEvent, const char[] szName, bool bDontBroadcast)
{
	int iTeam = hEvent.GetInt("team");
	char sOldSound[MAX_SOUND_NAME];
	hEvent.GetString("sound", sOldSound, sizeof(sOldSound));

	bool bWillOverride = false;
	if (StrContains(sOldSound, "YourTeamWon") != -1)bWillOverride = true;
	if (StrContains(sOldSound, "YourTeamLost") != -1)bWillOverride = true;

	if (!bWillOverride)return Plugin_Continue;

	for (int i = 1; i < MaxClients; i++)
	{
		if (!IsClientReady(i))continue;
		if (GetClientTeam(i) != iTeam)continue;

		char sSound[MAX_SOUND_NAME];

		Soundtrack_t hKit;
		if(GetClientKit(i, hKit))
		{
			if(StrContains(sOldSound, "YourTeamWon") != -1)
			{
				strcopy(sSound, sizeof(sSound), hKit.m_sWinMusic);
			}

			if(StrContains(sOldSound, "YourTeamLost") != -1)
			{
				strcopy(sSound, sizeof(sSound), hKit.m_sLossMusic);
			}
		}

		// FireToClient DOES NOT CLOSE THE HANDLE, so we run event.Cancel() after we're done
		if(StrEqual(sSound, ""))
		{
			hEvent.FireToClient(i);
			hEvent.Cancel();

		} else {
			Event hNewEvent = CreateEvent("teamplay_broadcast_audio");
			if (hNewEvent == null)continue;

			hNewEvent.SetInt("team", iTeam);
			hNewEvent.SetInt("override", 1);
			hNewEvent.SetString("sound", sSound);
			hNewEvent.FireToClient(i);
			hNewEvent.Cancel();
		}
	}

	return Plugin_Handled;
}

public int GetKitIndexByDefID(int defid)
{
	for (int i = 0; i < m_hKitDefs.Length; i++)
	{
		Soundtrack_t xKit;
		m_hKitDefs.GetArray(i, xKit);
		if (xKit.m_iDefIndex == defid)return i;
	}
	return -1;
}

public bool GetKitByIndex(int id, Soundtrack_t hKit)
{
	if(id >= m_hKitDefs.Length || id < 0) return false;
	m_hKitDefs.GetArray(id, hKit);
	return true;
}

public bool GetEventByIndex(int id, Event_t hEvent)
{
	if(id >= m_hEventDefs.Length || id < 0) return false;
	m_hEventDefs.GetArray(id, hEvent);
	return true;
}

public bool GetSampleByIndex(int id, Sample_t hSample)
{
	if(id >= m_hSampleDefs.Length || id < 0) return false;
	m_hSampleDefs.GetArray(id, hSample);
	return true;
}

public int GetEventIndexByKitAndID(int kit, char[] id)
{
	Soundtrack_t hKit;
	GetKitByIndex(kit, hKit);

	for (int i = 0; i < hKit.m_iEventsCount; i++)
	{
		int iEventIndex = hKit.m_iEvents[i];

		Event_t hEvent;
		if(GetEventByIndex(iEventIndex, hEvent))
		{
			if (StrEqual(hEvent.m_sID, ""))continue;
			if (StrEqual(hEvent.m_sID, id))return iEventIndex;
		}
	}

	return -1;
}

public bool GetClientKit(int client, Soundtrack_t hKit)
{
	if (!IsClientReady(client))return false;
	if (m_iMusicKit[client] < 0)return false;

	if (!GetKitByIndex(m_iMusicKit[client], hKit))return false;
	return true;
}

public void CEcon_OnClientEvent(int client, const char[] event, int add, int unique)
{
	Soundtrack_t hKit;
	if(!GetClientKit(client, hKit)) return;

	for (int i = 0; i < hKit.m_iEventsCount; i++)
	{
		int iEvent = hKit.m_iEvents[i];

		Event_t hEvent;
		GetEventByIndex(iEvent, hEvent);

		// Check if we need to start an event.
		if(StrEqual(hEvent.m_sStartHook, event))
		{
			// If this event is played only once, we skip this.
			if (hEvent.m_bFireOnce && m_iCurrentEvent[client] == iEvent)continue;

			if(m_iCurrentEvent[client] > -1)
			{
				Event_t hOldEvent;
				if(GetEventByIndex(m_iCurrentEvent[client], hOldEvent))
				{
					if(hOldEvent.m_iPriority > hEvent.m_iPriority) continue;
				}
			}

			m_iNextEvent[client] = iEvent;
			m_bForceNextEvent[client] = hEvent.m_bForceStart;
			m_bShouldStop[client] = false;
			break;
		}

		// Start Sample playing.
		if(StrEqual(hEvent.m_sStopHook, event))
		{
			if(m_bIsPlaying[client] && !m_bShouldStop[client])
			{
				m_bShouldStop[client] = true;
				if(hEvent.m_bForceStop)
				{
					m_bIsPlaying[client] = false;
					m_bQueuedSkipped[client] = true;
					PlayNextSample(client);
				}
			}
		}
	}

	PlayNextSample(client);
}

public void PlayNextSample(int client)
{
	if(m_bForceNextEvent[client])
	{
		// Stop everything if we have Force tag set.
		if(m_hTimer[client] != null)
		{
			KillTimer(m_hTimer[client]);
			m_hTimer[client] = null;
		}
		BufferFlush(client);

		m_bForceNextEvent[client] = false;
		m_bIsPlaying[client] = false;
		m_bShouldStop[client] = false;

	} else {
		// Otherwise, return if we're playing something.
		if (m_bIsPlaying[client])
		{
			return;
		}
	}

	Sample_t hSample;
	GetNextSample(client, hSample);

	if(!StrEqual(hSample.m_sSound, "") || hSample.m_bPreserveSample)
	{
		m_bIsPlaying[client] = true;

		if(!StrEqual(hSample.m_sSound, ""))
		{
			if(!StrEqual(m_sActiveSound[client], ""))
			{
				StopSound(client, SNDCHAN_AUTO, m_sActiveSound[client]);
			}

			strcopy(m_sActiveSound[client], sizeof(m_sActiveSound[]), hSample.m_sSound);
			PrecacheSound(hSample.m_sSound);
			EmitSoundToClient(client, hSample.m_sSound);
		}

		float flInterp = GetClientSoundInterp(client);
		float flDelay = hSample.m_flDuration - flInterp;

		m_hTimer[client] = CreateTimer(flDelay, Timer_PlayNextSample, client);
	}
}

public Action Timer_PlayNextSample(Handle timer, any client)
{
	// Play next sample from here only if this timer is the active one.
	if(m_hTimer[client] == timer)
	{
		m_hTimer[client] = INVALID_HANDLE;
		m_bIsPlaying[client] = false;
		PlayNextSample(client);
	}
}


public float GetClientSoundInterp(int client)
{
	return float(TF2_GetNativePing(client)) / 2000.0;
}

public int TF2_GetNativePing(int client)
{
	return GetEntProp(GetPlayerResourceEntity(), Prop_Send, "m_iPing", _, client);
}

public void BufferFlush(int client)
{
	m_iQueueLength[client] = 0;
	m_iQueuePointer[client] = 0;
	m_iCurrentEvent[client] = -1;

	strcopy(m_hPreSample[client].m_sSound, sizeof(m_hPreSample[].m_sSound), "");
	strcopy(m_hPostSample[client].m_sSound, sizeof(m_hPostSample[].m_sSound), "");
}

public void GetNextSample(int client, Sample_t hSample)
{
	// Make sure client exists.
	if (!IsClientValid(client))return;

	// First, we check if we need to switch to next sample.
	// We only do that if post and pre are not set and queue is empty.
	if(m_bShouldStop[client])
	{
		if(StrEqual(m_hPostSample[client].m_sSound, ""))
		{
			BufferFlush(client);
			m_bShouldStop[client] = false;
		} else {
			hSample = m_hPostSample[client];
			strcopy(m_hPostSample[client].m_sSound, MAX_SOUND_NAME, "");
			return;
		}
	}

	if(m_iNextEvent[client] > -1)
	{
		bool bSkipPost = false;

		Event_t CurrentEvent;
		if(GetEventByIndex(m_iNextEvent[client], CurrentEvent))
		{
			bSkipPost = CurrentEvent.m_bSkipPost;
		}

		if(StrEqual(m_hPostSample[client].m_sSound, "") || bSkipPost)
		{
			PrintToConsole(client, "m_iNextEvent, true");
			BufferLoadEvent(client, m_iNextEvent[client]);
			m_iNextEvent[client] = -1;
		} else {
			PrintToConsole(client, "m_iNextEvent, false");
			hSample = m_hPostSample[client];
			strcopy(m_hPostSample[client].m_sSound, MAX_SOUND_NAME, "");
			return;
		}
	}

	if(!StrEqual(m_hPreSample[client].m_sSound, ""))
	{
		PrintToConsole(client, "m_hPreSample");
		hSample = m_hPreSample[client];
		strcopy(m_hPreSample[client].m_sSound, MAX_SOUND_NAME, "");
		return;
	}

	int iPointer = m_iQueuePointer[client];

	// If we have more things to play in the main queue and queue is not skipped.
	if(m_iQueueLength[client] > iPointer && !m_bQueuedSkipped[client])
	{

		// Get currently active sample.
		Sample_t CurrentSample;
		CurrentSample = m_hQueue[client][iPointer];

		// If we run this sample and amount of iterations has exceeded the max amount,
		// we reset the value and run it again.
		if(CurrentSample.m_nCurrentIteration >= CurrentSample.m_nIterations)
		{
			CurrentSample.m_nCurrentIteration = 0;
		}

		//PrintToConsole(client, "m_hSampleQueue, %d, (%d/%d)", m_iCurrentSample[client], sample.m_nCurrentIteration + 1, sample.m_nIterations);

		// Increase current iteration every time we run through it.
		if(CurrentSample.m_nCurrentIteration < CurrentSample.m_nIterations)
		{
			CurrentSample.m_nCurrentIteration++;
		}

		// Update all changed data in the queue.
		m_hQueue[client][iPointer] = CurrentSample;

		// Move to next sample if we reached our limit.
		if(CurrentSample.m_nCurrentIteration == CurrentSample.m_nIterations)
		{
			int iMoveToEvent = GetEventIndexByKitAndID(m_iMusicKit[client], CurrentSample.m_sMoveToEvent);
			if(iMoveToEvent > -1)
			{
				// Check if we need to move to a specific event now.
				m_iNextEvent[client] = iMoveToEvent;
			} else if(CurrentSample.m_nMoveToSample > -1 && CurrentSample.m_nMoveToSample < m_iQueueLength[client])
			{
				// Otherwise check if we need to go to a specific sample.
				// m_iCurrentSample[client] = sample.m_nMoveToSample;
				m_iQueuePointer[client] = CurrentSample.m_nMoveToSample;
			} else {
				// Otherwise, move to next sample.
				m_iQueuePointer[client]++;
			}
		}

		hSample = CurrentSample;
		return;
	}

	if(!StrEqual(m_hPostSample[client].m_sSound, ""))
	{
		hSample = m_hPostSample[client];
		strcopy(m_hPostSample[client].m_sSound, MAX_SOUND_NAME, "");
		return;
	}

	// If we are at this point - nothing is left to play, so we clean up everything.
	BufferFlush(client);
}

public void BufferLoadEvent(int client, int event)
{
	if (!IsClientValid(client))return;
	m_bQueuedSkipped[client] = false;

	Event_t hEvent;
	if (!GetEventByIndex(event, hEvent))return;

	for (int i = 0; i < hEvent.m_iSamplesCount; i++)
	{
		int iEventIndex = hEvent.m_iSamples[i];

		Sample_t hSample;
		GetSampleByIndex(iEventIndex, hSample);

		m_hQueue[client][i] = hSample;
	}
	m_iQueueLength[client] = hEvent.m_iSamplesCount;
	m_iQueuePointer[client] = 0;

	// Loading Pre
	if(!GetSampleByIndex(hEvent.m_iPreSample, m_hPreSample[client]))
	{
		strcopy(m_hPreSample[client].m_sSound, sizeof(m_hPreSample[].m_sSound), "");
	}

	// Loading Post
	if(!GetSampleByIndex(hEvent.m_iPostSample, m_hPostSample[client]))
	{
		strcopy(m_hPostSample[client].m_sSound, sizeof(m_hPostSample[].m_sSound), "");
	}
}

public Action teamplay_round_start(Event hEvent, const char[] szName, bool bDontBroadcast)
{
	StopEventsForAll();
	if(!TF2_IsSetup() && !TF2_IsWaitingForPlayers())
	{
		RequestFrame(PlayRoundStartMusic, hEvent);
	}
}

public void PlayRoundStartMusic(any hEvent)
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if(IsClientReady(i))
		{
			CEcon_SendEventToClientFromGameEvent(i, "OST_ROUND_START", 1, hEvent);
		}
	}
}

public void StopEventsForAll()
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientValid(i))continue;
		if(m_bIsPlaying[i])
		{
			// Otherwise, queue a stop.

			// Play null sound to stop current sample.
			StopSound(i, SNDCHAN_AUTO, m_sActiveSound[i]);
			strcopy(m_sActiveSound[i], sizeof(m_sActiveSound[]), "");

			// Stop everything if we have Force tag set.
			if(m_hTimer[i] != null)
			{
				KillTimer(m_hTimer[i]);
				m_hTimer[i] = null;
			}
			BufferFlush(i);

			m_bForceNextEvent[i] = false;
			m_bIsPlaying[i] = false;
			m_bShouldStop[i] = false;
		}
		m_iNextEvent[i] = -1;
	}
}


public Action teamplay_round_win(Event hEvent, const char[] szName, bool bDontBroadcast)
{
	MvM_DisableDangerMode();

	int iWinReason = GetEventInt(hEvent, "winreason");
	if(m_nPayloadStage == 2 && iWinReason == 1)
	{
		for (int i = 1; i <= MaxClients; i++)
		{
			if(IsClientReady(i))
			{
				CEcon_SendEventToClientFromGameEvent(i, "OST_PAYLOAD_CLIMAX", 1, hEvent);
			}
		}
	}
}

public Action mvm_wave_complete(Event hEvent, const char[] szName, bool bDontBroadcast)
{
	MvM_DisableDangerMode();
}

public Action Timer_EscordProgressUpdate(Handle timer, any data)
{
	static float flOld = 0.0;
	float flNew = Payload_GetProgress();

	if(flOld != flNew)
	{
		switch(m_nPayloadStage)
		{
			case 0:
			{
				if(flNew >= PAYLOAD_STAGE_1_START)
				{
					for (int i = 1; i <= MaxClients; i++)
					{
						if(IsClientReady(i))
						{
							CEcon_SendEventToClientUnique(i, "OST_PAYLOAD_S1_START", 1);
						}
					}
					m_nPayloadStage = 1;
				}
			}
			case 1:
			{
				if(flNew >= PAYLOAD_STAGE_2_START)
				{
					for (int i = 1; i <= MaxClients; i++)
					{
						if(IsClientReady(i))
						{
							CEcon_SendEventToClientUnique(i, "OST_PAYLOAD_S2_START", 1);
						}
					}
					m_nPayloadStage = 2;
				}

				if(flNew < PAYLOAD_STAGE_1_START)
				{
					for (int i = 1; i <= MaxClients; i++)
					{
						if(IsClientReady(i))
						{
							CEcon_SendEventToClientUnique(i, "OST_PAYLOAD_S1_CANCEL", 1);
						}
					}
					m_nPayloadStage = 0;
				}
			}
			case 2:
			{
				if(flNew < PAYLOAD_STAGE_1_START)
				{
					for (int i = 1; i <= MaxClients; i++)
					{
						if(IsClientReady(i))
						{
							CEcon_SendEventToClientUnique(i, "OST_PAYLOAD_S2_CANCEL", 1);
						}
					}
					m_nPayloadStage = 0;
				}
			}
		}
		flOld = flNew;
	}
}

public float Payload_GetProgress()
{
	int iEnt = -1;
	float flProgress = 0.0;
	while((iEnt = FindEntityByClassname(iEnt, "team_train_watcher")) != -1 )
	{
		if (IsValidEntity(iEnt))
		{
			// If cart is of appropriate team.
			float flProgress2 = GetEntPropFloat(iEnt, Prop_Send, "m_flTotalProgress");
			if (flProgress < flProgress2)flProgress = flProgress2;
		}
	}
	return flProgress;
}

public Action teamplay_point_captured(Handle hEvent, const char[] szName, bool bDontBroadcast)
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientReady(i))continue;

		CEcon_SendEventToClientFromGameEvent(i, "OST_POINT_CAPTURE", 1, hEvent);
	}
}

public void OnEntityOutput(const char[] output, int caller, int activator, float delay)
{
	if (TF2_IsWaitingForPlayers())return;

	// Round almost over.
	if (strcmp(output, "On30SecRemain") == 0)
	{
		if (TF2_IsSetup())return;

		m_iRoundTime = 29;
		CreateTimer(1.0, Timer_Countdown, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
	}

	// Setup
	if (strcmp(output, "On1MinRemain") == 0)
	{
		if (!TF2_IsSetup())return;

		m_iRoundTime = 59;
		CreateTimer(1.0, Timer_Countdown, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
	}
}

public bool TF2_IsWaitingForPlayers()
{
	return GameRules_GetProp("m_bInWaitingForPlayers") == 1;
}

public bool TF2_IsSetup()
{
	return GameRules_GetProp("m_bInSetup") == 1;
}

public Action Timer_Countdown(Handle timer, any data)
{
	if (m_iRoundTime < 1) return Plugin_Stop;

	if(TF2_IsSetup() && m_iRoundTime == 45)
	{
		for (int i = 1; i <= MaxClients; i++)
		{
			if(IsClientReady(i))
			{
				CEcon_SendEventToClientUnique(i, "OST_ROUND_SETUP", 1);
			}
		}
	}

	if(!TF2_IsSetup() && m_iRoundTime == 20)
	{
		for (int i = 1; i <= MaxClients; i++)
		{
			if(IsClientReady(i))
			{
				CEcon_SendEventToClientUnique(i, "OST_ROUND_ALMOST_END", 1);
			}
		}
	}

	m_iRoundTime--;
	return Plugin_Continue;
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

public int FindTargetBySteamID(const char[] steamid)
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

public bool IsEntityValid(int entity)
{
	return entity > 0 && entity < 2049 && IsValidEntity(entity);
}
