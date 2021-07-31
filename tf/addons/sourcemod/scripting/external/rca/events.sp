// ===
// teamplay_point_captured
// ===

public Action evPointCaptured(Handle:hEvent, const String:szName[], bool:bDontBroadcast)
{
	if (DEBUG == 1)PrintToServer("evPointCaptured");
	new String:cappers[1024];
	GetEventString(hEvent,"cappers",cappers,sizeof(cappers));
    //int iTeam = GetEventInt(hEvent, "team");
	int len = strlen(cappers);
	for (new i = 0; i < len; i++)
	{
		int client = cappers{i};
		Exp_AddPoints(client, 40, false, "capturing a point");
		
	}  
    return Plugin_Continue;
}

public Action evFlagEvent(Handle:hEvent, const String:szName[], bool:bDontBroadcast)
{
    new attacker = GetEventInt(hEvent, "player");
    //new victim = GetEventInt(hEvent, "carrier");
    int type = GetEventInt(hEvent, "eventtype");
    if(type == 2)
    {
		Contract_TickCondition(attacker, QUEST_COND_FLAG_CAPTURE);
   	}
}

// ===
// killed_capping_player
// ===

public Action evKilledCapturing(Handle:hEvent, const String:szName[], bool:bDontBroadcast)
{
	if (DEBUG == 1)PrintToServer("evKilledCapturing");
    new attacker = GetEventInt(hEvent, "killer");
    new victim = GetEventInt(hEvent, "victim");

    if(attacker == victim){
    	return Plugin_Continue;
    }
	Exp_AddPoints(attacker, 40, false, "killing a capping player");
    
    return Plugin_Continue;
}

// ===
// player_death
// ===

public Action evPlayerDeath(Handle:hEvent, const String:szName[], bool:bDontBroadcast)
{
	if (DEBUG == 1)PrintToServer("evPlayerDeath");
    int client = GetClientOfUserId(GetEventInt(hEvent, "userid"));
    int attacker = GetClientOfUserId(GetEventInt(hEvent, "attacker"));
    int inflictor = GetEventInt(hEvent, "inflictor_entindex");
    int flags = GetEventInt(hEvent, "death_flags");
    int custom = GetEventInt(hEvent, "customkill");
	
	SetVariantString("");
	AcceptEntityInput(client, "SetCustomModel");
	RemoveValveHat(client,true);
	
    if(0 < client <= MaxClients && IsClientInGame(client))
    {
    	Pets_KillPet(client);
		if( 0 < attacker <= MaxClients)
		{
			if(attacker != client){
				g_PlayerCounters[attacker][COUNTER_KILLS]++;
				
				Players[attacker][iKillstreak]++;
				
			    if(g_PlayerCounters[attacker][COUNTER_KILLS] % 5 == 0 && g_PlayerCounters[attacker][COUNTER_KILLS]>0){
			    	Contract_TickCondition(attacker, QUEST_COND_5_KILLS_IN_LIFE);
			   	}
			   	
				new String:classname[32];
				GetEntityClassname(inflictor, classname, 32);
				if(StrEqual(classname, "obj_sentrygun"))
				{
					g_PlayerCounters[attacker][SENTRY_KILLS]++;
				}
				
			    if(g_PlayerCounters[attacker][SENTRY_KILLS] % 6 == 0 && g_PlayerCounters[attacker][SENTRY_KILLS]>0){
			    	Contract_TickCondition(attacker, QUEST_COND_6_KILLS_SG);
			   	}
			   	
			    if(Players[attacker][iKillstreak] % 5 == 0 && Players[attacker][iKillstreak]>0){
			  		Exp_AddPoints(attacker, Players[attacker][iKillstreak] * 10, false, "getting a killstreak");
			   	}
		    
			    if(flags & TF_DEATHFLAG_KILLERDOMINATION) {
			  		Exp_AddPoints(attacker, 30, false, "dominating a player");
			  		
			    	Contract_TickCondition(attacker, QUEST_COND_DOMINATE);
			  	}
		    
			    if(TF2_IsPlayerInCondition(attacker, TFCond_HalloweenCritCandy)) {
			    	Contract_TickCondition(attacker, QUEST_COND_CRUMPKIN_KILL);
			  	}
		    
			    if(TF2_IsPlayerInCondition(attacker, TFCond_HalloweenKart)) {
			    	Contract_TickCondition(attacker, QUEST_COND_KILL_IN_KART);
			  	}
		    
			    if(TF2_IsPlayerInCondition(attacker, TFCond_HalloweenInHell)) {
			    	Contract_TickCondition(attacker, QUEST_COND_KILL_IN_HELL);
			  	}
		    
			    if(TF2_IsPlayerInCondition(attacker, TFCond_EyeaductUnderworld)) {
			    	Contract_TickCondition(attacker, QUEST_COND_KILL_IN_PURGATORY);
			  	}
			  	
			  	if(custom & TF_CUSTOM_PUMPKIN_BOMB == TF_CUSTOM_PUMPKIN_BOMB) {
			    	Contract_TickCondition(attacker, QUEST_COND_PUMPKIN_KILL);
			  	}
			  	
				int iHoldWeapon = GetEntPropEnt(attacker, Prop_Send, "m_hActiveWeapon");
				
				if(iHoldWeapon > 0)
				{
					if(g_WeaponID[iHoldWeapon]>0){
						OpenItemContext(client, g_WeaponIndex[iHoldWeapon], true, attacker);
					}
					
					if(g_WeaponAttributes[iHoldWeapon][16] > 0)
					{
						ClientCommand(attacker, "sm_ban #%d %d Ban-hammer'ed",GetClientUserId(client),g_WeaponAttributes[iHoldWeapon][16]);
					}
				}
				
			    Contract_TickCondition(attacker, QUEST_COND_KILL);
			}
		}
   	}
   	return Plugin_Continue;

}

