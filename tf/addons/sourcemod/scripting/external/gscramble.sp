/************************************************************************
*************************************************************************
gScramble
Description:
    Automatic scramble and balance script for TF2
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
*/


#pragma semicolon 1
#include <sourcemod>
#include <tf2>
#include <tf2_stocks>
#include <sdktools>
#include <morecolors>

// comment out to disable debug
//#define DEBUG

#undef REQUIRE_EXTENSIONS
#include <clientprefs>
#define REQUIRE_EXTENSIONS

/**
comment these 2 lines if you want to compile without them.
*/
//#define GAMEME_INCLUDED
//#define HLXCE_INCLUDED

#undef REQUIRE_PLUGIN
#include <adminmenu>
#if defined GAMEME_INCLUDED
#include <gameme>
#endif
#if defined HLXCE_INCLUDED
#include <hlxce-sm-api>
#endif
#define REQUIRE_PLUGIN

#define VERSION "3.0.35b"
#define TEAM_RED 2
#define TEAM_BLUE 3
#define SCRAMBLE_SOUND  "vo/announcer_am_teamscramble03.mp3"
#define EVEN_SOUND      "vo/announcer_am_teamscramble01.mp3"

/**
cvar handles
*/
new Handle:cvar_Version             = INVALID_HANDLE,
    Handle:cvar_Steamroll           = INVALID_HANDLE,
    Handle:cvar_Needed              = INVALID_HANDLE,
    Handle:cvar_Delay               = INVALID_HANDLE,
    Handle:cvar_MinPlayers          = INVALID_HANDLE,
    Handle:cvar_MinAutoPlayers      = INVALID_HANDLE,
    Handle:cvar_FragRatio           = INVALID_HANDLE,
    Handle:cvar_AutoScramble        = INVALID_HANDLE,
    Handle:cvar_VoteEnable          = INVALID_HANDLE,
    Handle:cvar_WaitScramble        = INVALID_HANDLE,
    Handle:cvar_ForceTeam           = INVALID_HANDLE,
    Handle:cvar_ForceBalance        = INVALID_HANDLE,
    Handle:cvar_SteamrollRatio      = INVALID_HANDLE,
    Handle:cvar_VoteMode            = INVALID_HANDLE,
    Handle:cvar_PublicNeeded        = INVALID_HANDLE,
    Handle:cvar_FullRoundOnly       = INVALID_HANDLE,
    Handle:cvar_AutoScrambleWinStreak = INVALID_HANDLE,
    Handle:cvar_SortMode            = INVALID_HANDLE,
    Handle:cvar_TeamSwapBlockImmunity = INVALID_HANDLE,
    Handle:cvar_MenuVoteEnd         = INVALID_HANDLE,
    Handle:cvar_AutoscrambleVote    = INVALID_HANDLE,
    Handle:cvar_ScrambleImmuneMode  = INVALID_HANDLE,
    Handle:cvar_Punish              = INVALID_HANDLE,
    Handle:cvar_Balancer            = INVALID_HANDLE,
    Handle:cvar_BalanceTime         = INVALID_HANDLE,
    Handle:cvar_TopProtect          = INVALID_HANDLE,
    Handle:cvar_BalanceLimit        = INVALID_HANDLE,
    Handle:cvar_BalanceImmunity     = INVALID_HANDLE,
    Handle:cvar_Enabled             = INVALID_HANDLE,
    Handle:cvar_RoundTime           = INVALID_HANDLE,
    Handle:cvar_VoteDelaySuccess    = INVALID_HANDLE,
    Handle:cvar_RoundTimeMode       = INVALID_HANDLE,
    Handle:cvar_SetupCharge         = INVALID_HANDLE,
    Handle:cvar_MaxUnbalanceTime    = INVALID_HANDLE,
    Handle:cvar_AvgDiff             = INVALID_HANDLE,
    Handle:cvar_DominationDiff      = INVALID_HANDLE,
    Handle:cvar_Preference          = INVALID_HANDLE,
    Handle:cvar_SetupRestore        = INVALID_HANDLE,
    Handle:cvar_BalanceAdmFlags     = INVALID_HANDLE,
    Handle:cvar_ScrambleAdmFlags    = INVALID_HANDLE,
    Handle:cvar_TeamswapAdmFlags    = INVALID_HANDLE,
    Handle:cvar_Koth                = INVALID_HANDLE,
    Handle:cvar_AutoScrambleRoundCount = INVALID_HANDLE,
    Handle:cvar_ForceReconnect      = INVALID_HANDLE,
    Handle:cvar_TeamworkProtect     = INVALID_HANDLE,
    Handle:cvar_BalanceActionDelay  = INVALID_HANDLE,
    Handle:cvar_ForceBalanceTrigger = INVALID_HANDLE,
    Handle:cvar_NoSequentialScramble = INVALID_HANDLE,
    Handle:cvar_AdminBlockVote          = INVALID_HANDLE,
    Handle:cvar_BuddySystem             = INVALID_HANDLE,
    Handle:cvar_ImbalancePrevent        = INVALID_HANDLE,
    Handle:cvar_MenuIntegrate           = INVALID_HANDLE,
    Handle:cvar_Silent                  = INVALID_HANDLE,
    Handle:cvar_VoteCommand             = INVALID_HANDLE,
    Handle:cvar_VoteAd                  = INVALID_HANDLE,
    Handle:cvar_BlockJointeam           = INVALID_HANDLE,
    Handle:cvar_TopSwaps                = INVALID_HANDLE,
    Handle:cvar_BalanceTimeLimit        = INVALID_HANDLE,
    Handle:cvar_ScrLockTeams            = INVALID_HANDLE,
    Handle:cvar_RandomSelections        = INVALID_HANDLE,
    Handle:cvar_PrintScrambleStats      = INVALID_HANDLE,
    Handle:cvar_ScrambleDuelImmunity    = INVALID_HANDLE,
    Handle:cvar_AbHumanOnly             = INVALID_HANDLE,
    Handle:cvar_LockTeamsFullRound      = INVALID_HANDLE,
    Handle:cvar_SelectSpectators        = INVALID_HANDLE,
    Handle:cvar_ProtectOnlyMedic        = INVALID_HANDLE,
    Handle:cvar_BalanceDuelImmunity     = INVALID_HANDLE,
    Handle:cvar_BalanceChargeLevel      = INVALID_HANDLE,
    Handle:cvar_ScrambleCheckImmune     = INVALID_HANDLE,
    Handle:cvar_BalanceImmunityCheck    = INVALID_HANDLE,
    Handle:cvar_OneScramblePerRound     = INVALID_HANDLE,
    Handle:cvar_ProgressDisable         = INVALID_HANDLE,
    Handle:cvar_AutoTeamBalance         = INVALID_HANDLE,
    Handle:cvar_TeamWorkFlagEvent       = INVALID_HANDLE,
    Handle:cvar_TeamWorkUber            = INVALID_HANDLE,
    Handle:cvar_TeamWorkMedicKill       = INVALID_HANDLE,
    Handle:cvar_TeamWorkCpTouch         = INVALID_HANDLE,
    Handle:cvar_TeamWorkCpCapture       = INVALID_HANDLE,
    Handle:cvar_TeamWorkPlaceSapper     = INVALID_HANDLE,
    Handle:cvar_TeamWorkBuildingKill    = INVALID_HANDLE,
    Handle:cvar_TeamWorkCpBlock         = INVALID_HANDLE,
    Handle:cvar_TeamWorkExtinguish      = INVALID_HANDLE;

new Handle:g_hAdminMenu             = INVALID_HANDLE,
    Handle:g_hScrambleVoteMenu      = INVALID_HANDLE,
    Handle:g_hScrambleNowPack       = INVALID_HANDLE;
#if defined GAMEME_INCLUDED
    new Handle:g_hGameMeUpdateTimer     = INVALID_HANDLE;
#endif

/**
timer handles
*/
new Handle:g_hVoteDelayTimer        = INVALID_HANDLE,
    Handle:g_hScrambleDelay         = INVALID_HANDLE,
    Handle:g_hRoundTimeTick         = INVALID_HANDLE,
    Handle:g_hForceBalanceTimer     = INVALID_HANDLE,
    Handle:g_hBalanceFlagTimer      = INVALID_HANDLE,
    Handle:g_hCheckTimer            = INVALID_HANDLE,
    Handle:g_hVoteAdTimer           = INVALID_HANDLE;

new Handle:g_cookie_timeBlocked     = INVALID_HANDLE,
    Handle:g_cookie_teamIndex       = INVALID_HANDLE,
    Handle:g_cookie_serverIp        = INVALID_HANDLE,
    Handle:g_cookie_serverStartTime = INVALID_HANDLE;

new String:g_sVoteCommands[3][65];

new bool:g_bScrambleNextRound = false,
    bool:g_bVoteAllowed,
    bool:g_bScrambleAfterVote,
    bool:g_bWasFullRound = false,
    bool:g_bPreGameScramble,
    bool:g_bHooked = false,
    bool:g_bIsTimer,
    bool:g_bArenaMode,
    bool:g_bKothMode,
    bool:g_bRedCapped,
    bool:g_bBluCapped,
    bool:g_bFullRoundOnly,
    bool:g_bAutoBalance,
    bool:g_bForceTeam,
    bool:g_bForceReconnect,
    bool:g_bAutoScramble,
    bool:g_bUseClientPrefs = false,
    bool:g_bNoSequentialScramble,
    bool:g_bScrambledThisRound,
    bool:g_bBlockDeath,
    bool:g_bUseBuddySystem,
    bool:g_bSilent,
    bool:g_bBlockJointeam,
    bool:g_bNoSpec,
    bool:g_bUseGameMe,
    bool:g_bUseHlxCe,
    bool:g_bVoteCommandCreated,
    bool:g_bTeamsLocked,
    bool:g_bSelectSpectators,

    /**
    overrides the auto scramble check
    */
    bool:g_bScrambleOverride;  // allows for the scramble check to be blocked by admin
    //Float:g_fEscortProgress;

new g_iTeamIds[2] = {TEAM_RED, TEAM_BLUE};

new g_iPluginStartTime,
    g_iMapStartTime,
    g_iRoundStartTime,
    //g_iSpawnTime,
    g_iVotes,
    g_iVoters,
    g_iVotesNeeded,
    g_iCompleteRounds,
    g_iRoundTrigger,
    g_iForceTime,
    g_iLastRoundWinningTeam,
    g_iNumAdmins;


enum e_TeamInfo
{
    iRedFrags,
    iBluFrags,
    iRedScore,
    iBluScore,
    iRedWins,
    iBluWins,
    bool:bImbalanced
};

enum e_PlayerInfo
{
    iBalanceTime,
    bool:bHasVoted,
    iBlockTime,
    iBlockWarnings,
    iTeamPreference,
    iTeamworkTime,
    bool:bIsVoteAdmin,
    iBuddy,
    iFrags,
    iDeaths,
    bool:bHasFlag,
    iSpecChangeTime,
    iGameMe_Rank,
    iGameMe_Skill,
    iGameMe_gRank,
    iGameMe_gSkill,
    iGameMe_SkillChange,
    iHlxCe_Rank,
    iHlxCe_Skill,
};

enum e_RoundState
{
    newGame,
    preGame,
    bonusRound,
    suddenDeath,
    mapEnding,
    setup,
    normal,
};

enum ScrambleTime
{
    Scramble_Now,
    Scramble_Round,
};

enum e_ImmunityModes
{
    scramble,
    balance,
};

enum e_Protection
{
    none,
    admin,
    uberAndBuildings,
    both
};

enum e_ScrambleModes
{
    invalid,
    random,
    score,
    scoreSqdPerMinute,
    kdRatio,
    topSwap,
    gameMe_Rank,
    gameMe_Skill,
    gameMe_gRank,
    gameMe_gSkill,
    gameMe_SkillChange,
    hlxCe_Rank,
    hlxCe_Skill,
    playerClass,
    randomSort
};

enum eTeamworkReasons
{
    flagEvent,
    medicKill,
    medicDeploy,
    buildingKill,
    placeSapper,
    controlPointCaptured,
    controlPointTouch,
    controlPointBlock,
    playerExtinguish
};


e_RoundState g_RoundState;
ScrambleTime g_iDefMode;
int g_aTeams[e_TeamInfo];
int g_aPlayers[MAXPLAYERS + 1][e_PlayerInfo];


//new g_iRoundTimer;
new g_iTimerEnt;
new bool:g_bRoundIsTimed = false;    //True if this is a timed round
new Float:g_fRoundEndTime;   //Contains the round end time (compare to GetGameTime()'s return value) if round_is_timed is true

#include "gscramble/gscramble_menu_settings.sp"
#include "gscramble/gscramble_autoscramble.sp"
#include "gscramble/gscramble_autobalance.sp"
#include "gscramble/gscramble_tf2_extras.sp"

public Plugin:myinfo =
{
    name = "[TF2] gScramble",
    author = "Goerge",
    description = "Auto Managed team balancer/scrambler.",
    version = VERSION,
    url = "https://github.com/BrutalGoerge/tf2tmng"
};

