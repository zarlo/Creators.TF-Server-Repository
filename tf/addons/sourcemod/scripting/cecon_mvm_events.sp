#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <tf2>
#include <tf2_stocks>
#include <cecon>
#include <tf2attributes>

public Plugin myinfo =
{
	name = "Creators.TF Economy - TF2 MvM Events",
	author = "Creators.TF Team",
	description = "Creators.TF TF2 MvM Events",
	version = "1.0",
	url = "https://creators.tf"
}

char blimp_models[][] = {"models/bots/boss_bot/boss_blimp.mdl", "models/bots/boss_bot/boss_blimp_damage1.mdl", "models/bots/boss_bot/boss_blimp_damage2.mdl", "models/bots/boss_bot/boss_blimp_damage3.mdl"};
int blimp_models_precached[4];
bool uses_custom_upgrades = false;

#define TF_MAXPLAYERS 34 // 33 max players + 1 for offset

// Player data that persist for the duration of the mission
enum struct PlayerDataMission
{
	int wave_finished_counter;

	void Init()
	{
		this.wave_finished_counter = 0;
	}
}

enum struct PlayerData
{
	int touched_cp_area;
	int tank_damage_last_second;

	// Use this for MVP check instead.
	int tank_damage_wave;

	int tank_damage_mission;

	// Bit mask of every client index who damaged the player
	int hit_tracker;

	int killed_by;

	bool buster_save_sentry_ranged;

	int fire_weapon_gained_metal;
	int metal_pre_shoot;

	int ignited_by;

	float pick_bomb_time;
	float leave_spawn_time;

	// Total damage dealt to bots in the mission
	int damage_dealt_counter;

	void Init(int client)
	{
		this.touched_cp_area = -1;
		this.tank_damage_wave = 0;
		this.tank_damage_last_second = 0;
		this.killed_by = 0;
		this.hit_tracker = 0;
		this.buster_save_sentry_ranged = false;
		this.fire_weapon_gained_metal = 0;
		this.metal_pre_shoot = 0;
		this.ignited_by = 0;
		this.pick_bomb_time = 0.0;
		this.leave_spawn_time = 0.0;
		this.damage_dealt_counter = 0;

	}
}

PlayerData player_data[TF_MAXPLAYERS];

StringMap player_data_mission;

Handle get_condition_provider_handle;
//Handle attrib_float_handle;

int TankDamage[MAXPLAYERS+1] = 0;
int GrenadeDamage[MAXPLAYERS+1] = 0;

int bonus_currency_counter = 0;

public void OnPluginStart()
{
	HookEvent("upgrades_file_changed", upgrades_file_changed);

	HookEvent("mvm_mission_complete", mvm_mission_complete);

	HookEvent("mvm_tank_destroyed_by_players", mvm_tank_destroyed_by_players);

	HookEvent("mvm_begin_wave", mvm_begin_wave);
	HookEvent("mvm_wave_failed", mvm_wave_failed);
	HookEvent("mvm_wave_complete", mvm_wave_complete);

	HookEvent("controlpoint_starttouch", controlpoint_starttouch);
	HookEvent("controlpoint_endtouch", controlpoint_endtouch);

	HookEvent("player_spawn", player_spawn);
	HookEvent("player_death", player_death);
	HookEvent("medic_death", medic_death);

	HookEvent("player_hurt", player_hurt);
	HookEvent("damage_resisted", damage_resisted);
	HookEvent("player_ignited", player_ignited);

	HookEvent("player_healed", player_healed);
	HookEvent("player_healonhit", player_healonhit);
	HookEvent("revive_player_complete", revive_player_complete);
	HookEvent("medigun_shield_blocked_damage", medigun_shield_blocked_damage);
	HookEvent("player_chargedeployed", player_chargedeployed);
	HookEvent("mvm_medic_powerup_shared", mvm_medic_powerup_shared);

	HookEvent("mvm_pickup_currency", mvm_pickup_currency);
	HookEvent("mvm_creditbonus_wave", mvm_creditbonus_wave);

	HookEvent("mvm_sentrybuster_detonate", mvm_sentrybuster_detonate);
	HookEvent("player_carryobject", player_carryobject);
	HookEvent("building_healed", building_healed);

	HookEvent("player_stunned", player_stunned);

	HookEvent("deploy_buff_banner", deploy_buff_banner);

	HookEvent("mvm_bomb_reset_by_player", mvm_bomb_reset_by_player);
	HookEvent("mvm_bomb_deploy_reset_by_player", mvm_bomb_deploy_reset_by_player);

	HookEvent("player_extinguished", player_extinguished);

	HookEvent("teamplay_flag_event", teamplay_flag_event);

	HookEvent("player_used_powerup_bottle", player_used_powerup_bottle);

	Handle hData = LoadGameConfigFile("tf2.cecon_mvm_events");
	if (hData != null)
	{
		StartPrepSDKCall(SDKCall_Raw);
		PrepSDKCall_SetFromConf(hData, SDKConf_Signature, "CTFPlayerShared::GetConditionProvider");
		PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
		PrepSDKCall_SetReturnInfo(SDKType_CBaseEntity, SDKPass_Plain);
		get_condition_provider_handle = EndPrepSDKCall();

		//StartPrepSDKCall(SDKCall_Static);
		//PrepSDKCall_SetFromConf(hData, SDKConf_Signature, "CAttributeManager::AttribHookValueFloat");
		//
		//PrepSDKCall_AddParameter(SDKType_Float, SDKPass_Plain);
		//PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
		//PrepSDKCall_AddParameter(SDKType_CBaseEntity, SDKPass_Pointer, VDECODE_FLAG_ALLOWNULL);
		//PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
		//PrepSDKCall_AddParameter(SDKType_Bool, SDKPass_Plain);
		//PrepSDKCall_SetReturnInfo(SDKType_Float, SDKPass_Plain);

		//attrib_float_handle = EndPrepSDKCall();
	}
	else
	{
	}

	AddNormalSoundHook(OnSound);
	CreateTimer(1.0, UpdateTimer, 0, TIMER_REPEAT);
}

public void OnMapStart()
{
	for (int i = 0; i < 4; i++)
	{
		blimp_models_precached[i] = PrecacheModel(blimp_models[i], false);
	}
	if(GameRules_GetProp("m_bPlayingMannVsMachine") == 0)
	{
		// Only works in MVM.
		ServerCommand("sm plugins unload cecon_mvm_events");
	}
}

public void OnClientPutInServer(int client)
{
	player_data[client].Init(client);
	ResetDamage(client);

	if (player_data_mission != null)
	{
		PlayerDataMission player_data_mission_inst;
		SetPlayerMissionData(client, player_data_mission_inst, false);
	}

	SDKHook(client, SDKHook_OnTakeDamagePost, OnPlayerDamagePost);
	SDKHook(client, SDKHook_OnTakeDamage, OnPlayerDamage);
}

public void ResetDamage(int client)
{
	TankDamage[client] = 0;
	GrenadeDamage[client] = 0;
}

// Update every second events
public Action UpdateTimer(Handle timer, any data)
{
	if (GameRules_GetRoundState() == RoundState_RoundRunning)
	{
		int player_resource = GetPlayerResourceEntity();
		for (int i = 1; i <= TF_MAXPLAYERS; i++)
		{
			// Not a bot.
			if (IsClientValid(i) && !IsFakeClient(i))
			{
				if (TF2_IsPlayerInCondition(i, TFCond_CritOnKill))
				{
					CEcon_SendEventToClientUnique(i, "TF_MVM_CRITBOOST_ON_KILL_SECOND", 1);
				}

				int tank_damage = GetEntProp(player_resource, Prop_Send, "m_iDamageBoss", 4, i);

				if (tank_damage > player_data[i].tank_damage_last_second)
				{
					CEcon_SendEventToClientUnique(i, "TF_MVM_DAMAGE_TANK", tank_damage - player_data[i].tank_damage_last_second);
				}

				player_data[i].tank_damage_last_second = tank_damage;
				player_data[i].tank_damage_wave += tank_damage;
			}
		}
	}
}

public Action OnPlayerRunCmd(int client, int& buttons, int& impulse, float vel[3], float angles[3], int& weapon, int& subtype, int& cmdnum, int& tickcount, int& seed, int mouse[2])
{
	if (!(buttons & IN_ATTACK) && player_data[client].fire_weapon_gained_metal > 0)
	{
		CEcon_SendEventToClientUnique(client, "TF_MVM_KEEP_FIRING_GAIN_METAL_RESET", 1);
		player_data[client].fire_weapon_gained_metal = 0;
	}
	else if (weapon != 0 && player_data[client].fire_weapon_gained_metal > 0)
	{
		CEcon_SendEventToClientUnique(client, "TF_MVM_KEEP_FIRING_GAIN_METAL_RESET", 1);
		player_data[client].fire_weapon_gained_metal = 0;
	}
}

public Action OnSound(int clients[MAXPLAYERS], int &numClients, char sample[PLATFORM_MAX_PATH],
	  int &entity, int &channel, float &volume, int &level, int &pitch, int &flags,
	  char soundEntry[PLATFORM_MAX_PATH], int &seed)
{
	// Widowmaker shoot hook
	if (channel == 1 && strncmp(sample, ")weapons\\widow_maker_shot_", strlen(")weapons\\widow_maker_shot_")) == 0
		&& IsClientValid(entity) && GameRules_GetRoundState() == RoundState_RoundRunning)
	{
		player_data[entity].metal_pre_shoot = GetEntProp(entity, Prop_Data, "m_iAmmo", 4, 3);
		RequestFrame(WidowmakerShootUpdate, entity);
	}
	// Short circuit deflect sound hook
	else if (entity > TF_MAXPLAYERS && strcmp(sample, ")weapons\\upgrade_explosive_headshot.wav") == 0)
	{
		char classname[36];
		GetEntityClassname(entity, classname, sizeof(classname));
		if (strcmp(classname, "tf_projectile_mechanicalarmorb") == 0)
		{
			int owner = GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity");

			CEcon_SendEventToClientUnique(owner, "TF_MVM_DEFLECT_SHORT_CIRCUIT", 1);
		}
	}
}

