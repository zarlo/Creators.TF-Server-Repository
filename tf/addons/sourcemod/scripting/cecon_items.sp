//============= Copyright Amper Software 2021, All rights reserved. ============//
//
// Purpose: Loadout, attributes, items module for Creators.TF
// Custom Economy.
//
//=========================================================================//

//===============================//
// DOCUMENTATION

/* HOW DOES THE LOADOUT SYSTEM WORK?
*
*	When player requests their loadout (this happens when player respawns
*	or touches ressuply locker), we run Loadout_InventoryApplication function.
*	This function checks if we already have loadout information loaded for this
*	specific player. If we have, apply the loadout right away using `Loadout_ApplyLoadout`.
*
*	If we dont, we request loadout info for the player from the backend using
*	`Loadout_RequestPlayerLoadout`. The response for this request is parsed into m_Loadout[client] array.
*	m_Loadout[client] contains X ArrayLists, where X is the amount of classes that we have loadouts for.
*	(For TF2, the X value is 11. In consists of: 9 (TF2 Classes) + 1 (General Items Class) + 1 (Unknown Class)).
*
*	When we are sure we have loadout information available, `Loadout_ApplyLoadout` is run. This function checks
*	which equipped items player is able to wear, and which items we need to holster from player.
*
*	If an item is eligible for being equipped, we run a forward with all the data about this item
*	to the subplugins, who will take care of managing what these items need to do when equipped.
*
*/

/* DIFFERENCE BETWEEN EQUIPPED AND WEARABLE ITEMS
*
*	Terminology:
*	"(Item) Equipped" 	- Item is in player loadout.
*	"Wearing (Item)"	- Player is currently wearing this item.
*
*	Why?
*	Sometimes player loadout might not match what player
*	actually has equipped. This can happen, for example, with
*	holiday restricted items. They are only wearable during holidays.
*	Also some specific item types are auto-unequipped by the game itself
*	when player touches ressuply locker. This happens with Cosmetics and
*	Weapons. To prevent mismatch between equipped items and wearable items,
*	we keep track of them separately.
*/
//===============================//

#pragma semicolon 1
#pragma newdecls required
#pragma tabsize 0

#define MAX_ENTITY_LIMIT 2048

#include <cecon>
#include <cecon_http>
#include <cecon_items>

#include <sdktools>
#include <sdkhooks>
#include <tf2>
#include <tf2_stocks>
#include <tf2attributes>
//#include <tf_persist_item>
#include <tf_econ_data>

// ?
// there's an updated vers of steamtools inc, u guys know that rite
#pragma newdecls optional
#include <steamtools>
#pragma newdecls required

#define BACKEND_ATTRIBUTE_UPDATE_INTERVAL 30.0 // Every 30 seconds.

public Plugin myinfo =
{
	name = "Creators.TF Items Module",
	author = "Creators.TF Team",
	description = "Loadout, attributes, items module for Creators.TF Custom Economy.",
	version = "1.1.2",
	url = "https://creators.tf"
}

// Forwards.
Handle 	g_CEcon_ShouldItemBeBlocked,
		g_CEcon_OnEquipItem,
		g_CEcon_OnItemIsEquipped,
		g_CEcon_OnClientLoadoutUpdated,

		g_CEcon_OnUnequipItem,
		g_CEcon_OnItemIsUnequipped,

		g_CEcon_OnCustomEntityStyleUpdated;

// 	we should use sm-tf2econdata
// SDKCalls for native TF2 economy reading.
//Handle 	g_SDKCallGetEconItemSchema,
//		g_SDKCallSchemaGetAttributeDefinitionByName;

// Variables, needed to attach a specific CEItem to an entity.
bool m_bIsEconItem[MAX_ENTITY_LIMIT + 1];
CEItem m_hEconItem[MAX_ENTITY_LIMIT + 1];

// ArrayLists
ArrayList m_ItemDefinitons = null;

// Dictionaries (Optimization concerns)
StringMap m_IndexedDictionary;

// Loadouts
ArrayList m_PartialReapplicationTypes = null;

bool m_bLoadoutCached[MAXPLAYERS + 1];
//ArrayList m_Loadout[MAXPLAYERS + 1][CEconLoadoutClass];
ArrayList m_Loadout[MAXPLAYERS + 1][view_as<int>(CEconLoadoutClass)]; 	// Cached loadout data of a user.
ArrayList m_MyItems[MAXPLAYERS + 1]; 						// Array of items this user is wearing.

bool m_bWaitingForLoadout[MAXPLAYERS + 1];
bool m_bInRespawn[MAXPLAYERS + 1];
bool m_bFullReapplication[MAXPLAYERS + 1];
TFClassType m_nLoadoutUpdatedForClass[MAXPLAYERS + 1];

ConVar ce_items_use_backend_loadout;

/*
	TODO(Zonical): Version 1.2
		- Start experimentation of whether wearables are consistent (e.g not despawned on player death and whatnot).
		- Attempt some optimisations of applying loadouts by comparing two different loadout states: OLD and CURRENT.
		If an item is in both OLD and CURRENT, we shouldn't bother at all about applying that item, and just keep it
		on the player. TF2_OnReplaceItem should handle the rest for us. If an item is in OLD but not in CURRENT, we
		know we should remove it. This could save having to create and destroy a lot of entities, which could be the
		source for FPS issues that have been going on recently.
		- Create natives for grabbing a persons loadout by class. This could make disguised spies applying other peoples
		cosmetics a possibility. CEconItems_GetClientClassLoadout(int client, CEconLoadoutClass class)?
*/

// Native and Forward creation.
public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	RegPluginLibrary("cecon_items");

	g_CEcon_ShouldItemBeBlocked 	= new GlobalForward("CEconItems_ShouldItemBeBlocked", ET_Event, Param_Cell, Param_Array, Param_String);
	g_CEcon_OnEquipItem 			= new GlobalForward("CEconItems_OnEquipItem", ET_Event, Param_Cell, Param_Array, Param_String);
	g_CEcon_OnItemIsEquipped 		= new GlobalForward("CEconItems_OnItemIsEquipped", ET_Ignore, Param_Cell, Param_Cell, Param_Array, Param_String);
	g_CEcon_OnClientLoadoutUpdated 	= new GlobalForward("CEconItems_OnClientLoadoutUpdated", ET_Ignore, Param_Cell);

	g_CEcon_OnUnequipItem 			= new GlobalForward("CEconItems_OnUnequipItem", ET_Single, Param_Cell, Param_Array, Param_String);
	g_CEcon_OnItemIsUnequipped		= new GlobalForward("CEconItems_OnItemIsUnequipped", ET_Single, Param_Cell, Param_Array, Param_String);

	g_CEcon_OnCustomEntityStyleUpdated	= new GlobalForward("CEconItems_OnCustomEntityStyleUpdated", ET_Ignore, Param_Cell, Param_Cell, Param_Cell);

	// Items
    CreateNative("CEconItems_CreateNamedItem", Native_CreateNamedItem);
	CreateNative("CEconItems_CreateItem", Native_CreateItem);
	CreateNative("CEconItems_DestroyItem", Native_DestroyItem);

    CreateNative("CEconItems_IsEntityCustomEconItem", Native_IsEntityCustomEconItem);
    CreateNative("CEconItems_GetEntityItemStruct", Native_GetEntityItemStruct);

	CreateNative("CEconItems_GetItemDefinitionByIndex", Native_GetItemDefinitionByIndex);
	CreateNative("CEconItems_GetItemDefinitionByName", Native_GetItemDefinitionByName);


	// Attributes
	CreateNative("CEconItems_MergeAttributes", Native_MergeAttributes);
	CreateNative("CEconItems_AttributesKeyValuesToArrayList", Native_AttributesKeyValuesToArrayList);

	CreateNative("CEconItems_GetAttributeStringFromArray", Native_GetAttributeStringFromArray);
	CreateNative("CEconItems_GetAttributeIntegerFromArray", Native_GetAttributeIntegerFromArray);
	CreateNative("CEconItems_GetAttributeFloatFromArray", Native_GetAttributeFloatFromArray);
	CreateNative("CEconItems_GetAttributeBoolFromArray", Native_GetAttributeBoolFromArray);

	CreateNative("CEconItems_SetAttributeStringInArray", Native_SetAttributeStringInArray);
	CreateNative("CEconItems_SetAttributeIntegerInArray", Native_SetAttributeIntegerInArray);
	CreateNative("CEconItems_SetAttributeFloatInArray", Native_SetAttributeFloatInArray);
	CreateNative("CEconItems_SetAttributeBoolInArray", Native_SetAttributeBoolInArray);

	CreateNative("CEconItems_GetEntityAttributeString", Native_GetEntityAttributeString);
	CreateNative("CEconItems_GetEntityAttributeInteger", Native_GetEntityAttributeInteger);
	CreateNative("CEconItems_GetEntityAttributeFloat", Native_GetEntityAttributeFloat);
	CreateNative("CEconItems_GetEntityAttributeBool", Native_GetEntityAttributeBool);

	CreateNative("CEconItems_SetEntityAttributeString", Native_SetEntityAttributeString);
	CreateNative("CEconItems_SetEntityAttributeInteger", Native_SetEntityAttributeInteger);
	CreateNative("CEconItems_SetEntityAttributeFloat", Native_SetEntityAttributeFloat);
	CreateNative("CEconItems_SetEntityAttributeBool", Native_SetEntityAttributeBool);

    CreateNative("CEconItems_IsAttributeNameOriginal", Native_IsAttributeNameOriginal);
    CreateNative("CEconItems_ApplyOriginalAttributes", Native_ApplyOriginalAttributes);

    // Loadout
    CreateNative("CEconItems_RequestClientLoadoutUpdate", Native_RequestClientLoadoutUpdate);
    CreateNative("CEconItems_IsClientLoadoutCached", Native_IsClientLoadoutCached);

    CreateNative("CEconItems_IsClientWearingItem", Native_IsClientWearingItem);
    CreateNative("CEconItems_IsItemFromClientClassLoadout", Native_IsItemFromClientClassLoadout);
    CreateNative("CEconItems_IsItemFromClientLoadout", Native_IsItemFromClientLoadout);

    CreateNative("CEconItems_GiveItemToClient", Native_GiveItemToClient);
    CreateNative("CEconItems_RemoveItemFromClient", Native_RemoveItemFromClient);

    CreateNative("CEconItems_GetClientLoadoutSize", Native_GetClientLoadoutSize);
    CreateNative("CEconItems_GetClientItemFromLoadoutByIndex", Native_GetClientItemFromLoadoutByIndex);

    CreateNative("CEconItems_GetClientWearedItemsCount", Native_GetClientWearedItemsCount);
    CreateNative("CEconItems_GetClientWearedItemByIndex", Native_GetClientWearedItemByIndex);

    // Styles
    CreateNative("CEconItems_SetCustomEntityStyle", Native_SetCustomEntityStyle);

    return APLRes_Success;
}

