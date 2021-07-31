#pragma semicolon 1
#pragma newdecls required

#include <cecon>
#include <sdktools>
#include <sdkhooks>
#include <tf2>
#include <tf2_stocks>

#define TF_BUILDING_DISPENSER 0
#define TF_BUILDING_TELEPORTER 1
#define TF_BUILDING_SENTRY 2
#define TF_BUILDING_SAPPER 3

#define TF_BOSS_HHH 1
#define TF_BOSS_EYEBALL 2
#define TF_BOSS_MERASMUS 3

public Plugin myinfo =
{
	name = "Creators.TF Economy - TF2 Events",
	author = "Creators.TF Team",
	description = "Creators.TF TF2 Events",
	version = "1.0",
	url = "https://creators.tf"
}

public void OnPluginStart()
{
	// Misc Events
	HookEvent("payload_pushed", payload_pushed);
	HookEvent("killed_capping_player", killed_capping_player);
	HookEvent("environmental_death", environmental_death);
	HookEvent("medic_death", medic_death);

	// Teamplay Events
	HookEvent("teamplay_point_captured", teamplay_point_captured);
	HookEvent("teamplay_flag_event", teamplay_flag_event);
	HookEvent("teamplay_win_panel", evTeamplayWinPanel);
	HookEvent("teamplay_round_win", evTeamplayRoundWin);
	HookEvent("teamplay_round_start", evTeamplayRoundStart);
	HookEvent("teamplay_round_active", evTeamplayRoundActive);
	HookEvent("teamplay_setup_finished", teamplay_setup_finished);


	// Object Events
	HookEvent("object_destroyed", object_destroyed);
	HookEvent("object_detonated", object_detonated);
	HookEvent("object_deflected", object_deflected);


	// Player Events
	HookEvent("player_score_changed", player_score_changed);
	HookEvent("player_hurt", player_hurt);
	HookEvent("player_spawn", player_spawn);
	HookEvent("player_healed", player_healed);
	HookEvent("player_chargedeployed", player_chargedeployed);
	HookEvent("player_death", player_death);

	// Halloween Events
	HookEvent("halloween_soul_collected", halloween_soul_collected);
	HookEvent("halloween_duck_collected", halloween_duck_collected);
	HookEvent("halloween_skeleton_killed", halloween_skeleton_killed);
	HookEvent("halloween_boss_killed", halloween_boss_killed);
	HookEvent("halloween_pumpkin_grab", halloween_pumpkin_grab);
	HookEvent("respawn_ghost", respawn_ghost);
	HookEvent("tagged_player_as_it", tagged_player_as_it);
	HookEvent("merasmus_stunned", merasmus_stunned);
	HookEvent("merasmus_prop_found", merasmus_prop_found);
	HookEvent("eyeball_boss_stunned", eyeball_boss_stunned);
	HookEvent("eyeball_boss_killer", eyeball_boss_killer);
	HookEvent("escaped_loot_island", escaped_loot_island);
	HookEvent("escape_hell", escape_hell);

	//Passtime Events
	HookEvent("pass_get", pass_get);
	HookEvent("pass_score", pass_score);
	HookEvent("pass_free", pass_free);
	HookEvent("pass_pass_caught", pass_pass_caught);
	HookEvent("pass_ball_stolen", pass_ball_stolen);
	HookEvent("pass_ball_blocked", pass_ball_blocked);

	//Robot Destruction
	HookEvent("rd_robot_killed", rd_robot_killed);
	HookEvent("rd_player_score_points", rd_player_score_points);

	// Player Destruction
	HookEvent("special_score", pd_special_score);

	//Special Delivery
	HookEvent("team_leader_killed", team_leader_killed);
}

public bool IsStaffMember(int client)
{
	return false;
}

