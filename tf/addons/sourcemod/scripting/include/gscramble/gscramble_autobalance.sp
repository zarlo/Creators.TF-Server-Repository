/************************************************************************
*************************************************************************
gScramble autobalance logic
Description:
    Autobalance logic for the gscramble addon
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

new g_iImmunityDisabledWarningTime;

stock GetLargerTeam()
{
    if (GetTeamClientCount(TEAM_RED) > GetTeamClientCount(TEAM_BLUE))
    {
        return TEAM_RED;
    }
    return TEAM_BLUE;
}

stock GetSmallerTeam()
{
    return GetLargerTeam() == TEAM_RED ? TEAM_BLUE:TEAM_RED;
}

public Action:timer_StartBalanceCheck(Handle:timer, any:client)
{
    if (g_aTeams[bImbalanced] && BalancePlayer(client))
    {
        CheckBalance(true);
    }

    return Plugin_Handled;
}

bool:BalancePlayer(client)
{
    if (!TeamsUnbalanced(false))
    {
        return true;
    }

    new team, bool:overrider = false, iTime = GetTime();
    new big = GetLargerTeam();
    team = big == TEAM_RED?TEAM_BLUE:TEAM_RED;

    /**
    checks for preferences to override the client. will grab any client that stated a prefence regardless of status.
    */
    if (GetConVarBool(cvar_Preference))
    {
        for (new i = 1; i <= MaxClients; i++)
        {
            if (IsClientInGame(i) && GetClientTeam(i) == big && g_aPlayers[client][iTeamPreference] == team)
            {
                overrider = true;
                client = i;
                break;
            }
        }
    }

    if (!overrider)
    {
        if (!IsClientValidBalanceTarget(client) /*|| GetPlayerPriority(client) < 0*/)
        {
            return false;
        }
    }
    else if (IsPlayerAlive(client))
    {
        CreateTimer(0.5, Timer_BalanceSpawn, GetClientUserId(client));
    }

    new String:sName[MAX_NAME_LENGTH + 1], String:sTeam[32];
    GetClientName(client, sName, 32);
    team == TEAM_RED ? (sTeam = "RED") : (sTeam = "BLU");
    g_bBlockDeath = true;
    ChangeClientTeam(client, team);
    g_bBlockDeath = false;
    g_aPlayers[client][iBalanceTime] = iTime + (GetConVarInt(cvar_BalanceTime) * 60);

    if (!IsFakeClient(client))
    {
        new Handle:event = CreateEvent("teamplay_teambalanced_player");
        SetEventInt(event, "player", client);
        SetEventInt(event, "team", team);
        SetupTeamSwapBlock(client);
        FireEvent(event);
    }

    LogAction(client, -1, "\"%L\" has been auto-balanced to %s.", client, sTeam);
    if (!g_bSilent)
        PrintToChatAll("\x01\x04[SM]\x01 %t", "TeamChangedAll", sName, sTeam);
    g_aTeams[bImbalanced]=false;

    return true;
}

stock StartForceTimer()
{
    if (g_bBlockDeath)
    {
        return;
    }

    if (g_hForceBalanceTimer != INVALID_HANDLE)
    {
        KillTimer(g_hForceBalanceTimer);
        g_hForceBalanceTimer = INVALID_HANDLE;
    }

    new Float:fDelay;

    if (1 > (fDelay = GetConVarFloat(cvar_MaxUnbalanceTime)))
    {
        return;
    }

    g_hForceBalanceTimer = CreateTimer(fDelay, Timer_ForceBalance);
}

/**
    forces balance if teams stay unbalacned too long
*/
public Action:Timer_ForceBalance(Handle:timer)
{
    g_hForceBalanceTimer = INVALID_HANDLE;

    if (TeamsUnbalanced(false))
    {
        if (!g_bSilent)
            PrintToChatAll("\x01\x04[SM]\x01 %t", "ForceMessage");
        BalanceTeams(true);
    }

    g_aTeams[bImbalanced] = false;

    return Plugin_Handled;
}

