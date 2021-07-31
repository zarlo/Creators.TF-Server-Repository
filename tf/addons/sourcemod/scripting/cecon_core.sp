//============= Copyright Amper Software 2021, All rights reserved. ============//
//
// Purpose: Core plugin for Creators.TF Custom Economy plugin.
//
//=========================================================================//

// This gives us 64KB of heap space, from the default of 4KB.
// This should hopefully prevent "Not enough space on the heap" errors.
#pragma dynamic 65536

#include <steamtools>

#pragma semicolon 1
#pragma newdecls required
#pragma tabsize 0

#define MAX_ENTITY_LIMIT 2048

#include <cecon>
#include <cecon_http>
#include <tf2>
#include <sdkhooks>
#include <sdktools>
#include <tf2_stocks>
#include <tf2attributes>

#define DEFAULT_ECONOMY_BASE_URL "https://creators.tf"

public Plugin myinfo =
{
	name = "Creators.TF Core",
	author = "Creators.TF Team",
	description = "Core plugin for Creators.TF Custom Economy plugin.",
	version = "1.0.1",
	url = "https://creators.tf"
}

//-------------------------------------------------------------------
// Economy Credentials
//-------------------------------------------------------------------
char m_sBaseEconomyURL[64];		// Stores the base url that is used for api link generation.
char m_sEconomyAccessKey[150];	// Creators.TF Backend API key, associated with the provider.
char m_sBranchName[32];			// Schema branch name.
char m_sBranchPassword[64];		// Secret keyword, used to retrieve schema from the branch.
char m_sAuthorizationKey[129];	// Value to put into "Authorization" header, when making a request.
								// In case if remote backend is passworded.

// True if all credentials have loaded succesfully.
bool m_bCredentialsLoaded = false;


//-------------------------------------------------------------------
// Schema
//-------------------------------------------------------------------
ConVar 	ce_schema_autoupdate,	// If true, plugins will autoupdate the item schema on every map change.
		ce_schema_override_url;	// If set, url for the schema source will be overriden.

KeyValues m_Schema;				// Cached keyvalues handle of the schema, used for plugins that late load.

char m_sSchemaBuildVersion[64];	// Build version of the locally downloaded schema.
char m_sItemSchemaFilePath[96];	// File path to the items_config.cfg (Usually "addons/sourcemod/configs/items_config.cfg")

Handle 	g_CEcon_OnSchemaUpdated,	// Forward, that notifies the sub plugins, if the schema has changed.
		g_CEcon_OnSchemaPreUpdate;	// Forward, that notifies the sub plugins, that schema is about to be updated. This is used by plugins
									// that wish to override the schema somehow.


//-------------------------------------------------------------------
// Events
//-------------------------------------------------------------------
// When we generate a random event index, this value is used as the
// maximum value.
#define EVENT_UNIQUE_INDEX_MAX_INT 10000

// Fired when a new client even is fired.
Handle g_hOnClientEvent;

// We store last weapon that client has interacted with.
int m_iLastWeapon[MAXPLAYERS + 1];
bool m_bIsEventQueueProcessed = false;

ArrayList m_hEventsQueue;

ConVar 	ce_events_queue_debug,
		ce_events_log,
		ce_events_log_event_filter,
		ce_events_per_frame;

enum struct CEQueuedEvent
{
	int m_iUserID;
	char m_sEvent[128];
	int m_iAdd;
	int m_iUniqueID;
}




//-------------------------------------------------------------------
// Coordinator
//-------------------------------------------------------------------
// Stores all jobs indexes that we've already processed,
// and we need to mark as such on next coordiantor request.
char m_sSessionKey[16];
bool m_bCoordinatorActive = false;			// True if coordiantor is currently in process of making requests.
bool m_bIsBackendUnreachable = false;		// True if we can't reach backend for an extended period of time.

int m_iFailureCount = 0;					// Amount of failures that we have encountered in a row.

// Maximum amount of failures before we initiate a timeout.
#define COORDINATOR_MAX_FAILURES 5

// To prevent infinite spam to the backend,
// we timeout our requests if a certain amount of failures were made.
#define COORDINATOR_FAILURE_TIMEOUT 180.0

ConVar 	ce_coordinator_enabled,		// If true, coordinator will be online.
		ce_credentials_filename;	// Filename of the econome config.

ConVar  g_hostport;

//-------------------------------------------------------------------
// Purpose: Fired when plugin starts.
//-------------------------------------------------------------------
public void OnPluginStart()
{
	// ----------- COORD ------------ //

	// ConVars
	ce_coordinator_enabled = CreateConVar("ce_coordinator_enabled", "1", "If true, coordinator will be online.");
	ce_credentials_filename = CreateConVar("ce_credentials_filename", "economy.cfg", "Filename of the econome config.");
	ce_events_per_frame = CreateConVar("ce_events_per_frame", "2", "Don't process more than X events per a frame.");

	HookConVarChange(ce_coordinator_enabled, ce_coordinator_enabled__CHANGED);
	HookConVarChange(ce_credentials_filename, ce_credentials_filename__CHANGED);

	// Start long polling in 5 seconds. Why? I don't know yet.
	// TODO: THIS PROBABLY CAN BE REMOVED
	CreateTimer(5.0, Timer_InitialStartLongPolling);

	// ----------- SCHEMA ----------- //

	// Preload the schema file location path for later usage.
	BuildPath(Path_SM, m_sItemSchemaFilePath, sizeof(m_sItemSchemaFilePath), "configs/item_schema.cfg");
	// ConVars
	ce_schema_autoupdate = CreateConVar("ce_schema_autoupdate", "1", "Should auto-update item schema on every map change.");
	ce_schema_override_url = CreateConVar("ce_schema_override_url", "", "Overrides the remote source of the schema file.");

	// Commands
	RegServerCmd("ce_schema_update", cSchemaUpdate);
	RegServerCmd("ce_schema_reload", cSchemaReload);

	// ----------- EVENTS ----------- //

	g_hOnClientEvent = CreateGlobalForward("CEcon_OnClientEvent", ET_Ignore, Param_Cell, Param_String, Param_Cell, Param_Cell);
	RegAdminCmd("ce_events_test", cTestEvnt, ADMFLAG_ROOT, "Tests a CEcon event.");
	ce_events_queue_debug = CreateConVar("ce_events_queue_debug", "0");
	ce_events_log = CreateConVar("ce_events_log", "0");
	ce_events_log_event_filter = CreateConVar("ce_events_log_event_filter", "");

	// Hook all needed entities when plugin late loads.
	LateHooking();

	HookEvent("player_spawn", player_spawn);

	g_hostport = FindConVar("hostport");
	m_hEventsQueue = new ArrayList(sizeof(CEQueuedEvent));
}

