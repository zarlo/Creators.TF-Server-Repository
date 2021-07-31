#pragma semicolon 1
#pragma newdecls required

#include <tf2>
#include <tf2_stocks>
#include <tf2motd>
#include <morecolors>

bool m_bIsMOTDOpen[MAXPLAYERS + 1];
bool m_bWaitForNoInput[MAXPLAYERS + 1];

#define DISABLEDHTTP_MESSAGE "\x01* To use this command, you'll need to set \x03cl_disablehtmlmotd 0 \x01in your console."

public Plugin myinfo =
{
	name = "[TF2] MotD Module",
	author = "Moonly Days",
	description = "Handles custom MOTDs and automatically closes them.",
	version = "1.00",
	url = "https://moonlydays.com"
}

public void OnPluginStart()
{
	RegConsoleCmd("sm_l", cOpenLoadout, "Opens your Creators.TF Loadout");
	RegConsoleCmd("sm_loadout", cOpenLoadout, "Opens your Creators.TF Loadout");

	RegConsoleCmd("sm_website", cOpenWebsite, "Opens Creators.TF Website");
	RegConsoleCmd("sm_w", cOpenWebsite, "Opens Creators.TF Website");

	RegConsoleCmd("sm_servers", cOpenServers, "Opens Creators.TF Servers");
	RegConsoleCmd("sm_server", cOpenServers, "Opens Creators.TF Servers");
	RegConsoleCmd("sm_hop", cOpenServers, "Opens Creators.TF Servers");
	RegConsoleCmd("sm_serverhop", cOpenServers, "Opens Creators.TF Servers");
	RegConsoleCmd("sm_s", cOpenServers, "Opens Creators.TF Servers");

	RegConsoleCmd("sm_contracker", cOpenContracker, "Opens your Creators.TF ConTracker");
	RegConsoleCmd("sm_c", cOpenContracker, "Opens your Creators.TF ConTracker");

	RegConsoleCmd("sm_campaign", cOpenCampaign, "Opens active Creators.TF Campaign");
	RegConsoleCmd("sm_ca", cOpenCampaign, "Opens active Creators.TF Campaign");
	RegConsoleCmd("sm_cc", cOpenCampaign, "Opens active Creators.TF Campaign");

	RegConsoleCmd("sm_inventory", cOpenInventory, "Opens your Creators.TF Inventory");
	RegConsoleCmd("sm_i", cOpenInventory, "Opens your Creators.TF Inventory");

	RegConsoleCmd("sm_profile", cOpenProfile, "Opens your Creators.TF Profile");
	RegConsoleCmd("sm_p", cOpenProfile, "Opens your Creators.TF Profile");
	
	RegConsoleCmd("sm_wiki", cOpenWiki, "Opens the Wikipedia page of the current MvM Mission you're playing on.");
}

// Native and Forward creation.
public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	RegPluginLibrary("tf2motd");
	
	CreateNative("TF2Motd_OpenURL", Native_OpenURL);
	return APLRes_Success;
}

public Action cOpenWebsite(int client, int args)
{
 	TF2Motd_OpenURL(client, "https://creators.tf", DISABLEDHTTP_MESSAGE);
	return Plugin_Handled;
}

/**
*	Purpose: sm_loadout / sm_l command.
*/
public Action cOpenLoadout(int client, int args)
{
	TFClassType class = TF2_GetPlayerClass(client);
	if (class == TFClass_Unknown)return Plugin_Handled;

	char url[PLATFORM_MAX_PATH];
	Format(url, sizeof(url), "https://creators.tf/loadout/");

	switch (class)
	{
		case TFClass_Scout:Format(url, sizeof(url), "%sscout", url);
		case TFClass_Soldier:Format(url, sizeof(url), "%ssoldier", url);
		case TFClass_Pyro:Format(url, sizeof(url), "%spyro", url);
		case TFClass_DemoMan:Format(url, sizeof(url), "%sdemo", url);
		case TFClass_Heavy:Format(url, sizeof(url), "%sheavy", url);
		case TFClass_Engineer:Format(url, sizeof(url), "%sengineer", url);
		case TFClass_Medic:Format(url, sizeof(url), "%smedic", url);
		case TFClass_Sniper:Format(url, sizeof(url), "%ssniper", url);
		case TFClass_Spy:Format(url, sizeof(url), "%sspy", url);
	}

 	TF2Motd_OpenURL(client, url, DISABLEDHTTP_MESSAGE);
	return Plugin_Handled;
}

