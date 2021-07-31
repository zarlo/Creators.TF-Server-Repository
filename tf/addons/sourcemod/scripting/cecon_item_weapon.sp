 //============= Copyright Amper Software 2021, All rights reserved. ============//
//
// Purpose: Handler for the Weapon custom item type.
//
//=========================================================================//

#include <tf2items>

#pragma semicolon 1
#pragma tabsize 0
#pragma newdecls required

#include <cecon>
#include <cecon_items>

#include <tf2attributes>
#include <tf2wearables>
#include <tf2>
#include <tf2_stocks>
#include <tf_econ_data>
#include <sdkhooks>

public Plugin myinfo =
{
	name = "Creators.TF (Weapon)",
	author = "Creators.TF Team",
	description = "Handler for the Weapon custom item type.",
	version = "1.0",
	url = "https://creators.tf"
};

#define MAX_STYLES 16

enum struct CEItemDefinitionWeapon
{
	int m_iIndex;

    char m_sClassName[64];
	int m_iBaseIndex;

    int m_iClip;
    int m_iAmmo;

	char m_sWorldModel[256];
	bool m_bPreserveAttributes;

	int m_iStylesCount;
	int m_iStyles[MAX_STYLES];
	char m_sLogName[PLATFORM_MAX_PATH];
}

enum struct CEItemDefinitionWeaponStyle
{
	int m_iIndex;
	char m_sWorldModel[256];
}

ArrayList m_hDefinitions;
ArrayList m_hStyles;

char m_sWeaponModel[2049][256];
int m_hLastWeapon[MAXPLAYERS + 1];

Handle 	g_hSdkGetMaxAmmo,
		g_hSdkGetMaxClip;

bool m_bLogicMedievalExists;
int m_hLogicMedievalEntity;

public void OnPluginStart()
{
	HookEvent("player_death", player_death);
	HookEvent("player_death", player_death_PRE, EventHookMode_Pre);

	Handle hGameConf = LoadGameConfigFile("tf2.weapons");
	if (hGameConf != null)
	{
		// This call calculates the max ammo of a given weapon of a slot
		StartPrepSDKCall(SDKCall_Player);
		PrepSDKCall_SetFromConf(hGameConf, SDKConf_Signature, "CTFPlayer::GetMaxAmmo");
		PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
		PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
		PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
		g_hSdkGetMaxAmmo = EndPrepSDKCall();

		StartPrepSDKCall(SDKCall_Entity);
		PrepSDKCall_SetFromConf(hGameConf, SDKConf_Virtual, "CTFWeaponBase::GetMaxClip1");
		PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
		g_hSdkGetMaxClip = EndPrepSDKCall();

		CloseHandle(hGameConf);
	}
}

public Action player_death(Event hEvent, const char[] szName, bool bDontBroadcast)
{
	int client = GetClientOfUserId(hEvent.GetInt("userid"));
	for (int i = 0; i < 5; i++)
	{
		int iWeapon = GetPlayerWeaponSlot(client, i);
		if (!IsValidEntity(iWeapon))continue;

		TF2Wear_RemoveAllTiedWearables(iWeapon);
	}
}

public Action player_death_PRE(Event hEvent, const char[] szName, bool bDontBroadcast)
{
	int client = GetClientOfUserId(hEvent.GetInt("attacker"));

	int iWeapon = CEcon_GetLastUsedWeapon(client);
	if(IsValidEntity(iWeapon))
	{
		if(CEconItems_IsEntityCustomEconItem(iWeapon))
		{
			CEItem xItem;
			if(CEconItems_GetEntityItemStruct(iWeapon, xItem))
			{
				CEItemDefinitionWeapon xWeapon;
				if(FindWeaponDefinitionByIndex(xItem.m_iItemDefinitionIndex, xWeapon))
				{
					hEvent.SetString("weapon_logclassname", xWeapon.m_sLogName);
					return Plugin_Changed;
				}
			}
		}
	}

	return Plugin_Continue;
}

//--------------------------------------------------------------------
// Purpose: Precaches all the items of a specific type on plugin
// startup.
//--------------------------------------------------------------------
public void OnAllPluginsLoaded()
{
	ProcessEconSchema(CEcon_GetEconomySchema());

	// Hook all players that are already in game.
	LateSDKHooks();
}

