#include <sourcemod>
#include <sdkhooks>
#include <sdktools>

#pragma semicolon 1

#define PLUGIN_VERSION "1.0"

public Plugin myinfo =
{
	name = "Remove Pl_Camber Easter Egg",
	author = "Nanochip",
	description = "Removes the hitsound ding from blu spawn.",
	version = PLUGIN_VERSION,
	url = "https://steamcommunity.com/id/xNanochip/"
};

bool g_bCamber;

public void OnMapStart()
{
	char map[64];
	GetCurrentMap(map, sizeof(map));
	if (StrContains(map, "pl_camber") != -1) g_bCamber = true;
	else g_bCamber = false;
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if (g_bCamber && strcmp(classname, "ambient_generic") == 0)
	{
		SDKHook(entity, SDKHook_SpawnPost, OnSoundSpawn);
	}
}

public void OnSoundSpawn(int entity)
{
	if (IsValidEntity(entity))
	{
		char name[32];
		GetEntPropString(entity, Prop_Data, "m_iName", name, sizeof(name));
		if (StrContains(name, "ding") != -1)
		{
			RemoveEntity(entity);
		}
	}
}