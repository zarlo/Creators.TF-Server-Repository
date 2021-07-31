//============= Copyright Amper Software, All rights reserved. ============//
//
// Purpose: Include file for plugins that use Creators.TF Custom Economy features.
//
//=========================================================================//

//======================================//
// Schema
//======================================//


// Returns KeyValues with economy schema.
native KeyValues CEcon_GetEconomySchema();
// Called when economy schema is updated.
forward void CEcon_OnSchemaUpdated(KeyValues hSchema);
// Called after economy was parsed, but not subplugins were not yet notified about it.
forward void CEcon_OnSchemaPreUpdate(KeyValues hSchema);

//======================================//
// Events
//======================================//


// Send an event to the client.
native void CEcon_SendEventToClient(int client, const char[] name, int add, int unique_id);
// Send an event to the client with random unique index.
native void CEcon_SendEventToClientUnique(int client, const char[] name, int add);
// Send an event to the client attached to a real game event.
native void CEcon_SendEventToClientFromGameEvent(int client, const char[] name, int add, Handle event);

// Send an event to all clients.
native void CEcon_SendEventToAll(const char[] name, int add, int unique_id);
// Returns weapon index client has last interacted with.
native int CEcon_GetLastUsedWeapon(int client);

// Puts economy access key in the buffer.
native bool CEcon_GetAccessKey(const char[] buffer, int size);
// Puts Authorization key in the buffer.
native bool CEcon_GetAuthorizationKey(const char[] buffer, int size);
// Puts base backend url link in the buffer.
native bool CEcon_GetBaseBackendURL(const char[] buffer, int size);

// Called when client receives a new event.
forward void CEcon_OnClientEvent(int client, const char[] name, int add, int unique_id);

public SharedPlugin __pl_cecon_core = 
{
    name = "cecon_core",
    file = "cecon_core.smx",
#if defined REQUIRE_PLUGIN
    required = 1,
#else
    required = 0,
#endif
};
