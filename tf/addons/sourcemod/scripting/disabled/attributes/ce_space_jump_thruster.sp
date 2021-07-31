#pragma semicolon 1
#pragma newdecls required

#include <sdkhooks>
#include <cecon_items>
#include <tf2_stocks>

public Plugin myinfo =
{
	name = "[CE Attribute] space jump thruster",
	author = "Creators.TF Team",
	description = "space jump thruster",
	version = "1.00",
	url = "https://creators.tf"
}

#define SPACE_JUMP_THRUST_SOUND_START "Weapon_RocketPack.BoostersCharge"
#define SPACE_JUMP_THRUST_SOUND_END "Weapon_RocketPack.BoostersShutdown"
#define SPACE_JUMP_THRUST_SOUND_LOOP "Weapon_RocketPack.BoostersLoop"
#define SPACE_JUMP_THRUST_SOUND_LOOP_END "Weapon_RocketPack.BoostersLoopEnd"
#define SPACE_JUMP_THRUST_SOUND_FAILED "Weapon_RocketPack.BoostersNotReady"
#define SPACE_JUMP_THRUST_MIN_CHARGE_TO_LAUNCH 10.0

#define CHAR_FULL "■"
#define CHAR_EMPTY "□"
#define HUD_RATE 0.01

bool m_bIsSpaceJump[2049];
float m_flSpaceJumpMeter[MAXPLAYERS + 1];
bool m_bIsUsingSpaceJump[MAXPLAYERS + 1];
bool m_bSpaceJumpEquipped[MAXPLAYERS + 1];

ConVar tf_space_jump_use_rate;
ConVar tf_space_jump_recharge_rate;

int m_iLeftThrust[2049];
int m_iRightThrust[2049];

public void OnMapStart()
{
	PrecacheScriptSound(SPACE_JUMP_THRUST_SOUND_START);
	PrecacheScriptSound(SPACE_JUMP_THRUST_SOUND_END);
	PrecacheScriptSound(SPACE_JUMP_THRUST_SOUND_LOOP);
	PrecacheScriptSound(SPACE_JUMP_THRUST_SOUND_LOOP_END);
	PrecacheScriptSound(SPACE_JUMP_THRUST_SOUND_FAILED);
}

public void OnPluginStart()
{
	tf_space_jump_use_rate = CreateConVar("tf_space_jump_use_rate", "0.7", "Space Jump meter use rate");
	tf_space_jump_recharge_rate = CreateConVar("tf_space_jump_recharge_rate", "0.4", "Space Jump meter recharge rate");
	CreateTimer(HUD_RATE, Timer_Think, _, TIMER_REPEAT);
}

public Action Timer_Think(Handle timer, any data)
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientReady(i))continue;
		if (!HasSpaceJumpEquipped(i))continue;

		SpaceJump_DrawHUD(i);
	}
}

public void CEconItems_OnItemIsUnequipped(int client, CEItem xItem, const char[] type)
{
	if(CEconItems_GetAttributeBoolFromArray(xItem.m_Attributes, "space jump thruster"))
	{
		PrintToChatAll("Space jumper is unequipped");
		m_bSpaceJumpEquipped[client] = false;
		EmitGameSoundToAll(SPACE_JUMP_THRUST_SOUND_LOOP_END, client);
	}
}

public void CEconItems_OnItemIsEquipped(int client, int entity, CEItem xItem, const char[] type)
{
	if(CEconItems_GetEntityAttributeBool(entity, "space jump thruster"))
	{
		PrintToChatAll("Space jumper is equipped");
		m_bSpaceJumpEquipped[client] = true;
		
		SpaceJump_Init(entity, client);
		EmitGameSoundToAll(SPACE_JUMP_THRUST_SOUND_LOOP_END, client);
	}
}

public void SpaceJump_Init(int entity, int owner)
{
	m_bIsSpaceJump[entity] = true;
	m_bIsUsingSpaceJump[owner] = false;
	m_flSpaceJumpMeter[owner] = 100.0;
}

