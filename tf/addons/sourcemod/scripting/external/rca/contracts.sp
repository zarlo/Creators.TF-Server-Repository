int g_PlayerContract[MAXPLAYERS + 1][Quest];
int g_PlayerQuests[MAXPLAYERS + 1][MAXQUESTS][Quest];
int g_PlayersQuestTasks[MAXPLAYERS + 1][MAXQUESTTASKS][QuestTask];
int g_PlayerProgressBuffer[MAXPLAYERS + 1][MAXQUESTTASKS];
int g_PlayerProgress[MAXPLAYERS + 1][MAXQUESTS][MAXQUESTTASKS];

int g_PlayerCounters[MAXPLAYERS + 1][PlayerCounters];

bool g_QuestHUDYellow[MAXPLAYERS + 1];

char g_QuestConditions[_:QuestConds][32];

#define ITEMDRAW_SPACER_NOSLOT ((1<<1)|(1<<3)) //SPACER WITH NO SLOT

public Action Timer_UpdateContractHUD(Handle timer, any data)
{
	return;
	if (DEBUG == 1)PrintToServer("Timer_UpdateContractHUD");
	for (new i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && Players[i][bLogged] && Players[i][iContract] > 0)
		{
			char sHUDText[64];
			Format(sHUDText, sizeof(sHUDText), "CONTRACT: \n%d/%dCP \n", g_PlayerProgressBuffer[i][0], g_PlayersQuestTasks[i][0][iLimit]);
			for (new j = 1; j < MAXQUESTTASKS; j++)
			{
				Format(sHUDText, sizeof(sHUDText), "%s[%d/%d]", sHUDText,
				g_PlayerProgressBuffer[i][j],
				g_PlayersQuestTasks[i][j][iLimit]);
			}
			Format(sHUDText, sizeof(sHUDText), "%s ", sHUDText);
			bool bReady = (!g_PlayerQuests[i][Players[i][iContract]][bTurned] && g_PlayerProgress[i][Players[i][iContract]][0] == g_PlayersQuestTasks[i][0][iLimit]);
			if(bReady)
				Format(sHUDText, sizeof(sHUDText), "%s\n⚠TURN IN! ", sHUDText);
			if(g_QuestHUDYellow[i])
			{
				SetHudTextParams(1.0, -1.0, 0.5, 255, 150, 0, 255, 0, _, 0.01, 0.01);
				g_QuestHUDYellow[i] = false;
			}else if(bReady) SetHudTextParams(1.0, -1.0, 0.5, 178, 255, 128, 255, 0, _, 0.01, 0.01);
			else SetHudTextParams(1.0, -1.0, 0.5, 255, 255, 255, 255, 0, _, 0.01, 0.01);
			ShowHudText(i, -1, sHUDText);
		}
	}
}

public Action cQuest(int client, int args)
{
	Menu menu = new Menu(mBackpack);
	char sQuest[64];
	Format(sQuest, sizeof(sQuest), "%s [%d/%d]", g_PlayerContract[client][sName], g_PlayerProgressBuffer[client][0], g_PlayersQuestTasks[client][0][iLimit]);
	menu.SetTitle(sQuest);
	for (new i = 0; i < MAXQUESTTASKS; i++)
	{
		char sQuestTask[512];
		if(i > 0)
		Format(sQuestTask, sizeof(sQuestTask), "[%d/%d] %s: %dCP", 
			g_PlayerProgressBuffer[client][i],
			g_PlayersQuestTasks[client][i][iLimit],
			g_PlayersQuestTasks[client][i][sName],
			g_PlayersQuestTasks[client][i][iCP]);
		else Format(sQuestTask, sizeof(sQuestTask), "%s: %dCP", 
			g_PlayersQuestTasks[client][i][sName],
			g_PlayersQuestTasks[client][i][iCP]);
		
		if(i == MAXQUESTTASKS-1)
		{
			if(g_PlayerContract[client][iReward][iItem] > 0 
			|| g_PlayerContract[client][iReward][iCredit] > 0)
			{
				Format(sQuestTask, sizeof(sQuestTask), "%s\n \nReward: \n",sQuestTask);
				if(g_PlayerContract[client][iReward][iItem] > 0)
				{
					Format(sQuestTask, sizeof(sQuestTask), "%s- %s%s\n",sQuestTask, g_Quality[g_PlayerContract[client][iReward][iItemQuality]][sName], Items[g_PlayerContract[client][iReward][iItem]][sName]);
				}
				if(g_PlayerContract[client][iReward][iCredit] > 0)
				{
					Format(sQuestTask, sizeof(sQuestTask), "%s- %d MC",sQuestTask, g_PlayerContract[client][iReward][iCredit]);
				}
			}
			Format(sQuestTask, sizeof(sQuestTask), "%s\n ",sQuestTask);
		}
		menu.AddItem("blank", sQuestTask);
	}
	int contract = Players[client][iContract];
	bool bReady = (!g_PlayerQuests[client][contract][bTurned] && g_PlayerProgress[client][contract][0] == g_PlayersQuestTasks[client][0][iLimit]);
	if(g_PlayerQuests[client][contract][bTurned])
		menu.AddItem("", "Already Turned In.", ITEMDRAW_DISABLED);
	else if(bReady)
		menu.AddItem("turnin", "Turn In!");
	else if(!bReady && g_PlayerProgressBuffer[client][0] == g_PlayersQuestTasks[client][0][iLimit])
		menu.AddItem("", "Please wait until this round ends to Turn In.", ITEMDRAW_DISABLED);
	else menu.AddItem("", "Complete the Contract to Turn In.", ITEMDRAW_DISABLED);
	menu.ExitButton = true;
	menu.Display(client, 20);
	return Plugin_Handled;
}