CheckBalance(bool:post=false)
{
    if (!g_bHooked)
    {
        #if defined DEBUG
        LogToFile("addons/sourcemod/logs/gscramble.debug_spammy.txt", "Ending checkbalance because not hooked");
        #endif
        return;
    }

    if (g_hCheckTimer != INVALID_HANDLE)
    {
        #if defined DEBUG
        LogToFile("addons/sourcemod/logs/gscramble.debug_spammy.txt", "Ending checkbalance because checktimer running");
        #endif
        return;
    }

    if (!g_bAutoBalance)
    {
        #if defined DEBUG
        LogToFile("addons/sourcemod/logs/gscramble.debug_spammy.txt", "Ending checkbalance because ab flag set false");
        #endif
        return;
    }

    if (g_bBlockDeath)
    {
        #if defined DEBUG
        LogToFile("addons/sourcemod/logs/gscramble.debug_spammy.txt", "Ending checkbalance because scramble block death running");
        #endif
        return;
    }

    if (post)
    {
        if (g_hCheckTimer == INVALID_HANDLE)
        {
            g_hCheckTimer = CreateTimer(0.5, timer_CheckBalance);
        }
        #if defined DEBUG
        LogToFile("addons/sourcemod/logs/gscramble.debug_spammy.txt", "running checkbalance timer");
        #endif
        return;
    }
    if (TeamsUnbalanced())
    {
        if (IsOkToBalance() && !g_aTeams[bImbalanced] && g_hBalanceFlagTimer == INVALID_HANDLE)
        {
            new delay = GetConVarInt(cvar_BalanceActionDelay);
            if (!g_bSilent && delay > 1)
            {
                PrintToChatAll("\x01\x04[SM]\x01 %t", "FlagBalance", delay);
            }
            g_hBalanceFlagTimer = CreateTimer(float(delay), timer_BalanceFlag);
        }
        if (g_RoundState == preGame || g_RoundState == bonusRound || g_RoundState == suddenDeath)
        {
            if (g_hBalanceFlagTimer != INVALID_HANDLE)
            {
                KillTimer(g_hBalanceFlagTimer);
                g_hBalanceFlagTimer = INVALID_HANDLE;
            }
            g_aTeams[bImbalanced] = true;
        }
    }
    else
    {
        if (g_hForceBalanceTimer != INVALID_HANDLE)
        {
            KillTimer(g_hForceBalanceTimer);
            g_hForceBalanceTimer = INVALID_HANDLE;
        }
        g_aTeams[bImbalanced] = false;
        if (g_hBalanceFlagTimer != INVALID_HANDLE)
        {
            KillTimer(g_hBalanceFlagTimer);
            g_hBalanceFlagTimer = INVALID_HANDLE;
        }

    }
}

/**
flags the teams as being unbalanced
*/
public Action:timer_BalanceFlag(Handle:timer)
{
    g_hBalanceFlagTimer = INVALID_HANDLE;

    if (TeamsUnbalanced())
    {
        StartForceTimer();
        g_aTeams[bImbalanced] = true;
    }

    return Plugin_Handled;
}

public Action:timer_CheckBalance(Handle:timer)
{
    g_hCheckTimer = INVALID_HANDLE;
    CheckBalance();

    return Plugin_Handled;
}

stock bool:TeamsUnbalanced(bool:force=true)
{
    new iDiff = GetAbsValue(GetTeamClientCount(TEAM_RED), GetTeamClientCount(TEAM_BLUE));
    new iForceLimit = GetConVarInt(cvar_ForceBalanceTrigger);
    new iBalanceLimit = GetConVarInt(cvar_BalanceLimit);

    if (iDiff >= iBalanceLimit)
    {
        if (g_RoundState == normal && force && iForceLimit > 1 && iDiff >= iForceLimit)
        {
            BalanceTeams(true);

            if (g_hBalanceFlagTimer != INVALID_HANDLE)
            {
                KillTimer(g_hBalanceFlagTimer);
                g_hBalanceFlagTimer = INVALID_HANDLE;
            }

            return false;
        }

        return true;
    }

    return false;
}