public void WidowmakerShootUpdate(int client)
{
	int metal_diff = GetEntProp(client, Prop_Data, "m_iAmmo", 4, 3) - player_data[client].metal_pre_shoot;
	if (metal_diff < 0)
	{
		player_data[client].fire_weapon_gained_metal=0;
		CEcon_SendEventToClientUnique(client, "TF_MVM_KEEP_FIRING_GAIN_METAL_RESET", 1);
	}
	else
	{
		player_data[client].fire_weapon_gained_metal++;
		CEcon_SendEventToClientUnique(client, "TF_MVM_KEEP_FIRING_GAIN_METAL", 1);
	}
}

// BLIMP LOGIC:
public void OnEntityCreated(int entity, const char[] classname)
{
	if (StrEqual(classname, "tank_boss"))
	{
		SDKHook(entity, SDKHook_SpawnPost, OnTankSpawn);
	}
}
/*
	1) Check to see if this is a blimp.
	2) Rename the targetname to include this.
*/
public void OnTankSpawn(int tank)
{
	// Blimp check:
	float vec[3];
	GetEntPropVector(tank, Prop_Send, "m_vecOrigin", vec);
	float vecdown[3];
	vecdown = vec;
	vecdown[2] -= 40;
	vec[2] -= 90;

	TR_TraceRay(vec, vecdown, MASK_SOLID_BRUSHONLY, RayType_EndPoint);
	if (!TR_DidHit())
	{
		//PrintToChatAll("IsBlimp!");
	}

	//Hook individual tank damage
	SDKHook(tank, SDKHook_OnTakeDamageAlive, TankTakeDamage);
	//PrintToChatAll("Tank Spawned");
}


//Track damage from each player on all tanks in a single wave
public Action TankTakeDamage(int tank, int &attacker, int &inflictor, float &damage, int &damagetype, int &weapon, float damageForce[3], float damagePosition[3])
{
	if (IsClientValid(attacker))
	{
		TankDamage[attacker] += RoundFloat(damage);
		if (damagetype & DMG_BLAST) //Track Blast Damage
		{
			if (IsValidEntity(weapon))
			{
				char classname[32];
				GetEntityClassname(weapon, classname, sizeof(classname));
				if (StrEqual(classname, "tf_weapon_grenadelauncher") || StrEqual(classname, "tf_weapon_cannon"))
				{
					GrenadeDamage[attacker] += RoundFloat(damage);
				}
			}
			//PrintToChat(attacker, "Blast Damage: %i", GrenadeDamage[attacker]);
		}
		//PrintToChat(attacker, "Damage: %i", TankDamage[attacker]);
	}
}

public Action player_changeclass(Event hEvent, const char[] name, bool dontBroadcast)
{
	//int client = GetClientOfUserId(hEvent.GetInt("userid"));
	//int class = hEvent.GetInt("class");

	return Plugin_Continue;
}

public Action upgrades_file_changed(Handle hEvent, const char[] szName, bool bDontBroadcast)
{
	char upgrade_path[256];

	GetEventString(hEvent, "path", upgrade_path, sizeof(upgrade_path), "");

	uses_custom_upgrades = strcmp(upgrade_path, "") != 0 && strcmp(upgrade_path, "scripts/items/mvm_upgrades.txt") != 0;

	return Plugin_Continue;
}

public Action mvm_mission_complete(Handle hEvent, const char[] szName, bool bDontBroadcast)
{

	CEcon_SendEventToAll("TF_MVM_MISSION_COMPLETE", 1, GetRandomInt(0, 9999));

	int objective_resource = FindEntityByClassname(-1, "tf_objective_resource");


	/*
	int resource = GetPlayerResourceEntity();
	int highest_damage_tank = 0;
	int highest_damage_tank_player = 0;
	*/
	int highest_damage = 0;
	int highest_damage_player = 0;

	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientValid(i) && !IsFakeClient(i))
		{
			PlayerDataMission player_data_mission_inst;
			GetPlayerMissionData(i, player_data_mission_inst);

			if (player_data_mission_inst.wave_finished_counter == GetEntProp(objective_resource, Prop_Send,"m_nMannVsMachineMaxWaveCount"))
			{
				if (uses_custom_upgrades) {
					CEcon_SendEventToClientFromGameEvent(i, "TF_MVM_USE_CUSTOM_UPGRADES", 1, hEvent);
				}

				CEcon_SendEventToClientFromGameEvent(i, "TF_MVM_MISSION_COMPLETE_ALL_WAVES", 1, hEvent);
			}

			//int damage_tank = GetEntProp(resource, Prop_Send, "m_iDamageBoss", 4, i);
			//if (damage_tank > highest_damage_tank) {
			//	highest_damage_tank = damage_tank;
			//	highest_damage_tank_player = i;
			//}

			int damage = player_data[i].damage_dealt_counter;
			if (damage > highest_damage) {
				highest_damage = damage;
				highest_damage_player = i;
			}
		}
	}


	//if (highest_damage_tank_player > 0)
	//{
	//	CEcon_SendEventToClientFromGameEvent(highest_damage_tank_player, "TF_MVM_DAMAGE_TANK_MVP", 1, hEvent);
	//}

	if (highest_damage_player > 0)
	{
		CEcon_SendEventToClientFromGameEvent(highest_damage_player, "TF_MVM_DAMAGE_ROBOT_MVP", 1, hEvent);
	}

	return Plugin_Continue;
}

public Action player_spawn(Handle hEvent, const char[] szName, bool bDontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(hEvent, "userid"));

	player_data[client].hit_tracker = 0;
	player_data[client].killed_by = 0;
	player_data[client].touched_cp_area = -1;

	return Plugin_Continue;
}

int player_death_attacker_last;
int player_death_damage_custom_last;
int player_death_tick_last;

