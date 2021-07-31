#pragma semicolon 1
#pragma newdecls required

#include <sdkhooks>
#include <sdktools>
#include <ce_core>
#include <ce_util>
#include <ce_events>
#include <ce_manager_responses>
#include <ce_manager_attributes>
#include <tf2_stocks>
#include <SetCollisionGroup>

int m_hTarget[MAX_ENTITY_LIMIT + 1]; // the target client userid (not index) to send the gift to
float m_flCreationTime[MAX_ENTITY_LIMIT + 1];
float m_vecStartCurvePos[MAX_ENTITY_LIMIT + 1][3];
float m_vecPreCurvePos[MAX_ENTITY_LIMIT + 1][3];
float m_flDuration[MAX_ENTITY_LIMIT + 1];

public Plugin myinfo =
{
	name = "[CE Entity] ent_gift",
	author = "Creators.TF Team",
	description = "Holiday Gift Pickup",
	version = "1.05",
	url = "https://creators.tf"
}

#define TF_GIFT_MODEL "models/items/tf_gift.mdl"


enum SolidType_t
{
    SOLID_NONE          = 0,    // no solid model
    SOLID_BSP           = 1,    // a BSP tree
    SOLID_BBOX          = 2,    // an AABB
    SOLID_OBB           = 3,    // an OBB (not implemented yet)
    SOLID_OBB_YAW       = 4,    // an OBB, constrained so that it can only yaw
    SOLID_CUSTOM        = 5,    // Always call into the entity for tests
    SOLID_VPHYSICS      = 6,    // solid vphysics object, get vcollide from the model and collide with that
    SOLID_LAST,
};

 enum SolidFlags_t
{
    FSOLID_CUSTOMRAYTEST                = 0x0001,    // Ignore solid type + always call into the entity for ray tests
    FSOLID_CUSTOMBOXTEST                = 0x0002,    // Ignore solid type + always call into the entity for swept box tests
    FSOLID_NOT_SOLID                    = 0x0004,    // Are we currently not solid?
    FSOLID_TRIGGER                      = 0x0008,    // This is something may be collideable but fires touch functions
                                                     // ... even when it's not collideable (when the FSOLID_NOT_SOLID flag is set)
    FSOLID_NOT_STANDABLE                = 0x0010,    // You can't stand on this
    FSOLID_VOLUME_CONTENTS              = 0x0020,    // Contains volumetric contents (like water)
    FSOLID_FORCE_WORLD_ALIGNED          = 0x0040,    // Forces the collision rep to be world-aligned even if it's SOLID_BSP or SOLID_VPHYSICS
    FSOLID_USE_TRIGGER_BOUNDS           = 0x0080,    // Uses a special trigger bounds separate from the normal OBB
    FSOLID_ROOT_PARENT_ALIGNED          = 0x0100,    // Collisions are defined in root parent's local coordinate space
    FSOLID_TRIGGER_TOUCH_DEBRIS         = 0x0200,    // This trigger will touch debris objects

    FSOLID_MAX_BITS    = 10
};

public void OnPluginStart()
{
	// Misc Events
	HookEvent("player_death", player_death);
}

public void OnMapStart()
{
	PrecacheModel(TF_GIFT_MODEL);
}

public bool IsValidGift(int entity)
{
	if (!IsValidEntity(entity) || entity <= 0)
	{
		return false;
	}

	char sName[128];
	GetEntPropString(entity, Prop_Data, "m_iName", sName, sizeof(sName));
	return StrEqual(sName, "ce_gift");
}

public void Gift_CreateForPlayer(int client, int origin, bool deadRinged)
{
	float vecPos[3];
	GetClientAbsOrigin(origin, vecPos);

	vecPos[2] += 60.0;

	int iGift = EntRefToEntIndex(Gift_Create(client, vecPos, deadRinged));
	m_hTarget[iGift] = GetClientUserId(client);

	switch (TF2_GetClientTeam(client))
	{
		case TFTeam_Red:  TF_StartAttachedParticle("peejar_trail_red", iGift, 4.0);
		case TFTeam_Blue: TF_StartAttachedParticle("peejar_trail_blu", iGift, 4.0);
	}
}

