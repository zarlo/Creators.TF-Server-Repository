#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <tf2_stocks>
#include <cecon_items>

#include <tf2wearables>
#include <tf2attributes>
#include <tf2items>

#define SOUND_HEAL "creators/weapons/syringe_heal.wav"
#define SOUND_HEAL_READY "player/recharged.wav"
#define SOUND_HEAL_READY_VO "vo/medic_mvm_say_ready01.mp3"
#define SOUND_HEAL_DONE_VO "vo/medic_specialcompleted07.mp3"

#define HEALING_CAP 40
#define APPLY_CONDITION TFCond_RegenBuffed
#define DEFAULT_OVERHEAL 1.5
#define THINK_RATE 0.5

#define CHAR_FULL "■"
#define CHAR_EMPTY "□"

#define PLUGIN_NAME           "[CE Attribute] syringe blood mod"
#define PLUGIN_AUTHOR         "Creators.TF Team"
#define PLUGIN_DESCRIPTION    "syringe blood mod"
#define PLUGIN_VERSION        "1.00"
#define PLUGIN_URL            "https//creators.tf"

int m_iBlood[MAXPLAYERS]; // the amount of health stored in the syringe
int m_iBloodCap[MAXPLAYERS]; // the max amount of health that can be stored in the syringe
int m_iLastHealingAmount[MAXPLAYERS]; // the amount of healing done last time we checked (used to calculate the difference to add to blood)

public Plugin myinfo =
{
	name = PLUGIN_NAME,
	author = PLUGIN_AUTHOR,
	description = PLUGIN_DESCRIPTION,
	version = PLUGIN_VERSION,
	url = PLUGIN_URL
};

public void OnPluginStart()
{
	// Hook our events
	HookEvent("player_death", OnPlayerReset);
	HookEvent("player_spawn", OnPlayerReset);
	HookEvent("post_inventory_application", OnPlayerReset);
	HookEvent("teamplay_round_start", OnRoundStart);
	
	// Create our hud/charge updating timer
	CreateTimer(THINK_RATE, Timer_Think, _, TIMER_REPEAT);
}

public void OnMapStart()
{
	// Precache our sounds just in case
	PrecacheSound(SOUND_HEAL);
	PrecacheSound(SOUND_HEAL_READY);
	PrecacheSound(SOUND_HEAL_DONE_VO);
	PrecacheSound(SOUND_HEAL_READY_VO);
}

public void OnClientPutInServer(client)
{
	ResetCharge(client);
	SDKHook(client, SDKHook_TraceAttack, OnTraceAttack);
}

public void OnClientDisconnect(int client)
{
	ResetCharge(client);
}

public void CEconItems_OnItemIsEquipped(int client, int entity, CEItem xItem, const char[] type)
{
	if (!StrEqual(type, "weapon"))return;
	if(CEconItems_GetEntityAttributeBool(entity, "syringe blood mode"))
	{
		int m_iCapacity = CEconItems_GetEntityAttributeInteger(entity, "syringe blood mode capacity");
		m_iBloodCap[client] = m_iCapacity;
	}
}

public Action OnTraceAttack(int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &ammotype, int hitbox, int hitgroup)
{
	if(!IsClientValid(attacker)) return Plugin_Continue;
	if(!IsClientValid(victim)) return Plugin_Continue;
	if(!IsPlayerAlive(attacker)) return Plugin_Continue;
	if(!IsPlayerAlive(victim)) return Plugin_Continue;
	if(GetClientTeam(attacker) != GetClientTeam(victim)) return Plugin_Continue; // we cant heal enemies
	int iWeapon = GetEntPropEnt(attacker, Prop_Send, "m_hActiveWeapon");
	if(IsValidEntity(iWeapon) && IsSyringeBloodMod(iWeapon))
	{
		// are we actually fully charged
		if(m_iBlood[attacker] >= m_iBloodCap[attacker])
		{
			ApplyCharge(attacker, victim, iWeapon);
		}
	}
	return Plugin_Continue;
}

