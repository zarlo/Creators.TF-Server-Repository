#pragma semicolon 1 // Force strict semicolon mode.
#pragma newdecls required // use new syntax

#include <sourcemod>
#include <morecolors>

#define PLUGIN_VERSION "1.0.6"

bool STV;

public Plugin myinfo =
{
    name        = "Fix STV Slot",
    author      = "F2, fixed by stephanie",
    description = "When STV is enabled, changes the map so SourceTV joins properly.",
    version     = PLUGIN_VERSION,
    url         = ""
}

public void OnPluginStart()
{
    HookConVarChange(FindConVar("tv_enable"), OnSTVChanged);
}

public void OnSTVChanged(ConVar convar, char[] oldValue, char[] newValue)
{
    STV = GetConVarBool(FindConVar("tv_enable"));
    if (STV)
    {
        LogMessage("[FixSTVSlot] tv_enable changed to 1! Changing level!");
        MC_PrintToChatAll("{purple}[FixSTVSlot]{white} tv_enable changed to 1! Changing level!");
        CreateTimer(1.0, changein1);
    }
    else
    {
        LogMessage("[FixSTVSlot] tv_enable changed to 0!");
    }
}

public Action changein1(Handle timer)
{
    char mapName[128];
    GetCurrentMap(mapName, sizeof(mapName));
    ForceChangeLevel(mapName, "STV joined! Forcibly changing level");
}