public Action player_death(Handle hEvent, const char[] szName, bool bDontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(hEvent, "userid"));
	int attacker = GetClientOfUserId(GetEventInt(hEvent, "attacker"));
	int assister = GetClientOfUserId(GetEventInt(hEvent, "assister"));

	int death_flags = GetEventInt(hEvent, "death_flags");
	int customkill = GetEventInt(hEvent, "customkill");
	int kill_streak_victim = GetEventInt(hEvent, "kill_streak_victim");
	int crit_type = GetEventInt(hEvent, "crit_type");

	char weapon[64];
	GetEventString(hEvent, "weapon", weapon, sizeof(weapon));

	if(IsClientReady(client))
	{
		CEcon_SendEventToClientFromGameEvent(client, "TF_DEATH", 1, hEvent);
		if(IsClientValid(attacker))
		{
			if(attacker != client)
			{
				CEcon_SendEventToClientFromGameEvent(attacker, "TF_KILL", 1, hEvent);
				CEcon_SendEventToClientFromGameEvent(attacker, "TF_KILL_OR_ASSIST", 1, hEvent);

				if(death_flags & TF_DEATHFLAG_KILLERDOMINATION)
				{
					CEcon_SendEventToClientFromGameEvent(attacker, "TF_KILL_DOMINATE", 1, hEvent);
				}

				if(death_flags & TF_DEATHFLAG_KILLERREVENGE)
				{
					CEcon_SendEventToClientFromGameEvent(attacker, "TF_KILL_REVENGE", 1, hEvent);
				}

				switch(TF2_GetPlayerClass(client))
				{
					case TFClass_Scout:CEcon_SendEventToClientFromGameEvent(attacker, "TF_KILL_CLASS_SCOUT", 1, hEvent);
					case TFClass_Soldier:CEcon_SendEventToClientFromGameEvent(attacker, "TF_KILL_CLASS_SOLDIER", 1, hEvent);
					case TFClass_Pyro:CEcon_SendEventToClientFromGameEvent(attacker, "TF_KILL_CLASS_PYRO", 1, hEvent);
					case TFClass_DemoMan:CEcon_SendEventToClientFromGameEvent(attacker, "TF_KILL_CLASS_DEMOMAN", 1, hEvent);
					case TFClass_Heavy:CEcon_SendEventToClientFromGameEvent(attacker, "TF_KILL_CLASS_HEAVY", 1, hEvent);
					case TFClass_Engineer:CEcon_SendEventToClientFromGameEvent(attacker, "TF_KILL_CLASS_ENGINEER", 1, hEvent);
					case TFClass_Medic:CEcon_SendEventToClientFromGameEvent(attacker, "TF_KILL_CLASS_MEDIC", 1, hEvent);
					case TFClass_Sniper:CEcon_SendEventToClientFromGameEvent(attacker, "TF_KILL_CLASS_SNIPER", 1, hEvent);
					case TFClass_Spy:CEcon_SendEventToClientFromGameEvent(attacker, "TF_KILL_CLASS_SPY", 1, hEvent);
				}

				switch(customkill)
				{
					case TF_CUSTOM_BACKSTAB: CEcon_SendEventToClientFromGameEvent(attacker, "TF_KILL_BACKSTAB", 1, hEvent);
					case TF_CUSTOM_HEADSHOT: CEcon_SendEventToClientFromGameEvent(attacker, "TF_KILL_HEADSHOT", 1, hEvent);
					case TF_CUSTOM_PUMPKIN_BOMB: CEcon_SendEventToClientFromGameEvent(attacker, "TF_KILL_PUMPKIN_BOMB", 1, hEvent);

					case TF_CUSTOM_SPELL_BATS: CEcon_SendEventToClientFromGameEvent(attacker, "TF_KILL_MAGIC", 1, hEvent);
					case TF_CUSTOM_SPELL_BLASTJUMP: CEcon_SendEventToClientFromGameEvent(attacker, "TF_KILL_MAGIC", 1, hEvent);
					case TF_CUSTOM_SPELL_FIREBALL: CEcon_SendEventToClientFromGameEvent(attacker, "TF_KILL_MAGIC", 1, hEvent);
					case TF_CUSTOM_SPELL_LIGHTNING: CEcon_SendEventToClientFromGameEvent(attacker, "TF_KILL_MAGIC", 1, hEvent);
					case TF_CUSTOM_SPELL_METEOR: CEcon_SendEventToClientFromGameEvent(attacker, "TF_KILL_MAGIC", 1, hEvent);
					case TF_CUSTOM_SPELL_MIRV: CEcon_SendEventToClientFromGameEvent(attacker, "TF_KILL_MAGIC", 1, hEvent);
					case TF_CUSTOM_SPELL_MONOCULUS: CEcon_SendEventToClientFromGameEvent(attacker, "TF_KILL_MAGIC", 1, hEvent);
					case TF_CUSTOM_SPELL_SKELETON: CEcon_SendEventToClientFromGameEvent(attacker, "TF_KILL_MAGIC", 1, hEvent);
					case TF_CUSTOM_SPELL_TELEPORT: CEcon_SendEventToClientFromGameEvent(attacker, "TF_KILL_MAGIC", 1, hEvent);
					case TF_CUSTOM_SPELL_TINY: CEcon_SendEventToClientFromGameEvent(attacker, "TF_KILL_MAGIC", 1, hEvent);
				}

				// Airborne
				if(!(GetEntityFlags(attacker) & FL_ONGROUND))
				{
					CEcon_SendEventToClientFromGameEvent(attacker, "TF_KILL_WHILE_AIRBORNE", 1, hEvent);
				}

				if(!(GetEntityFlags(client) & FL_ONGROUND))
				{
					CEcon_SendEventToClientFromGameEvent(attacker, "TF_KILL_AIRBORNE_ENEMY", 1, hEvent);
				}

				// Reflect
				if(StrContains(weapon, "deflect") != -1)
				{
					CEcon_SendEventToClientFromGameEvent(attacker, "TF_KILL_WITH_REFLECT", 1, hEvent);
				}

				// Objects
				if(StrContains(weapon, "obj_") != -1)
				{
					CEcon_SendEventToClientFromGameEvent(attacker, "TF_KILL_WITH_OBJECT", 1, hEvent);
				}

				// Uber
				if (TF2_IsUbercharged(attacker))
				{
					CEcon_SendEventToClientFromGameEvent(attacker, "TF_KILL_WHILE_UBERCHARGED", 1, hEvent);
				}

				// Cloaked spy
				if(TF2_IsPlayerInCondition(client, TFCond_Stealthed))
				{
					CEcon_SendEventToClientFromGameEvent(attacker, "TF_KILL_CLOAKED_SPY", 1, hEvent);
				}

				if(kill_streak_victim > 5)
				{
					CEcon_SendEventToClientFromGameEvent(attacker, "TF_KILL_STREAK_ENDED", 1, hEvent);
				}

				// Crits
				switch(crit_type)
				{
					case 0: CEcon_SendEventToClientFromGameEvent(attacker, "TF_KILL_NON_CRITICAL", 1, hEvent);
					case 1: CEcon_SendEventToClientFromGameEvent(attacker, "TF_KILL_MINI_CRITICAL", 1, hEvent);
					case 2: CEcon_SendEventToClientFromGameEvent(attacker, "TF_KILL_CRITICAL", 1, hEvent);
				}

				if(death_flags & TF_DEATHFLAG_GIBBED)
				{
					CEcon_SendEventToClientFromGameEvent(attacker, "TF_KILL_GIB", 1, hEvent);
				}

				if(TF2_IsPlayerInCondition(attacker, TFCond_Taunting))
				{
					CEcon_SendEventToClientFromGameEvent(attacker, "TF_KILL_WHILE_TAUNTING", 1, hEvent);
				}

				if(TF2_IsPlayerInCondition(client, TFCond_Taunting))
				{
					CEcon_SendEventToClientFromGameEvent(attacker, "TF_KILL_TAUNTING", 1, hEvent);
				}

				// Halloween
				if(TF2_IsPlayerInCondition(attacker, TFCond_HalloweenInHell))
				{
					CEcon_SendEventToClientFromGameEvent(attacker, "TF_KILL_IN_HELL", 1, hEvent);
				}

				if(TF2_IsPlayerInCondition(attacker, TFCond_EyeaductUnderworld))
				{
					CEcon_SendEventToClientFromGameEvent(attacker, "TF_KILL_IN_PURGATORY", 1, hEvent);
				}

				if(TF2_IsPlayerInCondition(attacker, TFCond_HalloweenKart))
				{
					CEcon_SendEventToClientFromGameEvent(attacker, "TF_BUMPER_CARS_KILL", 1, hEvent);
				}

				if(TF2_IsPlayerInCondition(client, TFCond_Dazed))
				{
					CEcon_SendEventToClientFromGameEvent(attacker, "TF_KILL_STUNNED", 1, hEvent);
				}
			}
		}

		if(IsClientValid(assister))
		{
			if(assister != client)
			{
				CEcon_SendEventToClientFromGameEvent(assister, "TF_ASSIST", 1, hEvent);
				CEcon_SendEventToClientFromGameEvent(assister, "TF_KILL_OR_ASSIST", 1, hEvent);

				if(death_flags & TF_DEATHFLAG_ASSISTERDOMINATION)
				{
					CEcon_SendEventToClientFromGameEvent(assister, "TF_KILL_DOMINATE", 1, hEvent);
				}

				if(death_flags & TF_DEATHFLAG_ASSISTERREVENGE)
				{
					CEcon_SendEventToClientFromGameEvent(assister, "TF_KILL_REVENGE", 1, hEvent);
				}

				// Uber
				if (TF2_IsUbercharged(assister))
				{
					CEcon_SendEventToClientFromGameEvent(assister, "TF_ASSIST_WHILE_UBERCHARGED", 1, hEvent);
				}
			}
		}
	}

	return Plugin_Continue;
}

