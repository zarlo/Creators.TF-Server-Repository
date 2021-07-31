#pragma semicolon 1

#define PLUGIN_AUTHOR "Nanochip"
#define PLUGIN_VERSION "1.2"

#include <sourcemod>
#include <morecolors>
#include <nativevotes>


public Plugin myinfo =
{
	name = "[TF2] Vote Alltalk",
	author = PLUGIN_AUTHOR,
	description = "Vote to turn on alltalk.",
	version = PLUGIN_VERSION,
	url = "http://steamcommunity.com/id/xnanochip"
};

ConVar cvarVoteTime, cvarVoteTimeDelay, cvarVoteChatPercent, cvarVoteMenuPercent, cvarAlltalk;

int g_iVoters, g_iVotes, g_iVotesNeeded;
bool g_bVoted[MAXPLAYERS + 1], g_bVoteCooldown;

public void OnPluginStart()
{
	CreateConVar("votealltalk_version", PLUGIN_VERSION, "Vote Alltalk Version", FCVAR_DONTRECORD);

	cvarVoteTime = CreateConVar("votealltalk_time", "30.0", "Time in seconds the vote menu should last.", 0);
	cvarVoteTimeDelay = CreateConVar("votealltalk_delay", "60.0", "Time in seconds before players can initiate another alltalk vote.", 0);
	cvarVoteChatPercent = CreateConVar("votealltalk_chat_percentage", "0.20", "How many players are required for the chat vote to pass? 0.20 = 20%.", 0, true, 0.05, true, 1.0);
	cvarVoteMenuPercent = CreateConVar("votealltalk_menu_percentage", "0.60", "How many players are required for the menu vote to pass? 0.60 = 60%.", 0, true, 0.05, true, 1.0);
	cvarAlltalk = FindConVar("sv_alltalk");

	RegConsoleCmd("sm_votealltalk", Cmd_VoteAlltalk, "Initiate a vote for alltalk");
	RegConsoleCmd("sm_valltalk", Cmd_VoteAlltalk, "Initiate a vote for alltalk");
	RegConsoleCmd("sm_alltalk", Cmd_Alltalk, "See the current status of Alltalk");
	RegAdminCmd("sm_forcealltalk", Cmd_ForceAlltalk, ADMFLAG_VOTE, "Force toggle the status of Alltalk");
}

public void OnMapStart()
{
	g_iVoters = 0;
	g_iVotesNeeded = 0;
	g_iVotes = 0;
	g_bVoteCooldown = false;
}

public void OnClientAuthorized(int client, const char[] auth)
{
	if (!StrEqual(auth, "BOT"))
	{
		g_bVoted[client] = false;
		g_iVoters++;
		g_iVotesNeeded = RoundToCeil(float(g_iVoters) * cvarVoteChatPercent.FloatValue);
	}
}

public Action Cmd_ForceAlltalk(int client, int args)
{
	StartVoteAlltalk();
	return Plugin_Handled;
}

public void OnClientDisconnect(int client)
{
	if (g_bVoted[client]) g_iVotes--;
	g_iVoters--;
	g_iVotesNeeded = RoundToCeil(float(g_iVoters) * cvarVoteChatPercent.FloatValue);
}

