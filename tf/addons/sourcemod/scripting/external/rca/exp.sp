Handle g_cvExpPeriod;
Handle g_cvExpDropMin;
Handle g_cvExpDropMax;
Handle g_tExpTimer;
Handle g_cvDonatorMult;
Handle g_cvCreditMult;
Handle g_cvExpMult;
Handle g_cvUnusualChance;

bool g_HideHud[MAXPLAYERS + 1];

public Action cHud(int client, int args){
	g_HideHud[client] = !g_HideHud[client];
	return Plugin_Handled;
}

public int GetClientLevel(int client)
{
	//if (DEBUG == 1)PrintToServer("GetClientLevel");
	if(IsClientInGame(client) && Players[client][bLogged])
	{
		return RoundToFloor(float((Players[client][iExp] + Players[client][iCExp])) / 1000.0);
	}
	return 0;
}

public int GetClientExp(int client)
{
	//if (DEBUG == 1)PrintToServer("GetClientExp");
	if(IsClientInGame(client) && Players[client][bLogged])
	{
		return Players[client][iExp] + Players[client][iCExp];
	}
	return 0;
}

public Action Timer_UpdateHUD(Handle timer, any data)
{
	return;
	if (DEBUG == 1)PrintToServer("Timer_UpdateHUD");
	for (new i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && Players[i][bLogged] && !g_HideHud[i])
		{
			SetHudTextParams(0.04, 0.04, 0.5, 255, 255, 255, 255, 0, _, 0.01, 0.01);
			ShowHudText(i, -1, "[ЧиП] Level %d %N %d»\nEXP %d/%d\n%d MC ( !hud )",GetClientLevel(i), i,Players[i][iKillstreak], GetClientExp(i), (GetClientLevel(i) + 1) * 1000, Players[i][iCredit]);
		}
	}
}

public g_cvHookExpPeriod(Handle convar, const char[] oldValue, const char[] newValue)
{
	if (DEBUG == 1)PrintToServer("g_cvHookExpPeriod");
	if (g_tExpTimer != INVALID_HANDLE)KillTimer(g_tExpTimer);
	
	//g_tExpTimer = CreateTimer(StringToFloat(newValue), Timer_ExpRandomGain, _, TIMER_REPEAT);
}

public Action Timer_ExpRandomGain(Handle timer, any data)
{
	if (DEBUG == 1)PrintToServer("Timer_ExpRandomGain");
	for (new i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i))
		{
			Exp_AddPoints(i, GetRandomInt(GetConVarInt(g_cvExpDropMin), GetConVarInt(g_cvExpDropMax)), false, "playing on the server");
		}
	}
}


public Action cGiveCredit(int client, int args){
 	if (args < 2)
	{
		ReplyToCommand(client, "[SM] Usage: sm_givemc <#userid|name> <amount>");
		return Plugin_Handled;
	}

	char sArg1[20], sArg2[20];
	int iArg1, iArg2;
	iArg1 = GetCmdArg(1, sArg1, sizeof(sArg1));
	iArg2 = GetCmdArg(2, sArg2, sizeof(sArg2));
	
	if(iArg1 == 0 || iArg2 == 0) {
		ReplyToCommand(client, "[SM] Usage: sm_givemc <#userid|name> <amount>");
		return Plugin_Handled;
	}
	
	char target_name[MAX_TARGET_LENGTH];
	int target_list[MAXPLAYERS], target_count;
	bool tn_is_ml;
	
	if ((target_count = ProcessTargetString(
			sArg1,
			client,
			target_list,
			MAXPLAYERS,
			COMMAND_FILTER_NO_BOTS,
			target_name,
			sizeof(target_name),
			tn_is_ml)) <= 0)
	{
		ReplyToTargetError(client, target_count);
		return Plugin_Handled;
	}
	
	for (int i = 0; i < target_count; i++)
	{
		Exp_AddCredit(target_list[i], StringToInt(sArg2), false, "cheating");
	}

	return Plugin_Handled;
}

