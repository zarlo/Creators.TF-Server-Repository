#pragma semicolon 1

#include <sourcemod>
#include <clientprefs>
#include <regex>
#include <sourcebanspp>

#pragma newdecls required

public Plugin myinfo =
{
	name			= "Name Killer",
	author			= "Nanochip",
	description		= "Handles users who have slurs in their name.",
	version			= "1.0.0",
	url				= "https://steamcommunity.com/id/xNanochip"
};

Cookie g_Cookie;
bool g_bWarned[MAXPLAYERS+1];

Regex g_rNslur;
Regex g_rFslur;
Regex g_rTslur;
Regex g_rCslur;
Regex g_rNazi;

public void OnPluginStart()
{
	//the cookie that will see if the user has already been warned for their name
	g_Cookie = new Cookie("namekiller_cookie", "", CookieAccess_Protected);
	
	//setup regex
	g_rNslur  = new Regex("[n|ñ]+[i!\\|1l]+[gq]{2,}.*r+",							PCRE_CASELESS | PCRE_MULTILINE | PCRE_UTF8);
	g_rFslur  = new Regex("f+[a@4]+[gq]+(\b|[o0a]+t+)",								PCRE_CASELESS | PCRE_MULTILINE | PCRE_UTF8);
	g_rTslur  = new Regex("(tr[ao0]{2,}n)|t+r+[a4@]n+([il1][e3]+|y+|[e3]r+)s?",		PCRE_CASELESS | PCRE_MULTILINE | PCRE_UTF8);
	g_rCslur  = new Regex("\\bc[o0]{2}ns?\\b",										PCRE_CASELESS | PCRE_MULTILINE | PCRE_UTF8);
	g_rNazi   = new Regex("(ᛋᛋ|waffen|1488|卐|卍|white pride|kekistan)",				PCRE_CASELESS | PCRE_MULTILINE | PCRE_UTF8);
	
	HookEvent("player_changename", player_changename);
	
	//late load
	for (int i = 1; i <= MaxClients; i++)
	{
		g_bWarned[i] = false;
		if (AreClientCookiesCached(i)) OnClientCookiesCached(i);
	}
}

public void OnClientConnected(int client)
{
	g_bWarned[client] = false;
}

public void OnClientCookiesCached(int client)
{
	char value[16];
	g_Cookie.Get(client, value, sizeof value);
	if (StrEqual(value, "true")) g_bWarned[client] = true;
}

public void OnClientPostAdminCheck(int client)
{
	if (!IsFakeClient(client))
	{
		char name[MAX_NAME_LENGTH];
		GetClientName(client, name, sizeof name);
		CheckName(client, name);
	}
}

public void player_changename(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	
	char currentName[MAX_NAME_LENGTH], newName[MAX_NAME_LENGTH];
	event.GetString("oldname", currentName, sizeof(currentName));
	event.GetString("newname", newName, sizeof(newName));
	
	// check to make sure oldname doesn't equal newname.
	if (!StrEqual(currentName, newName))
	{
		CheckName(client, newName);
	}
}

void CheckName(int client, const char[] name)
{
	char slur[32];
	int captures = 0;
	
	if ((captures = g_rNslur.Match(name)) > 0)					g_rNslur.GetSubString(0, slur, sizeof slur);
	if (captures == 0 && (captures = g_rFslur.Match(name)) > 0)	g_rFslur.GetSubString(0, slur, sizeof slur);
	if (captures == 0 && (captures = g_rTslur.Match(name)) > 0)	g_rTslur.GetSubString(0, slur, sizeof slur);
	if (captures == 0 && (captures = g_rCslur.Match(name)) > 0)	g_rCslur.GetSubString(0, slur, sizeof slur);
	if (captures == 0 && (captures = g_rNazi.Match(name)) > 0)	g_rNazi.GetSubString(0, slur, sizeof slur);
	if (captures > 0)
	{
    	if (!g_bWarned[client])
		{
    		g_Cookie.Set(client, "true");
    		g_bWarned[client] = true; // this shouldn't be needed since the client is being kicked in the next game frame, but it's for my sanity.
    		KickClient(client, "Remove \"%s\" from your name. This is your only warning", slur);
		}
		else
		{
			char reason[256];
			Format(reason, sizeof reason, "Autobanned for user's name, found: %s", slur);
			SBPP_BanPlayer(0, client, 20160, reason);
		}
	}
}