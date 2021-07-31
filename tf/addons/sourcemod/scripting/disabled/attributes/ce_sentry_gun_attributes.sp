#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <cecon>
#include <cecon_items>
#include <tf2_stocks>

#pragma semicolon 1
#pragma newdecls required

#define BLUEPRINT_MODEL "models/buildables/sentry1_blueprint.mdl"

public Plugin myinfo = 
{
	name = "[Creators.TF] Building Model Override",
	author = "Creators.TF Team",
	description = "Functionality for custom sentry guns.",
	version = "1.0",
	url = "https://creators.tf"
};

public void OnPluginStart()
{
	// Upgrade if nessacary:
	HookEvent("player_builtobject", OnBuildObject);
	HookEvent("player_carryobject", OnBuiltCarry);
	HookEvent("player_dropobject", OnDropCarry);
	HookEvent("player_upgradedobject", OnUpgradeObject);
}

public bool CanBuildCustomSentry(int iSentryGun)
{
	// Grab the owner of this sentry gun so we can grab their weapon:
	int iSentryBuilder = GetEntPropEnt(iSentryGun, Prop_Send, "m_hBuilder");

	// Grab their PDA weapon which is in slot 3:
	int iBuilderWeapon = GetPlayerWeaponSlot(iSentryBuilder, 3);
	
	// Grab the model override attribute.
	char attribute_modelName[PLATFORM_MAX_PATH];
	CEconItems_GetEntityAttributeString(iBuilderWeapon, "override sentry model", attribute_modelName, sizeof(attribute_modelName));
	
	// Is a custom model being used?
	if (!StrEqual(attribute_modelName, ""))
	{	
		return true;
	}
	return false;
}

public void SetSentryOverrideModel(int iSentryGun)
{
	// Grab the owner of this sentry gun so we can grab their weapon:
	int iBuilder = GetEntPropEnt(iSentryGun, Prop_Send, "m_hBuilder");
	
	if (IsClientValid(iBuilder) && TF2_GetPlayerClass(iBuilder) == TFClass_Engineer)
	{
		if (CanBuildCustomSentry(iSentryGun))
		{
			// Grab their PDA weapon which is in slot 3:
			int iWeapon = GetPlayerWeaponSlot(iBuilder, 3);
	
			char modelName[PLATFORM_MAX_PATH];
			CEconItems_GetEntityAttributeString(iWeapon, "override sentry model", modelName, sizeof(modelName));
			
			// Grab the current level of the sentry:
			int iUpgradeLevel = GetEntProp(iSentryGun, Prop_Send, "m_iUpgradeLevel");
			PrintToChatAll("SetSentryOverrideModel Upgrade Level %d", iUpgradeLevel);
			
			char sUpgradeLevel[4];
			IntToString(iUpgradeLevel, sUpgradeLevel, sizeof(sUpgradeLevel));
			
			ReplaceString(modelName, sizeof(modelName), "%d", sUpgradeLevel);
			SetEntProp(iSentryGun, Prop_Send, "m_nModelIndexOverrides", PrecacheModel(modelName), 4, 0);
			
		}
		
	}
}

public Action OnUpgradeObject(Handle hEvent, const char[] szName, bool bDontBroadcast)
{
	int iObject = GetEventInt(hEvent, "object");
	PrintToChatAll("OnUpgradeObject %d", iObject);
	int iSentryGun = GetEventInt(hEvent, "index");

	if (iObject == 2)
	{
		// Change the model on the next frame:
		RequestFrame(SetSentryOverrideModel, iSentryGun);
	}
}

public Action SetSentryOverride_GoThroughLevels(Handle timer, int iSentryGun)
{
	static int levels = 1;
	int iUpgradeLevel = GetEntProp(iSentryGun, Prop_Send, "m_iUpgradeLevel");
	PrintToChatAll("SetSentryOverrideModel Ugprade Level %d", iUpgradeLevel);
	
	if (iUpgradeLevel == levels)
	{
		// Grab the owner of this sentry gun so we can grab their weapon:
		int iBuilder = GetEntPropEnt(iSentryGun, Prop_Send, "m_hBuilder");
	
		// Grab their PDA weapon which is in slot 3:
		int iWeapon = GetPlayerWeaponSlot(iBuilder, 3);
		
		// Grab the model override attribute.
		char modelName[PLATFORM_MAX_PATH];
		CEconItems_GetEntityAttributeString(iWeapon, "override sentry model", modelName, sizeof(modelName));
		
		char sUpgradeLevel[4];
		IntToString(iUpgradeLevel, sUpgradeLevel, sizeof(sUpgradeLevel));
		
		// Is a custom model being used?
		if (!StrEqual(modelName, ""))
		{	
			ReplaceString(modelName, sizeof(modelName), "%d", sUpgradeLevel);
			SetEntProp(iSentryGun, Prop_Send, "m_nModelIndexOverrides", PrecacheModel(modelName), 4, 0);
		}
		
		levels++;
		return Plugin_Continue;
	}
	return Plugin_Stop;
}

public Action OnBuildObject(Handle hEvent, const char[] szName, bool bDontBroadcast)
{
	int iObject = GetEventInt(hEvent, "object");
	PrintToChatAll("OnBuildObject %d", iObject);
	int iSentryGun = GetEventInt(hEvent, "index");

	if (iObject == 2)
	{
		// Change the model on the next frame:
		RequestFrame(SetSentryOverrideModel, iSentryGun);
	}
}

public Action OnBuiltCarry(Handle hEvent, const char[] szName, bool bDontBroadcast)
{
	int iObject = GetEventInt(hEvent, "object");
	PrintToChatAll("OnBuiltCarry %d", iObject);
	int iSentryGun = GetEventInt(hEvent, "index");

	if (iObject == 2)
	{
		// This overall checks to see if we're using a custom sentry gun model, and if we should override the model when
		// we pick up the sentry gun, as it automatically doesn't do it for us.
		
		// Grab the owner of this sentry gun so we can grab their weapon:
		int iBuilder = GetEntPropEnt(iSentryGun, Prop_Send, "m_hBuilder");
		
		// Grab their PDA weapon which is in slot 3:
		int iWeapon = GetPlayerWeaponSlot(iBuilder, 3);
		
		// Grab the model override attribute.
		char modelName[PLATFORM_MAX_PATH];
		CEconItems_GetEntityAttributeString(iWeapon, "override sentry model", modelName, sizeof(modelName));
	
		// Is a custom model being used?
		if (!StrEqual(modelName, ""))
		{
			SetEntProp(iSentryGun, Prop_Send, "m_nModelIndexOverrides", PrecacheModel(BLUEPRINT_MODEL), 4, 0);
		}
	}
}

public Action OnDropCarry(Handle hEvent, const char[] szName, bool bDontBroadcast)
{
	int iObject = GetEventInt(hEvent, "object");
	int iSentryGun = GetEventInt(hEvent, "index");

	if (iObject == 1)
	{
		// Change the model on the next frame:
		if (GameRules_GetProp("m_bPlayingMannVsMachine") == 0)
		{
			CreateTimer(2.0, SetSentryOverride_GoThroughLevels, iSentryGun, TIMER_REPEAT);
		}
	}
}

public bool IsClientValid(int client)
{
	if (client <= 0 || client > MaxClients)return false;
	if (!IsClientInGame(client))return false;
	if (!IsClientAuthorized(client))return false;
	return true;
}