public Action team_leader_killed(Handle hEvent, const char[] szName, bool bDontBroadcast)
{
	int killer = GetEventInt(hEvent, "killer");
	int victim = GetEventInt(hEvent, "victim");

	if(killer != victim)
	{
		CEcon_SendEventToClientFromGameEvent(killer, "TF_KILL_LEADER", 1, hEvent);
	}

	return Plugin_Continue;
}

public Action escaped_loot_island(Handle hEvent, const char[] szName, bool bDontBroadcast)
{
	int player = GetClientOfUserId(GetEventInt(hEvent, "player"));

	CEcon_SendEventToClientFromGameEvent(player, "TF_ESCAPE_LOOT_ISLAND", 1, hEvent);

	return Plugin_Continue;
}

public Action pd_special_score(Handle hEvent, const char[] szName, bool bDontBroadcast)
{
	int player = GetEventInt(hEvent, "player");

	if (IsClientValid(player))
	{
		CEcon_SendEventToClientFromGameEvent(player, "TF_PD_SCORE", 1, hEvent);
	}

	return Plugin_Continue;
}

public Action pass_get(Handle hEvent, const char[] szName, bool bDontBroadcast)
{
	int player = GetEventInt(hEvent, "owner");

	if (IsClientValid(player))
	{
		CEcon_SendEventToClientFromGameEvent(player, "TF_BALL_GET", 1, hEvent);
	}

	return Plugin_Continue;
}

