//============= Copyright Amper Software, All rights reserved. ============//
//
// Purpose: Main plugin that stores custom items information, and coordinates
// the subplugin to handle them.
//
//=========================================================================//

enum struct CEItem
{
	int m_iIndex;
	int m_iItemDefinitionIndex;
	int m_nQuality;
	int m_iClient;

	ArrayList m_Attributes;
}

enum struct CEItemDefinition
{
	int m_iIndex;
	char m_sName[128];
	char m_sType[32];

	ArrayList m_Attributes;
}

enum struct CEAttribute
{
	char m_sName[128];
	char m_sValue[256];
}

enum CEconLoadoutClass
{
	CEconLoadoutClass_Unknown,

	CEconLoadoutClass_General,
	CEconLoadoutClass_Scout,
	CEconLoadoutClass_Soldier,
	CEconLoadoutClass_Pyro,
	CEconLoadoutClass_Demoman,
	CEconLoadoutClass_Heavy,
	CEconLoadoutClass_Engineer,
	CEconLoadoutClass_Medic,
	CEconLoadoutClass_Sniper,
	CEconLoadoutClass_Spy
}

//========================================//
// NATIVES
//========================================//

//-----------------------------//
// Items

// Creates an CEItem instance by the definition name and puts it in the buffer.
native bool CEconItems_CreateNamedItem(any buffer[sizeof(CEItem)], const char[] name, int quality, ArrayList overrides);
// Creates a CEItem struct with provided value and returns it in buffer.
native bool	CEconItems_CreateItem(any buffer[sizeof(CEItem)], int defid, int quality, ArrayList override);
// Destroys the CEItem struct. This function is required to call if item struct is no longer needed to close connected handles.
native void	CEconItems_DestroyItem(any item[sizeof(CEItem)]);

// True if a specific world entity is custom econ item.
native bool CEconItems_IsEntityCustomEconItem(int entity);
// Stores entity CEItem struct in the buffer.
native bool CEconItems_GetEntityItemStruct(int entity, any buffer[sizeof(CEItem)]);

native bool CEconItems_GetItemDefinitionByIndex(int defid, any buffer[sizeof(CEItemDefinition)]);
native bool CEconItems_GetItemDefinitionByName(const char[] name, any buffer[sizeof(CEItemDefinition)]);

//-----------------------------//
// Attributes

// Returns true is a specific attribute name exists in the base game.
native bool CEconItems_IsAttributeNameOriginal(const char[] name);

// Merges two attribute ArrayLists together. Attributes with same name from array1 will
// be overwritten by value in array2.
native ArrayList CEconItems_MergeAttributes(ArrayList array1, ArrayList array2);
// Transforms KeyValues object into ArrayList of CEAttribute.
native ArrayList CEconItems_AttributesKeyValuesToArrayList(KeyValues attributes);

// Returns string type attribute value from ArrayList.
native bool CEconItems_GetAttributeStringFromArray(ArrayList attributes, const char[] name, char[] buffer, int length);
// Returns integer type attribute value from ArrayList.
native int CEconItems_GetAttributeIntegerFromArray(ArrayList attributes, const char[] name);
// Returns float type attribute value from ArrayList.
native float CEconItems_GetAttributeFloatFromArray(ArrayList attributes, const char[] name);
// Returns bool type attribute value from ArrayList.
native bool CEconItems_GetAttributeBoolFromArray(ArrayList attributes, const char[] name);

// Sets string type attribute value in ArrayList.
native void CEconItems_SetAttributeStringInArray(ArrayList attributes, const char[] name, const char[] value);
// Sets integer type attribute value in ArrayList.
native void CEconItems_SetAttributeIntegerInArray(ArrayList attributes, const char[] name, int value);
// Sets float type attribute value in ArrayList.
native void CEconItems_SetAttributeFloatInArray(ArrayList attributes, const char[] name, float value);
// Sets bool type attribute value in ArrayList.
native void CEconItems_SetAttributeBoolInArray(ArrayList attributes, const char[] name, bool value);