public OnPluginStart()
{
    CheckTranslation();
    cvar_Enabled            = CreateConVar("gs_enabled",        "1",        "Enable/disable the plugin and all its hooks.", FCVAR_NOTIFY, true, 0.0, true, 1.0);

    cvar_Balancer           =   CreateConVar("gs_autobalance",  "0",    "Enable/disable the auto-balance feature of this plugin.\nUse only if you have the built-in balancer disabled.", _, true, 0.0, true, 1.0);
    cvar_TopProtect         = CreateConVar("gs_ab_protect", "5",    "How many of the top players to protect on each team from auto-balance.", _, true, 0.0, false);
    cvar_BalanceTime        =   CreateConVar("gs_ab_balancetime",   "5",            "Time in minutes after a client is balanced in which they cannot be balanced again.");
    cvar_BalanceLimit       =   CreateConVar("gs_ab_unbalancelimit",    "2",    "If one team has this many more players than the other, then consider the teams imbalanced.");
    cvar_BalanceImmunity    =   CreateConVar("gs_ab_immunity",          "2",    "Controls who is immune from auto-balance\n0 = no immunity\n1 = admins\n2 = engies with buildings\n3 = both admins and engies with buildings", _, true, 0.0, true, 3.0);
    cvar_MaxUnbalanceTime   = CreateConVar("gs_ab_max_unbalancetime", "120", "Max time the teams are allowed to be unbalanced before a balanced is forced on living players.\n0 = disabled.", _, true, 0.0, false);
    cvar_Preference         = CreateConVar("gs_ab_preference",      "1",    "Allow clients to tell the plugin what team they prefer.  When an auto-balance starts, if the client prefers the team, it overrides any immunity check.", _, true, 0.0, true, 1.0);
    cvar_BalanceActionDelay = CreateConVar("gs_ab_actiondelay",     "5",    "Time, in seconds after an imbalance is detected in which an imbalance is flagged, and possible swapping can occur", _, true, 0.0, false);
    cvar_ForceBalanceTrigger = CreateConVar("gs_ab_forcetrigger",   "4",    "If teams become imbalanced by this many players, auto-force a balance", _, true, 0.0, false);
    cvar_BalanceTimeLimit   =   CreateConVar("gs_ab_timelimit", "0",        "If there are this many seconds, or less, remaining in a round, stop auto-balancing", _, true, 0.0, false);
    cvar_AbHumanOnly        = CreateConVar("gs_ab_humanonly", "0", "Only auto-balance human players", _, true, 0.0, true, 1.0);
    cvar_ProgressDisable    =   CreateConVar("gs_ab_cartprogress_disable", ".90", "If the cart has reached this percentage of progress, then disable auto-balance", _, true, 0.0, true, 1.0);
    cvar_BalanceDuelImmunity = CreateConVar("gs_ab_duel_immunity", "1", "Players in duels are immune from auto-balance", _, true, 0.0, true, 1.0);
    cvar_ProtectOnlyMedic   =   CreateConVar("gs_ab_protect_medic", "1", "A team's only medic will be immune from balancing", _, true, 0.0, true, 1.0);
    cvar_BalanceChargeLevel = CreateConVar("gs_ab_protectmedic_chargelevel", "0.5", "Charge level to protect medics from auto balance", _, true, 0.0, true, 1.0);
    cvar_BalanceImmunityCheck = CreateConVar("gs_balance_checkummunity_percent", "0.0", "Percentage of players immune from auto balance to start to ignore balance immunity check", _, true, 0.0, true, 1.0);

    cvar_TeamWorkFlagEvent      = CreateConVar("gs_ab_teamwork_flagevent",      "30", "Time immunity from auto-balance to grant when a player touches/drops the ctf flag.",     _, true, 0.0, false);
    cvar_TeamWorkUber           = CreateConVar("gs_ab_teamwork_uber_deploy",    "30", "Time immunity from auto-balance to grant when a player becomes uber charged.",           _, true, 0.0, false);
    cvar_TeamWorkMedicKill      = CreateConVar("gs_ab_teamwork_kill_medic",     "30", "Time immunity from auto-balance to grant when a player kills a charged medic.",          _, true, 0.0, false);
    cvar_TeamWorkCpTouch        = CreateConVar("gs_ab_teamwork_cp_touch",       "30", "Time immunity from auto-balance to grant when a player touches a control point.",        _, true, 0.0, false);
    cvar_TeamWorkCpCapture      = CreateConVar("gs_ab_teamwork_cp_capture",     "30", "Time immunity from auto-balance to grant when a player captures a control point.",       _, true, 0.0, false);
    cvar_TeamWorkPlaceSapper    = CreateConVar("gs_ab_teamwork_sapper_place",   "30", "Time immunity from auto-balance to grant when a spy places a sapper.",                   _, true, 0.0, false);
    cvar_TeamWorkBuildingKill   = CreateConVar("gs_ab_teamwork_building_kill",  "30", "Time immunity from auto-balance to grant when a player destroys a building.",            _, true, 0.0, false);
    cvar_TeamWorkCpBlock        = CreateConVar("gs_ab_teamwork_cp_block",       "30", "Time immunity from auto-balance to grant when a player blocks a control point.",         _, true, 0.0, false);
    cvar_TeamWorkExtinguish     = CreateConVar("gs_ab_teamwork_extinguish",     "30", "Time immunity from auto-balance to grant when a player extinguishes a team-mate.",       _, true, 0.0, false);

    cvar_ImbalancePrevent   = CreateConVar("gs_prevent_spec_imbalance", "0", "If set, block changes to spectate that result in a team imbalance", _, true, 0.0, true, 1.0);
    cvar_BuddySystem        = CreateConVar("gs_use_buddy_system", "0", "Allow players to choose buddies to try to keep them on the same team", _, true, 0.0, true, 1.0);
    cvar_SelectSpectators = CreateConVar("gs_Select_spectators", "60", "During a scramble or force-balance, select spectators who have change to spectator in less time in seconds than this setting, 0 disables", _, true, 0.0, false);

    cvar_TeamworkProtect    = CreateConVar("gs_teamwork_protect", "1",      "Enable/disable the teamwork protection feature.", _, true, 0.0, true, 1.0);
    cvar_ForceBalance       = CreateConVar("gs_force_balance",  "0",        "Force a balance between each round. (If you use a custom team balance plugin that doesn't do this already, or you have the default one disabled)", _, true, 0.0, true, 1.0);
    cvar_TeamSwapBlockImmunity = CreateConVar("gs_teamswitch_immune",   "1",    "Sets if admins (root and ban) are immune from team swap blocking", _, true, 0.0, true, 1.0);
    cvar_ScrambleImmuneMode = CreateConVar("gs_scramble_immune", "0",       "Sets if admins and people with uber and engie buildings are immune from being scrambled.\n0 = no immunity\n1 = just admins\n2 = charged medics + engineers with buildings\n3 = admins + charged medics and engineers with buildings.", _, true, 0.0, true, 3.0);
    cvar_SetupRestore       = CreateConVar("gs_setup_reset",    "1",        "If a scramble happens during setup, restore the setup timer to its starting value", _, true, 0.0, true, 1.0);
    cvar_ScrambleAdmFlags   = CreateConVar("gs_flags_scramble", "ab",       "Admin flags for scramble protection (if enabled)");
    cvar_BalanceAdmFlags    = CreateConVar("gs_flags_balance",  "ab",       "Admin flags for balance protection (if enabled)");
    cvar_TeamswapAdmFlags   = CreateConVar("gs_flags_teamswap", "bf",       "Admin flags for team swap block protection (if enabled)");

    cvar_NoSequentialScramble = CreateConVar("gs_no_sequential_scramble", "1", "If set, then it will block auto-scrambling from happening two rounds in a row. Also stops scrambles from being started if one has occured already during a round.", _, true, 0.0, true, 1.0);
    cvar_WaitScramble       = CreateConVar("gs_prescramble",    "0",        "If enabled, teams will scramble at the end of the 'waiting for players' period", _, true, 0.0, true, 1.0);
    cvar_RoundTime          = CreateConVar("gs_public_roundtime",   "0",        "If this many seconds or less is left on the round timer, then block public voting.\n0 = disabled.\nConfigure this with the roundtime_blockmode cvar.", _, true, 0.0, false);
    cvar_RoundTimeMode      = CreateConVar("gs_public_roundtime_blockmode", "0", "How to handle the final public vote if there are less that X seconds left in the round, specified by the roundtime cvar.\n0 = block the final vote.\n1 = Allow the vote and force a scramble for the next round regardless of any other setting.", _, true, 0.0, true, 1.0);
    cvar_VoteMode           = CreateConVar("gs_public_votemode",    "0",        "For public chat votes\n0 = if enough triggers, enable scramble for next round.\n1 = if enough triggers, start menu vote to start a scramble\n2 = scramble teams right after the last trigger.", _, true, 0.0, true, 2.0);
    cvar_PublicNeeded       = CreateConVar("gs_public_triggers",    "0.60",     "Percentage of people needing to trigger a scramble in chat.  If using votemode 1, I suggest you set this lower than 50%", _, true, 0.05, true, 1.0);
    cvar_VoteEnable         = CreateConVar("gs_public_votes",   "1",        "Enable/disable public voting", _, true, 0.0, true, 1.0);
    cvar_Punish             = CreateConVar("gs_punish_stackers", "0",       "Punish clients trying to restack teams during the team-switch block period by adding time to when they are able to team swap again", _, true, 0.0, true, 1.0);
    cvar_SortMode           = CreateConVar("gs_sort_mode",      "1",
        "Player scramble sort mode.\n1 = Random\n2 = Player Score\n3 = Player Score Per Minute.\n4 = Kill-Death Ratio\n5 = Swap the top players on each team.\n6 = GameMe rank\n7 = GameMe skill\n8 Global GameMe rank\n9 = Global GameMe Skill\n10 = GameMe session skill change.\n11 = HlxCe Rank.\n12 = HlxCe Skill\n13 = player classes.\n14. Random mode\nThis controls how players get swapped during a scramble.", _, true, 1.0, true, 14.0);
    cvar_RandomSelections = CreateConVar("gs_random_selections", "0.55", "Percentage of players to swap during a random scramble", _, true, 0.1, true, 0.80);
    cvar_TopSwaps           = CreateConVar("gs_top_swaps",      "5",        "Number of top players the top-swap scramble will switch", _, true, 1.0, false);

    cvar_SetupCharge        = CreateConVar("gs_setup_fill_ubers",       "0",        "If a scramble-now happens during setup time, fill up any medic's uber-charge.", _, true, 0.0, true, 1.0);
    cvar_ForceTeam          = CreateConVar("gs_changeblocktime",    "120",      "Time after being swapped by a scramble where players aren't allowed to change teams", _, true, 0.0, false);
    cvar_ForceReconnect     = CreateConVar("gs_check_reconnect",    "1",        "The plugin will check if people are reconnecting to the server to avoid being forced on a team.  Requires clientprefs", _, true, 0.0, true, 1.0);
    cvar_MenuVoteEnd        = CreateConVar("gs_menu_votebehavior",  "0",        "0 =will trigger scramble for round end.\n1 = will scramble teams after vote.", _, true, 0.0, true, 1.0);
    cvar_Needed             = CreateConVar("gs_menu_votesneeded",   "0.60",     "Percentage of votes for the menu vote scramble needed.", _, true, 0.05, true, 1.0);
    cvar_Delay              = CreateConVar("gs_vote_delay",         "60.0",     "Time in seconds after the map has started and after a failed vote in which players can votescramble.", _, true, 0.0, false);
    cvar_VoteDelaySuccess   = CreateConVar("gs_vote_delay2",        "300",      "Time in seconds after a successful scramble in which players can vote again.", _, true, 0.0, false);
    cvar_AdminBlockVote     = CreateConVar("gs_vote_adminblock",        "0",        "If set, publicly started votes are disabled when an admin is preset.", _, true, 0.0, true, 1.0);

    cvar_MinPlayers         = CreateConVar("gs_vote_minplayers",    "1",        "Minimum poeple connected before any voting will work.", _, true, 0.0, false);

    cvar_AutoScrambleWinStreak          = CreateConVar("gs_winstreak",      "0",        "If set, it will scramble after a team wins X full rounds in a row", _, true, 0.0, false);
    cvar_AutoScrambleRoundCount             = CreateConVar("gs_scramblerounds", "0",        "If set, it will scramble every X full round", _, true, 0.0, false, 1.0);

    cvar_AutoScramble       = CreateConVar("gs_autoscramble",   "1",        "Enables/disables the automatic scrambling.", _, true, 0.0, true, 1.0);
    cvar_FullRoundOnly      = CreateConVar("gs_as_fullroundonly",   "0",        "Auto-scramble only after a full round has completed.", _, true, 0.0, true, 1.0);
    cvar_AutoscrambleVote   = CreateConVar("gs_as_vote",        "0",        "Starts a scramble vote instead of scrambling at the end of a round", _, true, 0.0, true, 1.0);
    cvar_MinAutoPlayers     = CreateConVar("gs_as_minplayers", "12",        "Minimum people connected before automatic scrambles are possible", _, true, 0.0, false);
    cvar_FragRatio          = CreateConVar("gs_as_hfragratio",      "2.0",      "If a teams wins with a frag ratio greater than or equal to this setting, trigger a scramble.\nSetting this to 0 disables.", _, true, 0.0, false);
    cvar_Steamroll          = CreateConVar("gs_as_wintimelimit",    "120.0",    "If a team wins in less time, in seconds, than this, and has a frag ratio greater than specified: perform an auto scramble.", _, true, 0.0, false);
    cvar_SteamrollRatio     = CreateConVar("gs_as_wintimeratio",    "1.5",      "Lower kill ratio for teams that win in less than the wintime_limit.", _, true, 0.0, false);
    cvar_AvgDiff            = CreateConVar("gs_as_playerscore_avgdiff", "10.0", "If the average score difference for all players on each team is greater than this, then trigger a scramble.\n0 = skips this check", _, true, 0.0, false);
    cvar_DominationDiff     = CreateConVar("gs_as_domination_diff",     "10",   "If a team has this many more dominations than the other team, then trigger a scramble.\n0 = skips this check", _, true, 0.0, false);
    cvar_Koth               = CreateConVar("gs_as_koth_pointcheck",     "0",    "If enabled, trigger a scramble if a team never captures the point in koth mode.", _, true, 0.0, true, 1.0);
    cvar_ScrLockTeams       = CreateConVar("gs_as_lockteamsbefore", "1", "If enabled, lock the teams between the scramble check and the actual scramble", _, true, 0.0, true, 1.0);
    cvar_PrintScrambleStats = CreateConVar("gs_as_print_stats", "1", "If enabled, print the scramble stats", _, true, 0.0, true, 1.0);
    cvar_ScrambleDuelImmunity = CreateConVar("gs_as_dueling_immunity", "0", "If set it 1, grant immunity to duelling players during a scramble", _, true, 0.0, true, 1.0);
    cvar_LockTeamsFullRound = CreateConVar("gs_as_lockteamsafter", "0", "If enabled, block team changes after a scramble for the entire next round", _, true, 0.0, true, 1.0);
    cvar_ScrambleCheckImmune = CreateConVar("gs_scramble_checkummunity_percent", "0.0", "If this percentage or higher of the players are immune from scramble, ignore immunity", _, true, 0.0, true, 1.0);

    cvar_Silent         =   CreateConVar("gs_silent", "0",  "Disable most commen chat messages", _, true, 0.0, true, 1.0);
    cvar_VoteCommand =  CreateConVar("gs_vote_trigger", "votescramble", "The trigger for starting a vote-scramble");
    cvar_VoteAd     = CreateConVar("gs_vote_advertise", "500", "How often, in seconds, to advertise the vote command trigger.\n0 disables this", _, true, 0.0, false);
    cvar_MenuIntegrate = CreateConVar("gs_admin_menu",          "1",  "Enable or disable the automatic integration into the admin menu", _, true, 0.0, true, 1.0);

    cvar_BlockJointeam = CreateConVar("gs_block_jointeam",      "0", "If enabled, will block the use of the jointeam and spectate commands and force mp_forceautoteam enabled if it is not enabled", _, true, 0.0, true, 1.0);

    cvar_OneScramblePerRound =  CreateConVar("gs_onescrambleperround", "1", "If enabled, will only allow only allow one scramble per round", _, true, 0.0, true, 1.0);

    cvar_Version            = CreateConVar("gscramble_version", VERSION, "Gscramble version", FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY|FCVAR_DONTRECORD);
    RegCommands();

    /**
    convar variables we need to know the new values of
    */
    HookConVarChange(cvar_ForceReconnect, handler_ConVarChange);
    HookConVarChange(cvar_ForceTeam, handler_ConVarChange);
    HookConVarChange(cvar_FullRoundOnly, handler_ConVarChange);
    HookConVarChange(cvar_Enabled, handler_ConVarChange);
    HookConVarChange(cvar_AutoScramble, handler_ConVarChange);
    HookConVarChange(cvar_VoteMode, handler_ConVarChange);
    HookConVarChange(cvar_Balancer, handler_ConVarChange);
    HookConVarChange(cvar_NoSequentialScramble, handler_ConVarChange);
    HookConVarChange(cvar_SortMode, handler_ConVarChange);
    cvar_AutoTeamBalance = FindConVar("mp_autoteambalance");
    if (cvar_AutoTeamBalance != INVALID_HANDLE)
        HookConVarChange(cvar_AutoTeamBalance, handler_ConVarChange);

    AutoExecConfig(true, "plugin.gscramble");
    LoadTranslations("common.phrases");
    LoadTranslations("gscramble.phrases");

    CheckExtensions();

    g_iVoters = GetClientCount(false);
    g_iVotesNeeded = RoundToFloor(float(g_iVoters) * GetConVarFloat(cvar_PublicNeeded));
    g_bVoteCommandCreated = false;
    g_iPluginStartTime = GetTime();

}