public int Gift_Create(int client, float pos[3], bool deadRinged)
{
	int iEnt = CreateEntityByName("prop_physics_override");
	if (IsValidEntity(iEnt) && iEnt > 0)
	{
		SetEntityModel(iEnt, TF_GIFT_MODEL);

		float vecAng[3];
		vecAng[0] = GetRandomFloat(-20.0, 20.0);
		vecAng[2] = GetRandomFloat(-20.0, 20.0);

		TeleportEntity(iEnt, pos, vecAng, NULL_VECTOR);

		//DispatchKeyValue(iEnt, "spawnflags", "2");
		DispatchKeyValue(iEnt, "targetname", "ce_gift");

		DispatchSpawn(iEnt);
		ActivateEntity(iEnt);

		// SOLID_VPHYSICS - solid vphysics object, get vcollide from the model and collide with that
		SetEntProp(iEnt, Prop_Data, "m_nSolidType", SOLID_VPHYSICS);
		// FSOLID_TRIGGER - This is something may be collideable but fires touch functions
		// FSOLID_TRIGGER_TOUCH_DEBRIS - This trigger will touch debris objects
		SetEntProp(iEnt, Prop_Send, "m_usSolidFlags", FSOLID_TRIGGER | FSOLID_TRIGGER_TOUCH_DEBRIS);

		//SetEntProp(iEnt, Prop_Send, "m_CollisionGroup", 2);
		// https://github.com/ashort96/SetCollisionGroup
		SetEntityCollisionGroup(iEnt, COLLISION_GROUP_DEBRIS_TRIGGER);
		// why can't i pass deadRinged to the callback? this is silly...
		if (deadRinged) SDKHook(iEnt, SDKHook_StartTouch, Gift_OnTouch_Fake);
		else SDKHook(iEnt, SDKHook_StartTouch, Gift_OnTouch);

		// Gift is not flying to target when spawned.
		Gift_SetActive(iEnt, false);

		CreateTimer(1.0, Timer_Gift_SetActive, EntIndexToEntRef(iEnt));
	}
	return EntIndexToEntRef(iEnt);
}


public Action Timer_Gift_SetActive(Handle timer, any data)
{
	if (data == INVALID_ENT_REFERENCE)
	{
		return Plugin_Handled;
	}

	int gift = EntRefToEntIndex(data);
	if (!IsValidGift(gift))
	{
		return Plugin_Handled;
	}

	Gift_SetActive(gift, true);
	return Plugin_Handled;
}

public void Gift_StartTargetMovement(int ent)
{
	if (!IsValidGift(ent))
	{
		return;
	}

	Gift_InitSplineData(ent);
}

public Action Gift_OnTouch_Fake(int entity, int other)
{
	if (IsClientValid(other) && IsValidGift(entity))
	{
		if (GetClientUserId(other) != m_hTarget[entity])
		{
			return Plugin_Handled;
		}

		ClientPlayResponse(other, "XmasGift.Pickup");
		RemoveEntity(entity);

	}
	return Plugin_Handled;
}

public Action Gift_OnTouch(int entity, int other)
{
	if (IsClientValid(other) && IsValidGift(entity))
	{
		if (GetClientUserId(other) != m_hTarget[entity])
		{
			return Plugin_Handled;
		}

		ClientPlayResponse(other, "XmasGift.Pickup");
		RemoveEntity(entity);
		CEEvents_SendEventToClient(other, "LOGIC_COLLECT_GIFT", 1, GetRandomInt(0, 10000));

	}
	return Plugin_Handled;
}

public void Gift_SetActive(int entity, bool active)
{
	if (active)
	{
		// Gift is flying to the target.
		SetEntPropFloat(entity, Prop_Send, "m_flModelScale", 0.3);
		AcceptEntityInput(entity, "DisableMotion");
		TF_StartAttachedParticle("soul_trail", entity, 2.0);
		Gift_StartTargetMovement(entity);
	}
	else
	{
		SetEntPropFloat(entity, Prop_Send, "m_flModelScale", 0.7);
		AcceptEntityInput(entity, "EnableMotion");
	}
}

public void Gift_InitSplineData(int iEnt)
{
	if (!IsValidGift(iEnt))
	{
		return;
	}

	m_flCreationTime[iEnt] = GetEngineTime();
	GetEntPropVector(iEnt, Prop_Send, "m_vecOrigin", m_vecStartCurvePos[iEnt]);

	float vecRandom[3];
	for (int i = 0; i < 2; i++)
	{
		vecRandom[i] = GetRandomFloat(-2000.0, 2000.0);
	}
	vecRandom[2] = GetRandomFloat(-2000.0, -300.0);

	m_vecPreCurvePos[iEnt] = m_vecStartCurvePos[iEnt];
	for (int i = 0; i < 3; i++)
	{
		m_vecPreCurvePos[iEnt][i] += vecRandom[i];
	}
	if (m_vecPreCurvePos[iEnt][2] > 0.0)
	{
		m_vecPreCurvePos[iEnt][2] = 0.0;
	}

	m_flDuration[iEnt] = 1.1;

	RequestFrame(Gift_FlyTowardsTargetEntity, EntIndexToEntRef(iEnt));
}