// ===
// player_team
// ===

public Action evPlayerTeam(Handle:hEvent, const String:szName[], bool:bDontBroadcast)
{
	if (DEBUG == 1)PrintToServer("evPlayerTeam");
    new client = GetClientOfUserId(GetEventInt(hEvent, "userid"));
    new iOldTeam = GetEventInt(hEvent, "oldteam");
    new iNewTeam = GetEventInt(hEvent, "team");
    
    if((iNewTeam == 1 || iNewTeam == 0) && iOldTeam > 1 && iOldTeam != iNewTeam)
    {
   		Pets_KillPet(client);
   	}
    
   	return Plugin_Continue;

}

// ===
// teamplay_round_start
// ===

public Action evRoundStart(Handle:hEvent, const String:szName[], bool:bDontBroadcast)
{
	//Event_HWN2019_SpawnEggs();
}

// ===
// teamplay_round_win
// ===

public Action evRoundEnd(Handle:hEvent, const String:szName[], bool:bDontBroadcast)
{
	Contracts_SaveProgress();
}

// ===
// teamplay_flag_event
// ===

public Action evFlagStatus(Handle:hEvent, const String:szName[], bool:bDontBroadcast)
{
    int client = GetClientOfUserId(GetEventInt(hEvent, "userid"));
    if(TF2_IsPlayerInCondition(client, TFCond_EyeaductUnderworld))
    {
		Contract_TickCondition(client, QUEST_COND_DEPOSIT_SOUL);
   	}
}

// ===
// player_score_changed
// ===

public Action evPlayerScore(Handle:hEvent, const String:szName[], bool:bDontBroadcast)
{
    int client = GetEventInt(hEvent, "player");
    int delta = GetEventInt(hEvent, "delta");
	Contract_TickCondition(client, QUEST_COND_SCORE, delta);
}

// ===
// teamplay_win_panel
// ===

