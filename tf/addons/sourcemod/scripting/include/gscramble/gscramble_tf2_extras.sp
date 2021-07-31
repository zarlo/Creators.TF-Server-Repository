/************************************************************************
*************************************************************************
gScramble tf2 extras
Description:
	Snippets that make working with tf2 more fun! 
*************************************************************************
*************************************************************************

This plugin is free software: you can redistribute 
it and/or modify it under the terms of the GNU General Public License as
published by the Free Software Foundation, either version 3 of the License, or
later version. 

This plugin is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this plugin.  If not, see <http://www.gnu.org/licenses/>.
*************************************************************************
*************************************************************************
File Information
$Id$
$Author$
$Revision$
$Date$
$LastChangedBy$
$LastChangedDate$
$URL$
$Copyright: (c) Tf2Tmng 2009-2015$
*************************************************************************
*************************************************************************
*/
stock GetRoundTimerInformation(bool delay = false)
{
	if (delay)
	{
		CreateTimer(0.5, TimerRoundTimer);
		return;
	}
	#if defined DEBUG
	LogToFile("addons/sourcemod/logs/gscramble.debug.txt", "calling Round Timer Function");
	#endif
	new round_timer = -1;
	new Float:best_end_time = 1000000000000.0;    //a very large "time"
	new Float:timer_end_time;
	new bool:found_valid_timer = false;
	new bool:timer_is_disabled = true;
	new bool:timer_is_paused = true;

	while ( (round_timer = FindEntityByClassname(round_timer, "team_round_timer")) != -1) {
		//Make sure this timer is enabled
		timer_is_paused = bool:GetEntProp(round_timer, Prop_Send, "m_bTimerPaused");
		timer_is_disabled = bool:GetEntProp(round_timer, Prop_Send, "m_bIsDisabled");
		/** dont think i need this anymore
		if (timer_is_disabled || timer_is_paused)
		{
			#if defined DEBUG
			LogToFile("addons/sourcemod/logs/gscramble.debug.txt", "paused or disabled timer ent");
			#endif
			continue;
		}*/
		//End time is what we're interested in... fortunately, it works
		// (getting the current time remaining does NOT work as of late November 2010)
		timer_end_time = GetEntPropFloat(round_timer, Prop_Send, "m_flTimerEndTime");
		#if defined DEBUG
		LogToFile("addons/sourcemod/logs/gscramble.debug.txt", "TIME %i", RoundFloat(timer_end_time));
		#endif
		
		if (!timer_is_paused && !timer_is_disabled && (timer_end_time <= best_end_time || !found_valid_timer)) {
			best_end_time = timer_end_time;
			found_valid_timer = true;
		}
	}
	if (found_valid_timer) {
		g_fRoundEndTime = best_end_time;
		g_bRoundIsTimed = true;
	} else {
		#if defined DEBUG
		LogToFile("addons/sourcemod/logs/gscramble.debug.txt", "no timer ent found?");
		#endif
		g_RoundState = normal;
		g_bRoundIsTimed = false;
	}
}

public Action:TimerRoundTimer(Handle:timer)
{
	GetRoundTimerInformation();
}


/*
public TF2_GetRoundTimeLeft(Handle:plugin, numparams)
{
	if (g_RoundState == normal && g_bRoundIsTimed)
	{
		return RoundFloat(GetGameTime() - g_fRoundEndTime);
	}
	else return 0;
}*/

stock bool:TF2_HasBuilding(client)
{
	if (TF2_ClientBuilding(client, "obj_*"))
	{
		return true;
	}
	
	return false;
}

stock bool:TF2_ClientBuilding(client, const String:building[])
{
	new iEnt = -1;
	
	while ((iEnt = FindEntityByClassname(iEnt, building)) != -1)
	{
		if (GetEntDataEnt2(iEnt, FindSendPropInfo("CBaseObject", "m_hBuilder")) == client)
		{
			return true;
		}
	}
	
	return false;
}

stock TF2_ResetSetup()
{
	g_iTimerEnt = FindEntityByClassname(-1, "team_round_timer");
	new setupDuration = GetTime() - g_iRoundStartTime; 
	SetVariantInt(setupDuration);
	AcceptEntityInput(g_iTimerEnt, "AddTime");
	g_iRoundStartTime = GetTime();
}

stock bool:TF2_IsClientUberCharged(client)
{
	if (!IsPlayerAlive(client))
	{
		return false;
	}
	
	new TFClassType:class = TF2_GetPlayerClass(client);
	if (class == TFClass_Medic)
	{			
		new iIdx = GetPlayerWeaponSlot(client, 1);
		if (iIdx > 0)
		{
			decl String:sClass[33];
			GetEntityNetClass(iIdx, sClass, sizeof(sClass));
			if (StrEqual(sClass, "CWeaponMedigun", true))
			{
				new Float:chargeLevel = GetEntPropFloat(iIdx, Prop_Send, "m_flChargeLevel");
				if (chargeLevel >= GetConVarFloat(cvar_BalanceChargeLevel))
				{
					return true;
				}
			}
		}
	}
	return false;
}

