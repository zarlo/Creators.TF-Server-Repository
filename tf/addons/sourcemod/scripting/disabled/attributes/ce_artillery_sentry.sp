#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <cecon>
#include <cecon_items>
#include <tf2_stocks>

#pragma semicolon 1
#pragma newdecls required

public Plugin myinfo = 
{
	name = "[Creators.TF] Artillery Sentry Attribute",
	author = "Creators.TF Team",
	description = "Functionality for a custom sentry gun.",
	version = "1.0",
	url = "https://creators.tf"
};

public void OnPluginStart()
{

}

public void OnEntityCreated(int entity, const char[] classname)
{
	// Hook the entity creation of this new sentry gun.
	if (StrEqual(classname, "obj_sentrygun"))
	{
		SDKHook(entity, SDKHook_Spawn, Sentry_OnSpawn);
	}
}

public Action Sentry_OnSpawn(int iSentryGun)
{
	// Grab the owner of this sentry gun so we can grab their weapon:
	int iBuilder = GetEntPropEnt(iSentryGun, Prop_Send, "m_hBuilder");
	
	if (IsClientValid(iBuilder) && TF2_GetPlayerClass(iBuilder) == TFClass_Engineer)
	{
		// Grab their PDA weapon which is in slot 3:
		int iWeapon = GetPlayerWeaponSlot(iBuilder, 3);
		
		// Does this weapon have the "sentry gun override" attribute?
		if (CEconItems_GetEntityAttributeInteger(iWeapon, "sentry gun override") == 2)
		{
			// Apply custom attributes here. These are specific to the sentry gun itself!
			
			// Set maximum health if there's an increased value.
			int iSentryLevel = GetEntProp(iSentryGun, Prop_Send, "m_iUpgradeLevel");
			switch (iSentryLevel)
			{
				case 1: // Sentry Level 1
				{
					if (CEconItems_GetEntityAttributeInteger(iWeapon, "sentry level 1 max health value") > 1)
						SetEntProp(iSentryGun, Prop_Send, "m_iMaxHealth", CEconItems_GetEntityAttributeInteger(iWeapon, "sentry level 1 max health value"));
				}
				case 2: // Sentry Level 2
				{
					if (CEconItems_GetEntityAttributeInteger(iWeapon, "sentry level 2 max health value") > 1)
						SetEntProp(iSentryGun, Prop_Send, "m_iMaxHealth", CEconItems_GetEntityAttributeInteger(iWeapon, "sentry level 2 max health value"));
				}
				case 3: // Sentry Level 3
				{
					if (CEconItems_GetEntityAttributeInteger(iWeapon, "sentry level 3 max health value") > 1)
						SetEntProp(iSentryGun, Prop_Send, "m_iMaxHealth", CEconItems_GetEntityAttributeInteger(iWeapon, "sentry level 3 max health value"));
				}
			}
			
			PrintToChat(iBuilder, "Constructed Artillery Sentry!");
		}
	}
}

public bool IsClientReady(int client)
{
	if (!IsClientValid(client))return false;
	if (IsFakeClient(client))return false;
	return true;
}

public bool IsClientValid(int client)
{
	if (client <= 0 || client > MaxClients)return false;
	if (!IsClientInGame(client))return false;
	if (!IsClientAuthorized(client))return false;
	return true;
}