public Contracts_TurnIn(int client)
{
	if (!IsClientInGame(client))return;
	
	int contract = Players[client][iContract];
	bool bReady = (!g_PlayerQuests[client][contract][bTurned] && g_PlayerProgress[client][contract][0] == g_PlayersQuestTasks[client][0][iLimit]);
	if(bReady)
	{
		char szAuth[256];
		GetClientAuthId(client,AuthId_SteamID64, szAuth, sizeof(szAuth));
		if(g_PlayerContract[client][iReward][iItem] > 0)
		{
			int qual = g_PlayerContract[client][iReward][iItemQuality];
			int item = g_PlayerContract[client][iReward][iItem];
			Pack_GiveItem(client, item, qual);
			PrintToChatAll(GiveStrings[_:QUEST], client, g_PlayerContract[client][sName], g_Quality[qual][sColor], g_Quality[qual][sName], Items[item][sName]);
		}
		if(g_PlayerContract[client][iReward][iCredit] > 0)
		{
			Exp_AddCredit(client, g_PlayerContract[client][iReward][iCredit], false, "turning in a contract");
		}
		g_PlayerQuests[client][contract][bTurned] = true;
		char query[300];
		Format(query, sizeof(query), "UPDATE tf_progress SET turned=1 WHERE steamid='%s' AND contract=%d", szAuth, contract);
		SQL_FastQuery(g_hDB, query);
		ClientCommand(client, "playgamesound Quest.TurnInDecode");
	}
}

public Contract_SetContract(int client, int contract)
{
	if (Players[client][iContract] == contract)return;
	Players[client][iContract] = contract;
	new String:loc[96];
	BuildPath(Path_SM, loc, 96, "configs/items.cfg");
	new Handle:kv = CreateKeyValues("Items");
	FileToKeyValues(kv,loc);
	
	if(KvJumpToKey(kv,"Quests",false))
	{
		char sId[11];
		IntToString(contract, sId, 11);
		if(KvJumpToKey(kv, sId, false))
		{
			g_PlayerContract[client][iId] = contract;
			g_PlayerContract[client][iCampaign] = KvGetNum(kv, "campaign", 0);
			g_PlayerContract[client][bUpdated] = false;
			KvGetString(kv, "name", g_PlayerContract[client][sName], 64);
			if(KvJumpToKey(kv,"objectives",false))
			{
				for (new i = 0; i < MAXQUESTTASKS; i++)
				{
					g_PlayerProgressBuffer[client][i] = g_PlayerProgress[client][contract][i];
					IntToString(i, sId, 11);
					if(KvJumpToKey(kv, sId, false)){
						char sCondition[32];
						KvGetString(kv, "cond", sCondition, 32);
						g_PlayersQuestTasks[client][i][iCond] = Contract_GetConditionByString(sCondition);
						g_PlayersQuestTasks[client][i][iCP] = KvGetNum(kv, "value");
						g_PlayersQuestTasks[client][i][iLimit] = KvGetNum(kv, "limit",100);
						g_PlayersQuestTasks[client][i][iDifficulty] = KvGetNum(kv, "difficulty",i);
						g_PlayersQuestTasks[client][i][iClass] = KvGetNum(kv, "class",0);
						KvGetString(kv, "task", g_PlayersQuestTasks[client][i][sName], 64);
						KvGetString(kv, "map", g_PlayersQuestTasks[client][i][sMap], 32);
					}
					KvGoBack(kv);
				}
			}
			KvGoBack(kv);
			if(KvJumpToKey(kv,"reward",false))
			{
				g_PlayerContract[client][iReward][iItem] = KvGetNum(kv, "item", 0);
				g_PlayerContract[client][iReward][iItemQuality] = KvGetNum(kv, "quality", 6);
				g_PlayerContract[client][iReward][iCredit] = KvGetNum(kv, "currency", 0);
			}
			KvGoBack(kv);
		}
	}
	if(contract > 0)ClientCommand(client, "playgamesound Quest.Decode");
}

