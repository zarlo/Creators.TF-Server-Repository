#include <sourcemod>
#include <sdkhooks>
#include <tf2_stocks>

#define PLUGIN_VERSION  "1.2"

#pragma newdecls required	// Forces new Transitional Syntax https://wiki.alliedmods.net/SourcePawn_Transitional_Syntax
#pragma semicolon 1			// Forces the compiler to if you don't add a semicolon at the appropiate end of a line

public Plugin myinfo =
{
	name = "MvM Vaccinator/Hot Hand Model Fix",
	author = "Flowaria, Braindawg, mac",
	description = "Removes vaccinator backpack and hot hand from bot models, modified for Potato's MvM servers",
	version = PLUGIN_VERSION,
	url = "https://tinyurl.com/ybjeseao"
};

public void OnEntityCreated(int entity, const char[] classname)
{
	if(StrEqual(classname, "tf_wearable", false) || StrEqual(classname, "tf_weapon_slap", false))
	{
		SDKHook(entity, SDKHook_SpawnPost, CheckVaccinatorBackpack);
	}
}

public void CheckVaccinatorBackpack(int entity)
{
	if(!IsValidEdict(entity))
		return;
	CreateTimer(0.0, ManageVacBackpack, entity);
}

public Action ManageVacBackpack(Handle timer, int entity)
{
	if(!IsValidEdict(entity))
		return;
		
	int client = GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity");
	if(1 <= client <= MaxClients)
	{
		char plmodel[64];
		char classname[32];
		
		GetClientModel(client, plmodel, sizeof(plmodel));
		GetEntityClassname(entity, classname, sizeof(plmodel));
		
		if(StrEqual(plmodel,"models/bots/medic/bot_medic.mdl", false))
		{
			
			int secondary = GetPlayerWeaponSlot(client, TFWeaponSlot_Secondary);
			if(secondary)
			{
				char model[80];
				GetEntPropString(entity, Prop_Data, "m_ModelName", model, sizeof(model));
				
				// Vaccinator model
				if(StrEqual(model, "models/workshop/weapons/c_models/c_medigun_defense/c_medigun_defensepack.mdl", false)) 
				{
					RemoveEdict(entity);
				}
			}	
		}		
		else if(StrEqual(plmodel,"models/bots/pyro/bot_pyro.mdl", false))
		{	
			SetEntProp(entity, Prop_Send, "m_fEffects", 32);
		}
	}
	SDKUnhook(entity, SDKHook_SpawnPost, CheckVaccinatorBackpack);
}