stock BalanceTeams(bool:respawn=true)
{
    if (!TeamsUnbalanced(false) || g_bBlockDeath)
    {
        return;
    }

    new team = GetLargerTeam(), counter,
        smallTeam = GetSmallerTeam(),
        swaps = GetAbsValue(GetTeamClientCount(TEAM_RED), GetTeamClientCount(TEAM_BLUE)) / 2,
        iTeamSize = GetClientCount();

    new iFatTeam[iTeamSize][2];

    for (new i = 1; i <= MaxClients; i++)
    {
        if (!IsClientInGame(i))
        {
            continue;
        }

        if (IsValidSpectator(i))
        {
            iFatTeam[counter][0] = i;
            iFatTeam[counter][1] = 90;

            counter++;
        }
        else if (GetClientTeam(i) == team)
        {
            // player wants to be on the other team, give him preference
            if (GetConVarBool(cvar_Preference) && g_aPlayers[i][iTeamPreference] == smallTeam && !TF2_IsClientUbered(i))
            {
                iFatTeam[counter][1] = 100;
            }
            else
                iFatTeam[counter][1] = GetPlayerPriority(i);
            //else if (IsClientValidBalanceTarget(i))
            //{
            //}
            //else
            //{
                //iFatTeam[counter][1] = -5;
            //}
            iFatTeam[counter][0] = i;
            counter++;
        }
    }

    SortCustom2D(iFatTeam, counter, SortIntsDesc); // sort the array so low prio players are on the bottom
    g_bBlockDeath = true;

    for (new i = 0; swaps-- > 0 && i < counter; i++)
    {
        if (iFatTeam[i][0])
        {
            new bWasSpec = false;

            if (GetClientTeam(iFatTeam[i][0]) == 1)
            {
                bWasSpec = true;
            }

            new String:clientName[MAX_NAME_LENGTH + 1], String:sTeam[4];
            GetClientName(iFatTeam[i][0], clientName, 32);

            if (team == TEAM_RED)
            {
                sTeam = "Blu";
            }
            else
            {
                sTeam = "Red";
            }

            ChangeClientTeam(iFatTeam[i][0], team == TEAM_BLUE ? TEAM_RED : TEAM_BLUE);

            if (bWasSpec)
            {
                TF2_SetPlayerClass(iFatTeam[i][0], TFClass_Scout);
            }

            if (!g_bSilent)
                PrintToChatAll("\x01\x04[SM]\x01 %t", "TeamChangedAll", clientName, sTeam);

            SetupTeamSwapBlock(iFatTeam[i][0]);
            LogAction(iFatTeam[i][0], -1, "\"%L\" has been force-balanced to %s.", iFatTeam[i][0], sTeam);

            if (respawn)
            {
                CreateTimer(0.5, Timer_BalanceSpawn, GetClientUserId(iFatTeam[i][0]), TIMER_FLAG_NO_MAPCHANGE);
            }

            if (!IsFakeClient(iFatTeam[i][0]))
            {
                new Handle:event = CreateEvent("teamplay_teambalanced_player");
                SetEventInt(event, "player", iFatTeam[i][0]);
                g_aPlayers[iFatTeam[i][0]][iBalanceTime] = GetTime() + (GetConVarInt(cvar_BalanceTime) * 60);
                SetEventInt(event, "team", team == TEAM_BLUE ? TEAM_RED : TEAM_BLUE);
                FireEvent(event);
            }
        }
    }
    g_bBlockDeath = false;
    g_aTeams[bImbalanced] = false;
    return;
}

stock bool:IsOkToBalance()
{
    if (g_RoundState == normal)
    {
        new iBalanceTimeLimit = GetConVarInt(cvar_BalanceTimeLimit);

        if (iBalanceTimeLimit && g_bRoundIsTimed)
        {
            if ((g_fRoundEndTime - GetGameTime()) < float(iBalanceTimeLimit))
            {
            #if defined DEBUG
            LogToFile("addons/sourcemod/logs/gscramble.debug.txt", "disabling due to balance time");
            #endif
                return false;
            }
        }

        new Float:fProgress = GetConVarFloat(cvar_ProgressDisable);
        #if defined DEBUG
        LogToFile("addons/sourcemod/logs/gscramble.debug.txt", "Progress = %f", GetCartProgress());
        #endif
        if (fProgress > 0.0 && GetCartProgress() >= fProgress)
        {
            #if defined DEBUG
            LogToFile("addons/sourcemod/logs/gscramble.debug.txt", "disabling due to cart progress");
            #endif
            return false;
        }

        return true;
    }
    switch (g_RoundState)
    {
        case suddenDeath:
        {
            #if defined DEBUG
            LogToFile("addons/sourcemod/logs/gscramble.debug.txt", "disabling due to roundstate suddendeath");
            #endif
            return false;
        }

        case preGame:
        {
            #if defined DEBUG
            LogToFile("addons/sourcemod/logs/gscramble.debug.txt", "disabling due to roundstate pregame");
            #endif
            return false;
        }

        case setup:
        {
            #if defined DEBUG
            LogToFile("addons/sourcemod/logs/gscramble.debug.txt", "disabling due to roundstate setup");
            #endif
            return false;
        }

        case bonusRound:
        {
            #if defined DEBUG
            LogToFile("addons/sourcemod/logs/gscramble.debug.txt", "disabling due to roundstate bonusround");
            #endif
            return false;
        }
    }
    return true;
}

