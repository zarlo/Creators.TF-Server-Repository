#include <sourcemod>
#include <sdktools>
#include <tf2attributes>
#include <tf2_stocks>

// Special Delivery
#define SET_SCOUT 1

#define ITEM_HAT_MILKMAN 219
#define ITEM_SHORTSTOP 220
#define ITEM_FISH 221
#define ITEM_MADMILK 222

// Tank Buster
#define SET_SOLDIER 2

#define ITEM_BATTALIONS_BACKUP 226
#define ITEM_HAT_SOFTCAP 227
#define ITEM_BLACK_BOX 228

// The Gas Jockey's Gear
#define SET_PYRO 3

#define ITEM_HAT_ATTENDANT 213
#define ITEM_POWERJACK 214
#define ITEM_DEGREASER 215

// The Hibernating Bear
#define SET_HEAVY 4

#define ITEM_BRASS_BEAST 312
#define ITEM_STEAK 311
#define ITEM_SPIRIT 310
#define ITEM_BIG_CHIEF 309

// The Expert's Ordnance
#define SET_DEMO 5

#define ITEM_LOCH_LOAD 308
#define ITEM_CABER 307
#define ITEM_SCOTCH_BANNET 306

// The Medieval Medic
#define SET_MEDIC 6

#define ITEM_CROSSBOW 305
#define ITEM_AMPUTATOR 304
#define ITEM_HAT_HELM 303

// The Croc-o-Style kit
#define SET_SNIPER 7

#define ITEM_SYDNEY 230
#define ITEM_SHIELD 231
#define ITEM_BUSHWACKA 232
#define ITEM_CROCO_HAT 229

// The Saharan Spy
#define SET_SPY 8

#define ITEM_LETRANGER 224
#define ITEM_YER 225
#define ITEM_FEZ 223

public Plugin myinfo =
{
	name = "[TF2] Item Set Effects",
	author = "Item Set Effects",
	description = "Item Set Effects",
	version = "1.0",
	url = "https://moonlydays.com"
}

public void OnPluginStart()
{
	HookEvent("post_inventory_application", post_inventory_application);
}

public Action post_inventory_application(Handle hEvent, const char[] szName, bool bDontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(hEvent, "userid"));
	
	if(TF2_HasItemSetEquipped(client, SET_SCOUT))
	{
		TF2Attrib_SetByName(client, "SET BONUS: max health additive bonus", 25.0);
	}
	
	if(TF2_HasItemSetEquipped(client, SET_SOLDIER))
	{
		TF2Attrib_SetByName(client, "SET BONUS: dmg from sentry reduced", 0.8);
	}
	
	if(TF2_HasItemSetEquipped(client, SET_PYRO))
	{
		TF2Attrib_SetByName(client, "SET BONUS: move speed set bonus", 1.1);
		TF2Attrib_SetByName(client, "SET BONUS: dmg taken from bullets increased", 1.1);
	}
	
	if(TF2_HasItemSetEquipped(client, SET_DEMO))
	{
		TF2Attrib_SetByName(client, "SET BONUS: dmg taken from fire reduced set bonus", 0.9);
	}
	
	if(TF2_HasItemSetEquipped(client, SET_HEAVY))
	{
		TF2Attrib_SetByName(client, "SET BONUS: dmg taken from crit reduced set bonus", 0.95);
	}
	
	if(TF2_HasItemSetEquipped(client, SET_MEDIC))
	{
		TF2Attrib_SetByName(client, "SET BONUS: health regen set bonus", 1.0);
	}
	
	if(TF2_HasItemSetEquipped(client, SET_SNIPER))
	{
		TF2Attrib_SetByName(client, "SET BONUS: no death from headshots", 1.0);
	}
	
	if(TF2_HasItemSetEquipped(client, SET_SPY))
	{
		TF2Attrib_SetByName(client, "SET BONUS: cloak blink time penalty", 2);
		TF2Attrib_SetByName(client, "SET BONUS: quiet unstealth", 1.0);
	}
	
	return Plugin_Continue;
}

