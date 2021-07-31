#pragma semicolon 1

#include <sdktools>
#include <tf2wearables>
#include <tf2>

public Plugin myinfo =
{
	name = "TF2 Wearables",
	author = "Moonly Days",
	description = "Gives ability to equip visible wearables on players.",
	version = "1.0",
	url = "https://moonlydays.com"
};

int m_iTiedWeapon[2049];

public APLRes AskPluginLoad2(Handle plugin, bool late, char[] error, int err_max)
{
	RegPluginLibrary("tf2wearables");
	CreateNative("TF2Wear_CreateWearable", Native_CreateWearable);
	CreateNative("TF2Wear_EquipWearable", Native_EquipWearable);
	CreateNative("TF2Wear_RemoveWearable", Native_RemoveWearable);

	CreateNative("TF2Wear_GetClientWearablesCount", Native_GetClientWearablesCount);

	CreateNative("TF2Wear_SetModel", Native_SetModel);
	CreateNative("TF2Wear_ParseEquipRegionString", Native_ParseEquipRegionString);

	CreateNative("TF2Wear_CreateWeaponTiedWearable", Native_CreateWeaponTiedWearable);
	CreateNative("TF2Wear_RemoveAllTiedWearables", Native_RemoveAllTiedWearables);

	CreateNative("TF2Wear_SetEntPropFloatOfWeapon", Native_SetEntPropFloatOfWeapon);

	CreateNative("TF2_GetPlayerLoadoutSlot", Native_GetLoadoutSlot);

	return APLRes_Success;
}

Handle g_hSdkEquipWearable;
Handle g_hGetEntFromSlot;

public void OnPluginStart()
{
	Handle hGameConf = LoadGameConfigFile("tf2.wearables");
	if (hGameConf != null)
	{
		StartPrepSDKCall(SDKCall_Player);
		PrepSDKCall_SetFromConf(hGameConf, SDKConf_Virtual, "CTFPlayer::EquipWearable");
		PrepSDKCall_AddParameter(SDKType_CBaseEntity, SDKPass_Pointer);
		g_hSdkEquipWearable = EndPrepSDKCall();
		
		StartPrepSDKCall(SDKCall_Player);
		PrepSDKCall_SetFromConf(hGameConf, SDKConf_Signature, "CTFPlayer::GetEntityForLoadoutSlot");
		PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain );
		PrepSDKCall_SetReturnInfo(SDKType_CBaseEntity, SDKPass_Pointer);
		g_hGetEntFromSlot = EndPrepSDKCall();

		CloseHandle(hGameConf);
	}
}

public void OnMapStart()
{
	for (int i = 0; i < 2049; i++)
	{
		m_iTiedWeapon[i] = false;
	}
}

// --------------------------------------------- //
// Native: TF2Wear_CreateWeaponTiedWearable
// Purpose: Creates a wearable that will only be visible while a weapon is active.
// --------------------------------------------- //
public int Native_CreateWeaponTiedWearable(Handle plugin, int numParams)
{
	int weapon = GetNativeCell(1);
	if (!IsValidEntity(weapon))return -1;

	int client = GetEntPropEnt(weapon, Prop_Send, "m_hOwnerEntity");

	// Only attach this wearable if weapon is currently active.
	if (GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon") != weapon)return -1;

	char sModel[256];
	GetNativeString(3, sModel, sizeof(sModel));

	bool bIsViewModel = GetNativeCell(2);

	int entity = TF2Wear_CreateWearable(client, bIsViewModel, sModel);

	m_iTiedWeapon[entity] = weapon;

	return entity;
}

// --------------------------------------------- //
// 	Native: TF2Wear_CreateWearable
// --------------------------------------------- //
public int Native_CreateWearable(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);

	bool bIsViewModel = GetNativeCell(2);

	char sModel[256];
	GetNativeString(3, sModel, sizeof(sModel));
	
	int entity = CreateEntityByName(bIsViewModel ? "tf_wearable_vm" : "tf_wearable");
	if (!IsValidEntity(entity))
	{
		return -1;
	}

	// Effects
	SetEntProp(entity, Prop_Send, "m_fEffects", 129); // EF_BONEMERGE | EF_BONEMERGE_FASTCULL

	// Collision
	SetEntProp(entity, Prop_Send, "m_usSolidFlags", 4);	// FSOLID_NOT_SOLID
	SetEntProp(entity, Prop_Send, "m_CollisionGroup", 11); // COLLISION_GROUP_WEAPON

	// CBaseEntity
	SetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity", client);
	SetEntProp(entity, Prop_Send, "m_iTeamNum", GetClientTeam(client));
	SetEntProp(entity, Prop_Send, "m_nSkin", GetClientTeam(client));

	// This makes it visible.
	SetEntProp(entity, Prop_Send, "m_bValidatedAttachedEntity", 1);

	// CEconEntity
	SetEntProp(entity, Prop_Send, "m_iItemIDLow", 2048);
	SetEntProp(entity, Prop_Send, "m_iItemIDHigh", 0);
	SetEntProp(entity, Prop_Send, "m_iAccountID", GetSteamAccountID(client));
	SetEntProp(entity, Prop_Send, "m_iEntityLevel", -1);

	DispatchSpawn(entity);
	SetVariantString("!activator");
	ActivateEntity(entity);

	TF2Wear_SetModel(entity, sModel);

	TF2Wear_EquipWearable(client, entity);

	return entity;
}