//--------------------------------------------------------------------
// Purpose: Fired when an entity is created. Used to SDK hook
// specific entities.
//--------------------------------------------------------------------
public void OnEntityCreated(int entity, const char[] classname)
{
	if (entity < 1)return;
	strcopy(m_sWeaponModel[entity], PLATFORM_MAX_PATH, "");

	// This check is here so we can delete custom econ weapons on the floor.
	if (StrEqual(classname, "tf_dropped_weapon"))
	{
		// Hook dropped weapon and remove them immediately.
		SDKHook(entity, SDKHook_SpawnPost, OnWeaponDropped);
	}
	
	// If we have a tf_logic_medieval entity, we're in medieval mode, so
	// we should block some weapons. This is a backup check if m_bPlayingMedieval
	// isnt set for some reason.
	if (StrEqual(classname, "tf_logic_medieval"))
	{
		m_hLogicMedievalEntity = entity;
		m_bLogicMedievalExists = true;
	}
}

//--------------------------------------------------------------------
// Purpose: This is fired when an entity is destroyed. We use this to
// check if a tf_logic_medieval entity no longer exists in the server.
// This will allow players to use non-medieval override weapons again.
//--------------------------------------------------------------------
public void OnEntityDestroyed(int entity)
{
	if (entity == m_hLogicMedievalEntity)
	{
		m_hLogicMedievalEntity = -1;
		m_bLogicMedievalExists = false;
	}
}

public void OnClientPutInServer(int client)
{
	SDKHook(client, SDKHook_WeaponSwitchPost, OnWeaponSwitch);
}

//--------------------------------------------------------------------
// Purpose: Used to hook entities if this plugin was late loaded.
//--------------------------------------------------------------------
public void LateSDKHooks()
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if(IsClientValid(i))
		{
			SDKHook(i, SDKHook_WeaponSwitchPost, OnWeaponSwitch);
		}
	}
}

//--------------------------------------------------------------------
// Purpose: If schema was late updated (by an update), reprecache
// everything again.
//--------------------------------------------------------------------
public void CEcon_OnSchemaUpdated(KeyValues hSchema)
{
	ProcessEconSchema(hSchema);
}