public Action cGiveExp(int client, int args){
 	if (args < 2)
	{
		ReplyToCommand(client, "[SM] Usage: sm_givexp <#userid|name> <amount>");
		return Plugin_Handled;
	}

	char sArg1[20], sArg2[20];
	int iArg1, iArg2;
	iArg1 = GetCmdArg(1, sArg1, sizeof(sArg1));
	iArg2 = GetCmdArg(2, sArg2, sizeof(sArg2));
	
	if(iArg1 == 0 || iArg2 == 0) {
		ReplyToCommand(client, "[SM] Usage: sm_givexp <#userid|name> <amount>");
		return Plugin_Handled;
	}
	
	char target_name[MAX_TARGET_LENGTH];
	int target_list[MAXPLAYERS], target_count;
	bool tn_is_ml;
	
	if ((target_count = ProcessTargetString(
			sArg1,
			client,
			target_list,
			MAXPLAYERS,
			COMMAND_FILTER_NO_BOTS,
			target_name,
			sizeof(target_name),
			tn_is_ml)) <= 0)
	{
		ReplyToTargetError(client, target_count);
		return Plugin_Handled;
	}
	
	for (int i = 0; i < target_count; i++)
	{
		Exp_AddPoints(target_list[i], StringToInt(sArg2), false, "cheating");
	}

	return Plugin_Handled;
}

stock Exp_AddPoints(int client, int points, bool silent = false,char[] msg){
	if (DEBUG == 1)PrintToServer("Exp_AddPoints");
	//if(!(client > 0 && client <= MaxClients)) return;
	points *= GetConVarInt(g_cvExpMult);
	if(GetUserFlagBits(client) & ADMFLAG_CUSTOM1 == ADMFLAG_CUSTOM1 || GetUserFlagBits(client) & ADMFLAG_ROOT == ADMFLAG_ROOT)
	{
		points *= GetConVarInt(g_cvDonatorMult);
	}

	int t_OldLevel = GetClientLevel(client);
	Players[client][iExp]+=points;
	int t_NewLevel = GetClientLevel(client);
	
	if(!silent){
		char msg_[64];
		Format(msg_,sizeof(msg_),"[%d/%d] You earned %d exp for %s",GetClientExp(client), (GetClientLevel(client) + 1) * 1000,points,msg);
		PrintHintText(client,msg_);
	}
	if(t_OldLevel != t_NewLevel){
		ClientCommand(client,"playgamesound MatchMaking.LevelSixAchieved");
		PrintToChatAll("\x0753f442%N \x07ffffffreached new level: \x0753f442%d. \x07ffffffCongratulations!", client, t_NewLevel);
		Menu menu = new Menu(mBackpack);
		menu.SetTitle("Congratulations!\nYou've leveled up to next level.\nYour current level: %d.\nYou've got: %d MC.",t_NewLevel,t_NewLevel * 20);
		menu.AddItem("close", "Close");
		menu.ExitButton = false;
		menu.Display(client, 20);
		Exp_AddCredit(client, t_NewLevel * 20, false, "leveling up");
	}
	return;
}

stock void Exp_AddCredit(int client, int points, bool silent = false, char[] msg = "", bool mult = true){
	if (DEBUG == 1)PrintToServer("Exp_AddCredit");
	if(mult)
	{
		points *= GetConVarInt(g_cvCreditMult);
		if(GetUserFlagBits(client) & ADMFLAG_CUSTOM1 == ADMFLAG_CUSTOM1 || GetUserFlagBits(client) & ADMFLAG_ROOT == ADMFLAG_ROOT)
		{
			points *= GetConVarInt(g_cvDonatorMult);
		}
	}
	//if(!(client > 0 && client <= MaxClients)) return;
	Players[client][iCredit] += points;
	if(!silent){
		char msg_[64];
		Format(msg_,sizeof(msg_),"[%dMC] You earned %d MC for %s",Players[client][iCredit],points,msg);
		
		ClientCommand(client,"playgamesound MVM.MoneyPickup");
		PrintHintText(client,msg_);
	}
}