public Action pass_score(Handle hEvent, const char[] szName, bool bDontBroadcast)
{
	int scorer = GetEventInt(hEvent, "scorer");
	int assister = GetEventInt(hEvent, "assister");

	if (IsClientValid(scorer))
	{
		CEcon_SendEventToClientFromGameEvent(scorer, "TF_BALL_SCORE", 1, hEvent);
	}

	if (IsClientValid(assister))
	{
		CEcon_SendEventToClientFromGameEvent(assister, "TF_PASS_SCORE_ASSIST", 1, hEvent);
	}

	return Plugin_Continue;
}

public Action pass_free(Handle hEvent, const char[] szName, bool bDontBroadcast)
{
	int player = GetEventInt(hEvent, "owner");
	int attacker = GetEventInt(hEvent, "attacker");

	if (IsClientValid(player))
	{
		CEcon_SendEventToClientFromGameEvent(player, "TF_BALL_LOST", 1, hEvent);
	}
	if (IsClientValid(attacker))
	{
		CEcon_SendEventToClientFromGameEvent(attacker, "TF_BALL_STEAL", 1, hEvent);
	}

	return Plugin_Continue;
}

public Action pass_pass_caught(Handle hEvent, const char[] szName, bool bDontBroadcast)
{
	int passer = GetEventInt(hEvent, "passer");
	int catcher = GetEventInt(hEvent, "catcher");
	float distance = GetEventFloat(hEvent, "dist");
	float duration = GetEventFloat(hEvent, "duration");

	if (IsClientValid(passer))
	{
		CEcon_SendEventToClientFromGameEvent(passer, "TF_BALL_PASSED", 1, hEvent);
		CEcon_SendEventToClientFromGameEvent(passer, "TF_BALL_PASSED_DISTANCE", RoundFloat(distance), hEvent);
		CEcon_SendEventToClientFromGameEvent(passer, "TF_BALL_PASSED_DURATION", RoundFloat(duration), hEvent);
	}

	if (IsClientValid(catcher))
	{
		CEcon_SendEventToClientFromGameEvent(catcher, "TF_BALL_CAUGHT", 1, hEvent);
		CEcon_SendEventToClientFromGameEvent(catcher, "TF_BALL_CAUGHT_DISTANCE", RoundFloat(distance), hEvent);
		CEcon_SendEventToClientFromGameEvent(catcher, "TF_BALL_CAUGHT_DURATION", RoundFloat(duration), hEvent);
	}

	return Plugin_Continue;
}

public Action pass_ball_stolen(Handle hEvent, const char[] szName, bool bDontBroadcast)
{
	int victim = GetEventInt(hEvent, "victim");
	int attacker = GetEventInt(hEvent, "attacker");

	if (IsClientValid(victim))
	{
		CEcon_SendEventToClientFromGameEvent(victim, "TF_BALL_LOST_STOLEN", 1, hEvent);
	}

	if (IsClientValid(attacker))
	{
		CEcon_SendEventToClientFromGameEvent(attacker, "TF_BALL_STEAL_MELEE", 1, hEvent);
	}

	return Plugin_Continue;
}

public Action pass_ball_blocked(Handle hEvent, const char[] szName, bool bDontBroadcast)
{
	int player = GetEventInt(hEvent, "owner");
	int blocker = GetEventInt(hEvent, "blocker");

	if (IsClientValid(player))
	{
		CEcon_SendEventToClientFromGameEvent(player, "TF_BALL_INCOMPLETE_PASS", 1, hEvent);
	}

	if (IsClientValid(blocker))
	{
		CEcon_SendEventToClientFromGameEvent(blocker, "TF_BALL_BLOCKED_PASS", 1, hEvent);
	}

	return Plugin_Continue;
}

