#pragma semicolon 1
#pragma newdecls required

#include <sdkhooks>
#include <tf2_stocks>
#include <tf2>
#include <cecon_items>

//-------------------------------
// THROWABLE TYPES
// 1 - Brick
#define HAS_BRICK
// 2 - Smoke Grenade
#define HAS_SMOKE_GRENADE
// 3 - Bread Monster
#define HAS_BREAD_MONSTER
// 4 - Boomerang
#define HAS_BOOMERANG
//-------------------------------

public Plugin myinfo =
{
	name = "[CE Attribute] set throwable type",
	author = "Creators.TF Team",
	description = "set throwable type",
	version = "1.0",
	url = "https://creators.tf"
};

int m_nThrowableType[2049];
bool m_bRemoveNextProjectile[MAXPLAYERS + 1];

int m_iSmokeEffectCycles[2049];

#define TF_AMMO_GRENADES1 4

//---------------------------------------------------------------------------------------
// BRICK
//---------------------------------------------------------------------------------------
#define THROWABLE_TYPE_BRICK 1

ConVar 	tf_throwable_brick_force;

#define TF_THROWABLE_BRICK_MODEL "models/weapons/c_models/c_brick/c_brick.mdl"


//---------------------------------------------------------------------------------------
// SMOKE GRENADE
//---------------------------------------------------------------------------------------
#define THROWABLE_TYPE_SMOKE_GRENADE 2

ConVar 	tf_throwable_smoke_grenade_force,
		tf_throwable_smoke_grenade_delay,
		tf_throwable_smoke_grenade_duration;
		
#define TF_THROWABLE_SMOKE_GRENADE_INTERVAL 0.1
#define TF_THROWABLE_SMOKE_GRENADE_EXPLOSION_SOUND "creators/weapons/smoke_explosion.mp3"
#define TF_THROWABLE_SMOKE_GRENADE_ENTITY "tf_projectile_stun_ball"
#define TF_THROWABLE_SMOKE_GRENADE_PARTICLE "grenade_smoke_cycle"


//---------------------------------------------------------------------------------------
// BREAD MONSTER
//---------------------------------------------------------------------------------------
#define THROWABLE_TYPE_BREAD 3

ConVar 	tf_throwable_bread_force;
#define TF_THROWABLE_BREAD_ENTITY "tf_projectile_throwable_breadmonster"


//---------------------------------------------------------------------------------------
// BOOMERANG
//---------------------------------------------------------------------------------------
#define THROWABLE_TYPE_BOOMERANG 4

ConVar 	tf_throwable_boomerang_force,
		tf_throwable_boomerang_return_delay;
		
#define TF_THROWABLE_BOOMERANG_MODEL "models/weapons/c_models/c_boomerang/c_boomerang.mdl"
#define TF_THROWABLE_BOOMERANG_ENTITY "tf_projectile_arrow"
#define TF_THROWABLE_BOOMERANG_SPIN_SOUND "creators/weapons/boomerang_spin.wav"
#define TF_THROWABLE_BOOMERANG_BREAK_SOUND "drywall.ImpactHard"


public void OnMapStart()
{
	PrecacheModel(TF_THROWABLE_BRICK_MODEL);
	PrecacheModel(TF_THROWABLE_BOOMERANG_MODEL);
	PrecacheSound(TF_THROWABLE_SMOKE_GRENADE_EXPLOSION_SOUND);
	PrecacheSound(TF_THROWABLE_BOOMERANG_SPIN_SOUND);
	
	PrecacheScriptSound(TF_THROWABLE_BOOMERANG_BREAK_SOUND);
}

Handle 	g_hSdkInitThrowable, 
		g_hSdkInitArrow,
		g_hSdkGiveAmmo;

