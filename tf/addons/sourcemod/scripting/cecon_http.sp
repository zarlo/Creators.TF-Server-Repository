//============= Copyright Amper Software, All rights reserved. ============//
//
// Purpose: HTTP extension for Creators.TF economy.
//
//=========================================================================//

#include <steamtools>
#include <cecon_http>
#include <cecon>

#pragma semicolon 1
#pragma newdecls required
#pragma tabsize 0

public Plugin myinfo =
{
	name = "Creators.TF HTTP Module",
	author = "Creators.TF Team",
	description = "HTTP plugin that handles connection between plugins and backend.",
	version = "1.0",
	url = "https://creators.tf"
}

ConVar ce_http_debug_requests;

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	RegPluginLibrary("cecon_http");
	
	CreateNative("CEconHTTP_CreateAbsoluteBackendURL", Native_CreateAbsoluteBackendURL);
	CreateNative("CEconHTTP_CreateBaseHTTPRequest", Native_CreateBaseHTTPRequest);
	
	ce_http_debug_requests = CreateConVar("ce_http_debug_requests", "0");

	return APLRes_Success;
}

public any Native_CreateAbsoluteBackendURL(Handle plugin, int numParams)
{
	char sBaseURL[256], sURL[256];
	GetNativeString(1, sBaseURL, sizeof(sBaseURL));

	int size = GetNativeCell(3);

	char sBaseEconomyURL[128];
	CEcon_GetBaseBackendURL(sBaseEconomyURL, sizeof(sBaseEconomyURL));

	// If we don't have :// in the URL that means this is
	// not the full URL. We add base domain name
	// in the beginning.
	if(StrContains(sBaseURL, "://") == -1)
	{
		if(sBaseURL[0] != '/')
		{
			// We need to make sure we have a slash before URL, so we
			// can form a proper link in the end.
			Format(sBaseURL, sizeof(sBaseURL), "/%s", sBaseURL);
		}
		strcopy(sURL, sizeof(sURL), sBaseEconomyURL);

		Format(sURL, sizeof(sURL), "%s%s", sURL, sBaseURL);
	} else {
		strcopy(sURL, sizeof(sURL), sBaseURL);
	}

	if(ce_http_debug_requests.BoolValue)
	{
		LogMessage("Generated URL: %s", sURL);
	}
	SetNativeString(2, sURL, size);
}

public any Native_CreateBaseHTTPRequest(Handle plugin, int numParams)
{
	char sBaseURL[256], sURL[256];
	GetNativeString(1, sBaseURL, sizeof(sBaseURL));
	HTTPMethod nMethod = GetNativeCell(2);

	CEconHTTP_CreateAbsoluteBackendURL(sBaseURL, sURL, sizeof(sURL));

	HTTPRequestHandle httpRequest = Steam_CreateHTTPRequest(nMethod, sURL);
	Steam_SetHTTPRequestHeaderValue(httpRequest, "Accept", "text/keyvalues");

	char sAccessHeader[256];
	CEcon_GetAccessKey(sAccessHeader, sizeof(sAccessHeader));

	Format(sAccessHeader, sizeof(sAccessHeader), "Provider %s", sAccessHeader);
	Steam_SetHTTPRequestHeaderValue(httpRequest, "Access", sAccessHeader);

	CEcon_GetAuthorizationKey(sAccessHeader, sizeof(sAccessHeader));
	Steam_SetHTTPRequestHeaderValue(httpRequest, "Authorization", sAccessHeader);


	return httpRequest;
}
