#pragma semicolon 1

#define DEBUG

#define PLUGIN_AUTHOR "Nanochip"
#define PLUGIN_VERSION "1.01"

#include <sourcemod>
#include <gamemode>

public Plugin myinfo = 
{
	name = "Attack/Defend Gamemode Fix",
	author = PLUGIN_AUTHOR,
	description = "When the mp_timelimit has surpassed on Attack/Defend, the round gets force ended even though mp_match_end_at_timelimit 0 is set.",
	version = PLUGIN_VERSION,
	url = "https://steamcommunity.com/id/xNanochip"
};

ConVar mpTimeLimit, mpWinLimit, cvADWinLimit;

public void OnPluginStart()
{
	CreateConVar("attackdefend_fix_version", PLUGIN_VERSION, "Attack/Defend Gamemode Fix Version", FCVAR_DONTRECORD);
	
	RegAdminCmd("sm_gamemode", Cmd_Gamemode, ADMFLAG_RCON, "Get's the gamemode.");
	
	cvADWinLimit = CreateConVar("attackdefend_fix_maxrounds", "5", "Sets the max rounds to the Attack/Defend gamemode only.");
	
	mpTimeLimit = FindConVar("mp_timelimit");
	mpWinLimit = FindConVar("mp_maxrounds");
	
	AutoExecConfig();
}

//debug command
public Action Cmd_Gamemode(int client, int args)
{
	switch(TF2_DetectGameMode())
	{
		case TF2_GameMode_Unknown:ReplyToCommand(client, "Unknown");
		case TF2_GameMode_CTF:ReplyToCommand(client, "CTF");
		case TF2_GameMode_5CP:ReplyToCommand(client, "5CP");
		case TF2_GameMode_PL:ReplyToCommand(client, "PL");
		case TF2_GameMode_Arena:ReplyToCommand(client, "Arena");
		case TF2_GameMode_ADCP:ReplyToCommand(client, "ADCP");
		case TF2_GameMode_TC:ReplyToCommand(client, "TC");
		case TF2_GameMode_PLR:ReplyToCommand(client, "PLR");
		case TF2_GameMode_KOTH:ReplyToCommand(client, "KOTH");
		case TF2_GameMode_SD:ReplyToCommand(client, "SD");
		case TF2_GameMode_MvM:ReplyToCommand(client, "MVM");
		case TF2_GameMode_Training:ReplyToCommand(client, "Training");
		case TF2_GameMode_ItemTest:ReplyToCommand(client, "ItemTest");
	}
	return Plugin_Handled;
}

public void OnMapStart()
{
	CreateTimer(3.0, Timer_Delay, _, TIMER_FLAG_NO_MAPCHANGE);
}

public Action Timer_Delay(Handle hTimer)
{
	if (TF2_DetectGameMode() == TF2_GameMode_ADCP)
	{
		LogAction(0, -1, "Detected Attack/Defend gamemode. Disabling map timer and setting a round limit instead.");
		if (mpTimeLimit.IntValue > -1) mpTimeLimit.SetInt(-1);
		mpWinLimit.SetInt(cvADWinLimit.IntValue);
	}
}