//---------------------------------------------------------------------
// Purpose: Precache item definitions on plugin load.
//---------------------------------------------------------------------
public void OnAllPluginsLoaded()
{
	// Items
    PrecacheItemsFromSchema(CEcon_GetEconomySchema());
}

//---------------------------------------------------------------------
// Purpose: Precache item definitions on late schema update.
//---------------------------------------------------------------------
public void CEcon_OnSchemaUpdated(KeyValues hSchema)
{
    PrecacheItemsFromSchema(hSchema);
}

public void OnPluginStart()
{
	// Attributes
	//Handle hGameConf = LoadGameConfigFile("tf2.creators");
	//if (!hGameConf)
	//{
	//	SetFailState("Failed to load gamedata (tf2.creators).");
	//}

	/*

	StartPrepSDKCall(SDKCall_Static);
	PrepSDKCall_SetFromConf(hGameConf, SDKConf_Signature, "GEconItemSchema");
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
	g_SDKCallGetEconItemSchema = EndPrepSDKCall();

	StartPrepSDKCall(SDKCall_Raw);
	PrepSDKCall_SetFromConf(hGameConf, SDKConf_Signature, "CEconItemSchema::GetAttributeDefinitionByName");
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
	PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
	g_SDKCallSchemaGetAttributeDefinitionByName = EndPrepSDKCall();

	*/
	// Loadout
	HookEvent("post_inventory_application", post_inventory_application);
	HookEvent("player_spawn", player_spawn);
	HookEvent("player_death", player_death);

	m_PartialReapplicationTypes = new ArrayList(ByteCountToCells(32));
	m_PartialReapplicationTypes.PushString("cosmetic");
	m_PartialReapplicationTypes.PushString("weapon");

	RegServerCmd("ce_loadout_reset", cResetLoadout);
	RegAdminCmd("ce_item_debug", cItemDebug, ADMFLAG_ROOT);

	CreateTimer(BACKEND_ATTRIBUTE_UPDATE_INTERVAL, Timer_AttributeUpdateInterval, _, TIMER_REPEAT);

	ce_items_use_backend_loadout = CreateConVar("ce_items_use_backend_loadout", "1");
}

public Action cResetLoadout(int args)
{
	char sArg1[64], sArg2[11];
	GetCmdArg(1, sArg1, sizeof(sArg1));
	GetCmdArg(2, sArg2, sizeof(sArg2));

	int iTarget = FindTargetBySteamID64(sArg1);
	if (IsClientValid(iTarget))
	{
		if (m_bWaitingForLoadout[iTarget])return Plugin_Handled;

		m_nLoadoutUpdatedForClass[iTarget] = TF2_GetClass(sArg2);
		CEconItems_RequestClientLoadoutUpdate(iTarget, false);

	}
	return Plugin_Handled;
}

public Action cItemDebug(int client, int args)
{
	char argument[64];

	if (args > 0)
	{
		GetCmdArg(1, argument, sizeof(argument));

		// Special edge cases here first:
		if (StrEqual(argument, "active_weapon", false))
		{
			int iWeapon = CEcon_GetLastUsedWeapon(client);

			CEItem xItem;
			CEconItems_GetEntityItemStruct(iWeapon, xItem);

			CEItemDefinition xDef;

			// Grab the Item Definition of the item (sounds weird, I know).
			if(CEconItems_GetItemDefinitionByIndex(xItem.m_iItemDefinitionIndex, xDef))
			{
				// Print out the information:
				PrintToConsole(client, "ACTIVE CLIENTS WEAPON");
				PrintToConsole(client, "\"%s\" (%s) =", xDef.m_sName, xDef.m_sType);
				PrintToConsole(client, "[");
				PrintToConsole(client, "	m_iIndex = %d", xItem.m_iIndex);
				PrintToConsole(client, "	m_iItemDefinitionIndex = %d", xItem.m_iItemDefinitionIndex);
				PrintToConsole(client, "	m_nQuality = %d", xItem.m_nQuality);
				PrintToConsole(client, "	m_Attributes =");
				PrintToConsole(client, "	[");

				// Print out all of the attributes.
				for (int j = 0; j < xItem.m_Attributes.Length; j++)
				{
					CEAttribute xAttr;
					xItem.m_Attributes.GetArray(j, xAttr);

					PrintToConsole(client, "		\"%s\" = \"%s\"", xAttr.m_sName, xAttr.m_sValue);
				}
				PrintToConsole(client, "	]");
				PrintToConsole(client, "]");
				PrintToConsole(client, "");

				return Plugin_Handled;
			}
		}
	}


	// Go through each of the items on the user:
	int iCount = CEconItems_GetClientWearedItemsCount(client);
	for (int i = 0; i < iCount; i++)
	{
		// Grab the item.
		CEItem xItem;
		if(CEconItems_GetClientWearedItemByIndex(client, i, xItem))
		{
			CEItemDefinition xDef;

			// Grab the Item Definition of the item (sounds weird, I know).
			if(CEconItems_GetItemDefinitionByIndex(xItem.m_iItemDefinitionIndex, xDef))
			{
				// ZoNiCaL - For a nicer debugging experience (mainly for me) and to see information that I only really want,
				// you can now only show certain information (e.g weapons only, cosmetics, etc...)
				//if (!StrEqual(argument, xDef.m_sType, false) && args > 0) { continue; }

				// Print out the information:
				PrintToConsole(client, "[%d] \"%s\" (%s) =", i, xDef.m_sName, xDef.m_sType);
				PrintToConsole(client, "[");
				PrintToConsole(client, "	m_iIndex = %d", xItem.m_iIndex);
				PrintToConsole(client, "	m_iItemDefinitionIndex = %d", xItem.m_iItemDefinitionIndex);
				PrintToConsole(client, "	m_nQuality = %d", xItem.m_nQuality);
				PrintToConsole(client, "	m_Attributes =");
				PrintToConsole(client, "	[");

				// Print out all of the attributes.
				for (int j = 0; j < xItem.m_Attributes.Length; j++)
				{
					CEAttribute xAttr;
					xItem.m_Attributes.GetArray(j, xAttr);

					PrintToConsole(client, "		\"%s\" = \"%s\"", xAttr.m_sName, xAttr.m_sValue);
				}
				PrintToConsole(client, "	]");
				PrintToConsole(client, "]");
				PrintToConsole(client, "");
			}
		}
	}

	return Plugin_Handled;

}