stock bool:TF2_IsClientUbered(client)
{
	if (TF2_IsPlayerInCondition(client, TFCond_Ubercharged) 
		|| TF2_IsPlayerInCondition(client, TFCond_Kritzkrieged) 
		|| TF2_IsPlayerInCondition(client, TFCond_UberchargeFading)
		|| TF2_IsPlayerInCondition(client, TFCond_UberBulletResist)
		|| TF2_IsPlayerInCondition(client, TFCond_UberBlastResist)
		|| TF2_IsPlayerInCondition(client, TFCond_UberFireResist))
	{
		#if defined DEBUG
		LogToFile("addons/sourcemod/logs/gscramble.debug.txt", "Found Ubercond player");
		#endif
		return true;
	}
	
	return false;
}

stock TF2_GetPlayerDominations(client)
{
	new offset = FindSendPropInfo("CTFPlayerResource", "m_iActiveDominations"),
		ent = FindEntityByClassname(-1, "tf_player_manager");
	if (ent != -1)
	{
		return GetEntData(ent, (offset + client*4), 4);
	}
	
	return 0;
}

stock TF2_GetTeamDominations(team)
{
	new dominations;
	for (new i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && GetClientTeam(i) == team)
		{
			dominations += TF2_GetPlayerDominations(i);
		}
	}
	return dominations;
}

stock bool:TF2_IsClientOnlyMedic(client)
{
	if (TFClassType:TF2_GetPlayerClass(client) != TFClass_Medic)
	{
		return false;
	}
	
	new clientTeam = GetClientTeam(client);
	for (new i = 1; i <= MaxClients; i++)
	{
		if (i != client && IsClientInGame(i) && GetClientTeam(i) == clientTeam && TFClassType:TF2_GetPlayerClass(i) == TFClass_Medic)
		{
			return false;
		}
	}
	
	return true;
}

public Action:UserMessageHook_Class(UserMsg:msg_id, Handle:bf, const players[], playersNum, bool:reliable, bool:init) 
{	
	new String:strMessage[50];
	BfReadString(bf, strMessage, sizeof(strMessage), true);
	
	if (StrContains(strMessage, "#TF_TeamsSwitched", true) != -1)
	{
		SwapPreferences();
		new oldRed = g_aTeams[iRedWins], oldBlu = g_aTeams[iBluWins];
		
		g_aTeams[iRedWins] = oldBlu;
		g_aTeams[iBluWins] = oldRed;
		
		g_iTeamIds[0] == TEAM_RED ? (g_iTeamIds[0] = TEAM_BLUE) :  (g_iTeamIds[0] = TEAM_RED);
		g_iTeamIds[1] == TEAM_RED ? (g_iTeamIds[1] = TEAM_BLUE) :  (g_iTeamIds[1] = TEAM_RED);
	}
	
	return Plugin_Continue;
}

stock TF2_RemoveRagdolls()
{
	new iEnt = -1;
	while ((iEnt = FindEntityByClassname(iEnt, "tf_ragdoll")) != -1)
	{
		AcceptEntityInput(iEnt, "Kill");
	}
}

stock Float:GetCartProgress()
{
	new iEnt = -1,
		Float:fTotalProgress_1,
		Float:fTotalProgress_2,
		bool:bFoundCart = false; 
		
	while((iEnt = FindEntityByClassname(iEnt, "team_train_watcher")) != -1 )
	{
		if (IsValidEntity(iEnt))
		{
			if (GetEntProp(iEnt, Prop_Data, "m_bDisabled"))
				continue;
			if (!bFoundCart)
			{
				fTotalProgress_1 = GetEntPropFloat(iEnt, Prop_Send, "m_flTotalProgress");
				bFoundCart = true;
				continue;
			}
			fTotalProgress_2 = GetEntPropFloat(iEnt, Prop_Send, "m_flTotalProgress");
			break;
		}
	}
	if (fTotalProgress_1 > fTotalProgress_2)
		return fTotalProgress_1;
	return fTotalProgress_2;
}

stock bool:DoesClientHaveIntel(client)
{
	new iEnt = -1;
	while ((iEnt = FindEntityByClassname(iEnt, "item_teamflag")) != -1) 
	{
		if (IsValidEntity(iEnt))
		{
			if (GetEntPropEnt(iEnt, Prop_Data, "m_hMoveParent") == client)
				return true;
		}
	}
	return false;
}