public OnAllPluginsLoaded()
{
    new Handle:gTopMenu;

    if (LibraryExists("adminmenu") && ((gTopMenu = GetAdminTopMenu()) != INVALID_HANDLE))
    {
        OnAdminMenuReady(gTopMenu);
    }
}

stock CheckTranslation()
{
    decl String:sPath[257];
    BuildPath(Path_SM, sPath, sizeof(sPath), "translations/gscramble.phrases.txt");

    if (!FileExists(sPath))
    {
        SetFailState("Translation file 'gscramble.phrases.txt' is missing. Please download the zip file at 'http://forums.alliedmods.net/showthread.php?t=1983244'");
    }
}

RegCommands()
{
    RegAdminCmd("sm_scrambleround", cmd_Scramble, ADMFLAG_GENERIC, "Scrambles at the end of the bonus round");
    RegAdminCmd("sm_cancel",        cmd_Cancel, ADMFLAG_GENERIC, "Cancels any active scramble, and scramble timer.");
    RegAdminCmd("sm_resetvotes",    cmd_ResetVotes, ADMFLAG_GENERIC, "Resets all public votes.");
    RegAdminCmd("sm_scramble",      cmd_Scramble_Now, ADMFLAG_GENERIC, "sm_scramble <delay> <respawn> <mode>");
    RegAdminCmd("sm_forcebalance",  cmd_Balance, ADMFLAG_GENERIC, "Forces a team balance if an imbalance exists.");
    RegAdminCmd("sm_scramblevote",  cmd_Vote, ADMFLAG_GENERIC, "Start a vote. sm_scramblevote <now/end>");

    //AddCommandListener(CMD_Listener, "say_team"); commenting out since this does nothing, maybe i was going to check for donator commands?
    AddCommandListener(CMD_Listener, "jointeam");
    AddCommandListener(CMD_Listener, "spectate");

    RegConsoleCmd("sm_preference", cmd_Preference);
    RegConsoleCmd("sm_addbuddy",   cmd_AddBuddy);
}

public Action:CMD_Listener(client, const String:command[], argc)
{
    if (StrEqual(command, "jointeam", false) || StrEqual(command, "spectate", false))
    {
        if (client && !IsFakeClient(client))
        {
            if (g_bBlockJointeam)
            {
                if (GetConVarBool(cvar_TeamSwapBlockImmunity))
                {
                    new String:flags[32];
                    GetConVarString(cvar_TeamswapAdmFlags, flags, sizeof(flags));
                    if (IsAdmin(client, flags))
                    {
                        CheckBalance(true);
                        return Plugin_Continue;
                    }
                }
                if (TeamsUnbalanced(false)) //allow clients to change teams during imbalances
                {
                    return Plugin_Continue;
                }
                if (GetClientTeam(client) >= 2)
                {
                    MC_PrintToChat(client, "[{creators}Creators.TF{default}] %t", "BlockJointeam");
                    LogAction(-1, client, "\"%L\" is being blocked from using the %s command due to setting", client, command);
                    return Plugin_Handled;
                }
            }
            if (IsValidTeam(client))
            {
                new String:sArg[9];
                if (argc)
                {
                    GetCmdArgString(sArg, sizeof(sArg));
                }
                if (StrEqual(sArg, "blue", false) || StrEqual(sArg, "red", false) || StringToInt(sArg) >= 2)
                {
                    if (TeamsUnbalanced(false)) //allow clients to change teams during imbalances
                    {
                        return Plugin_Continue;
                    }
                }
                if (IsBlocked(client))
                {
                    HandleStacker(client);
                    return Plugin_Handled;

                }

                if (StrEqual(command, "spectate", false) || StringToInt(sArg) < 2 || StrContains(sArg, "spec", false) != -1)
                {
                    if (GetConVarBool(cvar_ImbalancePrevent))
                    {
                        if (CheckSpecChange(client) || IsBlocked(client))
                        {
                            HandleStacker(client);
                            return Plugin_Handled;
                        }
                    }
                    else if (g_bNoSpec)
                    {
                        HandleStacker(client);
                        return Plugin_Handled;
                    }
                    else if (g_bSelectSpectators)
                    {
                        g_aPlayers[client][iSpecChangeTime] = GetTime();
                    }
                }
            }
        }
    }
    return Plugin_Continue;
}

CheckExtensions()
{
    new String:sMod[14];
    GetGameFolderName(sMod, 14);

    if (!StrEqual(sMod, "TF", false))
    {
        SetFailState("This plugin only works on Team Fortress 2");
    }

    new String:sExtError[256];
    new iExtStatus;

    //check to see if client prefs is loaded and configured properly
    iExtStatus = GetExtensionFileStatus("clientprefs.ext", sExtError, sizeof(sExtError));
    switch (iExtStatus)
    {
        case -1:
        {
            LogAction(-1, 0, "Optional extension clientprefs failed to load.");
        }
        case 0:
        {
            LogAction(-1, 0, "Optional extension clientprefs is loaded with errors.");
            LogAction(-1, 0, "Status reported was [%s].", sExtError);
        }
        case -2:
        {
            LogAction(-1, 0, "Optional extension clientprefs is missing.");
        }
        case 1:
        {
            if (SQL_CheckConfig("clientprefs"))
            {
                g_bUseClientPrefs = true;
            }
            else
            {
                LogAction(-1, 0, "Optional extension clientprefs found, but no database entry is present");
            }
        }
    }

    //now that we have checked for the clientprefs ext, see if we can use its natives
    if (g_bUseClientPrefs)
    {
        g_cookie_timeBlocked = RegClientCookie("time blocked", "time player was blocked", CookieAccess_Private);
        g_cookie_serverIp   = RegClientCookie("server_id", "ip of the server", CookieAccess_Private);
        g_cookie_teamIndex = RegClientCookie("team index", "index of the player's team", CookieAccess_Private);
        g_cookie_serverStartTime = RegClientCookie("start time", "time the plugin was loaded", CookieAccess_Private);
    }
}

public Action:cmd_AddBuddy(client, args)
{
    if (!g_bUseBuddySystem)
    {
        MC_ReplyToCommand(client, "[{creators}Creators.TF{default}] %t", "BuddyDisabledError");

        return Plugin_Handled;
    }
    if (args == 1)
    {
        new String:target_name[MAX_NAME_LENGTH+1], String:arg[32], target_list[1], bool:tn_is_ml;
        GetCmdArgString(arg, sizeof(arg));
        if (ProcessTargetString(
            arg,
            client,
            target_list,
            MAXPLAYERS,
            COMMAND_FILTER_NO_IMMUNITY|COMMAND_FILTER_NO_MULTI,
            target_name,
            sizeof(target_name),
            tn_is_ml) == 1)
            AddBuddy(client, target_list[0]);
        else
        {
            ReplyToTargetError(client, COMMAND_TARGET_NONE);
        }
    }
    else if (!args)
    {
        ShowBuddyMenu(client);
    }
    else
    {
        MC_ReplyToCommand(client, "[{creators}Creators.TF{default}] %t", "BuddyArgError");
    }

    return Plugin_Handled;
}

public Action:cmd_Preference(client, args)
{
    if (!g_bHooked)
    {

        MC_ReplyToCommand(client, "[{creators}Creators.TF{default}] %t", "EnableReply");
        return Plugin_Handled;
    }

    if (!GetConVarBool(cvar_Preference))
    {
        MC_ReplyToCommand(client, "[{creators}Creators.TF{default}] %t", "PrefDisabled");

        return Plugin_Handled;
    }

    if (!args)
    {
        if (g_aPlayers[client][iTeamPreference] != 0)
        {
            if (g_aPlayers[client][iTeamPreference] == TEAM_RED)
            {
                ReplyToCommand(client, "RED");
            }
            else
            {
                ReplyToCommand(client, "BLU");
            }

            return Plugin_Handled;
        }
    }

    decl String:Team[10];
    GetCmdArgString(Team, sizeof(Team));

    if (StrContains(Team, "red", false) != -1)
    {
        g_aPlayers[client][iTeamPreference] = TEAM_RED;
        ReplyToCommand(client, "RED");
        return Plugin_Handled;
    }

    if (StrContains(Team, "blu", false) != -1)
    {
        g_aPlayers[client][iTeamPreference] = TEAM_BLUE;
        ReplyToCommand(client, "BLU");
        return Plugin_Handled;
    }

    if (StrContains(Team, "clear", false) != -1)
    {
        g_aPlayers[client][iTeamPreference] = 0;
        ReplyToCommand(client, "CLEARED");
        return Plugin_Handled;
    }

    ReplyToCommand(client, "Usage: sm_preference <TEAM|CLEAR>");
    return Plugin_Handled;
}

public OnPluginEnd()
{
    if (g_bAutoBalance)
    {
        ServerCommand("mp_autoteambalance 1");
    }
}


public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max)
{
    //if late, assume state = setup and check the timer ent
    if (late)
    {
        CreateTimer(1.0, Timer_load);
    }

    CreateNative("GS_IsClientTeamChangeBlocked", Native_GS_IsBlocked);
    //CreateNative("TF2_GetRoundTimeLeft", TF2_GetRoundTimeLeft);
    MarkNativeAsOptional("HLXCE_GetPlayerData");
    MarkNativeAsOptional("QueryGameMEStats");
    MarkNativeAsOptional("RegClientCookie");
    MarkNativeAsOptional("SetClientCookie");
    MarkNativeAsOptional("GetClientCookie");
    RegPluginLibrary("gscramble");

    return APLRes_Success;
}

public Action:Timer_load(Handle:timer)
{
    g_RoundState = normal;
    CreateTimer(1.0, Timer_GetTime);
    for (new i = 1; i <= MaxClients; i++)
    {
        if (IsClientInGame(i) && !IsFakeClient(i))
        {
            g_iVoters++;
        }
    }
    g_iVotesNeeded = RoundToFloor(float(g_iVoters) * GetConVarFloat(cvar_PublicNeeded));
}

updateVoters()
{
    for (new i = 1; i <= MaxClients; i++)
    {
        if (IsClientInGame(i) && !IsFakeClient(i))
        {
            g_iVoters++;
        }
    }
    g_iVotesNeeded = RoundToFloor(float(g_iVoters) * GetConVarFloat(cvar_PublicNeeded));
}