/**
*	Purpose: sm_servers / sm_s command.
*/
public Action cOpenServers(int client, int args)
{
 	TF2Motd_OpenURL(client, "https://creators.tf/servers", DISABLEDHTTP_MESSAGE);
	return Plugin_Handled;
}

/**
*	Purpose: sm_contracker / sm_c command.
*/
public Action cOpenContracker(int client, int args)
{
 	TF2Motd_OpenURL(client, "https://creators.tf/contracker", DISABLEDHTTP_MESSAGE);
	return Plugin_Handled;
}

/**
*	Purpose: sm_contracker / sm_c command.
*/
public Action cOpenCampaign(int client, int args)
{
 	TF2Motd_OpenURL(client, "https://creators.tf/campaign", DISABLEDHTTP_MESSAGE);
	return Plugin_Handled;
}

/**
*	Purpose: sm_inventory / sm_i command.
*/
public Action cOpenInventory(int client, int args)
{
	char sSteamID[64];
	char url[PLATFORM_MAX_PATH];
	GetClientAuthId(client, AuthId_SteamID64, sSteamID, sizeof(sSteamID));
	Format(url, sizeof(url), "https://creators.tf/profiles/%s/inventory", sSteamID);

 	TF2Motd_OpenURL(client, url, DISABLEDHTTP_MESSAGE);
	return Plugin_Handled;
}

/**
*	Purpose: sm_profile / sm_p command.
*/
public Action cOpenProfile(int client, int args)
{
	char sSteamID[64];
	char url[PLATFORM_MAX_PATH];
	GetClientAuthId(client, AuthId_SteamID64, sSteamID, sizeof(sSteamID));
	Format(url, sizeof(url), "https://creators.tf/profiles/%s", sSteamID);

 	TF2Motd_OpenURL(client, url, DISABLEDHTTP_MESSAGE);
	return Plugin_Handled;
}

public Action cOpenWiki(int client, int args)
{
	if (!TF2MvM_IsPlayingMvM())
	{
		MC_ReplyToCommand(client, "[{creators}Creators.TF{default}] This command currently only works while playing Mann Vs. Machine.");
		return Plugin_Handled;
	}
	
	char sSteamID[64];
	char url[PLATFORM_MAX_PATH];
	GetClientAuthId(client, AuthId_SteamID64, sSteamID, sizeof(sSteamID));
	
	char missionPath[PLATFORM_MAX_PATH], missionName[256];
	int resource = FindEntityByClassname(-1, "tf_objective_resource");
	GetEntPropString(resource, Prop_Send,"m_iszMvMPopfileName", missionPath, sizeof missionPath);
	Format(missionName, sizeof missionName, "%s", missionPath[FindCharInString(missionPath,'/',true)+1]);
	ReplaceString(missionName, sizeof missionName, ".pop", "");
	ReplaceString(missionName, sizeof missionName, "mvm_", "");
	
	char toRemove[128];
	SplitString(missionName, "adv", toRemove, sizeof toRemove);
	Format(toRemove, sizeof toRemove, "%sadv_", toRemove);
	ReplaceString(missionName, sizeof missionName, toRemove, "");
	
	bool upper = false;
	for (int i = 0; i < strlen(missionName); i++)
	{
		if (i == 0 || upper)
		{
			missionName[i] = CharToUpper(missionName[i]);
			upper = false;
		}
		if (missionName[i] == '_') upper = true;
	}
	
	ReplaceString(missionName, sizeof missionName, "To", "to"); // this is stupid...
	
	Format(url, sizeof(url), "https://wiki.teamfortress.com/wiki/%s_(mission)", missionName);

 	TF2Motd_OpenURL(client, url, DISABLEDHTTP_MESSAGE);
	return Plugin_Handled;
}