public void OnPluginStart()
{
	//---------------------------------------------------------------------------------------
	// CONVARS
	//---------------------------------------------------------------------------------------
	
	// Brick
	tf_throwable_brick_force 				= CreateConVar("tf_throwable_brick_force", "1200");

	// Bread Monster
	tf_throwable_bread_force 				= CreateConVar("tf_throwable_bread_force", "900");

	// Smoke Greande
	tf_throwable_smoke_grenade_force 		= CreateConVar("tf_throwable_smoke_grenade_force", "1200");
	tf_throwable_smoke_grenade_delay 		= CreateConVar("tf_throwable_smoke_grenade_delay", "2.0");
	tf_throwable_smoke_grenade_duration 	= CreateConVar("tf_throwable_smoke_grenade_duration", "5.0");

	// Boomerang
	tf_throwable_boomerang_force 			= CreateConVar("tf_throwable_boomerang_force", "800");
	tf_throwable_boomerang_return_delay 	= CreateConVar("tf_throwable_boomerang_return_delay", "0.8");
	
	//---------------------------------------------------------------------------------------
	// GAME DATA
	//---------------------------------------------------------------------------------------
	Handle hGameConf = LoadGameConfigFile("tf2.throwables");
	if (hGameConf != null)
	{
		StartPrepSDKCall(SDKCall_Entity);
		PrepSDKCall_SetFromConf(hGameConf, SDKConf_Virtual, "CTFProjectile_Throwable::InitThrowable");
		PrepSDKCall_AddParameter(SDKType_Float, SDKPass_Plain);
		g_hSdkInitThrowable = EndPrepSDKCall();
		
		StartPrepSDKCall(SDKCall_Entity);
		PrepSDKCall_SetFromConf(hGameConf, SDKConf_Virtual, "CTFProjectile_Arrow::InitArrow");
		PrepSDKCall_AddParameter(SDKType_QAngle, SDKPass_ByRef);		// const QAngle &vecAngles
		PrepSDKCall_AddParameter(SDKType_Float, SDKPass_Plain);			// const float fSpeed
		PrepSDKCall_AddParameter(SDKType_Float, SDKPass_Plain);			// const float fGravity
		PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);	// ProjectileType_t projectileType
		PrepSDKCall_AddParameter(SDKType_CBaseEntity, SDKPass_Pointer);	// CBaseEntity *pOwner
		PrepSDKCall_AddParameter(SDKType_CBaseEntity, SDKPass_Pointer);	// CBaseEntity *pScorer
		g_hSdkInitArrow = EndPrepSDKCall();
		
		StartPrepSDKCall(SDKCall_Entity);
		PrepSDKCall_SetFromConf(hGameConf, SDKConf_Virtual, "CBaseCombatCharacter::GiveAmmo");
		PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);		// int iCount
		PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);		// int iAmmoIndex
		PrepSDKCall_AddParameter(SDKType_Bool, SDKPass_Plain);				// bool bSuppressSound
		g_hSdkGiveAmmo = EndPrepSDKCall();

		CloseHandle(hGameConf);
	}

	
	//---------------------------------------------------------------------------------------
	// SOUNDS
	//---------------------------------------------------------------------------------------
	AddNormalSoundHook(view_as<NormalSHook>(OnSoundHook));
}

//---------------------------------------------------------------------------------------
// Purpose:	Fired when a sound if played. 
//---------------------------------------------------------------------------------------
public Action OnSoundHook(int[] clients, int &numClients, char[] sample, int &entity, int &channel, float &volume, int &level, int &pitch, int &flags, char[] soundEntry, int &seed)
{
	// Don't do anything if emitter is not a client.
	if (!IsClientReady(entity))return Plugin_Continue;

	// Only check for sniper lines.
	if(TF2_GetPlayerClass(entity) == TFClass_Sniper)
	{
		// Get current weapon.
		int iWeapon = GetEntPropEnt(entity, Prop_Send, "m_hActiveWeapon");
		if(IsValidEntity(iWeapon))
		{
			// Don't shout "Jarate" if we're shooting a custom throwable.
			if(m_nThrowableType[iWeapon] > 0)
			{
				if(StrEqual(sample, "vo/sniper_JarateToss01.mp3"))
				{
					strcopy(sample, 30, "vo/sniper_JarateToss02.mp3");
					return Plugin_Changed;
				}
			}
		}
	}
	return Plugin_Continue;
}

//---------------------------------------------------------------------------------------
// Purpose:	Fired a new cecon item is equipped.
//---------------------------------------------------------------------------------------
public void CEconItems_OnItemIsEquipped(int client, int entity, CEItem xItem, const char[] type)
{
	if (!StrEqual(type, "weapon"))return;

	m_nThrowableType[entity] = CEconItems_GetEntityAttributeInteger(entity, "set throwable type");
	
	if(m_nThrowableType[entity] > 0)
	{
		CBaseCombatCharacter_GiveAmmo(client, 1, TF_AMMO_GRENADES1, true);
	}
}

//---------------------------------------------------------------------------------------
// Purpose:	Fired when a new entity is created
//---------------------------------------------------------------------------------------
public void OnEntityCreated(int entity, const char[] classname)
{
	if (entity < 1)return;

	m_nThrowableType[entity] = 0;

	if(strncmp(classname, "tf_projectile_jar", 17) == 0)
	{
		SDKHook(entity, SDKHook_Spawn, SDKHook_Projectile_OnSpawn);
	}
}

//---------------------------------------------------------------------------------------
// Purpose:	Fired when jar projectile is spawned
//---------------------------------------------------------------------------------------
public Action SDKHook_Projectile_OnSpawn(int entity)
{
	int iClient = GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity");
	if(iClient > 0)
	{
		if(m_bRemoveNextProjectile[iClient])
		{
			AcceptEntityInput(entity, "Kill");
			m_bRemoveNextProjectile[iClient] = false;
		}
	}
}

//---------------------------------------------------------------------------------------
// Purpose:	Fired when client makes an attack
//---------------------------------------------------------------------------------------
public Action TF2_CalcIsAttackCritical(int client, int weapon, char[] name, bool &result)
{
	if (!CEconItems_IsEntityCustomEconItem(weapon))return;
	if (m_nThrowableType[weapon] <= 0)return;

	CreateTimer(0.035, Timer_DelayedCreateThrowableProjectile, weapon);

	if(StrContains(name, "tf_weapon_jar") != -1)
	{
		m_bRemoveNextProjectile[client] = true;
	}
}

//---------------------------------------------------------------------------------------
// Purpose:	Creates a projectile after a certain amount of times
//---------------------------------------------------------------------------------------
public Action Timer_DelayedCreateThrowableProjectile(Handle timer, any data)
{
	CreateWeaponThrowableProjectile(data);
}

