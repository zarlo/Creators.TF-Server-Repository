#include <sourcemod>
#include <tf2_stocks>
#include <tf2attributes>
#undef REQUIRE_PLUGIN
#include <ce_core>
#define REQUIRE_PLUGIN

public Plugin myinfo =
{
	name = "Balance Mod Rebalance Plugin",
	author = "Moonly Days & HiGPS",
	description = "Rebalance weapons for Balance Mod",
	version = "1.0",
	url = "https://steamcommunity.com/profiles/76561197963998743"
}

bool g_bCooldown[MAXPLAYERS + 1];
KeyValues g_hConfig;

public void OnPluginStart()
{
	HookEvent("post_inventory_application", evPostEvent);
	HookEvent("player_spawn", evPostEvent);
	
	RegAdminCmd("sm_reloadbalance", cReload, ADMFLAG_ROOT, "Reloads balance changes");
	
	LoadConfig();
}

public Action cReload(int client, int args)
{
	LoadConfig();
	ReplyToCommand(client, "[SM] Balance Changes Reloaded");
	return Plugin_Handled;
}

public void LoadConfig()
{
	if (g_hConfig != INVALID_HANDLE)delete g_hConfig;
	
	char sLoc[128];
	BuildPath(Path_SM, sLoc, sizeof(sLoc), "data/balance.cfg");
	
	g_hConfig = new KeyValues("Balance");
	g_hConfig.ImportFromFile(sLoc);
}

public void CE_OnPostEquip(int client, int entity, int index, int defid, int quality, ArrayList hAttributes, char[] type)
{
	char sClass[11];
	switch(TF2_GetPlayerClass(client))
	{
		case TFClass_Scout: strcopy(sClass, sizeof(sClass), "Scout");
		case TFClass_Soldier: strcopy(sClass, sizeof(sClass), "Soldier");
		case TFClass_Pyro: strcopy(sClass, sizeof(sClass), "Pyro");
		case TFClass_DemoMan: strcopy(sClass, sizeof(sClass), "Demoman");
		case TFClass_Heavy: strcopy(sClass, sizeof(sClass), "Heavy");
		case TFClass_Engineer: strcopy(sClass, sizeof(sClass), "Engineer");
		case TFClass_Medic: strcopy(sClass, sizeof(sClass), "Medic");
		case TFClass_Sniper: strcopy(sClass, sizeof(sClass), "Sniper");
		case TFClass_Spy: strcopy(sClass, sizeof(sClass), "Spy");
	}
	
	if (g_hConfig.JumpToKey(sClass, false))
	{
		ApplyChanges(client, entity, g_hConfig, sClass);
		g_hConfig.GoBack();
	}
	if (g_hConfig.JumpToKey("Multi", false))
	{
		ApplyChanges(client, entity, g_hConfig, sClass);
		g_hConfig.GoBack();
	}
}

public Action evPostEvent(Event event, const char[] name, bool dontBroadcast)
{
	int iClient = GetClientOfUserId(event.GetInt("userid"));
	if (g_bCooldown[iClient])return Plugin_Handled;
	CreateTimer(0.5, Timer_Cooldown, iClient);
	g_bCooldown[iClient] = true;
	
	
	char sClass[11];
	switch(TF2_GetPlayerClass(iClient))
	{
		case TFClass_Scout: strcopy(sClass, sizeof(sClass), "Scout");
		case TFClass_Soldier: strcopy(sClass, sizeof(sClass), "Soldier");
		case TFClass_Pyro: strcopy(sClass, sizeof(sClass), "Pyro");
		case TFClass_DemoMan: strcopy(sClass, sizeof(sClass), "Demoman");
		case TFClass_Heavy: strcopy(sClass, sizeof(sClass), "Heavy");
		case TFClass_Engineer: strcopy(sClass, sizeof(sClass), "Engineer");
		case TFClass_Medic: strcopy(sClass, sizeof(sClass), "Medic");
		case TFClass_Sniper: strcopy(sClass, sizeof(sClass), "Sniper");
		case TFClass_Spy: strcopy(sClass, sizeof(sClass), "Spy");
	}
	
	
	
	for (int i = 0; i <= 5 ; i++){
		int iWeapon = GetPlayerWeaponSlot(iClient, i);
		if(IsValidEntity(iWeapon)){
			if (g_hConfig.JumpToKey(sClass, false))
			{
				ApplyChanges(iClient, iWeapon, g_hConfig, sClass);
				g_hConfig.GoBack();
			}
			if (g_hConfig.JumpToKey("Multi", false))
			{
				ApplyChanges(iClient, iWeapon, g_hConfig, sClass);
				g_hConfig.GoBack();
			}
		}
	}
	
	int iWearable;
	while ((iWearable = FindEntityByClassname(iWearable, "tf_wearable*")) != -1)
	{
		if(GetEntPropEnt(iWearable, Prop_Send, "m_hOwnerEntity") == iClient)
		{
			if (g_hConfig.JumpToKey(sClass, false))
			{
				ApplyChanges(iClient, iWearable, g_hConfig, sClass);
				g_hConfig.GoBack();
			}
			if (g_hConfig.JumpToKey("Multi", false))
			{
				ApplyChanges(iClient, iWearable, g_hConfig, sClass);
				g_hConfig.GoBack();
			}
		}
	}
	
	g_hConfig.Rewind();
	return Plugin_Handled;
}