public Action Timer_Think(Handle hTimer, any data)
{
	for (int i = 1; i <= MAXPLAYERS; i++)
	{
		if(IsClientValid(i))
		{
			// check for class type to save looping over every weapon
			// if this attribute ever gets applied to other classes, remove this check
			if(TF2_GetPlayerClass(i) == TFClass_Medic)
			{
				if(HasAttribute(i))
				{
					UpdateCharge(i);
					DrawHUD(i);
				}
			}
		}
	}
}

void UpdateCharge(int client)
{
	// if we are already at max charge, no need to check anything
	if(m_iBlood[client] >= m_iBloodCap[client])
	{
		m_iBlood[client] = m_iBloodCap[client];
		return;
	}
	
	int iActualHealingAmount = GetHealing(client);
	int iDelta = iActualHealingAmount - m_iLastHealingAmount[client];
	
	#if defined HEALING_CAP
	// Clamp the healing done to avoid getting instant charges with fast healing like quickfix uber
	if(iDelta > HEALING_CAP)
	{
		iDelta = HEALING_CAP;
	}
	#endif
	
	m_iBlood[client] += iDelta;
	m_iLastHealingAmount[client] = iActualHealingAmount;
	
	// if we reached the cap after healing, play the voicelines and such
	if(m_iBlood[client] >= m_iBloodCap[client])
	{
		m_iBlood[client] = m_iBloodCap[client];
		EmitSoundToClient(client, SOUND_HEAL_READY);
		EmitSoundToAll(SOUND_HEAL_READY_VO, client);
	}
	UpdatePoseParameter(client, GetWeaponWithAttribute(client));
}

void UpdatePoseParameter(int client, int weapon)
{
	// update the pose parameter so the weapon model can show the correct amount of charge ( in %)
	TF2Wear_SetEntPropFloatOfWeapon(weapon, Prop_Send, "m_flPoseParameter", float(m_iBlood[client]) / float(m_iBloodCap[client]));
}

void DrawHUD(int client)
{
	char sHUDText[128];
	char sProgress[32];
	int iPercents = RoundToCeil(float(m_iBlood[client]) / float(m_iBloodCap[client]) * 100.0);

	for (int j = 1; j <= 10; j++)
	{
		if (iPercents >= j * 10)StrCat(sProgress, sizeof(sProgress), CHAR_FULL);
		else StrCat(sProgress, sizeof(sProgress), CHAR_EMPTY);
	}

	Format(sHUDText, sizeof(sHUDText), "Syringe: %d%%%%   \n%s   ", iPercents, sProgress);

	if(iPercents >= 100)
	{
		SetHudTextParams(1.0, 0.8, 0.5, 255, 0, 0, 255);
	} else {
		SetHudTextParams(1.0, 0.8, 0.5, 255, 255, 255, 255);
	}
	ShowHudText(client, -1, sHUDText);
}

void ApplyCharge(int client, int victim, int weapon)
{
	int iBaseHealth = GetClientHealth(victim);
	int iMaxHealth = GetMaxOverheal(client, victim);

	// get the amount of health we heal and make sure to not go over the max overheal
	int iHealing = CEconItems_GetEntityAttributeInteger(weapon, "syringe blood mode heal");
	int iHealth = iBaseHealth + iHealing;
	if (iHealth > iMaxHealth) iHealth = iMaxHealth;
	
	// Apply the syringe gun effects
	SetEntityHealth(victim, iHealth);
	TF2_AddCondition(victim, APPLY_CONDITION, CEconItems_GetEntityAttributeFloat(weapon, "syringe blood mode uber"), client);
	
	// lastly all the cosmetic stuff
	EmitSoundToAll(SOUND_HEAL, victim);
	EmitSoundToAll(SOUND_HEAL_DONE_VO, client);
	ResetCharge(client);
	UpdatePoseParameter(client, weapon);
	
	// not sure why this is here but the original syringe code had it so ill just port it over just in case
	Event hEvent = CreateEvent("player_healed");
	if (hEvent == null) return;
	hEvent.SetInt("sourcemod", 1);
	hEvent.SetInt("patient", GetClientUserId(victim));
	hEvent.SetInt("healer", GetClientUserId(client));
	hEvent.SetInt("amount", iHealth - iBaseHealth);
	hEvent.Fire();

	hEvent = CreateEvent("player_healonhit", true);
	hEvent.SetInt("amount", iHealth - iBaseHealth);
	hEvent.SetInt("entindex", victim);
	hEvent.Fire();
}