public Action OpenURL(int client, const char[] url)
{
	DataPack dPack = new DataPack();
	WritePackString(dPack, url);
	QueryClientConVar(client, "cl_disablehtmlmotd", QueryConVar_Motd, dPack);

	return Plugin_Handled;
}

public void OnClientDisconnect(int client)
{
	m_bIsMOTDOpen[client] = false;
}

public void CloseMOTD(int client)
{
	m_bIsMOTDOpen[client] = false;

	KeyValues hConf = new KeyValues("data");
	hConf.SetNum("type", 2);
	hConf.SetString("msg", "about:blank");
	hConf.SetNum("customsvr", 1);

	ShowVGUIPanel(client, "info", hConf, false);
	delete hConf;
}

public Action OnPlayerRunCmd(int client, int &buttons)
{
	// We're waiting for client to unpress input keys.
	if(m_bWaitForNoInput[client])
	{
		if(!(buttons & (IN_ATTACK | IN_JUMP | IN_DUCK | IN_FORWARD | IN_BACK | IN_MOVELEFT | IN_MOVERIGHT | IN_ATTACK2)))
		{
			m_bWaitForNoInput[client] = false;
		}
		
	} else {
		// They unpressed all the keys.
		
		// Since TF2 no longer allows us to check when a MOTD is closed, we'll have to detect player's movements (indicating that motd is no longer open).
		if (m_bIsMOTDOpen[client])
		{
			if (buttons & (IN_ATTACK | IN_JUMP | IN_DUCK | IN_FORWARD | IN_BACK | IN_MOVELEFT | IN_MOVERIGHT | IN_ATTACK2))
			{
				CloseMOTD(client);
			}
		}
	}
}

public any Native_OpenURL(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	char sURL[PLATFORM_MAX_PATH];
	GetNativeString(2, sURL, sizeof(sURL));
	
	char sMessage[PLATFORM_MAX_PATH];
	GetNativeString(3, sMessage, sizeof(sMessage));
	
	DataPack dPack = new DataPack();
	WritePackString(dPack, sURL);
	WritePackString(dPack, sMessage);
	
	QueryClientConVar(client, "cl_disablehtmlmotd", QueryConVar_Motd, dPack);
}
	
public void QueryConVar_Motd(QueryCookie cookie, int client, ConVarQueryResult result, const char[] cvarName, const char[] cvarValue, DataPack dPack)
{
	ResetPack(dPack);
	
	char sURL[PLATFORM_MAX_PATH];
	ReadPackString(dPack, sURL, sizeof(sURL));
	
	char sMessage[PLATFORM_MAX_PATH];
	ReadPackString(dPack, sMessage, sizeof(sMessage));
	
	delete dPack;
	
	
	if (result == ConVarQuery_Okay)
	{
		if (StringToInt(cvarValue) != 0)
		{
			if(!StrEqual(sMessage, ""))
			{
				PrintToChat(client, sMessage);
			}
			return;
		}
		else
		{
			KeyValues hConf = new KeyValues("data");
			hConf.SetNum("type", 2);
			hConf.SetString("msg", sURL);
			hConf.SetNum("customsvr", 1);
			ShowVGUIPanel(client, "info", hConf);
			delete hConf;
			
			m_bWaitForNoInput[client] = true;
			m_bIsMOTDOpen[client] = true;
		}
	}
}

stock bool TF2MvM_IsPlayingMvM()
{
	return (GameRules_GetProp("m_bPlayingMannVsMachine") != 0);
}