//-------------------------------------------------------------------
// Purpose: Fired when map starts or changes. This is also fired after OnPluginStart if the plugin is manually loaded.
//-------------------------------------------------------------------
public void OnMapStart()
{
	if(Steam_IsConnected())
	{
		// Process economy precached schema.
		Schema_ProcessCachedItemSchema();
		// But we also try to see if there are any updates.
		Steam_OnReady();
	}
}

//-------------------------------------------------------------------
// Purpose: Native initialization.
//-------------------------------------------------------------------
public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	RegPluginLibrary("cecon_core");

	//------------------------------------------------
	// Core

	CreateNative("CEcon_GetAccessKey", Native_GetAccessKey);
	CreateNative("CEcon_GetBaseBackendURL", Native_GetBaseBackendURL);
	CreateNative("CEcon_GetAuthorizationKey", Native_GetAuthorizationKey);

	//------------------------------------------------
	// Schema

	g_CEcon_OnSchemaPreUpdate = CreateGlobalForward("CEcon_OnSchemaPreUpdate", ET_Ignore, Param_Cell);
	g_CEcon_OnSchemaUpdated = CreateGlobalForward("CEcon_OnSchemaUpdated", ET_Ignore, Param_Cell);
	CreateNative("CEcon_GetEconomySchema", Native_GetEconomySchema);

	//------------------------------------------------
	// Events

	CreateNative("CEcon_SendEventToClient", Native_SendEventToClient);
	CreateNative("CEcon_SendEventToClientUnique", Native_SendEventToClientUnique);
	CreateNative("CEcon_SendEventToClientFromGameEvent", Native_SendEventToClientFromGameEvent);
	CreateNative("CEcon_SendEventToAll", Native_SendEventToAll);
	CreateNative("CEcon_GetLastUsedWeapon", Native_LastUsedWeapon);

	return APLRes_Success;
}

//-------------------------------------------------------------------
// Purpose: Event callback for the spawn event
//-------------------------------------------------------------------
public Action player_spawn(Handle hEvent, const char[] szName, bool bDontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(hEvent, "userid"));
	SetClientLastWeapon(client, -1);

	return Plugin_Continue;
}

//-------------------------------------------------------------------
// Purpose: Fired when SteamTools is late loaded. TODO: Need to confirm if this is actually a late load or if it loads regardless.
//-------------------------------------------------------------------
public void Steam_FullyLoaded()
{
	Steam_OnReady();
}

//-------------------------------------------------------------------
// Purpose: This is fired on every plugin lifecycle
// when SteamTools is available.
//-------------------------------------------------------------------
public void Steam_OnReady()
{
	ReloadEconomyCredentials();
	Schema_CheckForUpdates(false);
}

public void ce_credentials_filename__CHANGED(ConVar cvar, char[] oldval, char[] newval)
{
	ReloadEconomyCredentials();
}

public void ce_coordinator_enabled__CHANGED(ConVar cvar, char[] oldval, char[] newval)
{
	SafeStartCoordinatorPolling();
}

//-------------------------------------------------------------------
// Purpose: Used to refresh economy credentials from economy.cfg
// file.
//-------------------------------------------------------------------
public void ReloadEconomyCredentials()
{
	// Before we reload everything, let's mark this flag as false
	// in case if something fails and this function is returned.
	m_bCredentialsLoaded = false;

	char sFileName[32];
	ce_credentials_filename.GetString(sFileName, sizeof(sFileName));

	// Format the economy.cfg location.
	char sLoc[96];
	BuildPath(Path_SM, sLoc, 96, "configs/%s", sFileName);

	if(!FileExists(sLoc))
	{
		SetFailState("Couldn't find economy credentials file. Expected: %s", sLoc);
		return;
	}

	// Create a new KeyValues to store the credentials in.
	KeyValues kv = new KeyValues("Economy");
	if (!kv.ImportFromFile(sLoc))
	{
		// This usually means that the KV format is incorrect in the file.
		SetFailState("Failed to import economy credentials into key values.");
		delete kv;
		return;
	}

	// Load everything from the file.
	kv.GetString("Key", m_sEconomyAccessKey, sizeof(m_sEconomyAccessKey));
	kv.GetString("Branch", m_sBranchName, sizeof(m_sBranchName));
	kv.GetString("Password", m_sBranchPassword, sizeof(m_sBranchPassword));
	kv.GetString("Domain", m_sBaseEconomyURL, sizeof(m_sBaseEconomyURL), DEFAULT_ECONOMY_BASE_URL);
	kv.GetString("Authorization", m_sAuthorizationKey, sizeof(m_sAuthorizationKey));

	// We don't need this handle anymore, remove it.
	delete kv;

	// Everything was succesful, mark it as true again.
	m_bCredentialsLoaded = true;
	LogMessage("Loaded economy backend credentials.");

	// Start coordinator request, if it's not started already.
	SafeStartCoordinatorPolling();
}

