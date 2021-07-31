#pragma semicolon 1;
#pragma newdecls required;

#include <sourcemod>
#include <sdktools>
#include <tf2>
#include <gamemode>
#include <morecolors>

public Plugin myinfo =
{
    name             = "Disable Autobalance during bad times",
    author           = "stephanie",
    description      = "Don't autobalance people during these times",
    version          = "0.0.3",
    url              = "https://sappho.io"
}

/*
    Don't autobalance people during these times:
    -   1 minute left in server time
    -   1 min or less in round time on non koth
    -   30 sec or less in round time on koth
    -   one team owns 4 out of 5 cap points
    -   cart is before the last point
        this only includes the LAST last point on multistage pl maps

    TODO - if one team has 2 intel captures and the 3rd intel is picked up
*/

int uncappedpoints;
int redpoints;
int blupoints;

// stay disabled thru other events? [ for end of round autobalance ]
bool staydisabled;
// stored gamemode
TF2_GameMode gamemode;

ConVar cvAuto;

// enable autobalance
void EnableAuto()
{
    if (!staydisabled)
    {
        cvAuto.SetInt(1);
        //MC_PrintToChatAll("[{creators}Creators.TF{default}] Enabled autobalance.");
    }
}

// disable autobalance
void DisableAuto()
{
    cvAuto.SetInt(0);
    //MC_PrintToChatAll("[{creators}Creators.TF{default}] Disabled autobalance due to round almost being over.");
}

public void OnPluginStart()
{
    CreateTimer(1.0, CheckMapTimeLeft, _, TIMER_REPEAT);
    HookEvent("teamplay_round_start", OnRoundStart);
    HookEvent("teamplay_point_captured", ControlPointCapped);
    HookEntityOutput("team_round_timer", "On30SecRemain", NearEndOfRound);
    HookEntityOutput("team_round_timer", "On1MinRemain", NearEndOfRound);
    
    cvAuto = FindConVar("mp_autoteambalance");
}

public void OnMapStart()
{
    staydisabled = false;
    LogMessage("Map started. Enabling autobalance!");
    EnableAuto();
    CheckGamemode();
}

Action OnRoundStart(Event event, const char[] name, bool dontBroadcast)
{
    LogMessage("A round started. Enabling autobalance!");
    EnableAuto();
    CheckGamemode();
}

void CheckGamemode()
{
    gamemode = TF2_DetectGameMode();
    if (gamemode == TF2_GameMode_5CP)
    {
        checkPoints();
    }
}

void checkPoints()
{
    // clear these
    uncappedpoints  = 0;
    redpoints       = 0;
    blupoints       = 0;

    // init to -1 to search from first ent
    int iEnt = -1;
    // search thru ents to find all the control points and check their teams
    while ((iEnt = FindEntityByClassname(iEnt, "team_control_point")) != -1)
    {
        // uncapped
        if (GetEntProp(iEnt, Prop_Send, "m_iTeamNum") == view_as<int>(TFTeam_Unassigned))
        {
            uncappedpoints++;
            continue;
        }
        // red
        if (GetEntProp(iEnt, Prop_Send, "m_iTeamNum") == view_as<int>(TFTeam_Red))
        {
            redpoints++;
            continue;
        }
        // blu
        if (GetEntProp(iEnt, Prop_Send, "m_iTeamNum") == view_as<int>(TFTeam_Blue))
        {
            blupoints++;
            continue;
        }
    }
    LogMessage("uncapped %i blue %i red %i", uncappedpoints, blupoints, redpoints);
}

// whenever any point gets capped
Action ControlPointCapped(Event event, const char[] name, bool dontBroadcast)
{
    // only do this on 5cp or payload duh
    if (gamemode == TF2_GameMode_5CP || gamemode == TF2_GameMode_PL)
    {
        // recheck our points
        checkPoints();

        if (gamemode == TF2_GameMode_5CP)
        {
            // it should only ever be 4 vs 1 if someones pushing last
            if
            (
                (
                    redpoints == 4
                    &&
                    blupoints == 1
                )
                ||
                (
                    blupoints == 4
                    &&
                    redpoints == 1
                )
            )
            {
                LogMessage("Someone is pushing last. Disabling autobalance!");
                DisableAuto();
            }
            else
            {
                LogMessage("Nobody is pushing last. Enabling autobalance!");
                EnableAuto();
            }
        }
        else if (gamemode == TF2_GameMode_PL)
        {
            // this means red only has one point left
            if (redpoints == 1)
            {
                LogMessage("Someone is pushing last. Disabling autobalance!");
                DisableAuto();
            }
            else
            {
                LogMessage("Nobody is pushing last. Enabling autobalance!");
                EnableAuto();
            }
        }
    }
}

// fired on 30 seconds left, including setup time!
void NearEndOfRound(const char[] output, int caller, int activator, float delay)
{
    if
    (
        // only bother if we're running
        GameRules_GetRoundState() == RoundState_RoundRunning
        &&
        // make sure we're not in stinky setup time
        GameRules_GetProp("m_bInSetup") == 0
        &&
        // make sure we're not in waiting for players
        GameRules_GetProp("m_bInWaitingForPlayers") == 0
    )
    {
        if (StrEqual(output, "On1MinRemain", true) && gamemode != TF2_GameMode_KOTH)
        {
            LogMessage("1 minute left in the round, we're not in koth. Disabling autobalance!");
            DisableAuto();
        }
        else if (StrEqual(output, "On30SecRemain", true) && gamemode == TF2_GameMode_KOTH)
        {
            LogMessage("30 seconds left on a koth timer - Disabling autobalance!");
            DisableAuto();
        }
    }
}

// check server time - runs every second
public Action CheckMapTimeLeft(Handle timer)
{
    int timelimit;
    GetMapTimeLimit(timelimit);

    int totalsecs;
    GetMapTimeLeft(totalsecs);

    // don't bother if no timelimit or server time is expired
    if (timelimit == 0 || totalsecs <= 0)
    {
        return Plugin_Handled;
    }

    // 1 minute left!
    if (totalsecs == 60)
    {
        LogMessage("server time at 1 minute left, disabling autobalance");
        DisableAuto();
        staydisabled = true;
    }

    return Plugin_Handled;
}