// --------------------------------------------- //
// 	Native: TF2Wear_EquipWearable
// --------------------------------------------- //
public int Native_EquipWearable(Handle plugin, int numParams)
{
	if (g_hSdkEquipWearable == null)
	{
		LogMessage("Error: Can't call EquipWearable, SDK functions not loaded!");
		return;
	}

	int client = GetNativeCell(1);
	int entity = GetNativeCell(2);

	SDKCall(g_hSdkEquipWearable, client, entity);
}

// --------------------------------------------- //
// 	Native: TF2Wear_RemoveWearable
// --------------------------------------------- //
public int Native_RemoveWearable(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	int entity = GetNativeCell(2);

	if (client < 0)return;

	TF2_RemoveWearable(client, entity);
}

// --------------------------------------------- //
// 	Native: TF2Wear_SetModel
// --------------------------------------------- //
public int Native_SetModel(Handle plugin, int numParams)
{
	int iEntity = GetNativeCell(1);

	char sModel[512];
	GetNativeString(2, sModel, sizeof(sModel));

	if (StrEqual(sModel, ""))return;

	if(IsValidEntity(iEntity))
	{
		int iModel = PrecacheModel(sModel, false);

		SetEntProp(iEntity, Prop_Send, "m_nModelIndex", iModel);
		for (int i = 0; i < 4; i++)
		{
			SetEntProp(iEntity, Prop_Send, "m_nModelIndexOverrides", iModel, 4, i);
		}
	}
}

// --------------------------------------------- //
// Purpose: On Entity Created
// --------------------------------------------- //
public void OnEntityCreated(int entity, const char[] class)
{
	if (!(0 < entity <= 2049))return;

	m_iTiedWeapon[entity] = false;
}

// --------------------------------------------- //
// Purpose: On Entity Destroyed
// --------------------------------------------- //
public void OnEntityDestroyed(int entity)
{
	if (!(0 < entity <= 2049))return;

	m_iTiedWeapon[entity] = false;
}

// --------------------------------------------- //
// Native: TF2Wear_GetClientWearablesCount
// Purpose: Returns the amount of wearables a specific client has.
// --------------------------------------------- //
public int Native_GetClientWearablesCount(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);

	int iCount = 0;

	int next = GetEntPropEnt(client, Prop_Data, "m_hMoveChild");
	while (next != -1)
	{
		int iEdict = next;
		next = GetEntPropEnt(iEdict, Prop_Data, "m_hMovePeer");
		char classname[32];
		GetEntityClassname(iEdict, classname, 32);
		if (strncmp(classname, "tf_wearable", 11) != 0) continue;

		iCount++;
	}

	return iCount;
}

// --------------------------------------------- //
// 	Native: TF2Wear_RemoveAllTiedWearables
// --------------------------------------------- //
public int Native_RemoveAllTiedWearables(Handle plugin, int numParams)
{
	int weapon = GetNativeCell(1);
	if (weapon <= 0)return;
	if (!IsValidEntity(weapon))return;

	if (!HasEntProp(weapon, Prop_Send, "m_hOwnerEntity"))return;
	int client = GetEntPropEnt(weapon, Prop_Send, "m_hOwnerEntity");

	int iEdict = -1;
	while((iEdict = FindEntityByClassname(iEdict, "tf_wearable*")) != -1)
	{
		if(m_iTiedWeapon[iEdict] == weapon)
		{
			TF2Wear_RemoveWearable(client, iEdict);
			AcceptEntityInput(iEdict, "Kill");
		}
	}
}