public Action evWinPanel(Handle:hEvent, const String:szName[], bool:bDontBroadcast)
{
	int iPlayer1 = GetEventInt(hEvent, "player_1");
	int iPlayer2 = GetEventInt(hEvent, "player_2");
	int iPlayer3 = GetEventInt(hEvent, "player_3");
	if(IsValidPlayer(iPlayer1) && IsClientInGame(iPlayer1))
	{
		Contract_TickCondition(iPlayer1, QUEST_COND_MVP);
	}
	if(IsValidPlayer(iPlayer2) && IsClientInGame(iPlayer2))
	{
		Contract_TickCondition(iPlayer2, QUEST_COND_MVP);
	}
	if(IsValidPlayer(iPlayer3) && IsClientInGame(iPlayer3))
	{
		Contract_TickCondition(iPlayer3, QUEST_COND_MVP);
	}
}

public Action evObjectDestroyed(Handle:hEvent, const String:szName[], bool:bDontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(hEvent, "attacker"));
	int type = GetEventInt(hEvent, "objecttype");
	if(type == 3)
		Contract_TickCondition(client, QUEST_COND_SAPPER_REMOVE);
}

		

// ===
// npc_hurt
// ===

public Action evNPCHurt(Handle:hEvent, const String:szName[], bool:bDontBroadcast)
{
	if (DEBUG == 1)PrintToServer("evNPCHurt");
	new client = GetClientOfUserId(GetEventInt(hEvent, "attacker_player"));
	new victim = GetEventInt(hEvent, "entindex");
	if (!IsValidPlayer(client))return Plugin_Continue;
	
	new ClientWeapons[4];
	new ActiveWeapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
	for (new i = 0; i < 4; i++)ClientWeapons[i] = GetPlayerWeaponSlot(client, i);
	
	new String:classname[32];
	GetEntityClassname(victim, classname, 32);
	
	// ***************
	// Dichlorvos | If Damage to sapper then Damage it
	// ***************
	
	if(StrEqual(classname,"obj_attachment_sapper")){
		
		if(g_WeaponAttributes[ActiveWeapon][1] > 0){
			new metal = GetEntProp(client, Prop_Data, "m_iAmmo", 4, 3);
			new iCost = g_WeaponAttributes[ActiveWeapon][1];
			if(metal < iCost) {
				bDontBroadcast = false;
				SetEventInt(hEvent, "damageamount", 0);
				SetEventBroadcast(hEvent, false);
				return Plugin_Continue;
			}
			
			SetEntProp(client, Prop_Data, "m_iAmmo",metal-iCost, 4, 3);
			
			SetVariantString("50");
			AcceptEntityInput(victim,"RemoveHealth");
			
			int iHealth = GetEntProp(victim, Prop_Send, "m_iHealth");
			
			if(iHealth < 1){
				new Handle:sEvent = CreateEvent("object_destroyed");
				if (sEvent == INVALID_HANDLE)
					return Plugin_Continue;
				
				SetEventInt(sEvent, "userid", GetClientUserId(GetEntPropEnt(victim,Prop_Send,"m_hBuilder")));
				SetEventInt(sEvent, "attacker", GetClientUserId(client));
				SetEventInt(sEvent, "assister", 0);
				SetEventString(sEvent, "weapon", "the_capper");
				SetEventInt(sEvent, "weaponid", 41);
				SetEventInt(sEvent, "objecttype", 3); //Sapper
				SetEventInt(sEvent, "index", victim);
				SetEventBool(sEvent, "was_building", false);
				SetEventBool(sEvent, "isfake", true);
				FireEvent(sEvent);
			}
			SetEventInt(hEvent, "damageamount", 50);
		}
	}

	return Plugin_Continue;
}

public Action Merasmus_PropOnTakeDamage(iVictim, &iAtker, &iInflictor, &Float:flDamage, &iDmgType, &iWeapon, Float:vDmgForce[3], Float:vDmgPos[3], iDmgCustom)
{
}

public void TF2_OnConditionAdded(int client, TFCond cond)
{
	if(cond == TFCond_HalloweenCritCandy)
	{
		Contract_TickCondition(client, QUEST_COND_PUMPKIN_GRAB);
	}
}

public void TF2_OnConditionRemoved(int client, TFCond cond)
{
	if(cond == TFCond_EyeaductUnderworld && IsPlayerAlive(client))
	{
		Contract_TickCondition(client, QUEST_COND_ESCAPE_HELL);
	}
}