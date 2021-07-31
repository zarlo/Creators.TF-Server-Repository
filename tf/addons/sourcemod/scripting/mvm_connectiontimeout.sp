#pragma semicolon 1

#define PLUGIN_AUTHOR "Nanochip"
#define PLUGIN_VERSION "1.0"

#include <sourcemod>
#include <tf2_stocks>


public Plugin myinfo =
{
	name = "[TF2-MvM] Connection Timeout",
	author = PLUGIN_AUTHOR,
	description = "Kicks people that are taking too long to connect.",
	version = PLUGIN_VERSION,
	url = "http://steamcommunity.com/id/xnanochip"
};

ConVar cvTime;

public void OnPluginStart()
{
	cvTime = CreateConVar("connectiontimeout_time", "300.0", "After a player is taking too long to connect, they will be kicked after this many seconds.");
}

public void OnMapStart()
{
	if (GameRules_GetProp("m_bPlayingMannVsMachine") == 0)
	{
		Handle plugin = GetMyHandle();
		char namePlugin[256];
		GetPluginFilename(plugin, namePlugin, sizeof(namePlugin));
		ServerCommand("sm plugins unload %s", namePlugin);
	}
}

public void OnClientConnected(int client)
{
	CreateTimer(cvTime.FloatValue, Timer_ConnectionTimeout, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
}

public Action Timer_ConnectionTimeout(Handle timer, any data)
{	
	int client = GetClientOfUserId(data);
	if (client > 0 && client <= MaxClients && !IsClientInGame(client))
	{
		KickClient(client, "Connection timeout: creators.tf/assetpack");
	}
}