bool:IsBlocked(client)
{
    if (!g_bForceTeam)
    {
        return false;
    }

    if (g_bTeamsLocked)
    {
        new String:flags[32];
        GetConVarString(cvar_TeamswapAdmFlags, flags, sizeof(flags));

        if (IsAdmin(client, flags))
        {
            return false;
        }

        return true;
    }

    if (g_aPlayers[client][iBlockTime] > GetTime())
    {
        return true;
    }

    return false;
}

public Native_GS_IsBlocked(Handle:plugin, numParams)
{
    new client = GetNativeCell(1), initiator = GetNativeCell(2);

    if (!client || client > MaxClients || !IsClientInGame(client))
    {
        return ThrowNativeError(SP_ERROR_NATIVE, "Invalid client index");
    }

    if (IsBlocked(client))
    {
        if (initiator)
        {
            HandleStacker(client);
        }

        return true;
    }

    return false;
}

stock CreateVoteCommand()
{
    if (!g_bVoteCommandCreated)
    {
        decl String:sCommand[256];
        GetConVarString(cvar_VoteCommand, sCommand, sizeof(sCommand));
        ExplodeString(sCommand, ",", g_sVoteCommands, 3, sizeof(g_sVoteCommands[]));

        for (new i; i < 3; i++)
        {
            if (strlen(g_sVoteCommands[i]) > 2)
            {
                g_bVoteCommandCreated = true;
                RegConsoleCmd(g_sVoteCommands[i], CMD_VoteTrigger);
            }
        }
    }
}

public Action:CMD_VoteTrigger(client, args)
{
    if (!IsFakeClient(client))
    {
        AttemptScrambleVote(client);
    }

    return Plugin_Handled;
}

public OnConfigsExecuted()
{
    g_bUseGameMe = false;
    g_bUseHlxCe = false;

    if (GetFeatureStatus(FeatureType_Native, "HLXCE_GetPlayerData") == FeatureStatus_Available)
    {
        g_bUseHlxCe = true;

        LogMessage("HlxCe Available");
    }
    else
    {
        LogMessage("HlxCe Unavailable");
    }

    CreateVoteCommand();

    if (GetFeatureStatus(FeatureType_Native, "QueryGameMEStats") == FeatureStatus_Available)
    {
        g_bUseGameMe = true;

        LogMessage("GameMe Available");
    }
    else
    {
        g_bUseGameMe = false;

        LogMessage("GameMe Unavailavble");
    }

    decl String:sMapName[32];
    new bool:bAuto = false;

    GetCurrentMap(sMapName, 32);
    if (StrContains(sMapName, "workshop") != -1)
	{
		GetMapDisplayName(sMapName, sMapName, sizeof sMapName);
	}
    SetConVarString(cvar_Version, VERSION);

    //load load global values
    g_bSelectSpectators = GetConVarBool(cvar_SelectSpectators);
    g_bSilent = GetConVarBool(cvar_Silent);
    g_bAutoBalance = GetConVarBool(cvar_Balancer);
    g_bFullRoundOnly = GetConVarBool(cvar_FullRoundOnly);
    g_bForceTeam = GetConVarBool(cvar_ForceTeam);
    g_iForceTime = GetConVarInt(cvar_ForceTeam);
    g_bAutoScramble = GetConVarBool(cvar_AutoScramble);
    GetConVarInt(cvar_MenuVoteEnd) ? (g_iDefMode = Scramble_Now) : (g_iDefMode = Scramble_Round);
    g_bNoSequentialScramble = GetConVarBool(cvar_NoSequentialScramble);
    g_bUseBuddySystem = GetConVarBool(cvar_BuddySystem);

    if (g_bUseClientPrefs)
    {
        g_bForceReconnect = GetConVarBool(cvar_ForceReconnect);
    }

    if (GetConVarBool(cvar_Enabled))
    {
        if (g_bAutoBalance)
        {
            if (GetConVarBool(FindConVar("mp_autoteambalance")))
            {
                LogAction(-1, 0, "set mp_autoteambalance to false");

                SetConVarBool(FindConVar("mp_autoteambalance"), false);
            }
        }
        if (!g_bHooked)
        {
            hook();
        }
    }
    else if (g_bHooked)
    {
        unHook();
    }

    g_bKothMode = false;
    g_bArenaMode = false;

    if (GetConVarBool(cvar_AutoScramble) || GetConVarBool(cvar_AutoScrambleWinStreak))
    {
        bAuto = true;
    }

    if (GetConVarBool(cvar_AutoScrambleRoundCount))
    {
        bAuto = true;
        g_iRoundTrigger = GetConVarInt(cvar_AutoScrambleRoundCount);
    }


    //shut off tf2's built in auto-scramble
    //if gscramble's auto modes are enabled.
    if (bAuto)
    {
        if (GetConVarBool(FindConVar("mp_scrambleteams_auto")))
        {
            SetConVarBool(FindConVar("mp_scrambleteams_auto"), false);
            LogMessage("Setting mp_scrambleteams_auto false");
        }
        if (GetConVarBool(FindConVar("sv_vote_issue_scramble_teams_allowed")))
        {
            SetConVarBool(FindConVar("sv_vote_issue_scramble_teams_allowed"), false);
            LogMessage("Setting 'sv_vote_issue_scramble_teams_allowed' to '0'");
        }
    }

    if (GetConVarBool(cvar_Koth) && strncmp(sMapName, "koth_", 5, false) == 0)
    {
        g_bRedCapped = false;
        g_bBluCapped = false;
        g_bKothMode = true;
    }
    else if (strncmp(sMapName, "arena_", 6, false) == 0)
    {
        if (GetConVarBool(FindConVar("tf_arena_use_queue")))
        {
            if (g_bHooked)
            {
                LogAction(-1, 0, "Unhooking events since it's arena, and tf_arena_use_queue is enabled");

                unHook();
            }

            g_bArenaMode = true;
        }
    }

    if (!GetConVarBool(cvar_MenuIntegrate))
    {
        if (g_hAdminMenu != INVALID_HANDLE && g_Category != INVALID_TOPMENUOBJECT)
        {
            RemoveFromTopMenu(g_hAdminMenu, g_Category);
            g_hAdminMenu = INVALID_HANDLE;
            g_Category = INVALID_TOPMENUOBJECT;
        }
    }

    if (g_hVoteAdTimer != INVALID_HANDLE)
    {
        KillTimer(g_hVoteAdTimer);
        g_hVoteAdTimer = INVALID_HANDLE;
    }

    new Float:fAd = GetConVarFloat(cvar_VoteAd);

    if (fAd > 0.0)
    {
        g_hVoteAdTimer = CreateTimer(fAd, Timer_VoteAd, _, TIMER_REPEAT);
    }

    if (GetConVarBool(cvar_BlockJointeam))
    {
        g_bBlockJointeam = true;
        SetConVarBool(FindConVar("mp_forceautoteam"), true);
    }
    else
    {
        g_bBlockJointeam = false;
    }

    #if defined GAMEME_INCLUDED
    if (g_bUseGameMe && e_ScrambleModes:GetConVarInt(cvar_SortMode) == gameMe_SkillChange)
    {
        StartSkillUpdates();
    }
    else
    {
        StopSkillUpdates();
    }
    #endif
}

public Action:Timer_VoteAd(Handle:timer)
{
    decl String:sVotes[120];
    if (strlen(g_sVoteCommands[0]))
    {
        Format(sVotes, sizeof(sVotes), "!%s", g_sVoteCommands[0]);
    }

    if (strlen(g_sVoteCommands[1]))
    {
        Format(sVotes, sizeof(sVotes), "%s, !%s", sVotes, g_sVoteCommands[1]);
    }

    if (strlen(g_sVoteCommands[2]))
    {
        Format(sVotes, sizeof(sVotes), "%s, or !%s", sVotes, g_sVoteCommands[2]);
    }

    if (strlen(sVotes))
    {
        MC_PrintToChatAll("[{creators}Creators.TF{default}] %t", "VoteAd", sVotes);
    }

    return Plugin_Continue;
}

public handler_ConVarChange(Handle:convar, const String:oldValue[], const String:newValue[])
{
    new iNewValue = StringToInt(newValue);
    if (convar == cvar_Enabled)
    {
        new bool:teamBalance;

        if (!iNewValue && g_bHooked)
        {
            teamBalance = true;
            unHook();
        }
        else if (!g_bHooked)
        {
            teamBalance = false;
            hook();
        }

        if (GetConVarBool(cvar_Balancer))
        {
            SetConVarBool(FindConVar("mp_autoteambalance"), teamBalance);
            LogAction(0, -1, "set conVar mp_autoteambalance to %i.", teamBalance);
        }
    }

    #if defined GAMEME_INCLUDED
    if (convar == cvar_SortMode)
    {
        if (g_bUseGameMe && e_ScrambleModes:iNewValue == gameMe_SkillChange)
        {
            StartSkillUpdates();
        }
        else
        {
            StopSkillUpdates();
        }
    }
    #endif

    if (convar == cvar_FullRoundOnly)
    {
        iNewValue == 1 ? (g_bFullRoundOnly = true) : (g_bFullRoundOnly = false);
    }

    if (convar == cvar_Balancer)
    {
        iNewValue == 1 ? (g_bAutoBalance = true) : (g_bAutoBalance = false);
    }

    if (convar == cvar_ForceTeam)
    {
        g_iForceTime = iNewValue;
        iNewValue == 1 ? (g_bForceTeam = true) : (g_bForceTeam = false);
    }

    if (convar == cvar_ForceReconnect && g_bUseClientPrefs)
    {
        iNewValue == 1 ? (g_bForceReconnect = true) : (g_bForceReconnect = false);
    }


    if (convar == cvar_AutoScramble)
    {
        iNewValue == 1  ? (g_bAutoScramble = true):(g_bAutoScramble = false);
    }

    if (convar == cvar_MenuVoteEnd)
    {
        iNewValue == 1 ? (g_iDefMode = Scramble_Now) : (g_iDefMode = Scramble_Round);
    }

    if (convar == cvar_NoSequentialScramble)
    {
        g_bNoSequentialScramble = iNewValue?true:false;
    }

    if (convar == cvar_AutoTeamBalance)
    {
        if (g_bHooked && g_bAutoBalance)
        {
            if (StringToInt(newValue))
            {
                LogMessage("Something tried to enable the built in balancer with gs_autobalance still enabled.");
                SetConVarBool(convar, false);
                LogAction(0, -1, "Setting mp_autoteambalance back to 0");
            }
        }
    }
}

#if defined GAMEME_INCLUDED
stock StartSkillUpdates()
{
    if (g_hGameMeUpdateTimer != INVALID_HANDLE)
    {
        return;
    }

    LogMessage("Starting gameMe data update timer");
    g_hGameMeUpdateTimer = CreateTimer(60.0, Timer_GameMeUpdater, _, TIMER_REPEAT);
    UpdateSessionSkill();
}

public Action:Timer_GameMeUpdater(Handle:timer)
{
    UpdateSessionSkill();
    return Plugin_Continue;
}

stock StopSkillUpdates()
{
    if (g_hGameMeUpdateTimer != INVALID_HANDLE)
    {
        KillTimer(g_hGameMeUpdateTimer);
        g_hGameMeUpdateTimer = INVALID_HANDLE;
    }
}


stock UpdateSessionSkill()
{
    if (GetFeatureStatus(FeatureType_Native, "QueryGameMEStats") == FeatureStatus_Available)
    {
        for (new i = 1; i <= MaxClients; i++)
        {
            if (IsClientInGame(i) && !IsFakeClient(i))
            {
                QueryGameMEStats("playerinfo", i, QuerygameMEStatsCallback, 0);
            }
        }
    }
    else
    {
        g_bUseGameMe = false;
    }
}
#endif

hook()
{
    LogAction(0, -1, "Hooking events.");
    HookEvent("teamplay_round_start",       Event_RoundStart, EventHookMode_PostNoCopy);
    HookEvent("player_disconnect", Event_PlayerDisconnect, EventHookMode_Post);
    HookEvent("teamplay_round_win",         Event_RoundWin, EventHookMode_Post);
    HookEvent("teamplay_round_active",      Event_RoundActive);
    HookEvent("teamplay_pre_round_time_left", Event_SetupActive);
    HookEvent("teamplay_setup_finished",    hook_Setup, EventHookMode_PostNoCopy);
    HookEvent("player_death",               Event_PlayerDeath_Pre, EventHookMode_Pre);
    HookEvent("game_start",                 hook_Event_GameStart);
    HookEvent("teamplay_restart_round",     hook_Event_TFRestartRound);
    HookEvent("player_team",                Event_PlayerTeam_Pre, EventHookMode_Pre);
    HookEvent("teamplay_round_stalemate",   hook_RoundStalemate, EventHookMode_PostNoCopy);
    HookEvent("teamplay_point_captured",    hook_PointCaptured, EventHookMode_Post);
    HookEvent("object_destroyed",           hook_ObjectDestroyed, EventHookMode_Post);
    HookEvent("teamplay_flag_event",        hook_FlagEvent, EventHookMode_Post);
    HookEvent("teamplay_pre_round_time_left",           hookPreRound, EventHookMode_PostNoCopy);
    HookEvent("teamplay_capture_blocked", Event_capture_blocked);
    HookEvent("player_extinguished", Event_player_extinguished);
    HookUserMessage(GetUserMessageId("TextMsg"), UserMessageHook_Class, false);
    AddGameLogHook(LogHook);

    HookEvent("teamplay_game_over", hook_GameEnd, EventHookMode_PostNoCopy);
    HookEvent("player_chargedeployed", hook_UberDeploy, EventHookMode_Post);
    HookEvent("player_sapped_object", hook_Sapper, EventHookMode_Post);
    HookEvent("medic_death", hook_MedicDeath, EventHookMode_Post);
    HookEvent("controlpoint_endtouch", hook_EndTouch, EventHookMode_Post);
    HookEvent("teamplay_timer_time_added", TimerUpdateAdd, EventHookMode_PostNoCopy);
    g_bHooked = true;
}