public void Gift_FlyTowardsTargetEntity(any data)
{
	if (data == INVALID_ENT_REFERENCE)
	{
		return;
	}

	int iEnt = EntRefToEntIndex(data);
	if (!IsValidGift(iEnt))
	{
		return;
	}

	int iTarget = GetClientOfUserId(m_hTarget[iEnt]);
	float flLife = GetEngineTime() - m_flCreationTime[iEnt];
	float flT = flLife / m_flDuration[iEnt];

	if (!IsClientValid(iTarget))
	{
		return;
	}

	if (flLife > 5.0 || flT > 2.0 || !IsPlayerAlive(iTarget))
	{
		RemoveEntity(iEnt);
		return;
	}

	const float flBiasAmt = 0.2;
	flT = Bias(flT, flBiasAmt);

	if (flT < 0.0)
	{
		flT = 0.0;
	}

	if (flT > 1.0)
	{
		flT = 1.0;
	}

	float angEyes[3];
	GetClientEyeAngles(iTarget, angEyes);
	float vecBehindChest[3];
	GetAngleVectors(angEyes, vecBehindChest, NULL_VECTOR, NULL_VECTOR);
	ScaleVector(vecBehindChest, -2000.0);

	float vecTargetPos[3], vecNextCuvePos[3];
	GetEntPropVector(iTarget, Prop_Send, "m_vecOrigin", vecTargetPos);
	for (int i = 0; i < 3; i++)
	{
		vecNextCuvePos[i] = vecTargetPos[i] + vecBehindChest[i];
	}

	vecTargetPos[2] += 60.0;

	float vecOutput[3];
	Catmull_Rom_Spline(m_vecPreCurvePos[iEnt], m_vecStartCurvePos[iEnt], vecTargetPos, vecNextCuvePos, flT, vecOutput);

	TeleportEntity(iEnt, vecOutput, NULL_VECTOR, NULL_VECTOR);

	RequestFrame(Gift_FlyTowardsTargetEntity, EntIndexToEntRef(iEnt));
}

public Action player_death(Event ev, const char[] szName, bool bDontBroadcast)
{
	int victim = GetClientOfUserId(ev.GetInt("userid"));
	int attacker = GetClientOfUserId(ev.GetInt("attacker"));
	int assister = GetClientOfUserId(ev.GetInt("assister"));

	bool deadRinged = false;
	if (ev.GetInt("death_flags") & 32)
	{
		deadRinged = true;
	}

	if (IsClientReady(attacker) && attacker != victim)
	{
		float vecPos[3];
		GetClientAbsOrigin(victim, vecPos);

		vecPos[2] += 60.0;

		Gift_CreateForPlayer(attacker, victim, deadRinged);
	}

	if (IsClientReady(assister))
	{
		Gift_CreateForPlayer(assister, victim, deadRinged);
	}

	return Plugin_Continue;
}

// -----------------------------------------------------------------------------------------
// Credit: Valve. I have no clue how this function works, but it works, so we'll use it.
// -----------------------------------------------------------------------------------------
public void Catmull_Rom_Spline(float p1[3], float p2[3], float p3[3], float p4[3], float t, float output[3])
{

	float tSqr = t * t * 0.5;
	float tSqrSqr = t * tSqr;

	t *= 0.5;

	float a[3], b[3], c[3], d[3];

	// Matrix row 1
	VectorScale(p1, -tSqrSqr, a);
	VectorScale(p2, tSqrSqr * 3.0, b);
	VectorScale(p3, tSqrSqr * -3.0, c);
	VectorScale(p4, tSqrSqr, d);

	AddVectors(a, output, output);
	AddVectors(b, output, output);
	AddVectors(c, output, output);
	AddVectors(d, output, output);

	// Matrix row 2
	VectorScale(p1, tSqr * 2, a);
	VectorScale(p2, tSqr * -5.0, b);
	VectorScale(p3, tSqr * 4.0, c);
	VectorScale(p4, -tSqr, d);

	AddVectors(a, output, output);
	AddVectors(b, output, output);
	AddVectors(c, output, output);
	AddVectors(d, output, output);

	// Matrix row 3
	VectorScale(p1, -t, a);
	VectorScale(p3, t, b);

	AddVectors(a, output, output);
	AddVectors(b, output, output);

	// Matrix row 4
	AddVectors(p2, output, output);
}

public void VectorScale(float input[3], float scale, float output[3])
{
	output = input;
	ScaleVector(output, scale);
}

public float Bias(float x, float biasAmt)
{
	static float lastAmt = -1.0;
	static float lastExponent = 0.0;
	if (lastAmt != biasAmt)
	{
		lastExponent = Logarithm( biasAmt ) * -1.4427;
	}
	float fRet = Pow( x, lastExponent );
	return fRet;
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
