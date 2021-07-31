//============= Copyright Amper Software 2021, All rights reserved. ============//
//
// Purpose: Handler for the Cosmetic custom item type.
// 
//=========================================================================//

#pragma semicolon 1
#pragma newdecls required
#pragma tabsize 0

#include <cecon>
#include <cecon_items>

#include <tf2wearables>
#include <tf2>
#include <tf2_stocks>
#include <tf_econ_data>

#include <morecolors>
#include <clientprefs>

// Why? 
// The game supports up to 8 concurrent wearables, equipped on a player.
// This is due to that m_MyWearables array netprop in the player entity 
// can store up to 8 members.
// If we exceed this limit, bugs with randomly dissapearing cosmetics may occur.
// 
// To address this, we limit the maximum amount of possible cosmetics on a player
// to 4. We reserve 3 cosmetics for weapons' display. And one spare cosmetic as a
// threshold to prevent array overflowing.
//
// To properly equip custom cosmetics, we perform a few optimization techniques. 
// We unequip base TF2 cosmetics with intersecting equip regions. This is to
// prevent clipping between overlapping cosmetics. If we still can't get enough space 
// to equip a custom cosmetic, we just remove one base TF2 cosmetic to free up space.
#define MAX_COSMETICS 4

public Plugin myinfo = 
{
	name = "Creators.TF (Cosmetics)", 
	author = "Creators.TF Team", 
	description = "Handler for the Cosmetic custom item type.", 
	version = "1.1", 
	url = "https://creators.tf"
};

#define MAX_STYLES 16

enum struct CEItemDefinitionCosmetic
{
	int m_iIndex;
	char m_sWorldModel[256];
	int m_iBaseIndex;
	int m_iEquipRegion;
	
	int m_iStylesCount;
	int m_iStyles[MAX_STYLES];
}

enum struct CEItemDefinitionCosmeticStyle 
{
	int m_iIndex;
	char m_sWorldModel[256];
}

ArrayList m_hDefinitions;
ArrayList m_hStyles;

bool m_bHasSeenWarning[MAXPLAYERS + 1];
Handle m_hWarningTimers[MAXPLAYERS + 1];

Handle g_WarningCookie;

/*
	TODO: Version 1.2
		- Start experimentation of whether wearables are consistent (e.g not despawned on player death and whatnot).
		- Attempt some optimisations of applying loadouts by comparing two different loadout states: OLD and CURRENT.
		If an item is in both OLD and CURRENT, we shouldn't bother at all about applying that item, and just keep it
		on the player. TF2_OnReplaceItem should handle the rest for us. If an item is in OLD but not in CURRENT, we
		know we should remove it. This could save having to create and destroy a lot of entities, which could be the
		source for FPS issues that have been going on recently.
		- Create natives for grabbing a persons loadout by class. This could make disguised spies applying other peoples
		cosmetics a possibility. CEconItems_GetClientClassLoadout(int client, CEconLoadoutClass class)?
		- Remove the stupid comments and document everything better.
*/

public void OnPluginStart()
{
	g_WarningCookie = RegClientCookie("cecon_cosmetic_warning_message_cookie", "Shows a warning message if a default tf2 wearable was replaced with a CreatorsTF wearable.", CookieAccess_Public);
	SetCookiePrefabMenu(g_WarningCookie, CookieMenu_OnOff_Int, "Cosmetic Wearable Replacement Warning Chat Message");
	
	for (int i = 1; i <= MaxClients; i++)
	{
		m_bHasSeenWarning[i] = false;
		if (AreClientCookiesCached(i)) OnClientCookiesCached(i);
	}
}

//--------------------------------------------------------------------
// Purpose: When a player gets a warning saying that a base TF2 cosmetic
// was randomly removed, a check is performed to see if they've
// recently seen it to prevent spam. Initalize this warning on start
// and remove it on disconnect.
//--------------------------------------------------------------------
public void OnClientConnected(int client)
{
	m_bHasSeenWarning[client] = false;
}

public void OnClientCookiesCached(int client)
{
	char val[8];
	GetClientCookie(client, g_WarningCookie, val, sizeof val);
	if (StrEqual(val, "0")) m_bHasSeenWarning[client] = true;
}