public Action:LogHook(const String:message[])
{
    if (g_bBlockDeath)
    {
        return Plugin_Handled;
    }

    return Plugin_Continue;
}

unHook()
{
    LogAction(0, -1, "Unhooking events");
    UnhookEvent("player_disconnect", Event_PlayerDisconnect, EventHookMode_Post);
    UnhookEvent("teamplay_round_start",         Event_RoundStart, EventHookMode_PostNoCopy);
    UnhookEvent("teamplay_round_win",       Event_RoundWin, EventHookMode_Post);
    UnhookEvent("teamplay_setup_finished",  hook_Setup, EventHookMode_PostNoCopy);
    UnhookEvent("player_death",                 Event_PlayerDeath_Pre, EventHookMode_Pre);
    UnhookEvent("game_start",               hook_Event_GameStart);
    UnhookEvent("teamplay_restart_round",   hook_Event_TFRestartRound);
    UnhookEvent("player_team",              Event_PlayerTeam_Pre, EventHookMode_Pre);
    UnhookEvent("teamplay_round_stalemate", hook_RoundStalemate, EventHookMode_PostNoCopy);
    UnhookEvent("teamplay_point_captured",  hook_PointCaptured, EventHookMode_Post);
    UnhookEvent("teamplay_game_over", hook_GameEnd, EventHookMode_PostNoCopy);
    UnhookEvent("object_destroyed", hook_ObjectDestroyed, EventHookMode_Post);
    UnhookEvent("teamplay_flag_event",      hook_FlagEvent, EventHookMode_Post);
    UnhookUserMessage(GetUserMessageId("TextMsg"), UserMessageHook_Class, false);
    UnhookEvent("player_chargedeployed", hook_UberDeploy, EventHookMode_Post);
    UnhookEvent("player_sapped_object", hook_Sapper, EventHookMode_Post);
    UnhookEvent("medic_death", hook_MedicDeath, EventHookMode_Post);
    UnhookEvent("controlpoint_endtouch", hook_EndTouch, EventHookMode_Post);
    UnhookEvent("teamplay_timer_time_added", TimerUpdateAdd, EventHookMode_PostNoCopy);
    UnhookEvent("teamplay_pre_round_time_left",         hookPreRound, EventHookMode_PostNoCopy);
    UnhookEvent("teamplay_capture_blocked", Event_capture_blocked);
    UnhookEvent("player_extinguished", Event_player_extinguished);
    UnhookEvent("teamplay_round_active",        Event_RoundActive);
    UnhookEvent("teamplay_pre_round_time_left", Event_SetupActive);

    g_bHooked = false;
}

public Event_SetupActive(Handle event, const char[] name, bool dontBroadcast)
{
    g_RoundState = setup;
}

public Event_RoundActive(Handle event, const char[] name, bool dontBroadcast)
{
    g_RoundState = normal;
}

public Event_player_extinguished(Handle event, const char[] name, bool dontBroadcast)
{
    new healer = GetClientOfUserId(GetEventInt(event, "healer"));
    new victim = GetClientOfUserId(GetEventInt(event, "victim"));
    if (!healer || !victim)
        return;
    AddTeamworkTime(healer, playerExtinguish);
}

public Event_capture_blocked(Handle:event, const String:name[], bool:dontBroadcast)
{
    new client = GetEventInt(event, "blocker");
    if (client && g_RoundState == normal)
    {
        AddTeamworkTime(client, controlPointBlock);
    }
}

/**
add protection to those killing fully charged medics
*/
public hook_MedicDeath(Handle:event, const String:name[], bool:dontBroadcast)
{
    if (g_RoundState == normal && GetEventBool(event, "charged"))
    {
        AddTeamworkTime(GetClientOfUserId(GetEventInt(event, "userid")), medicKill);
    }
}

public hookPreRound(Handle:event, const String:name[], bool:dontBroadcast)
{
    g_RoundState = preGame;
}

public hook_EndTouch(Handle:event, const String:name[], bool:dontBroadcast)
{
    if (g_RoundState == normal)
    {
        AddTeamworkTime(GetEventInt(event, "player"), controlPointTouch);
    }
}

/**
add protection to those sapping buildings
*/
public hook_Sapper(Handle:event, const String:name[], bool:dontBroadcast)
{
    if (g_RoundState == normal)
    {
        AddTeamworkTime(GetClientOfUserId(GetEventInt(event, "userid")), placeSapper);
    }
}

/**
add protection to those deploying uber
*/
public hook_UberDeploy(Handle:event, const String:name[], bool:dontBroadcast)
{
    if (g_RoundState == normal)
    {
        new medic = GetClientOfUserId(GetEventInt(event, "userid")), target = GetClientOfUserId(GetEventInt(event, "targetid"));

        AddTeamworkTime(medic, medicDeploy);
        AddTeamworkTime(target, medicDeploy);
    }
}

public hook_ObjectDestroyed(Handle:event, const String:name[], bool:dontBroadcast)
{
    /**
    adds teamwork protection if clients destroy a sentry
    */
    if (g_RoundState == normal && GetEventInt(event, "objecttype") == 3)
    {
        new client = GetClientOfUserId(GetEventInt(event, "attacker")), assister = GetClientOfUserId(GetEventInt(event, "assister"));

        AddTeamworkTime(client, buildingKill);
        AddTeamworkTime(assister, buildingKill);
    }
}

public hook_GameEnd(Handle:event, const String:name[], bool:dontBroadcast)
{
    g_RoundState = mapEnding;
}

public hook_PointCaptured(Handle:event, const String:name[], bool:dontBroadcast)
{
    if (GetConVarBool(cvar_BalanceTimeLimit))
        GetRoundTimerInformation(true);
    if (GetConVarBool(cvar_TeamworkProtect))
    {
        decl String:cappers[128];
        GetEventString(event, "cappers", cappers, sizeof(cappers));

        new len = strlen(cappers);
        for (new i = 0; i < len; i++)
        {
            AddTeamworkTime(cappers[i], controlPointCaptured);
        }
    }

    if (g_bKothMode)
    {
        GetEventInt(event, "team") == TEAM_RED ? (g_bRedCapped = true) : (g_bBluCapped = true);
    }
}

public hook_RoundStalemate(Handle:event, const String:name[], bool:dontBroadcast)
{
    if (GetConVarBool(cvar_ForceBalance) && g_aTeams[bImbalanced])
    {
        BalanceTeams(true);
    }

    g_RoundState = suddenDeath;
}

/**
add protection to those interacting with the CTF flag
*/
public hook_FlagEvent(Handle:event, const String:name[], bool:dontBroadcast)
{
    new client = GetEventInt(event, "player");
    new type = GetEventInt(event, "eventtype");

    switch (type)
    {
        case 1:
        {
            g_aPlayers[client][bHasFlag] = true;
        }
        default:
        {
            g_aPlayers[client][bHasFlag] = false;
        }
    }

    AddTeamworkTime(GetEventInt(event, "player"), flagEvent);
}

/*public Action:hook_EscortProgress(Handle:event, const String:name[], bool:dontBroadcast)
{
    g_fEscortProgress = GetEventFloat(event, "progress");
}*/

public Action:Event_PlayerTeam_Pre(Handle:event, const String:name[], bool:dontBroadcast)
{
    if (g_bBlockDeath)
    {
        SetEventBroadcast(event, true);
        return Plugin_Continue;
    }

    CheckBalance(true);
    return Plugin_Continue;
}

public hook_Event_TFRestartRound(Handle:event, const String:name[], bool:dontBroadcast)
{
    g_iCompleteRounds = 0;
}

public hook_Event_GameStart(Handle:event, const String:name[], bool:dontBroadcast)
{
    g_aTeams[iRedFrags] = 0;
    g_aTeams[iBluFrags] = 0;
    g_iCompleteRounds = 0;
    g_RoundState = preGame;
    g_aTeams[iRedWins] = 0;
    g_aTeams[iBluWins] = 0;
}

#if defined GAMEME_INCLUDED
public OnClientPutInServer(client)
{
    if (IsFakeClient(client))
    {
        return;
    }

    if (g_bUseGameMe && client > 0 && !IsFakeClient(client))
    {
        if (GetFeatureStatus(FeatureType_Native, "QueryGameMEStats") == FeatureStatus_Available)
        {
            QueryGameMEStats("playerinfo", client, QuerygameMEStatsCallback, 1);
        }
        else
        {
            g_bUseGameMe = false;
        }
    }
}
#endif

#if defined GAMEME_INCLUDED
public QuerygameMEStatsCallback(command, payload, client, &Handle: datapack)
{
    if ((client > 0) && (command == RAW_MESSAGE_CALLBACK_PLAYER))
    {
        new Handle: data = CloneHandle(datapack);
        ResetPack(data);
        g_aPlayers[client][iGameMe_Rank] = ReadPackCell(data);
        SetPackPosition(data, GetPackPosition(data)+1);
        g_aPlayers[client][iGameMe_Skill] = ReadPackCell(data);
        SetPackPosition(data, GetPackPosition(data)+28);
        g_aPlayers[client][iGameMe_gRank] = ReadPackCell(data);
        SetPackPosition(data, GetPackPosition(data)+1);
        g_aPlayers[client][iGameMe_gSkill] = ReadPackCell(data);
        SetPackPosition(data, GetPackPosition(data) -16);
        g_aPlayers[client][iGameMe_SkillChange] = ReadPackCell(data);
        CloseHandle(data);
    }
}
#endif

public OnClientDisconnect(client)
{
    if (IsFakeClient(client))
    {
        return;
    }

    g_aPlayers[client][bHasFlag] = false;
    if (g_aPlayers[client][bHasVoted] == true)
    {
        g_iVotes--;
        g_aPlayers[client][bHasVoted] = false;
    }

    updateVoters();
    g_aPlayers[client][iTeamPreference] = 0;

    if (GetConVarBool(cvar_AdminBlockVote) && g_aPlayers[client][bIsVoteAdmin])
    {
        g_iNumAdmins--;
    }
}

public Action:Event_PlayerDisconnect(Handle:event, const String:name[], bool:dontBroadcast)
{
    CheckBalance(true);
    new client = GetClientOfUserId(GetEventInt(event, "userid"));

    if (client && !IsFakeClient(client))
    {
        /**
        check to see if we should remember his info for disconnect
        reconnect team blocking
        */
        if (g_bUseClientPrefs && g_bForceTeam && g_bForceReconnect && IsClientInGame(client) && IsValidTeam(client) && (g_bTeamsLocked || IsBlocked(client)))
        {
            decl String:blockTime[128], String:teamIndex[5], String:serverIp[50], String:serverPort[10], String:startTime[33];
            new iIndex;
            GetConVarString(FindConVar("hostip"), serverIp, sizeof(serverIp));
            GetConVarString(FindConVar("hostport"), serverPort, sizeof(serverPort));
            Format(serverIp, sizeof(serverIp), "%s%s", serverIp, serverPort);
            IntToString(GetTime(), blockTime, sizeof(blockTime));
            IntToString(g_iPluginStartTime, startTime, sizeof(startTime));

            if (g_iTeamIds[1] == GetClientTeam(client))
            {
                iIndex = 1;
            }

            IntToString(iIndex, teamIndex, sizeof(teamIndex));
            SetClientCookie(client, g_cookie_timeBlocked, blockTime);
            SetClientCookie(client, g_cookie_teamIndex, teamIndex);
            SetClientCookie(client, g_cookie_serverIp, serverIp);
            SetClientCookie(client, g_cookie_serverStartTime, startTime);
            LogAction(client, -1, "\"%L\" is team swap blocked, and is being saved.", client);
        }
        if (g_bUseBuddySystem)
        {
            for (new i = 1; i <= MaxClients; i++)
            {
                if (g_aPlayers[i][iBuddy] == client)
                {
                    if (IsClientInGame(i))
                    {
                        MC_PrintToChat(i, "[{creators}Creators.TF{default}] %t", "YourBuddyLeft");
                    }

                    g_aPlayers[i][iBuddy] = 0;
                }
            }
        }
    }
}

