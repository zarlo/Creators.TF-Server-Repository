#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>

public Plugin myinfo =
{
    name        = "No Auto-Kick for Admins",
    author      = "steph",
    description = "Prevent admins from getting autokicked",
    version     = "0.0.1",
    url         = "https://sappho.io"
};

public void OnPluginStart()
{
    for (int client = 1; client <= MaxClients; client++)
    {
        CheckIfAdmin(client);
    }
}

public void OnClientPostAdminCheck(int client)
{
    CheckIfAdmin(client);
}

void CheckIfAdmin(int client)
{
    if (IsValidClient(client))
    {
        int flags = GetUserFlagBits(client);
        if (flags & ADMFLAG_ROOT || flags & ADMFLAG_GENERIC)
        {
            int id = GetClientUserId(client);
            ServerCommand("mp_disable_autokick %i", id);
        }
    }
}

bool IsValidClient(int client)
{
    return
    (
        (0 < client <= MaxClients)
        && IsClientInGame(client)
        && !IsFakeClient(client)
    );
}
