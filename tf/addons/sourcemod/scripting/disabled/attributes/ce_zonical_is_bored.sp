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
	name = "[Creators.TF] Plasma Gun",
	author = "Creators.TF Team",
	description = "I'm bored.",
	version = "1.0",
	url = "https://creators.tf"
};

public void OnPluginStart()
{
	
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if(StrEqual(classname, "tf_projectile_sentryrocket"))
	{
		RequestFrame(CreatePlasmaBallEntity, entity);
	}
}

public void CreatePlasmaBallEntity(any iRocket)
{
	// Grab the entity that owns this rocket. It should be a sentry gun:
	int iSentryGun = GetEntPropEnt(iRocket, Prop_Send, "m_hOwnerEntity");

	// Grab the builder:
	int iBuilder = GetEntPropEnt(iSentryGun, Prop_Send, "m_hBuilder");
	
	// Grab their PDA weapon which is in slot 3:
	int iBuilderWeapon = GetPlayerWeaponSlot(iBuilder, 3);
	
	// Are we using this plasma technology(TM)?
	if (CEconItems_GetEntityAttributeInteger(iBuilderWeapon, "plasma sentry gun") != 0)
	{
		// Grab this rockets position:
		float position[3];
		GetEntPropVector(iRocket, Prop_Send, "m_vecOrigin", position);
		
		// Grab this rockets angles:
		float angle[3];
		GetEntPropVector(iRocket, Prop_Send, "m_angRotation", angle);
		
		// Grab this rockets velocity:
		float velocity[3];
		GetEntPropVector(iRocket, Prop_Data, "m_vecVelocity", velocity);
		
		// Double the speed of this ball:
		velocity[0] *= 2;
		velocity[1] *= 2;
		velocity[2] *= 2;
		
		// We don't need this rocket anymore, kill it.
		AcceptEntityInput(iRocket, "Kill");
		
		// Spawn a new plasma ball entity:
		int iPlasmaBall = CreateEntityByName("tf_projectile_mechanicalarmorb");
		DispatchSpawn(iPlasmaBall);
		
		// Set the attributes of this plasma ball.
		SetEntPropFloat(iPlasmaBall, Prop_Send, "m_flModelScale", 0.25);
		SetEntPropEnt(iPlasmaBall, Prop_Send, "m_hOwnerEntity", iSentryGun);
		
		// Punish the sentry gun by taking away more rockets:
		int iNewRocketCount = GetEntProp(iSentryGun, Prop_Send, "m_iAmmoRockets") - 2;
		SetEntProp(iSentryGun, Prop_Send, "m_iAmmoRockets", iNewRocketCount);
		
		
		// Finally, teleport it and set it loose:
		TeleportEntity(iPlasmaBall, position, angle, velocity);
	}
}