public OnClientPostAdminCheck(client)
{
    if(IsFakeClient(client))
    {
        return;
    }

    if (GetConVarBool(cvar_Preference) && g_bAutoBalance && g_bHooked)
    {
        CreateTimer(25.0, Timer_PrefAnnounce, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
    }

    g_aPlayers[client][iBlockTime] = 0;
    g_aPlayers[client][iBalanceTime] = 0;
    g_aPlayers[client][iTeamworkTime] = 0;
    g_aPlayers[client][iFrags] = 0;
    g_aPlayers[client][iDeaths] = 0;
    g_aPlayers[client][bHasFlag] = false;
    g_aPlayers[client][iSpecChangeTime] = 0;

    if (GetConVarBool(cvar_AdminBlockVote) && CheckCommandAccess(client, "sm_scramblevote", ADMFLAG_BAN))
    {
        g_aPlayers[client][bIsVoteAdmin] = true;
        g_iNumAdmins++;
    }
    else
    {
        g_aPlayers[client][bIsVoteAdmin] = false;
    }

    g_aPlayers[client][bHasVoted] = false;
    updateVoters();
}

#if defined HLXCE_INCLUDED
public HLXCE_OnClientReady(client)
{
    HLXCE_GetPlayerData(client);
}

public HLXCE_OnGotPlayerData(client, const PData[HLXCE_PlayerData])
{
    g_aPlayers[client][iHlxCe_Rank] = PData[PData_Rank];
    g_aPlayers[client][iHlxCe_Skill] = PData[PData_Skill];
}
#endif

public OnClientCookiesCached(client)
{
    if (!IsClientConnected(client) || IsFakeClient(client) || !g_bForceTeam || !g_bForceReconnect)
    {
        return;
    }

    g_aPlayers[client][iBlockWarnings] = 0;
    decl String:sStartTime[33];
    GetClientCookie(client, g_cookie_serverStartTime, sStartTime, sizeof(sStartTime));

    if (StringToInt(sStartTime) != g_iPluginStartTime)
    {
        return;
        /**
        bug out since the sessions dont match
        */
    }

    decl String:time[32], iTime, String:clientServerIp[33], String:serverIp[100], String:serverPort[100];
    GetConVarString(FindConVar("hostip"), serverIp, sizeof(serverIp));
    GetConVarString(FindConVar("hostport"), serverPort, sizeof(serverPort));
    Format(serverIp, sizeof(serverIp), "%s%s", serverIp, serverPort);
    GetClientCookie(client, g_cookie_timeBlocked, time, sizeof(time));
    GetClientCookie(client, g_cookie_serverIp, clientServerIp, sizeof(clientServerIp));

    if ((iTime = StringToInt(time)) && strncmp(clientServerIp, serverIp, true) == 0)
    {
        if (iTime > g_iMapStartTime && (GetTime() - iTime) <= GetConVarInt(cvar_ForceTeam))
        {
            LogAction(client, -1, "\"%L\" is reconnect blocked", client);
            SetupTeamSwapBlock(client);
            CreateTimer(10.0, timer_Restore, GetClientUserId(client));
        }
    }
}

public Action:Timer_PrefAnnounce(Handle:timer, any:id)
{
    new client;

    if ((client = GetClientOfUserId(id)))
    {
        MC_PrintToChat(client, "[{creators}Creators.TF{default}] %t", "PrefAnnounce");
    }

    return Plugin_Handled;
}

public Action:timer_Restore(Handle:timer, any:id)
{
    /**
    make sure that the client is still conneceted
    */
    new client;

    if (!(client = GetClientOfUserId(id)) || !IsClientInGame(client))
    {
        return Plugin_Handled;
    }

    new String:sIndex[10], iIndex;
    GetClientCookie(client, g_cookie_teamIndex, sIndex, sizeof(sIndex));

    iIndex = StringToInt(sIndex);
    if (iIndex != 0 || iIndex != 1)
    {
        return Plugin_Handled;
    }

    if (GetClientTeam(client) != g_iTeamIds[iIndex])
    {
        ChangeClientTeam(client, g_iTeamIds[iIndex]);
        ShowVGUIPanel(client, "team", _, false);
        MC_PrintToChat(client, "[{creators}Creators.TF{default}] %t", "TeamRestore");
        TF2_SetPlayerClass(client, TFClass_Scout);
        LogAction(client, -1, "\"%L\" has had his/her old team restored after reconnecting.", client);
        RestoreMenuCheck(client, g_iTeamIds[iIndex]);
    }

    return Plugin_Handled;
}

public OnMapStart()
{
    g_iMapStartTime = GetTime();
    /**
    * reset most of what we track with this plugin
    * team wins, frags, gamestate... ect
    */
    g_iImmunityDisabledWarningTime = 0;
    g_bTeamsLocked = false;
    g_bScrambledThisRound = false;
    g_bScrambleOverride = false;
    g_iRoundTrigger = 0;
    g_aTeams[iRedFrags] = 0;
    g_aTeams[iBluFrags] = 0;
    g_iCompleteRounds = 0;
    g_bScrambleNextRound = false;
    g_aTeams[iRedWins] = 0;
    g_aTeams[iBluWins] = 0;
    g_RoundState = newGame;
    g_bWasFullRound = false;
    g_bPreGameScramble = false;
    g_bIsTimer = false;
    g_bPreGameScramble = false;
    g_iVotes = 0;
    PrecacheSound(SCRAMBLE_SOUND, true);
    PrecacheSound(EVEN_SOUND, true);
    //g_fEscortProgress = 0.0;

    if (g_hBalanceFlagTimer != INVALID_HANDLE)
    {
        KillTimer(g_hBalanceFlagTimer);
        g_hBalanceFlagTimer = INVALID_HANDLE;
    }

    if (g_hForceBalanceTimer != INVALID_HANDLE)
    {
        KillTimer(g_hForceBalanceTimer);
        g_hForceBalanceTimer = INVALID_HANDLE;
    }

    g_hCheckTimer = INVALID_HANDLE;

    if (g_hScrambleNowPack != INVALID_HANDLE)
    {
        CloseHandle(g_hScrambleNowPack);
    }

    g_hScrambleNowPack = INVALID_HANDLE;
    g_iLastRoundWinningTeam = 0;
}

AddTeamworkTime(client, eTeamworkReasons:reason)
{
    if (!GetConVarBool(cvar_TeamworkProtect))
        return;
    if (g_RoundState == normal && client && IsClientInGame(client) && !IsFakeClient(client))
    {
        new iTime;
        switch (reason)
        {
            case flagEvent:
                iTime = GetConVarInt(cvar_TeamWorkFlagEvent);
            case medicKill:
                iTime = GetConVarInt(cvar_TeamWorkMedicKill);
            case medicDeploy:
                iTime = GetConVarInt(cvar_TeamWorkUber);
            case buildingKill:
                iTime = GetConVarInt(cvar_TeamWorkBuildingKill);
            case placeSapper:
                iTime = GetConVarInt(cvar_TeamWorkPlaceSapper);
            case controlPointCaptured:
                iTime = GetConVarInt(cvar_TeamWorkCpCapture);
            case controlPointTouch:
                iTime = GetConVarInt(cvar_TeamWorkCpTouch);
            case controlPointBlock:
                iTime = GetConVarInt(cvar_TeamWorkCpBlock);
            case playerExtinguish:
                iTime = GetConVarInt(cvar_TeamWorkExtinguish);
        }
        g_aPlayers[client][iTeamworkTime] = GetTime()+iTime;
    }
}

public OnMapEnd()
{
    if (g_hScrambleDelay != INVALID_HANDLE)
        KillTimer(g_hScrambleDelay);
    g_hScrambleDelay = INVALID_HANDLE;
}

public Action:TimerEnable(Handle:timer)
{
    g_bVoteAllowed = true;
    g_hVoteDelayTimer = INVALID_HANDLE;
    return Plugin_Handled;
}

public Action:cmd_ResetVotes(client, args)
{
    PerformVoteReset(client);
    return Plugin_Handled;
}

PerformVoteReset(client)
{
    LogAction(client, -1, "\"%L\" has reset all the public votes", client);
    ShowActivity(client, "%t", "AdminResetVotes");
    MC_ReplyToCommand(client, "[{creators}Creators.TF{default}] %t", "ResetReply", g_iVotes);

    for (new i = 1; i <= MaxClients; i++)
    {
        g_aPlayers[i][bHasVoted] = false;
    }

    g_iVotes = 0;
}

HandleStacker(client)
{
    if (g_aPlayers[client][iBlockWarnings] < 2)
    {
        new String:clientName[MAX_NAME_LENGTH + 1];

        GetClientName(client, clientName, 32);
        LogAction(client, -1, "\"%L\" was blocked from changing teams", client);
        MC_ReplyToCommand(client, "[{creators}Creators.TF{default}] %t", "BlockSwitchMessage");

        if (!g_bSilent)
        {
            MC_PrintToChatAll("[{creators}Creators.TF{default}] %t", "ShameMessage", clientName);
        }

        g_aPlayers[client][iBlockWarnings]++;
    }

    if (GetConVarBool(cvar_Punish))
    {
        SetupTeamSwapBlock(client);
    }

}

public Action:cmd_Balance(client, args)
{
    PerformBalance(client);
    return Plugin_Handled;
}

PerformBalance(client)
{
    if (g_bArenaMode)
    {
        MC_ReplyToCommand(client, "[{creators}Creators.TF{default}] %t", "ArenaReply");
        return;
    }

    if (!g_bHooked)
    {
        MC_ReplyToCommand(client, "[{creators}Creators.TF{default}] %t", "EnableReply");
        return;
    }

    if (TeamsUnbalanced(false))
    {
        BalanceTeams(true);
        LogAction(client, -1, "\"%L\" performed the force balance command", client);
        ShowActivity(client, "%t", "AdminForceBalance");
    }
    else
    {
        MC_ReplyToCommand(client, "[{creators}Creators.TF{default}] %t", "NoImbalnceReply");
    }

}

Float:GetAvgScoreDifference(team)
{
    new teamScores, otherScores, Float:otherAvg, Float:teamAvg;

    for (new i = 1; i <= MaxClients; i++)
    {
        new entity = GetPlayerResourceEntity();
        new Totalscore = GetEntProp(entity, Prop_Send, "m_iScore", _, i);

        if (IsClientInGame(i) && IsValidTeam(i))
        {
            if (GetClientTeam(i) == team)
            {
                teamScores += Totalscore;
            }
            else
            {
                otherScores += Totalscore;
            }
        }
    }
    teamAvg = float(teamScores) / float(GetTeamClientCount(team));
    otherAvg = float(otherScores) / float(GetTeamClientCount(team == TEAM_RED ? TEAM_BLUE : TEAM_RED));

    if (otherAvg > teamAvg)
    {
        return 0.0;
    }

    return FloatAbs(teamAvg - otherAvg);
}

public Action:cmd_Scramble_Now(client, args)
{
    if (args > 3)
    {
        MC_ReplyToCommand(client, "[{creators}Creators.TF{default}] %t", "NowCommandReply");
        return Plugin_Handled;
    }

    new Float:fDelay = 5.0, bool:respawn = true, e_ScrambleModes:mode;

    if (args)
    {
        char arg1[5];
        GetCmdArg(1, arg1, sizeof(arg1));

        if((fDelay = StringToFloat(arg1)) == 0.0)
        {
            MC_ReplyToCommand(client, "[{creators}Creators.TF{default}] %t", "NowCommandReply");
            return Plugin_Handled;
        }

        if (args > 1)
        {
            char arg2[2];
            GetCmdArg(2, arg2, sizeof(arg2));
            if (!StringToInt(arg2))
                respawn = false;
        }

        if (args > 2)
        {
            char arg3[5];
            GetCmdArg(3, arg3, sizeof(arg3));
            LogMessage("arg3 = %s", arg3);
            if (StrEqual(arg3, "-1"))
            {
                mode = view_as<e_ScrambleModes>(GetConVarInt(cvar_SortMode));
                LogMessage("SCRAMBLING NOW with mode %i", view_as<int>(mode));
                PerformScrambleNow(client, fDelay, respawn, mode);
                return Plugin_Handled;
            }
            if ((mode = e_ScrambleModes:StringToInt(arg3)) > randomSort)
            {
                MC_ReplyToCommand(client, "[{creators}Creators.TF{default}] %t", "NowCommandReply");
                return Plugin_Handled;
            }
        }
    }

    PerformScrambleNow(client, fDelay, respawn, mode);
    return Plugin_Handled;
}

stock PerformScrambleNow(client, Float:fDelay = 5.0, bool:respawn = false, e_ScrambleModes:mode = invalid)
{
    if (!g_bHooked)
    {
        MC_ReplyToCommand(client, "[{creators}Creators.TF{default}] %t", "EnableReply");
        return;
    }

    if (g_bNoSequentialScramble && g_bScrambledThisRound)
    {
        MC_ReplyToCommand(client, "[{creators}Creators.TF{default}] %t", "ScrambledAlready");
        return;
    }

    if (g_bScrambleNextRound)
    {
        g_bScrambleNextRound = false;
        if (g_hScrambleDelay != INVALID_HANDLE)
        {
            KillTimer(g_hScrambleDelay);
            g_hScrambleDelay = INVALID_HANDLE;
        }
    }

    LogAction(client, -1, "\"%L\" performed the scramble command", client);
    ShowActivity(client, "%t", "AdminScrambleNow");
    StartScrambleDelay(fDelay, respawn, mode);
}

stock AttemptScrambleVote(client)
{
    if (g_bArenaMode)
    {
        MC_ReplyToCommand(client, "[{creators}Creators.TF{default}] %t", "ArenaReply");
        return;
    }

    if (GetConVarBool(cvar_AdminBlockVote) && g_iNumAdmins > 0)
    {
        MC_ReplyToCommand(client, "[{creators}Creators.TF{default}] %t", "AdminBlockVoteReply");
        return;
    }

    if (!g_bHooked)
    {
        MC_ReplyToCommand(client, "[{creators}Creators.TF{default}] %t", "EnableReply");
        return;
    }

    new bool:Override = false;

    if (!GetConVarBool(cvar_VoteEnable))
    {
        MC_ReplyToCommand(client, "[{creators}Creators.TF{default}] %t", "VoteDisabledReply");
        return;
    }

    if (g_bNoSequentialScramble && g_bScrambledThisRound)
    {
        MC_ReplyToCommand(client, "[{creators}Creators.TF{default}] %t", "ScrambledAlready");
        return;
    }

    if (!g_bVoteAllowed)
    {
        MC_ReplyToCommand(client, "[{creators}Creators.TF{default}] %t", "VoteDelayedReply");
        return;
    }

    if (g_iVotesNeeded - g_iVotes == 1 && GetConVarInt(cvar_VoteMode) == 1 && IsVoteInProgress())
    {
        MC_ReplyToCommand(client, "[{creators}Creators.TF{default}] %t", "Vote in Progress");
        return;
    }

    if (GetConVarInt(cvar_MinPlayers) > g_iVoters)
    {
        MC_ReplyToCommand(client, "[{creators}Creators.TF{default}] %t", "NotEnoughPeopleVote");
        return;
    }

    if (g_aPlayers[client][bHasVoted] == true)
    {
        MC_ReplyToCommand(client, "[{creators}Creators.TF{default}] %t", "AlreadyVoted");
        return;
    }

    if (g_bScrambleNextRound)
    {
        MC_ReplyToCommand(client, "[{creators}Creators.TF{default}] %t", "ScrambleReply");
        return;
    }

    if (g_RoundState == normal && g_bRoundIsTimed && GetConVarBool(cvar_RoundTime) && g_bIsTimer && g_iVotesNeeded - g_iVotes == 1)
    {
        new iRoundLimit = GetConVarInt(cvar_RoundTime);
        if (RoundFloat((g_fRoundEndTime - GetGameTime())) - iRoundLimit <= 0)
        {
            if (GetConVarBool(cvar_RoundTimeMode))
            {
                Override = true;
            }
            else
            {
                MC_ReplyToCommand(client, "[{creators}Creators.TF{default}] %t", "VoteRoundTimeReply", iRoundLimit);
                return;
            }
        }
    }

    g_iVotes++;
    g_aPlayers[client][bHasVoted] = true;

    new String:clientName[MAX_NAME_LENGTH + 1];

    GetClientName(client, clientName, 32);
    MC_PrintToChatAll("[{creators}Creators.TF{default}] %t", "VoteTallied", clientName, g_iVotes, g_iVotesNeeded);

    if (g_iVotes >= g_iVotesNeeded && !g_bScrambleNextRound)
    {
        if (GetConVarInt(cvar_VoteMode) == 1)
        {
            StartScrambleVote(g_iDefMode);
        }
        else if (GetConVarInt(cvar_VoteMode) == 0)
        {
            g_bScrambleNextRound = true;
            if (!g_bSilent)
                MC_PrintToChatAll("[{creators}Creators.TF{default}] %t", "ScrambleRound");
        }
        else if (!Override && GetConVarInt(cvar_VoteMode) == 2)
        {
            StartScrambleDelay(5.0, true);
        }

        DelayPublicVoteTriggering();
    }
}

public Action:cmd_Vote(client, args)
{
    if (IsVoteInProgress())
    {
        MC_ReplyToCommand(client, "[{creators}Creators.TF{default}] %t", "Vote in Progress");
        return Plugin_Handled;
    }

    if (args < 1)
    {
        MC_ReplyToCommand(client, "[{creators}Creators.TF{default}] Usage: sm_scramblevote <now/end>");
        return Plugin_Handled;
    }

    decl String:arg[16];
    GetCmdArg(1, arg, sizeof(arg));

    new ScrambleTime:mode;
    if (StrEqual(arg, "now", false))
    {
        mode = Scramble_Now;
    }
    else if (StrEqual(arg, "end", false))
    {
        mode = Scramble_Round;
    }
    else
    {
        MC_ReplyToCommand(client, "[{creators}Creators.TF{default}] %t", "InvalidArgs");
        return Plugin_Handled;
    }

    PerformVote(client, mode);
    return Plugin_Handled;
}

PerformVote(client, ScrambleTime:mode)
{
    if (g_bArenaMode)
    {
        MC_ReplyToCommand(client, "[{creators}Creators.TF{default}] %t", "ArenaReply");
        return;
    }

    if (!g_bHooked)
    {
        MC_ReplyToCommand(client, "[{creators}Creators.TF{default}] %t", "EnableReply");
        return;
    }

    if (GetConVarInt(cvar_MinPlayers) > g_iVoters)
    {
        MC_ReplyToCommand(client, "[{creators}Creators.TF{default}] %t", "NotEnoughPeopleVote");
        return;
    }

    if (g_bScrambleNextRound)
    {
        MC_ReplyToCommand(client, "[{creators}Creators.TF{default}] %t", "ScrambleReply");
        return;
    }

    if (IsVoteInProgress())
    {
        MC_ReplyToCommand(client, "[{creators}Creators.TF{default}] %t", "Vote in Progress");
        return;
    }

    if (!g_bVoteAllowed)
    {
        MC_ReplyToCommand(client, "[{creators}Creators.TF{default}] %t", "VoteDelayedReply");
        return;
    }

    if (g_bNoSequentialScramble && g_bScrambledThisRound)
    {
        MC_ReplyToCommand(client, "[{creators}Creators.TF{default}] %t", "ScrambledAlready");
        return;
    }

    LogAction(client, -1, "\"%L\" has started a scramble vote", client);
    StartScrambleVote(mode, 20);
}

StartScrambleVote(ScrambleTime:mode, time=20)
{
    if (IsVoteInProgress())
    {
        MC_PrintToChatAll("[{creators}Creators.TF{default}] %t", "VoteWillStart");
        CreateTimer(1.0, Timer_ScrambleVoteStarter, mode, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
        return;
    }

    DelayPublicVoteTriggering();
    g_hScrambleVoteMenu = CreateMenu(Handler_VoteCallback, MenuAction:MENU_ACTIONS_ALL);

    new String:sTmpTitle[64];
    if (mode == Scramble_Now)
    {
        g_bScrambleAfterVote = true;
        Format(sTmpTitle, 64, "Scramble Teams Now?");
    }
    else
    {
        g_bScrambleAfterVote = false;
        Format(sTmpTitle, 64, "Scramble Teams Next Round?");
    }

    SetMenuTitle(g_hScrambleVoteMenu, sTmpTitle);
    AddMenuItem(g_hScrambleVoteMenu, "1", "Yes");
    AddMenuItem(g_hScrambleVoteMenu, "2", "No");
    SetMenuExitButton(g_hScrambleVoteMenu, false);
    VoteMenuToAll(g_hScrambleVoteMenu, time);
}

public Action:Timer_ScrambleVoteStarter(Handle:timer, any:mode)
{
    if (IsVoteInProgress())
    {
        return Plugin_Continue;
    }

    StartScrambleVote(mode, 15);

    return Plugin_Stop;
}

public Handler_VoteCallback(Handle:menu, MenuAction:action, param1, param2)
{
    DelayPublicVoteTriggering();

    if (action == MenuAction_End)
    {
        CloseHandle(g_hScrambleVoteMenu);
        g_hScrambleVoteMenu = INVALID_HANDLE;
    }

    if (action == MenuAction_VoteEnd)
    {
        new i_winningVotes, i_totalVotes;
        GetMenuVoteInfo(param2, i_winningVotes, i_totalVotes);

        if (param1 == 1)
        {
            i_winningVotes = i_totalVotes - i_winningVotes;
        }

        new Float:comp = float(i_winningVotes) / float(i_totalVotes);
        new Float:comp2 = GetConVarFloat(cvar_Needed);

        if (comp >= comp2)
        {
            MC_PrintToChatAll("[{creators}Creators.TF{default}] %t", "VoteWin", RoundToNearest(comp*100), i_totalVotes);
            LogAction(-1 , 0, "%T", "VoteWin", LANG_SERVER, RoundToNearest(comp*100), i_totalVotes);

            if (g_bScrambleAfterVote)
            {
                StartScrambleDelay(5.0, true);
            }
            else
            {
                if ((g_bFullRoundOnly && g_bWasFullRound) || !g_bFullRoundOnly)
                {
                    g_bScrambleNextRound = true;
                    MC_PrintToChatAll("[{creators}Creators.TF{default}] %t", "ScrambleStartVote");
                }
            }
        }
        else
        {
            new against = 100 - RoundToNearest(comp*100);
            MC_PrintToChatAll("[{creators}Creators.TF{default}] %t", "VoteFailed", against, i_totalVotes);
            LogAction(-1 , 0, "%T", "VoteFailed", LANG_SERVER, against, i_totalVotes);
        }
    }
}

DelayPublicVoteTriggering(bool:success = false)  // success means a scramble happened... longer delay
{
    if (GetConVarBool(cvar_VoteEnable))
    {
        for (new i = 0; i <= MaxClients; i++)
        {
            g_aPlayers[i][bHasVoted] = false;
        }

        g_iVotes = 0;
        g_bVoteAllowed = false;

        if (g_hVoteDelayTimer != INVALID_HANDLE)
        {
            KillTimer(g_hVoteDelayTimer);
            g_hVoteDelayTimer = INVALID_HANDLE;
        }

        new Float:fDelay;
        if (success)
        {
            fDelay = GetConVarFloat(cvar_VoteDelaySuccess);
        }
        else
        {
            fDelay = GetConVarFloat(cvar_Delay);
        }

        g_hVoteDelayTimer = CreateTimer(fDelay, TimerEnable, TIMER_FLAG_NO_MAPCHANGE);
    }
}

public Action:cmd_Scramble(client, args)
{
    SetupRoundScramble(client);
    return Plugin_Handled;
}

public Action:cmd_Cancel(client, args)
{
    PerformCancel(client);
    return Plugin_Handled;
}

PerformCancel(client)
{
    if (g_bScrambleNextRound || g_hScrambleDelay != INVALID_HANDLE)
    {
        g_bScrambleNextRound = false;

        if (g_hScrambleDelay != INVALID_HANDLE)
        {
            KillTimer(g_hScrambleDelay);
            g_hScrambleDelay = INVALID_HANDLE;
        }

        ShowActivity(client, "%t", "CancelScramble");
        LogAction(client, -1, "\"%L\" canceled the pending scramble", client);
    }
    else if (g_RoundState == bonusRound && g_bAutoScramble)
    {
        if (g_bScrambleOverride)
        {
            g_bScrambleOverride = false;
            ShowActivity(client, "%t", "OverrideUnCheck");
            LogAction(client, -1, "\"%L\" un-blocked the autoscramble check for the next round.", client);
        }
        else
        {
        g_bScrambleOverride = true;
        ShowActivity(client, "%t", "OverrideCheck");
        LogAction(client, -1, "\"%L\" blocked the autoscramble check for the next round.", client);
        }
    }
    else
    {
        MC_ReplyToCommand(client, "[{creators}Creators.TF{default}] %t", "NoScrambleReply");
        return;
    }
}

/**
    tirggered after an admin selects round scramble via menu or command
*/
SetupRoundScramble(client)
{
    if (!g_bHooked)
    {
        MC_ReplyToCommand(client, "[{creators}Creators.TF{default}] %t", "EnableReply");
        return;
    }

    if (g_bNoSequentialScramble && g_bScrambledThisRound)
    {
        MC_ReplyToCommand(client, "[{creators}Creators.TF{default}] %t", "ScrambledAlready");
        return;
    }

    if (g_bScrambleNextRound)
    {
        MC_ReplyToCommand(client, "[{creators}Creators.TF{default}] %t", "ScrambleReply");
        return;
    }

    g_bScrambleNextRound = true;
    ShowActivity(client, "%t", "ScrambleRound");
    LogAction(client, -1, "\"%L\" toggled a scramble for next round", client);
}

SwapPreferences()
{
    for (new i = 1; i <= MaxClients; i++)
    {
        if (g_aPlayers[i][iTeamPreference] == TEAM_RED)
        {
            g_aPlayers[i][iTeamPreference] = TEAM_BLUE;
        }
        else if (g_aPlayers[i][iTeamPreference] == TEAM_BLUE)
        {
            g_aPlayers[i][iTeamPreference] = TEAM_RED;
        }
    }
}

public Event_RoundStart(Handle:event, const String:name[], bool:dontBroadcast)
{

    g_bTeamsLocked = false;
    g_bNoSpec = false;
    /**
    check to see if the previos round warrented a trigger
    moved to the start event to make checking for map ending uneeded
    */
    g_bScrambleNextRound = ScrambleCheck();
    /**
    execute the trigger
    */

    if (g_bScrambleNextRound)
    {
        new rounds = GetConVarInt(cvar_AutoScrambleRoundCount);

        if (rounds)
        {
            g_iRoundTrigger += rounds;
        }

        StartScrambleDelay(0.3);
    }
    else if (GetConVarBool(cvar_ForceBalance) && g_hForceBalanceTimer == INVALID_HANDLE)
    {
        g_hForceBalanceTimer = CreateTimer(0.2, Timer_ForceBalance);
    }

    /**
    dont reset the team frag counting if full round only is specified, and it was not a full round
    */
    if ((g_bFullRoundOnly && g_bWasFullRound) || !g_bFullRoundOnly)
    {
        g_aTeams[iRedFrags] = 0;
        g_aTeams[iBluFrags] = 0;
    }

    if (g_RoundState == newGame)
    {
        g_RoundState = preGame;
        DelayPublicVoteTriggering();
        if (GetConVarBool(cvar_WaitScramble))
        {
            g_bPreGameScramble = true;
            g_bScrambleNextRound = true;
            if (!g_bSilent)
                MC_PrintToChatAll("[{creators}Creators.TF{default}] %t", "ScrambleRound");
        }
    }
    else if (g_RoundState == preGame)
    {
        g_RoundState = normal;
    }

    /**
    check the timer entity, and see if its in setup mode
    as well as get the round duration for the countdown
    */
    if (g_RoundState != preGame)
    {
        CreateTimer(0.5, Timer_GetTime, TIMER_FLAG_NO_MAPCHANGE);
    }

    g_iRoundStartTime = GetTime();
    //g_iSpawnTime = g_iRoundStartTime;

    /**
    reset
    */
    g_bScrambleOverride = false;
    g_bWasFullRound = false;
    g_bRedCapped = false;
    g_bBluCapped = false;
    g_bScrambledThisRound = false;
    //g_fEscortProgress = 0.0;
}

public Action:hook_Setup(Handle:event, const String:name[], bool:dontBroadcast)
{
    g_RoundState = normal;
    CreateTimer(0.5, Timer_GetTime, TIMER_FLAG_NO_MAPCHANGE);

    if (g_aTeams[bImbalanced])
    {
        StartForceTimer();
    }

    return Plugin_Continue;
}

public Event_RoundWin(Handle:event, const String:name[], bool:dontBroadcast)
{
    //g_iRoundTimer = 0;

    if (GetConVarBool(cvar_ScrLockTeams))
    {
        g_bNoSpec = true;
    }

    g_RoundState = bonusRound;
    g_bWasFullRound = false;

    if (GetEventBool(event, "full_round"))
    {
        g_bWasFullRound = true;
        g_iCompleteRounds++;
    }
    else if (!GetConVarBool(cvar_FullRoundOnly))
    {
        g_iCompleteRounds++;
    }

    g_iLastRoundWinningTeam = GetEventInt(event, "team");

    if (g_hForceBalanceTimer != INVALID_HANDLE)
    {
        KillTimer(g_hForceBalanceTimer);
        g_hForceBalanceTimer = INVALID_HANDLE;
    }
    if (g_hRoundTimeTick != INVALID_HANDLE)
    {
        KillTimer(g_hRoundTimeTick);
        g_hRoundTimeTick = INVALID_HANDLE;
    }

    if (g_hBalanceFlagTimer != INVALID_HANDLE)
    {
        KillTimer(g_hBalanceFlagTimer);
        g_hBalanceFlagTimer = INVALID_HANDLE;
    }
}

public Action:Event_PlayerDeath_Pre(Handle:event, const String:name[], bool:dontBroadcast)
{
    if (g_bBlockDeath)
    {
        return Plugin_Handled;
    }

    new k_client = GetClientOfUserId(GetEventInt(event, "attacker"));
    new v_client = GetClientOfUserId(GetEventInt(event, "userid"));

    if (k_client && IsClientInGame(k_client) && k_client != v_client && g_bBlockDeath)
    {
        g_bBlockDeath = false;
    }

    if (g_RoundState != normal || GetEventInt(event, "death_flags") & 32)
    {
        return Plugin_Continue;
    }

    if (g_bAutoBalance && IsOkToBalance() && g_aTeams[bImbalanced] && GetClientTeam(v_client) == GetLargerTeam())
    {
        #if defined DEBUG
        LogToFile("addons/sourcemod/logs/gscramble.debug.txt", "Checking balance for player: %N", v_client);
        #endif
        CreateTimer(0.1, timer_StartBalanceCheck, v_client, TIMER_FLAG_NO_MAPCHANGE);
    }

    if (!k_client || k_client == v_client || k_client > MaxClients)
    {
        return Plugin_Continue;
    }

    g_aPlayers[k_client][iFrags]++;
    g_aPlayers[v_client][iDeaths]++;
    GetClientTeam(k_client) == TEAM_RED ? (g_aTeams[iRedFrags]++) : (g_aTeams[iBluFrags]++);
    CheckBalance(true);

    return Plugin_Continue;
}

stock GetAbsValue(value1, value2)
{
    return RoundFloat(FloatAbs((float(value1) - float(value2))));
}

bool:IsNotTopPlayer(client, team)  // this arranges teams based on their score, and checks to see if a client is among the top X players
{
    new iSize, iHighestScore;
    decl iScores[MAXPLAYERS+1][2];

    for (new i = 1; i <= MaxClients; i++)
    {
        if (IsClientInGame(i) && GetClientTeam(i) == team)
        {
            new entity = GetPlayerResourceEntity();
            new Totalscore = GetEntProp(entity, Prop_Send, "m_iTotalScore", _, i);

            iScores[iSize][1] = 1 + Totalscore;
            iScores[iSize][0] = i;

            if (iScores[iSize][1] > iHighestScore)
            {
                iHighestScore = iScores[iSize][1];
            }

            iSize++;
        }
    }

    if (iHighestScore <= 10)
    {
        return true;
    }

    if (iSize < GetConVarInt(cvar_TopProtect) + 4)
    {
        return true;

    }
    SortCustom2D(iScores, iSize, SortScoreDesc);

    for (new i = 0; i < GetConVarInt(cvar_TopProtect); i++)
    {
        if (iScores[i][0] == client)
        {
            return false;
        }
    }

    return true;
}

bool:IsClientBuddy(client)
{
    for (new i = 1; i <= MaxClients; i++)
    {
        if (IsClientInGame(i) && g_aPlayers[i][iBuddy] == client)
        {
            if (GetClientTeam(client) == GetClientTeam(i))
            {
                LogAction(-1, 0, "Buddy detected for client %L", client);
                return true;
            }
        }
    }

    return false;
}

bool IsValidTarget(client)
{
    if (GetConVarBool(cvar_ScrambleDuelImmunity))
    {
        if (TF2_IsPlayerInDuel(client))
        {
            return false;
        }
    }

    new e_Protection:iImmunity;
    char flags[32];

    iImmunity = e_Protection:GetConVarInt(cvar_ScrambleImmuneMode);
    if (iImmunity == none)
    {
        return true;
    }
    GetConVarString(cvar_ScrambleAdmFlags, flags, sizeof(flags));
    /*
        override immunities when things like alive or buildings don't matter
        if the round started within 10 seconds, override immunity too
    */
    if (g_RoundState == setup || g_RoundState == bonusRound)
        return true;
    if (GetTime() - g_iRoundStartTime <= 10)
        return true;

    if (IsClientInGame(client) && IsValidTeam(client))
    {
        if (iImmunity == none) // if no immunity mode set, don't check for it :p
        {
            return true;
        }
        new bool:bCheckAdmin = false,
            bool:bCheckUberBuild = false;
        switch (iImmunity)
        {
            case admin:
            {
                bCheckAdmin = true;
            }
            case uberAndBuildings:
            {
                bCheckUberBuild = true;
                /*
                //if (TF2_HasBuilding(client) || TF2_IsClientUberCharged(client) || TF2_IsClientUbered(client))
                // return false;*/
            }
            case both:
            {
                bCheckAdmin = true;
                bCheckUberBuild = true;
                /*
                //if (IsAdmin(client, flags) || TF2_HasBuilding(client) || TF2_IsClientUberCharged(client) || TF2_IsClientUbered(client))
                //  return false;*/
            }
        }
        if (bCheckUberBuild)
        {
            if (TF2_HasBuilding(client) || TF2_IsClientUberCharged(client) || TF2_IsClientUbered(client))
            {
                return false;
            }
        }

        if (bCheckAdmin)
        {
            new bool:bSkip = false;
            new Float:fPercent = GetConVarFloat(cvar_ScrambleCheckImmune);
            // check to see if we set to stop checking admin flags during scramble
            if (fPercent > 0.0)
            {
                new iImmune,
                    iTotal,
                    iTargets;
                for (new i = 1; i <= MaxClients; i++)
                {
                    if (IsClientInGame(i) && IsValidTeam(i))
                    {
                        if (IsAdmin(i, flags))
                            iImmune++;
                        else
                            iTargets++;
                    }
                }
                if (iImmune)
                {
                    iTotal = iImmune + iTargets;
                    if ((float(iImmune)/ float(iTotal)) >= fPercent)
                        bSkip = true;
                }
            }
            if (!bSkip && IsAdmin(client, flags))
                return false;
        }
        return true;
    }

    if (IsValidSpectator(client))
    {
        return true;
    }
    return false;
}

stock bool:IsValidSpectator(client)
{
    if (!IsFakeClient(client))
    {
        if (g_bSelectSpectators)
        {
            if (GetClientTeam(client) == 1)
            {
                new iChangeTime = g_aPlayers[client][iSpecChangeTime];

                if (iChangeTime && (GetTime() - iChangeTime) < GetConVarInt(cvar_SelectSpectators))
                {
                    return true;
                }

                new Float:fTime = GetClientTime(client);

                if (fTime <= 60.0)
                {
                    return true;
                }
            }
        }
    }

    return false;
}

bool IsAdmin(client, const char[] flags)
{
    new bits = GetUserFlagBits(client);

    if (bits & ADMFLAG_ROOT)
    {
        return true;
    }

    new iFlags = ReadFlagString(flags);

    if (bits & iFlags)
    {
        return true;
    }

    return false;
}

stock BlockAllTeamChange()
{
    if (GetConVarBool(cvar_LockTeamsFullRound))
    {
        g_bTeamsLocked = true;
    }

    for (new i=1; i <= MaxClients; i++)
    {
        if (!IsClientInGame(i) || !IsValidTeam(i) || IsFakeClient(i))
        {
            continue;
        }

        SetupTeamSwapBlock(i);
    }
}

SetupTeamSwapBlock(client)  /* blocks proper clients from spectating*/
{
    if (!g_bForceTeam)
    {
        return;
    }

    if (GetConVarBool(cvar_TeamSwapBlockImmunity))
    {
        if (IsClientInGame(client))
        {
            new String:flags[32];
            GetConVarString(cvar_TeamswapAdmFlags, flags, sizeof(flags));
            if (IsAdmin(client, flags))
                return;
        }
    }

    g_aPlayers[client][iBlockTime] = GetTime() + g_iForceTime;
}

public Action:TimerStopSound(Handle:timer)   // cuts off the sound after 1.7 secs so it only plays 'Lets even this out'
{
    for (new i=1; i<=MaxClients;i++)
    {
        if (IsClientInGame(i) && !IsFakeClient(i))
        {
            StopSound(i, SNDCHAN_AUTO, EVEN_SOUND);
        }
    }

    return Plugin_Handled;
}

public Action:Timer_GetTime(Handle:timer)
{
    CheckBalance(true);
    GetRoundTimerInformation();
    /*g_iTimerEnt = FindEntityByClassname(-1, "team_round_timer");

    if (g_iTimerEnt != -1)
    {
        g_bIsTimer = true;
        new iState = GetEntProp(g_iTimerEnt, Prop_Send, "m_nState");

        if (!iState)
        {
            g_RoundState = setup;
            return Plugin_Handled;
        }

        //g_iRoundTimer = GetEntProp(g_iTimerEnt, Prop_Send, "m_nTimerLength") -2

        if (g_RoundState == bonusRound || g_RoundState == setup)
        {
            g_RoundState = normal;
        }
    }
    else
    {
        g_RoundState = normal;
        g_bIsTimer = false;
    }*/
    if (g_hRoundTimeTick != INVALID_HANDLE)
    {
        g_hRoundTimeTick = CreateTimer(15.0, Timer_Countdown, _, TIMER_REPEAT);
    }
    return Plugin_Handled;
}

public TimerUpdateAdd(Handle:event, const String:name[], bool:dontBroadcast)
{
    if (GetConVarInt(cvar_BalanceTimeLimit) > 0)
    {
        GetRoundTimerInformation();
        CheckBalance(true);
    }
}


public Action:Timer_Countdown(Handle:timer)
{
    #if defined DEBUG
    LogToFile("addons/sourcemod/logs/gscramble.debug.txt", "countdown timer ticking");
    #endif
    GetRoundTimerInformation();
    return Plugin_Continue;
}

public OnLibraryRemoved(const String:name[])
{
    if (StrEqual(name, "adminmenu"))
    {
        g_hAdminMenu = INVALID_HANDLE;
    }
    #if defined HLXCE_INCLUDED
    if (StrEqual(name, "hlxce-sm-api"))
    {
        g_bUseHlxCe = false;
    }
    #endif

    #if defined GAMEME_INCLUDED
    if (StrEqual(name, "gameme", false))
    {
        g_bUseGameMe = false;
    }
    #endif
}

public OnLibraryAdded(const String:name[])
{
    #if defined HLXCE_INCLUDED
    if (StrEqual(name, "hlxce-sm-api"))
    {
        if (GetFeatureStatus(FeatureType_Native, "HLXCE_GetPlayerData") == FeatureStatus_Available)
        {
            g_bUseHlxCe = true;
        }
    }
    #endif
    #if defined GAMEME_INCLUDED
    if (StrEqual(name, "gameme"))
    {
        if (GetFeatureStatus(FeatureType_Native, "QueryGameMEStats") == FeatureStatus_Available)
        {
            g_bUseGameMe = true;
        }
    }
    #endif
}

public SortScoreDesc(x[], y[], array[][], Handle:data)
{
    if (Float:x[1] > Float:y[1])
    {
        return -1;
    }
    else if (Float:x[1] < Float:y[1])
    {
        return 1;
    }

    return 0;
}

public SortScoreAsc(x[], y[], array[][], Handle:data)
{
    if (Float:x[1] > Float:y[1])
    {
        return 1;
    }
    else if (Float:x[1] < Float:y[1])
    {
        return -1;
    }

    return 0;
}

bool:CheckSpecChange(client)
{
    if (GetConVarBool(cvar_TeamSwapBlockImmunity))
    {
        new String:flags[32];

        GetConVarString(cvar_TeamswapAdmFlags, flags, sizeof(flags));

        if (IsAdmin(client, flags))
        {
            return false;
        }
    }
    new redSize = GetTeamClientCount(TEAM_RED), bluSize = GetTeamClientCount(TEAM_BLUE), difference;

    if (GetClientTeam(client) == TEAM_RED)
    {
        redSize -= 1;
    }
    else
    {
        bluSize -= 1;
    }

    difference = GetAbsValue(redSize, bluSize);

    if (difference >= GetConVarInt(cvar_BalanceLimit))
    {
        MC_PrintToChat(client, "[{creators}Creators.TF{default}] %t", "SpecChangeBlock");
        LogAction(client, -1, "Client \"%L\" is being blocked from swapping to spectate", client);
        return true;
    }

    return false;
}

public SortIntsAsc(x[], y[], array[][], Handle:data)        // this sorts everything in the info array ascending
{
    if (x[1] > y[1])
    {
        return 1;
    }
    else if (x[1] < y[1])
    {
        return -1;
    }

    return 0;
}

public SortIntsDesc(x[], y[], array[][], Handle:data)       // this sorts everything in the info array descending
{
    if (x[1] > y[1])
    {
        return -1;
    }
    else if (x[1] < y[1])
    {
        return 1;
    }

    return 0;
}