int player_hurt_attacker_decap_last;
int weapon_damage_last;
public Action player_death(Handle hEvent, const char[] szName, bool bDontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(hEvent, "userid"));
	int attacker = GetClientOfUserId(GetEventInt(hEvent, "attacker"));
	int assister = GetClientOfUserId(GetEventInt(hEvent, "assister"));

	/*
	int weapon_def = GetEventInt(hEvent, "weapon_def_index");
	int death_flags = GetEventInt(hEvent, "death_flags");
	int kill_streak_victim = GetEventInt(hEvent, "kill_streak_victim");
	*/
	int customkill = GetEventInt(hEvent, "customkill");
	int crit_type = GetEventInt(hEvent, "crit_type");

	char weapon_name[64];
	GetEventString(hEvent, "weapon_logclassname", weapon_name, sizeof(weapon_name));

	player_death_attacker_last = attacker;
	player_death_damage_custom_last = customkill;
	player_death_tick_last = GetGameTickCount();
	if (IsClientValid(client))
	{
		//player_data[client].ResetStreak();
		if (IsClientValid(attacker))
		{
			if (client != attacker)
			{

				if (IsFakeClient(client))
				{
					int leave_spawn_timespan = RoundToCeil(GetGameTime() - player_data[client].leave_spawn_time);
					if (leave_spawn_timespan < 1)
					{
						leave_spawn_timespan = 1;
					}

					CEcon_SendEventToClientFromGameEvent(attacker, "TF_MVM_KILL_ROBOT", 1, hEvent);

					switch (crit_type)
					{
						case 0: CEcon_SendEventToClientFromGameEvent(attacker, "TF_MVM_KILL_ROBOT_CRIT_NONE", 1, hEvent);
						case 1: CEcon_SendEventToClientFromGameEvent(attacker, "TF_MVM_KILL_ROBOT_CRIT_MINI", 1, hEvent);
						case 2: CEcon_SendEventToClientFromGameEvent(attacker, "TF_MVM_KILL_ROBOT_CRIT_FULL", 1, hEvent);
					}

					if (IsClientValid(assister))
					{
						player_data[client].hit_tracker |= 1 << (assister - 1);
						CEcon_SendEventToClientFromGameEvent(assister, "TF_MVM_KILL_ASSIST_ROBOT", 1, hEvent);
					}

					if (IsGiantNotBuster(client))
					{
						int hit_tracker = player_data[client].hit_tracker;
						// Players who assisted or dealt damage receive kill
						for (int i = 0; i < 32; i++)
						{
							if ((hit_tracker & (1 << i)) != 0)
							{
								int scorer = i + 1;
								CEcon_SendEventToClientFromGameEvent(scorer, "TF_MVM_KILL_ROBOT_GIANT", 1, hEvent);
								CEcon_SendEventToClientFromGameEvent(scorer, "TF_MVM_KILL_ROBOT_GIANT_X_SECONDS_AFTER_SPAWN_LEAVE", leave_spawn_timespan, hEvent);

								switch (TF2_GetPlayerClass(client))
								{
									case TFClass_Scout: CEcon_SendEventToClientFromGameEvent(scorer, "TF_MVM_KILL_ROBOT_GIANT_SCOUT", 1, hEvent);
									case TFClass_Soldier: CEcon_SendEventToClientFromGameEvent(scorer, "TF_MVM_KILL_ROBOT_GIANT_SOLDIER", 1, hEvent);
									case TFClass_Pyro: CEcon_SendEventToClientFromGameEvent(scorer, "TF_MVM_KILL_ROBOT_GIANT_PYRO", 1, hEvent);
									case TFClass_DemoMan: CEcon_SendEventToClientFromGameEvent(scorer, "TF_MVM_KILL_ROBOT_GIANT_DEMOMAN", 1, hEvent);
									case TFClass_Heavy: CEcon_SendEventToClientFromGameEvent(scorer, "TF_MVM_KILL_ROBOT_GIANT_HEAVY", 1, hEvent);
									case TFClass_Engineer: CEcon_SendEventToClientFromGameEvent(scorer, "TF_MVM_KILL_ROBOT_GIANT_ENGINEER", 1, hEvent);
									case TFClass_Medic:
									{
										CEcon_SendEventToClientFromGameEvent(scorer, "TF_MVM_KILL_ROBOT_GIANT_MEDIC", 1, hEvent);
										CEcon_SendEventToClientFromGameEvent(scorer, "TF_MVM_KILL_ROBOT_GIANT_MEDIC_X_SECONDS_AFTER_SPAWN_LEAVE", leave_spawn_timespan, hEvent);
									}
									case TFClass_Sniper: CEcon_SendEventToClientFromGameEvent(scorer, "TF_MVM_KILL_ROBOT_GIANT_SNIPER", 1, hEvent);
									case TFClass_Spy: CEcon_SendEventToClientFromGameEvent(scorer, "TF_MVM_KILL_ROBOT_GIANT_SPY", 1, hEvent);
								}

								if (TF2_IsPlayerInCondition(client, TFCond_OnFire))
								{
									CEcon_SendEventToClientFromGameEvent(scorer, "TF_MVM_KILL_ROBOT_GIANT_BURNING", 1, hEvent);

									if (GetConditionProvider(client, TFCond_OnFire) == scorer)
									{
										CEcon_SendEventToClientFromGameEvent(scorer, "TF_MVM_KILL_ROBOT_GIANT_BURNING_PROVIDER", 1, hEvent);
									}
								}

								if (TF2_GetPlayerClass(client) == TFClass_Scout && GetAttributeValue(client, "mult_player_movespeed", 1.0) >= 2.0)
								{
									CEcon_SendEventToClientFromGameEvent(scorer, "TF_MVM_KILL_ROBOT_SUPER_SCOUT", 1, hEvent);
								}
							}
						}

						CEcon_SendEventToClientFromGameEvent(attacker, "TF_MVM_KILL_ROBOT_GIANT_FINAL", 1, hEvent);
					}

					if (!IsSentryBuster(client))
					{
						switch (TF2_GetPlayerClass(client))
						{
							case TFClass_Scout: CEcon_SendEventToClientFromGameEvent(attacker, "TF_MVM_KILL_ROBOT_SCOUT", 1, hEvent);
							case TFClass_Soldier: CEcon_SendEventToClientFromGameEvent(attacker, "TF_MVM_KILL_ROBOT_SOLDIER", 1, hEvent);
							case TFClass_Pyro: CEcon_SendEventToClientFromGameEvent(attacker, "TF_MVM_KILL_ROBOT_PYRO", 1, hEvent);
							case TFClass_DemoMan: CEcon_SendEventToClientFromGameEvent(attacker, "TF_MVM_KILL_ROBOT_DEMOMAN", 1, hEvent);
							case TFClass_Heavy: CEcon_SendEventToClientFromGameEvent(attacker, "TF_MVM_KILL_ROBOT_HEAVY", 1, hEvent);
							case TFClass_Engineer: CEcon_SendEventToClientFromGameEvent(attacker, "TF_MVM_KILL_ROBOT_ENGINEER", 1, hEvent);
							case TFClass_Medic: CEcon_SendEventToClientFromGameEvent(attacker, "TF_MVM_KILL_ROBOT_MEDIC", 1, hEvent);
							case TFClass_Sniper: CEcon_SendEventToClientFromGameEvent(attacker, "TF_MVM_KILL_ROBOT_SNIPER", 1, hEvent);
							case TFClass_Spy: CEcon_SendEventToClientFromGameEvent(attacker, "TF_MVM_KILL_ROBOT_SPY", 1, hEvent);
						}
					}

					// All players receive boss kill events
					if (IsBoss(client))
					{
						CEcon_SendEventToAll("TF_MVM_KILL_ROBOT_BOSS", 1, GetRandomInt(0, 9999));
					}

					if (GetEntProp(client, Prop_Data, "m_iMaxHealth") >= 8000)
					{
						CEcon_SendEventToAll("TF_MVM_KILL_ROBOT_LARGE_HEALTH", 1, GetRandomInt(0, 9999));
					}

					if (TF2_IsPlayerInCondition(client, TFCond_OnFire))
					{
						CEcon_SendEventToClientFromGameEvent(attacker, "TF_MVM_KILL_ROBOT_BURNING", 1, hEvent);

						if (GetConditionProvider(client, TFCond_OnFire) == attacker)
						{
							CEcon_SendEventToClientFromGameEvent(attacker, "TF_MVM_KILL_ROBOT_BURNING_PROVIDER", 1, hEvent);
						}
					}

					if (TF2_IsPlayerInCondition(client, TFCond_Sapped))
					{
						CEcon_SendEventToClientFromGameEvent(attacker, "TF_MVM_KILL_ROBOT_SAPPED", 1, hEvent);
					}

					if (!(GetEntityFlags(attacker) & FL_ONGROUND))
					{
						CEcon_SendEventToClientFromGameEvent(attacker, "TF_MVM_KILL_WHILE_AIRBORNE", 1, hEvent);
					}

					if (TF2_IsPlayerInCondition(client, TFCond_Dazed))
					{
						CEcon_SendEventToClientFromGameEvent(attacker, "TF_MVM_KILL_ROBOT_STUNNED", 1, hEvent);
					}

					// Gatebot filter
					int filter = CreateEntityByName("filter_tf_bot_has_tag");
					if (filter != -1)
					{
						DispatchKeyValue(filter, "tags", "bot_gatebot");
						DispatchSpawn(filter);
						ActivateEntity(filter);

						player_data[client].killed_by = attacker;

						HookSingleEntityOutput(filter, "OnPass", OnGatebotFilterPass, true);
						HookSingleEntityOutput(filter, "OnFail", OnGatebotFilterFail, true);
						AcceptEntityInput(filter, "TestActivator", client, attacker);
					}

					if (IsTauntKill(customkill))
					{
						CEcon_SendEventToClientFromGameEvent(attacker, "TF_MVM_KILL_ROBOT_TAUNT", 1, hEvent);
					}

					if(StrContains(weapon_name, "obj_") != -1)
					{
						CEcon_SendEventToClientUnique(attacker, "TF_MVM_KILL_ROBOT_SENTRY", 1);
					}

					if (customkill == 30) // Sentry wrangler damage
					{
						CEcon_SendEventToClientUnique(attacker, "TF_MVM_KILL_ROBOT_SENTRY", 1);
						CEcon_SendEventToClientFromGameEvent(attacker, "TF_MVM_KILL_ROBOT_SENTRY_WRANGLER", 1, hEvent);
					}

					// Razorback detection
					int child = GetEntPropEnt(client, Prop_Data, "m_hMoveChild");

					while (child != -1)
					{
						char classname[32];
						GetEntityClassname(child, classname, 32);

						if (strcmp(classname, "tf_wearable_razorback") == 0)
						{
							CEcon_SendEventToClientFromGameEvent(attacker, "TF_MVM_KILL_ROBOT_RAZORBACK", 1, hEvent);
							break;
						}
						child = GetEntPropEnt(child, Prop_Data, "m_hMovePeer");
					}

					// Half-zatoichi detection
					int active_weapon_robot = GetEntPropEnt(client, Prop_Data, "m_hActiveWeapon");

					if (active_weapon_robot != -1)
					{

						char classname[32];
						GetEntityClassname(active_weapon_robot, classname, 32);
						if (StrEqual(classname, "tf_weapon_katana"))
						{
							CEcon_SendEventToClientFromGameEvent(attacker, "TF_MVM_KILL_ROBOT_ZATOICHI", 1, hEvent);
						}
					}

					int active_weapon_attacker = GetEntPropEnt(attacker, Prop_Data, "m_hActiveWeapon");

					if (active_weapon_attacker != -1 && weapon_damage_last == active_weapon_attacker)
					{
						CEcon_SendEventToClientFromGameEvent(attacker, "TF_MVM_KILL_ROBOT_ACTIVE_WEAPON", 1, hEvent);
					}

					if (TF2_IsPlayerInCondition(attacker, TFCond_CritCola))
					{
						CEcon_SendEventToClientFromGameEvent(attacker, "TF_MVM_KILL_ROBOT_CRIT_COLA", 1, hEvent);
					}


					if (customkill == 1 || customkill == 51) // Headshot, Headshot decapitation
					{
						CEcon_SendEventToClientFromGameEvent(attacker, "TF_MVM_KILL_ROBOT_HEADSHOT", 1, hEvent);
					}
					else
					{
						CEcon_SendEventToClientFromGameEvent(attacker, "TF_MVM_KILL_ROBOT_NOT_HEADSHOT", 1, hEvent);
					}

					switch (customkill)
					{
						case 2: CEcon_SendEventToClientFromGameEvent(attacker, "TF_MVM_KILL_ROBOT_BACKSTAB", 1, hEvent);
						case 21: CEcon_SendEventToClientFromGameEvent(attacker, "TF_MVM_KILL_ROBOT_BASEBALL", 1, hEvent);
						case 34: CEcon_SendEventToClientFromGameEvent(attacker, "TF_MVM_KILL_ROBOT_BLEEDING", 1, hEvent);
					}

					if (StrContains(weapon_name, "deflect") != -1 || StrContains(weapon_name, "reflect") != -1)
					{
						CEcon_SendEventToClientFromGameEvent(attacker, "TF_MVM_KILL_ROBOT_DEFLECT", 1, hEvent);
					}

					if (TF2_IsPlayerInCondition(attacker, TFCond_CritMmmph)) // Baseball hit
					{
						CEcon_SendEventToClientFromGameEvent(attacker, "TF_MVM_KILL_ROBOT_MMMPH", 1, hEvent);
					}

					if (GetEntProp(attacker, Prop_Send, "m_bRageDraining"))
					{
						CEcon_SendEventToClientFromGameEvent(attacker, "TF_MVM_KILL_ROBOT_RAGE", 1, hEvent);
					}

					CEcon_SendEventToClientFromGameEvent(attacker, "TF_MVM_KILL_ROBOT_X_SECONDS_AFTER_SPAWN_LEAVE", leave_spawn_timespan, hEvent);

					if (GetEntProp(attacker, Prop_Send, "m_iRevengeCrits") > 0 && TF2_IsPlayerInCondition(attacker, TFCond_Kritzkrieged) && GetConditionProvider(attacker, TFCond_Kritzkrieged) == -1)
					{
						CEcon_SendEventToClientFromGameEvent(attacker, "TF_MVM_KILL_ROBOT_REVENGE_CRIT", 1, hEvent);

						if (TF2_GetPlayerClass(client) == TFClass_Sniper)
						{
							CEcon_SendEventToClientFromGameEvent(attacker, "TF_MVM_KILL_ROBOT_REVENGE_CRIT_SNIPER", 1, hEvent);
						}
					}

					int heads_add = GetEntProp(attacker, Prop_Send, "m_iDecapitations") - player_hurt_attacker_decap_last;
					if (heads_add > 0)
					{
						CEcon_SendEventToClientFromGameEvent(attacker, "TF_MVM_KILL_ROBOT_HEADS", heads_add, hEvent);
					}



				}
			}

		}
	}
}