//-------------------------------------------------------------------
// Purpose: Returns true if client is a real player that
// is ready for backend interactions.
//-------------------------------------------------------------------
public bool IsClientReady(int client)
{
	if (!IsClientValid(client))return false;
	if (IsFakeClient(client))return false;
	return true;
}

//-------------------------------------------------------------------
// Purpose: Returns true if client exists.
//-------------------------------------------------------------------
public bool IsClientValid(int client)
{
	if (client <= 0 || client > MaxClients)return false;
	if (!IsClientInGame(client))return false;
	if (!IsClientAuthorized(client))return false;
	return true;
}

//-------------------------------------------------------------------
// Purpose: Finds client by their SteamID.
//-------------------------------------------------------------------
// Purpose: Used to refresh economy credentials from economy.cfg
// file.
//-------------------------------------------------------------------
//-------------------------------------------------------------------
public int FindTargetBySteamID(const char[] steamid)
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

//-------------------------------------------------------------------
// Purpose: Wrapper for IsValidEntity that also checks if entity
// index is between 0 and MAX_ENTITY_LIMIT.
//-------------------------------------------------------------------
public bool IsEntityValid(int entity)
{
	return entity > 0 && entity < MAX_ENTITY_LIMIT && IsValidEntity(entity);
}

//-------------------------------------------------------------------
// Native: CEcon_GetBaseBackendURL
//-------------------------------------------------------------------
public any Native_GetBaseBackendURL(Handle plugin, int numParams)
{
	int size = GetNativeCell(2);
	SetNativeString(1, m_sBaseEconomyURL, size);
}

//-------------------------------------------------------------------
// Native: CEcon_GetAccessKey
//-------------------------------------------------------------------
public any Native_GetAccessKey(Handle plugin, int numParams)
{
	int size = GetNativeCell(2);
	SetNativeString(1, m_sEconomyAccessKey, size);
}

//-------------------------------------------------------------------
// Native: CEcon_GetAuthorizationKey
//-------------------------------------------------------------------
public any Native_GetAuthorizationKey(Handle plugin, int numParams)
{
	int size = GetNativeCell(2);
	SetNativeString(1, m_sAuthorizationKey, size);
}

//============= Copyright Amper Software, All rights reserved. ============//
//
// Purpose: Creates the connection between website and servers. Allows two-way
// messaging between servers and website using long-polling technique.
//
//=========================================================================//


//===============================//
// DOCUMENTATION

/* HOW DOES COORDINATOR WORK?
*
*	Coordinator is a module that is made to provide two-way communuication
*	brigde between servers and backend. For requests directed from servers
*	to website, we simply use HTTP requests to API.
*
*	For requests fron website to server we can't use direct HTTP requests,
*	so we need to do some trickery here. We're using Long-Polling technique
*	that allows us to send events from backend to game server in real time.
*
*	If you want to learn more about how Long-Polling works, google it. But
*	in short: When coordinator is initialized, we send a request to backend
*	which, unlike all other typical requests, is kept open for an extended
*	period of time. If something happens on the backend, that we need to
*	alert this plugin about, backend responds with event's content and closes
*	connection in this request. Plugin reads contents of the event, does
*	whatever it needs with it, opens another similar request and loop goes on.
*
*/
//===============================//

//-------------------------------------------------------------------
// Purpose: Timer that reenables coordinator queue if it's offline,
// but it should be online.
//-------------------------------------------------------------------
public Action Timer_InitialStartLongPolling(Handle timer, any data)
{
	SafeStartCoordinatorPolling();
}

//-------------------------------------------------------------------
// Purpose: Used to start coordinator request, but it only does
// that if there are no active requests right now.
//-------------------------------------------------------------------
public void SafeStartCoordinatorPolling()
{
	if (m_bCoordinatorActive)return;

	StartCoordinatorLongPolling();
}