//---------------------------------------------------------------------
// Purpose: Parses the schema keyvalues and adds all the definition
// structs in the cache.
//---------------------------------------------------------------------
public void PrecacheItemsFromSchema(KeyValues hSchema)
{
	// Clean loadout cache for everyone.
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i))continue;
		ClearClientLoadout(i, false);
	}

    // Make sure to remove all previous definitions if exist.
	FlushItemDefinitionCache();

    // Initiate the array.
	m_ItemDefinitons = new ArrayList(sizeof(CEItemDefinition));
	m_IndexedDictionary = new StringMap();

	if (hSchema == null)return;

	if(hSchema.JumpToKey("Items"))
	{
		if(hSchema.GotoFirstSubKey())
		{
			do {
				CEItemDefinition hDef;

                // We retrieve the defid of this defintion from the section name
                // of the current KV stack we're in.
				char sSectionName[11];
				hSchema.GetSectionName(sSectionName, sizeof(sSectionName));

                // Definition index.
				hDef.m_iIndex = StringToInt(sSectionName);

                // Base item name and type.
				hSchema.GetString("name", hDef.m_sName, sizeof(hDef.m_sName));
				hSchema.GetString("type", hDef.m_sType, sizeof(hDef.m_sType));
				//hSchema.GetString("provider", hDef.m_sProvider, sizeof(hDef.m_sProvider), "[PRV:1]");

                // Getting attributes.
                if(hSchema.JumpToKey("attributes"))
				{
                    // Converting attributes from KeyValues to ArrayList format.
					hDef.m_Attributes = CEconItems_AttributesKeyValuesToArrayList(hSchema);
					hSchema.GoBack();
				}

				int iNumericIndex = m_ItemDefinitons.Length;

				m_IndexedDictionary.SetValue(sSectionName, iNumericIndex, true);
				m_IndexedDictionary.SetValue(hDef.m_sName, iNumericIndex, true);

                // Push this struct to the cache storage.
				m_ItemDefinitons.PushArray(hDef);

			} while (hSchema.GotoNextKey());
		}
	}

    // Make sure we do that every time
	hSchema.Rewind();
}

//---------------------------------------------------------------------
// Purpose: Fired before the schema is loaded.
//---------------------------------------------------------------------
public void CEcon_OnSchemaPreUpdate(KeyValues hSchema)
{
	ParseExtraItemsAndAddToSchema(hSchema);
}

//---------------------------------------------------------------------
// Purpose: Add items from override folder to the item list.
//---------------------------------------------------------------------
public void ParseExtraItemsAndAddToSchema(KeyValues hSchema)
{
	if(hSchema.JumpToKey("Items"))
	{
		char sPath[64];
		BuildPath(Path_SM, sPath, sizeof(sPath), "configs/cecon_items");
		if(!DirExists(sPath))
		{
			return;
		}

		int iLastIndex = -1;
		bool bIsAvailable;

		DirectoryListing hDir = OpenDirectory(sPath);
		char sFileName[PLATFORM_MAX_PATH];
		while(hDir.GetNext(sFileName, sizeof(sFileName)))
		{
			Format(sFileName, sizeof(sFileName), "%s\\%s", sPath, sFileName);
			if (!FileExists(sFileName))continue;


			KeyValues hBuffer = new KeyValues("Item");
			if (!hBuffer.ImportFromFile(sFileName))
			{
				LogError("Failed to load \"%s\". Check syntax of the file.", sFileName);
				continue;
			}

			char sName[11];

			do {

				iLastIndex++;
				IntToString(iLastIndex, sName, sizeof(sName));

				if(hSchema.JumpToKey(sName, false))
				{
					bIsAvailable = false;
					hSchema.GoBack();
				} else {
					bIsAvailable = true;
				}

			} while (!bIsAvailable);

			if(hSchema.JumpToKey(sName, true))
			{
				LogMessage("Asigning \"%s\" to item index %s", sFileName, sName);
				hSchema.Import(hBuffer);
				hSchema.GoBack();
			}

			delete hBuffer;

		}
	}

	hSchema.Rewind();
}

//---------------------------------------------------------------------
// Native: CEconItems_GetItemDefinitionByIndex
//---------------------------------------------------------------------
public any Native_GetItemDefinitionByIndex(Handle plugin, int numParams)
{
	int index = GetNativeCell(1);

	if (m_IndexedDictionary == null)return false;
	if (m_ItemDefinitons == null)return false;

	char sIndex[11];
	IntToString(index, sIndex, sizeof(sIndex));

	int iIndex;
	if(m_IndexedDictionary.GetValue(sIndex, iIndex))
	{
		if(iIndex <= m_ItemDefinitons.Length)
		{
			CEItemDefinition buffer;
			m_ItemDefinitons.GetArray(iIndex, buffer);

			SetNativeArray(2, buffer, sizeof(CEItemDefinition));
			return true;
		}

	}
	return false;
}

//---------------------------------------------------------------------
// Native: CEconItems_GetItemDefinitionByName
//---------------------------------------------------------------------
public any Native_GetItemDefinitionByName(Handle plugin, int numParams)
{
	char sName[128];
	GetNativeString(1, sName, sizeof(sName));
	if (StrEqual(sName, ""))return false;

	if (m_IndexedDictionary == null)return false;
	if (m_ItemDefinitons == null)return false;

	int iIndex;
	if(m_IndexedDictionary.GetValue(sName, iIndex))
	{
		if(iIndex <= m_ItemDefinitons.Length)
		{
			CEItemDefinition buffer;
			m_ItemDefinitons.GetArray(iIndex, buffer);

			SetNativeArray(2, buffer, sizeof(CEItemDefinition));
			return true;
		}

	}
	return false;
}

//---------------------------------------------------------------------
// Purpose: Flushes item definition cache.
//---------------------------------------------------------------------
public void FlushItemDefinitionCache()
{
	if (m_ItemDefinitons == null)return;

    // We go through every element in the array...
	for (int i = 0; i < m_ItemDefinitons.Length; i++)
	{
		CEItemDefinition buffer;
		m_ItemDefinitons.GetArray(i, buffer);

        // And make sure to remove the ArrayList of attrubutes.
        // So that we don't cause a memory leak.
		delete buffer.m_Attributes;
	}

    // Clean the array itself.
	delete m_ItemDefinitons;

	delete m_IndexedDictionary;
}

//---------------------------------------------------------------------
// Purpose: Returns true if this item was made by the economy.
//---------------------------------------------------------------------
public bool IsEntityCustomEconItem(int entity)
{
	return m_bIsEconItem[entity];
}

//---------------------------------------------------------------------
// Purpose: Creates a CEItem struct out of all the params that were
// provided.
// Note: m_Attributes member of returned CEItem contains merged static
// and override attributes. However you only provide override
// attrubutes in this function.
// Native: CEconItems_CreateItem
//---------------------------------------------------------------------
public any Native_CreateItem(Handle plugin, int numParams)
{
    int defid = GetNativeCell(2);
    int quality = GetNativeCell(3);
    ArrayList overrides = GetNativeCell(4);

	CEItemDefinition hDef;
	if (!CEconItems_GetItemDefinitionByIndex(defid, hDef))return false;

	CEItem buffer;

	buffer.m_iItemDefinitionIndex = defid;
	buffer.m_nQuality = quality;
	buffer.m_Attributes = CEconItems_MergeAttributes(hDef.m_Attributes, overrides);

    SetNativeArray(1, buffer, sizeof(CEItem));

	return true;
}

//---------------------------------------------------------------------
// Native: CEconItems_CreateNamedItem
//---------------------------------------------------------------------
public any Native_CreateNamedItem(Handle plugin, int numParams)
{
	char sName[128];
	GetNativeString(2, sName, sizeof(sName));

    int quality = GetNativeCell(3);
    ArrayList overrides = GetNativeCell(4);

	CEItemDefinition hDef;
	if (!CEconItems_GetItemDefinitionByName(sName, hDef))return false;

	CEItem buffer;

	buffer.m_iItemDefinitionIndex = hDef.m_iIndex;
	buffer.m_nQuality = quality;
	buffer.m_Attributes = CEconItems_MergeAttributes(hDef.m_Attributes, overrides);

    SetNativeArray(1, buffer, sizeof(CEItem));

	return true;
}

//---------------------------------------------------------------------
// Native: CEconItems_DestroyItem
//---------------------------------------------------------------------
public any Native_DestroyItem(Handle plugin, int numParams)
{
	CEItem hItem;
	GetNativeArray(1, hItem, sizeof(CEItem));

	delete hItem.m_Attributes;

	SetNativeArray(1, hItem, sizeof(CEItem));
}