public Action rd_robot_killed(Handle hEvent, const char[] szName, bool bDontBroadcast)
{
	int attacker = GetClientOfUserId(GetEventInt(hEvent, "attacker"));

	if (IsClientValid(attacker)) CEcon_SendEventToClientFromGameEvent(attacker, "TF_RD_ROBOT_KILLED", 1, hEvent);

	return Plugin_Continue;
}

public Action rd_player_score_points(Handle hEvent, const char[] szName, bool bDontBroadcast)
{
	int player = GetClientOfUserId(GetEventInt(hEvent, "player"));

	if (IsClientValid(player)) CEcon_SendEventToClientFromGameEvent(player, "TF_RD_POINTS_SCORE", 1, hEvent);

	return Plugin_Continue;
}

public Action escape_hell(Handle hEvent, const char[] szName, bool bDontBroadcast)
{
	int player = GetClientOfUserId(GetEventInt(hEvent, "player"));

	CEcon_SendEventToClientFromGameEvent(player, "TF_ESCAPE_HELL", 1, hEvent);

	return Plugin_Continue;
}

public Action halloween_pumpkin_grab(Handle hEvent, const char[] szName, bool bDontBroadcast)
{
	int player = GetClientOfUserId(GetEventInt(hEvent, "userid"));

	CEcon_SendEventToClientFromGameEvent(player, "TF_COLLECT_CRIT_PUMPKIN", 1, hEvent);

	return Plugin_Continue;
}

public Action merasmus_stunned(Handle hEvent, const char[] szName, bool bDontBroadcast)
{
	int player = GetClientOfUserId(GetEventInt(hEvent, "player"));

	CEcon_SendEventToClientFromGameEvent(player, "TF_MERASMUS_STUN", 1, hEvent);

	return Plugin_Continue;
}

public Action halloween_boss_killed(Handle hEvent, const char[] szName, bool bDontBroadcast)
{
	int boss = GetEventInt(hEvent, "boss");
	int player = GetClientOfUserId(GetEventInt(hEvent, "killer"));

	switch(boss)
	{
		case TF_BOSS_HHH: CEcon_SendEventToClientFromGameEvent(player, "TF_HHH_KILL", 1, hEvent);
		case TF_BOSS_MERASMUS: CEcon_SendEventToClientFromGameEvent(player, "TF_MERASMUS_KILL", 1, hEvent);
	}
	return Plugin_Continue;
}

public Action halloween_skeleton_killed(Handle hEvent, const char[] szName, bool bDontBroadcast)
{
	int player = GetClientOfUserId(GetEventInt(hEvent, "player"));

	CEcon_SendEventToClientFromGameEvent(player, "TF_SKELETON_KILL", 1, hEvent);

	return Plugin_Continue;
}

public Action merasmus_prop_found(Handle hEvent, const char[] szName, bool bDontBroadcast)
{
	int player = GetClientOfUserId(GetEventInt(hEvent, "player"));

	CEcon_SendEventToClientFromGameEvent(player, "TF_MERASMUS_PROP_FOUND", 1, hEvent);

	return Plugin_Continue;
}

public Action eyeball_boss_stunned(Handle hEvent, const char[] szName, bool bDontBroadcast)
{
	int player = GetEventInt(hEvent, "player_entindex");

	CEcon_SendEventToClientFromGameEvent(player, "TF_EYEBALL_STUN", 1, hEvent);

	return Plugin_Continue;
}

public Action eyeball_boss_killer(Handle hEvent, const char[] szName, bool bDontBroadcast)
{
	int player = GetEventInt(hEvent, "player_entindex");

	CEcon_SendEventToClientFromGameEvent(player, "TF_EYEBALL_KILL", 1, hEvent);

	return Plugin_Continue;
}

public Action tagged_player_as_it(Handle hEvent, const char[] szName, bool bDontBroadcast)
{
	int player = GetClientOfUserId(GetEventInt(hEvent, "player"));

	CEcon_SendEventToClientFromGameEvent(player, "TF_HHH_TARGET_IT", 1, hEvent);

	return Plugin_Continue;
}

public Action respawn_ghost(Handle hEvent, const char[] szName, bool bDontBroadcast)
{
	int reviver = GetClientOfUserId(GetEventInt(hEvent, "reviver"));

	CEcon_SendEventToClientFromGameEvent(reviver, "TF_BUMPER_CARS_REVIVE", 1, hEvent);

	return Plugin_Continue;
}

public Action halloween_duck_collected(Handle hEvent, const char[] szName, bool bDontBroadcast)
{
	int collector = GetClientOfUserId(GetEventInt(hEvent, "collector"));

	CEcon_SendEventToClientFromGameEvent(collector, "TF_COLLECT_DUCK", 1, hEvent);

	return Plugin_Continue;
}