// Returns string type attribute value of custom econ entity.
native bool CEconItems_GetEntityAttributeString(int entity, const char[] name, char[] buffer, int length);
// Returns integer type attribute value of custom econ entity.
native int CEconItems_GetEntityAttributeInteger(int entity, const char[] name);
// Returns float type attribute value of custom econ entity.
native float CEconItems_GetEntityAttributeFloat(int entity, const char[] name);
// Returns bool type attribute value of custom econ entity.
native bool CEconItems_GetEntityAttributeBool(int entity, const char[] name);

// Sets string type attribute value of custom econ entity.
native void CEconItems_SetEntityAttributeString(int entity, const char[] name, const char[] value, bool networked = false);
// Sets integer type attribute value of custom econ entity.
native void CEconItems_SetEntityAttributeInteger(int entity, const char[] name, int value, bool networked);
// Sets float type attribute value of custom econ entity.
native void CEconItems_SetEntityAttributeFloat(int entity, const char[] name, float value, bool networked = false);
// Sets bool type attribute value of custom econ entity.
native void CEconItems_SetEntityAttributeBool(int entity, const char[] name, bool value, bool networked = false);

// Applies all base game attributes using TF2Attributes plugin.
native void CEconItems_ApplyOriginalAttributes(int entity);

//-----------------------------//
// Loadout

// Returns true if client is wearing an item.
native bool CEconItems_IsClientWearingItem(int client, any item[sizeof(CEItem)]);
// Returns true if player has item index in their class loadout.
native bool CEconItems_IsItemFromClientClassLoadout(int client, CEconLoadoutClass class, any item[sizeof(CEItem)]);
native bool CEconItems_IsItemFromClientLoadout(int client, any item[sizeof(CEItem)]);

// Calls client's loadout update.
native bool CEconItems_RequestClientLoadoutUpdate(int client, bool apply);
// Returns true if client's loadout is already loaded.
native bool CEconItems_IsClientLoadoutCached(int client);

// Gives this item to player.
native bool	CEconItems_GiveItemToClient(int client, any item[sizeof(CEItem)]);
// Removes an item from player.
native bool	CEconItems_RemoveItemFromClient(int client, any item[sizeof(CEItem)]);

// Returns the amount of items that user has in their class loadout. -1 if loadout is not yet loaded.
native int CEconItems_GetClientLoadoutSize(int client, CEconLoadoutClass class);
// Stores the nth item from the class loadout in the buffer, where n is index. Returns false if item does not exist.
native bool CEconItems_GetClientItemFromLoadoutByIndex(int client, CEconLoadoutClass class, int index, any buffer[sizeof(CEItem)]);

// Returns the amount of items client is wearing right now.
native int CEconItems_GetClientWearedItemsCount(int client);
// Stores the nth item that client is wearing right now in the buffer, where n is index. Returns false if item does not exist.
native bool CEconItems_GetClientWearedItemByIndex(int client, int index, any buffer[sizeof(CEItem)]);
// Sets the style index of the entity.
native int CEconItems_SetCustomEntityStyle(int entity, int style);

//========================================//
// FORWARDS
//========================================//


// Called to define whether this item should be blocked from equipping.
forward bool CEconItems_ShouldItemBeBlocked(int client, CEItem item, const char[] type);
// Called when subplugins need to initialize the code for item types.
forward int CEconItems_OnEquipItem(int client, CEItem item, const char[] type);
// Called after this item has been equipped.
forward void CEconItems_OnItemIsEquipped(int client, int entity, CEItem item, const char[] type);

// Called when subplugins need to initialize the code for item types.
forward int CEconItems_OnUnequipItem(int client, CEItem item, const char[] type);
// Called after this item has been unequipped.
forward void CEconItems_OnItemIsUnequipped(int client, CEItem item, const char[] type);

// Called when user's loadout was updated.
forward void CEconItems_OnClientLoadoutUpdated(int client);
// Called when style index of the entity has been updated.
forward void CEconItems_OnCustomEntityStyleUpdated(int client, int entity, int style);

public SharedPlugin __pl_cecon_items =
{
    name = "cecon_items",
    file = "cecon_items.smx",
#if defined REQUIRE_PLUGIN
    required = 1,
#else
    required = 0,
#endif
};