public Action cSetQuest(int client, int args){
 	if(args != 2) return Plugin_Handled;
 	
	char sArg1[MAX_NAME_LENGTH], sArg2[11];
	GetCmdArg(1, sArg1, sizeof(sArg1));
	GetCmdArg(2, sArg2, sizeof(sArg2));
	int iTarget = CE_FindTargetBySteamID(sArg1);
	if (!IsClientInGame(iTarget))return Plugin_Handled;
	int iQuest = StringToInt(sArg2);
	
	if (iQuest < 0 || iQuest > MAXQUESTS)return Plugin_Handled;
	CEQuest_SetContract(iTarget, iQuest);
	PrintToChat(iTarget, "\x03You have activated '\x05%s\x03' contract. Type \x05!quest \x03or \x05!contract \x03to view current completion progress.", "a");
	PrintToChat(iTarget, "\x03You can change your contract on \x05creators.tf \x03in \x05ConTracker \x03tab.");
	return Plugin_Handled;
}

public Contracts_SaveProgress()
{
	char query[4096];
	for (new i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i))continue;
		if(g_PlayerContract[i][iId] > 0)
		{
			int contract = g_PlayerContract[i][iId];
			if(g_PlayerContract[i][bUpdated])
			{
				g_PlayerProgress[i][contract] = g_PlayerProgressBuffer[i];
				
				char szAuth[256];
				GetClientAuthId(i,AuthId_SteamID64, szAuth, sizeof(szAuth));
				char sProgressString[32];
				for (new j = 0; j < MAXQUESTTASKS; j++)
				{
					Format(sProgressString, 32, "%s%d;", sProgressString, g_PlayerProgressBuffer[i][j]);
				}
				if(g_PlayerQuests[i][contract][bCreated])
				{	
					Format(query, sizeof(query), "%sUPDATE tf_progress SET progress=\'%s\'WHERE steamid=\'%s\'AND contract=%d;", query, sProgressString, szAuth, contract);
				}else{
					Format(query, sizeof(query), "%sINSERT INTO tf_progress (progress,steamid,contract)VALUES(\'%s\',\'%s\',%d);", query, sProgressString, szAuth, contract);
				}
				PrintToChat(i, "\x03Your contract progress was saved.");
				
				bool bReady = (!g_PlayerQuests[i][contract][bTurned] && g_PlayerProgress[i][contract][0] == g_PlayersQuestTasks[i][0][iLimit]);
				g_PlayerContract[i][bUpdated] = false;
				if(bReady) PrintToChat(i, "\x03You completed your contract. Now type \x05!quest\x03 or \x05!contract \x03to Turn In and get the Reward.");
			}			
		}
	}
	PrintToServer(query);
	SQL_Query(g_hDB, query);
}

public Contracts_LoadClient(int client, int quest)
{
	if (!IsClientInGame(client))return;
	if (IsFakeClient(client))return;
	char szAuth[256];
	GetClientAuthId(client,AuthId_SteamID64, szAuth, sizeof(szAuth));
	char query[300];	
	
	// Cleaning old info
	// Tell me how to properly clean all children :(
	for (new i = 0; i < MAXQUESTS; i++)
	{
		g_PlayerQuests[client][i][bCreated] = false;
		g_PlayerQuests[client][i][bTurned] = false;
	}
		
	for (new i = 0; i < MAXQUESTS; i++)
		for (new j = 0; j < MAXQUESTTASKS; j++)
			g_PlayerProgress[client][i][j] = 0;
			
	Format(query, 300, "SELECT contract,progress,turned FROM `tf_progress` WHERE `steamid` = \'%s\'",szAuth);
	Handle queryH = SQL_Query(g_hDB, query);
	
	if(queryH != INVALID_HANDLE)
	{   
		//new row = 0;
		while (SQL_FetchRow(queryH))
		{
			int contract = SQL_FetchInt(queryH, 0);
			char Progress[32];
			SQL_FetchString(queryH, 1, Progress, sizeof(Progress));
			Contract_ParsePorgressString(Progress, client, contract);
			g_PlayerQuests[client][contract][bCreated] = true;
			g_PlayerQuests[client][contract][bTurned] = SQL_FetchInt(queryH, 2) == 1 ? true : false;
		}
	}
	Contract_SetContract(client, quest);
}

