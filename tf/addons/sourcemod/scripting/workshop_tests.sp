#include <sourcemod>
#include <mapnames>

#pragma semicolon 1
#pragma newdecls required

#define PLUGIN_VERSION "1.0.0"

public Plugin myinfo =
{
	name = "[TF2] Workshop Tests",
	author = "Nanochip",
	description = "",
	version = PLUGIN_VERSION,
	url = "https://steamcommunity.com/id/xNanochip/"
};

public void OnPluginStart()
{
	RegAdminCmd("sm_testmapnames", sm_testmapnames, ADMFLAG_RCON);
	RegAdminCmd("sm_bagel", sm_bagel, ADMFLAG_RCON);
	RegAdminCmd("sm_maptest", sm_maptest, ADMFLAG_RCON);
}

public Action sm_testmapnames(int client, int args)
{
	TestMapNames();
}

public Action sm_bagel(int client, int args)
{
	char map[64];
	GetMapDisplayName("workshop/2056802978", map, sizeof map);
	PrintToServer(map);
}

public Action sm_maptest(int client, int args)
{
	char arg1[64], arg2[16], map[PLATFORM_MAX_PATH], display[PLATFORM_MAX_PATH];
	GetCmdArg(1, arg1, sizeof arg1);
	GetCmdArg(2, arg2, sizeof arg2);
	//bool foundMap = false;
	if (FindMap(arg1, map, sizeof map) != FindMap_NotFound)
	{
		PrintToServer("Found Map: %s", map);
		//foundMap = true;
	}
	else
	{
		PrintToServer("Didn't find map.");
	}
	GetMapDisplayName(map, display, sizeof display);
	PrintToServer("Display Name: %s", display);
	GetPrettyMapName(display, display, sizeof display);
	PrintToServer("Pretty Name: %s", display);
	if (StrEqual(arg2, "1")) ForceChangeLevel(map, "Map Test");
	
	return Plugin_Handled;
}

public void OnMapStart()
{
	TestMapNames();
}

void TestMapNames()
{
	char map[64];
	GetCurrentMap(map, sizeof map);
	PrintToServer("GetCurrentMap: %s", map);
	
	GetMapDisplayName(map, map, sizeof map);
	PrintToServer("GetMapDisplayName: %s", map);
}
