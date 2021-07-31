#pragma semicolon 1

#include <sourcemod>
#include <tf2items>
#include <tf2_stocks>
#include <tf2attributes>
#include <sdkhooks>
#include <sdktools>
#include <clientprefs>

/**
 * CTF game mode test for Creators.TF
 */

public Plugin:myinfo = {
	name = "[C.TF] Capture The Flag Rework",
	author = "IvoryPal",
	version = "1.1"
}

#define MAXTEAMS 4

int TimerSeconds;
Handle TimerValue;
Handle TimerMax;
Handle CapTimeAdd;
Handle ReturnTime;
int TeamScore[MAXTEAMS];

//flag vars
int BLUFlag;
int REDFlag;

//bool RoundInProgress = false;

Cookie g_Cookie;
bool g_bShowTipMenu[MAXPLAYERS+1];

public void OnPluginStart()
{
	HookEvent("teamplay_round_win", Event_RoundEnd, EventHookMode_PostNoCopy);
	HookEvent("teamplay_round_start", Event_RoundStart, EventHookMode_Pre);
	HookEvent("teamplay_flag_event", Event_FlagCapped, EventHookMode_Pre);
	AddCommandListener(ClassListener, "joinclass");

	RegConsoleCmd("sm_ctfrework", Cmd_CTFRework, "Show the Capture the Flag Rework Tip Panel");

	CapTimeAdd = CreateConVar("sm_ctf_time_added", "135", "How many seconds are added to the timer on capture");
	TimerValue = CreateConVar("sm_ctf_timer", "300", "Initial round timer in seconds");
	TimerMax = CreateConVar("sm_ctf_timer_max", "720", "Max value for round timer in seconds");
	ReturnTime = CreateConVar("sm_ctf_return_time", "15", "Return time for intel in seconds");

	g_Cookie = new Cookie("ctfrework_cookie", "CTF Rework Popup Tip", CookieAccess_Public);

	for (int i = 1; i <= MaxClients; i++)
	{
		g_bShowTipMenu[i] = true;
		if (AreClientCookiesCached(i)) OnClientCookiesCached(i);
	}
}

public Action Cmd_CTFRework(int client, int args)
{
	if (IsValidClient(client)) TipMenu(client);
	return Plugin_Handled;
}

public Action Event_RoundStart(Handle event, const char[] name, bool dontBroadcast)
{
	if (GameRules_GetProp("m_bInWaitingForPlayers"))
		return;

	CreateTimer(0.5, SetRoundSettings, _, TIMER_FLAG_NO_MAPCHANGE);
}

public void OnClientConnected(int client)
{
	g_bShowTipMenu[client] = true;
}

public void OnClientCookiesCached(int client)
{
	char info[16];
	GetClientCookie(client, g_Cookie, info, sizeof info);
	if (strcmp(info, "false") == 0) g_bShowTipMenu[client] = false;
}

public Action ClassListener(int client, const char[] command, int args)
{
	if (IsValidClient(client) && g_bShowTipMenu[client])
	{
		TipMenu(client);
		g_bShowTipMenu[client] = false;
	}
}

void TipMenu(int client)
{
	Panel panel = new Panel();

	panel.SetTitle("[Creators.TF] Capture The Flag Reworkedᴮᴱᵀᴬ");
	panel.DrawText(" ");
	panel.DrawText("To help encourage objective-based playing, a few changes have been introduced:");
	panel.DrawText("    ➝ Added a 5 minute round timer.");
	panel.DrawText("    ➝ The intel now returns on drop much faster (15 seconds).");
	panel.DrawText("    ➝ When time runs out, the team with most captures will win.");
	panel.DrawText("    ➝ If both teams tied, both will lose to Stalemate.");
	panel.DrawText("    ➝ Capturing the intel will add 2.25 minutes to the round.");
	panel.DrawText(" ");
	panel.DrawText("As always, send us #feedback in our discord.");
	panel.DrawText(" ");
	panel.DrawItem("Close", ITEMDRAW_CONTROL);
	panel.DrawItem("", ITEMDRAW_NOTEXT);
	panel.DrawItem("Don't show this again", ITEMDRAW_CONTROL);

	panel.Send(client, PanelHandler, 120);
	delete panel;
}

public int PanelHandler(Menu menu, MenuAction action, int client, int param2)
{
	if (action == MenuAction_Select)
	{
		ClientCommand(client, "playgamesound \"%s\"", "ui\\panel_close.wav");
		if (param2 == 5)
		{
			char info[16];
			Format(info, sizeof info, "false");
			SetClientCookie(client, g_Cookie, info);
		}
	}
}

public Action SetRoundSettings(Handle Timer)
{
	int iEnt;
	iEnt = FindEntityByClassname(iEnt, "team_round_timer");
	if (iEnt < 1)
	{
		iEnt = CreateEntityByName("team_round_timer");
		if (IsValidEntity(iEnt))
			DispatchSpawn(iEnt);
		else
		{
			PrintToServer("Unable to find or create a team_round_timer entity!");
		}
	}
	TimerSeconds = GetConVarInt(TimerValue); //Initial seconds left for round
	SetVariantInt(TimerSeconds);
	AcceptEntityInput(iEnt, "SetTime");
	SetVariantInt(GetConVarInt(TimerMax)); //Max time for timer
	AcceptEntityInput(iEnt, "SetMaxTime");
	AcceptEntityInput(iEnt, "Resume");
	HookEntityOutput("team_round_timer", "OnFinished", TimerExpire); //Hook for when the timer ends
	//RoundInProgress = true;
	for (int team = 2; team < MAXTEAMS; team++)
	{
		TeamScore[team] = 0;
	}
	SetFlagReturnTime(REDFlag, GetConVarInt(ReturnTime));
	SetFlagReturnTime(BLUFlag, GetConVarInt(ReturnTime));
	HookEntityOutput("item_teamflag", "OnDrop", FlagDropped);
}

