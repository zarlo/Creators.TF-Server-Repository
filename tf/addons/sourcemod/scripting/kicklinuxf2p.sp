#pragma semicolon 1

#define PLUGIN_AUTHOR "Nanochip"
#define PLUGIN_VERSION "1.00"

#include <sourcemod>
#include <steamtools>

public Plugin myinfo = 
{
	name = "SourceBans++ Integration",
	author = PLUGIN_AUTHOR,
	description = "Custom Integrations for SB++",
	version = PLUGIN_VERSION,
	url = "https://steamcommunity.com/id/xNanochip"
};

ConVar cvKickMode, cvKickF2PMessage, cvKickLinuxMessage, cvKickOnlyMessage;
int g_iMode;
char g_sKickF2PMessage[256], g_sKickLinuxMessage[256], g_sKickOnlyMessage[256];


ArrayList g_aSteamIDs;

public void OnPluginStart()
{
	cvKickMode = CreateConVar("playerkicker_mode", "0", "0 = Don't kick, 1 = Kick all Free-to-Plays, 2 Kick all Linux players, 3 = Kick both all Free-to-Plays and all Linux players, 4 = Kick only Free-To-Plays who are on Linux");
	cvKickF2PMessage = CreateConVar("playerkicker_f2p_message", "You have been kicked for being Free-to-Play.", "Kick message to display when kicking F2P players.");
	cvKickLinuxMessage = CreateConVar("playerkicker_linux_message", "You have been kicked for playing on a Linux operating system.", "Kick message to display when kicking Linux players.");
	cvKickOnlyMessage = CreateConVar("playerkicker_f2ponlinux_message", "You have been flagged by our anti-cheat system.", "Kick message to display when kicking players who are Free-To-Play and are on Linux.");
	
	cvKickMode.AddChangeHook(OnCvarChanged);
	cvKickF2PMessage.AddChangeHook(OnCvarChanged);
	cvKickLinuxMessage.AddChangeHook(OnCvarChanged);
	cvKickOnlyMessage.AddChangeHook(OnCvarChanged);
	
	g_iMode = cvKickMode.IntValue;
	cvKickF2PMessage.GetString(g_sKickF2PMessage, sizeof(g_sKickF2PMessage));
	cvKickLinuxMessage.GetString(g_sKickLinuxMessage, sizeof(g_sKickLinuxMessage));
	cvKickOnlyMessage.GetString(g_sKickOnlyMessage, sizeof(g_sKickOnlyMessage));
	
	g_aSteamIDs = new ArrayList();
	
	ParseConfig();
}

public int OnCvarChanged(ConVar cvar, const char[] oldValue, const char[] newValue)
{
	if (cvar == cvKickMode) g_iMode = cvKickMode.IntValue;
	if (cvar == cvKickF2PMessage) cvKickF2PMessage.GetString(g_sKickF2PMessage, sizeof(g_sKickF2PMessage));
	if (cvar == cvKickLinuxMessage) cvKickLinuxMessage.GetString(g_sKickLinuxMessage, sizeof(g_sKickLinuxMessage));
	if (cvar == cvKickOnlyMessage) cvKickOnlyMessage.GetString(g_sKickOnlyMessage, sizeof(g_sKickOnlyMessage));
}

public void OnParseOS(int client, int os)
{
	//ignore if plugin disabled or invalid client
	if (g_iMode == 0 || client == 0) return;
	
	//ignore bots
	if (IsClientInGame(client) && (IsFakeClient(client) || IsClientSourceTV(client) || IsClientReplay(client))) return;
	
	//ignore people with flags
	if (GetUserAdmin(client) != INVALID_ADMIN_ID) return;
	
	//ignore steamids in the config file
	char steamid[32];
	GetClientAuthId(client, AuthId_SteamID64, steamid, sizeof(steamid));
	if (g_aSteamIDs.FindString(steamid) != -1) return;
	
	bool f2p, linux;
	
	//kick free-to-plays
	if (Steam_CheckClientSubscription(client, 0) && !Steam_CheckClientDLC(client, 459))
	{
		f2p = true;
	}
	
	//kick linux users
	if (os == 1)
	{
		linux = true;
	}
	
	if ((g_iMode == 1 || g_iMode == 3) && f2p)
	{
		KickClient(client, g_sKickF2PMessage);
	}
	if ((g_iMode == 2 || g_iMode == 3) && linux)
	{
		KickClient(client, g_sKickLinuxMessage);
	}
	if (g_iMode == 4 && f2p && linux)
	{
		KickClient(client, g_sKickOnlyMessage);
	}
}

void ParseConfig()
{
	char configPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, configPath, sizeof(configPath), "configs/playerkicker_ignore.txt");
	
	File file;
	if (!FileExists(configPath))
	{
		file = OpenFile(configPath, "w"); //just create an empty file
		file.Close();
		return;
	}
	
	file = OpenFile(configPath, "r");
	char steamid[32];
	
	while (file.ReadLine(steamid, sizeof(steamid)))
	{
		ReplaceString(steamid, sizeof(steamid), "\n", "", false);
		g_aSteamIDs.PushString(steamid);
		PrintToChatAll(steamid);
	}
	file.Close();
}