//---------------------------------------------------------------------------------------
// Purpose:	Creates a projectile from weapon.
//---------------------------------------------------------------------------------------
public void CreateWeaponThrowableProjectile(int weapon)
{
	if (!CEconItems_IsEntityCustomEconItem(weapon))return;
	if (m_nThrowableType[weapon] <= 0)return;

	switch(m_nThrowableType[weapon])
	{
		#if defined HAS_BRICK
		case THROWABLE_TYPE_BRICK:
		{
			CreateWeaponThrowableProjectile_Brick(weapon);
		}
		#endif

		#if defined HAS_BREAD_MONSTER
		case THROWABLE_TYPE_BREAD:
		{
			CreateWeaponThrowableProjectile_BreadMonster(weapon);
		}
		#endif

		#if defined HAS_SMOKE_GRENADE
		case THROWABLE_TYPE_SMOKE_GRENADE:
		{
			CreateWeaponThrowableProjectile_SmokeGrenade(weapon);
		}
		#endif

		#if defined HAS_BOOMERANG
		case THROWABLE_TYPE_BOOMERANG:
		{
			CreateWeaponThrowableProjectile_Boomerang(weapon);
		}
		#endif
	}
}

public void GetThrowableTrailParticle(int weapon, char[] buffer, int size)
{
	if (weapon < 0)return;
	if (m_nThrowableType[weapon] <= 0)return;
	
	int iTeamNum = GetEntProp(weapon, Prop_Send, "m_iTeamNum");
	
	char sOverride[PLATFORM_MAX_PATH];
	switch(iTeamNum)
	{
		case 2: // TF_TEAM_RED
		{
			CEconItems_GetEntityAttributeString(weapon, "override throwable particle red", sOverride, sizeof(sOverride));
			if(!StrEqual(sOverride, ""))
			{
				strcopy(buffer, size, sOverride);
				return;
			}
			
			strcopy(buffer, size, "peejar_trail_red");
		}
		
		case 3: // TF_TEAM_BLUE
		{
			CEconItems_GetEntityAttributeString(weapon, "override throwable particle blue", sOverride, sizeof(sOverride));
			if(!StrEqual(sOverride, ""))
			{
				strcopy(buffer, size, sOverride);
				return;
			}
			
			strcopy(buffer, size, "peejar_trail_blu");
		}
	}
}

public void GetThrowableModel(int weapon, char[] buffer, int size)
{
	if (weapon < 0)return;
	if (m_nThrowableType[weapon] <= 0)return;
	
	char sOverride[PLATFORM_MAX_PATH];
	CEconItems_GetEntityAttributeString(weapon, "override throwable model", sOverride, sizeof(sOverride));
	
	if(!StrEqual(sOverride, ""))
	{
		strcopy(buffer, size, sOverride);
		return;
	}
	
	switch(m_nThrowableType[weapon])
	{
		#if defined HAS_BRICK
		case THROWABLE_TYPE_BRICK:
		{
			strcopy(buffer, size, TF_THROWABLE_BRICK_MODEL);
		}
		#endif

		#if defined HAS_BOOMERANG
		case THROWABLE_TYPE_BOOMERANG:
		{
			strcopy(buffer, size, TF_THROWABLE_BOOMERANG_MODEL);
		}
		#endif
	}
}

public float GetThrowableForce(int weapon)
{
	if (weapon < 0)return 0.0;
	if (m_nThrowableType[weapon] <= 0)return 0.0;
	
	float flOverride = CEconItems_GetEntityAttributeFloat(weapon, "override throwable force");
	
	if(flOverride > 0.0)
	{
		return flOverride;
	}
	
	switch(m_nThrowableType[weapon])
	{
		#if defined HAS_BRICK
		case THROWABLE_TYPE_BRICK:
		{
			return tf_throwable_brick_force.FloatValue;
		}
		#endif

		#if defined HAS_SMOKE_GRENADE
		case THROWABLE_TYPE_SMOKE_GRENADE:
		{
			return tf_throwable_smoke_grenade_force.FloatValue;
		}
		#endif

		#if defined HAS_BREAD_MONSTER
		case THROWABLE_TYPE_BREAD:
		{
			return tf_throwable_bread_force.FloatValue;
		}
		#endif

		#if defined HAS_BOOMERANG
		case THROWABLE_TYPE_BOOMERANG:
		{
			return tf_throwable_boomerang_force.FloatValue;
		}
		#endif
	}
	
	return 0.0;
}

//---------------------------------------------------------------------------------------
// BRICK FUNCTIONS
//---------------------------------------------------------------------------------------