public Action halloween_soul_collected(Handle hEvent, const char[] szName, bool bDontBroadcast)
{
	int collector = GetClientOfUserId(GetEventInt(hEvent, "collecting_player"));
	int soul_count = GetEventInt(hEvent, "soul_count");

	CEcon_SendEventToClientFromGameEvent(collector, "TF_COLLECT_SOULS", soul_count, hEvent);

	return Plugin_Continue;
}

public Action object_destroyed(Handle hEvent, const char[] szName, bool bDontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(hEvent, "userid"));
	int attacker = GetClientOfUserId(GetEventInt(hEvent, "attacker"));
	int assister = GetClientOfUserId(GetEventInt(hEvent, "assister"));
	int objecttype = GetEventInt(hEvent, "objecttype");

	if(IsClientValid(client))
	{
		switch(objecttype)
		{
			case TF_BUILDING_SENTRY: CEcon_SendEventToClientFromGameEvent(client, "TF_OBJECT_DESTROYED_SENTRY", 1, hEvent);
			case TF_BUILDING_DISPENSER: CEcon_SendEventToClientFromGameEvent(client, "TF_OBJECT_DESTROYED_DISPENSER", 1, hEvent);
			case TF_BUILDING_TELEPORTER: CEcon_SendEventToClientFromGameEvent(client, "TF_OBJECT_DESTROYED_TELEPORTER", 1, hEvent);
		}
	}

	if(IsClientValid(attacker) && attacker != client)
	{
		CEcon_SendEventToClientFromGameEvent(attacker, "TF_KILL_OBJECT", 1, hEvent);
		switch(objecttype)
		{
			case TF_BUILDING_SENTRY: CEcon_SendEventToClientFromGameEvent(attacker, "TF_KILL_OBJECT_SENTRY", 1, hEvent);
			case TF_BUILDING_DISPENSER: CEcon_SendEventToClientFromGameEvent(attacker, "TF_KILL_OBJECT_DISPENSER", 1, hEvent);
			case TF_BUILDING_TELEPORTER: CEcon_SendEventToClientFromGameEvent(attacker, "TF_KILL_OBJECT_TELEPORTER", 1, hEvent);
			case TF_BUILDING_SAPPER: CEcon_SendEventToClientFromGameEvent(attacker, "TF_KILL_OBJECT_SAPPER", 1, hEvent);
		}
	}

	if(IsClientValid(assister))
	{
		if(TF2_IsUbercharged(assister))
		{
			switch(objecttype)
			{
				case TF_BUILDING_SENTRY: CEcon_SendEventToClientFromGameEvent(assister, "TF_ASSIST_WHILE_UBERCHARGED_OBJECT_SENTRY", 1, hEvent);
				case TF_BUILDING_DISPENSER: CEcon_SendEventToClientFromGameEvent(assister, "TF_ASSIST_WHILE_UBERCHARGED_OBJECT_DISPENSER", 1, hEvent);
				case TF_BUILDING_TELEPORTER: CEcon_SendEventToClientFromGameEvent(assister, "TF_ASSIST_WHILE_UBERCHARGED_OBJECT_TELEPORTER", 1, hEvent);
			}
		}
	}

	return Plugin_Continue;
}

public Action teamplay_setup_finished(Handle hEvent, const char[] szName, bool bDontBroadcast)
{

	return Plugin_Continue;
}

public Action evTeamplayRoundStart(Handle hEvent, const char[] szName, bool bDontBroadcast)
{

	return Plugin_Continue;
}

public Action evTeamplayRoundActive(Handle hEvent, const char[] szName, bool bDontBroadcast)
{

	return Plugin_Continue;
}

public Action object_detonated(Handle hEvent, const char[] szName, bool bDontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(hEvent, "userid"));
	int objecttype = GetClientOfUserId(GetEventInt(hEvent, "attacker"));

	if(IsClientValid(client))
	{
		switch(objecttype)
		{
			case TF_BUILDING_SENTRY: CEcon_SendEventToClientFromGameEvent(client, "TF_OBJECT_DESTROYED_SENTRY", 1, hEvent);
			case TF_BUILDING_DISPENSER: CEcon_SendEventToClientFromGameEvent(client, "TF_OBJECT_DESTROYED_DISPENSER", 1, hEvent);
			case TF_BUILDING_TELEPORTER: CEcon_SendEventToClientFromGameEvent(client, "TF_OBJECT_DESTROYED_TELEPORTER", 1, hEvent);
		}
	}

	return Plugin_Continue;
}

