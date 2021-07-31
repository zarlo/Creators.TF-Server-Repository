#pragma semicolon 1
#pragma newdecls required
#pragma tabsize 0

#define PLUGIN_AUTHOR "Creators.TF Team"
#define PLUGIN_VERSION "1.0"

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

#define PROP_MODEL "models/bots/boss_bot/carrier.mdl"

public Plugin myinfo =
{
	name = "Skybox Prop Spawner",
	author = PLUGIN_AUTHOR,
	description = "Spawns Props in Map's Skyboxes",
	version = PLUGIN_VERSION,
	url = "https://creators.tf"
};

public void OnPluginStart()
{
	HookEvent("teamplay_round_start", evRoundStart);
	RegAdminCmd("sm_skyprop_test", sm_skyprop_test, ADMFLAG_GENERIC);
}

public Action sm_skyprop_test(int client, int args)
{
	int iProp = -1;
	while ((iProp = FindEntityByClassname(iProp, "prop_dynamic")) != -1)
	{
		char tName[16];
		GetEntPropString(iProp, Prop_Data, "m_iName", tName, 16);
		if (StrEqual(tName, "tf_skyprop"))
		{
			RemoveEntity(iProp);
		}
	}
	
	float flRotation = 0.0;
	float flScale = 0.1;
	
	char sBuff[11];
	GetCmdArg(1, sBuff, sizeof(sBuff));
	flRotation = StringToFloat(sBuff);
	GetCmdArg(2, sBuff, sizeof(sBuff));
	flScale = StringToFloat(sBuff);
	
	if (flScale < 0.1)flScale = 0.1;
	
	char sMap[64];
	GetCurrentMap(sMap, sizeof(sMap));
	if (StrContains(sMap, "workshop") != -1)
	{
		GetMapDisplayName(sMap, sMap, sizeof sMap);
	}
	
	float flPos[3];
	GetEntPropVector(client, Prop_Send, "m_vecOrigin", flPos);
	PrintToConsole(client, "\"%s\"\n{\n 	\"x\" \"%f\"\n 	\"y\" \"%f\"\n 	\"z\" \"%f\"\n	\"r\" \"%f\"\n	\"s\" \"%f\"\n}", sMap, flPos[0], flPos[1], flPos[2], flRotation, flScale);
	Prop_Create(flPos, flRotation, flScale);
}

public void OnMapStart()
{
	PrecacheModel(PROP_MODEL);
}

public Action evRoundStart(Event hEvent, const char[] szName, bool bDontBroadcast)
{
	char sLoc[96];
	BuildPath(Path_SM, sLoc, 96, "configs/skybox_props.cfg");
	KeyValues kv = new KeyValues("Props");
	kv.ImportFromFile(sLoc);

	char sMap[64];
	GetCurrentMap(sMap, sizeof(sMap));

	if(kv.JumpToKey(sMap))
	{
		float flPos[3];
		float flScale = kv.GetFloat("s", 0.1);
		flPos[0] = kv.GetFloat("x", 0.0);
		flPos[1] = kv.GetFloat("y", 0.0);
		flPos[2] = kv.GetFloat("z", 0.0);
		float flRotate = kv.GetFloat("r", 0.0);

		Prop_Create(flPos, flScale, flRotate);
	}
	delete kv;
}

public void Prop_Create(float flPos[3], float flScale, float flRotate)
{
	int iCitadel;
	iCitadel = CreateEntityByName("prop_dynamic_override");
	if(iCitadel > 0)
	{
		float flAng[3];
		flAng[1] = flRotate;
		TeleportEntity(iCitadel, flPos, flAng, NULL_VECTOR);
		SetEntityModel(iCitadel, PROP_MODEL);
		SetEntPropFloat(iCitadel, Prop_Send, "m_flModelScale", flScale);
		DispatchKeyValue(iCitadel, "targetname", "tf_skyprop");
		DispatchSpawn(iCitadel);
		ActivateEntity(iCitadel);
	}
}