public int Native_SetEntPropFloatOfWeapon(Handle plugin, int numParams)
{
	int weapon = GetNativeCell(1);
	if (weapon <= 0)return;

	PropType type = GetNativeCell(2);

	char sProp[PLATFORM_MAX_PATH];
	GetNativeString(3, sProp, sizeof(sProp));

	float value = GetNativeCell(4);
	int children = GetNativeCell(5);

	SetEntPropFloat(weapon, type, sProp, value);

	int edict;
	while((edict = FindEntityByClassname(edict, "tf_wearable*")) != -1)
	{
		if (m_iTiedWeapon[edict] == weapon)
		{
			if(HasEntProp(edict, type, sProp))
			{
				SetEntPropFloat(edict, type, sProp, value, children);
			}
		}
	}

}

public int Native_ParseEquipRegionString(Handle plugin, int numParams)
{
	char string[256];
	GetNativeString(1, string, 256);

	int bits;
	if (StrContains(string, "whole_head") != -1)bits |= TFEquip_WholeHead | TFEquip_Hat | TFEquip_Face | TFEquip_Glasses;
	if (StrContains(string, "hat") != -1)bits |= TFEquip_Hat;
	if (StrContains(string, "face") != -1)bits |= TFEquip_Face;
	if (StrContains(string, "glasses") != -1)bits |= TFEquip_Glasses | TFEquip_Face | TFEquip_Lenses;
	if (StrContains(string, "lenses") != -1)bits |= TFEquip_Lenses;
	if (StrContains(string, "pants") != -1)bits |= TFEquip_Pants;
	if (StrContains(string, "beard") != -1)bits |= TFEquip_Beard;
	if (StrContains(string, "shirt") != -1)bits |= TFEquip_Shirt;
	if (StrContains(string, "medal") != -1)bits |= TFEquip_Medal;
	if (StrContains(string, "arms") != -1)bits |= TFEquip_Arms;
	if (StrContains(string, "back") != -1)bits |= TFEquip_Back;
	if (StrContains(string, "feet") != -1)bits |= TFEquip_Feet;
	if (StrContains(string, "necklace") != -1)bits |= TFEquip_Necklace;
	if (StrContains(string, "grenades") != -1)bits |= TFEquip_Grenades;
	if (StrContains(string, "arm_tatoos") != -1)bits |= TFEquip_ArmTatoos;
	if (StrContains(string, "flair") != -1)bits |= TFEquip_Flair;
	if (StrContains(string, "head_skin") != -1)bits |= TFEquip_HeadSkin;
	if (StrContains(string, "ears") != -1)bits |= TFEquip_Ears;
	if (StrContains(string, "left_shoulder") != -1)bits |= TFEquip_LeftShoulder;
	if (StrContains(string, "belt_misc") != -1)bits |= TFEquip_BeltMisc;
	if (StrContains(string, "disconnected_floating_item") != -1)bits |= TFEquip_Floating;
	if (StrContains(string, "zombie_body") != -1)bits |= TFEquip_Zombie;
	if (StrContains(string, "sleeves") != -1)bits |= TFEquip_Sleeves;
	if (StrContains(string, "right_shoulder") != -1)bits |= TFEquip_RightShoulder;

	if (StrContains(string, "pyro_spikes") != -1)bits |= TFEquip_PyroSpikes;
	if (StrContains(string, "scout_bandages") != -1)bits |= TFEquip_ScoutBandages;
	if (StrContains(string, "engineer_pocket") != -1)bits |= TFEquip_EngineerPocket;
	if (StrContains(string, "heavy_belt_back") != -1)bits |= TFEquip_HeavyBeltBack;
	if (StrContains(string, "demo_eyepatch") != -1)bits |= TFEquip_DemoEyePatch;
	if (StrContains(string, "soldier_gloves") != -1)bits |= TFEquip_SoldierGloves;
	if (StrContains(string, "spy_gloves") != -1)bits |= TFEquip_SpyGloves;
	if (StrContains(string, "sniper_headband") != -1)bits |= TFEquip_SniperHeadband;

	if (StrContains(string, "scout_backpack") != -1)bits |= TFEquip_ScoutBack;
	if (StrContains(string, "heavy_pocket") != -1)bits |= TFEquip_HeavyPocket;
	if (StrContains(string, "engineer_belt") != -1)bits |= TFEquip_EngineerBelt;
	if (StrContains(string, "soldier_pocket") != -1)bits |= TFEquip_SoldierPocket;
	if (StrContains(string, "demo_belt") != -1)bits |= TFEquip_DemoBelt;
	if (StrContains(string, "sniper_quiver") != -1)bits |= TFEquip_SniperQuiver;

	if (StrContains(string, "pyro_wings") != -1)bits |= TFEquip_PyroWings;
	if (StrContains(string, "sniper_bullets") != -1)bits |= TFEquip_SniperBullets;
	if (StrContains(string, "medigun_accessories") != -1)bits |= TFEquip_MediAccessories;
	if (StrContains(string, "soldier_coat") != -1)bits |= TFEquip_SoldierCoat;
	if (StrContains(string, "heavy_hip") != -1)bits |= TFEquip_HeavyHip;
	if (StrContains(string, "scout_hands") != -1)bits |= TFEquip_ScoutHands;

	if (StrContains(string, "engineer_left_arm") != -1)bits |= TFEquip_EngineerLeftArm;
	if (StrContains(string, "pyro_tail") != -1)bits |= TFEquip_PyroTail;
	if (StrContains(string, "sniper_legs") != -1)bits |= TFEquip_SniperLegs;
	if (StrContains(string, "medic_gloves") != -1)bits |= TFEquip_MedicGloves;
	if (StrContains(string, "soldier_cigar") != -1)bits |= TFEquip_SoldierCigar;
	if (StrContains(string, "demoman_collar") != -1)bits |= TFEquip_DemomanCollar;
	if (StrContains(string, "heavy_towel") != -1)bits |= TFEquip_HeavyTowel;

	if (StrContains(string, "engineer_wings") != -1)bits |= TFEquip_EngineerWings;
	if (StrContains(string, "pyro_head_replacement") != -1)bits |= TFEquip_PyroHead;
	if (StrContains(string, "scout_wings") != -1)bits |= TFEquip_ScoutWings;
	if (StrContains(string, "heavy_hair") != -1)bits |= TFEquip_HeavyHair;
	if (StrContains(string, "medic_pipe") != -1)bits |= TFEquip_MedicPipe;
	if (StrContains(string, "soldier_legs") != -1)bits |= TFEquip_SoldierLegs;

	if (StrContains(string, "scout_pants") != -1)bits |= TFEquip_ScoutPants;
	if (StrContains(string, "heavy_bullets") != -1)bits |= TFEquip_HeavyBullets;
	if (StrContains(string, "engineer_hair") != -1)bits |= TFEquip_EngineerHair;
	if (StrContains(string, "sniper_vest") != -1)bits |= TFEquip_SniperVest;
	if (StrContains(string, "medigun_backpack") != -1)bits |= TFEquip_MedigunBackpack;
	if (StrContains(string, "sniper_pocket_left") != -1)bits |= TFEquip_SniperPocketLeft;

	if (StrContains(string, "sniper_pocket") != -1)bits |= TFEquip_SniperPocket;
	if (StrContains(string, "heavy_hip_pouch") != -1)bits |= TFEquip_HeavyHipPouch;
	if (StrContains(string, "spy_coat") != -1)bits |= TFEquip_SpyCoat;
	if (StrContains(string, "medic_hip") != -1)bits |= TFEquip_MedicHip;
	return bits;
}

public int Native_GetLoadoutSlot(Handle plugin, int numParams)
{
	if (g_hGetEntFromSlot == null)
	{
		LogMessage("Error: Can't call GetLoadoutSlot, SDK functions not loaded!");
		
		// TODO (ZoNiCaL): Log error here to Sentry when it's merged into master.
		// Our gamedata might be off!
		return -1;
	}
	
	int client = GetNativeCell(1);
	if (client < 1 || client > MaxClients || !IsClientInGame(client))
	{
		ThrowNativeError(SP_ERROR_NATIVE, "Client %d is invalid", client);
		return -1;
	}
	
	int slot = GetNativeCell(2);
	
	return SDKCall(g_hGetEntFromSlot, client, slot);
}