public void OnClientDisconnect(int client)
{
	m_bHasSeenWarning[client] = false;
	delete m_hWarningTimers[client];
}

//--------------------------------------------------------------------
// Purpose: Reset the players wearable warning after 5 minutes.
//--------------------------------------------------------------------
public Action RemoveWearableWarning(Handle timer, int client)
{
	m_bHasSeenWarning[client] = false;
	m_hWarningTimers[client] = null;
}

//--------------------------------------------------------------------
// Purpose: Precaches all the items of a specific type on plugin
// startup.
//--------------------------------------------------------------------
public void OnAllPluginsLoaded()
{
	ProcessEconSchema(CEcon_GetEconomySchema());
}

//--------------------------------------------------------------------
// Purpose: If schema was late updated (by an update), reprecache
// everything again.
//--------------------------------------------------------------------
public void CEcon_OnSchemaUpdated(KeyValues hSchema)
{
	ProcessEconSchema(hSchema);
}

public int EquipOverrideItem(int client, CEItem item, CEItemDefinitionCosmetic hDef)
{
	char sModel[512];
	strcopy(sModel, sizeof(sModel), hDef.m_sWorldModel);
	ParseCosmeticModel(client, sModel, sizeof(sModel));
	
	int iWear = TF2Wear_CreateWearable(client, false, sModel);
				
	if (IsValidEntity(iWear))
	{
		SetEntProp(iWear, Prop_Send, "m_iItemDefinitionIndex", hDef.m_iBaseIndex);
		SetEntProp(iWear, Prop_Send, "m_iEntityQuality", item.m_nQuality);
		SetEntProp(iWear, Prop_Send, "m_bInitialized", 1);
		return iWear;
	}
	return -1;
}

public int FindSimilarWearableByRegion(int client, int region)
{
	// Loop through all of our cosmetics.
	int next = GetEntPropEnt(client, Prop_Data, "m_hMoveChild");
	while (next != -1)
	{
		int iEdict = next;
		next = GetEntPropEnt(iEdict, Prop_Data, "m_hMovePeer");

		char classname[32];
		GetEntityClassname(iEdict, classname, 32);

		if (strncmp(classname, "tf_wearable", 11) != 0) continue;

		char sNetClassName[32];
		GetEntityNetClass(iEdict, sNetClassName, sizeof(sNetClassName));
		
		// We only remove CTFWearable and CTFWearableCampaignItem items.
		if (!StrEqual(sNetClassName, "CTFWearable") && !StrEqual(sNetClassName, "CTFWearableCampaignItem"))continue;
		
		if (CEconItems_IsEntityCustomEconItem(iEdict))continue;
		if (!HasEntProp(iEdict, Prop_Send, "m_iItemDefinitionIndex"))continue;
		
		int iItemDefIndex = GetEntProp(iEdict, Prop_Send, "m_iItemDefinitionIndex");
		
		// Invalid Item Definiton Index.
		if (iItemDefIndex == 0xFFFF)continue;
		
		int iCompareBits = TF2Econ_GetItemEquipRegionGroupBits(iItemDefIndex);
		if (region & iCompareBits)
		{
			// This item shares an equip region with another cosmetic.
			return iEdict;
		}
	}
	// We could not find a similar entity.
	return -1;
}


