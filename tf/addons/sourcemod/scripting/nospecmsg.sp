#pragma semicolon 1

#include <sourcemod>

public Plugin myinfo =
{
    name             =  "no join spec msgs 4 admins",
    author           =  "stephanie",
    description      =  "dont print admins joining spectator events to chat",
    version          =  "0.0.2",
    url              =  "https://steph.anie.dev/"
}

public OnPluginStart()
{
    HookEvent("player_team", ePlayerTeam, EventHookMode_Pre);
}

public Action ePlayerTeam (Event event, const char[] name, bool dontBroadcast)
{
    int team    = GetEventInt(event, "team");
    int oldteam = GetEventInt(event, "oldteam");
    int Cl      = GetClientOfUserId(GetEventInt(event, "userid"));
    if (team == 1 || oldteam == 1)
    {
        if (IsValidClient(Cl))
	{
	    if (CheckCommandAccess(Cl, "sm_ban", ADMFLAG_ROOT))
            {
                SetEventBroadcast(event, true);
            }
        }
    }
}

// IsValidClient stock
bool IsValidClient(int client)
{
    return
    (
        (0 < client <= MaxClients)
        && IsClientInGame(client)
        && !IsClientInKickQueue(client)
        && !IsFakeClient(client)
    );
}

