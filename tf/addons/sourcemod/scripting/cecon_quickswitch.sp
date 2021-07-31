#include <steamtools>

#pragma semicolon 1
#pragma newdecls required

#include <sdktools>
#include <sdkhooks>
#include <cecon>
#include <cecon_items>
#include <cecon_http>
#include <tf2>
#include <tf2_stocks>
#include <tf_econ_data>

public Plugin myinfo =
{
	name = "Creators.TF Quickswitch",
	author = "Creators.TF Team",
	description = "Creators.TF Quickswitch",
	version = "1.00",
	url = "https://creators.tf"
}

enum struct QuickswitchData_t 
{
	int m_bIsRequesting;
	char m_sClass[16];
	char m_sSlot[16];
}

QuickswitchData_t m_xQuickswitch[MAXPLAYERS + 1];

public void OnPluginStart()
{
	RegConsoleCmd("sm_quickswitch", cQuickswitch, "");
	RegConsoleCmd("sm_qs", cQuickswitch, "");
}

public Action cQuickswitch(int client, int args)
{
	TFClassType nClass = TF2_GetPlayerClass(client);
	
	int iWeapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
	if (iWeapon == -1)return Plugin_Handled;
	
	char sClassName[32];
	int iDefID = GetEntProp(iWeapon, Prop_Send, "m_iItemDefinitionIndex");
	GetEntityClassname(iWeapon, sClassName, sizeof(sClassName));
	
	int iSlot = TF2Econ_GetItemSlot(iDefID, nClass);
	
	if (StrEqual(sClassName, "tf_weapon_revolver"))iSlot = 0;
	if (StrEqual(sClassName, "tf_weapon_sapper"))iSlot = 3;
	if (StrEqual(sClassName, "tf_weapon_pda_engineer_build"))iSlot = 3;
	if (StrEqual(sClassName, "tf_weapon_pda_engineer_destroy"))iSlot = 3;
	
	if (iSlot > 3)return Plugin_Handled;
	if (iSlot < 0)return Plugin_Handled;
	RequestClientSlotItems(client, nClass, iSlot);
		
	return Plugin_Handled;
}