public Action controlpoint_starttouch(Handle hEvent, const char[] szName, bool bDontBroadcast)
{
	int player = GetEventInt(hEvent, "player");
	int area = GetEventInt(hEvent, "area");

	player_data[player].touched_cp_area = area;

	return Plugin_Continue;
}

public Action controlpoint_endtouch(Handle hEvent, const char[] szName, bool bDontBroadcast)
{
	int player = GetEventInt(hEvent, "player");
	int area = GetEventInt(hEvent, "area");
	if (player_data[player].touched_cp_area == area)
		player_data[player].touched_cp_area = -1;

	return Plugin_Continue;
}

public void OnGatebotFilterFail(const char[] output, int caller, int activator, float delay)
{
	RemoveEntity(caller);
}

public void OnGatebotFilterPass(const char[] output, int caller, int activator, float delay)
{
	RemoveEntity(caller);
	int killed_by = player_data[activator].killed_by;

	CEcon_SendEventToClientUnique(killed_by, "TF_MVM_KILL_GATEBOT", 1);

	int cp_area = player_data[activator].touched_cp_area;
	if (cp_area != -1 )
	{
		if (IsGiant(activator))
			CEcon_SendEventToClientUnique(killed_by, "TF_MVM_KILL_GATEBOT_GIANT_CAPTURE", 1);

		// count all players if they touch same cp, if its the last one, activate event
		bool found = false;
		for (int i = 1; i <= MaxClients; i++)
		{
			if (i != activator && IsClientValid(i) && IsPlayerAlive(i) && player_data[i].touched_cp_area == cp_area)
			{
				found = true;
				break;
			}
		}

		if (!found)
		{
			int objective_resource = FindEntityByClassname(-1, "tf_objective_resource");
			// If one of the cps have more than 75% progress, activate event
			if (GetEntPropFloat(objective_resource, Prop_Send, "m_flLazyCapPerc", cp_area) < 0.25) {
				CEcon_SendEventToClientUnique(killed_by, "TF_MVM_CLEAR_POINT_GATEBOT", 1);
			}
		}

		player_data[activator].touched_cp_area = -1;
	}
}


public Action mvm_begin_wave(Handle hEvent, const char[] szName, bool bDontBroadcast)
{
	int wave_number = GetEventInt(hEvent, "wave_index");

	if (wave_number == 0)
	{
		for (int i = 1; i <= MaxClients; i++)
		{
			if (IsClientValid(i) && !IsFakeClient(i))
			{
				PlayerDataMission data;
				GetPlayerMissionData(i, data);

				data.wave_finished_counter = 0;

				SetPlayerMissionData(i, data, true);

				ResetDamage(i);
			}
		}
		CEcon_SendEventToAll("TF_MVM_MISSION_BEGIN", 1, GetRandomInt(0, 9999));
	}

	CEcon_SendEventToAll("TF_MVM_WAVE_BEGIN", 1, GetRandomInt(0, 9999));

	bonus_currency_counter = 0;

	// (Safety), reset tank damage here as well.
	for (int i; i < TF_MAXPLAYERS, i++;)
	{
		// Players only.
		if (!IsClientValid(i) || IsFakeClient(i))continue;

		// Reset this players tank damage.
		player_data[i].tank_damage_wave = 0;
	}

	return Plugin_Continue;
}

public Action mvm_wave_failed(Handle hEvent, const char[] szName, bool bDontBroadcast)
{
	int objective_resource = FindEntityByClassname(-1,"tf_objective_resource");
	int wave_number = GetEntProp(objective_resource, Prop_Send,"m_nMannVsMachineWaveCount");

	CEcon_SendEventToAll("TF_MVM_WAVE_FAIL", 1, GetRandomInt(0, 9999));
	CEcon_SendEventToAll("TF_MVM_WAVE_END", 1, GetRandomInt(0, 9999));

	if (wave_number == 1)
	{
		// reset mission data
		if (player_data_mission != null)
		{
			delete player_data_mission;
		}

		player_data_mission = new StringMap();
		for (int i = 1; i <= MaxClients; i++)
		{
			if (IsClientValid(i) && !IsFakeClient(i))
			{
				PlayerDataMission data;
				SetPlayerMissionData(i, data, true);
				player_data[i].Init(i);
			}
		}

		CEcon_SendEventToAll("TF_MVM_MISSION_RESET", 1, GetRandomInt(0, 9999));
	}

	return Plugin_Continue;
}

bool currency_grade_a_scored = false;
public Action mvm_wave_complete(Handle hEvent, const char[] szName, bool bDontBroadcast)
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientValid(i) && !IsFakeClient(i))
		{
			PlayerDataMission data;
			GetPlayerMissionData(i, data);

			data.wave_finished_counter += 1;

			SetPlayerMissionData(i, data, true);
		}
	}
	CEcon_SendEventToAll("TF_MVM_WAVE_COMPLETE", 1, GetRandomInt(0, 9999));
	CEcon_SendEventToAll("TF_MVM_WAVE_END", 1, GetRandomInt(0, 9999));

	int wave_stats = FindEntityByClassname(-1, "tf_mann_vs_machine_stats");

	currency_grade_a_scored = false;

	if (wave_stats != -1)
	{
		int offset_prev_wave = FindSendPropInfo("CMannVsMachineStats", "m_currentWaveStats");
		int prev_dropped = GetEntData(wave_stats, offset_prev_wave + 4,2);
		int prev_collected = GetEntData(wave_stats, offset_prev_wave + 8,2);

		if ( (prev_collected + 0.0) / prev_dropped >= 0.9)
		{
			currency_grade_a_scored = true;
			CEcon_SendEventToAll("TF_MVM_COLLECT_CURRENCY_A", 1, GetRandomInt(0, 9999));
		}
	}

	CheckTopDamage(hEvent);
	/*
	int iTankDamageMVP = -1;
	int iDamageDealt = 0;
	// Award tank MVP for tanks:
	for (int i; i < TF_MAXPLAYERS, i++;)
	{
		// Players only.
		if (!IsClientValid(i))continue;

		// Has this player dealt the most damage?
		if (player_data[i].tank_damage_wave > iDamageDealt && player_data[i].tank_damage_wave > 0)
		{
			iTankDamageMVP = i;
			iDamageDealt = player_data[i].tank_damage_wave;
		}

		// Reset this players tank damage.
		player_data[i].tank_damage_wave = 0;
	}

	//PrintToChatAll("%d", iTankDamageMVP);

	// Send event to the MVP if we have one.
	if (iTankDamageMVP != -1)
	{
		CEcon_SendEventToClientFromGameEvent(iTankDamageMVP, "TF_MVM_DAMAGE_TANK_MVP", 1, hEvent);
	}
	*/

	return Plugin_Continue;
}

// Loop through all valid players and find the player with the most damage
public void CheckTopDamage(Handle tEvent)
{
	int top;
	//int second;
	int damage;
	int topblast;
	int topdmg = 0;
	int topgrenadedmg = 0;
	//char firstname[64], secondname[64];
	for (int player = 1; player <= MaxClients; player++)
	{
		if (IsClientValid(player))
		{
			damage = TankDamage[player];
			int grenadedamage = GrenadeDamage[player];
			if (damage > topdmg)
			{
				top = player;
				topdmg = damage;
			}
			if (grenadedamage > topgrenadedmg)
			{
				topblast = player;
				topgrenadedmg = grenadedamage;
			}
		}
	}
	if (IsClientValid(top))
	{
		CEcon_SendEventToClientFromGameEvent(top, "TF_MVM_DAMAGE_TANK_MVP", 1, tEvent);
		//PrintToChatAll("Top Damage is client: %s", firstname);
		if (HasTopGrenadeDamage(top, topblast))
		{
			topblast = top;
			CEcon_SendEventToClientFromGameEvent(topblast, "TF_MVM_DAMAGE_TANK_MVP_GRENADE", 1, tEvent);

			//Debug
			//PrintToChatAll("top damage player also has top blast damage");
		}
	}
}

