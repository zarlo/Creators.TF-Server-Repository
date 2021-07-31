#pragma semicolon 1

#include <steamtools>
#include <cecon_http>
#include <ccc>

public Plugin myinfo =
{
	name = "Creators.TF Patreon Perks",
	author = "Creators.TF Team",
	description = "Applies perks to Creators.TF Patreons.",
	version = "1.0",
	url = "https://creators.tf"
};

bool g_bCCC;

ConVar ce_patreon_debug;

public void OnPluginStart()
{
	ce_patreon_debug = CreateConVar("ce_patreon_debug", "0");

	LoadAllClientsPledges();
}

public void OnLibraryAdded(const char[] name)
{
	if (StrEqual(name, "ccc")) g_bCCC = true;
}

public void OnLibraryRemoved(const char[] name)
{
	if (StrEqual(name, "ccc")) g_bCCC = false;
}

public void LoadAllClientsPledges()
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientReady(i))continue;

		LoadClientPledge(i);
	}
}

public void OnClientPostAdminCheck(int client)
{
	if (!IsClientReady(client))return;

	LoadClientPledge(client);
}

public void LoadClientPledge(int client)
{
	LogMessage("LoadClientPledge(%d)", client);

	char sSteamID[PLATFORM_MAX_PATH];
	GetClientAuthId(client, AuthId_SteamID64, sSteamID, sizeof(sSteamID));

	HTTPRequestHandle httpRequest = CEconHTTP_CreateBaseHTTPRequest("/api/IEconomySDK/UserDonations", HTTPMethod_GET);
	Steam_SetHTTPRequestGetOrPostParameter(httpRequest, "steamid", sSteamID);

	Steam_SendHTTPRequest(httpRequest, httpPlayerDonation_Callback, client);
}

public void httpPlayerDonation_Callback(HTTPRequestHandle request, bool success, HTTPStatusCode code, any client)
{
	LogMessage("httpPlayerDonation_Callback %d %d %d", code, success, client);
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

	KeyValues kv = new KeyValues("Response");
	kv.ImportFromString(content);

	int centsAmount = kv.GetNum("amount");
	delete kv;

	if (ce_patreon_debug.BoolValue)
	{
		PrintToServer("Amount of cents for %N: %d", client, centsAmount);
	}
	
	bool patron = false;
	if (centsAmount >= 200 && centsAmount < 500)
	{
		SetClientAdminFlag(client, Admin_Custom1);
		patron = true;
	}
	else if (centsAmount >= 500 && centsAmount < 1000)
	{
		SetClientAdminFlag(client, Admin_Custom2);
		patron = true;
	}
	else if (centsAmount >= 1000)
	{
		SetClientAdminFlag(client, Admin_Custom3);
		patron = true;
	}

	if (patron)
	{
        SetClientAdminFlag(client, Admin_Custom4);
        RunAdminCacheChecks(client);
        if (g_bCCC) CreateTimer(1.0, Timer_ReloadCCC, _, TIMER_FLAG_NO_MAPCHANGE);
	}
}

public Action Timer_ReloadCCC(Handle hTimer)
{
	ServerCommand("sm_reloadccc");
}


public void SetClientAdminFlag(int client, AdminFlag flag)
{
	AdminId adm = GetUserAdmin(client);

	if (adm == INVALID_ADMIN_ID)
	{
		adm = CreateAdmin();
		SetUserAdmin(client, adm, true);
	}

	adm.SetFlag(flag, true);
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