//---------------------------------------------------------------------
// Purpose: Gives players a specific item, defined by the struct.
//---------------------------------------------------------------------
public bool GivePlayerCEItem(int client, CEItem item)
{
    // TODO: Make a client check.

	// First, let's see if this item's definition even exists.
	// If it's not, we return false as a sign of an error.
	CEItemDefinition hDef;
	if (!CEconItems_GetItemDefinitionByIndex(item.m_iItemDefinitionIndex, hDef))return false;

	// This boolean will be returned in the end of this func's execution.
	// It shows whether item was actually created.
	bool bResult = false;

	// Let's ask subplugins if they're fine with equipping this item.
	Call_StartForward(g_CEcon_ShouldItemBeBlocked);
	Call_PushCell(client);
	Call_PushArray(item, sizeof(CEItem));
	Call_PushString(hDef.m_sType);

	bool bShouldBlock = false;
	Call_Finish(bShouldBlock);

	// If noone responded or response is positive, equip this item.
	if (GetForwardFunctionCount(g_CEcon_ShouldItemBeBlocked) == 0 || !bShouldBlock)
	{
        // Start a forward to engage subplugins to initialize the item.
		Call_StartForward(g_CEcon_OnEquipItem);
		Call_PushCell(client);
		Call_PushArray(item, sizeof(CEItem));
		Call_PushString(hDef.m_sType);
		int iEntity = -1;
		Call_Finish(iEntity);

        // If subplugins return an entity index, we attach the given CEItem struct to it.
        // We'll then remove clear all the attributes to set this weapon to base stats,
        // and then apply original TF attributes if possible.
		if(IsEntityValid(iEntity))
		{
			m_bIsEconItem[iEntity] = true;
			m_hEconItem[iEntity] = item;

			// Remove all of the TF2 Attributes.
			
			// When we merged econ/persist-item into master, this caused a regression bug
			// where MVM upgrades would get removed. TODO (ZoNiCaL): Possibly look at a way of
			// preserving MVM upgrades but doing this step as well?
		
			//TF2Attrib_RemoveAll(iEntity);
			
			// If we have any original attributes in our attribute list,
			// make sure to apply them here.
			CEconItems_ApplyOriginalAttributes(iEntity);
			
			// Set our item style to default. Other plugins should override this
			// on CEconItems_OnItemIsEquipped as they'll have access to this entity
			// by then.
			CEconItems_SetCustomEntityStyle(iEntity, 0);
		}

		// Alerting subplugins that this item was equipped.
		Call_StartForward(g_CEcon_OnItemIsEquipped);
		Call_PushCell(client);
		Call_PushCell(iEntity);
		Call_PushArray(item, sizeof(CEItem));
		Call_PushString(hDef.m_sType);
		Call_Finish();

        // Item was successfully created.
		bResult = true;
	}

	return bResult;
}

//---------------------------------------------------------------------
// Native: CEconItems_IsEntityCustomEconItem
//---------------------------------------------------------------------
public any Native_IsEntityCustomEconItem(Handle plugin, int numParams)
{
	int iEntity = GetNativeCell(1);
	if (!IsEntityValid(iEntity))return false;

	return IsEntityCustomEconItem(iEntity);
}

//=======================================================//
// ATTRIBUTES
//=======================================================//

//---------------------------------------------------------------------
// Purpose: Transforms a keyvalues of attributes into an ArrayList of
// CEAttribute-s.
// Native: CEconItems_AttributesKeyValuesToArrayList
//---------------------------------------------------------------------
public any Native_AttributesKeyValuesToArrayList(Handle plugin, int numParams)
{
    KeyValues kv = GetNativeCell(1);
	if (kv == null)return kv;

	ArrayList Attributes = new ArrayList(sizeof(CEAttribute));
	if(kv.GotoFirstSubKey(false))
	{
		do {
			CEAttribute attr;

			// Test if this attribute is written in compact mode.
			kv.GetString(NULL_STRING, attr.m_sValue, sizeof(attr.m_sValue));
			if(StrEqual(attr.m_sValue, ""))
			{
				// If it's not, then get values inside the keys.
				kv.GetString("name", attr.m_sName, sizeof(attr.m_sName));
				kv.GetString("value", attr.m_sValue, sizeof(attr.m_sValue));
			} else {
				// Otherwise, we already have the value in the struct, so just
				// get the section name as the name.
				kv.GetSectionName(attr.m_sName, sizeof(attr.m_sName));
			}

			Attributes.PushArray(attr);
		} while (kv.GotoNextKey(false));
		kv.GoBack();
	}

	return Attributes;
}

//---------------------------------------------------------------------
// Purpose: Merges two attribute arrays together. Attributes with same
// names from array1 will be overwritten by value in array2.
// Native: CEconItems_MergeAttributes
//---------------------------------------------------------------------
public any Native_MergeAttributes(Handle plugin, int numParams)
{
    ArrayList hArray1 = GetNativeCell(1);
    ArrayList hArray2 = GetNativeCell(2);

	if (hArray1 == null && hArray2 == null)
	{
		return new ArrayList(sizeof(CEAttribute));
	} else if(hArray1 == null)
	{
		return hArray2.Clone();
	} else if(hArray2 == null)
	{
		return hArray1.Clone();
	}

	ArrayList hResult = hArray1.Clone();

	int size = hResult.Length;
	for (int i = 0; i < hArray2.Length; i++)
	{
		CEAttribute newAttr;
		hArray2.GetArray(i, newAttr);

		for (int j = 0; j < size; j++)
		{
			CEAttribute oldAttr;
			hResult.GetArray(j, oldAttr);
			if (StrEqual(oldAttr.m_sName, newAttr.m_sName))
			{
				hResult.Erase(j);
				j--;
				size--;
			}
		}
		hResult.PushArray(newAttr);
	}

	return hResult;
}

// ARRAYLIST ATTRIBUTES
// ================================== //

//---------------------------------------------------------------------
// Native: CEconItems_GetAttributeStringFromArray
//---------------------------------------------------------------------
public any Native_GetAttributeStringFromArray(Handle plugin, int numParams)
{
    ArrayList hArray = GetNativeCell(1);
    if(hArray == null) return false;
    char sName[128];
    GetNativeString(2, sName, sizeof(sName));
    int length = GetNativeCell(4);

	for(int i = 0; i < hArray.Length; i++)
	{
		CEAttribute hAttr;
		hArray.GetArray(i, hAttr);

		if(StrEqual(hAttr.m_sName, sName))
		{
            SetNativeString(3, hAttr.m_sValue, length);
			return true;
		}
	}
	return false;
}

//---------------------------------------------------------------------
// Native: CEconItems_GetAttributeIntegerFromArray
//---------------------------------------------------------------------
public any Native_GetAttributeIntegerFromArray(Handle plugin, int numParams)
{
    ArrayList hArray = GetNativeCell(1);
    if(hArray == null) return 0;

    char name[128];
    GetNativeString(2, name, sizeof(name));

	char sBuffer[11];
	CEconItems_GetAttributeStringFromArray(hArray, name, sBuffer, sizeof(sBuffer));

	return StringToInt(sBuffer);
}

//---------------------------------------------------------------------
// Native: CEconItems_GetAttributeFloatFromArray
//---------------------------------------------------------------------
public any Native_GetAttributeFloatFromArray(Handle plugin, int numParams)
{
    ArrayList hArray = GetNativeCell(1);
    if(hArray == null) return 0.0;

    char name[128];
    GetNativeString(2, name, sizeof(name));

	char sBuffer[11];
	CEconItems_GetAttributeStringFromArray(hArray, name, sBuffer, sizeof(sBuffer));

	return StringToFloat(sBuffer);
}

//---------------------------------------------------------------------
// Native: CEconItems_GetAttributeBoolFromArray
//---------------------------------------------------------------------
public any Native_GetAttributeBoolFromArray(Handle plugin, int numParams)
{
    ArrayList hArray = GetNativeCell(1);
    if(hArray == null) return false;

    char name[128];
    GetNativeString(2, name, sizeof(name));

	char sBuffer[11];
	CEconItems_GetAttributeStringFromArray(hArray, name, sBuffer, sizeof(sBuffer));

	return StringToInt(sBuffer) > 0;
}