public bool HasTopGrenadeDamage(int client, int other)
{
	return client == other;
}

public bool FilterTank(int entity, int contentsMosk, int tank)
{
	return entity != tank;
}

public Action mvm_tank_destroyed_by_players(Handle hEvent, const char[] szName, bool bDontBroadcast)
{
	//Check if one of tanks is a blimp
	bool is_blimp = false;
	for (int i = FindEntityByClassname(-1, "tank_boss"); i != -1; i = FindEntityByClassname(i, "tank_boss"))
	{
		if (GetEntProp(i, Prop_Data, "m_iHealth") > 0)
			continue;

		//char modelstr[128];
		for (int j = 0; j < 4; j++)
		{
			if (GetEntProp(i, Prop_Data, "m_nModelIndex") == blimp_models_precached[j] || GetEntProp(i, Prop_Data, "m_nModelIndexOverrides", 4, 0) == blimp_models_precached[j])
			{
				is_blimp = true;
				break;
			}
		}
	}

	if (!is_blimp)
		CEcon_SendEventToAll("TF_MVM_DESTROY_TANK", 1, GetRandomInt(0, 10000));
	else
		CEcon_SendEventToAll("TF_MVM_DESTROY_TANK_BLIMP", 1, GetRandomInt(0, 10000));


	return Plugin_Continue;
}

void CountVacType(int client, int damage, int crit, TFCond vac_heal_cond, TFCond vac_uber_cond)
{
	float dmg_resisted = 0.0;
	int healer = 0;
	bool has_vac_uber = TF2_IsPlayerInCondition(client, vac_uber_cond);
	bool has_vac_heal = TF2_IsPlayerInCondition(client, vac_heal_cond);

	// Assume regular resist rate
	if (has_vac_uber)
	{
		healer = GetConditionProvider(client, vac_uber_cond);

		dmg_resisted = damage * 3.0;
		if (crit)
		{
			dmg_resisted += damage * 4.0 * 2.0;
		}
	}
	else if (has_vac_heal)
	{
		healer = GetConditionProvider(client, vac_heal_cond);

		dmg_resisted = damage * 0.18;

	}
	// Find vac resist medics
	if (dmg_resisted > 0.0)
	{
		if (healer > 0 && healer != client)
		{
			CEcon_SendEventToClientUnique(healer, "TF_MVM_BLOCK_DAMAGE_VAC", RoundFloat(dmg_resisted));
		}
		CEcon_SendEventToClientUnique(client, "TF_MVM_BLOCK_DAMAGE_VAC", RoundFloat(dmg_resisted));
	}
}
/*
int resist_client_last;
int resist_tick_last;

int player_hurt_client_last;
int player_hurt_weapon_id_last;
//int player_hurt_madmilk_last;
*/
int player_hurt_attacker_last;
int player_hurt_tick_last;
int damage_type_last;
int inflictor_last;
int health_attacker_last;
int victim_last;
public Action player_hurt(Handle hEvent, const char[] szName, bool bDontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(hEvent, "userid"));
	int attacker = GetClientOfUserId(GetEventInt(hEvent, "attacker"));
	int custom = GetEventInt(hEvent, "custom");
	int damage = GetEventInt(hEvent, "damageamount");
	bool crit = GetEventBool(hEvent, "crit");
	bool minicrit = GetEventBool(hEvent, "minicrit");
	int bonuseffect = GetEventInt(hEvent, "bonuseffect");

	/*
	int weaponid = GetEventInt(hEvent, "weaponid");
	player_hurt_client_last = client;
	player_hurt_attacker_last = attacker;
	player_hurt_weapon_id_last = weaponid;
	player_hurt_tick_last = GetGameTickCount();
	*/
	if (IsClientValid(attacker) && attacker != client)
	{
		if (IsFakeClient(client) && !IsFakeClient(attacker))
		{
			player_hurt_attacker_decap_last = GetEntProp(attacker, Prop_Send, "m_iDecapitations");

			// Add to hit tracker;
			player_data[client].hit_tracker |= 1 << (attacker - 1);

			// Don't include overkill damage
			if (GetEntProp(client, Prop_Data, "m_iHealth") < 0)
				damage += GetEntProp(client, Prop_Data, "m_iHealth");

			CEcon_SendEventToClientFromGameEvent(attacker, "TF_MVM_DAMAGE_ROBOT", damage, hEvent);

			if (custom == 30) // Sentry wrangler damage
			{
				CEcon_SendEventToClientFromGameEvent(attacker, "TF_MVM_DAMAGE_ROBOT_SENTRY_WRANGLER", damage, hEvent);
			}

			if (inflictor_last > 0 && inflictor_last != attacker && IsValidEntity(inflictor_last))
			{
				char classname[32];
				GetEntityClassname(inflictor_last, classname, sizeof(classname));
				if (strcmp(classname, "obj_sentrygun") == 0 || strcmp(classname, "tf_projectile_sentryrocket") == 0)
				{
					CEcon_SendEventToClientFromGameEvent(attacker, "TF_MVM_DAMAGE_ROBOT_SENTRY", damage, hEvent);
				}
			}

			int active_weapon_attacker = GetEntPropEnt(attacker, Prop_Data, "m_hActiveWeapon");
			if (active_weapon_attacker != -1 && weapon_damage_last == active_weapon_attacker)
			{
				CEcon_SendEventToClientFromGameEvent(attacker, "TF_MVM_DAMAGE_ROBOT_ACTIVE_WEAPON", damage, hEvent);
			}

			if (custom == 45) // Boot / Jetpack Stomp
			{
				if (IsGiantNotBuster(client))
				{
					CEcon_SendEventToClientFromGameEvent(attacker, "TF_MVM_STOMP_ROBOT_GIANT", 1, hEvent);
					CEcon_SendEventToClientFromGameEvent(attacker, "TF_MVM_STOMP_ROBOT_GIANT_DAMAGE", damage, hEvent);
				}
			}

			if (minicrit && TF2_IsPlayerInCondition(attacker, TFCond_Buffed))
			{
				int buff_provider = GetConditionProvider(attacker, TFCond_Buffed);
				if (IsClientValid(buff_provider))
				{
					CEcon_SendEventToClientFromGameEvent(buff_provider, "TF_MVM_DAMAGE_ASSIST_BUFF", damage, hEvent);
				}
			}

			if (crit)
			{
				CEcon_SendEventToClientFromGameEvent(attacker, "TF_MVM_DAMAGE_ROBOT_CRIT_FULL", damage, hEvent);
			}
			else if(minicrit)
			{
				CEcon_SendEventToClientFromGameEvent(attacker, "TF_MVM_DAMAGE_ROBOT_CRIT_MINI", damage, hEvent);
			}
			else
			{
				CEcon_SendEventToClientFromGameEvent(attacker, "TF_MVM_DAMAGE_ROBOT_CRIT_NONE", damage, hEvent);
			}

			if (bonuseffect == 2) // Double donk
			{
				CEcon_SendEventToClientFromGameEvent(attacker, "TF_MVM_DAMAGE_ROBOT_DOUBLE_DONK", 1, hEvent);
			}

			if (TF2_IsPlayerInCondition(attacker, TFCond_Kritzkrieged))
			{
				int crits_provider = GetConditionProvider(attacker, TFCond_Kritzkrieged);
				if (IsClientValid(crits_provider))
				{
					CEcon_SendEventToClientFromGameEvent(crits_provider, "TF_MVM_DAMAGE_ASSIST_KRITZKRIEG", damage, hEvent);
				}
			}
			player_data[attacker].damage_dealt_counter += damage;
		}
		else if (IsFakeClient(attacker))
		{
			if (damage_type_last & (DMG_BURN | DMG_IGNITE))
			{
				CountVacType(client, damage, crit, TFCond_SmallFireResist, TFCond_UberFireResist);
			}
			if (damage_type_last & (DMG_BLAST))
			{
				CountVacType(client, damage, crit, TFCond_SmallBlastResist, TFCond_UberBlastResist);
			}
			if (damage_type_last & (DMG_BULLET | DMG_BUCKSHOT))
			{
				CountVacType(client, damage, crit, TFCond_SmallBulletResist, TFCond_UberBulletResist);
			}
		}

	}


	// Battalions backup check
	if (IsClientValid(attacker) && IsFakeClient(attacker) && !IsFakeClient(client))
	{


		if (TF2_IsPlayerInCondition(client, TFCond_DefenseBuffed))
		{
			// Find buff provider
			int buff_provider = GetConditionProvider(client, TFCond_DefenseBuffed);

			if (IsClientValid(buff_provider))
			{
				CEcon_SendEventToClientUnique(buff_provider, "TF_MVM_BLOCK_DAMAGE_BATTALION_BACKUP", RoundFloat(damage * 1.50));
			}
		}
		if (GetEntProp(client, Prop_Send, "m_bFeignDeathReady") > 0 && GetEntProp(client, Prop_Data, "m_iHealth") + damage / 4 - damage < 0)
		{
			CEcon_SendEventToClientFromGameEvent(client, "TF_MVM_BLOCK_DAMAGE_NEAR_DEATH_DEAD_RINGER", 1, hEvent);
		}
	}

	return Plugin_Continue;
}