public void SpaceJump_DrawHUD(int client)
{
	if (!HasSpaceJumpEquipped(client))return;

	char sHUDText[128];
	char sProgress[32];
	int iPercents = RoundToFloor(GetSpaceJumpCharge(client));
	bool bLow = iPercents <= SPACE_JUMP_THRUST_MIN_CHARGE_TO_LAUNCH;

	for (int j = 1; j <= 10; j++)
	{
		if (iPercents >= j * 10)StrCat(sProgress, sizeof(sProgress), CHAR_FULL);
		else StrCat(sProgress, sizeof(sProgress), CHAR_EMPTY);
	}

	Format(sHUDText, sizeof(sHUDText), "Thrust: %d%%%%   \n%s   ", iPercents, sProgress);

	if(bLow)
	{
		SetHudTextParams(1.0, 0.8, HUD_RATE + 0.1, 255, 0, 0, 255);
	} else {
		SetHudTextParams(1.0, 0.8, HUD_RATE + 0.1, 255, 255, 255, 255);
	}
	ShowHudText(client, -1, sHUDText);
}

public void FlushEntityData(int entity)
{
	m_bIsSpaceJump[entity] = false;
}

public bool IsSpaceJump(int entity)
{
	return m_bIsSpaceJump[entity];
}

public bool HasSpaceJumpEquipped(int client)
{
	return GetSpaceJumpWearable(client) > -1;
}

public int GetSpaceJumpWearable(int client)
{
	int iEdict = -1;
	while((iEdict = FindEntityByClassname(iEdict, "tf_wearable*")) != -1)
	{
		char sClass[32];
		GetEntityNetClass(iEdict, sClass, sizeof(sClass));
		if (!StrEqual(sClass, "CTFWearable"))continue;
		if (GetEntPropEnt(iEdict, Prop_Send, "m_hOwnerEntity") != client)continue;

		if(!IsSpaceJump(iEdict)) continue;
		return iEdict;
	}

	return -1;
}

public float GetSpaceJumpCharge(int client)
{
	return m_flSpaceJumpMeter[client];
}

public float SetSpaceJumpCharge(int client, float value)
{
	if(value < 0.0) value = 0.0;
	if(value > 100.0) value = 100.0;
	m_flSpaceJumpMeter[client] = value;
}

public Action OnPlayerRunCmd(int client, int &buttons)
{
	static bool bIsJumpPressed[MAXPLAYERS + 1];

	if(m_bSpaceJumpEquipped[client])
	{
		bool bIsJumping = buttons & IN_JUMP == IN_JUMP;
		bool bIsOnGround = GetEntityFlags(client) & FL_ONGROUND == FL_ONGROUND;
		bool bHasCharge = GetSpaceJumpCharge(client) > tf_space_jump_use_rate.FloatValue;
		bool bCanLaunch = GetSpaceJumpCharge(client) > SPACE_JUMP_THRUST_MIN_CHARGE_TO_LAUNCH;
		bool bShouldLaunch = false;

		if(m_bIsUsingSpaceJump[client])
		{
			bShouldLaunch = bHasCharge;
		} else {
			bShouldLaunch = bCanLaunch;
		}

		if(bIsJumping && !bIsOnGround && bShouldLaunch)
		{
			float vecVelocity[3];
			float flPower = GetSpaceJumpPowerOfClass(TF2_GetPlayerClass(client));
			GetEntPropVector(client, Prop_Data, "m_vecAbsVelocity", vecVelocity);
			if(flPower > 0.0)
			{
				vecVelocity[2] = 140.0 + flPower;
				SetEntPropVector(client, Prop_Data, "m_vecAbsVelocity", vecVelocity);

				if(!m_bIsUsingSpaceJump[client])
				{
					EmitGameSoundToAll(SPACE_JUMP_THRUST_SOUND_START, client);
					EmitGameSoundToAll(SPACE_JUMP_THRUST_SOUND_LOOP, client);

					// CreateThrustParticle(iJump);
				}
				m_bIsUsingSpaceJump[client] = true;
			}

			SetSpaceJumpCharge(client, GetSpaceJumpCharge(client) - tf_space_jump_use_rate.FloatValue);
		} else {
			if(bIsOnGround)
			{
				SetSpaceJumpCharge(client, GetSpaceJumpCharge(client) + tf_space_jump_recharge_rate.FloatValue);

				if(m_bIsUsingSpaceJump[client])
				{
					EmitGameSoundToAll(SPACE_JUMP_THRUST_SOUND_LOOP_END, client);
					EmitGameSoundToAll(SPACE_JUMP_THRUST_SOUND_END, client);
					m_bIsUsingSpaceJump[client] = false;

					// StopThrustparticle(iJump);
				}
			} else {
				if(m_bIsUsingSpaceJump[client] && !bHasCharge)
				{
					EmitGameSoundToAll(SPACE_JUMP_THRUST_SOUND_END, client);
					EmitGameSoundToAll(SPACE_JUMP_THRUST_SOUND_FAILED, client);
					m_bIsUsingSpaceJump[client] = false;

					// StopThrustparticle(iJump);
				}
			}

			if(bIsJumping && !bCanLaunch && !bIsJumpPressed[client])
			{
				EmitGameSoundToAll(SPACE_JUMP_THRUST_SOUND_FAILED, client);
			}
		}
		bIsJumpPressed[client] = bIsJumping;
	}
}