public bool TF2_HasItemSetEquipped(int client, int item_set)
{
	switch(item_set)
	{
		case SET_SCOUT: 
		{
			if (TF2_GetPlayerClass(client) != TFClass_Scout)return false;
			if (!TF2_HasEconItemWithDefIndex(client, ITEM_HAT_MILKMAN))return false;
			if (!TF2_HasEconItemWithDefIndex(client, ITEM_SHORTSTOP))return false;
			if (!TF2_HasEconItemWithDefIndex(client, ITEM_FISH))return false;
			if (!TF2_HasEconItemWithDefIndex(client, ITEM_MADMILK))return false;
			return true;
		}
		case SET_SOLDIER:
		{
			if (TF2_GetPlayerClass(client) != TFClass_Soldier)return false;
			if (!TF2_HasEconItemWithDefIndex(client, ITEM_BATTALIONS_BACKUP))return false;
			if (!TF2_HasEconItemWithDefIndex(client, ITEM_HAT_SOFTCAP))return false;
			if (!TF2_HasEconItemWithDefIndex(client, ITEM_BLACK_BOX))return false;
			return true;
		}
		case SET_PYRO:
		{
			if (TF2_GetPlayerClass(client) != TFClass_Pyro)return false;
			if (!TF2_HasEconItemWithDefIndex(client, ITEM_HAT_ATTENDANT))return false;
			if (!TF2_HasEconItemWithDefIndex(client, ITEM_POWERJACK))return false;
			if (!TF2_HasEconItemWithDefIndex(client, ITEM_DEGREASER))return false;
			return true;
		}
		case SET_DEMO:
		{
			if (TF2_GetPlayerClass(client) != TFClass_DemoMan)return false;
			if (!TF2_HasEconItemWithDefIndex(client, ITEM_LOCH_LOAD))return false;
			if (!TF2_HasEconItemWithDefIndex(client, ITEM_CABER))return false;
			if (!TF2_HasEconItemWithDefIndex(client, ITEM_SCOTCH_BANNET))return false;
			return true;
		}
		case SET_HEAVY:
		{
			if (TF2_GetPlayerClass(client) != TFClass_Heavy)return false;
			if (!TF2_HasEconItemWithDefIndex(client, ITEM_BRASS_BEAST))return false;
			if (!TF2_HasEconItemWithDefIndex(client, ITEM_STEAK))return false;
			if (!TF2_HasEconItemWithDefIndex(client, ITEM_SPIRIT))return false;
			if (!TF2_HasEconItemWithDefIndex(client, ITEM_BIG_CHIEF))return false;
			return true;
		}
		case SET_MEDIC:
		{
			if (TF2_GetPlayerClass(client) != TFClass_Medic)return false;
			if (!TF2_HasEconItemWithDefIndex(client, ITEM_CROSSBOW))return false;
			if (!TF2_HasEconItemWithDefIndex(client, ITEM_AMPUTATOR))return false;
			if (!TF2_HasEconItemWithDefIndex(client, ITEM_HAT_HELM))return false;
			return true;
		}
		case SET_SNIPER:
		{
			if (TF2_GetPlayerClass(client) != TFClass_Sniper)return false;
			if (!TF2_HasEconItemWithDefIndex(client, ITEM_SYDNEY))return false;
			if (!TF2_HasEconItemWithDefIndex(client, ITEM_SHIELD))return false;
			if (!TF2_HasEconItemWithDefIndex(client, ITEM_BUSHWACKA))return false;
			if (!TF2_HasEconItemWithDefIndex(client, ITEM_CROCO_HAT))return false;
			return true;
		}
		case SET_SPY:
		{
			if (TF2_GetPlayerClass(client) != TFClass_Spy)return false;
			if (!TF2_HasEconItemWithDefIndex(client, ITEM_LETRANGER))return false;
			if (!TF2_HasEconItemWithDefIndex(client, ITEM_YER))return false;
			if (!TF2_HasEconItemWithDefIndex(client, ITEM_FEZ))return false;
			return true;
		}
	}
	return false;
}

public bool TF2_HasEconItemWithDefIndex(int client, int index)
{
	// Checking Cosmetics
	int iWear;
	while ((iWear = FindEntityByClassname(iWear, "tf_wearable*")) != -1)
	{
		if (GetEntPropEnt(iWear, Prop_Send, "m_hOwnerEntity") != client)continue;
		if (!HasEntProp(iWear, Prop_Send, "m_iItemDefinitionIndex"))continue;
		
		int idx = GetEntProp(iWear, Prop_Send, "m_iItemDefinitionIndex");
		if (index == idx)return true;
	}
	
	for (int i = 0; i < 5; i++)
	{
		int iWeapon = GetPlayerWeaponSlot(client, i);
		if (!IsValidEntity(iWeapon))continue;
		if (!HasEntProp(iWeapon, Prop_Send, "m_iItemDefinitionIndex"))continue;
		
		int idx = GetEntProp(iWeapon, Prop_Send, "m_iItemDefinitionIndex");
		if (index == idx)return true;
	}
	
	return false;
}