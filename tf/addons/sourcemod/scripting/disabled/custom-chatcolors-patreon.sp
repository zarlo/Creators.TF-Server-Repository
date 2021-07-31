#pragma semicolon 1

#define PLUGIN_AUTHOR "Creators.TF Team"
#define PLUGIN_VERSION "1.0"

#include <sourcemod>
#include <ce_core>
#include <system2>
#include <ccc>

bool g_bCCC = false;
bool g_bCreators = false;
char g_sCreatorsKey[PLATFORM_MAX_PATH];


public Plugin myinfo =
{
	name = "Custom Chat Colors Patreon Module",
	author = PLUGIN_AUTHOR,
	description = "Adds chat tags to players who are a Creators.TF patron.",
	version = PLUGIN_VERSION,
	url = "https://creators.tf"
};

public void OnPluginStart()
{
	CreateConVar("ccc_patreon_version", PLUGIN_VERSION, "Custom Chat Colors Patreon Module Version", FCVAR_DONTRECORD);
	AddCommandListener(Cmd_ReloadCCC, "sm_reloadccc");

	CE_GetServerAccessKey(g_sCreatorsKey, sizeof(g_sCreatorsKey));

	ApplyTags();
}

public Action Cmd_ReloadCCC(int client, const char[] command, int argc)
{
	ApplyTags();
}

public void OnLibraryAdded(const char[] name)
{
	if (StrEqual(name, "ccc"))
	{
		g_bCCC = true;
	}
	if (StrEqual(name, "ce_core"))
	{
		g_bCCC = true;
		CE_GetServerAccessKey(g_sCreatorsKey, sizeof(g_sCreatorsKey));
	}
	if(g_bCCC && g_bCreators)
	{
		ApplyTags();
	}
}

public void OnLibraryRemoved(const char[] name)
{
	if (StrEqual(name, "ccc")) g_bCCC = false;
	if (StrEqual(name, "ce_core")) g_bCCC = false;
}

public void OnClientPostAdminCheck(int client)
{
	if ((!IsClientInGame(client) || IsFakeClient(client)) || GetUserAdmin(client) != INVALID_ADMIN_ID) return;
	ApplyTags(client);
}

void ApplyTags(int client = 0)
{
	if (client == 0)
	{
		for (int i = 1; i <= MaxClients; i++)
		{
			if (IsClientInGame(i) && !IsFakeClient(i) && GetUserAdmin(i) == INVALID_ADMIN_ID)
			{
				ApplyTagsClient(i);
			}
		}
	}
	else
	{
		ApplyTagsClient(client);
	}
}

public void ApplyTagsClient(int client)
{
	char sSteamID[PLATFORM_MAX_PATH];
	GetClientAuthId(client, AuthId_SteamID64, sSteamID, sizeof(sSteamID));

	char sURL[128];
	CE_GetAPIGatewayBase(sURL, sizeof(sURL));
	Format(sURL, sizeof(sURL), "%s/IDonations/GUserDonations?steamid=%s", sURL, sSteamID);
	System2HTTPRequest httpRequest = new System2HTTPRequest(httpDonationCallback, sURL);

	char sHeader[256];
	CE_GetAPIGatewayKey(sHeader, sizeof(sHeader));
	httpRequest.SetHeader("Authorization", sHeader);

	// Authentication using server API key and user steamid.
	Format(sHeader, sizeof(sHeader), "server %s %d %s", g_sCreatorsKey, CE_GetServerID(), sSteamID);
	httpRequest.SetHeader("Access", sHeader);

	// Setting to accept the response in the KeyValues format.
	httpRequest.SetHeader("Accept", "text/keyvalues");

	httpRequest.Any = client;
	httpRequest.GET();

	delete httpRequest;
}

public void httpDonationCallback(bool success, const char[] error, System2HTTPRequest request, System2HTTPResponse response, HTTPRequestMethod method)
{
	if (!IsClientReady(request.Any))return;
	if(success && response.StatusCode == 200)
	{
		char[] content = new char[response.ContentLength + 1];
		response.GetContent(content, response.ContentLength + 1);
		KeyValues kv = new KeyValues("Response");
		kv.ImportFromString(content);

		int centsAmount = kv.GetNum("amount");

		delete kv;
		char tag[32], color[32];

		if (centsAmount >= 200 && centsAmount < 500)
		{
			Format(tag, sizeof(tag), "Patreon Tier I | ");
			Format(color, sizeof(color), "f0cca5");
		}
		else if (centsAmount >= 500 && centsAmount < 1000)
		{
			Format(tag, sizeof(tag), "Patreon Tier II | ");
			Format(color, sizeof(color), "e8af72");
		}
		else if (centsAmount >= 1000)
		{
			Format(tag, sizeof(tag), "Patreon Tier III | ");
			Format(color, sizeof(color), "e38a2b");
		}

		if (g_bCCC)
		{
			CCC_SetTag(request.Any, tag);
			CCC_SetColor(request.Any, CCC_TagColor, StringToInt(color, 16), false);
		}
		else
		{
			LogError("Custom-ChatColors was not detected, therefore patreon tags cannot be set.");
		}
	}else{
		PrintToChat(request.Any, "\x03We couldn't check your donation status. Your name tag might not work if you have one.");
	}
}