public float GetSpaceJumpPowerOfClass(TFClassType nClass)
{
	switch(nClass)
	{
		case TFClass_Scout: return 40.0;
		case TFClass_Soldier: return 34.0;
		case TFClass_Pyro: return 35.0;
		case TFClass_DemoMan: return 34.0;
		case TFClass_Heavy: return 30.0;
		case TFClass_Engineer: return 36.0;
		case TFClass_Medic: return 36.0;
		case TFClass_Sniper: return 36.0;
		case TFClass_Spy: return 40.0;
	}
	return 0.0;
}

public void OnEntityCreated(int entity)
{
	if(entity < 0) return;
	FlushEntityData(entity);
}

public void OnEntityDestroyed(int entity)
{
	if(entity < 0) return;
	FlushEntityData(entity);
}

public void CreateThrustParticle(int wearable)
{
	/*
	m_iLeftThrust[wearable] = TF_StartAttachedParticle("rockettrail", "charge_LA", wearable, 1.0);
	m_iRightThrust[wearable] = TF_StartAttachedParticle("rockettrail", "charge_RA", wearable, 1.0);

	int client = GetEntPropEnt(wearable, Prop_Send, "m_hOwnerEntity");

	if(client > 0)
	{
		SetEntPropEnt(m_iLeftThrust[wearable], Prop_Send, "m_hOwnerEntity", client);
		SetEntPropEnt(m_iRightThrust[wearable], Prop_Send, "m_hOwnerEntity", client);
	}*/
}

public void StopThrustparticle(int wearable)
{
	if(m_iLeftThrust[wearable] > 0)
	{
		AcceptEntityInput(m_iLeftThrust[wearable], "Kill", 0, 0, 0);
	}

	if(m_iRightThrust[wearable] > 0)
	{
		AcceptEntityInput(m_iRightThrust[wearable], "Kill", 0, 0, 0);
	}
}

public int TF_StartAttachedParticle(const char[] system, const char[] attachment, int entity, float lifetime)
{
	LogMessage("CreateEntityByName(info_particle_system)");
	int iParticle = CreateEntityByName("info_particle_system");
	if (iParticle > -1)
	{
		float vecPos[3];
		GetEntPropVector(entity, Prop_Send, "m_vecOrigin", vecPos);
		TeleportEntity(iParticle, vecPos, NULL_VECTOR, NULL_VECTOR);

		DispatchKeyValue(iParticle, "effect_name", system);
		DispatchSpawn(iParticle);

		SetVariantString("!activator");
		AcceptEntityInput(iParticle, "SetParent", entity, entity, 0);
		SetVariantString(attachment);
		AcceptEntityInput(iParticle, "SetParentAttachment", entity, entity, 0);

		ActivateEntity(iParticle);
		AcceptEntityInput(iParticle, "Start");
	}
	return iParticle;
}

//-------------------------------------------------------------------
// Purpose: Returns true if client is a real player that
// is ready for backend interactions.
//-------------------------------------------------------------------
public bool IsClientReady(int client)
{
	if (!IsClientValid(client))return false;
	if (IsFakeClient(client))return false;
	return true;
}

//-------------------------------------------------------------------
// Purpose: Returns true if client exists.
//-------------------------------------------------------------------
public bool IsClientValid(int client)
{
	if (client <= 0 || client > MaxClients)return false;
	if (!IsClientInGame(client))return false;
	if (!IsClientAuthorized(client))return false;
	return true;
}
