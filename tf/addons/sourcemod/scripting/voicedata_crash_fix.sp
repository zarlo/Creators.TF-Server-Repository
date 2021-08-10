#pragma semicolon 1
#include <sourcemod>
#include <sdktools>
#include <voiceannounce_ex>
#pragma newdecls required

#define PATH            "logs/voicedata_crashfix.log"
#define PLUGIN_VERSION      "1.0.2" 

ConVar maxVoicePackets;
ConVar punishment;

int g_voicePacketCount[MAXPLAYERS+1];
int iPunishMent;
int iMaxVoicePackets;

public Plugin myinfo = 
{
    name = "Voice Data Crash Fix",
    author = "Ember & V1sual",
    description = "Punishes players who are overflowing voice data to crash the server",
    version = PLUGIN_VERSION,
    url = ""
};

public void OnPluginStart()
{
    punishment = CreateConVar("sm_voicedatafix_punishment", "1", "Punishment. 1 = Kick, 2 = Perm ban", _, true, 1.0, true, 2.0);
    maxVoicePackets = CreateConVar("sm_voicedatafix_count", "92", "How many packets per second max?", FCVAR_PROTECTED);

    iPunishMent = punishment.IntValue;
    iMaxVoicePackets = maxVoicePackets.IntValue;

    punishment.AddChangeHook(OnConVarHook);
    maxVoicePackets.AddChangeHook(OnConVarHook);
}

public void OnConVarHook(ConVar cvar, const char[] oldVal, const char[] newVal) 
{
    if (cvar == punishment)
    {
        iPunishMent = cvar.IntValue;
    }
    else if (cvar == maxVoicePackets)
    {
        iMaxVoicePackets = cvar.IntValue;
    }
}

public void OnMapStart()
{
    CreateTimer(1.0, ResetCount, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
}

public Action ResetCount(Handle timer)
{
    for (int i = 1; i <= MaxClients; i++)
    {
            g_voicePacketCount[i] = 0;
    }
    
    return Plugin_Continue;
}

public void OnClientSpeakingEx(int client)
{
    if (++g_voicePacketCount[client] > iMaxVoicePackets) 
    {
        SetClientListeningFlags(client, VOICE_MUTED);

        char id[64], ip[32];

        GetClientAuthId(client, AuthId_Steam2, id, sizeof(id));  
        GetClientIP(client, ip, sizeof(ip));

        LogToPluginFile("%N (ID: %s | IP: %s) was %s for trying to crash the server with voice data overflow. Total packets: %i", 
        client, 
        id, 
        ip, 
        punishment.IntValue == 1 ? "kicked" : "banned", 
        g_voicePacketCount[client]);
        
        switch (iPunishMent)
        {
            case 1:
            {
                if (!IsClientInKickQueue(client))
                {
                    KickClient(client, "Voice data overflow detected!");
                }
            }
            case 2:
            {
                ServerCommand("sm_ban #%d 0 \"Voice data overflow detected!\"", GetClientUserId(client));
            }
        }
    }
}

stock void LogToPluginFile(const char[] format, any:...)
{
    char f_sBuffer[1024], f_sPath[1024];
    VFormat(f_sBuffer, sizeof(f_sBuffer), format, 2);
    BuildPath(Path_SM, f_sPath, sizeof(f_sPath), PATH);
    LogToFile(f_sPath, "%s", f_sBuffer);
}