public Action object_deflected(Handle hEvent, const char[] szName, bool bDontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(hEvent, "userid"));

	CEcon_SendEventToClientFromGameEvent(client, "TF_REFLECT", 1, hEvent);

	return Plugin_Continue;
}

public Action player_hurt(Handle hEvent, const char[] szName, bool bDontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(hEvent, "userid"));
	int attacker = GetClientOfUserId(GetEventInt(hEvent, "attacker"));
	int damage = GetEventInt(hEvent, "damageamount");

	if(IsClientValid(attacker) && attacker != client)
	{
		CEcon_SendEventToClientFromGameEvent(attacker, "TF_HIT_PLAYER", 1, hEvent);
		CEcon_SendEventToClientFromGameEvent(attacker, "TF_DEAL_DAMAGE", damage, hEvent);
	}

	if(IsClientValid(client))
	{
		CEcon_SendEventToClientFromGameEvent(client, "TF_TAKE_DAMAGE", damage, hEvent);
	}

	return Plugin_Continue;
}

public Action player_score_changed(Handle hEvent, const char[] szName, bool bDontBroadcast)
{
	int player = GetEventInt(hEvent, "player");
	int delta = GetEventInt(hEvent, "delta");

	CEcon_SendEventToClientFromGameEvent(player, "TF_SCORE_POINTS", delta, hEvent);

	return Plugin_Continue;
}

public Action environmental_death(Handle hEvent, const char[] szName, bool bDontBroadcast)
{
	int killer = GetEventInt(hEvent, "killer");
	int victim = GetEventInt(hEvent, "victim");

	if(IsClientValid(killer) && killer != victim)
	{
		CEcon_SendEventToClientFromGameEvent(killer, "TF_KILL_ENVIRONMENTAL", 1, hEvent);
	}

	return Plugin_Continue;
}

public Action medic_death(Handle hEvent, const char[] szName, bool bDontBroadcast)
{
	int attacker = GetClientOfUserId(GetEventInt(hEvent, "attacker"));
	bool charged = GetEventBool(hEvent, "charged");

	if(charged)
	{
		CEcon_SendEventToClientFromGameEvent(attacker, "TF_KILL_UBERED_MEDIC", 1, hEvent);
	}

	return Plugin_Continue;
}

public Action evTeamplayRoundWin(Handle hEvent, const char[] szName, bool bDontBroadcast)
{

	return Plugin_Continue;
}

public Action player_spawn(Handle hEvent, const char[] szName, bool bDontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(hEvent, "userid"));
	CEcon_SendEventToClientFromGameEvent(client, "TF_SPAWN", 1, hEvent);

	return Plugin_Continue;
}

public Action teamplay_flag_event(Handle hEvent, const char[] szName, bool bDontBroadcast)
{
	int player = GetEventInt(hEvent, "player");
	int eventtype = GetEventInt(hEvent, "eventtype");

	if(IsClientValid(player))
	{
		switch(eventtype)
		{
			case TF_FLAGEVENT_PICKEDUP:CEcon_SendEventToClientFromGameEvent(player, "TF_PICKUP_FLAG", 1, hEvent);
			case TF_FLAGEVENT_CAPTURED:
			{
				CEcon_SendEventToClientFromGameEvent(player, "TF_CAPTURE_FLAG", 1, hEvent);
				CEcon_SendEventToClientFromGameEvent(player, "TF_OBJECTIVE_CAPTURE", 1, hEvent);
				CEcon_SendEventToClientFromGameEvent(player, "TF_OBJECTIVE_CAPTURE_OR_DEFEND", 1, hEvent);
			}
			case TF_FLAGEVENT_DEFENDED:
			{
				CEcon_SendEventToClientFromGameEvent(player, "TF_DEFEND_FLAG", 1, hEvent);
				CEcon_SendEventToClientFromGameEvent(player, "TF_OBJECTIVE_DEFEND", 1, hEvent);
				CEcon_SendEventToClientFromGameEvent(player, "TF_OBJECTIVE_CAPTURE_OR_DEFEND", 1, hEvent);
			}
		}
	}

	return Plugin_Continue;
}

public Action player_healed(Handle hEvent, const char[] szName, bool bDontBroadcast)
{
	int patient = GetClientOfUserId(GetEventInt(hEvent, "patient"));
	int healer = GetClientOfUserId(GetEventInt(hEvent, "healer"));
	int amount = GetEventInt(hEvent, "amount");

	if(IsClientValid(healer) && healer != patient)
	{
		CEcon_SendEventToClientFromGameEvent(healer, "TF_HEALING_TEAMMATES", amount, hEvent);
	}

	return Plugin_Continue;
}