//---------------------------------------------------------------------
// Native: CEconItems_SetAttributeStringInArray
//---------------------------------------------------------------------
public any Native_SetAttributeStringInArray(Handle plugin, int numParams)
{
    ArrayList hArray = GetNativeCell(1);
    if(hArray == null) return;

    char sName[128], sValue[128];
    GetNativeString(2, sName, sizeof(sName));
    GetNativeString(3, sValue, sizeof(sValue));

	for(int i = 0; i < hArray.Length; i++)
	{
		CEAttribute hAttr;
		hArray.GetArray(i, hAttr);

		if(StrEqual(hAttr.m_sName, sName))
		{
			hArray.Erase(i);
			i--;
		}
	}

	CEAttribute xNewAttr;
	strcopy(xNewAttr.m_sName, sizeof(xNewAttr.m_sName), sName);
	strcopy(xNewAttr.m_sValue, sizeof(xNewAttr.m_sValue), sValue);
	hArray.PushArray(xNewAttr);

	return;
}


//---------------------------------------------------------------------
// Native: CEconItems_SetAttributeIntegerInArray
//---------------------------------------------------------------------
public any Native_SetAttributeIntegerInArray(Handle plugin, int numParams)
{
    ArrayList hArray = GetNativeCell(1);
    if(hArray == null) return;

    char sName[128], sValue[128];
    GetNativeString(2, sName, sizeof(sName));

    int iValue = GetNativeCell(3);
    IntToString(iValue, sValue, sizeof(sValue));

    CEconItems_SetAttributeStringInArray(hArray, sName, sValue);

	return;
}

//---------------------------------------------------------------------
// Native: CEconItems_SetAttributeFloatInArray
//---------------------------------------------------------------------
public any Native_SetAttributeFloatInArray(Handle plugin, int numParams)
{
    ArrayList hArray = GetNativeCell(1);
    if(hArray == null) return;

    char sName[128], sValue[128];
    GetNativeString(2, sName, sizeof(sName));

    float flValue = GetNativeCell(3);
    FloatToString(flValue, sValue, sizeof(sValue));

    CEconItems_SetAttributeStringInArray(hArray, sName, sValue);

	return;
}

//---------------------------------------------------------------------
// Native: CEconItems_SetAttributeBoolInArray
//---------------------------------------------------------------------
public any Native_SetAttributeBoolInArray(Handle plugin, int numParams)
{
    ArrayList hArray = GetNativeCell(1);
    if(hArray == null) return;

    char sName[128], sValue[128];
    GetNativeString(2, sName, sizeof(sName));

    bool bValue = GetNativeCell(3);
    IntToString(bValue ? 1 : 0, sValue, sizeof(sValue));

    CEconItems_SetAttributeStringInArray(hArray, sName, sValue);

	return;
}


// ENTITY ATTRIBUTES
// ================================== //

//---------------------------------------------------------------------
// Native: CEconItems_GetEntityAttributeString
//---------------------------------------------------------------------
public any Native_GetEntityAttributeString(Handle plugin, int numParams)
{
    int entity = GetNativeCell(1);

    char sName[128];
    GetNativeString(2, sName, sizeof(sName));

    int length = GetNativeCell(4);

	if(!CEconItems_IsEntityCustomEconItem(entity)) return false;
	if(m_hEconItem[entity].m_Attributes == null) return false;

    char[] buffer = new char[length + 1];
	CEconItems_GetAttributeStringFromArray(m_hEconItem[entity].m_Attributes, sName, buffer, length);

    SetNativeString(3, buffer, length);
    return true;
}

//---------------------------------------------------------------------
// Native: CEconItems_GetEntityAttributeInteger
//---------------------------------------------------------------------
public any Native_GetEntityAttributeInteger(Handle plugin, int numParams)
{
    int entity = GetNativeCell(1);

    char sName[128];
    GetNativeString(2, sName, sizeof(sName));

	if(!CEconItems_IsEntityCustomEconItem(entity)) return 0;
	if(m_hEconItem[entity].m_Attributes == null) return 0;

	return CEconItems_GetAttributeIntegerFromArray(m_hEconItem[entity].m_Attributes, sName);
}

//---------------------------------------------------------------------
// Native: CEconItems_GetEntityAttributeFloat
//---------------------------------------------------------------------
public any Native_GetEntityAttributeFloat(Handle plugin, int numParams)
{
    int entity = GetNativeCell(1);

    char sName[128];
    GetNativeString(2, sName, sizeof(sName));

	if(!CEconItems_IsEntityCustomEconItem(entity)) return 0.0;
	if(m_hEconItem[entity].m_Attributes == null) return 0.0;

	return CEconItems_GetAttributeFloatFromArray(m_hEconItem[entity].m_Attributes, sName);
}

//---------------------------------------------------------------------
// Native: CEconItems_GetEntityAttributeBool
//---------------------------------------------------------------------
public any Native_GetEntityAttributeBool(Handle plugin, int numParams)
{
    int entity = GetNativeCell(1);

    char sName[128];
    GetNativeString(2, sName, sizeof(sName));

	if(!CEconItems_IsEntityCustomEconItem(entity)) return false;
	if(m_hEconItem[entity].m_Attributes == null) return false;

	return CEconItems_GetAttributeBoolFromArray(m_hEconItem[entity].m_Attributes, sName);
}

//---------------------------------------------------------------------
// Native: CEconItems_SetEntityAttributeString
//---------------------------------------------------------------------
public any Native_SetEntityAttributeString(Handle plugin, int numParams)
{
    int entity = GetNativeCell(1);
    if (m_hEconItem[entity].m_Attributes == null)return;

    char sName[128], sValue[128];
    GetNativeString(2, sName, sizeof(sName));
    GetNativeString(3, sValue, sizeof(sValue));

	// We may have multiple instances of this item in different
	// loadouts. Make sure to update them all.
	if(m_hEconItem[entity].m_iIndex > 0)
	{
		int iItemIndex = m_hEconItem[entity].m_iIndex;
		int iClient = m_hEconItem[entity].m_iClient;

		for (int i = 0; i < view_as<int>(CEconLoadoutClass); i++)
		{
			CEconLoadoutClass nClass = view_as<CEconLoadoutClass>(i);

			int iCount = CEconItems_GetClientLoadoutSize(iClient, nClass);
			for (int j = 0; j < iCount; j++)
			{
				CEItem xItem;
				if (CEconItems_GetClientItemFromLoadoutByIndex(iClient, nClass, j, xItem))
				{
					if(xItem.m_iIndex == iItemIndex)
					{
						CEconItems_SetAttributeStringInArray(xItem.m_Attributes, sName, sValue);
					}
				}
			}
		}
	}

	// In a local build of the economy, the users will not be able to update
	// any attributes on their items using HTTP requests to the website.
#if defined LOCAL_BUILD
	return;
#else
	bool bNetworked = GetNativeCell(4);

	if(bNetworked)
	{
		int iItemIndex = m_hEconItem[entity].m_iIndex;
		if(iItemIndex > 0)
		{
			AddAttributeUpdateBatch(iItemIndex, sName, sValue);
		}
	}
	
	return;
#endif
}

//---------------------------------------------------------------------
// Native: CEconItems_SetEntityAttributeInteger
//---------------------------------------------------------------------
public any Native_SetEntityAttributeInteger(Handle plugin, int numParams)
{
    int entity = GetNativeCell(1);

    char sName[128], sValue[128];
    GetNativeString(2, sName, sizeof(sName));

    int iValue = GetNativeCell(3);
    IntToString(iValue, sValue, sizeof(sValue));
    bool bNetworked = GetNativeCell(4);

    CEconItems_SetEntityAttributeString(entity, sName, sValue, bNetworked);

	return;
}

//---------------------------------------------------------------------
// Native: CEconItems_SetEntityAttributeFloat
//---------------------------------------------------------------------
public any Native_SetEntityAttributeFloat(Handle plugin, int numParams)
{
    int entity = GetNativeCell(1);

    char sName[128], sValue[128];
    GetNativeString(2, sName, sizeof(sName));

    float flValue = GetNativeCell(3);
    FloatToString(flValue, sValue, sizeof(sValue));
    bool bNetworked = GetNativeCell(4);

    CEconItems_SetEntityAttributeString(entity, sName, sValue, bNetworked);

	return;
}

//---------------------------------------------------------------------
// Native: CEconItems_SetEntityAttributeBool
//---------------------------------------------------------------------
public any Native_SetEntityAttributeBool(Handle plugin, int numParams)
{
    int entity = GetNativeCell(1);

    char sName[128], sValue[128];
    GetNativeString(2, sName, sizeof(sName));

    bool bValue = GetNativeCell(3);
    IntToString(bValue ? 1 : 0, sValue, sizeof(sValue));
    bool bNetworked = GetNativeCell(4);

    CEconItems_SetEntityAttributeString(entity, sName, sValue, bNetworked);

	return;
}