//-------------------------------------------------------------------
// Purpose: Used to force start a coordinator request.
//-------------------------------------------------------------------
public void StartCoordinatorLongPolling()
{
	// Before we make anoher request, let's make sure that nothing tells us
	// not to. Before we are sure that nothing stops us from making a request, let's
	// set this flag to false.

	m_bCoordinatorActive = false;

	// If there are any conditons that tell us not to make a request, we return this function.
	// m_bCoordinatorActive will be false at this point, and this will mean that plugin stopped
	// making requests in queue. And it will not do any until this function is called again
	// and all these conditions are met.

	// If we decided not to have coordiantor feature, don't do it.
	if (!ce_coordinator_enabled.BoolValue)
	{
		LogMessage("ce_coordinator_enabled is disabled therefore we won't start economy.");
		return;
	}

	// If we failed to read economy credentials (Backend Domain, API Key, etc..).
	if (!m_bCredentialsLoaded)
	{
		SetFailState("Economy credentials was not loaded for some reason, therefore economy cannot start.");
		return;
	}

	// All conditions were met, mark this flag as true and start the request.
	m_bCoordinatorActive = true;

	char sURL[64];
	Format(sURL, sizeof(sURL), "%s/api/coordinator", m_sBaseEconomyURL);

	// Getting Server IP
	int iIPVals[4];
	Steam_GetPublicIP(iIPVals);
	char sIP[64];
	Format(sIP, sizeof(sIP), "%d.%d.%d.%d", iIPVals[0], iIPVals[1], iIPVals[2], iIPVals[3]);
	//Format(sIP, sizeof(sIP), "%d.%d.%d.%d", 192, 168, 100, 68);
	int iPort = g_hostport.IntValue;

	HTTPRequestHandle httpRequest = Steam_CreateHTTPRequest(HTTPMethod_GET, sURL);
	Steam_SetHTTPRequestNetworkActivityTimeout(httpRequest, 40);
	Steam_SetHTTPRequestGetOrPostParameter(httpRequest, "session_id", m_sSessionKey);
	Steam_SetHTTPRequestGetOrPostParameter(httpRequest, "squash_arguments", "1");
	Steam_SetHTTPRequestHeaderValue(httpRequest, "Accept", "text/keyvalues");
	Steam_SetHTTPRequestHeaderValue(httpRequest, "Authorization", m_sAuthorizationKey);

	char sSteamID[64], sKey[24];

	// Let's provide some data for this request.
	int iPlayerCount = 0;
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientReady(i))continue;
		GetClientAuthId(i, AuthId_SteamID64, sSteamID, sizeof(sSteamID));

		Format(sKey, sizeof(sKey), "steamids[%d]", iPlayerCount);
		Steam_SetHTTPRequestGetOrPostParameter(httpRequest, sKey, sSteamID);
		iPlayerCount++;
	}

	// Access Header
	char sHeader[256];

	Format(sHeader, sizeof(sHeader), "Provider %s (Address \"%s:%d\")", m_sEconomyAccessKey, sIP, iPort);
	Steam_SetHTTPRequestHeaderValue(httpRequest, "Access", sHeader);

	Steam_SendHTTPRequest(httpRequest, Coordinator_Request_Callback);
}

//-------------------------------------------------------------------
// Purpose: Callback to the coordinator request.
//-------------------------------------------------------------------
public void Coordinator_Request_Callback(HTTPRequestHandle request, bool success, HTTPStatusCode code)
{
	m_bCoordinatorActive = false;
	bool bError = true;

	// If response was succesful...
	if (success)
	{
		// And response code is 200...
		if (code == HTTPStatusCode_OK)
		{
			// Let's try to process the request response.
			// --------------------------------------------- //
			// NOTE: Notice that it may still return an error, if for some reason response
			// body is in invalid format (i.e. not KeyValues).
			// --------------------------------------------- //
			// NOTE: Also keep in mind that long-polling timeout is not considered to be an error.
			// If response content is "TIMEOUT", that means that backend has decided to close
			// the connection. We do not consider that as an error and just make another request
			// right away.

			// CoordinatorProcessRequestContent() will only return true if the response was not in Keyvalues or the ImportFromString failed.
			bError = CoordinatorProcessRequestContent(request);
		}
	}

	// If we ended up with an error, that means that something went wrong.
	// Let's try a few more times (defined in COORDINATOR_MAX_FAILURES) and then
	// make a timeout for COORDINATOR_FAILURE_TIMEOUT seconds.
	if (bError)
	{

		// We increase this variable if an error happened.
		m_iFailureCount++;

		// If this variable reached the limit, we make a timeout.
		if (m_iFailureCount >= COORDINATOR_MAX_FAILURES)
		{
			if (!m_bIsBackendUnreachable)
			{
				// If last time backend was reachable, mark it as unreachable
				// and throw a message in chat to notify everyone about downtime.
				m_bIsBackendUnreachable = true;
				CoordinatorOnBackendUnreachable();
			}

			// Throw a message in console.
			LogError("Connection to backend failed after %d retries. Making another attempts in %f seconds", COORDINATOR_MAX_FAILURES, COORDINATOR_FAILURE_TIMEOUT);
			// Reset the variable so that we start with zero upon next request.
			m_iFailureCount = 0;

			// Create a delay with timer.
			CreateTimer(COORDINATOR_FAILURE_TIMEOUT, Timer_DelayedCoordinatorRequest);
			return;

		} else {

			// If we didn't reach the timeout limit yet, wait for a minute and
			// try to make another attempt.
			LogError("Connection to backend failed. Count: %d. Error code: %d. Retrying...", m_iFailureCount, code);
			CreateTimer(60.0, Timer_DelayedCoordinatorRequest);
		}
	} else {

		// If there was no error, and last time backend was marked as unreachable,
		// that means we've connected to it again.
		// Send a message in chat to notify everyone that economy is up again.
		if (m_bIsBackendUnreachable)
		{
			m_bIsBackendUnreachable = false;
			CoordinatorOnBackendReachable();
		}

		// If everything was succesfully, make another request in the next frame.
		RequestFrame(RF_DelayerCoordinatorRequest);
	}
}

//-------------------------------------------------------------------
// Purpose: Fired when backend is marked as unreachable.
//-------------------------------------------------------------------
public void CoordinatorOnBackendUnreachable()
{
	// TODO: Make a forward.
	//PrintToChatAll("\x01Creators.TF Item Servers are \x03down.");
	LogMessage("[WARNING] Creators.TF Item Servers are down.");
}

//-------------------------------------------------------------------
// Purpose: Fired when backend is back available.
//-------------------------------------------------------------------
public void CoordinatorOnBackendReachable()
{
	// TODO: Make a forward.
	//PrintToChatAll("\x01Creators.TF Item Servers are \x03up.");
	LogMessage("[WARNING] Creators.TF Item Servers are up.");
}

//-------------------------------------------------------------------
// Purpose: Used to start a coordiantor request with a
// delay using RequestFrame.
//-------------------------------------------------------------------
public void RF_DelayerCoordinatorRequest(any data)
{
	StartCoordinatorLongPolling();
}