#if defined HAS_BRICK
public void CreateWeaponThrowableProjectile_Brick(int weapon)
{
	int iClient = GetEntPropEnt(weapon, Prop_Send, "m_hOwnerEntity");

	if (iClient < 0)return;

	float vecPos[3], vecAng[3];
	GetClientEyeAngles(iClient, vecAng);
	GetClientEyePosition(iClient, vecPos);

	float flSpeed = GetThrowableForce(weapon);
	int iProjectile = CreateThrowableBrick(iClient, weapon, flSpeed, 30.0);
	if(iProjectile > -1)
	{
		//------ SETTING MODEL ------//
		char sModel[PLATFORM_MAX_PATH];
		GetThrowableModel(weapon, sModel, sizeof(sModel));
		
		if(!StrEqual(sModel, ""))
		{
			SetEntityModel(iProjectile, sModel);
		}
		//--------------------------//
		
		
		//------ SETTING TRAIL -----//
		char sTrail[PLATFORM_MAX_PATH];
		GetThrowableTrailParticle(weapon, sTrail, sizeof(sTrail));
		
		if(!StrEqual(sTrail, ""))
		{
			TF_StartAttachedParticle(sTrail, iProjectile, 5.0);
		}
		//--------------------------//

		EmitGameSoundToAll("Passtime.Throw", iClient);
	}
}
#endif

//---------------------------------------------------------------------------------------
// BREAD MONSTER FUNCTIONS
//---------------------------------------------------------------------------------------

#if defined HAS_BREAD_MONSTER
public void CreateWeaponThrowableProjectile_BreadMonster(int weapon)
{
	int iTeamNum = GetEntProp(weapon, Prop_Send, "m_iTeamNum");
	int iClient = GetEntPropEnt(weapon, Prop_Send, "m_hOwnerEntity");

	if (iClient < 0)return;


	float vecPos[3], vecAng[3];
	GetClientEyeAngles(iClient, vecAng);
	GetClientEyePosition(iClient, vecPos);

	float flSpeed = GetThrowableForce(weapon);
	int iProjectile = CreateEntityByName(TF_THROWABLE_BREAD_ENTITY);
	if(iProjectile > -1)
	{
		DispatchSpawn(iProjectile);

		SetEntProp(iProjectile, Prop_Send, "m_iTeamNum", iTeamNum);
		SetEntPropEnt(iProjectile, Prop_Send, "m_hOwnerEntity", iClient);
		SetEntProp(iProjectile, Prop_Send, "m_bCritical", 0);
		SetEntPropEnt(iProjectile, Prop_Send, "m_hOriginalLauncher", weapon);

		float vecVelAng[3];
		vecVelAng = vecAng;
		vecVelAng[0] -= 10.0;

		float vecVel[3], vecShift[3];

		GetAngleVectors(vecVelAng, vecVel, vecShift, NULL_VECTOR);
		NormalizeVector(vecVel, vecVel);
		ScaleVector(vecVel, flSpeed);

		NormalizeVector(vecShift, vecShift);
		ScaleVector(vecShift, 8.0); // Shift by 8HU.

		AddVectors(vecPos, vecShift, vecPos);

		ActivateEntity(iProjectile);
		TeleportEntity(iProjectile, vecPos, vecAng, vecVel);
		
		//------ SETTING MODEL ------//
		char sModel[PLATFORM_MAX_PATH];
		GetThrowableModel(weapon, sModel, sizeof(sModel));
		
		if(!StrEqual(sModel, ""))
		{
			SetEntityModel(iProjectile, sModel);
		}
		//--------------------------//
		
		
		//------ SETTING TRAIL -----//
		char sTrail[PLATFORM_MAX_PATH];
		GetThrowableTrailParticle(weapon, sTrail, sizeof(sTrail));
		
		if(!StrEqual(sTrail, ""))
		{
			TF_StartAttachedParticle(sTrail, iProjectile, 5.0);
		}
		//--------------------------//

		SetDelayedProjectileLauncher(iProjectile, weapon);

		EmitGameSoundToAll("Passtime.Throw", iClient);
	}
}
#endif

//---------------------------------------------------------------------------------------
// SMOKE GRENADE FUNCTIONS
//---------------------------------------------------------------------------------------

#if defined HAS_SMOKE_GRENADE
public void CreateWeaponThrowableProjectile_SmokeGrenade(int weapon)
{
	int iTeamNum = GetEntProp(weapon, Prop_Send, "m_iTeamNum");
	int iClient = GetEntPropEnt(weapon, Prop_Send, "m_hOwnerEntity");

	if (iClient < 0)return;

	float vecPos[3], vecAng[3];
	GetClientEyeAngles(iClient, vecAng);
	GetClientEyePosition(iClient, vecPos);

	float flSpeed = GetThrowableForce(weapon);
	int iProjectile = CreateEntityByName(TF_THROWABLE_SMOKE_GRENADE_ENTITY);
	if(iProjectile > -1)
	{
		DispatchSpawn(iProjectile);

		SetEntProp(iProjectile, Prop_Send, "m_iTeamNum", iTeamNum);
		SetEntPropEnt(iProjectile, Prop_Send, "m_hOwnerEntity", iClient);
		SetEntProp(iProjectile, Prop_Send, "m_bCritical", 0);
		SetEntPropEnt(iProjectile, Prop_Send, "m_hOriginalLauncher", weapon);

		float vecVelAng[3];
		vecVelAng = vecAng;
		vecVelAng[0] -= 10.0;

		float vecVel[3], vecShift[3];

		GetAngleVectors(vecVelAng, vecVel, vecShift, NULL_VECTOR);
		NormalizeVector(vecVel, vecVel);
		ScaleVector(vecVel, flSpeed);

		NormalizeVector(vecShift, vecShift);
		ScaleVector(vecShift, 8.0); // Shift by 8HU.

		AddVectors(vecPos, vecShift, vecPos);

		ActivateEntity(iProjectile);
		TeleportEntity(iProjectile, vecPos, vecAng, vecVel);
		
		//------ SETTING MODEL ------//
		char sModel[PLATFORM_MAX_PATH];
		GetThrowableModel(weapon, sModel, sizeof(sModel));
		
		if(!StrEqual(sModel, ""))
		{
			SetEntityModel(iProjectile, sModel);
		}
		//--------------------------//


		m_iSmokeEffectCycles[iProjectile] = SmokeGrenade_GetMaxCycleCount();
		CreateTimer(tf_throwable_smoke_grenade_delay.FloatValue, Timer_SmokeGrenade_StartSmokeCycle, iProjectile);

		SetDelayedProjectileLauncher(iProjectile, weapon);

		EmitGameSoundToAll("Passtime.Throw", iClient);
	}
}

