#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdkhooks>
#include <tf2_stocks>
#include <ce_core>
#include <ce_util>

public Plugin myinfo =
{
	name = "[CE Attribute] bombs stick to players",
	author = "Creators.TF Team",
	description = "bombs stick to players",
	version = "1.00",
	url = "https://creators.tf"
};

public void OnMapStart()
{
}

public void OnPluginStart()
{
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if(StrEqual(classname, "tf_projectile_pipe_remote"))
	{
		RequestFrame(RF_Cursify, entity);
	}
}

public void RF_Cursify(int entity)
{
	int client = GetEntPropEnt(entity, Prop_Send, "m_hThrower");
	if(IsClientValid(client))
	{
		int iLauncher = GetPlayerWeaponSlot(client, 1);
		if(CE_GetAttributeInteger(iLauncher, "bombs stick to players") > 0)
		{
			SDKHook(entity, SDKHook_StartTouch, Pipe_Touch);
		}
	}
}

public void Pipe_Touch(int iPipe, int iClient)
{
	int client = GetEntPropEnt(iPipe, Prop_Send, "m_hThrower");
	if(IsClientValid(iClient) && iClient != client)
	{
		// HACK: Pipes don't have m_bValidatedAttachedEntity, so we have to go in another way.
		
		int iProxy = CreateEntityByName("prop_dynamic");
		if(IsValidEntity(iProxy))
		{
			SetEntityModel(iProxy, "models/player/scout.mdl");
			DispatchSpawn(iProxy);
			
			SetVariantString("!activator");
			AcceptEntityInput(iPipe, "SetParent", iProxy);
			
			SetVariantString("!activator");
			AcceptEntityInput(iProxy, "SetParent", iClient);
		}
	}
}