//-------------------------------------------------------------------
// Used to start a coordiantor request with a delay using CreateTimer.
//-------------------------------------------------------------------
public Action Timer_DelayedCoordinatorRequest(Handle timer, any data)
{
	SafeStartCoordinatorPolling();
}

//-------------------------------------------------------------------
// Processes response of the coordinator request. Returns true if
// there are any errors.
//-------------------------------------------------------------------
public bool CoordinatorProcessRequestContent(HTTPRequestHandle request)
{
	// Getting response content length.
	int size = Steam_GetHTTPResponseBodySize(request);
	if (size < 0)return true;
	char[] content = new char[size + 1];

	// Getting actual response content body.
	Steam_GetHTTPResponseBodyData(request, content, size);
	Steam_ReleaseHTTPRequest(request);

	// If response content is "TIMEOUT", that means that backend has decided to close
	// the connection. We do not count that as an error, but we still return, because
	// there is nothing to parse.
	if (StrEqual(content, "TIMEOUT"))return false;

	// We can't really check if content in response is in KeyValues or not,
	// but what we can do is check if it starts with a quote mark. KV1 (which is
	// the format, that backend gives us a response in) always has this symbol
	// in the beginning.
	if (content[0] != '"')return true;

	// Do I have to explain you what this is?
	KeyValues kv = new KeyValues("Response");

	// KeyValues.ImportFromString() returns false if it failed to process string into a KV handle.
	// If this happens we return true because some error has occured.
	if (!kv.ImportFromString(content))
	{
		LogError("The response was not able to be read in Keyvalue Format.");
		return true;
	}

	char sSessionKey[16];
	kv.GetString("session_id", sSessionKey, sizeof(sSessionKey));
	if(!StrEqual(sSessionKey, ""))
	{
		strcopy(m_sSessionKey, sizeof(m_sSessionKey), sSessionKey);
		return false;
	}

	// Assuming that at this point KV handle is valid. Processing it.
	if(kv.JumpToKey("jobs", false))
	{
		if(kv.GotoFirstSubKey(false))
		{
			do {
				// Getting the actual job command that we need to excetute. And execute it.
				char sCommand[256];
				kv.GetString(NULL_STRING, sCommand, sizeof(sCommand));

				PrintToServer(sCommand);
				ServerCommand(sCommand);

			} while (kv.GotoNextKey(false));

			kv.GoBack();
		}
		kv.GoBack();
	}

	// Deleting this handle as we don't need it anymore.
	delete kv;

	// Return false as there were no errors in this execution.
	return false;
}

//============= Copyright Amper Software, All rights reserved. ============//
//
// Purpose: Manages Economy Schema auto-update.
//
//=========================================================================//

//-------------------------------------------------------------------
// Purpose: Command callback to check for schema updates.
//-------------------------------------------------------------------
public Action cSchemaUpdate(int args)
{
	Schema_CheckForUpdates(true);
	return Plugin_Handled;
}
//-------------------------------------------------------------------
// Purpose: Command callback to manually reload item schema.
//-------------------------------------------------------------------
public Action cSchemaReload(int args)
{
	Schema_ProcessCachedItemSchema();
	return Plugin_Handled;
}

//-------------------------------------------------------------------
// Purpose: Processes cached item schema and notifies plugins about
// it being updated.
//-------------------------------------------------------------------
public void Schema_ProcessCachedItemSchema()
{
	KeyValues kv = new KeyValues("Schema");
	if (!kv.ImportFromFile(m_sItemSchemaFilePath))return;

	// Print build version in chat.
	kv.GetString("Version/build", m_sSchemaBuildVersion, sizeof(m_sSchemaBuildVersion), "");
	LogMessage("Current Item Schema version: %s", m_sSchemaBuildVersion);

	// Make a forward call to notify other plugins prior to the change.
	Call_StartForward(g_CEcon_OnSchemaPreUpdate);
	Call_PushCell(kv);
	Call_Finish();

	// Make a forward call to notify other plugins about the change.
	Call_StartForward(g_CEcon_OnSchemaUpdated);
	Call_PushCell(kv);
	Call_Finish();

	// Clearing old schema if exists.
	delete m_Schema;
	m_Schema = kv;
}

//-------------------------------------------------------------------
// Purpose: Used to make a backend request to check for updates.
//-------------------------------------------------------------------
public void Schema_CheckForUpdates(bool bIsForced)
{
	// If we're not forcing autoupdate.
	if(!bIsForced)
	{
		// And autoupdate is not enabled...
		if (!ce_schema_autoupdate.BoolValue)
		{
			// Dont do anything.
			return;
		}
	}

	LogMessage("Checking for Item Schema updates...");

	char sURL[256], sOverrideURL[256];
	ce_schema_override_url.GetString(sOverrideURL, sizeof(sOverrideURL));

	if(StrEqual(sOverrideURL, ""))
	{
		// Otherwise use base url.
		Format(sURL, sizeof(sURL), "%s/api/IEconomyItems/GScheme", m_sBaseEconomyURL);
 	} else {
		// If we set to override the schema url, use value from the cvar.
		strcopy(sURL, sizeof(sURL), sOverrideURL);
	}

	LogMessage(sURL);

	HTTPRequestHandle httpRequest = Steam_CreateHTTPRequest(HTTPMethod_GET, sURL);
	Steam_SetHTTPRequestGetOrPostParameter(httpRequest, "field", "Version");
	Steam_SetHTTPRequestNetworkActivityTimeout(httpRequest, 10);
	Steam_SetHTTPRequestHeaderValue(httpRequest, "Accept", "text/keyvalues");
	Steam_SetHTTPRequestHeaderValue(httpRequest, "Authorization", m_sAuthorizationKey);

	char sAccessHeader[256];
	Format(sAccessHeader, sizeof(sAccessHeader), "Provider %s", m_sEconomyAccessKey);
	Steam_SetHTTPRequestHeaderValue(httpRequest, "Access", sAccessHeader);

	Steam_SendHTTPRequest(httpRequest, Schema_CheckForUpdates_Callback);
}