public void OnClientPutInServer(int client)
{
	CreateTimer(5.0, AlltalkMessage, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
}

public Action AlltalkMessage(Handle hTimer, int userid)
{
	int client = GetClientOfUserId(userid);
	if (client == 0) return Plugin_Stop;

	if (cvarAlltalk.BoolValue)
	{
		MC_PrintToChat(client, "[{creators}Creators.TF{default}] Alltalk is currently {green}enabled{default}. Type {lightgreen}valltalk {default}if you want to initiate a vote to disable it.");
	}
	return Plugin_Continue;
}

public Action Cmd_Alltalk(int client, int args)
{
	if (cvarAlltalk.BoolValue)
	{
		MC_ReplyToCommand(client, "[{creators}Creators.TF{default}] Alltalk is currently {green}enabled{default}. Type {lightgreen}valltalk {default}if you want to initiate a vote to disable it.");
	}
	else
	{
		MC_ReplyToCommand(client, "[{creators}Creators.TF{default}] Alltalk is currently {red}disabled{default}. Type {lightgreen}valltalk {default}if you want to initiate a vote to enable it.");
	}
	return Plugin_Handled;
}

public Action Cmd_VoteAlltalk(int client, int args)
{
	AttemptVoteAlltalk(client);
	return Plugin_Handled;
}

public OnClientSayCommand_Post(int client, const char[] command, const char[] sArgs)
{
	if (strcmp(sArgs, "votealltalk", false) == 0 || strcmp(sArgs, "valltalk", false) == 0)
	{
		new ReplySource:old = SetCmdReplySource(SM_REPLY_TO_CHAT);

		AttemptVoteAlltalk(client);

		SetCmdReplySource(old);
	}
}

void AttemptVoteAlltalk(int client)
{
	if (g_bVoteCooldown)
	{
		MC_ReplyToCommand(client, "[{creators}Creators.TF{default}] Sorry, votealltalk is currently on cool-down.");
		return;
	}

	char name[MAX_NAME_LENGTH];
	GetClientName(client, name, sizeof(name));

	if (g_bVoted[client])
	{
		MC_ReplyToCommandEx(client, client, "[{creators}Creators.TF{default}] {teamcolor}You {default}have already voted for alltalk. [{lightgreen}%d{default}/{lightgreen}%d {default}votes required]", g_iVotes, g_iVotesNeeded);
		return;
	}

	g_iVotes++;
	g_bVoted[client] = true;
	if (!cvarAlltalk.BoolValue) MC_PrintToChatAllEx(client, "[{creators}Creators.TF{default}] {teamcolor}%s {default}wants to {green}enable {default}alltalk. [{lightgreen}%d{default}/{lightgreen}%d {default}votes required]", name, g_iVotes, g_iVotesNeeded);
	else MC_PrintToChatAllEx(client, "[{creators}Creators.TF{default}] {teamcolor}%s {default}wants to {red}disable {default}alltalk. [{lightgreen}%d{default}/{lightgreen}%d {default}votes required]", name, g_iVotes, g_iVotesNeeded);

	if (g_iVotes >= g_iVotesNeeded)
	{
		StartVoteAlltalk();
	}
}

void StartVoteAlltalk()
{
	VoteAlltalkMenu();
	ResetVoteAlltalk();
	g_bVoteCooldown = true;
	CreateTimer(cvarVoteTimeDelay.FloatValue, Timer_Delay, _, TIMER_FLAG_NO_MAPCHANGE);
}

public Action Timer_Delay(Handle timer)
{
	g_bVoteCooldown = false;
}

void ResetVoteAlltalk()
{
	g_iVotes = 0;
	for (int i = 1; i <= MAXPLAYERS; i++) g_bVoted[i] = false;
}

void VoteAlltalkMenu()
{
	if (NativeVotes_IsVoteInProgress())
	{
		CreateTimer(10.0, Timer_Retry, _, TIMER_FLAG_NO_MAPCHANGE);
		PrintToConsoleAll("[SM] Can't vote alltalk because there is already a vote in progress. Retrying in 10 seconds...");
		return;
	}

	Handle vote = NativeVotes_Create(NativeVote_Handler, NativeVotesType_Custom_Mult);

	if (!cvarAlltalk.BoolValue) NativeVotes_SetTitle(vote, "Enable Alltalk?");
	else NativeVotes_SetTitle(vote, "Disable Alltalk?");

	NativeVotes_AddItem(vote, "yes", "Yes");
	NativeVotes_AddItem(vote, "no", "No");
	NativeVotes_DisplayToAll(vote, cvarVoteTime.IntValue);
}

public int NativeVote_Handler(Handle vote, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_End: NativeVotes_Close(vote);
		case MenuAction_VoteCancel:
		{
			if (param1 == VoteCancel_NoVotes)
			{
				NativeVotes_DisplayFail(vote, NativeVotesFail_NotEnoughVotes);
			}
			else
			{
				NativeVotes_DisplayFail(vote, NativeVotesFail_Generic);
			}
		}
		case MenuAction_VoteEnd:
		{
			char item[64];
			float percent, limit;
			int votes, totalVotes;

			GetMenuVoteInfo(param2, votes, totalVotes);
			NativeVotes_GetItem(vote, param1, item, sizeof(item));

			percent = float(votes) / float(totalVotes);
			limit = cvarVoteMenuPercent.FloatValue;

			if (FloatCompare(percent, limit) >= 0 && StrEqual(item, "yes"))
			{
				if (!cvarAlltalk.BoolValue)
				{
					NativeVotes_DisplayPass(vote, "Alltalk has been enabled.");
					cvarAlltalk.SetBool(true);
				}
				else
				{
					NativeVotes_DisplayPass(vote, "Alltalk has been disabled.");
					cvarAlltalk.SetBool(false);
				}
			}
			else NativeVotes_DisplayFail(vote, NativeVotesFail_Loses);
		}
	}
}

public Action Timer_Retry(Handle timer)
{
	VoteAlltalkMenu();
}
