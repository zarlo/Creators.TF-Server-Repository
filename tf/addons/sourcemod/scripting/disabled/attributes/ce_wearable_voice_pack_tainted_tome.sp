#pragma semicolon 1
#pragma newdecls required

// TODO: Adapt to new econ before Halloween.

#include <sourcemod>
#include <tf2_stocks>
#include <cecon_items>
#include <ce_manager_responses>

#define VOICE_PACK_TAINTED_TOME 1

#define RESPONSE_GET_SOULS "TaintedTime.GetMeSouls"
#define RESPONSE_MORE_SOULS "TaintedTime.GetMoreSouls"
#define RESPONSE_CRAVE_SOULS "TaintedTime.CraveForMore"

#define RESPONSE_MORE_COOLDOWN 180.0
#define RESPONSE_SPAWN_COOLDOWN 240.0

float m_flNextSoulResponse[MAXPLAYERS + 1];
float m_flNextSpawnResponse[MAXPLAYERS + 1];

bool m_bSpawned[MAXPLAYERS + 1];

public Plugin myinfo =
{
	name = "[CE Attribute] wearable voice pack (Tainted Tome)",
	author = "Creators.TF Team",
	description = "wearable voice pack  (Tainted Tome)",
	version = "1.00",
	url = "https://creators.tf"
};

public void OnEconItemNewLevel(int client, int index, const char[] name)
{
	if(!CEconItems_IsClientWearingItem( (client, index)) return;

	int wear = -1;
	while ((wear = FindEntityByClassname(wear, "tf_wearable*")) != -1)
	{
		// Skip all cosmetics that we don't own.
		if (GetEntPropEnt(wear, Prop_Send, "m_hOwnerEntity") != client)continue;

		// Skill all entities that are not econ items.
		if (!CE_IsEntityCustomEcomItem(wear))continue;

		// Skip all items with different index.
		if (CE_GetEntityEconIndex(wear) != index) continue;

		// Skip all items that have a different pack.
		if (CE_GetAttributeInteger(wear, "wearable voice pack") != VOICE_PACK_TAINTED_TOME) continue;

		// Play voice line.
		ClientPlayResponse(client, RESPONSE_CRAVE_SOULS);
		break;
	}
	return;
}

public bool PlayerHasWearableWithVoicePack(int client, int pack)
{
	int wear = -1;
	while ((wear = FindEntityByClassname(wear, "tf_wearable*")) != -1)
	{
		if (GetEntPropEnt(wear, Prop_Send, "m_hOwnerEntity") != client)continue;
		if (!CE_IsEntityCustomEcomItem(wear))continue;
		if (CE_GetAttributeInteger(wear, "wearable voice pack") == pack)return true;
	}
	return false;
}

public void OnPluginStart()
{
	HookEvent("player_death", player_death);
	HookEvent("halloween_soul_collected", halloween_soul_collected);
}

public void CE_OnInventoryApplication(int client, bool full)
{
	if (m_bSpawned[client])return;
	m_bSpawned[client] = true;
	
	if (GetEngineTime() > m_flNextSpawnResponse[client])
	{
		// Tainted Tome
		if(PlayerHasWearableWithVoicePack(client, VOICE_PACK_TAINTED_TOME))
		{
			ClientCommand(client, "playgamesound Quest.Alert");
			ClientPlayResponse(client, RESPONSE_GET_SOULS);
			
			m_flNextSpawnResponse[client] = GetEngineTime() + RESPONSE_SPAWN_COOLDOWN;
		}
	}

	return;
}

public Action halloween_soul_collected(Handle hEvent, const char[] szName, bool bDontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(hEvent, "collecting_player"));

	if (GetEngineTime() < m_flNextSoulResponse[client])return Plugin_Continue;

	// Tainted Tome
	if(PlayerHasWearableWithVoicePack(client, VOICE_PACK_TAINTED_TOME))
	{
		ClientPlayResponse(client, RESPONSE_MORE_SOULS);
		m_flNextSoulResponse[client] = GetEngineTime() + RESPONSE_MORE_COOLDOWN;
	}

	return Plugin_Continue;
}

public Action player_death(Handle hEvent, const char[] szName, bool bDontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(hEvent, "userid"));
	m_bSpawned[client] = false;
}

public void OnClientDisconnect(int client)
{
	FlushClient(client);
}

public void OnClientPostAdminCheck(int client)
{
	FlushClient(client);
}

public void FlushClient(int client)
{
	m_flNextSoulResponse[client] = 0.0;
	m_flNextSpawnResponse[client] = 0.0;
	m_bSpawned[client] = false;
}
