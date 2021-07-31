#pragma semicolon 1

#define PLUGIN_AUTHOR "Nanochip"
#define PLUGIN_VERSION "1.0"

#include <sourcemod>


public Plugin myinfo =
{
	name = "[TF2] Vote Kick",
	author = PLUGIN_AUTHOR,
	description = "Aliases the callvote console command.",
	version = PLUGIN_VERSION,
	url = "http://steamcommunity.com/id/xnanochip"
};

public void OnPluginStart()
{
	RegConsoleCmd("sm_votekick", Cmd_VoteKick, "Call a vote to kick someone on your team.");
	RegConsoleCmd("sm_vkick", Cmd_VoteKick, "Call a vote to kick someone on your team.");
}

public Action Cmd_VoteKick(int client, int args)
{
	if (client < 1) return Plugin_Handled;
	
	if (args < 1)
	{
		FakeClientCommand(client, "callvote");
		return Plugin_Handled;
	}
	
	char arg1[32];
	GetCmdArg(1, arg1, sizeof arg1);
	int target = FindTarget(client, arg1);
	if (target < 1) return Plugin_Handled;
	
	FakeClientCommand(client, "callvote kick %d", GetClientUserId(target));
	return Plugin_Handled;
}

public Action OnClientSayCommand(int client, const char[] command, const char[] sArgs)
{
	if (StrEqual(sArgs, "vkick"))
	{
		Cmd_VoteKick(client, 0);
		return Plugin_Handled;
	}
	if (StrStarts(sArgs, "!vkick") || StrStarts(sArgs, "!votekick"))
	{
		return Plugin_Handled;
	}
	return Plugin_Continue;
}

stock bool StrStarts(const char[] szStr, const char[] szSubStr, bool bCaseSensitive = true) 
{
	return !StrContains(szStr, szSubStr, bCaseSensitive);
}