//-------------------------------------------------------------------
// Purpose: Check for updates request callback.
//-------------------------------------------------------------------
public void Schema_CheckForUpdates_Callback(HTTPRequestHandle request, bool success, HTTPStatusCode code)
{
	// If request is succesful...
	if (success)
	{
		// And response code is 200...
		if (code == HTTPStatusCode_OK)
		{
			// Getting response content length.
			int size = Steam_GetHTTPResponseBodySize(request);

			if(size > 500)
			{
				// If for check for updates we received more than 500 bytes of data
				// request was probably made to a different file. Which does not allow us to
				// check for version name, because of the memory heap overflow.
				//
				// If we're in debug mode, update the schema anyway. Otherwise, don't.

				LogMessage("Version name check failed, assumming that we have a new version. Updating the schema...");

				Schema_ForceUpdate();
				return;
			}

			char[] content = new char[size + 1];

			// Getting actual response content body.
			Steam_GetHTTPResponseBodyData(request, content, size);
			Steam_ReleaseHTTPRequest(request);

			// We can't really check if content in response is in KeyValues or not,
			// but what we can do is check if it starts with a quote mark. KV1 (which is
			// the format, that backend gives us a response in) always has this symbol
			// in the beginning.
			if (content[0] != '"')return;

			KeyValues kv = new KeyValues("Response");

			// KeyValues.ImportFromString() returns false if it failed to process string into a KV handle.
			// If this happens we return because some error has occured.
			if (!kv.ImportFromString(content))return;

			// Assuming that at this point KV handle is valid. Processing it.
			char sNewBuild[64];
			kv.GetString("build", sNewBuild, sizeof(sNewBuild));

			if(StrEqual(m_sSchemaBuildVersion, sNewBuild))
			{
				LogMessage("No new updates found.");
			} else {
				LogMessage("A new version detected. Updating...");
				Schema_ForceUpdate();
			}

			delete kv;
			return;
		}
	}

	return;
}

//-------------------------------------------------------------------
// Purpose: Used to make a backend request to force update the
// schema.
//-------------------------------------------------------------------
public void Schema_ForceUpdate()
{
	char sURL[256], sOverrideURL[256];
	ce_schema_override_url.GetString(sOverrideURL, sizeof(sOverrideURL));

	if(StrEqual(sOverrideURL, ""))
	{
		// Otherwise use base url.
		Format(sURL, sizeof(sURL), "%s/api/IEconomyItems/GScheme", m_sBaseEconomyURL);
	} else {
		// If we set to override the schema url, use value from the cvar.
		strcopy(sURL, sizeof(sURL), sOverrideURL);
	}

	HTTPRequestHandle httpRequest = Steam_CreateHTTPRequest(HTTPMethod_GET, sURL);
	Steam_SetHTTPRequestNetworkActivityTimeout(httpRequest, 10);
	Steam_SetHTTPRequestHeaderValue(httpRequest, "Accept", "text/keyvalues");

	Steam_SetHTTPRequestHeaderValue(httpRequest, "Authorization", m_sAuthorizationKey);

	char sAccessHeader[256];
	Format(sAccessHeader, sizeof(sAccessHeader), "Provider %s", m_sEconomyAccessKey);
	Steam_SetHTTPRequestHeaderValue(httpRequest, "Access", sAccessHeader);

	Steam_SendHTTPRequest(httpRequest, Schema_ForceUpdate_Callback);
}

//-------------------------------------------------------------------
// Purpose: Force update request callback.
//-------------------------------------------------------------------
public void Schema_ForceUpdate_Callback(HTTPRequestHandle request, bool success, HTTPStatusCode code)
{
	// If request is succesful...
	if (success)
	{
		// And response code is 200...
		if (code == HTTPStatusCode_OK)
		{
			Steam_WriteHTTPResponseBody(request, m_sItemSchemaFilePath);
			Schema_ProcessCachedItemSchema();
		}
	}

	return;
}

//-------------------------------------------------------------------
// Native: CEcon_GetEconomySchema
//-------------------------------------------------------------------
public any Native_GetEconomySchema(Handle plugin, int numParams)
{
	return m_Schema;
}

//-------------------------------------------------------------------
// Purpose: Fired when something touches an entity.
//-------------------------------------------------------------------
public Action OnTouch(int entity, int toucher)
{
	// This is only hooked with healthkits right now.
	// Health hit is considered to be a sandvich if it has an owner.

	if (!IsClientValid(toucher))return Plugin_Continue;

	// See if we have an owner.
	int hOwner = GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity");
	// Don't do anything if our owner touched us.
	if (hOwner == toucher)return Plugin_Continue;

	// If someone else touched a sandvich, mark heavy's secondary weapon as last used.
	if(IsClientValid(hOwner))
	{
		// Only do this if owner class is heavy.
		if(TF2_GetPlayerClass(hOwner) == TFClass_Heavy)
		{
			int iLunchBox = GetPlayerWeaponSlot(hOwner, 1);
			if(IsValidEntity(iLunchBox))
			{
				SetClientLastWeapon(hOwner, iLunchBox);
			}
		}
	}

	return Plugin_Continue;
}