public Action damage_resisted(Handle hEvent, const char[] szName, bool bDontBroadcast)
{
	//resist_client_last = GetEventInt(hEvent, "entindex");
	//resist_tick_last = GetGameTickCount();
}

int damagecustom_last;
public Action OnPlayerDamage(int victim, int& attacker, int& inflictor, float& damage, int& damagetype, int& weapon, float damageForce[3], float damagePosition[3], int damagecustom)
{
	victim_last = victim;
	if (IsClientValid(attacker))
		health_attacker_last = GetEntProp(attacker, Prop_Data, "m_iHealth");

	damage_type_last = damagetype;
	weapon_damage_last = weapon;
	damagecustom_last = damagecustom;
	inflictor_last = inflictor;
}

public void OnPlayerDamagePost(int victim, int attacker, int inflictor, float damage, int damagetype)
{
	health_attacker_last = 0;
	victim_last = -1;
	if (IsClientValid(attacker) && attacker != victim && GetClientTeam(attacker) != GetClientTeam(victim) )
	{
		if (TF2_IsPlayerInCondition(victim, TFCond_Ubercharged) && damagecustom_last != 2) // backstab
		{
			// Multiply crit damage
			if ((damagetype & DMG_CRIT) == DMG_CRIT)
			{
				damage *= 3.0;
			}

			// Find ubercharged medic

			int healer = GetConditionProvider(victim, TFCond_Ubercharged);

			if (IsClientValid(healer))
			{
				bool valid = healer != victim;

				// Count damage absorbed by medic if he is healing someone
				if (!valid)
				{
					int medigun = GetPlayerWeaponSlot(healer, 1);
					if (medigun != -1)
					{
						char classname[32];
						GetEntityClassname(medigun, classname, sizeof(classname));
						if (strcmp(classname, "tf_weapon_medigun") == 0)
						{
							int target = GetEntPropEnt(medigun, Prop_Send, "m_hHealingTarget");
							valid = target > 0;
						}
					}
				}

				if (valid)
				{
					CEcon_SendEventToClientUnique(healer, "TF_MVM_BLOCK_DAMAGE_UBER", RoundFloat(damage));
				}
			}
		}
	}

}

public Action player_ignited(Handle hEvent, const char[] szName, bool bDontBroadcast)
{
	int client = GetEventInt(hEvent, "victim_entindex");
	int attacker = GetEventInt(hEvent, "pyro_entindex");

	player_data[client].ignited_by = attacker;

	if (IsClientValid(attacker) && attacker != client && IsFakeClient(client))
	{
		CEcon_SendEventToClientFromGameEvent(attacker, "TF_MVM_IGNITE_ROBOT", 1, hEvent);
	}

	return Plugin_Continue;
}

public int TF2_GetMaxHealth(int iClient)
{
    return GetEntProp(iClient, Prop_Data, "m_iMaxHealth");
}


public Action player_healed(Handle hEvent, const char[] szName, bool bDontBroadcast)
{
	int patient = GetClientOfUserId(GetEventInt(hEvent, "patient"));
	int healer = GetClientOfUserId(GetEventInt(hEvent, "healer"));
	int amount = GetEventInt(hEvent, "amount");

	if (IsClientValid(healer) && healer != patient)
	{
		if (!IsFakeClient(healer))
		{
			if (IsFakeClient(patient))
			{
				CEcon_SendEventToClientFromGameEvent(healer, "TF_MVM_HEALING_ROBOTS", amount, hEvent);
			}
			else
			{
				if (health_attacker_last != 0 && TF2_IsPlayerInCondition(victim_last, TFCond_Milked)) {
					// Removed as people believed the healing counts even if the healed player is at max health (as green damage indicator mistakenly shows)
					// if (amount > GetEntProp(patient, Prop_Data, "m_iMaxHealth") - GetEntProp(patient, Prop_Data, "m_iHealth"))
					// {
					// 	amount = GetEntProp(patient, Prop_Data, "m_iMaxHealth") - GetEntProp(patient, Prop_Data, "m_iHealth");
					// }
					CEcon_SendEventToClientFromGameEvent(healer, "TF_MVM_HEALING_MADMILK", amount, hEvent);
				}

				// Is the patient being overhealed?
				if (!(GetClientHealth(patient) > TF2_GetMaxHealth(patient)))
				{
					CEcon_SendEventToClientFromGameEvent(healer, "TF_MVM_HEALING_TEAMMATES_NO_OVERHEAL", amount, hEvent);
				}
				CEcon_SendEventToClientFromGameEvent(healer, "TF_MVM_HEALING_TEAMMATES", amount, hEvent);
			}

		}
	}

	return Plugin_Continue;
}

public Action player_healonhit(Handle hEvent, const char[] szName, bool bDontBroadcast)
{
	int client = GetEventInt(hEvent, "entindex");
	int amount = GetEventInt(hEvent, "amount");

	int weapon_def_index = GetEventInt(hEvent, "weapon_def_index");
	int health_before = GetEntProp(client, Prop_Data, "m_iHealth") - amount;

	if (player_death_attacker_last == client && player_death_damage_custom_last == 2 && player_death_tick_last == GetGameTickCount())
	{
		CEcon_SendEventToClientFromGameEvent(client, "TF_MVM_HEALING_KUNAI", amount, hEvent);

		if (health_before < 35)
		{
			CEcon_SendEventToClientFromGameEvent(client, "TF_MVM_HEALING_KUNAI_NEAR_DEATH", 1, hEvent);
		}
	}

	if (weapon_def_index != 65535 && player_hurt_attacker_last == client && player_hurt_tick_last == GetGameTickCount())
	{
		if (TF2_IsPlayerInCondition(client, TFCond_RegenBuffed) && IsClientValid(GetConditionProvider(client, TFCond_RegenBuffed)))
		{
			// Removed as people believed the healing counts even if the healed player is at max health (as green damage indicator mistakenly shows)
			// if (health_attacker_last != 0 && amount > GetEntProp(client, Prop_Data, "m_iHealth") - health_attacker_last) {
			// 	amount = GetEntProp(client, Prop_Data, "m_iHealth") - health_attacker_last;
			// }
			CEcon_SendEventToClientFromGameEvent(GetConditionProvider(client, TFCond_RegenBuffed), "TF_MVM_HEALING_CONCHEROR", amount, hEvent);
		}
		CEcon_SendEventToClientFromGameEvent(client, "TF_MVM_HEALING_ON_HIT", amount, hEvent);
	}
}

public Action mvm_medic_powerup_shared(Handle hEvent, const char[] szName, bool bDontBroadcast)
{
	int client = GetEventInt(hEvent, "player");

	int medigun = GetPlayerWeaponSlot(client, 1);

	if (medigun != -1)
	{
		int target = GetEntPropEnt(medigun, Prop_Send, "m_hHealingTarget");
		if (IsClientValid(target) && IsFakeClient(target))
		{
			CEcon_SendEventToClientFromGameEvent(client, "TF_MVM_CANTEEN_SHARE_ROBOT", 1, hEvent);
		}
		CEcon_SendEventToClientFromGameEvent(client, "TF_MVM_CANTEEN_SHARE", 1, hEvent);
	}

}

public Action player_chargedeployed(Handle hEvent, const char[] szName, bool bDontBroadcast)
{
	int patient = GetClientOfUserId(GetEventInt(hEvent, "targetid"));
	int healer = GetClientOfUserId(GetEventInt(hEvent, "userid"));

	if (IsClientValid(patient) && IsFakeClient(patient))
	{
		CEcon_SendEventToClientFromGameEvent(healer, "TF_MVM_UBER_DEPLOY_ROBOT", 1, hEvent);
	}

	CEcon_SendEventToClientFromGameEvent(healer, "TF_MVM_UBER_DEPLOY", 1, hEvent);

	if (GetEntProp(healer, Prop_Data, "m_iHealth") < 50)
	{
		CEcon_SendEventToClientFromGameEvent(healer, "TF_MVM_UBER_DEPLOY_NEAR_DEATH", 1, hEvent);
	}
}

public Action revive_player_complete(Handle hEvent, const char[] szName, bool bDontBroadcast)
{
	int client = GetEventInt(hEvent, "entindex");

	CEcon_SendEventToClientFromGameEvent(client, "TF_MVM_REVIVE", 1, hEvent);
}

public Action medigun_shield_blocked_damage(Handle hEvent, const char[] szName, bool bDontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(hEvent, "userid"));
	int damage = GetEventInt(hEvent, "damage");

	CEcon_SendEventToClientFromGameEvent(client, "TF_MVM_BLOCK_DAMAGE_SHIELD", damage, hEvent);
}

public Action medic_death(Handle hEvent, const char[] szName, bool bDontBroadcast)
{
	int healer = GetClientOfUserId(GetEventInt(hEvent, "userid"));
	int attacker = GetClientOfUserId(GetEventInt(hEvent, "attacker"));
	bool charged = GetEventBool(hEvent, "charged");

	// Only count regular uber
	bool charged_uber = charged && GetAttributeValue(healer, "set_charge_type", 0.0) == 0.0;


	if (charged_uber && IsClientValid(healer) && IsFakeClient(healer))
	{
		CEcon_SendEventToClientFromGameEvent(attacker, "TF_MVM_KILL_UBER_MEDIC", 1, hEvent);

		if (IsGiant(healer))
			CEcon_SendEventToClientFromGameEvent(attacker, "TF_MVM_KILL_GIANT_UBER_MEDIC", 1, hEvent);

		int active_weapon_attacker = GetEntPropEnt(attacker, Prop_Data, "m_hActiveWeapon");
		if (active_weapon_attacker != -1 && weapon_damage_last == active_weapon_attacker)
		{
			CEcon_SendEventToClientFromGameEvent(attacker, "TF_MVM_KILL_UBER_MEDIC_ACTIVE_WEAPON", 1, hEvent);
		}
	}

	return Plugin_Continue;
}