public int SmokeGrenade_GetMaxCycleCount()
{
	float flIntervalMult = 1 / TF_THROWABLE_SMOKE_GRENADE_INTERVAL;
	return RoundToFloor(tf_throwable_smoke_grenade_duration.FloatValue * flIntervalMult);
}

public Action Timer_SmokeGrenade_StartSmokeCycle(Handle timer, any grenade)
{
	CreateTimer(0.1, Timer_SmokeGrenade_CycleSmoke, grenade);
}

public Action Timer_SmokeGrenade_CycleSmoke(Handle timer, any grenade)
{
	int iMaxCycleCount = SmokeGrenade_GetMaxCycleCount();
	
	// Only perform smoke cycle if we more cycles.
	if(m_iSmokeEffectCycles[grenade] > 0)
	{
		// Spawn explosion on first cycle.

		if(m_iSmokeEffectCycles[grenade] == iMaxCycleCount)
		{
			SmokeGrenade_ExplodeEffects(grenade);
			SetEntityMoveType(grenade, MOVETYPE_PUSH);
			SetEntityRenderMode(grenade, RENDER_NONE);
		}

		TF_StartParticleOnEntity(TF_THROWABLE_SMOKE_GRENADE_PARTICLE, grenade, 2.0);
		m_iSmokeEffectCycles[grenade]--;

		if(m_iSmokeEffectCycles[grenade] == 0)
		{
			AcceptEntityInput(grenade, "Kill");
		} else {
			CreateTimer(TF_THROWABLE_SMOKE_GRENADE_INTERVAL, Timer_SmokeGrenade_CycleSmoke, grenade);
		}
	}
}

public void SmokeGrenade_ExplodeEffects(int grenade)
{
	TF_StartParticleOnEntity("ExplosionCore_MidAir", grenade, 2.0);
	EmitSoundToAll(TF_THROWABLE_SMOKE_GRENADE_EXPLOSION_SOUND, grenade);
}
#endif

//---------------------------------------------------------------------------------------
// BOOMERANG FUNCTIONS
//---------------------------------------------------------------------------------------

#if defined HAS_BOOMERANG

enum struct CEProjectileBoomerang 
{
	bool m_bIsActive;
	bool m_bIsReturning;
	
	int m_iTarget;
	int m_iLastHit;
	
	float m_flForce;
	
	float m_flInitTime;
	float m_flExpireTime;
	float m_flReturnTime;
	
	float m_flLastEaseInValue;
}

CEProjectileBoomerang m_Boomerang[2049];

public void CreateWeaponThrowableProjectile_Boomerang(int weapon)
{
	// Getting all the values beforehand.
	int iClient = GetEntPropEnt(weapon, Prop_Send, "m_hOwnerEntity");
	
	// We can't create a projectile if owner in unspecified.
	if (iClient < 0)return;
	
	// Getting force of the boomerang.
	float flSpeed = GetThrowableForce(weapon);
	float flReturnDelay = tf_throwable_boomerang_return_delay.FloatValue;

	// Creating projectile.
	int iProjectile = CreateArrow(iClient, weapon, flSpeed, 30.0, 26);
	if(iProjectile > -1)
	{
		// Resetting values.
		m_Boomerang[iProjectile].m_bIsActive = true;
		m_Boomerang[iProjectile].m_bIsReturning = false;
		
		m_Boomerang[iProjectile].m_iTarget = iClient;
		m_Boomerang[iProjectile].m_iLastHit = -1;
		
		m_Boomerang[iProjectile].m_flForce = flSpeed;
		m_Boomerang[iProjectile].m_flInitTime = GetEngineTime();
		m_Boomerang[iProjectile].m_flReturnTime = GetEngineTime() + flReturnDelay;
		m_Boomerang[iProjectile].m_flExpireTime = GetEngineTime() + (flReturnDelay * 3.0);
		
		m_Boomerang[iProjectile].m_flLastEaseInValue = 0.0;
		
		//------ SETTING MODEL ------//
		char sModel[PLATFORM_MAX_PATH];
		GetThrowableModel(weapon, sModel, sizeof(sModel));
		
		if(!StrEqual(sModel, ""))
		{
			SetEntityModel(iProjectile, sModel);
		}
		//--------------------------//
		
		SetEntityGravity(iProjectile, 0.0);
		SetEntityMoveType(iProjectile, MOVETYPE_FLY);
		
		SetEntProp(iProjectile, Prop_Send, "m_usSolidFlags", 8);
		SetEntProp(iProjectile, Prop_Send, "m_CollisionGroup", 1);
		
		
		//------ SETTING TRAIL -----//
		char sTrail[PLATFORM_MAX_PATH];
		GetThrowableTrailParticle(weapon, sTrail, sizeof(sTrail));
		
		if(!StrEqual(sTrail, ""))
		{
			TF_StartAttachedParticle(sTrail, iProjectile, m_Boomerang[iProjectile].m_flExpireTime);
		}
		//--------------------------//
		
		SDKHook(iProjectile, SDKHook_Touch, OnBoomerangTouch);
		EmitGameSoundToAll("Passtime.Throw", iClient);
		
		CreateTimer(0.1, Timer_Boomerang_Think, iProjectile, TIMER_REPEAT);
		
		EmitSoundToAll(TF_THROWABLE_BOOMERANG_SPIN_SOUND, iProjectile);
		
		// Resetting Z axis
		float angAng[3];
		GetEntPropVector(iProjectile, Prop_Send, "m_angRotation", angAng);
		angAng[2] = 90.0;
		TeleportEntity(iProjectile, NULL_VECTOR, angAng, NULL_VECTOR);
	}
}

