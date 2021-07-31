//============= Copyright Amper Software, All rights reserved. ============//
//
// Purpose: SteamTools HTTP wrapper, that eases the process of making
// requests to the backend.
//
//=========================================================================//


// Creates a full absolute url to the backend.
native void 				CEconHTTP_CreateAbsoluteBackendURL(const char[] url, char[] buffer, int size);
native HTTPRequestHandle 	CEconHTTP_CreateBaseHTTPRequest(const char[] url, HTTPMethod method);


public SharedPlugin __pl_cecon_http = 
{
    name = "cecon_http",
    file = "cecon_http.smx",
#if defined REQUIRE_PLUGIN
    required = 1,
#else
    required = 0,
#endif
};