public void FlagDropped(const char[] name, int caller, int activator, float delay)
{
	SetFlagReturnTime(REDFlag, GetConVarInt(ReturnTime));
	SetFlagReturnTime(BLUFlag, GetConVarInt(ReturnTime));
}

public void TimerExpire(const char[] output, int caller, int victim, float delay)
{
	if (GameRules_GetProp("m_bInWaitingForPlayers"))
		return;

	EndRound();
}

//Increment score of team that captured
public Action Event_FlagCapped(Handle event, const char[] name, bool dontBroadcast)
{
	int type = GetEventInt(event, "eventtype"); //type corresponding to event
	int client = GetEventInt(event, "player"); //Player involved with type
	if (!IsValidClient(client))
	{
		//PrintToChatAll("Invalid Carrier %i", client);
		return Plugin_Continue;
	}

	switch (type)
	{
		case 2: //Flag Captured
		{
			int team = GetClientTeam(client);
			int iEnt;
			iEnt = FindEntityByClassname(iEnt, "team_round_timer");
			SetVariantInt(GetConVarInt(CapTimeAdd));
			AcceptEntityInput(iEnt, "AddTime");
			TeamScore[team]++;
			//PrintToChatAll("Red Score: %i\nBlue Score: %i", TeamScore[2], TeamScore[3]);
			return Plugin_Continue;
		}
	}
	return Plugin_Continue;
}

//Hook the spawn of any item_teamflag
public void OnEntityCreated(int entity, const char[] classname)
{
	if (StrEqual(classname, "item_teamflag"))
	{
		SDKHook(entity, SDKHook_SpawnPost, FlagSpawn);
	}
}

//Set flag return time on spawn
public Action FlagSpawn(int flag)
{
	SetFlagReturnTime(flag, GetConVarInt(ReturnTime)); //set flag return time
	int team = GetEntProp(flag, Prop_Send, "m_iTeamNum");
	switch (team)
	{
		case 2: REDFlag = flag;
		case 3: BLUFlag = flag;
	}
	return Plugin_Continue;
}

public void SetFlagReturnTime(int flag, int time)
{
	if (!IsValidEntity(flag)) return;
	SetVariantInt(time);
	AcceptEntityInput(flag, "SetReturnTime");
	//PrintToChatAll("Set flag return time to %i", GetConVarInt(ReturnTime));
}

//Reset scores on round end
public Action Event_RoundEnd(Handle event, const char[] name, bool dontBroadcast)
{
	//RoundInProgress = false;
	for (int team = 2; team < MAXTEAMS; team++)
	{
		TeamScore[team] = 0;
	}
}

//Ends the round and sets the winner to team with more captures
public void EndRound()
{
	int iEnt;
	int winningteam;
	int winningscore = -1;
	iEnt = FindEntityByClassname(iEnt, "game_round_win");
	if (iEnt < 1)
	{
		iEnt = CreateEntityByName("game_round_win");
		if (IsValidEntity(iEnt))
			DispatchSpawn(iEnt);
		else
		{
			PrintToServer("Unable to find or create a game_round_win entity!");
		}
	}
	for (int team = 2; team < MAXTEAMS; team++) //loops through both teams and compares scores
	{
		if (TeamScore[team] >= winningscore) //Set red team's score to winning score, then override if blue team's score is higher
		{
			winningscore = TeamScore[team];
			winningteam = team;
		}
	}
	if (TeamScore[2] == TeamScore[3]) //if both team's score is equal, end in stalemate
		winningteam = 0;

	SetVariantInt(winningteam);
	AcceptEntityInput(iEnt, "SetTeam");
	AcceptEntityInput(iEnt, "RoundWin");
}

public void OnMapStart()
{
	char currentMap[PLATFORM_MAX_PATH];
	GetCurrentMap(currentMap, sizeof(currentMap));
	if (StrContains(currentMap, "workshop") != -1)
	{
		GetMapDisplayName(currentMap, currentMap, sizeof currentMap);
	}

	if(StrContains(currentMap, "ctf_" , false) != -1)
	{
		PrintToServer("[C.TF] Capture the Flag detected, enabling CTF Rework...");
	}
	else //Unload plugin if map is not ctf
	{
		PrintToServer("[C.TF] Capture the Flag not detected, unloading CTF Rework...");
		Handle plugin = GetMyHandle();
		char namePlugin[256];
		GetPluginFilename(plugin, namePlugin, sizeof(namePlugin));
		PrintToServer("[C.TF] ..Done!");
		ServerCommand("sm plugins unload %s", namePlugin);
	}
}

stock bool IsValidClient(int iClient)
{
	if (iClient <= 0 || iClient > MaxClients || !IsClientInGame(iClient))
	{
		return false;
	}
	if (IsClientSourceTV(iClient) || IsClientReplay(iClient))
	{
		return false;
	}
	return true;
}