//-------------------------------------------------------------------
// Purpose: Fired when something deals damage to an entity.
//-------------------------------------------------------------------
public Action OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &weapon, float damageForce[3], float damagePosition[3])
{
	if(IsClientValid(attacker))
	{
		if(IsValidEntity(inflictor))
		{
			// If inflictor entity has a "m_hBuilder" prop, that means we've killed with a building.
			// Setting our wrench as last weapon.
			if(HasEntProp(inflictor, Prop_Send, "m_hBuilder"))
			{
				if(TF2_GetPlayerClass(attacker) == TFClass_Engineer)
				{
					int iWrench = GetPlayerWeaponSlot(attacker, 2);
					if(IsValidEntity(iWrench))
					{
						SetClientLastWeapon(attacker, iWrench);
					}
				}
			} else {
				// Player killed someone with a hitscan weapon. Saving the one.
				SetClientLastWeapon(attacker, weapon);
			}
		}
	}
}

//-------------------------------------------------------------------
// Purpose: Command callback to test an event on a client.
//-------------------------------------------------------------------
public Action cTestEvnt(int client, int args)
{
	if(IsClientValid(client))
	{
		char sArg1[128], sArg2[11];
		GetCmdArg(1, sArg1, sizeof(sArg1));
		GetCmdArg(2, sArg2, sizeof(sArg2));

		CEcon_SendEventToClientUnique(client, sArg1, MAX(StringToInt(sArg2), 1));
	}

	return Plugin_Handled;
}

//-------------------------------------------------------------------
// Purpose: Late hook specific entities.
//-------------------------------------------------------------------
public void LateHooking()
{
	// Hook objects (Buildings) with OnTakeDamage SDKHook
	int ent = -1;
	while ((ent = FindEntityByClassname(ent, "obj_*")) != -1)
	{
		SDKHook(ent, SDKHook_OnTakeDamage, OnTakeDamage);
	}

	// Hook players with OnTouch SDKHook
	ent = -1;
	while ((ent = FindEntityByClassname(ent, "item_healthkit_*")) != -1)
	{
		SDKHook(ent, SDKHook_Touch, OnTouch);
	}

	// Hook Tanks with OnTakeDamage SDKHook
	ent = -1;
	while ((ent = FindEntityByClassname(ent, "tank_boss")) != -1)
	{
		SDKHook(ent, SDKHook_Touch, OnTakeDamage);
	}

	for (int i = 1; i <= MaxClients; i++)
	{
		if(IsClientValid(i))
		{
			SDKHook(i, SDKHook_OnTakeDamage, OnTakeDamage);
			SDKHook(i, SDKHook_WeaponSwitchPost, OnWeaponSwitch);
		}
	}
}

//-------------------------------------------------------------------
// Purpose: Fired when a new entity is created.
//-------------------------------------------------------------------
public void OnEntityCreated(int entity, const char[] classname)
{
	// Hook objects (Buildings) with OnTakeDamage SDKHook
	if(StrContains(classname, "obj_") != -1)
	{
		SDKHook(entity, SDKHook_OnTakeDamage, OnTakeDamage);
	}

	// Hook Tanks with OnTakeDamage SDKHook
	if(StrContains(classname, "tank_boss") != -1)
	{
		SDKHook(entity, SDKHook_OnTakeDamage, OnTakeDamage);
	}

	// Hook players with OnTouch SDKHook
	if(StrContains(classname, "item_healthkit") != -1)
	{
		SDKHook(entity, SDKHook_Touch, OnTouch);
	}
}

public void OnClientPutInServer(int client)
{
	SDKHook(client, SDKHook_WeaponSwitchPost, OnWeaponSwitch);
	SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
}

public void OnWeaponSwitch(int client, int weapon)
{
	// Validate that we have really switched to this weapon.
	// This fixes cases when some weapon become invisible.
	int iActiveWeapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
	if (iActiveWeapon != weapon)return;

	SetClientLastWeapon(client, weapon);
}

public void SetClientLastWeapon(int client, int weapon)
{
	if (m_iLastWeapon[client] == weapon)return;

	/*
	if(weapon > 0)
	{
		char sName[32];
		GetEntityNetClass(weapon, sName, sizeof(sName));
		PrintToChatAll("m_iLastWeapon => %s", sName);
	}
	*/
	m_iLastWeapon[client] = weapon;
}

//-------------------------------------------------------------------
// Native: CEcon_GetLastUsedWeapon
//-------------------------------------------------------------------
public any Native_LastUsedWeapon(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);

	int iWeapon = m_iLastWeapon[client];

	if (iWeapon <= 0)return -1;
	if (!IsValidEntity(iWeapon))return -1;
	if (!HasEntProp(iWeapon, Prop_Send, "m_iItemDefinitionIndex"))return -1;

	return iWeapon;
}

//-------------------------------------------------------------------
// Native: CEcon_SendEventToClientFromGameEvent
//-------------------------------------------------------------------
public any Native_SendEventToClientFromGameEvent(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);

	char event[128];
	GetNativeString(2, event, sizeof(event));

	int add = GetNativeCell(3);
	int unique_id = GetNativeCell(4);

	CEcon_SendEventToClient(client, event, add, unique_id);
}

//-------------------------------------------------------------------
// Native: CEcon_SendEventToClientUnique
//-------------------------------------------------------------------
public any Native_SendEventToClientUnique(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);

	char event[128];
	GetNativeString(2, event, sizeof(event));

	int add = GetNativeCell(3);
	int unique_id = GetRandomInt(0, EVENT_UNIQUE_INDEX_MAX_INT);

	CEcon_SendEventToClient(client, event, add, unique_id);
}

#define TF_TEAM_UNASSIGNED 0
#define TF_TEAM_SPECTATOR 1
#define TF_TEAM_RED 2
#define TF_TEAM_BLUE 3

