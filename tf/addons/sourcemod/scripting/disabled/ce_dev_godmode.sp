#pragma semicolon 1
#pragma newdecls required

#include <sdkhooks>
#include <cecon_items>

public Plugin myinfo =
{
	name = "[CE Attribute] Developer Testing - Godmode",
	author = "Creators.TF Team",
	description = "zonicals godmode",
	version = "1.00",
	url = "https://creators.tf"
};

/*
	TO-DO: Literally just made this so I can easily test things. Please remove before shipping
	Operation Digital Directive! - ZoNiCaL.
	
	PS: Could there have been an easier way to do this? Maybe, but I'm ZoNiCaL and I always take
	the hardest option.
	
	PPS: Also I mostly stole this from ce_weapon_removes_sappers, thanks to whoever wrote it!
*/


public void OnClientPutInServer(int client)
{
	SDKHook(client, SDKHook_OnTakeDamageAlive, PlayerTakesDamage);
}

public Action PlayerTakesDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype)
{
	int iWeapon = GetEntPropEnt(victim, Prop_Send, "m_hActiveWeapon");
	if (IsValidEntity(iWeapon))
	{
		if (CEconItems_GetEntityAttributeBool(iWeapon, "zonicals godmode"))
		{
			if (damage > 0.0)
			{
				damage = 0.0;
				return Plugin_Handled;
			}
		}
	}
	return Plugin_Changed;
}