//--------------------------------------------------------------------
// Purpose: This is called upon item equipping process.
//--------------------------------------------------------------------
public int CEconItems_OnEquipItem(int client, CEItem item, const char[] type)
{
	if (!StrEqual(type, "cosmetic"))return -1;
	
	CEItemDefinitionCosmetic hDef;
	if (FindCosmeticDefinitionByIndex(item.m_iItemDefinitionIndex, hDef))
	{
		// If there are any weapons that occupy this equip
		// regions, we do not equip this cosmetic.
		if (HasOverlappingWeapons(client, hDef.m_iEquipRegion))
		{
			return -1;
		}
		
		// Can we get another cosmetic?
		if (CanGetAnotherCosmetic(client))
		{
			// Does this item share any equip regions with another?
			int iSimilarWearable = FindSimilarWearableByRegion(client, hDef.m_iEquipRegion);
			
			// Do we have a similar wearable?
			if (IsValidEntity(iSimilarWearable) && IsWearableCosmetic(iSimilarWearable))
			{
				// Change the model of our pre-existing wearable:
				char sModel[512];
				strcopy(sModel, sizeof(sModel), hDef.m_sWorldModel);
				ParseCosmeticModel(client, sModel, sizeof(sModel));
				
				PrecacheModel(sModel);
				TF2Wear_SetModel(iSimilarWearable, sModel);
				return iSimilarWearable;
			}
			else
			{
				// We couldn't find a similar wearable to override first. No worries! We can still equip this item.
				int iWearable = EquipOverrideItem(client, item, hDef);
				if (iWearable != -1) 
				{
					return iWearable;
				}
			}
		}
		else
		{
			// We weren't able to find any items with similar equip regions.
			// We'll now go through all of our wearables and create new cosmetics in their place.
			int iAttempts = MAX_COSMETICS;
			int next = GetEntPropEnt(client, Prop_Data, "m_hMoveChild");
			
			while(iAttempts > 0 && !CanGetAnotherCosmetic(client))
			{
				iAttempts--;
				while (next != -1)
				{
					int iEdict = next;
					next = GetEntPropEnt(iEdict, Prop_Data, "m_hMovePeer");
					char classname[32];
					GetEntityClassname(iEdict, classname, 32);
					if (strncmp(classname, "tf_wearable", 11) != 0) continue;
					
					if (!IsWearableCosmetic(iEdict))continue;
					if (CEconItems_IsEntityCustomEconItem(iEdict))continue;
					
					TF2Wear_RemoveWearable(client, iEdict);
					AcceptEntityInput(iEdict, "Kill");
					
					// Attempt to put on our cosmetic.
					int iWearable = EquipOverrideItem(client, item, hDef);
					if (iWearable != -1) 
					{
						// We've overriden a random base TF2 cosmetic to apply this one, let the user know for the future.
						if (!m_bHasSeenWarning[client])
						{
							m_bHasSeenWarning[client] = true;
							m_hWarningTimers[client] = CreateTimer(300.0, RemoveWearableWarning, client);
							MC_PrintToChat(client, "{red}WARNING: {default}Due to TF2's strict wearables limit, a random base TF2 cosmetic has been removed in order to apply a Creators.TF cosmetic. If you don't wish for this to happen, you can remove a C.TF cosmetic from your C.TF loadout.");
						}
						
						return iWearable;
					}
				}
			}
		}
	}
	
	// We either couldn't apply a cosmetic or we have an invalid item :(
	return -1;
}

//--------------------------------------------------------------------
// Purpose: Finds a cosmetic's definition by the definition index.
// Returns true if found, false otherwise. 
//--------------------------------------------------------------------
public bool FindCosmeticDefinitionByIndex(int defid, CEItemDefinitionCosmetic output)
{
	if (m_hDefinitions == null)return false;
	
	for (int i = 0; i < m_hDefinitions.Length; i++)
	{
		CEItemDefinitionCosmetic hDef;
		m_hDefinitions.GetArray(i, hDef);
		
		if (hDef.m_iIndex == defid)
		{
			output = hDef;
			return true;
		}
	}
	
	return false;
}