public void RequestClientSlotItems(int client, TFClassType nClass, int nSlot)
{
	if (!IsClientReady(client))return;
	
	char sSteamID[64];
	GetClientAuthId(client, AuthId_SteamID64, sSteamID, sizeof(sSteamID));
	
	char sClass[16];
	switch(nClass)
	{
		case TFClass_Scout:strcopy(sClass, sizeof(sClass), "scout");
		case TFClass_Soldier:strcopy(sClass, sizeof(sClass), "soldier");
		case TFClass_Pyro:strcopy(sClass, sizeof(sClass), "pyro");
		case TFClass_DemoMan:strcopy(sClass, sizeof(sClass), "demo");
		case TFClass_Heavy:strcopy(sClass, sizeof(sClass), "heavy");
		case TFClass_Engineer:strcopy(sClass, sizeof(sClass), "engineer");
		case TFClass_Medic:strcopy(sClass, sizeof(sClass), "medic");
		case TFClass_Sniper:strcopy(sClass, sizeof(sClass), "sniper");
		case TFClass_Spy:strcopy(sClass, sizeof(sClass), "spy");
	}
	
	char sSlot[16];
	switch(nSlot)
	{
		case 0:strcopy(sSlot, sizeof(sSlot), "PRIMARY");
		case 1:strcopy(sSlot, sizeof(sSlot), "SECONDARY");
		case 2:strcopy(sSlot, sizeof(sSlot), "MELEE");
		case 3:strcopy(sSlot, sizeof(sSlot), "PDA");
	}
	
	HTTPRequestHandle hRequest = CEconHTTP_CreateBaseHTTPRequest("/api/IEconomySDK/UserQuickswitch", HTTPMethod_GET);

	// Setting mission name.
	Steam_SetHTTPRequestGetOrPostParameter(hRequest, "steamid", sSteamID);
	Steam_SetHTTPRequestGetOrPostParameter(hRequest, "class", sClass);
	Steam_SetHTTPRequestGetOrPostParameter(hRequest, "slot", sSlot);
	
	Steam_SendHTTPRequest(hRequest, RequestClientSlotItems_Callback, client);
	
	m_xQuickswitch[client].m_bIsRequesting = true;
	strcopy(m_xQuickswitch[client].m_sClass, sizeof(m_xQuickswitch[].m_sClass), sClass);
	strcopy(m_xQuickswitch[client].m_sSlot, sizeof(m_xQuickswitch[].m_sSlot), sSlot);
	
	Menu menu = new Menu(Menu_QuickSwitch);
	menu.SetTitle("Please wait...");
	menu.AddItem("", "Close");
		
	menu.ExitButton = false;
	menu.Display(client, 20);
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

public void RequestClientSlotItems_Callback(HTTPRequestHandle request, bool success, HTTPStatusCode code, any client)
{
	m_xQuickswitch[client].m_bIsRequesting = false;
	
	// If request was not succesful, return.
	if (!success)return;
	if (code != HTTPStatusCode_OK)return;
	
	// Getting response size.
	int size = Steam_GetHTTPResponseBodySize(request);
	char[] content = new char[size + 1];
	
	Steam_GetHTTPResponseBodyData(request, content, size);
	Steam_ReleaseHTTPRequest(request);
	
	KeyValues kv = new KeyValues("Response");
	
	// If we fail to import content return.
	if (!kv.ImportFromString(content))return;
	
	bool bIsEmpty = kv.GetNum("is_empty", 0) == 1;
	
	if(kv.JumpToKey("items", false))
	{
		bool bNoItems = true;
		
		Menu menu = new Menu(Menu_QuickSwitch);
		menu.SetTitle("Select an Item to equip:");
		
		if(!bIsEmpty)
		{
			bNoItems = false;
			menu.AddItem("0", "[Unequip]");
		}
		
		if(kv.GotoFirstSubKey())
		{
			do {
				bNoItems = false;
				char sIndex[11], sName[256];
				kv.GetString("id", sIndex, sizeof(sIndex));
				kv.GetString("name", sName, sizeof(sName));
				
				menu.AddItem(sIndex, sName);
			
			} while kv.GotoNextKey();
		}
		
		if(bNoItems)
		{
			menu.AddItem("", "No items are available to equip for this slot.", ITEMDRAW_DISABLED);
		}
		
		menu.ExitButton = true;
		menu.Display(client, 20);
	}
	
	delete kv;
}

public int Menu_QuickSwitch(Menu menu, MenuAction action, int client, int param2)
{
    if (action == MenuAction_Select)
    {
        char info[32];
        bool found = menu.GetItem(param2, info, sizeof(info));
        if(found && !StrEqual(info, ""))
        {
        	ChangePlayerLoadoutSlotItem(client, m_xQuickswitch[client].m_sClass, m_xQuickswitch[client].m_sSlot, info);
       	}
    } else if (action == MenuAction_End)
    {
        delete menu;
    }
}

public void ChangePlayerLoadoutSlotItem(int client, const char[] classname, const char[] slot, const char[] item)
{
	if (!IsClientReady(client))return;
	
	char sSteamID[64];
	GetClientAuthId(client, AuthId_SteamID64, sSteamID, sizeof(sSteamID));
	
	HTTPRequestHandle hRequest = CEconHTTP_CreateBaseHTTPRequest("/api/IEconomySDK/UserQuickswitch", HTTPMethod_POST);

	// Setting mission name.
	Steam_SetHTTPRequestGetOrPostParameter(hRequest, "steamid", sSteamID);
	Steam_SetHTTPRequestGetOrPostParameter(hRequest, "class", classname);
	Steam_SetHTTPRequestGetOrPostParameter(hRequest, "slot", slot);
	Steam_SetHTTPRequestGetOrPostParameter(hRequest, "item", item);
	
	Steam_SendHTTPRequest(hRequest, ChangePlayerLoadoutSlotItem_Callback);
}

public void ChangePlayerLoadoutSlotItem_Callback(HTTPRequestHandle request, bool success, HTTPStatusCode code, any client)
{
	// Le epic.
}