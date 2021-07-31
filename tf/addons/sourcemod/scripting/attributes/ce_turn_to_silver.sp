#pragma semicolon 1
#pragma newdecls required

#include <cecon>
#include <cecon_items>
#include <sdktools>
#include <tf2_stocks>

#define SILVER1 "weapons/saxxy_impact_gen_03.wav"
#define SILVER2 "weapons/saxxy_turntogold_05.wav"
#define SILVER3 "weapons/saxxy_impact_gen_06.wav"

public Plugin myinfo =
{
	name = "[CE Attribute] turn to silver",
	author = "Creators.TF Team",
	description = "turns ragdolls to silver",
	version = "1.00",
	url = "https://creators.tf"
};

bool g_bTurnsToSilver[2049];
bool g_bShouldBeSilver[MAXPLAYERS+1];

public void OnPluginStart()
{
	HookEvent("player_death", OnPlayerDeath);
}

public void OnMapStart()
{
	PrecacheSound(SILVER1);
	PrecacheSound(SILVER2);
	PrecacheSound(SILVER3);
}

public void OnEntityCreated(int ent, const char[] strClassname)
{
	if (ent < 0) return;
	g_bTurnsToSilver[ent] = false;

	if (strcmp(strClassname, "tf_ragdoll") == 0)
	{
		RequestFrame(RemoveBody, ent);
	}
}

public void RemoveBody(any ent)
{
	if (IsValidEntity(ent))
	{
		if (!HasEntProp(ent, Prop_Send, "m_iPlayerIndex"))
		{
			return;
		}
		int client = GetEntProp(ent, Prop_Send, "m_iPlayerIndex");
		if (IsValidClient(client) && g_bShouldBeSilver[client])
		{
			RemoveEntity(ent);
			CreateSilverBody(client);
		}
	}
}

public void OnPlayerDeath(Event ev, const char[] name, bool dontBroadcast)
{
	int attacker = GetClientOfUserId(ev.GetInt("attacker"));
	int client = GetClientOfUserId(ev.GetInt("userid"));
	if (client == attacker || !IsValidClient(attacker) || !IsValidClient(client)) return;

	int weapon = CEcon_GetLastUsedWeapon(attacker);
	if (IsValidEntity(weapon) && g_bTurnsToSilver[weapon])
	{
		g_bShouldBeSilver[client] = true;

		switch(GetRandomInt(1, 3))
		{
			case 1: EmitSoundToAll(SILVER1, client, SNDCHAN_AUTO, 100);
			case 2: EmitSoundToAll(SILVER2, client, SNDCHAN_AUTO, 100);
			case 3: EmitSoundToAll(SILVER3, client, SNDCHAN_AUTO, 100);
		}
	}
}

public void CreateSilverBody(int client)
{
	int ragdoll = CreateEntityByName("tf_ragdoll");

	int team = GetClientTeam(client);
	int class = view_as<int>(TF2_GetPlayerClass(client));
	float pos[3], ang[3], vel[3];

	GetClientAbsOrigin(client, pos);
	GetClientAbsAngles(client, ang);
	GetEntPropVector(client, Prop_Data, "m_vecVelocity", vel);

	TeleportEntity(ragdoll, pos, ang, vel);

	SetEntProp(ragdoll, Prop_Send, "m_iPlayerIndex", client);
	SetEntProp(ragdoll, Prop_Send, "m_bIceRagdoll", 1);
	SetEntProp(ragdoll, Prop_Send, "m_iTeam", team);
	SetEntProp(ragdoll, Prop_Send, "m_iClass", class);
	SetEntProp(ragdoll, Prop_Send, "m_nForceBone", 1);
	SetEntProp(ragdoll, Prop_Send, "m_bOnGround", 1);

	SetEntPropFloat(ragdoll, Prop_Send, "m_flHeadScale", 1.0);
	SetEntPropFloat(ragdoll, Prop_Send, "m_flTorsoScale", 1.0);
	SetEntPropFloat(ragdoll, Prop_Send, "m_flHandScale", 1.0);

	g_bShouldBeSilver[client] = false;
	DispatchSpawn(ragdoll);
	ActivateEntity(ragdoll);
	SetEntPropEnt(client, Prop_Send, "m_hRagdoll", ragdoll);

	//despawn after 20 seconds
	char info[64];
	Format(info, sizeof info, "OnUser1 !self:kill::20:1");
	SetVariantString(info);
	AcceptEntityInput(ragdoll, "AddOutput");
	AcceptEntityInput(ragdoll, "FireUser1");
}

public void CEconItems_OnItemIsEquipped(int client, int entity, CEItem xItem, const char[] type)
{
	if (strcmp(type, "weapon") != 0) return;
	if (CEconItems_GetEntityAttributeBool(entity, "turn to silver"))
	{
		g_bTurnsToSilver[entity] = true;
	}
}

stock bool IsValidClient(int iClient)
{
    return (iClient > 0 && iClient <= MaxClients);
}