//--------------------------------------------------------------------
// Purpose: Parses the schema and reads precaches all the items.
//--------------------------------------------------------------------
public void ProcessEconSchema(KeyValues kv)
{
	delete m_hDefinitions;
	delete m_hStyles;
	m_hDefinitions 	= new ArrayList(sizeof(CEItemDefinitionCosmetic));
	m_hStyles 		= new ArrayList(sizeof(CEItemDefinitionCosmeticStyle));
	
	if (kv == null)return;
	
	if (kv.JumpToKey("Items"))
	{
		if (kv.GotoFirstSubKey())
		{
			do {
				char sType[16];
				kv.GetString("type", sType, sizeof(sType));
				if (!StrEqual(sType, "cosmetic"))continue;
				
				char sIndex[11];
				kv.GetSectionName(sIndex, sizeof(sIndex));
				
				CEItemDefinitionCosmetic hDef;
				hDef.m_iIndex = StringToInt(sIndex);
				hDef.m_iBaseIndex = kv.GetNum("item_index");
				
				char sEquipRegions[64];
				kv.GetString("equip_region", sEquipRegions, sizeof(sEquipRegions));
				hDef.m_iEquipRegion = TF2Wear_ParseEquipRegionString(sEquipRegions);
				
				kv.GetString("world_model", hDef.m_sWorldModel, sizeof(hDef.m_sWorldModel));
				
				if(kv.JumpToKey("visuals/styles", false))
				{
					if(kv.GotoFirstSubKey())
					{
						do {
							int iWorldStyleIndex = m_hStyles.Length;
							int iLocalStyleIndex = hDef.m_iStylesCount;
							
							kv.GetSectionName(sIndex, sizeof(sIndex));
							
							CEItemDefinitionCosmeticStyle xStyle;
							xStyle.m_iIndex = StringToInt(sIndex);
							kv.GetString("world_model", xStyle.m_sWorldModel, sizeof(xStyle.m_sWorldModel));
							
							m_hStyles.PushArray(xStyle);
							
							hDef.m_iStylesCount++;
							hDef.m_iStyles[iLocalStyleIndex] = iWorldStyleIndex;
							
						} while (kv.GotoNextKey());
						kv.GoBack();
					}
					kv.GoBack();
				}
				
				m_hDefinitions.PushArray(hDef);
			} while (kv.GotoNextKey());
		}
	}
	
	kv.Rewind();
}

//--------------------------------------------------------------------
// Purpose: Replaces %s symbol in model path with TF2 class name.
//--------------------------------------------------------------------
public void ParseCosmeticModel(int client, char[] sModel, int size)
{
	switch (TF2_GetPlayerClass(client))
	{
		case TFClass_Scout:ReplaceString(sModel, size, "%s", "scout");
		case TFClass_Soldier:ReplaceString(sModel, size, "%s", "soldier");
		case TFClass_Pyro:ReplaceString(sModel, size, "%s", "pyro");
		case TFClass_DemoMan:ReplaceString(sModel, size, "%s", "demo");
		case TFClass_Heavy:ReplaceString(sModel, size, "%s", "heavy");
		case TFClass_Engineer:ReplaceString(sModel, size, "%s", "engineer");
		case TFClass_Medic:ReplaceString(sModel, size, "%s", "medic");
		case TFClass_Sniper:ReplaceString(sModel, size, "%s", "sniper");
		case TFClass_Spy:ReplaceString(sModel, size, "%s", "spy");
	}
}

//--------------------------------------------------------------------
// Purpose: Returns true if there are weapons that occupy specific
// equip regions.
//--------------------------------------------------------------------
public bool HasOverlappingWeapons(int client, int bits)
{
	for (int i = 0; i < 5; i++)
	{
		int iWeapon = GetPlayerWeaponSlot(client, i);
		if (iWeapon != -1)
		{
			int idx = GetEntProp(iWeapon, Prop_Send, "m_iItemDefinitionIndex");
			int iCompareBits = TF2Econ_GetItemEquipRegionGroupBits(idx);
			if (bits & iCompareBits != 0)return true;
		}
	}
	return false;
}

//--------------------------------------------------------------------
// Purpose: Returns the amount of cosmetics a user has. 
// NOT wearables in general. Just cosmetics.
//--------------------------------------------------------------------
public int GetClientCosmeticsCount(int client)
{
	int iCount = 0;
	
	int next = GetEntPropEnt(client, Prop_Data, "m_hMoveChild");
	while (next != -1)
	{
		int iEdict = next;
		next = GetEntPropEnt(iEdict, Prop_Data, "m_hMovePeer");
		char classname[32];
		GetEntityClassname(iEdict, classname, 32);
		if (strncmp(classname, "tf_wearable", 11) != 0) continue;
		if (!IsWearableCosmetic(iEdict))continue;
		
		iCount++;
	}
	
	return iCount;
}

//--------------------------------------------------------------------
// Purpose: Returns true if we can get another cosmetic equipped.
//--------------------------------------------------------------------
public bool CanGetAnotherCosmetic(int client)
{
	return GetClientCosmeticsCount(client) < MAX_COSMETICS;
}