public Action:Timer_BalanceSpawn(Handle:timer, any:id)
{
    new client;

    if ((client = (GetClientOfUserId(id))))
    {
        if (!IsPlayerAlive(client))
        {
            TF2_RespawnPlayer(client);
        }
    }

    return Plugin_Handled;
}

bool IsClientValidBalanceTarget(client, bool CalledFromPrio = false)
{
    if (IsClientInGame(client) && IsValidTeam(client))
    {
        if (IsFakeClient(client))
        {
            if (GetConVarBool(cvar_AbHumanOnly) && !TF2_IsClientOnlyMedic(client))
            {
                return false;
            }
            #if defined DEBUG
            LogToFile("addons/sourcemod/logs/gscramble.debug.txt", "Is valid target for reason: bot, player: %N", client);
            #endif
            return true;
        }

    // allow client's team prefence to override balance check
        if (GetConVarBool(cvar_Preference))
        {
            new big = GetLargerTeam(),
                pref = g_aPlayers[client][iTeamPreference];
            if (pref && pref != big)
            {
                #if defined DEBUG
                LogToFile("addons/sourcemod/logs/gscramble.debug.txt", "Is valid target for reason: player preference, player: %N", client);
                #endif
                return true;
            }
        }

        if (g_aPlayers[client][iBalanceTime] > GetTime())
        {
            #if defined DEBUG
            LogToFile("addons/sourcemod/logs/gscramble.debug.txt", "Is INVALID target for reason: swapped recently, player: %N", client);
            #endif
            return false;
        }

        if (GetConVarBool(cvar_TeamworkProtect) && g_aPlayers[client][iTeamworkTime] >= GetTime())
        {
            #if defined DEBUG
            LogToFile("addons/sourcemod/logs/gscramble.debug.txt", "Is INVALID target for reason: teamwork protection, player: %N", client);
            #endif
            return false;
        }

        // hard coded protections no one wants to be swapped carrying objective or while ubered
        if (TF2_IsClientUberCharged(client) || TF2_IsClientUbered(client) || DoesClientHaveIntel(client))
            return false;

        if (GetConVarInt(cvar_TopProtect) && !IsNotTopPlayer(client, GetClientTeam(client)))
        {
            #if defined DEBUG
            LogToFile("addons/sourcemod/logs/gscramble.debug.txt", "Flagging immune top protect");
            #endif
            return false;
        }

        if (GetConVarBool(cvar_ProtectOnlyMedic) && TF2_IsClientOnlyMedic(client))
        {
            #if defined DEBUG
            LogToFile("addons/sourcemod/logs/gscramble.debug.txt", "Flagging immune only medic");
            #endif
            return false;
        }

        new iImmunity = e_Protection:GetConVarInt(cvar_BalanceImmunity),
            bool:bAdmin = false,
            bool:bEngie = false;
        switch (iImmunity)
        {
            case admin:
            {
                #if defined DEBUG
                LogToFile("addons/sourcemod/logs/gscramble.debug.txt", "Balance var read: admin");
                #endif
                bAdmin = true;
            }
            case uberAndBuildings:
            {
                #if defined DEBUG
                LogToFile("addons/sourcemod/logs/gscramble.debug.txt", "Balance var read: engie with buildings");
                #endif
                bEngie = true;
            }
            case both:
            {
                #if defined DEBUG
                LogToFile("addons/sourcemod/logs/gscramble.debug.txt", "Balance var read: Both engie + admin");
                #endif
                bAdmin = true;
                bEngie = true;
            }
        }

        if (bEngie)
        {
            if (TF2_HasBuilding(client))
            {
            #if defined DEBUG
            LogToFile("addons/sourcemod/logs/gscramble.debug.txt", "Is INVALID target for reason: engineer building, player: %N", client);
            #endif
                return false;
            }
        }

        if (!CalledFromPrio && bAdmin)
        {
            char flags[32];
            new bool:bSkip = false;

            GetConVarString(cvar_BalanceAdmFlags, flags, sizeof(flags));
            bSkip = SkipBalanceCheck();
            if (!bSkip && IsAdmin(client, flags))
            {
                #if defined DEBUG
                LogToFile("addons/sourcemod/logs/gscramble.debug.txt", "Is INVALID target for reason: admin, player: %N", client);
                #endif
                return false;
            }
        }

        switch (CheckBuddySystem(client))
        {
            case 1:
            {
                #if defined DEBUG
                LogToFile("addons/sourcemod/logs/gscramble.debug.txt", "Is INVALID target for reason: buddy system, player: %N", client);
                #endif
                return false;
            }
            case 2:
            {
                #if defined DEBUG
                LogToFile("addons/sourcemod/logs/gscramble.debug.txt", "Is valid target for reason: buddy system, player: %N", client);
                #endif
                return true;
            }
        }

        if (GetConVarBool(cvar_BalanceDuelImmunity) && TF2_IsPlayerInDuel(client))
            return false;
        #if defined DEBUG
        LogToFile("addons/sourcemod/logs/gscramble.debug.txt", "Is valid target for reason: passed all checks, player: %N", client);
        #endif
        return true;
    }
    return false;
}