public Action mvm_pickup_currency(Handle hEvent, const char[] szName, bool bDontBroadcast)
{
	int client = GetEventInt(hEvent, "player");
	int currency = GetEventInt(hEvent, "currency");

	CEcon_SendEventToClientFromGameEvent(client, "TF_MVM_COLLECT_CURRENCY", currency, hEvent);
	CEcon_SendEventToAll("TF_MVM_COLLECT_CURRENCY_ALL_PLAYERS", currency, GetRandomInt(0, 9999));

	if (!currency_grade_a_scored && GameRules_GetRoundState() != RoundState_RoundRunning)
	{
		int wave_stats = FindEntityByClassname(-1,"tf_mann_vs_machine_stats");
		if (wave_stats != -1)
		{
			int offset_prev_wave = FindSendPropInfo("CMannVsMachineStats", "m_previousWaveStats");
			int prev_dropped = GetEntData(wave_stats, offset_prev_wave + 4,2);
			int prev_collected = GetEntData(wave_stats, offset_prev_wave + 8,2) + currency;

			if ( (prev_collected + 0.0) / prev_dropped >= 0.9)
			{
				currency_grade_a_scored = true;
				CEcon_SendEventToAll("TF_MVM_COLLECT_CURRENCY_A", 1, GetRandomInt(0, 9999));
			}
		}
	}

	return Plugin_Continue;
}

public Action mvm_creditbonus_wave(Handle hEvent, const char[] szName, bool bDontBroadcast)
{
	bonus_currency_counter++;

	if (bonus_currency_counter == 1)
	{
		CEcon_SendEventToAll("TF_MVM_COLLECT_CURRENCY_BONUS", 1, GetRandomInt(0, 9999));
	}
	else if (bonus_currency_counter == 2)
	{
		CEcon_SendEventToAll("TF_MVM_COLLECT_CURRENCY_BONUS_ALL", 1, GetRandomInt(0, 9999));
	}

	return Plugin_Continue;
}

public Action mvm_sentrybuster_detonate(Handle hEvent, const char[] szName, bool bDontBroadcast)
{

	int target = GetEventInt(hEvent, "player");

	for (int i = -1 ; (i = FindEntityByClassname(i, "obj_sentrygun")) != -1;)
	{
		if (GetEntProp(i, Prop_Data, "m_iHealth") > 0 && GetEntPropEnt(i, Prop_Send, "m_hBuilder") == target)
		{
			CEcon_SendEventToClientFromGameEvent(target, "TF_MVM_SAVE_SENTRY", 1, hEvent);

			if (player_data[target].buster_save_sentry_ranged)
			{
				CEcon_SendEventToClientFromGameEvent(target, "TF_MVM_SAVE_SENTRY_RESCUE", 1, hEvent);
			}
		}
	}
	return Plugin_Continue;
}

public Action player_carryobject(Handle hEvent, const char[] szName, bool bDontBroadcast)
{

	int builder = GetClientOfUserId(GetEventInt(hEvent, "userid"));
	int type = GetEventInt(hEvent, "object");
	//int entity = GetEventInt(hEvent, "index");
	if (type == 2) //OBJ_SENTRYGUN
	{
		player_data[builder].buster_save_sentry_ranged = GetAttributeValue(GetEntPropEnt(builder, Prop_Data, "m_hActiveWeapon"), "building_teleporting_pickup", 0.0) != 0.0;

	}

	return Plugin_Continue;
}

public Action player_stunned(Handle hEvent, const char[] szName, bool bDontBroadcast)
{
	int stunner = GetClientOfUserId(GetEventInt(hEvent, "stunner"));
	int victim = GetClientOfUserId(GetEventInt(hEvent, "victim"));
	bool capping = GetEventBool(hEvent, "victim_capping");
	bool big_stun = GetEventBool(hEvent, "big_stun");


	if (stunner == 0)
	{
		float vecvictim[3];
		GetEntPropVector(victim, Prop_Send, "m_vecOrigin", vecvictim);

		// Search for rocket pack pyros nearbly
		for (int i = 1; i <= MaxClients; i++)
		{
			if (IsClientValid(i) && !IsFakeClient(i) && GetClientTeam(i) != GetClientTeam(victim) && TF2_IsPlayerInCondition(i, TFCond_RocketPack))
			{

				float vecpyro[3];
				GetEntPropVector(i, Prop_Send, "m_vecOrigin", vecpyro);

				if (GetVectorDistance(vecvictim, vecpyro, true) < 500.0 * 500.0)
				{
					stunner = i;
					CEcon_SendEventToClientFromGameEvent(stunner, "TF_MVM_STUN_ROBOT_WITH_JETPACK", 1, hEvent);

					if (TF2_GetPlayerClass(victim) == TFClass_Medic)
					{
						CEcon_SendEventToClientFromGameEvent(stunner, "TF_MVM_STUN_ROBOT_MEDIC_WITH_JETPACK", 1, hEvent);
					}
				}
				break;
			}
		}
	}

	if (IsClientValid(stunner) && IsFakeClient(victim) && !IsFakeClient(stunner))
	{
		CEcon_SendEventToClientFromGameEvent(stunner, "TF_MVM_STUN_ROBOT", 1, hEvent);

		if (IsGiantNotBuster(victim))
		{
			CEcon_SendEventToClientFromGameEvent(stunner, "TF_MVM_STUN_ROBOT_GIANT", 1, hEvent);
		}

		if (capping)
		{
			CEcon_SendEventToClientFromGameEvent(stunner, "TF_MVM_STUN_ROBOT_CAPPING", 1, hEvent);
		}

		if (big_stun)
		{
			CEcon_SendEventToClientFromGameEvent(stunner, "TF_MVM_STUN_ROBOT_MOONSHOT", 1, hEvent);
		}

		if (GetEntPropEnt(victim, Prop_Send, "m_hItem") != -1)
		{
			CEcon_SendEventToClientFromGameEvent(stunner, "TF_MVM_STUN_ROBOT_BOMB_CARRIER", 1, hEvent);
		}
	}

	return Plugin_Continue;
}

public Action deploy_buff_banner(Handle hEvent, const char[] szName, bool bDontBroadcast)
{
	int buff_type = GetEventInt(hEvent, "buff_type");
	int buff_owner = GetClientOfUserId(GetEventInt(hEvent, "buff_owner"));

	CEcon_SendEventToClientFromGameEvent(buff_owner, "TF_MVM_BUFF_ACTIVATE", 1, hEvent);

	switch (buff_type)
	{
		case 1: CEcon_SendEventToClientFromGameEvent(buff_owner, "TF_MVM_BUFF_BANNER_ACTIVATE", 1, hEvent);
		case 2: CEcon_SendEventToClientFromGameEvent(buff_owner, "TF_MVM_BATTALION_BACKUP_ACTIVATE", 1, hEvent);
		case 3: CEcon_SendEventToClientFromGameEvent(buff_owner, "TF_MVM_CONCHEROR_ACTIVATE", 1, hEvent);
	}
}

public Action mvm_bomb_reset_by_player(Handle hEvent, const char[] szName, bool bDontBroadcast)
{
	int player = GetEventInt(hEvent, "player");

	CEcon_SendEventToClientFromGameEvent(player, "TF_MVM_BOMB_RESET", 1, hEvent);
}

public Action mvm_bomb_deploy_reset_by_player(Handle hEvent, const char[] szName, bool bDontBroadcast)
{
	int player = GetEventInt(hEvent, "player");

	CEcon_SendEventToClientFromGameEvent(player, "TF_MVM_BOMB_DEPLOY_RESET", 1, hEvent);
}

public Action player_extinguished(Handle hEvent, const char[] szName, bool bDontBroadcast)
{
	int victim = GetEventInt(hEvent, "victim");
	int healer = GetEventInt(hEvent, "healer");

	// The effect is already gone so you cant tell who ignited, so have to use a different way
	if (GameRules_GetRoundState() == RoundState_RoundRunning && player_data[victim].ignited_by != victim && IsClientValid(player_data[victim].ignited_by))
	{
		CEcon_SendEventToClientFromGameEvent(healer, "TF_MVM_EXTINGUISH", 1, hEvent);
	}
}

public Action mvm_bomb_carrier_killed(Handle hEvent, const char[] szName, bool bDontBroadcast)
{

}

public Action teamplay_flag_event(Handle hEvent, const char[] szName, bool bDontBroadcast)
{
	int type = GetEventInt(hEvent, "eventtype");
	int player = GetEventInt(hEvent, "player");
	int carrier = GetEventInt(hEvent, "carrier");

	if (type == 1 && IsFakeClient(player)) // Pickup
	{
		player_data[player].pick_bomb_time = GetGameTime();
	}

	if (type == 3 && IsFakeClient(carrier)) // Defend
	{

		if (IsSentryBuster(player) && GetClientTeam(player) == GetClientTeam(carrier))
		{
			CEcon_SendEventToAll("TF_MVM_SENTRY_BUSTER_KILL_BOMB_CARRIER", 1, GetRandomInt(0, 9999));
		}

		CEcon_SendEventToClientFromGameEvent(player, "TF_MVM_KILL_ROBOT_BOMB_CARRIER", 1, hEvent);

		float carry_time = GetGameTime() - player_data[carrier].pick_bomb_time;

		if (carry_time >= 0.0)
		{
			CEcon_SendEventToClientFromGameEvent(player, "TF_MVM_KILL_ROBOT_BOMB_CARRIER_X_SECONDS_AFTER_PICKUP", RoundToCeil(carry_time), hEvent);
		}
	}
}

