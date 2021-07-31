#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <tf2>

#pragma semicolon 1
#pragma newdecls required

ConVar g_cvEnabled;

public Plugin myinfo =
{
	name = "Soldier Statue Spawner",
	author = "Creators.TF Team",
	description = "Spawns Soldier Statue",
	version = "1.0",
	url = "https://creators.tf"
};

public void OnMapStart()
{
	if (!TF2_IsHolidayActive(TFHoliday_Soldier))
	{
		return;
	}
	char sLoc[96];
	BuildPath(Path_SM, sLoc, sizeof(sLoc), "configs/soldier_spawner.cfg");
	KeyValues kv = new KeyValues("Spawner");
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

		Entity_Create(flPos, flScale, flRotate);
	}
	delete kv;
}

public void Entity_Create(float flPos[3], float flScale, float flRotate)
{
	int iEnt;
	iEnt = CreateEntityByName("entity_soldier_statue");
	if(iEnt > 0)
	{
		float flAng[3];
		flPos[2] -= 2.0;
		flAng[1] = flRotate;
		TeleportEntity(iEnt, flPos, flAng, NULL_VECTOR);
		DispatchSpawn(iEnt);
		ActivateEntity(iEnt);
	}
}