CheckBuddySystem(client)
{
    if (g_bUseBuddySystem)
    {
        new buddy;

        if ((buddy = g_aPlayers[client][iBuddy]))
        {
            if (GetClientTeam(buddy) == GetClientTeam(client))
            {
                LogAction(-1, 0, "Flagging client %L invalid because of buddy preference", client);
                return 1;
            }
            else if (IsValidTeam(g_aPlayers[client][iBuddy]))
            {
                LogAction(-1, 0, "Flagging client %L valid because of buddy preference", client);
                return 2;
            }
        }
        if (IsClientBuddy(client))
        {
            return 1;
        }
    }
    return 0;
}

bool SkipBalanceCheck()
{
    if (GetConVarFloat(cvar_BalanceImmunityCheck) > 0.0)
    {
        new iTargets,
            iImmune,
            iTotal;
        char flags[32];
        GetConVarString(cvar_BalanceAdmFlags, flags, sizeof(flags));
        for (new i = 1; i <= MaxClients; i++)
        {
            if (IsClientInGame(i) && IsValidTeam(i))
            {
                if (IsAdmin(i, flags))
                {
                    iImmune++;
                }
                else
                {
                    iTargets++;
                }
            }
        }
        if (iImmune)
        {
            float fPercent;
            iTotal = iImmune + iTargets;
            fPercent = (float(iImmune) / float(iTotal));
            if (fPercent >= GetConVarFloat(cvar_BalanceImmunityCheck))
            {
                if (!g_bSilent && (GetTime() - g_iImmunityDisabledWarningTime) > 300)
                {
                    PrintToChatAll("\x01\x04[SM]\x01 %t", "ImmunityDisabled", RoundFloat(fPercent));
                    g_iImmunityDisabledWarningTime = GetTime();
                    return true;
                }
            }
        }
    }
    return false;
}

/**
* Prioritize people based on active buildings, ubercharge, living/dead, or connection time
* used for the force-balance function
*/
GetPlayerPriority(client)
{
    if (IsFakeClient(client))
    {
        return 50;
    }
    new iPriority;
    if (!IsClientValidBalanceTarget(client, false))
        iPriority -=50;
    if (!IsPlayerAlive(client))
    {
        iPriority += 5;
    }


    if (GetConVarInt(cvar_BalanceImmunity) == 1 || GetConVarInt(cvar_BalanceImmunity) == 3)
    {
        char sFlags[32];
        GetConVarString(cvar_BalanceAdmFlags, sFlags, sizeof(sFlags));
        if (IsAdmin(client, sFlags))
            iPriority -=100;
    }
    if (g_aPlayers[client][iBalanceTime] > GetTime())
    {
        iPriority -=20;
    }
    if (GetClientTime(client) < 180)
    {
        iPriority += 5;
    }

    switch (CheckBuddySystem(client))
    {
        case 1:
            iPriority -=20;
        case 2:
            iPriority +=100;
    }

    return iPriority;
}

bool:IsValidTeam(client)
{
    new team = GetClientTeam(client);

    if (team == TEAM_RED || team == TEAM_BLUE)
    {
        return true;
    }

    return false;
}