public Action player_used_powerup_bottle(Handle hEvent, const char[] szName, bool bDontBroadcast)
{
	int player = GetEventInt(hEvent, "player");
	int type = GetEventInt(hEvent, "type");

	CEcon_SendEventToClientFromGameEvent(player, "TF_MVM_CANTEEN", 1, hEvent);

	switch (type)
	{
		case 1: CEcon_SendEventToClientFromGameEvent(player, "TF_MVM_CANTEEN_CRIT", 1, hEvent);
		case 2: CEcon_SendEventToClientFromGameEvent(player, "TF_MVM_CANTEEN_UBER", 1, hEvent);
		case 3: CEcon_SendEventToClientFromGameEvent(player, "TF_MVM_CANTEEN_RECALL", 1, hEvent);
		case 4: CEcon_SendEventToClientFromGameEvent(player, "TF_MVM_CANTEEN_AMMO", 1, hEvent);
		case 5: CEcon_SendEventToClientFromGameEvent(player, "TF_MVM_CANTEEN_BUILDING_UPGRADE", 1, hEvent);
	}
}

public Action building_healed(Handle hEvent, const char[] szName, bool bDontBroadcast)
{
	int healer = GetEventInt(hEvent, "healer");
	int amount = GetEventInt(hEvent, "amount");
	//int building = GetEventInt(hEvent, "building");

	CEcon_SendEventToClientFromGameEvent(healer, "TF_MVM_REPAIR", amount, hEvent);
}

public void TF2_OnConditionAdded(int client, TFCond cond)
{

	switch(cond)
	{
		case TFCond_Milked:
		{
			int entity = GetConditionProvider(client, cond);
			if (IsClientValid(entity) && !IsFakeClient(entity) && IsFakeClient(client))
			{
				CEcon_SendEventToClientUnique(entity, "TF_MVM_MADMILK_ROBOT", 1);

				if (IsGiantNotBuster(client))
				{
					CEcon_SendEventToClientUnique(entity, "TF_MVM_MADMILK_ROBOT_GIANT", 1);

					if (TF2_IsPlayerInCondition(client, TFCond_MarkedForDeath))
					{
						CEcon_SendEventToClientUnique(entity, "TF_MVM_MADMILK_MARK_ROBOT_GIANT", 1);
					}
				}

				// Snare upgrade detection

				if (GetAttributeValue(entity, "applies_snare_effect", 1.0) != 1.0)
				{
					CEcon_SendEventToClientUnique(entity, "TF_MVM_STUN_ROBOT_JAR", 1);
					if (IsGiantNotBuster(client) && TF2_GetPlayerClass(client) == TFClass_Scout)
					{
						CEcon_SendEventToClientUnique(entity, "TF_MVM_STUN_ROBOT_JAR_GIANT_SCOUT", 1);
					}
				}
			}
		}
		case TFCond_Jarated:
		{
			int entity = GetConditionProvider(client, cond);

			if (IsClientValid(entity) && !IsFakeClient(entity) && IsFakeClient(client))
			{
				int iJar = GetPlayerWeaponSlot(entity, 1);

				// Snare upgrade detection
				if (GetAttributeValue(iJar, "applies_snare_effect", 1.0) != 1.0)
				{
					CEcon_SendEventToClientUnique(entity, "TF_MVM_STUN_ROBOT_JAR", 1);
					if (IsGiantNotBuster(client) && TF2_GetPlayerClass(client) == TFClass_Scout)
					{
						CEcon_SendEventToClientUnique(entity, "TF_MVM_STUN_ROBOT_JAR_GIANT_SCOUT", 1);
					}
				}
			}
		}
		case TFCond_MarkedForDeath:
		{
			int entity = GetConditionProvider(client, cond);
			if (IsClientValid(entity) && !IsFakeClient(entity) && IsFakeClient(client))
			{
				CEcon_SendEventToClientUnique(entity, "TF_MVM_MARK_FOR_DEATH_ROBOT", 1);

				if (IsGiantNotBuster(client))
				{
					CEcon_SendEventToClientUnique(entity, "TF_MVM_MARK_FOR_DEATH_ROBOT_GIANT", 1);

					if (TF2_IsPlayerInCondition(client, TFCond_Milked))
					{
						CEcon_SendEventToClientUnique(entity, "TF_MVM_MADMILK_MARK_ROBOT_GIANT", 1);
					}
				}
			}
		}
		case TFCond_CritOnKill:
		{

		}
		case TFCond_Sapped:
		{
			int entity = GetConditionProvider(client, cond);
			if (IsClientValid(entity) && !IsFakeClient(entity) && IsFakeClient(client))
			{
				CEcon_SendEventToClientUnique(entity, "TF_MVM_SAP_ROBOT", 1);
			}
		}
	}
}

public void TF2_OnConditionRemoved(int client, TFCond cond)
{
	switch(cond)
	{
		case TFCond_CritOnKill:
		{
			CEcon_SendEventToClientUnique(client, "TF_MVM_CRITBOOST_ON_KILL_STOP", 1);
		}

		case TFCond_OnFire:
		{
			int ignited_by = player_data[client].ignited_by;
			if (ignited_by != client && IsFakeClient(client) && IsClientValid(ignited_by))
			{
				CEcon_SendEventToClientUnique(player_data[client].ignited_by, "TF_MVM_IGNITE_STOP_ROBOT", 1);
			}
			player_data[client].ignited_by = 0;
		}
		case TFCond_UberchargedHidden:
		{
			player_data[client].leave_spawn_time = GetGameTime();
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

public bool IsSentryBuster(int client)
{

	char model[256];
	GetEntPropString(client, Prop_Send, "m_iszCustomModel", model, sizeof(model));

	bool buster_model = strcmp(model, "models/bots/demo/bot_sentry_buster.mdl") == 0;

	return buster_model;
}

public bool IsGiant(int client)
{
	return GetEntProp(client, Prop_Send, "m_bIsMiniBoss") != 0;
}

public bool IsGiantNotBuster(int client)
{
	return IsGiant(client) && !IsSentryBuster(client);
}

public bool IsBoss(int client)
{
	return GetEntProp(client, Prop_Send, "m_bUseBossHealthBar") != 0;
}

public void GetTFClassName(TFClassType class, char[] buf, int len)
{
	switch (class)
	{
		case TFClass_Scout: strcopy(buf, len, "SCOUT");
		case TFClass_Soldier: strcopy(buf, len, "SOLDIER");
		case TFClass_Pyro: strcopy(buf, len, "PYRO");
		case TFClass_DemoMan: strcopy(buf, len, "DEMOMAN");
		case TFClass_Heavy: strcopy(buf, len, "HEAVY");
		case TFClass_Engineer: strcopy(buf, len, "ENGINEER");
		case TFClass_Medic: strcopy(buf, len, "MEDIC");
		case TFClass_Sniper: strcopy(buf, len, "SNIPER");
		case TFClass_Spy: strcopy(buf, len, "SPY");
	}
}

public bool IsTauntKill(int damageTypeCustom)
{
	switch (damageTypeCustom)
	{
		case 7: return true;
		case 9: return true;
		case 10: return true;
		case 13: return true;
		case 15: return true;
		case 21: return true;
		case 24: return true;
		case 29: return true;
		case 33: return true;
		case 52: return true;
		case 53: return true;
		case 63: return true;
		case 82: return true;
	}
	return false;
}

public int GetConditionProvider(int client, TFCond cond)
{
	if (!IsClientValid(client) || get_condition_provider_handle == null)
	{
		return -1;
	}

	int shared = FindSendPropInfo("CTFPlayer", "m_Shared");
	int entity = SDKCall(get_condition_provider_handle, GetEntityAddress(client) + view_as<Address>(shared), view_as<int>(cond));
	return entity;

}

public float GetAttributeValue(int entity, char[] attribute, float inValue)
{
	//if (attrib_float_handle == null)
	//{
	//	LogMessage("Null");
	//	return inValue;
	//}
	//return SDKCall(attrib_float_handle, inValue, attribute, entity, 0, false);

	return TF2Attrib_HookValueFloat(inValue, attribute,entity);
}

public bool HasFullUberOfType(int client, int type)
{
	int medigun = GetPlayerWeaponSlot(client, 1);
	if (medigun != -1)
	{
		char classname[32];
		GetEntityClassname(medigun, classname, sizeof(classname));
		if (strcmp(classname, "tf_weapon_medigun") == 0 && GetEntProp(medigun, Prop_Send, "m_flChargeLevel") >= 1.0)
		{
			return type == -1 || RoundFloat(GetAttributeValue(medigun, "set_charge_type", 0.0)) == type;
		}
	}
	return false;
}

public void GetPlayerMissionData(int client, PlayerDataMission data)
{
	if (player_data_mission == null)
		return;

	int steam_id = GetSteamAccountID(client);
	char steam_id_str[16];

	IntToString(steam_id, steam_id_str, sizeof(steam_id_str));

	player_data_mission.GetArray(steam_id_str, data, sizeof(data));
}

public void SetPlayerMissionData(int client, PlayerDataMission data, bool replace)
{
	if (player_data_mission == null)
		return;

	int steam_id = GetSteamAccountID(client);
	char steam_id_str[16];

	IntToString(steam_id, steam_id_str, sizeof(steam_id_str));

	player_data_mission.SetArray(steam_id_str, data, sizeof(data), replace);
}