public Contract_ParsePorgressString(char[] string, int client, int contract)
{
	new String:items[MAXQUESTTASKS][11];
	new count = ExplodeString(string, ";", items, MAXQUESTTASKS, 11);
	if (count > 0)
	{
		for (new i = 0; i < MAXQUESTTASKS; i++)
		{
			g_PlayerProgress[client][contract][i] = StringToInt(items[i]);
		}
	}
}

stock int Contract_TickCondition(int client, QuestConds cond, int mult = 1)
{
	int iCondSlot = Contract_FindSlotWithCondition(client, cond);
	if(iCondSlot != -1)
	{
		Contract_AddProgress(client, iCondSlot, g_PlayersQuestTasks[client][iCondSlot][iCP] * mult);
	}
}

public int Contract_FindSlotWithCondition(int client, QuestConds cond)
{
	for (new i = 0; i < MAXQUESTTASKS; i++)
	{
		if (g_PlayersQuestTasks[client][i][iCond] == cond)return i;
	}
	return -1;
}

public QuestConds Contract_GetConditionByString(char[] string)
{
	for(new i = 0;i<_:QuestConds;i++){
		if (StrEqual(g_QuestConditions[i], string)) return view_as<QuestConds>(i);
	}
	return QUEST_COND_NO_COND;
}

public Contract_AddProgress(int client, int slot, int points)
{
	// Map Filter
	if (StrContains(g_sMap, g_PlayersQuestTasks[client][slot][sMap]) == -1)return;
	
	// Class Filter
	if (g_PlayersQuestTasks[client][slot][iClass] > 0)
		if (_:TF2_GetPlayerClass(client) != g_PlayersQuestTasks[client][slot][iClass])return;
	
	int t_OldValues[MAXQUESTTASKS];
	t_OldValues = g_PlayerProgressBuffer[client];
	
	if (
		g_PlayerProgressBuffer[client][0] < g_PlayersQuestTasks[client][0][iLimit]
		&& g_PlayerProgressBuffer[client][slot] < g_PlayersQuestTasks[client][slot][iLimit]
	) g_PlayerProgressBuffer[client][0] += points;
	if (slot > 0 && g_PlayerProgressBuffer[client][slot] < g_PlayersQuestTasks[client][slot][iLimit])g_PlayerProgressBuffer[client][slot]++;
	
	g_PlayerProgressBuffer[client][0] = Math_Clamp(g_PlayerProgressBuffer[client][0], 0, g_PlayersQuestTasks[client][0][iLimit]);
	g_PlayerProgressBuffer[client][slot]= Math_Clamp(g_PlayerProgressBuffer[client][slot], 0, g_PlayersQuestTasks[client][slot][iLimit]);
	
	bool isCompleted, isChanged;
	
	// Check if anything changed
	for (new i = 0; i < MAXQUESTTASKS; i++)
	{
		if(t_OldValues[i] != g_PlayerProgressBuffer[client][i])
		{
			isChanged = true;
			if(i == 0)
				if(g_PlayerProgressBuffer[client][0] == g_PlayersQuestTasks[client][0][iLimit])
					isCompleted = true;
					
			if(g_PlayerProgressBuffer[client][i] == g_PlayersQuestTasks[client][i][iLimit])
			{
				if(i == 0)
					PrintToChatAll("\x05%N \x03has completed their primary objective for '\x05%s\x03' contract.", client, g_PlayerContract[client][sName]);
				else 
					PrintToChatAll("\x05%N \x03has completed an incredibly difficult bonus objective for '\x05%s\x03' contract.", client, g_PlayerContract[client][sName]);
					
			}
			
				
		}
	}
	char sCmd[64];
	if(isChanged)
	{
		int iDiff = g_PlayersQuestTasks[client][slot][iDifficulty];
		if (isCompleted)Format(sCmd, sizeof(sCmd), "playgamesound %s", g_SoundsQuestCompleted[iDiff]);
		else Format(sCmd, sizeof(sCmd), "playgamesound %s", g_SoundsQuest[iDiff]);
		if(!g_QuestHUDYellow[client]) ClientCommand(client, sCmd);
		g_QuestHUDYellow[client] = true;
		g_PlayerContract[client][bUpdated] = true;
		Exp_AddPoints(client, (iDiff+1) * points, false, "completing an objective");
	}
	
}