//-------------------------------------------------------------------
// Native: CEcon_SendEventToAll
//-------------------------------------------------------------------
public any Native_SendEventToAll(Handle plugin, int numParams)
{
	char event[128];
	GetNativeString(1, event, sizeof(event));

	int add = GetNativeCell(2);
	int unique_id = GetNativeCell(3);

	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientValid(i))continue;
		if (GetClientTeam(i) < TF_TEAM_RED)continue;

		CEcon_SendEventToClient(i, event, add, unique_id);
	}
}

//-------------------------------------------------------------------
// Native: CEcon_SendEventToClient
//-------------------------------------------------------------------
public any Native_SendEventToClient(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	if (!IsClientValid(client))return;

	// If we are playing MvM, we shouldn't be processing events for bots.
	if (GameRules_GetProp("m_bPlayingMannVsMachine") != 0)
	{
		if (IsFakeClient(client))
		{
			return;
		}
	}

	// TODO: Could we also add a check to prevent spectators from receiving any events? Or possibly pass through a
	// default argument that prevents spectators from receiving events by default but it can be toggled?
	// Food for thought. - ZoNiCaL.

	// APPENDIX - I'm currently disabling all spectators from receiving events here,
	// but I want it to become some sort of optional argument in the native later.
	if (GetClientTeam(client) < TF_TEAM_RED) return;

	char event[128];
	GetNativeString(2, event, sizeof(event));

	int add = GetNativeCell(3);
	int unique_id = GetNativeCell(4);

	if(ce_events_log.BoolValue)
	{
		bool bSendMessage = true;
		char szEventString[128];
		GetConVarString(ce_events_log_event_filter, szEventString, sizeof(szEventString));

		if (!StrEqual(szEventString, ""))
		{
			if (StrContains(event, szEventString, false) != -1)
			{
				bSendMessage = true;
			}
			else
			{
				bSendMessage = false;
			}

		}

		if (bSendMessage)
		{
			LogMessage("%s (client \"%N\") (add %d) (unique_id)", event, client, add, unique_id);
		}

	}

	// We only start new queue, if we are sure nothing is currently being proccessed.
	bool bShouldStartQueue = m_hEventsQueue.Length == 0;

	// Create a new struct and push it to the queue.
	CEQueuedEvent xEvent;
	xEvent.m_iUserID = GetClientUserId(client);
	strcopy(xEvent.m_sEvent, sizeof(xEvent.m_sEvent), event);
	xEvent.m_iAdd = add;
	xEvent.m_iUniqueID = unique_id;

	m_hEventsQueue.PushArray(xEvent);

	// Start the queue next frame.
	if(bShouldStartQueue)
	{
		RequestFrame(RF_StartEventsProcessQueue);
	}
}

public void StartEventsProcessQueue()
{
	// We already have a working queue processor.
	if (m_bIsEventQueueProcessed)return;

	// If we don't, make this as the one.
	m_bIsEventQueueProcessed = true;

	if(ce_events_queue_debug.BoolValue) LogMessage("Queue started...");
	ProcessNextEventsChunk();
}

public void ProcessNextEventsChunk()
{
	if(ce_events_queue_debug.BoolValue) LogMessage("%d events left.", m_hEventsQueue.Length);
	// We only process this amount of events per a frame.
	for (int i = 0; i < ce_events_per_frame.IntValue; i++)
	{
		// We exceeded the queue, there's nothing there anymore.
		if (m_hEventsQueue.Length < 1)break;

		// Get first element in the queue.
		CEQueuedEvent xEvent;
		m_hEventsQueue.GetArray(0, xEvent);

		// And remove it.
		m_hEventsQueue.Erase(0);

		int client = GetClientOfUserId(xEvent.m_iUserID);

		// This client doesn't exist anymore, skip this event.
		if (!IsClientValid(client))continue;

		// Log the event execution.
		if(ce_events_queue_debug.BoolValue)
		{
			LogMessage("%s (client \"%N\") (add %d) (unique_id %d)", xEvent.m_sEvent, client, xEvent.m_iAdd, xEvent.m_iUniqueID);
		}

		// Send it to plugins.
		Call_StartForward(g_hOnClientEvent);
		Call_PushCell(client);
		Call_PushString(xEvent.m_sEvent);
		Call_PushCell(xEvent.m_iAdd);
		Call_PushCell(xEvent.m_iUniqueID);
		Call_Finish();
	}

	// If there are any more events to process, wait till another frame.
	if(m_hEventsQueue.Length > 0)
	{
		if(ce_events_queue_debug.BoolValue) LogMessage("Waiting until next frame...");
		RequestFrame(RF_ProcessNextEventChunk);
	} else {

		// We're done.
		m_bIsEventQueueProcessed = false;
		if(ce_events_queue_debug.BoolValue) LogMessage("Queue ended.");
	}
}

public void RF_ProcessNextEventChunk(any data)
{
	ProcessNextEventsChunk();
}

public void RF_StartEventsProcessQueue(any data)
{
	StartEventsProcessQueue();
}

//-------------------------------------------------------------------
// Purpose: Returns maximum of two.
//-------------------------------------------------------------------
public int MAX(int iNum1, int iNum2)
{
	if (iNum1 > iNum2)return iNum1;
	if (iNum2 > iNum1)return iNum2;
	return iNum1;
}

//-------------------------------------------------------------------
// Purpose: Returns minimum of two.
//-------------------------------------------------------------------
public int MIN(int iNum1, int iNum2)
{
	if (iNum1 < iNum2)return iNum1;
	if (iNum2 < iNum1)return iNum2;
	return iNum1;
}