public Action OnBoomerangTouch(int boomerang, int other)
{
	if (IsClientValid(other))
	{
		if(m_Boomerang[boomerang].m_bIsReturning && other == m_Boomerang[boomerang].m_iTarget)
		{
			// We hit our target, remove ourselves.
			RemoveEntity(boomerang);
			
			// And also refil ammo for the player.
			CBaseCombatCharacter_GiveAmmo(other, 1, TF_AMMO_GRENADES1, false);
		} else {
			int iOwner = GetEntPropEnt(boomerang, Prop_Send, "m_hOwnerEntity");
			int iTeamNum = GetEntProp(boomerang, Prop_Send, "m_iTeamNum");
			
			if(GetClientTeam(other) != iTeamNum)
			{		
				// If this enemy isn't who we damaged before, deal damage.
				if(m_Boomerang[boomerang].m_iLastHit != other)
				{
					float vecPos[3], vecPosTarget[3], vecVel[3];
					GetEntPropVector(boomerang, Prop_Send, "m_vecOrigin", vecPos);
					GetClientEyePosition(other, vecPosTarget);
					vecPosTarget[2] -= 20.0;
					SubtractVectors(vecPosTarget, vecPos, vecVel);
					NormalizeVector(vecVel, vecVel);
					
					SDKHooks_TakeDamage(other, boomerang, iOwner, 30.0, _, _, vecVel, vecPos);
					m_Boomerang[boomerang].m_iLastHit = other;
				}
			}	
		}
		
	} else {
		EmitGameSoundToAll(TF_THROWABLE_BOOMERANG_BREAK_SOUND, boomerang);
		TransformBoomerangToProp(boomerang, true);
	}
	
	return Plugin_Handled;
}

public Action Timer_Boomerang_Think(Handle timer, any iProjectile)
{
	// If this entity is no longer a boomerang, stop this timer.
	if (!m_Boomerang[iProjectile].m_bIsActive)return Plugin_Stop;
	
	float flTime = GetEngineTime();
	
	// Calculate the lifetime of this entity. 
	float flExpireTime = m_Boomerang[iProjectile].m_flExpireTime;
	float flLifeTime = flExpireTime - flTime;

	if(flLifeTime < 0.0)
	{
		TransformBoomerangToProp(iProjectile, false);
		return Plugin_Stop;
	}
	
	
	float flReturnTime = m_Boomerang[iProjectile].m_flReturnTime;
	bool bIsReturning = m_Boomerang[iProjectile].m_bIsReturning;
	
	if(flTime > flReturnTime && !bIsReturning)
	{
		m_Boomerang[iProjectile].m_bIsReturning = true;
		bIsReturning = true;
		m_Boomerang[iProjectile].m_iLastHit = -1;
	}
	
	// Calculating velocity multiplicator.
	float flMult = FloatAbs(flReturnTime - flTime) * 2;
	if (flMult > 1.0)flMult = 1.0;
	
	// flMult = 1.0;
	
	bool bVelocityChanged = false;
	float vecVel[3];
	
	if(m_Boomerang[iProjectile].m_flLastEaseInValue != flMult)
	{
		GetEntPropVector(iProjectile, Prop_Send, "m_vInitialVelocity", vecVel);
		m_Boomerang[iProjectile].m_flLastEaseInValue = flMult;
		bVelocityChanged = true;
	}
		
	// If we're returning.
	if(bIsReturning)
	{
		// Get our target, and see if it's valid.
		int iTarget = m_Boomerang[iProjectile].m_iTarget;
		if(IsClientValid(iTarget) && IsPlayerAlive(iTarget))
		{
			// Calculate new velocity and normalize it.
			float vecPos[3], vecPosTarget[3];
			GetEntPropVector(iProjectile, Prop_Send, "m_vecOrigin", vecPos);
			GetClientEyePosition(iTarget, vecPosTarget);
			vecPosTarget[2] -= 10.0;
			SubtractVectors(vecPosTarget, vecPos, vecVel);
			NormalizeVector(vecVel, vecVel);
			
			ScaleVector(vecVel, m_Boomerang[iProjectile].m_flForce);
			SetEntPropVector(iProjectile, Prop_Send, "m_vInitialVelocity", vecVel);
			bVelocityChanged = true;
		}
	}
	
	if(bVelocityChanged)
	{
		ScaleVector(vecVel, flMult);
		TeleportEntity(iProjectile, NULL_VECTOR, NULL_VECTOR, vecVel);
	}
	
	float angAng[3];
	GetEntPropVector(iProjectile, Prop_Send, "m_angRotation", angAng);
	angAng[1] += 100.0;
	TeleportEntity(iProjectile, NULL_VECTOR, angAng, NULL_VECTOR);
	
	return Plugin_Continue;
}