//--------------------------------------------------------------------
// Purpose: This is called upon item equipping process.
//--------------------------------------------------------------------
public int CEconItems_OnEquipItem(int client, CEItem item, const char[] type)
{
	if (!StrEqual(type, "weapon"))return -1;

	CEItemDefinitionWeapon hDef;
	if (FindWeaponDefinitionByIndex(item.m_iItemDefinitionIndex, hDef))
	{
		if(StrEqual(hDef.m_sClassName, "tf_wearable"))
		{
			int iWear = TF2Wear_CreateWearable(client, false, hDef.m_sWorldModel);
			return iWear;
		} else {
			int iWeapon = CreateWeapon(client, hDef.m_iBaseIndex, hDef.m_sClassName, item.m_nQuality, hDef.m_bPreserveAttributes);
			if (iWeapon > -1)
			{
				int iBaseDefID = GetEntProp(iWeapon, Prop_Send, "m_iItemDefinitionIndex");
				int item_slot = TF2Econ_GetItemSlot(iBaseDefID, TF2_GetPlayerClass(client));

				//--------------------------------------------------------------------------//
				// Some weapons	have their slot index mismatched with the real value.
				// Here are some weapons that have a different slot index.

				// Hardcode revolvers to 0th slot.
				if(StrEqual(hDef.m_sClassName, "tf_weapon_revolver"))
				{
					item_slot = 0;
				}
				// Hardcode the sappers to 1th slot.
				if(StrEqual(hDef.m_sClassName, "tf_weapon_sapper"))
				{
					SetEntProp(iWeapon, Prop_Send, "m_iObjectType", 3, 4, 0);
					SetEntProp(iWeapon, Prop_Data, "m_iSubType", 3, 4, 0);
					item_slot = 1;
				}
				// Hardcode the PDAs to 3th slot.
				if(StrEqual(hDef.m_sClassName, "tf_weapon_pda_engineer_build"))
				{
					item_slot = 3;
				}
				// Hardcode the PDAs to 3th slot.
				if(StrEqual(hDef.m_sClassName, "tf_weapon_pda_engineer_destroy"))
				{
					item_slot = 3;
				}

				// Removing all wearables that take up the same slot as this weapon.
				// Some weapons are also considered to be wearables. For example Manntreads.
				// We need to get rid of them too.
				int next = GetEntPropEnt(client, Prop_Data, "m_hMoveChild");
				while (next != -1)
				{
					int iEdict = next;
					next = GetEntPropEnt(iEdict, Prop_Data, "m_hMovePeer");
					char classname[32];
					GetEntityClassname(iEdict, classname, 32);

					// We need to also include the demoshield entity here as well since that is also considered a weapon.
					// The previous version of this check only checked to see if the classname string length matched with
					// "tf_wearable". We can do that better with a StrContains check.

					// EDIT 23/04/21 8:09am - So you wanna know something really funny? This also applies to other weapons like
					// the Razorback and the Contracker! Thanks TF2 Team! - ZoNiCaL.

					// is there any reason to not do a non case sensitive check with "wearable"?
					// (StrContains(classname, "wearable", false) == -1)
					if (StrContains(classname, "tf_wearable") == -1)
					{
						continue;
					}

					/* i don't think we need to check the netclass? like at all?
					char sClass[32];
					GetEntityNetClass(iEdict, sClass, sizeof(sClass));

					// Make sure we include all types of wearables. With the same check above, we need to also include the
					// other wearable weapon entites because it doesn't have CTFWearable in it's classname.

					if (StrContains(sClass, "CTFWearable") == -1)
					{
					    continue;
					}
					*/
					int iDefIndex = GetEntProp(iEdict, Prop_Send, "m_iItemDefinitionIndex");
					if (iDefIndex == 0xFFFF)
					{
						continue;
					}

					int iSlot = TF2Econ_GetItemSlot(iDefIndex, TF2_GetPlayerClass(client));
					if (iSlot == item_slot)
					{
						TF2Wear_RemoveWearable(client, iEdict);
						AcceptEntityInput(iEdict, "Kill");
					}
				}

				strcopy(m_sWeaponModel[iWeapon], sizeof(m_sWeaponModel[]), hDef.m_sWorldModel);
				ParseCosmeticModel(client, m_sWeaponModel[iWeapon], sizeof(m_sWeaponModel[]));

				// Making weapon visible.
				SetEntProp(iWeapon, Prop_Send, "m_bValidatedAttachedEntity", 1);

				TF2_RemoveWeaponSlot(client, item_slot);
				EquipPlayerWeapon(client, iWeapon);

				DataPack DrawPack = new DataPack();
				DrawPack.WriteCell(client);
				DrawPack.WriteCell(iWeapon);
				DrawPack.Reset();
				RequestFrame(RF_OnDrawWeapon, DrawPack);

				DataPack RegenPack = new DataPack();
				RegenPack.WriteCell(client);
				RegenPack.WriteCell(iWeapon);
				RegenPack.Reset();
				RequestFrame(RF_RegenerateWeapon, RegenPack);

				return iWeapon;
			}
		}
	}
	return -1;
}

public void RF_OnDrawWeapon(any data)
{
	DataPack pack = data;
	int client = pack.ReadCell();
	int weapon = pack.ReadCell();
	delete pack;

	OnDrawWeapon(client, weapon);
}

public void RF_RegenerateWeapon(any data)
{
	DataPack pack = data;
	int client = pack.ReadCell();
	int weapon = pack.ReadCell();
	delete pack;

	TF2_RegenerateWeaponAmmo(client, weapon);
}