//--------------------------------------------------------------------
// Purpose: Checks if a wearable is a real cosmetic.
//--------------------------------------------------------------------
public bool IsWearableCosmetic(int wearable)
{
	char sNetClassName[32];
	GetEntityNetClass(wearable, sNetClassName, sizeof(sNetClassName));
	
	// We only remove CTFWearable and CTFWearableCampaignItem items.
	if (!StrEqual(sNetClassName, "CTFWearable") && !StrEqual(sNetClassName, "CTFWearableCampaignItem")) return false;
	
	// Cosmetics have this set.
	if (!HasEntProp(wearable, Prop_Send, "m_iItemDefinitionIndex")) return false;
	int iItemDefIndex = GetEntProp(wearable, Prop_Send, "m_iItemDefinitionIndex");
	if (iItemDefIndex == 0xFFFF) return false;
	// And now go through the items that can occupy weapon slots (e.g Gunboats) and that are
	// tf_wearables. We can use the ItemDefinitionIndex here:
	int m_iListOfWearableWeapons[] =  { 133, 444, 405, 608, 231, 642 };
	
	for (int i = 0; i < sizeof(m_iListOfWearableWeapons); i++)
	{
		if (iItemDefIndex == m_iListOfWearableWeapons[i])
		{
			// We're not allowed to override this.
			return false;
		}
	}
	
	return true;
}

//--------------------------------------------------------------------
// Purpose: Puts the style definition of the cosmetic in buffer
//--------------------------------------------------------------------
public bool GetCosmeticStyleDefinition(CEItemDefinitionCosmetic xCosmetic, int style, CEItemDefinitionCosmeticStyle xBuffer)
{
	for (int i = 0; i < xCosmetic.m_iStylesCount; i++)
	{
		int iWorldIndex = xCosmetic.m_iStyles[i];
		
		CEItemDefinitionCosmeticStyle xStyle;
		m_hStyles.GetArray(iWorldIndex, xStyle);
		
		if(xStyle.m_iIndex == style)
		{
			xBuffer = xStyle;
			return true;
		}
	}
	return false;
}

//--------------------------------------------------------------------
// Purpose: Fired when cosmetic style changes.
//--------------------------------------------------------------------
public void CEconItems_OnCustomEntityStyleUpdated(int client, int entity, int style)
{
	CEItem xItem;
	if(CEconItems_GetEntityItemStruct(entity, xItem))
	{
		CEItemDefinitionCosmetic xCosmetic;
		if(FindCosmeticDefinitionByIndex(xItem.m_iItemDefinitionIndex, xCosmetic))
		{
			CEItemDefinitionCosmeticStyle xStyle;
			if(GetCosmeticStyleDefinition(xCosmetic, style, xStyle))
			{
				char sModel[PLATFORM_MAX_PATH];
				strcopy(sModel, sizeof(sModel), xStyle.m_sWorldModel);
				ParseCosmeticModel(client, sModel, sizeof(sModel));
				
				TF2Wear_SetModel(entity, sModel);
			}
		}
	}
}

//--------------------------------------------------------------------
// Purpose: If returned value is true, this item will be blocked.
// We check here to see if this item can be used on this server.
//--------------------------------------------------------------------

/* 	PROVIDER CODE SUPPORT WILL BE IMPLEMENTED AT A FUTURE POINT
	DON'T WORRY ABOUT ME FOR NOW
	
public bool CEconItems_ShouldItemBeBlocked(int client, CEItem xItem, const char[] type)
{
	if (!StrEqual(type, "cosmetic"))return false;
	
	// Grab our provider ID:
	char providerID[16];
	CEcon_GetServerProvider(providerID, sizeof(providerID));

	// Grab the item definition from the schema here:
	CEItemDefinition xDef;
	if (CEconItems_GetItemDefinitionByIndex(xItem.m_iIndex, xDef))
	{
		// Does this servers provider ID match this economy item?
		// If so, we wont block it by returning the opposite of StrEqual
		// (in this case, true to false. If it doesn't, it'll be false to
		// true instead).
		return !StrEqual(providerID, xDef.m_sProvider, true);
	}
	return false;
}
*/