public void ApplyChanges(int iClient, int iWeapon, KeyValues hConfig, const char[] sClass)
{
	int iDef = -1, iSlot = -1;
	if(HasEntProp(iWeapon, Prop_Send, "m_iItemDefinitionIndex"))
		iDef = GetEntProp(iWeapon, Prop_Send, "m_iItemDefinitionIndex");
	
	iSlot = GetPlayerSlotOfWeapon(iClient, iWeapon);
	
	if(hConfig.GotoFirstSubKey())
	{
		do {
			char 	sEntClass[64], 
					sCompareClass[64], 
					sOnly[128], 
					sExcept[128];
			
			GetEntityClassname(iWeapon, sEntClass, sizeof(sEntClass));
			
			TF2_ParseClassname(sEntClass, sizeof(sEntClass), TF2_GetPlayerClass(iClient));
			
			hConfig.GetString("Classname", sCompareClass, sizeof(sCompareClass));
			hConfig.GetString("Only", sOnly, sizeof(sOnly));
			hConfig.GetString("Except", sExcept, sizeof(sExcept));
			
			if((
				StrEqual(sCompareClass, "") ||
				(!StrEqual(sCompareClass, "") && StrEqual(sEntClass, sCompareClass))
			) && (
				hConfig.GetNum("Index", -1) == -1 ||
				(hConfig.GetNum("Index", -1) != -1 && hConfig.GetNum("Index", -1) == iDef)
			) && (
				hConfig.GetNum("Slot", -1) == -1 ||
				(hConfig.GetNum("Slot", -1) != -1 && hConfig.GetNum("Slot", -1) == iSlot)
			) && (
				hConfig.GetNum("AllClassOnly", -1) == -1 ||
				(hConfig.GetNum("AllClassOnly", -1) != -1 && IsAllClass(iDef) == true)
			) && (
				StrEqual(sOnly, "") ||
				(!StrEqual(sOnly, "") && StrContains(sOnly, sClass) != -1)
			) && (
				StrEqual(sExcept, "") ||
				(!StrEqual(sExcept, "") && StrContains(sExcept, sClass) == -1)
			)) {
				if(hConfig.GotoFirstSubKey())
				{
					do {
						char sSection[64];
						hConfig.GetSectionName(sSection, sizeof(sSection));
						if (!StrEqual(sSection, "attribute", false)) continue;
						
						int iIndex = hConfig.GetNum("Index", 0);
						char sName[128];
						hConfig.GetString("Name", sName, sizeof(sName));
						
						float flValue = hConfig.GetFloat("Value", 1.0);
						
						if (!StrEqual(sName, ""))TF2Attrib_SetByName(iWeapon, sName, flValue);
						else if (iIndex != 0)TF2Attrib_SetByDefIndex(iWeapon, iIndex, flValue);
					}	while (hConfig.GotoNextKey())
					hConfig.GoBack();
				}
			}
		} while (hConfig.GotoNextKey())
		hConfig.GoBack();
	}
}

public void TF2_ParseClassname(char[] classname, int length, TFClassType class)
{
	if(
		StrEqual(classname, "tf_weapon_shotgun_soldier") ||
		StrEqual(classname, "tf_weapon_shotgun_primary") ||
		StrEqual(classname, "tf_weapon_shotgun_pyro") ||
		StrEqual(classname, "tf_weapon_shotgun_hwg")
	) {
		strcopy(classname, length, "tf_weapon_shotgun");
	}
	
	else if(
		StrEqual(classname, "tf_weapon_pistol_scout") ||
		StrEqual(classname, "tf_weapon_pistol")
	) {
		strcopy(classname, length, "tf_weapon_pistol");
	}
	
	return;
}

public Action Timer_Cooldown(Handle timer, any data)
{
	g_bCooldown[data] = false;
}

public bool IsAllClass(int id){
	return (
		id == 264 || 
		id == 423 || 
		id == 474 || 
		id == 880 || 
		id == 939 || 
		id == 954 || 
		id == 1013 || 
		id == 1071 || 
		id == 1123 || 
		id == 1127 || 
		id == 30758
	);
}

public int GetPlayerSlotOfWeapon(int client, int wep)
{
	for (int i = 0; i <= 5 ; i++){
		int wep2 = GetPlayerWeaponSlot(client, i);
		if(IsValidEntity(wep2)){
			if (wep == wep2)return i;
		}
	}
	return -1;
}