//--------------------------------------------------------------------
// Purpose: Finds a weapon's definition by the definition index.
// Returns true if found, false otherwise.
//--------------------------------------------------------------------
public bool FindWeaponDefinitionByIndex(int defid, CEItemDefinitionWeapon output)
{
	if (m_hDefinitions == null)return false;

	for (int i = 0; i < m_hDefinitions.Length; i++)
	{
		CEItemDefinitionWeapon hDef;
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
	m_hDefinitions = new ArrayList(sizeof(CEItemDefinitionWeapon));
	m_hStyles = new ArrayList(sizeof(CEItemDefinitionWeaponStyle));

	if (kv == null)return;

	// Our items are stored in a KeyValues object called "Items"
	if (kv.JumpToKey("Items"))
	{
		// Jump to our first item.
		if (kv.GotoFirstSubKey())
		{
			// Iterate through ALL of our items in the economy schema.
			do {
				// We only care about items with type "weapon". We can safely
				// ignore anything else.
				char sType[16];
				kv.GetString("type", sType, sizeof(sType));
				if (!StrEqual(sType, "weapon"))continue;

				char sIndex[11];
				kv.GetSectionName(sIndex, sizeof(sIndex));
				
				// Create a CEItemDefinitionWeapon struct. We'll push this into
				// an ArrayList of weapon definitions so we can access them
				// if we want to at a later point.
				CEItemDefinitionWeapon hDef;
				hDef.m_iIndex = StringToInt(sIndex);
				hDef.m_iBaseIndex = kv.GetNum("item_index", -1);

				// Access clip size and ammo.
				hDef.m_iClip = kv.GetNum("weapon_clip");
				hDef.m_iAmmo = kv.GetNum("weapon_ammo");

				// Preserve Attributes value. This should be returned as a bool.
				hDef.m_bPreserveAttributes = kv.GetNum("preserve_attributes", 0) == 1;

				// World model. Typically a c_model.
				kv.GetString("world_model", hDef.m_sWorldModel, sizeof(hDef.m_sWorldModel));
				
				// The base item class that this item will use when we create it for the player.
				kv.GetString("item_class", hDef.m_sClassName, sizeof(hDef.m_sClassName));
				
				// The log name that's used for the
				kv.GetString("item_logname", hDef.m_sLogName, sizeof(hDef.m_sLogName));

				// Parse all of our weapon styles. If a weapon has a different style depending
				// on what comes in through the players loadout, we can easily grab it in the
				// future.
				if(kv.JumpToKey("visuals/styles", false))
				{
					// Jump to the first style in the list.
					if(kv.GotoFirstSubKey())
					{
						// Loop through all of the styles.
						do {
							int iWorldStyleIndex = m_hStyles.Length;
							int iLocalStyleIndex = hDef.m_iStylesCount;

							kv.GetSectionName(sIndex, sizeof(sIndex));
							
							// Create a CEItemDefinitionWeaponStyle struct. We'll be storing this
							// later in our weapon definition struct.
							CEItemDefinitionWeaponStyle xStyle;
							
							// We grab styles by ID.
							xStyle.m_iIndex = StringToInt(sIndex);
							
							// Grab the world model override.
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
// Purpose: Creates a TF2 weapon, using TF2Items extension.
//--------------------------------------------------------------------
public int CreateWeapon(int client, int index, const char[] classname, int quality, bool preserve)
{
	int nFlags = OVERRIDE_ALL | FORCE_GENERATION;
	if (preserve)nFlags |= PRESERVE_ATTRIBUTES;

	Handle hWeapon = TF2Items_CreateItem(nFlags);

	// Weapon classname.
	char class[128];
	strcopy(class, sizeof(class), classname);

	// If for some reason this client is not a recognised class, don't
	// bother creating a weapon for them.
	if (TF2_GetPlayerClass(client) == TFClass_Unknown)return -1;

	// This section deals with giving a player the same type of "base weapon"
	// for each class. In Live TF2, some items have multiple copies with different
	// classnames. An example of this is the Shotgun: (tf_weapon_shotgun_soldier,
	// tf_weapon_shotgun_primary, tf_weapon_shotgun_pyro, tf_weapon_shotgun_hwg).
	// In our economy schema, we can only have one base classname to select our
	// items with. This can be circumnavigated by using special classnames.
	
	// If a multi-class weapon needs to be given and it needs to use a different
	// base item, make sure it's specified here.
	if(StrEqual(class, "tf_weapon_saxxy"))			// Catch-all Melee item.
	{
		switch (TF2_GetPlayerClass(client))
		{
			case TFClass_Scout: Format(class, sizeof(class), "tf_weapon_bat");
			case TFClass_Sniper: Format(class, sizeof(class), "tf_weapon_club");
			case TFClass_Soldier: Format(class, sizeof(class), "tf_weapon_shovel");
			case TFClass_DemoMan: Format(class, sizeof(class), "tf_weapon_bottle");
			case TFClass_Medic: Format(class, sizeof(class), "tf_weapon_bonesaw");
			case TFClass_Spy: Format(class, sizeof(class), "tf_weapon_knife");
			case TFClass_Engineer: Format(class, sizeof(class), "tf_weapon_wrench");
			case TFClass_Pyro: Format(class, sizeof(class), "tf_weapon_fireaxe");
			case TFClass_Heavy: Format(class, sizeof(class), "tf_weapon_fireaxe");
		}
	} else if(StrEqual(class, "tf_weapon_shotgun"))	// Catch-all shotgun.
	{
		switch (TF2_GetPlayerClass(client))
		{
			case TFClass_Soldier: Format(class, sizeof(class), "tf_weapon_shotgun_soldier");
			case TFClass_Engineer: Format(class, sizeof(class), "tf_weapon_shotgun_primary");
			case TFClass_Pyro: Format(class, sizeof(class), "tf_weapon_shotgun_pyro");
			case TFClass_Heavy: Format(class, sizeof(class), "tf_weapon_shotgun_hwg");
		}
	} else if(StrEqual(class, "tf_weapon_pistol"))	// Catch-all pistol.
	{
		switch (TF2_GetPlayerClass(client))
		{
			case TFClass_Scout: Format(class, sizeof(class), "tf_weapon_pistol_scout");
			case TFClass_Engineer: Format(class, sizeof(class), "tf_weapon_pistol");
		}
	} else if(StrEqual(class, "tf_weapon_throwable")) // Catch-all throwable item.
	{
		switch (TF2_GetPlayerClass(client))
		{
			case TFClass_Scout:
			{
				Format(class, sizeof(class), "tf_weapon_jar_milk");
				if (index == -1)index = 222;
			}
			case TFClass_Soldier:
			{
				Format(class, sizeof(class), "tf_weapon_shovel");
				if (index == -1)index = 196;
			}
			case TFClass_Pyro:
			{
				Format(class, sizeof(class), "tf_weapon_jar_gas");
				if (index == -1)index = 1180;
			}
			case TFClass_DemoMan:
			{
				Format(class, sizeof(class), "tf_weapon_bottle");
				if (index == -1)index = 191;
			}
			case TFClass_Heavy:
			{
				Format(class, sizeof(class), "tf_weapon_fists");
				if (index == -1)index = 195;
			}
			case TFClass_Engineer:
			{
				Format(class, sizeof(class), "tf_weapon_wrench");
				if (index == -1)index = 197;
			}
			case TFClass_Medic:
			{
				Format(class, sizeof(class), "tf_weapon_bonesaw");
				if (index == -1)index = 198;
			}
			case TFClass_Sniper:
			{
				Format(class, sizeof(class), "tf_weapon_jar");
				if (index == -1)index = 58;
			}
			case TFClass_Spy:
			{
				Format(class, sizeof(class), "tf_weapon_knife");
				if (index == -1)index = 194;
			}
		}
	}

	// Construct the final parts of our entity:
	// Classname, Item Def Index, and Quality.
	TF2Items_SetClassname(hWeapon, class);
	TF2Items_SetItemIndex(hWeapon, index);
	TF2Items_SetQuality(hWeapon, quality);

	// Create our weapon entity.
	int iWep = TF2Items_GiveNamedItem(client, hWeapon);
	delete hWeapon;

	// Set our weapon level to -1. We don't use this for Creators items.
	SetEntProp(iWep, Prop_Send, "m_iEntityLevel", -1);
	return iWep;
}

//--------------------------------------------------------------------
// Purpose: Returns true if weapon's view model is supposed
// to be visible. We don't draw viewmodels for bots as we
// don't see from their POV.
//--------------------------------------------------------------------
public bool ShouldDrawWeaponViewModel(int client, int weapon)
{
	if(IsFakeClient(client))return false;
	if (!ShouldDrawWeaponModel(client, weapon))return false;
	return true;
}

//--------------------------------------------------------------------
// Purpose: Returns true if weapon is supposed to be visible.
// This weapon will render if it's active, a Creators.TF economy item,
// and if it has a valid weapon model.
//--------------------------------------------------------------------
public bool ShouldDrawWeaponModel(int client, int weapon)
{
	if (GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon") != weapon)return false;
	if (!CEconItems_IsEntityCustomEconItem(weapon))return false;
	if (StrEqual(m_sWeaponModel[weapon], ""))return false;
	return true;
}

//--------------------------------------------------------------------
// Purpose: This function handles weapons custom models appearance.
//--------------------------------------------------------------------
public void OnDrawWeapon(int client, int iWeapon)
{
	// Make sure to remove all tied wearables before we do anything else.
	TF2Wear_RemoveAllTiedWearables(iWeapon);

	// Draw models only if we're supposed to be drawing them in the first place.
	if(ShouldDrawWeaponModel(client, iWeapon))
	{
		// If client is a bot, we're not going to deal with wearables.
		// Instead, we'll just change the model of the weapon. However, this
		// breaks animations in first person, so we don't do this with real players.
		if(IsFakeClient(client))
		{
			for (int i = 0; i < 4; i++)
			{
				SetEntProp(iWeapon, Prop_Send, "m_nModelIndexOverrides", PrecacheModel(m_sWeaponModel[iWeapon]), _, i);
			}
		} else {

			SetEntityRenderMode(iWeapon, RENDER_TRANSALPHA);
			SetEntityRenderColor(iWeapon, 0, 0, 0, 0);

			bool bShouldDrawHands = false;

			// These are the only weapons that for some reason break when this is set to 1.
			// I guess we can go with the old way of doing things and just
			// create the hand as the wearable. This will bring back the random red lights issue.
			char sClassName[32];
			GetEntityClassname(iWeapon, sClassName, sizeof(sClassName));

			// The flamethrower, minigun, and medigun.
			if(	StrEqual(sClassName, "tf_weapon_flamethrower") ||
				StrEqual(sClassName, "tf_weapon_minigun") ||
				StrEqual(sClassName, "tf_weapon_medigun")
			) {
				bShouldDrawHands = true;
			} else {
				SetEntProp(iWeapon, Prop_Send, "m_bBeingRepurposedForTaunt", 1);
			}


			int iWM = TF2Wear_CreateWeaponTiedWearable(iWeapon, false, m_sWeaponModel[iWeapon]);
			int iVM = TF2Wear_CreateWeaponTiedWearable(iWeapon, true, m_sWeaponModel[iWeapon]);

			// Crutch to make the sheen appear on custom weapons models.
			int iKillStreakSheen = CEconItems_GetEntityAttributeInteger(iWeapon, "killstreak idleeffect");
			if(iKillStreakSheen > 0)
			{
				TF2Attrib_SetByName(iWM, "killstreak idleeffect", float(iKillStreakSheen));
				TF2Attrib_SetByName(iVM, "killstreak idleeffect", float(iKillStreakSheen));
			}

			if(bShouldDrawHands)
			{
				char arms[PLATFORM_MAX_PATH];
				switch (TF2_GetPlayerClass(client))
				{
					case TFClass_Scout: Format(arms, sizeof(arms), "models/weapons/c_models/c_scout_arms.mdl");
					case TFClass_Soldier: Format(arms, sizeof(arms), "models/weapons/c_models/c_soldier_arms.mdl");
					case TFClass_Pyro: Format(arms, sizeof(arms), "models/weapons/c_models/c_pyro_arms.mdl");
					case TFClass_DemoMan: Format(arms, sizeof(arms), "models/weapons/c_models/c_demo_arms.mdl");
					case TFClass_Heavy: Format(arms, sizeof(arms), "models/weapons/c_models/c_heavy_arms.mdl");
					case TFClass_Engineer: Format(arms, sizeof(arms), "models/weapons/c_models/c_engineer_arms.mdl");
					case TFClass_Medic: Format(arms, sizeof(arms), "models/weapons/c_models/c_medic_arms.mdl");
					case TFClass_Sniper: Format(arms, sizeof(arms), "models/weapons/c_models/c_sniper_arms.mdl");
					case TFClass_Spy: Format(arms, sizeof(arms), "models/weapons/c_models/c_spy_arms.mdl");
				}
				TF2Wear_CreateWeaponTiedWearable(iWeapon, true, arms);
			}
		}
	}
}


public void OnWeaponSwitch(int client, int weapon)
{
	// Validate that we have really switched to this weapon.
	// This fixes cases when some weapon become invisible.
	int iActiveWeapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
	if (iActiveWeapon != weapon)return;

	if (m_hLastWeapon[client] == weapon)return; // Nothing has changed.
	int iLastWeapon = m_hLastWeapon[client];

	if(iLastWeapon > 0)
	{
		TF2Wear_RemoveAllTiedWearables(iLastWeapon);
	}

	m_hLastWeapon[client] = weapon;

	if(CEconItems_IsEntityCustomEconItem(weapon))
	{
		OnDrawWeapon(client, weapon);
	}
}

public void OnWeaponDropped(int weapon)
{
	// If a weapon is dropped and it has a negative level, this means it's
	// most likely a Creators item. We'll remove it since it would be using
	// the stock item on the ground.
	if(IsValidEntity(weapon) && GetEntProp(weapon, Prop_Send, "m_iEntityLevel") == -1)
	{
		AcceptEntityInput(weapon, "Kill");
	}
}

public bool IsClientValid(int client)
{
	if (client <= 0 || client > MaxClients)return false;
	if (!IsClientInGame(client))return false;
	// if (!IsClientAuthorized(client))return false;
	return true;
}

public void TF2_OnConditionAdded(int client, TFCond cond)
{
	// If we are taunting, we don't want to be rendering any custom weapons.
	// We have to manually stop rendering them ourselves, so let's handle it here.
	if (cond == TFCond_Taunting)
	{
		bool bShouldHideWeapon = false;

		int iTaunt = GetEntProp(client, Prop_Send, "m_iTauntItemDefIndex");
		if(iTaunt > 0)
		{
			bShouldHideWeapon = true;
		}
		else 
		{
			// Grab the players active weapon.
			int iActiveWeapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");

			if(IsValidEntity(iActiveWeapon))
			{
				char sClassName[32];
				GetEntityClassname(iActiveWeapon, sClassName, sizeof(sClassName));
				
				// We're not going to be rendering the Rocket Launcher and the Engineers shotgun.
				if (StrEqual("tf_weapon_rocketlauncher", sClassName))bShouldHideWeapon = true;
				if (StrEqual("tf_weapon_shotgun_primary", sClassName))bShouldHideWeapon = true;
			}
		}
		
		// Hide all of our weapons.
		if(bShouldHideWeapon)
		{
			for (int i = 0; i < 5; i++)
			{
				int iWeapon = GetPlayerWeaponSlot(client, i);
				if (!IsValidEntity(iWeapon))continue;

				SetEntityRenderMode(iWeapon, RENDER_NORMAL);
				SetEntityRenderColor(iWeapon, 255, 255, 255, 255);

				TF2Wear_RemoveAllTiedWearables(iWeapon);
				SetEntProp(iWeapon, Prop_Send, "m_bBeingRepurposedForTaunt", 0);
			}
		}
	}
}

public void TF2_OnConditionRemoved(int client, TFCond cond)
{
	// If we've stopped taunting or zooming in, we should start
	// to redraw our weapons.
	if (cond == TFCond_Taunting ||
		cond == TFCond_Zoomed
	) {
		for (int i = 0; i < 5; i++)
		{
			int iWeapon = GetPlayerWeaponSlot(client, i);
			if (!IsValidEntity(iWeapon))continue;
			if (!CEconItems_IsEntityCustomEconItem(iWeapon))continue;
			
			// Start rendering.
			OnDrawWeapon(client, iWeapon);
		}
	}
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
// Purpose: Puts the style definition of the weapon in buffer
//--------------------------------------------------------------------
public bool GetWeaponStyleDefinition(CEItemDefinitionWeapon xWeapon, int style, CEItemDefinitionWeaponStyle xBuffer)
{
	for (int i = 0; i < xWeapon.m_iStylesCount; i++)
	{
		int iWorldIndex = xWeapon.m_iStyles[i];

		CEItemDefinitionWeaponStyle xStyle;
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
// Purpose: Fired when weapon style changes.
//--------------------------------------------------------------------
public void CEconItems_OnCustomEntityStyleUpdated(int client, int entity, int style)
{
	CEItem xItem;
	
	// Create our CEItem struct from this entity.
	if(CEconItems_GetEntityItemStruct(entity, xItem))
	{
		CEItemDefinitionWeapon xWeapon;
		
		// Create a CEItemDefinitionWeapon struct from this entity.
		if(FindWeaponDefinitionByIndex(xItem.m_iItemDefinitionIndex, xWeapon))
		{
			// Create a CEItemDefinitionWeaponStyle struct from this item definition.
			CEItemDefinitionWeaponStyle xStyle;
			if(GetWeaponStyleDefinition(xWeapon, style, xStyle))
			{
				// Update our weapon model, and start rendering again.
				strcopy(m_sWeaponModel[entity], sizeof(m_sWeaponModel[]), xStyle.m_sWorldModel);
				OnDrawWeapon(client, entity);
			}
		}
	}
}

//--------------------------------------------------------------------
// Purpose: If returned value is true, this item will be blocked.
// We check it to see if a specific weapon is allowed in a specific
// gamemode. I.e. Medieval.
//--------------------------------------------------------------------
public bool CEconItems_ShouldItemBeBlocked(int client, CEItem xItem, const char[] type)
{
	// We only want to care about weapons in this Forward.
	if (!StrEqual(type, "weapon"))return false;

	// Checks to see if this is medieval. The reason why this has two checks is because
	// of a bug in Medieval MvM missions where a tf_logic_medieval entity may exist, but
	// the GameRules prop isn't properly set. To counteract this, we just hook the creation
	// of the medieval logic entity.
	if(GameRules_GetProp("m_bPlayingMedieval") == 1 || m_bLogicMedievalExists == true)
	{
		// Grab this weapons item definition.
		CEItemDefinitionWeapon xWeapon;
		if(FindWeaponDefinitionByIndex(xItem.m_iItemDefinitionIndex, xWeapon))
		{
			int item_slot = TF2Econ_GetItemSlot(xWeapon.m_iBaseIndex, TF2_GetPlayerClass(client));

			// If this weapon is a melee weapon, allow it.
			if(item_slot == 2)return false;
			
			// Otherwise, see if this item has "allowed in medieval mode attribute".
			if(CEconItems_GetAttributeBoolFromArray(xItem.m_Attributes, "allowed in medieval mode")) return false;
			
			// Allow the weapon if we get here since it shouldn't be restricted.
			return true;
		}
	}
	return false;
}

#define TF_AMMO_PRIMARY 1
#define TF_AMMO_SECONDARY 2

public void TF2_RegenerateWeaponAmmo(int client, int weapon)
{
	if (!IsValidEntity(weapon))return;

	int iAmmoType = TF2_GetWeaponAmmoType(client, weapon);

	int iMaxAmmo = CTFPlayer_GetMaxAmmo(client, iAmmoType);
	int iClipSize = CTFWeaponBase_GetMaxClip1(weapon);

	SetEntData(client, FindSendPropInfo("CTFPlayer", "m_iAmmo") + iAmmoType * 4, iMaxAmmo	);
	SetEntProp(weapon, Prop_Send, "m_iClip1", iClipSize);
}

public int TF2_GetWeaponAmmoType(int client, int weapon)
{
	int iType = 0;
	for (int i = 0; i < 2; i++)
	{
		int iWeapon = GetPlayerWeaponSlot(client, i);
		if(iWeapon == weapon)
		{
			switch(i)
			{
				case 0:iType = TF_AMMO_PRIMARY;
				case 1:iType = TF_AMMO_SECONDARY;
			}
			break;
		}
	}
	return iType;
}

public int CTFPlayer_GetMaxAmmo(int client, int ammo)
{
	return SDKCall(g_hSdkGetMaxAmmo, client, ammo, -1);
}

public int CTFWeaponBase_GetMaxClip1(int weapon)
{
	return SDKCall(g_hSdkGetMaxClip, weapon);
}