public int TransformBoomerangToProp(int boomerang, bool inverse)
{
	float vecPos[3], vecAng[3], vecVel[3];
	GetEntPropVector(boomerang, Prop_Send, "m_vecOrigin", vecPos);
	GetEntPropVector(boomerang, Prop_Send, "m_angRotation", vecAng);
	GetEntPropVector(boomerang, Prop_Send, "m_vInitialVelocity", vecVel);
	
	RemoveEntity(boomerang);
	
	int iProjectile = CreateEntityByName("prop_physics_override");
	if(iProjectile > -1)
	{
		// Setting the model, and making this prop a debris.
		SetEntityModel(iProjectile, TF_THROWABLE_BOOMERANG_MODEL);
		SetEntProp(iProjectile, Prop_Send, "m_CollisionGroup", 1);
        
        // Creating this entity.
		DispatchSpawn(iProjectile);
		
		// Spawning it.
		ActivateEntity(iProjectile);

		float flMult = 0.4;
		if (inverse)flMult *= -1;

		// Inversing velocity vector to simulate bounce.
		ScaleVector(vecVel, flMult);

		// Teleporting to desired location.
		TeleportEntity(iProjectile, vecPos, vecAng, vecVel);

		// Making it dissapear in 5 seconds.
		char info[64];
		Format(info, sizeof(info), "OnUser1 !self:kill::%d:1", 5);
		SetVariantString(info);
		AcceptEntityInput(iProjectile, "AddOutput");
		AcceptEntityInput(iProjectile, "FireUser1");
		
		return iProjectile;
	}
	
	return -1;
}
#endif	// HAS_BOOMERANG

//---------------------------------------------------------------------------------------
// Purpose:	tf_projectile_brick
//---------------------------------------------------------------------------------------
public int CreateThrowableBrick(int owner, int weapon, float speed, float damage)
{
	if (owner <= 0)return -1;
	if (weapon <= 0)return -1;
	
	int iTeamNum = GetEntProp(weapon, Prop_Send, "m_iTeamNum");
	
	float vecPos[3], vecAng[3];
	GetClientEyeAngles(owner, vecAng);
	GetClientEyePosition(owner, vecPos);
	
	int iProjectile = CreateEntityByName("tf_projectile_throwable_brick");
	if(iProjectile > -1)
	{
		DispatchSpawn(iProjectile);

		SetEntProp(iProjectile, Prop_Send, "m_iTeamNum", iTeamNum);
		SetEntPropEnt(iProjectile, Prop_Send, "m_hOwnerEntity", owner);
		SetEntProp(iProjectile, Prop_Send, "m_bCritical", 0);
		SetEntPropEnt(iProjectile, Prop_Send, "m_hOriginalLauncher", weapon);

		SetBaseThrowableDamage(iProjectile, damage);

		float vecVelAng[3];
		vecVelAng = vecAng;
		vecVelAng[0] -= 10.0;

		float vecVel[3], vecShift[3];
		GetAngleVectors(vecVelAng, vecVel, vecShift, NULL_VECTOR);
		NormalizeVector(vecVel, vecVel);
		ScaleVector(vecVel, speed);

		NormalizeVector(vecShift, vecShift);
		ScaleVector(vecShift, 8.0); // Shift by 8HU.

		AddVectors(vecPos, vecShift, vecPos);

		ActivateEntity(iProjectile);
		TeleportEntity(iProjectile, vecPos, vecAng, vecVel);

		SetDelayedProjectileLauncher(iProjectile, weapon);
		
		return iProjectile;
	}
	
	return -1;
}

//---------------------------------------------------------------------------------------
// Purpose:	tf_projectile_arrow
//---------------------------------------------------------------------------------------
public int CreateArrow(int owner, int weapon, float speed, float damage, int type)
{
	if (owner <= 0)return -1;
	if (weapon <= 0)return -1;
	
	float vecPos[3], vecAng[3];
	GetClientEyeAngles(owner, vecAng);
	GetClientEyePosition(owner, vecPos);
	
	int iProjectile = CreateEntityByName("tf_projectile_arrow");
	if(iProjectile > -1)
	{
		DispatchSpawn(iProjectile);
		CTFProjectile_Arrow_InitArrow(iProjectile, vecAng, speed, 0.0, type, owner, owner);
		
		SetEntProp(iProjectile, Prop_Send, "m_bCritical", 0);
		SetEntPropEnt(iProjectile, Prop_Send, "m_hOriginalLauncher", weapon);

		float vecShift[3];
		GetAngleVectors(vecAng, NULL_VECTOR, vecShift, NULL_VECTOR);
		NormalizeVector(vecShift, vecShift);
		ScaleVector(vecShift, 8.0); // Shift by 8HU.

		AddVectors(vecPos, vecShift, vecPos);

		ActivateEntity(iProjectile);
		TeleportEntity(iProjectile, vecPos, NULL_VECTOR, NULL_VECTOR);

		SetDelayedProjectileLauncher(iProjectile, weapon);
		
		return iProjectile;
	}
	
	return -1;
}