//---------------------------------------------------------------------
// Native: CEconItems_ApplyOriginalAttributes
//---------------------------------------------------------------------
public any Native_ApplyOriginalAttributes(Handle plugin, int numParams)
{
    int entity = GetNativeCell(1);

	if(!CEconItems_IsEntityCustomEconItem(entity)) return;
	if(m_hEconItem[entity].m_Attributes == null) return;

	// TODO: Make a check to see if entity accepts TF2 attributes.
	for(int i = 0; i < m_hEconItem[entity].m_Attributes.Length; i++)
	{
		CEAttribute hAttr;
		m_hEconItem[entity].m_Attributes.GetArray(i, hAttr);

		if(CEconItems_IsAttributeNameOriginal(hAttr.m_sName))
		{
			float flValue = StringToFloat(hAttr.m_sValue);
			TF2Attrib_SetByName(entity, hAttr.m_sName, flValue);
		}
	}
}

//---------------------------------------------------------------------
// Native: CEconItems_IsAttributeNameOriginal
//---------------------------------------------------------------------
public any Native_IsAttributeNameOriginal(Handle plugin, int numParams)
{
    char sName[64];
    GetNativeString(1, sName, sizeof(sName));
    return (TF2Econ_TranslateAttributeNameToDefinitionIndex(sName) != -1);
	//
	//Address pSchema = SDKCall(g_SDKCallGetEconItemSchema);
	//if(pSchema)
	//{
	//	return SDKCall(g_SDKCallSchemaGetAttributeDefinitionByName, pSchema, sName) != Address_Null;
	//}
	//return false;
}

// Loadout
//======================================//


// Entry point for loadout application. Requests user loadout if not yet cached.
public void LoadoutApplication(int client, bool bFullReapplication)
{
	// We do not apply loadouts on bots.
	if (!IsClientReady(client))return;

	// This user is currently already waiting for a loadout.
	if (m_bWaitingForLoadout[client])return;

	// If it's full reapplication.
	if(bFullReapplication)
	{
		// We unequip all the items from the player.
		RemoveAllClientWearableItems(client);
	} else {
		// If it's partial reapplication, we only unequip items of specific type.
		if(m_MyItems[client] != null)
		{
			for (int i = 0; i < m_PartialReapplicationTypes.Length; i++)
			{
				char sType[32];
				m_PartialReapplicationTypes.GetString(i, sType, sizeof(sType));
				RemoveClientWearableItemsByType(client, sType);
			}
		}
	}

	if (CEconItems_IsClientLoadoutCached(client))
	{
		// If cached loadout is still recent, we parse cached response.
		 ApplyClientLoadout(client);
	} else {
		// Otherwise request for the most recent data.
		CEconItems_RequestClientLoadoutUpdate(client, true);
	}
}

public CEconLoadoutClass GetCEconLoadoutClassFromTFClass(TFClassType class)
{
	switch(class)
	{
		case TFClass_Scout:return CEconLoadoutClass_Scout;
		case TFClass_Soldier:return CEconLoadoutClass_Soldier;
		case TFClass_Pyro:return CEconLoadoutClass_Pyro;
		case TFClass_DemoMan:return CEconLoadoutClass_Demoman;
		case TFClass_Heavy:return CEconLoadoutClass_Heavy;
		case TFClass_Engineer:return CEconLoadoutClass_Engineer;
		case TFClass_Medic:return CEconLoadoutClass_Medic;
		case TFClass_Sniper:return CEconLoadoutClass_Sniper;
		case TFClass_Spy:return CEconLoadoutClass_Spy;
	}
	return CEconLoadoutClass_Unknown;
}

//---------------------------------------------------------------------
// Native: CEconItems_IsItemFromClientClassLoadout
//---------------------------------------------------------------------
public any Native_IsItemFromClientClassLoadout(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	CEconLoadoutClass nClass = GetNativeCell(2);

	if (m_Loadout[client][nClass] == null)return false;

	CEItem xItem;
	GetNativeArray(3, xItem, sizeof(CEItem));

	for (int i = 0; i < m_Loadout[client][nClass].Length; i++)
	{
		CEItem hItem;
		m_Loadout[client][nClass].GetArray(i, hItem);

		if (hItem.m_Attributes == xItem.m_Attributes)return true;
	}

	return false;
}

//---------------------------------------------------------------------
// Native: CEconItems_IsClientWearingItem
//---------------------------------------------------------------------
public any Native_IsClientWearingItem(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	if (m_MyItems[client] == null)return false;

	CEItem xNeedle;
	GetNativeArray(2, xNeedle, sizeof(CEItem));

	for (int i = 0; i < m_MyItems[client].Length; i++)
	{
		CEItem hItem;
		m_MyItems[client].GetArray(i, hItem);

		if (hItem.m_Attributes == xNeedle.m_Attributes)return true;
	}

	return false;
}

//---------------------------------------------------------------------
// Native: CEconItems_GiveItemToClient
//---------------------------------------------------------------------
public any Native_GiveItemToClient(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	if (m_MyItems[client] == null)
	{
		m_MyItems[client] = new ArrayList(sizeof(CEItem));
	}

	CEItem xItem;
	GetNativeArray(2, xItem, sizeof(CEItem));

	xItem.m_iClient = client;
	m_MyItems[client].PushArray(xItem);

	GivePlayerCEItem(client, xItem);
}

//---------------------------------------------------------------------
// Native: CEconItems_RemoveItemFromClient
//---------------------------------------------------------------------
public any Native_RemoveItemFromClient(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	if (m_MyItems[client] == null)return;

	CEItem xNeedle;
	GetNativeArray(2, xNeedle, sizeof(CEItem));

	bool bRemoved = false;
	for (int i = 0; i < m_MyItems[client].Length; i++)
	{
		CEItem hItem;
		m_MyItems[client].GetArray(i, hItem);

		if(hItem.m_Attributes == xNeedle.m_Attributes)
		{
			m_MyItems[client].Erase(i);
			bRemoved = true;
			i--;
		}
	}

	if(bRemoved)
	{
		CEItemDefinition xDef;
		if(CEconItems_GetItemDefinitionByIndex(xNeedle.m_iItemDefinitionIndex, xDef))
		{
			// Call subplugins that we've unequipped this item.
			Call_StartForward(g_CEcon_OnUnequipItem);
			Call_PushCell(client);
			Call_PushArray(xNeedle, sizeof(CEItem));
			Call_PushString(xDef.m_sType);
			Call_Finish();

			// Call subplugins that we've unequipped this item.
			Call_StartForward(g_CEcon_OnItemIsUnequipped);
			Call_PushCell(client);
			Call_PushArray(xNeedle, sizeof(CEItem));
			Call_PushString(xDef.m_sType);
			Call_Finish();
		}

		// If removed, let's check if this item isn't in the player loadout.
		// It it is not, remove it, as it was not created by the econ.
		// This is to prevent memory leaks.

		if(!CEconItems_IsItemFromClientLoadout(client, xNeedle))
		{
			CEconItems_DestroyItem(xNeedle);
		}

	}
}

public void RemoveClientWearableItemsByType(int client, const char[] type)
{
	if (m_MyItems[client] == null)return;

	for (int i = 0; i < m_MyItems[client].Length; i++)
	{
		CEItem hItem;
		m_MyItems[client].GetArray(i, hItem);

		CEItemDefinition hDef;
		if(CEconItems_GetItemDefinitionByIndex(hItem.m_iItemDefinitionIndex, hDef))
		{
			if(StrEqual(hDef.m_sType, type))
			{
				CEconItems_RemoveItemFromClient(client, hItem);
				i--;
			}
		}
	}
}

public void RemoveAllClientWearableItems(int client)
{
	if (m_MyItems[client] == null)return;

	// I would just delete the m_MyItems, but we still need to notify other plugins about
	// all the items being holstered.

	for (int i = 0; i < m_MyItems[client].Length; i++)
	{
		CEItem hItem;
		m_MyItems[client].GetArray(i, hItem);

		CEconItems_RemoveItemFromClient(client, hItem);
		i--;
	}
}

//---------------------------------------------------------------------
// Native: CEconItems_IsClientLoadoutCached
//---------------------------------------------------------------------
public any Native_IsClientLoadoutCached(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);

	return m_bLoadoutCached[client];
}

public Action player_death(Event hEvent, const char[] szName, bool bDontBroadcast)
{
	int client = GetClientOfUserId(hEvent.GetInt("userid"));
	m_bInRespawn[client] = false;
}

public Action post_inventory_application(Event hEvent, const char[] szName, bool bDontBroadcast)
{
	int client = GetClientOfUserId(hEvent.GetInt("userid"));
	RequestFrame(RF_LoadoutApplication, client);
}

public Action player_spawn(Event hEvent, const char[] szName, bool bDontBroadcast)
{
	int client = GetClientOfUserId(hEvent.GetInt("userid"));

	m_bFullReapplication[client] = true;

	// Users are in respawn room by default when they spawn.
	// m_bInRespawn[client] = true;

}