public Action player_chargedeployed(Handle hEvent, const char[] szName, bool bDontBroadcast)
{
	int deployer = GetEventInt(hEvent, "userid");

	if(IsClientValid(deployer))
	{
		CEcon_SendEventToClientFromGameEvent(deployer, "TF_DEPLOY_UBERCHARGE", 1, hEvent);
	}
	return Plugin_Continue;
}

public Action killed_capping_player(Handle hEvent, const char[] szName, bool bDontBroadcast)
{
	int attacker = GetEventInt(hEvent, "killer");
	int victim = GetEventInt(hEvent, "victim");

	if(IsClientValid(attacker) && attacker != victim)
	{
		CEcon_SendEventToClientFromGameEvent(attacker, "TF_DEFEND_POINT", 1, hEvent);
		CEcon_SendEventToClientFromGameEvent(attacker, "TF_OBJECTIVE_DEFEND", 1, hEvent);
		CEcon_SendEventToClientFromGameEvent(attacker, "TF_OBJECTIVE_CAPTURE_OR_DEFEND", 1, hEvent);
	}

	return Plugin_Continue;
}

public Action payload_pushed(Handle hEvent, const char[] szName, bool bDontBroadcast)
{
	int pusher = GetClientOfUserId(GetEventInt(hEvent, "pusher"));
	int distance = GetEventInt(hEvent, "distance");

	if(IsClientValid(pusher))
	{
		CEcon_SendEventToClientFromGameEvent(pusher, "TF_PAYLOAD_PUSH", distance, hEvent);
	}

	return Plugin_Continue;
}

public bool TF2_IsUbercharged(int client)
{
	return 	TF2_IsPlayerInCondition(client, TFCond_Ubercharged) ||
			TF2_IsPlayerInCondition(client, TFCond_Kritzkrieged) ||
			TF2_IsPlayerInCondition(client, TFCond_MegaHeal) ||
			TF2_IsPlayerInCondition(client, TFCond_UberBlastResist) ||
			TF2_IsPlayerInCondition(client, TFCond_UberFireResist) ||
			TF2_IsPlayerInCondition(client, TFCond_UberBulletResist);
}

public Action evTeamplayWinPanel(Handle hEvent, const char[] szName, bool bDontBroadcast)
{
	int player_1 = GetEventInt(hEvent, "player_1");
	int player_2 = GetEventInt(hEvent, "player_2");
	int player_3 = GetEventInt(hEvent, "player_3");

	if (IsClientValid(player_1))
    {
        CEcon_SendEventToClientFromGameEvent(player_1, "TF_MVP", 1, hEvent);
        CEcon_SendEventToClientFromGameEvent(player_1, "TF_MVP_1", 1, hEvent);
    }
	if (IsClientValid(player_2))
    {
        CEcon_SendEventToClientFromGameEvent(player_2, "TF_MVP", 1, hEvent);
        CEcon_SendEventToClientFromGameEvent(player_2, "TF_MVP_2", 1, hEvent);
    }
	if (IsClientValid(player_2))
    {
        CEcon_SendEventToClientFromGameEvent(player_3, "TF_MVP", 1, hEvent);
        CEcon_SendEventToClientFromGameEvent(player_3, "TF_MVP_3", 1, hEvent);
    }

	return Plugin_Continue;
}

public Action teamplay_point_captured(Handle hEvent, const char[] szName, bool bDontBroadcast)
{

	char cappers[1024];
	GetEventString(hEvent, "cappers", cappers, sizeof(cappers));
	int len = strlen(cappers);
	for (int i = 0; i < len; i++)
	{
		int client = cappers[i];
		if (!IsClientValid(client))continue;

		CEcon_SendEventToClientFromGameEvent(client, "TF_CAPTURE_POINT", 1, hEvent);
		CEcon_SendEventToClientFromGameEvent(client, "TF_OBJECTIVE_CAPTURE", 1, hEvent);
		CEcon_SendEventToClientFromGameEvent(client, "TF_OBJECTIVE_CAPTURE_OR_DEFEND", 1, hEvent);
	}
	return Plugin_Continue;
}

public void TF2_OnConditionAdded(int client, TFCond cond)
{
}

public void TF2_OnConditionRemoved(int client, TFCond cond)
{
	switch(cond)
	{
		case TFCond_EyeaductUnderworld:
		{
			if(IsPlayerAlive(client))
			{
				CEcon_SendEventToClientUnique(client, "TF_ESCAPE_UNDERWORLD", 1);
			}
		}
	}
}

public bool IsClientValid(int client)
{
	if (client <= 0 || client > MaxClients)return false;
	if (!IsClientInGame(client))return false;
	if (!IsClientAuthorized(client))return false;
	return true;
}

public bool IsClientReady(int client)
{
	if (!IsClientValid(client))return false;
	if (IsFakeClient(client))return false;
	return true;
}