//---------------------------------------------------------------------------------------
// SDK Calls
//---------------------------------------------------------------------------------------

public void CTFProjectile_Throwable_InitThrowable(int entity, float charge)
{
	SDKCall(g_hSdkInitThrowable, entity, charge);
}

public void CTFProjectile_Arrow_InitArrow(int arrow, float angles[3], float speed, float gravity, int type, int owner, int scorer)
{
	SDKCall(g_hSdkInitArrow, arrow, angles, speed, gravity, type, owner, scorer);
}

public void CBaseCombatCharacter_GiveAmmo(int client, int ammo, int type, bool nosound)
{
	SDKCall(g_hSdkGiveAmmo, client, ammo, type, nosound);
}

//---------------------------------------------------------------------------------------
// Misc Functions
//---------------------------------------------------------------------------------------

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

public void SetBaseThrowableDamage(int entity, float damage)
{
	CTFProjectile_Throwable_InitThrowable(entity, (damage - 40) / 30);
}

public int TF_StartAttachedParticle(const char[] system, int entity, float lifetime)
{
	int iParticle = CreateEntityByName("info_particle_system");
	if (IsValidEntity(iParticle) && iParticle > 0)
	{
		float vecPos[3];
		GetEntPropVector(entity, Prop_Send, "m_vecOrigin", vecPos);
		TeleportEntity(iParticle, vecPos, NULL_VECTOR, NULL_VECTOR);

		DispatchKeyValue(iParticle, "effect_name", system);
		DispatchSpawn(iParticle);

		SetVariantString("!activator");
		AcceptEntityInput(iParticle, "SetParent", entity, entity, 0);

		ActivateEntity(iParticle);
		AcceptEntityInput(iParticle, "Start");

		char info[64];
		Format(info, sizeof(info), "OnUser1 !self:kill::%d:1", RoundFloat(lifetime));
		SetVariantString(info);
		AcceptEntityInput(iParticle, "AddOutput");
		AcceptEntityInput(iParticle, "FireUser1");
	}
	return iParticle;
}

public int TF_StartParticleOnEntity(const char[] system, int entity, float lifetime)
{
	int iParticle = CreateEntityByName("info_particle_system");
	if (IsValidEntity(iParticle) && iParticle > 0)
	{
		float vecPos[3];
		GetEntPropVector(entity, Prop_Send, "m_vecOrigin", vecPos);
		TeleportEntity(iParticle, vecPos, NULL_VECTOR, NULL_VECTOR);

		DispatchKeyValue(iParticle, "effect_name", system);
		DispatchSpawn(iParticle);

		ActivateEntity(iParticle);
		AcceptEntityInput(iParticle, "Start");

		char info[64];
		Format(info, sizeof(info), "OnUser1 !self:kill::%d:1", RoundFloat(lifetime));
		SetVariantString(info);
		AcceptEntityInput(iParticle, "AddOutput");
		AcceptEntityInput(iParticle, "FireUser1");
	}
	return iParticle;
}

public void SetDelayedProjectileLauncher(int entity, int launcher)
{
	DataPack pack = new DataPack();
	pack.WriteCell(entity);
	pack.WriteCell(launcher);
	pack.Reset();

	RequestFrame(RF_SetDelayedProjectileLauncher, pack);
}

public void RF_SetDelayedProjectileLauncher(any data)
{
	DataPack pack = data;
	int proj = pack.ReadCell();
	int weapon = pack.ReadCell();
	delete pack;
	SetEntPropEnt(proj, Prop_Send, "m_hLauncher", weapon);
}

public void OnEntityDestroyed(int entity)
{
	if (entity < 0)return;
	
	#if defined HAS_BOOMERANG
	if(m_Boomerang[entity].m_bIsActive)
	{
		m_Boomerang[entity].m_bIsActive = false;
		
		// Stop spin sound
		StopSoundAllChannels(entity, TF_THROWABLE_BOOMERANG_SPIN_SOUND);
	}
	#endif	// HAS_BOOMERANG
}

public void StopSoundAllChannels(int entity, char[] sound)
{
    StopSound(entity, SNDCHAN_AUTO, sound);
    StopSound(entity, SNDCHAN_WEAPON, sound);
    StopSound(entity, SNDCHAN_VOICE, sound);
    StopSound(entity, SNDCHAN_ITEM, sound);
    StopSound(entity, SNDCHAN_BODY, sound);
    StopSound(entity, SNDCHAN_STREAM, sound);
    StopSound(entity, SNDCHAN_VOICE_BASE, sound);
    StopSound(entity, SNDCHAN_USER_BASE, sound);
} 