// Called whenever something that resets the player happens
// (ex: resupplying, death)
public Action OnPlayerReset(Handle hEvent, const char[] sName, bool bDontBroadcast)
{
	int iPlayer = GetClientOfUserId(GetEventInt(hEvent, "userid"));
	ResetCharge(iPlayer);
	return Plugin_Continue;
}

// reset all players on round start
public Action OnRoundStart(Handle hEvent, const char[] sName, bool bDontBroadcast)
{
	for(int i = 0; i < MAXPLAYERS; i++)
	{
		if(IsClientValid(i))
		{
			ResetCharge(i);
		}
	}
}

void ResetCharge(int client)
{
	m_iBlood[client] = 0;
	m_iLastHealingAmount[client] = GetHealing(client);
}

bool IsSyringeBloodMod(int weapon)
{
	return CEconItems_GetEntityAttributeBool(weapon, "syringe blood mode");
}

// check if any weapon on the player has the attribute
bool HasAttribute(int client)
{
	for (int i = 0; i <= TFWeaponSlot_Melee; i++)
	{
		int iWeapon = GetPlayerWeaponSlot(client, i);
		if(iWeapon > 0 && IsValidEntity(iWeapon) && IsSyringeBloodMod(iWeapon))
		{
			return true;
		}
	}
	return false;
}

// check which weapon on the player has the attribute
int GetWeaponWithAttribute(int client)
{
	for (int i = 0; i <= TFWeaponSlot_Melee; i++)
	{
		int iWeapon = GetPlayerWeaponSlot(client, i);
		if(iWeapon > 0 && IsValidEntity(iWeapon) && IsSyringeBloodMod(iWeapon))
		{
			return iWeapon;
		}
	}
	return -1;
}

int GetMaxOverheal(client, victim)
{
	int iMaxHealth = GetEntProp(victim, Prop_Data, "m_iMaxHealth");
	
	
	// first all the multipliers from the healer
	float flOverhealMultiplier = TF2Attrib_HookValueFloat(1.0, "mult_medigun_overheal_amount", client);
	int iOverhealExpertAttribute = TF2Attrib_HookValueInt(0, "overheal_expert", client);
	// last all the multipliers from the victim
	float flMaxOverhealMultiplier = TF2Attrib_HookValueFloat(1.0, "mult_patient_overheal_penalty", victim);
	
	float flTotalMultiplier = ((DEFAULT_OVERHEAL-1) * flOverhealMultiplier) * flMaxOverhealMultiplier; // as an inverted percentage (0.5 -> 150% multiplier)
	
	if(iOverhealExpertAttribute > 0)
	{
		flTotalMultiplier += float(iOverhealExpertAttribute)/ 4.0; // overheal expert is additive
	}
	
	return RoundToFloor(iMaxHealth * (1 + flTotalMultiplier));
}

int GetHealing(int client)
{
	if(!IsClientValid(client))
	{
		return 0;
	}
	
	return GetEntProp(client, Prop_Send, "m_iHealPoints");
}

//Utility Functions

bool IsClientValid(int client)
{
	if (client <= 0 || client > MaxClients) return false;
	if(!IsValidEntity(client)) return false;
	if (!IsClientInGame(client)) return false;
	if (!IsClientAuthorized(client)) return false;
	return true;
}