public void RF_LoadoutApplication(int client)
{
	if(m_bFullReapplication[client])
	{
		LoadoutApplication(client, true);
	} else {
		LoadoutApplication(client, false);
	}

	m_bFullReapplication[client] = false;
}

//---------------------------------------------------------------------
// Native: CEconItems_RequestClientLoadoutUpdate
//---------------------------------------------------------------------
public any Native_RequestClientLoadoutUpdate(Handle plugin, int numParams)
{
	// If we decided not to use backend loadout, don't do anything.
	if (!ce_items_use_backend_loadout.BoolValue)return false;

	int client = GetNativeCell(1);
	if (m_bWaitingForLoadout[client])return false;

	bool apply = GetNativeCell(2);

	if (!IsClientReady(client))return false;

	m_bWaitingForLoadout[client] = true;

	DataPack pack = new DataPack();
	pack.WriteCell(client);
	pack.WriteCell(apply);
	pack.Reset();

	char sSteamID64[64];
	GetClientAuthId(client, AuthId_SteamID64, sSteamID64, sizeof(sSteamID64));

	HTTPRequestHandle httpRequest = CEconHTTP_CreateBaseHTTPRequest("/api/IEconomySDK/UserLoadout", HTTPMethod_GET);
	Steam_SetHTTPRequestGetOrPostParameter(httpRequest, "steamid", sSteamID64);

	Steam_SendHTTPRequest(httpRequest, RequestClientLoadout_Callback, pack);
	return true;
}

//---------------------------------------------------------------------
// Native: CEconItems_RequestClientLoadoutUpdate
//---------------------------------------------------------------------
public void RequestClientLoadout_Callback(HTTPRequestHandle request, bool success, HTTPStatusCode code, any pack)
{
	// Retrieving DataPack parameter.
	DataPack hPack = pack;

	// Getting client index and apply boolean from datapack.
	int client = hPack.ReadCell();
	bool apply = hPack.ReadCell();
	m_bWaitingForLoadout[client] = false;

	// Removing Datapack.
	delete hPack;

	// We are not processing bots.
	if (!IsClientReady(client))return;

	//-------------------------------//
	// Making HTTP checks.

	// If request was not succesful, return.
	if (!success)return;
	if (code != HTTPStatusCode_OK)return;

	// Getting response size.
	int size = Steam_GetHTTPResponseBodySize(request);
	char[] content = new char[size + 1];

	// Getting actual response content body.
	Steam_GetHTTPResponseBodyData(request, content, size);
	Steam_ReleaseHTTPRequest(request);

	KeyValues Response = new KeyValues("Response");

	//-------------------------------//
	// Parsing loadout response.

	// If we fail to import content return.
	if (!Response.ImportFromString(content))return;

	ClearClientLoadout(client, false);

	if(Response.JumpToKey("loadout"))
	{
		if(Response.GotoFirstSubKey())
		{
			do {
				char sClassName[32];
				Response.GetSectionName(sClassName, sizeof(sClassName));

				CEconLoadoutClass nClass;
				if(StrEqual(sClassName, "general")) nClass = CEconLoadoutClass_General;
				if(StrEqual(sClassName, "scout")) 	nClass = CEconLoadoutClass_Scout;
				if(StrEqual(sClassName, "soldier")) nClass = CEconLoadoutClass_Soldier;
				if(StrEqual(sClassName, "pyro")) 	nClass = CEconLoadoutClass_Pyro;
				if(StrEqual(sClassName, "demo")) 	nClass = CEconLoadoutClass_Demoman;
				if(StrEqual(sClassName, "heavy")) 	nClass = CEconLoadoutClass_Heavy;
				if(StrEqual(sClassName, "engineer"))nClass = CEconLoadoutClass_Engineer;
				if(StrEqual(sClassName, "medic")) 	nClass = CEconLoadoutClass_Medic;
				if(StrEqual(sClassName, "sniper")) 	nClass = CEconLoadoutClass_Sniper;
				if(StrEqual(sClassName, "spy")) 	nClass = CEconLoadoutClass_Spy;

				m_Loadout[client][nClass] = new ArrayList(sizeof(CEItem));

				if(Response.GotoFirstSubKey())
				{
					do {
						int iIndex = Response.GetNum("id", -1);
						int iDefID = Response.GetNum("defid", -1);
						int iQuality = Response.GetNum("quality", -1);

						ArrayList hOverrides;
						if(Response.JumpToKey("attributes"))
						{
							hOverrides = CEconItems_AttributesKeyValuesToArrayList(Response);
							Response.GoBack();
						}

						CEItem hItem;
						if(CEconItems_CreateItem(hItem, iDefID, iQuality, hOverrides))
						{
							hItem.m_iIndex = iIndex;
							hItem.m_iClient = client;
							m_Loadout[client][nClass].PushArray(hItem);
						}

						delete hOverrides;

					} while (Response.GotoNextKey());
					Response.GoBack();
				}
			} while (Response.GotoNextKey());
		}
	}

	m_bLoadoutCached[client] = true;

	delete Response;

	Call_StartForward(g_CEcon_OnClientLoadoutUpdated);
	Call_PushCell(client);
	Call_Finish();

	bool bIsRespawned = false;

	if(m_bInRespawn[client])
	{
		bool bShouldRespawn = false;
		if (m_nLoadoutUpdatedForClass[client] == TFClass_Unknown)bShouldRespawn = true;
		if (m_nLoadoutUpdatedForClass[client] == TF2_GetPlayerClass(client))bShouldRespawn = true;

		if(bShouldRespawn)
		{
			bIsRespawned = true;
			TF2_RespawnPlayer(client);
			m_nLoadoutUpdatedForClass[client] = view_as<TFClassType>(-1);
		}
	}

	if(!bIsRespawned && apply)
	{
		LoadoutApplication(client, true);
	}
}


public void ApplyClientLoadout(int client)
{
	CEconLoadoutClass nClass = GetCEconLoadoutClassFromTFClass(TF2_GetPlayerClass(client));

	if (nClass == CEconLoadoutClass_Unknown)return;
	if (m_Loadout[client][nClass] == null)return;

	// See if we need to holster something.
	if(m_MyItems[client] != null)
	{
		for (int i = 0; i < m_MyItems[client].Length; i++)
		{
			CEItem hItem;
			m_MyItems[client].GetArray(i, hItem);
			if(!CEconItems_IsItemFromClientClassLoadout(client, nClass, hItem))
			{
				CEconItems_RemoveItemFromClient(client, hItem);
				i--;
			}
		}
	}

	// See if we need to equip something.
	if(m_Loadout[client][nClass] != null)
	{
		for (int i = 0; i < m_Loadout[client][nClass].Length; i++)
		{
			CEItem hItem;
			m_Loadout[client][nClass].GetArray(i, hItem);

			if(!CEconItems_IsClientWearingItem(client, hItem))
			{
				CEconItems_GiveItemToClient(client, hItem);
			}
		}
	}
}

public void ClearClientLoadout(int client, bool full)
{
	CEconLoadoutClass nCurrentClass = CEconLoadoutClass_Unknown;

	if(IsClientValid(client))
	{
		nCurrentClass = GetCEconLoadoutClassFromTFClass(TF2_GetPlayerClass(client));
	}

	for (int i = 0; i < view_as<int>(CEconLoadoutClass); i++)
	{
		CEconLoadoutClass nClass = view_as<CEconLoadoutClass>(i);

		if (m_Loadout[client][nClass] == null)continue;

		// Don't remove items of the current class, as we still may need them.
		if(full || nClass != nCurrentClass)
		{
			for (int j = 0; j < m_Loadout[client][nClass].Length; j++)
			{
				CEItem hItem;
				m_Loadout[client][nClass].GetArray(j, hItem);

				CEconItems_DestroyItem(hItem);
			}
		}

		delete m_Loadout[client][nClass];
	}
	m_bLoadoutCached[client] = false;
}

//---------------------------------------------------------------------
// Native: CEconItems_GetClientLoadoutSize
//---------------------------------------------------------------------
public int Native_GetClientLoadoutSize(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	CEconLoadoutClass nClass = GetNativeCell(2);

	if (m_Loadout[client][nClass] == null)return -1;

	return m_Loadout[client][nClass].Length;
}

//---------------------------------------------------------------------
// Native: CEconItems_GetClientItemFromLoadoutByIndex
//---------------------------------------------------------------------
public any Native_GetClientItemFromLoadoutByIndex(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	CEconLoadoutClass nClass = GetNativeCell(2);
	if (m_Loadout[client][nClass] == null)return false;

	int index = GetNativeCell(3);

	if (index < 0)return false;
	if (index >= m_Loadout[client][nClass].Length)return false;


	CEItem xItem;
	m_Loadout[client][nClass].GetArray(index, xItem);

	SetNativeArray(4, xItem, sizeof(CEItem));

	return true;
}

//---------------------------------------------------------------------
// Native: CEconItems_GetClientWearedItemsCount
//---------------------------------------------------------------------
public int Native_GetClientWearedItemsCount(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);

	if (m_MyItems[client] == null)return -1;

	return m_MyItems[client].Length;
}

//---------------------------------------------------------------------
// Native: CEconItems_GetClientWearedItemByIndex
//---------------------------------------------------------------------
public any Native_GetClientWearedItemByIndex(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	if (m_MyItems[client] == null)return false;

	int index = GetNativeCell(2);

	if (index < 0)return false;
	if (index >= m_MyItems[client].Length)return false;

	CEItem xItem;
	m_MyItems[client].GetArray(index, xItem);

	SetNativeArray(3, xItem, sizeof(CEItem));

	return true;
}

//---------------------------------------------------------------------
// Native: CEconItems_IsItemFromClientLoadout
//---------------------------------------------------------------------
public any Native_IsItemFromClientLoadout(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	if (m_MyItems[client] == null)return false;

	CEItem xItem;
	GetNativeArray(2, xItem, sizeof(CEItem));

	for (int i = 0; i < view_as<int>(CEconLoadoutClass); i++)
	{
		CEconLoadoutClass nClass = view_as<CEconLoadoutClass>(i);

		if (CEconItems_IsItemFromClientClassLoadout(client, nClass, xItem))return true;
	}

	return false;
}

//---------------------------------------------------------------------
// Native: CEconItems_GetEntityItemStruct
//---------------------------------------------------------------------
public any Native_GetEntityItemStruct(Handle plugin, int numParams)
{
	int entity = GetNativeCell(1);

	if(CEconItems_IsEntityCustomEconItem(entity))
	{
		SetNativeArray(2, m_hEconItem[entity], sizeof(CEItem));
		return true;
	}

	return false;
}

//---------------------------------------------------------------------
// Native: CEconItems_SetCustomEntityStyle
//---------------------------------------------------------------------
public any Native_SetCustomEntityStyle(Handle plugin, int numParams)
{
	int entity = GetNativeCell(1);
	int style = GetNativeCell(2);

	if (!CEconItems_IsEntityCustomEconItem(entity))return;

	Call_StartForward(g_CEcon_OnCustomEntityStyleUpdated);
	Call_PushCell(m_hEconItem[entity].m_iClient);
	Call_PushCell(entity);
	Call_PushCell(style);
	Call_Finish();
}

public bool IsEntityValid(int entity)
{
	return entity > 0 && entity < MAX_ENTITY_LIMIT && IsValidEntity(entity);
}

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

public void OnMapStart()
{
	int iEntity = -1;
	while ((iEntity = FindEntityByClassname(iEntity, "func_respawnroom")) != -1)
	{
		SDKHook(iEntity, SDKHook_StartTouchPost, OnRespawnRoomStartTouch);
		SDKHook(iEntity, SDKHook_EndTouchPost, OnRespawnRoomEndTouch);
	}
}

// --------------------------------------------- //
// Purpose: On Entity Created
// --------------------------------------------- //
public void OnEntityCreated(int entity, const char[] class)
{
	ClearEntityData(entity);
	if (entity < 1)return;

	if (StrEqual(class, "func_respawnroom"))
	{
		SDKHook(entity, SDKHook_StartTouchPost, OnRespawnRoomStartTouch);
		SDKHook(entity, SDKHook_EndTouchPost, OnRespawnRoomEndTouch);
	}
}

// --------------------------------------------- //
// Purpose: On Entity Destroyed
// --------------------------------------------- //
public void OnEntityDestroyed(int entity)
{
	if(CEconItems_IsEntityCustomEconItem(entity))
	{
		CEItem xItem;
		if(CEconItems_GetEntityItemStruct(entity, xItem))
		{
			CEconItems_RemoveItemFromClient(xItem.m_iClient, xItem);
		}
	}

	ClearEntityData(entity);
}

public void ClearEntityData(int entity)
{
	if (!(0 < entity <= 2049))return;
	m_bIsEconItem[entity] = false;
}

public int FindTargetBySteamID64(const char[] steamid)
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && IsClientAuthorized(i))
		{
			char szAuth[256];
			GetClientAuthId(i, AuthId_SteamID64, szAuth, sizeof(szAuth));
			if (StrEqual(szAuth, steamid))return i;
		}
	}
	return -1;
}

public void OnRespawnRoomStartTouch(int iSpawnRoom, int iClient)
{
	if(IsClientValid(iClient))
	{
		m_bInRespawn[iClient] = true;
	}
}

public void OnRespawnRoomEndTouch(int iSpawnRoom, int iClient)
{
	if(IsClientValid(iClient))
	{
		m_bInRespawn[iClient] = false;
	}
}

public void OnClientDisconnect(int client)
{
	FlushClientData(client);
}

public void OnClientPostAdminCheck(int client)
{
	FlushClientData(client);
}

public void FlushClientData(int client)
{
	ClearClientLoadout(client, true);

	delete m_MyItems[client];
	m_bWaitingForLoadout[client] = false;
	m_bInRespawn[client] = false;
	m_bFullReapplication[client] = false;
}

enum struct CEAttributeUpdateBatch
{
	int m_iIndex;
	char m_sAttr[256];
	char m_sValue[256];
}

ArrayList m_AttributeUpdateBatches;

public void AddAttributeUpdateBatch(int index, const char[] name, const char[] value)
{
	if(m_AttributeUpdateBatches == null)
	{
		m_AttributeUpdateBatches = new ArrayList(sizeof(CEAttributeUpdateBatch));
	}

	for (int i = 0; i < m_AttributeUpdateBatches.Length; i++)
	{
		CEAttributeUpdateBatch xBatch;
		m_AttributeUpdateBatches.GetArray(i, xBatch);

		if (xBatch.m_iIndex != index)continue;

		if(StrEqual(xBatch.m_sAttr, name))
		{
			m_AttributeUpdateBatches.Erase(i);
			i--;
		}
	}

	CEAttributeUpdateBatch xBatch;
	xBatch.m_iIndex = index;
	strcopy(xBatch.m_sAttr, sizeof(xBatch.m_sAttr), name);
	strcopy(xBatch.m_sValue, sizeof(xBatch.m_sValue), value);
	m_AttributeUpdateBatches.PushArray(xBatch);
}

public Action Timer_AttributeUpdateInterval(Handle timer, any data)
{
	if (m_AttributeUpdateBatches == null)return;
	if (m_AttributeUpdateBatches.Length == 0)return;

	HTTPRequestHandle hRequest = CEconHTTP_CreateBaseHTTPRequest("/api/IEconomySDK/ItemAttributes", HTTPMethod_POST);

	for (int i = 0; i < m_AttributeUpdateBatches.Length; i++)
	{
		CEAttributeUpdateBatch xBatch;
		m_AttributeUpdateBatches.GetArray(i, xBatch);

		char sKey[128];
		Format(sKey, sizeof(sKey), "items[%d][%s]", xBatch.m_iIndex, xBatch.m_sAttr);

		Steam_SetHTTPRequestGetOrPostParameter(hRequest, sKey, xBatch.m_sValue);
	}

	Steam_SendHTTPRequest(hRequest, AttributeUpdate_Callback);
	delete m_AttributeUpdateBatches;
}

public void AttributeUpdate_Callback(HTTPRequestHandle request, bool success, HTTPStatusCode code)
{
	// If request was not succesful, return.
	if (!success)return;
	if (code != HTTPStatusCode_OK)return;

	// Cool, we've updated everything.
}

public Action TF2_OnReplaceItem(int client, int item)
{
	// Get our current class.
	TFClassType m_hClientClass = TF2_GetPlayerClass(client);
	CEconLoadoutClass m_hLoadoutClass = GetCEconLoadoutClassFromTFClass(m_hClientClass);
	
	// Is this item we're currently looking at a Creators.TF item?
	if (CEconItems_IsEntityCustomEconItem(item))
	{
		// Grab this item in the form of a CEItem.
		CEItem xItem;
		CEconItems_GetEntityItemStruct(item, xItem);
		
		// Is this item currently in our loadout?
		if (CEconItems_IsItemFromClientClassLoadout(client, m_hLoadoutClass, xItem))
		{
			// Don't replace it.
			return Plugin_Handled;
		}
	}
	
	// We couldn't find this item in our loadout anymore, replace it.
	return Plugin_Continue;
}
