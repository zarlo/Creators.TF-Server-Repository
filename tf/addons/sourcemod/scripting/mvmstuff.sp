#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <profiler>
#include <nativevotes>
#include <tf2>
#include <tf2_stocks>
#include <tf2items>
#include <tf2attributes>
#include <SteamWorks>

#define TF_DMG_MELEE                        (1 << 27) | (1 << 12) | (1 << 7)

public Plugin myinfo =
{
	name = "MvM stuff",
	author = "rafradek",
	description = "Changes to the Mann vs. Machine Gamemode",
	version = SOURCEMOD_VERSION,
	url = "http://www.sourcemod.net/"
};

ConVar caber_buff_enabled;
ConVar eoi_nerf_enabled;
ConVar medic_shield_nerf_enabled;
ConVar vote_em_enabled;
ConVar vote_10mvm_enabled;
ConVar super_shotgun_enabled;
ConVar radius_sleeper_enabled;
//ConVar old_panic_attack_enabled;
ConVar write_wave_time_enabled;

float wave_times[64];
bool wave_passed[64];
float wave_start_time = 0.0;
float waves_total_time = 0.0;
int last_wave_number = 0;
int fail_counter_tick = 0; //if increases 4 times in a singe tick, mission is restarted;

Handle wave_time_timer = null;
Handle reset_mission_timer = null;
bool firstrestart = false;

bool extramodded_set = false;
bool mvm10_set = false;
bool super_fire_fan[MAXPLAYERS];
bool vanilla_mode;
Handle burn_prep;

StringMap whitelisted_afterburn_items;

public void OnPluginStart()
{
	LoadTranslations("common.phrases");

	caber_buff_enabled = CreateConVar("sm_caber_buff", "1", "enable caber buff");
	eoi_nerf_enabled = CreateConVar("sm_eoi_nerf", "1", "enable eoi nerf");
	medic_shield_nerf_enabled = CreateConVar("sm_medic_shield_nerf", "0.75", "shield duration multiplier");
	vote_em_enabled = CreateConVar("sm_vote_em_nerf", "1", "enable vote for extra modded upgrades");
	vote_10mvm_enabled = CreateConVar("sm_vote_10mvm", "1", "enable vote for 10 max players");
	super_shotgun_enabled = CreateConVar("sm_super_shotgun", "1", "fan super shotgun");
	radius_sleeper_enabled = CreateConVar("sm_radius_sleeper", "1", "radius sydney sleeper jarate");
	//old_panic_attack_enabled = CreateConVar("sm_old_panic_attack", "1", "old panic attack");
	write_wave_time_enabled = CreateConVar("sm_write_wave_time", "1", "write wave time in client chat");


	ConVar sig_vanilla_mode = FindConVar("sig_vanilla_mode");
	if (sig_vanilla_mode != null)
	{
		HookConVarChange(sig_vanilla_mode, VanillaModeChanged);
	}
	
	RegConsoleCmd("sm_wave_time", Command_WaveTime, "Shows times for all waves in the mission");
	RegConsoleCmd("sm_fuck_go_back", Command_RestartGame, "Restart game");
	RegConsoleCmd("sm_wave_summary", Command_WaveTime, "Shows times for all waves in the mission");
	RegAdminCmd("sm_potato_mode", Command_Vanilla_Mode,ADMFLAG_GENERIC, "Enables / Disables vanilla mode");
	RegConsoleCmd("sm_rtv", Command_Rtv);
	AutoExecConfig();
	HookEvent("mvm_begin_wave", Event_WaveStart);
	HookEvent("mvm_wave_complete", Event_WaveEnd);
	HookEvent("mvm_wave_failed", Event_WaveFail);
	HookEvent("mvm_mission_complete", Event_MissionComplete);
	HookEvent("teamplay_round_start", Event_RestartRound);

	AddCommandListener(Command_CallVote, "callvote"); // TF2, CS:GO

	Handle game_conf = LoadGameConfigFile("tf2.mvm");

	StartPrepSDKCall(SDKCall_Raw);
	if (PrepSDKCall_SetFromConf(game_conf,SDKConf_Signature,"CTFPlayerShared::Burn"))
	{
		PrepSDKCall_AddParameter(SDKType_CBasePlayer, SDKPass_Pointer, VDECODE_FLAG_ALLOWNULL);
		PrepSDKCall_AddParameter(SDKType_CBaseEntity, SDKPass_Pointer, VDECODE_FLAG_ALLOWNULL);
		PrepSDKCall_AddParameter(SDKType_Float, SDKPass_Plain);
	}
	burn_prep = EndPrepSDKCall();

	whitelisted_afterburn_items = CreateTrie();
	whitelisted_afterburn_items.SetValue("tf_weapon_fireaxe",1);
	whitelisted_afterburn_items.SetValue("tf_weapon_flamethrower",1);
	whitelisted_afterburn_items.SetValue("tf_weapon_flaregun",1);
	whitelisted_afterburn_items.SetValue("tf_weapon_flaregun_revenge",1);
	whitelisted_afterburn_items.SetValue("tf_weapon_compound_bow",1);
	whitelisted_afterburn_items.SetValue("tf_weapon_minigun",1);
	whitelisted_afterburn_items.SetValue("tf_weapon_rocketlauncher_fireball",1);
	whitelisted_afterburn_items.SetValue("tf_weapon_spellbook",1);
	whitelisted_afterburn_items.SetValue("tf_weapon_particle_cannon",1);
}

public void SetGameDescription()
{
	// This functionality already exists in cecon_mvm.sp, plus it also has team composition values.
	// - Moonly
	/*
	char gameDesc[64] = "Team Fortress";
	//if (GetEntProp(FindEntityByClassname(-1,"tf_gamerules"), Prop_Send,"m_bPlayingMannVsMachine", 1) != 0) {
		int resource = FindEntityByClassname(-1,"tf_objective_resource");
		int max_wave = GetEntProp(resource, Prop_Send,"m_nMannVsMachineMaxWaveCount");
		int wave = GetEntProp(resource, Prop_Send,"m_nMannVsMachineWaveCount");
		Format(gameDesc,64, "%s (Wave %d/%d", gameDesc, wave,max_wave);
		if (max_wave == 0 && wave == 0)
			StrCat(gameDesc,64, " :: Waiting)");
		else if (GetEntProp(resource, Prop_Send,"m_bMannVsMachineBetweenWaves") == 0)
			StrCat(gameDesc,64, " :: In-Wave)");
		else if (GetEntProp(resource, Prop_Send,"m_bMannVsMachineBetweenWaves") != 0)
			StrCat(gameDesc,64, " :: Setup)");
	//}
	SteamWorks_SetGameDescription(gameDesc);
	*/
}

public void VanillaModeChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	if (strcmp("0",newValue) != 0)
	{
		vanilla_mode = false;
		ServerCommand("exec sigvanilla.cfg");
		
		if (extramodded_set)
		{
			SetConVarString(FindConVar("sig_mvm_custom_upgrades_file"),"");
			extramodded_set = false;
		}
		
		if (mvm10_set)
		{
			SetConVarInt(FindConVar("sig_mvm_red_team_max_players"), 0);
			mvm10_set = false;
		}
	} else {
		vanilla_mode = true;
		ServerCommand("exec sig.cfg");
	}
}

public void OnClientPutInServer(int client)
{
	SDKHook(client, SDKHook_OnTakeDamage, OnPlayerDamage);
	SDKHook(client, SDKHook_OnTakeDamage, OnAnyDamage);
	if (IsFakeClient(client))
	{
		SDKHook(client, SDKHook_WeaponEquip, OnWeaponEquip);
	} else {
		SDKHook(client, SDKHook_PreThink, OnPlayerThink);
	}
	
	SetGameDescription();
}

void ResetCustomUpgrades(int data)
{
	SetConVarString(FindConVar("sig_mvm_custom_upgrades_file"),"");
}

public void OnClientDisconnect_Post(int client)
{
	int players = 0;
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && !IsFakeClient(i))
		{
			players++;
		}
	}
	
	if(players == 0)
	{
		ResetAllStats();
		
		if (extramodded_set)
		{
			RequestFrame(ResetCustomUpgrades, 0);
			extramodded_set = false;
		}
		
		if (mvm10_set) {
			SetConVarInt(FindConVar("sig_mvm_red_team_max_players"), 0);
			mvm10_set = false;
		}
	}
	SetGameDescription();
}

public Action Command_Vanilla_Mode(int client, int args)
{
	if (args < 1)
	{
		ReplyToCommand(client, "[MvM-Admin] Usage: sm_potato_mode <0|1>");
		return Plugin_Handled;
	}
	
	char target[2];
	GetCmdArg(1, target, 2);
	SetConVarBool(FindConVar("sig_vanilla_mode"),strcmp(target,"0") != 0);
	
	ShowActivity2(client,"[MvM-Admin] ", "Potato mode changed");
	return Plugin_Handled;
}

public Action Command_CallVote(int client, const char[] command, int args)
{
	if (args == 0)
	{
		Handle message = StartMessageOne("VoteSetup", client, USERMSG_RELIABLE);
		
		BfWriteByte(message,11);
		BfWriteString(message,"Kick");
		BfWriteString(message,"");
		BfWriteByte(message,1);
		BfWriteString(message,"RestartGame");
		BfWriteString(message,"");
		BfWriteByte(message,1);
		BfWriteString(message,"ChangeLevel");
		BfWriteString(message,"");
		BfWriteByte(message,1);
		BfWriteString(message,"ChangeMission");
		BfWriteString(message,"");
		BfWriteByte(message,1);
		BfWriteString(message,"RestartWave");
		BfWriteString(message,"#Winpanel_PVE_Evil_Wins");
		BfWriteByte(message,1);
		
		if (GetConVarBool(vote_em_enabled))
		{
			BfWriteString(message,"Upgrade");
			BfWriteString(message,"#TF_Coach_FreeAccount_Title");
			BfWriteByte(message,1);
		}
		if (GetConVarBool(vote_10mvm_enabled))
		{
			BfWriteString(message,"10mvm");
			BfWriteString(message,"#TF_hwn2018_pyro_in_chinatown_style1");
			BfWriteByte(message,1);
		}

		EndMessage();

		return Plugin_Handled;
	} else {
		
		char buf[128];
		GetCmdArg(1,buf,128);
		if (strcmp(buf,"RestartWave") == 0 && GetEntProp(FindEntityByClassname(-1,"tf_objective_resource"), Prop_Send,"m_bMannVsMachineBetweenWaves") == 0)
		{
			NativeVote vote = new NativeVote(RestartWaveHandler, NativeVotesType_Custom_YesNo);
	
			vote.Initiator = client;
			vote.SetDetails("Restart current wave?");
			vote.DisplayVoteToAll(15);
		} else if (strcmp(buf,"Upgrade") == 0 && !vanilla_mode && GetEntProp(FindEntityByClassname(-1,"tf_objective_resource"), Prop_Send,"m_bMannVsMachineBetweenWaves") == 1)
		{
			NativeVote vote = new NativeVote(UpgradesHandler, NativeVotesType_Custom_YesNo);
	
			vote.Initiator = client;
			char oldval[128];
			GetConVarString(FindConVar("sig_mvm_custom_upgrades_file"),oldval,128);
			if (strcmp(oldval,"mvm_upgrades_sigsegv_extra_v19.txt") == 0)
			{
				vote.SetDetails("Revert to the original upgrades?");
			} else {
				vote.SetDetails("Use extra modded upgrades?");
			}
			vote.DisplayVoteToAll(15);
			
		} else if (strcmp(buf,"10mvm") == 0 && !vanilla_mode)
		{
			NativeVote vote = new NativeVote(MVM10Handler, NativeVotesType_Custom_YesNo);
	
			vote.Initiator = client;

			if (mvm10_set)
			{
				vote.SetDetails("Revert to 6 max players?");
			} else {
				vote.SetDetails("Enable 10 max players?");
			}
			vote.DisplayVoteToAll(15);
			
		} else {
			return Plugin_Continue;
		}
	}
	return Plugin_Handled;
}

public int RestartWaveHandler(NativeVote vote, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_End:
		{
			vote.Close();
		}
		
		case MenuAction_VoteCancel:
		{
			if (param1 == VoteCancel_NoVotes)
			{
				vote.DisplayFail(NativeVotesFail_NotEnoughVotes);
			} else {
				vote.DisplayFail(NativeVotesFail_Generic);
			}
		}
		
		case MenuAction_VoteEnd:
		{
			if (param1 == NATIVEVOTES_VOTE_NO)
			{
				vote.DisplayFail(NativeVotesFail_Loses);
			} else {
				
				vote.DisplayPass("Restarting the wave");
				// Do something because it passed
				ServerCommand("mp_restartgame_immediate 1");
			}
		}
	}
}

public int UpgradesHandler(NativeVote vote, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_End:
		{
			vote.Close();
		}
		case MenuAction_VoteCancel:
		{
			if (param1 == VoteCancel_NoVotes)
			{
				vote.DisplayFail(NativeVotesFail_NotEnoughVotes);
			} else {
				vote.DisplayFail(NativeVotesFail_Generic);
			}
		}
		
		case MenuAction_VoteEnd:
		{
			if (param1 == NATIVEVOTES_VOTE_NO)
			{
				vote.DisplayFail(NativeVotesFail_Loses);
			} else {
				
				if (extramodded_set)
				{
					vote.DisplayPass("Reverting default upgrades");
				} else {
					vote.DisplayPass("Using extra modded upgrades");
				}
				CreateTimer(0.0, TimerPutUpgrades, 1);
			}
		}
	}
}

public int MVM10Handler(NativeVote vote, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_End:
		{
			vote.Close();
		}
		case MenuAction_VoteCancel:
		{
			if (param1 == VoteCancel_NoVotes)
			{
				vote.DisplayFail(NativeVotesFail_NotEnoughVotes);
			} else {
				vote.DisplayFail(NativeVotesFail_Generic);
			}
		}
		
		case MenuAction_VoteEnd:
		{
			if (param1 == NATIVEVOTES_VOTE_NO)
			{
				vote.DisplayFail(NativeVotesFail_Loses);
			} else {
				
				if (mvm10_set)
				{
					vote.DisplayPass("Reverting to 6 max players");
					SetConVarInt(FindConVar("sig_mvm_red_team_max_players"), 0);
				} else {
					vote.DisplayPass("Enabling 10 max players");
					SetConVarInt(FindConVar("sig_mvm_red_team_max_players"), 10);
				}
			}
		}
	}
}

public Action TimerPutUpgrades(Handle timer, int arg) {
	for (int i = arg; i < MaxClients; i++) {
		if (IsClientInGame(i) && !IsFakeClient(i)) {
			SetEntProp(i,Prop_Send,"m_bInUpgradeZone",true);
			KeyValues kv = CreateKeyValues("MVM_Respec");
			FakeClientCommandKeyValues(i,kv);
			SetEntProp(i,Prop_Send,"m_bInUpgradeZone",false);
			CreateTimer(0.0, TimerPutUpgrades, i+1);
			return Plugin_Handled;
		}
	}
	char oldval[128];
	GetConVarString(FindConVar("sig_mvm_custom_upgrades_file"),oldval,128);
	if (extramodded_set){
		SetConVarString(FindConVar("sig_mvm_custom_upgrades_file"),"");
		extramodded_set = false;
	}
	else {
		extramodded_set = true;
		SetConVarString(FindConVar("sig_mvm_custom_upgrades_file"),"mvm_upgrades_sigsegv_extra_v19.txt");
	}
	return Plugin_Handled;
} 

public Action Command_Rtv(int client, int args)
{
	FakeClientCommand(client,"callvote");
	return Plugin_Handled;
}

public Action Command_WaveTime(int client, int args)
{
	DisplayWaveTimesTotal(client);
	return Plugin_Handled;
}

public Action Command_RestartGame(int client, int args)
{
	if (GetEntProp(FindEntityByClassname(-1,"tf_objective_resource"), Prop_Send,"m_bMannVsMachineBetweenWaves") == 0){
		NativeVote vote = new NativeVote(RestartWaveHandler, NativeVotesType_Custom_YesNo);

		vote.Initiator = client;
		vote.SetDetails("Restart current wave?");
		vote.DisplayVoteToAll(20);
		
	}
	return Plugin_Handled;
}

bool firstfakeballspawn = true;
public void OnMapStart()
{
	if (GameRules_GetProp("m_bPlayingMannVsMachine") == 0) {
		ServerCommand("sm plugins unload mvmstuff");
		return;
	}


	ResetAllStats();
	SetGameDescription();
	firstrestart = false;
	firstfakeballspawn = true;
		//if (GetConVarBool(caber_buff_enabled))
	CreateTimer(2.0, ResetCaber, 0, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
}
public Action ResetCaber(Handle handle, int data)
{
	for (int i=1; i<= MaxClients; i++)
	{		
		if (!IsClientInGame(i) || !IsPlayerAlive(i))
			continue;
		
		int iWeapon = GetPlayerWeaponSlot(i, 2);
		// if weapon def id is caber, and caber buff convar is enabled, or regenerate_stickbomb attribute is present, regenerate it
		if (iWeapon > 0 && GetEntProp(iWeapon, Prop_Send, "m_iItemDefinitionIndex") == 307 
			&& ((!IsFakeClient(i) && GetConVarBool(caber_buff_enabled)) || TF2Attrib_HookValueFloat(0.0,"regenerate_stickbomb",iWeapon) != 0.0 )) {
			if (GetEntProp(iWeapon, Prop_Send, "m_iDetonated") == 1)
			{
				SetEntProp(iWeapon, Prop_Send, "m_iDetonated", 0);
			}
		}
	}
	return Plugin_Continue;
}

public void OnMapEnd(){
	if (extramodded_set) {
		SetConVarString(FindConVar("sig_mvm_custom_upgrades_file"),"");
		extramodded_set = false;
	}
	if (mvm10_set) {
		SetConVarInt(FindConVar("sig_mvm_red_team_max_players"), 0);
		mvm10_set = false;
	}
	if (vanilla_mode) {
		SetConVarBool(FindConVar("sig_vanilla_mode"), false);
		vanilla_mode = false;
	}
}

void ResetAllStats() {
	for (int i = 0;i < 64; i++){
		wave_times[i] = 0.0;
		wave_passed[i] = false;
	}
	wave_start_time=0.0;
	waves_total_time=0.0;
	last_wave_number=0;
}

public void WriteTime(float time, char[] str, int maxlen) {
	int timeint = RoundToFloor(time);
	if (timeint/3600 > 0)
		Format(str,maxlen,"%d h %d min %d sec", timeint/3600, (timeint/60) % 60,(timeint) % 60);
	else if (timeint/60 > 0)
		Format(str,maxlen,"%d min %d sec",(timeint/60) % 60,(timeint) % 60);
	else
		Format(str,maxlen,"%d sec",(timeint) % 60);
}

public void DisplayCurrentWaveTime() {
	if (last_wave_number == 0)
		return;
	char timestr[64];
	WriteTime(GetGameTime()-wave_start_time,timestr,64);
	PrintToChatAll("\x0700FFFFTime spent on Wave %d:\x07FFD800 %s",last_wave_number,timestr);
}

public float GetWaveSuccessTime()
{
	float success_time = 0.0;

	for (int i = 0; i < sizeof(wave_passed); i++)
	{
		if (wave_passed[i])
			success_time += wave_times[i];
	}
	return success_time;
}

int last_wave_display_tick;
public void DisplayWaveTimes() {
	if (last_wave_display_tick == GetGameTickCount())
		return;

	char timestr[64];
	if (last_wave_number != 0) {
		WriteTime(wave_times[last_wave_number],timestr,64);
		PrintToChatAll("\x0700FFFFTime spent on Wave %d:\x07FFD800 %s",last_wave_number,timestr);
	}

	WriteTime(GetWaveSuccessTime(),timestr,64);
	PrintToChatAll("\x0700FFFFTotal success time spent:\x07FFD800 %s",timestr);
	WriteTime(waves_total_time,timestr,64);
	PrintToChatAll("\x0700FFFFTotal time spent:\x07FFD800 %s",timestr);
	last_wave_display_tick = GetGameTickCount();
}

public void DisplayWaveTimesTotal(int client) {
	int resource = FindEntityByClassname(-1,"tf_objective_resource");
	int max_wave = GetEntProp(resource, Prop_Send,"m_nMannVsMachineMaxWaveCount");

	char timestr[64];
	char strprint[256];
	for (int i = 1; i <= max_wave; i++) {
		WriteTime(wave_times[i],timestr,64);
		Format(strprint,256,"\x0700FFFF[Wave %d] Time spent:\x07FFD800 %s",i,timestr);
		if (wave_passed[i])
			Format(strprint,256,"%s %s",strprint,"\x077FFF8E(Success)");
		else if(wave_times[i] > 0)
			Format(strprint,256,"%s %s",strprint,"\x07FF5661(Fail)");
		else
			Format(strprint,256,"%s %s",strprint,"\x07FFF47F(Not played)");
		if (client == 0)
			PrintToChatAll(strprint);
		else
			PrintToChat(client, strprint);
	}

	WriteTime(wave_times[last_wave_number],timestr,64);
	PrintToChatAll("\x0700FFFFTime spent on Wave %d:\x07FFD800 %s",last_wave_number,timestr);
	WriteTime(GetWaveSuccessTime(), timestr,64);
	PrintToChatAll("\x0700FFFFTotal success time spent:\x07FFD800 %s",timestr);
	WriteTime(waves_total_time,timestr,64);
	PrintToChatAll("\x0700FFFFTotal time spent:\x07FFD800 %s",timestr);
}

public void Event_WaveStart(Event event, const char[] name, bool dontBroadcast)
{
	//PrintToChatAll("mvm_wave_start");
	int resource = FindEntityByClassname(-1,"tf_objective_resource");
	last_wave_number = GetEntProp(resource, Prop_Send,"m_nMannVsMachineWaveCount");
	//GetEntPropString(resource, Prop_Send,"m_iszMvMPopfileName",mission,128);
	//SubString(mission, FindCharInString(mission,'/',true)+1,FindCharInString(mission,'.',true)+1);
	wave_start_time = GetGameTime();

	if (write_wave_time_enabled.BoolValue)
		wave_time_timer = CreateTimer(60.0,UpdateMissionProgressTime, 0, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);

	SetGameDescription();
}

public void Event_WaveEnd(Event event, const char[] name, bool dontBroadcast)
{

	//PrintToChatAll("mvm_wave_end");
	wave_passed[last_wave_number] = true;
	wave_times[last_wave_number] = GetGameTime()-wave_start_time;
	waves_total_time += GetGameTime()-wave_start_time;
	last_wave_number = 0;

	if (write_wave_time_enabled.BoolValue)
		DisplayWaveTimes();
		
	if (wave_time_timer != null) {
		CloseHandle(wave_time_timer);
		wave_time_timer = null;
	}
	SetGameDescription();
}


public void Event_WaveFail(Event event, const char[] name, bool dontBroadcast)
{

	//PrintToChatAll("mvm_wave_fail");
	
	fail_counter_tick++;
	if (fail_counter_tick > 3){
		MissionRestarted();
	}

	CreateTimer(0.00,ResetFailCounterTimer, 0);

	if (last_wave_number != 0) {
		wave_times[last_wave_number] = GetGameTime()-wave_start_time;
		waves_total_time += GetGameTime()-wave_start_time;

		if (write_wave_time_enabled.BoolValue)
			DisplayWaveTimes();
	}
	last_wave_number = 0;
	if (wave_time_timer != null) {
		delete wave_time_timer;
		wave_time_timer = null;
	}

	if (reset_mission_timer != null) {
		delete reset_mission_timer;
		reset_mission_timer = null;
	}
}

public void Event_RestartRound(Event event, const char[] name, bool dontBroadcast)
{
	if (wave_time_timer != null) {
		CloseHandle(wave_time_timer);
		wave_time_timer = null;
	}
	if(!firstrestart){
		firstrestart=true;
	}
	SetGameDescription();
}

public Action ResetFailCounterTimer(Handle timer, any value) {
	fail_counter_tick=0;
}

public Action UpdateMissionProgressTime(Handle timer, any value) {
	DisplayCurrentWaveTime();
}


void MissionRestarted() {
	//PrintToChatAll("mission restarted");
	ResetAllStats();
	
}


public Action ResetMissionTimer(Handle timer, any value) {
	
	int resource = FindEntityByClassname(-1,"tf_objective_resource");
	char missionname[256];
	GetEntPropString(resource, Prop_Send,"m_iszMvMPopfileName", missionname,256);
	missionname[FindCharInString(missionname,'.',true)]=0;
	PrintToServer("server mission change to %s",missionname);
	ServerCommand("tf_mvm_popfile %s",missionname[FindCharInString(missionname,'/',true)+1]);

	reset_mission_timer = null;
}

public void Event_MissionComplete(Event event, const char[] name, bool dontBroadcast)
{
	PrintToServer("Mission complete");
	PrintToChatAll("Mission complete");

	if (write_wave_time_enabled.BoolValue)
		DisplayWaveTimesTotal(0);

	ResetAllStats();
	reset_mission_timer = CreateTimer(12.0,ResetMissionTimer, 0);

}


public void OnEntityCreated(int entity, const char[] classname)
{
	if (strcmp(classname,"tank_boss") == 0 || strncmp(classname,"obj_",4) == 0)
	{
		SDKHook(entity, SDKHook_OnTakeDamage, OnAnyDamage);
	}
	else if
	// almost certain that this strcmp logic is bunk
	//(strcmp(classname,"tf_projectile_mechanicalarmorb") == 0)
	(StrEqual(classname,"tf_projectile_mechanicalarmorb"))
	{
		RequestFrame(OnEnergyBallSpawn,entity);
		//SDKHook(entity,SDKHook_Spawn, OnEnergyBallSpawn);
	}
}

public bool IsDuringWave()
{
	int resource = FindEntityByClassname(-1,"tf_objective_resource");
	return GetEntProp(resource, Prop_Send,"m_bMannVsMachineBetweenWaves") == 0;
}
public void OnEnergyBallSpawn(int entity)
{
	if (firstfakeballspawn) {
		firstfakeballspawn = false;
		return;
	}

	if (IsValidEntity(entity))
	{
		// this shouldn't be needed but just in case
		if (!HasEntProp(entity, Prop_Send, "m_hLauncher"))
		{
			return;
		}
		int launcher = GetEntPropEnt(entity,Prop_Send, "m_hLauncher");
		if (IsValidEntity(launcher))
		{
			float gameTime = GetGameTime();
			float fireRateMult= TF2Attrib_HookValueFloat(1.0,"mult_postfiredelay",launcher);
			float nextAttack = GetEntPropFloat(launcher,Prop_Send, "m_flNextPrimaryAttack");

			SetEntPropFloat(launcher, Prop_Send, "m_flNextPrimaryAttack", gameTime+((nextAttack-gameTime)*fireRateMult));
			SetEntPropFloat(launcher, Prop_Send, "m_flNextSecondaryAttack", gameTime+((nextAttack-gameTime)*fireRateMult));
			//PrintToChatAll("ball %f", fireRateMult, GetEntPropFloat(launcher,Prop_Send, "m_flNextPrimaryAttack"));
		}
	}
}
int last_stickbomb_victim = 0;
public Action OnAnyDamage(int victim, int& attacker, int& inflictor, float& damage, int& damagetype, int& weapon, float damageForce[3], float damagePosition[3], int damagecustom)
{
	if (attacker > 0 && attacker <= MaxClients && IsClientInGame(attacker) && weapon != 0 && IsValidEntity(weapon)){
		if (!IsFakeClient(attacker) /*GetEntProp(victim, Prop_Send, "m_iTeamNum") == 3*/) {
			char classname[32];
			GetEntityClassname(weapon,classname,32);
			if(!vanilla_mode){
				if (attacker != victim && GetConVarBool(caber_buff_enabled)) {
					if (damagecustom == 42 && strcmp(classname,"tf_weapon_stickbomb") == 0) {
						//Damage increase if not under critical effect
						if ((damagetype & DMG_ACID) == 0 || (victim <= MaxClients && TF2_IsPlayerInCondition(attacker, TFCond_DefenseBuffed)))
							damage *= 1.35;

						//10% damage increase vs tank (blast only)
						char victim_classname[32];
						GetEntityClassname(victim,victim_classname,32);
						if (strcmp(victim_classname, "tank_boss") == 0)
							damage *= 1.1;

						damage = TF2Attrib_HookValueFloat(1.31 * damage,"mult_dmg",weapon);
						if (last_stickbomb_victim == victim) {
							damagetype |= TF_DMG_MELEE;
							last_stickbomb_victim = 0;
						}
					}
					else if ((damagetype & TF_DMG_MELEE) == TF_DMG_MELEE && strcmp(classname,"tf_weapon_stickbomb") == 0) {
						damage *= 0.64;
						last_stickbomb_victim = victim;
					}
				}
			}
			if ((damagetype & DMG_SHOCK) == DMG_SHOCK && strcmp(classname,"tf_weapon_mechanical_arm") == 0) {
				damage = TF2Attrib_HookValueFloat(damage,"mult_dmg",weapon);
			}
			if (damagecustom == 46 && (strcmp(classname, "tf_weapon_raygun") == 0 || strcmp(classname, "tf_weapon_drg_pomson") == 0)) {
				damage = TF2Attrib_HookValueFloat(damage,"mult_dmg",weapon);
			}
		}
		//PrintToChat(attacker,"%d %f %d %d %d", attacker,damage, damagetype, weapon, damagecustom);
	}
	return Plugin_Changed;
}

public Action OnPlayerDamage(int victim, int& attacker, int& inflictor, float& damage, int& damagetype, int& weapon, float damageForce[3], float damagePosition[3], int damagecustom)
{
	
	//PrintToChatAll("%d %f %d %d %d", attacker,damage, damagetype, weapon, damagecustom);
	//Stickbomb reset

	if (attacker > 0 && attacker != victim && attacker <= MaxClients && IsClientInGame(attacker) ){

		if (weapon > 0 && IsValidEntity(weapon) && GetClientTeam(victim) != GetClientTeam(attacker)) {
			if( /*GetClientTeam(victim) == 3 */ /*blue*/ !vanilla_mode && !IsFakeClient(attacker)) {
				char classname[32];
				GetEntityClassname(weapon,classname,32);
				if ((damagetype & 2048) == 0 && damagecustom == 3 && GetClientTeam(victim) == 3 && GetConVarBool(eoi_nerf_enabled) && strcmp(classname,"tf_weapon_jar_gas") == 0 ) {
					damage = damage * 0.215;
					TF2_StunPlayer(victim,0.6,0.12,TF_STUNFLAG_SLOWDOWN,attacker);
				}
				
				else if (damagecustom == 14 && ((GetConVarBool(radius_sleeper_enabled) && !IsFakeClient(attacker)) || TF2Attrib_HookValueFloat(damage,"radius_sleeper",attacker) != 0.0) && strcmp(classname,"tf_weapon_sniperrifle") == 0) {
					float charge = GetEntPropFloat(weapon,Prop_Send, "m_flChargedDamage");
					if (charge > 0.0) {
						float pos[3];
						float ang[3];
						GetClientEyePosition(attacker,pos);
						GetClientEyeAngles(attacker,ang);
						TR_TraceRayFilter(pos,ang,MASK_SHOT,RayType_Infinite,FilterPlayer,attacker);
						if (TR_GetEntityIndex() == victim && TR_GetHitGroup() == 1) //headshot
						{
							charge = ((charge-30.0)/120.0);
							if (charge < 0.0)
								charge = 0.0;

							float distsq = 225.0 + charge * 185.0;
							distsq *= distsq;

							charge = 1.0+charge*3.0;
							
							float victimpos[3];
							GetClientAbsOrigin(victim,victimpos);
							for (int i =1; i < 33; i++) {
								if (IsClientInGame(i) && GetClientTeam(i) == GetClientTeam(victim)) {
									float enemypos[3];
									GetClientAbsOrigin(i,enemypos);
									float distance = (enemypos[0]-victimpos[0])*(enemypos[0]-victimpos[0])+(enemypos[1]-victimpos[1])*(enemypos[1]-victimpos[1])+(enemypos[2]-victimpos[2])*(enemypos[2]-victimpos[2]);
									if (distance < distsq){
										TF2_AddCondition(i,TFCond_Jarated,charge,attacker);
									}
								}
							}
						}
					}
					//PrintToChat(attacker," %f",GetEntPropFloat(weapon,Prop_Send, "m_flChargedDamage"));
				}
			}
			Address address = TF2Attrib_GetByDefIndex(weapon,208);
			if ((address != Address_Null && TF2Attrib_GetValue(address ) > 0)){
				BurnClient(victim, attacker, -1, TF2Attrib_HookValueFloat(10.0, "mult_wpn_burntime",weapon));
				//PrintToChat(attacker," burning");
			}
			//PrintToChatAll("Damagetype %d %d",damagetype, damagecustom);
			/*else if (damagetype & DMG_PLASMA) {
				int whitelisted=0;
				if (weapon > 0) {
					char classname[32];
					GetEntityClassname(weapon,classname,32);
					whitelisted_afterburn_items.GetValue(classname,whitelisted);
				}
				if (!whitelisted)
					TF2_IgnitePlayer(victim, attacker);
			}*/
		}
		
		if (damagecustom == 75) {
			damage = TF2Attrib_HookValueFloat(damage,"mult_dmg",attacker);
			damage = TF2Attrib_HookValueFloat(damage,"mult_dmg_vs_players",attacker);
		}
		//PrintToServer("%d %f %d %d %d", attacker,damage, damagetype, weapon, damagecustom);
	}
	return Plugin_Changed;
}
public bool FilterPlayer(int entity, int contentsMosk, int shooter)
{
	return entity != shooter;
}
public bool UpdateWeaponFire(int player, int weapon)
{
	int pressedbutton = GetClientButtons(player);
	if ((pressedbutton & IN_ATTACK2) == IN_ATTACK2 && GetEntProp(weapon,Prop_Send,"m_iClip1") != 1){
		if (!super_fire_fan[player]){
			super_fire_fan[player] = true;
			//TF2Attrib_RemoveByDefIndex(weapon, 44);
			TF2Attrib_SetByDefIndex(weapon, 45, 2.4); //Bullet bonus
			TF2Attrib_SetByDefIndex(weapon, 348, 2.56); //Fire rate penalty hidden
			TF2Attrib_SetByDefIndex(weapon, 298, 2.0); //mod ammo per shot
			TF2Attrib_SetByDefIndex(weapon, 36, 1.15); //spread penalty
		}
	}
	else
	{
		if (super_fire_fan[player]){
			super_fire_fan[player] = false;
			TF2Attrib_RemoveByDefIndex(weapon, 45);
			TF2Attrib_RemoveByDefIndex(weapon, 348);
			TF2Attrib_RemoveByDefIndex(weapon, 298);
			TF2Attrib_RemoveByDefIndex(weapon, 36);
			//TF2Attrib_SetByDefIndex(weapon, 44, -1.0); //scattergun has knockback
		}
	}
}
public Action OnPlayerThink(int player)
{
	if (vanilla_mode)
		return;
	if (IsPlayerAlive(player) && GetConVarBool(super_shotgun_enabled)){
		int weaponprim = GetPlayerWeaponSlot(player,0);
		if (weaponprim > 0 && IsValidEntity(weaponprim))
		{
			int defIndex = GetEntProp(weaponprim,Prop_Send,"m_iItemDefinitionIndex");
			if (defIndex == 45 || defIndex == 1078){
				UpdateWeaponFire(player,weaponprim);
			}
			else
			{
				super_fire_fan[player] = false;
			}
		}
		else
		{
			super_fire_fan[player] = false;
		}
	}
}

public Action OnWeaponEquipTimer(Handle timer, int weaponref)
{
	int weapon = EntRefToEntIndex(weaponref);
	if (IsValidEntity(weapon)){
		Address address = TF2Attrib_GetByDefIndex(weapon, 834);
		if (address != Address_Null){
			//PrintToServer("lowid: %f %d",TF2Attrib_GetValue(address), view_as<int>(TF2Attrib_GetValue(address)));
			TF2Attrib_SetByDefIndex(weapon, 834, view_as<float>(RoundFloat(TF2Attrib_GetValue(address)))); 
		}
		
		//address = TF2Attrib_GetByDefIndex(weapon, 152);
		//if (address != Address_Null){
			//TF2Attrib_SetByDefIndex(weapon, 152, view_as<float>(3099725842)); 
		//}

		//address = TF2Attrib_GetByDefIndex(weapon, 227);
		//if (address != Address_Null){
			//TF2Attrib_SetByDefIndex(weapon, 227, view_as<float>(235522665)); 
		//}
		
		//Fix inactive weapons being rendered
		SetEntProp(weapon, Prop_Send, "m_fEffects", GetEntProp(weapon, Prop_Send, "m_fEffects"));
	
	}
}
public Action OnWeaponEquip(int client, int weapon)
{
	CreateTimer(0.5,OnWeaponEquipTimer,EntIndexToEntRef(weapon));
	//TF2Attrib_SetByDefIndex(weapon, 152, view_as<float>(3099725842)); 
	//TF2Attrib_SetByDefIndex(weapon, 227, view_as<float>(235522665)); 
	//TF2Attrib_SetByDefIndex(weapon, 866, view_as<float>(-2070913525));
	//TF2Attrib_SetByDefIndex(weapon, 867, view_as<float>(1));
}
public int TF2Items_OnGiveNamedItem_Post(int client, char[] classname, int itemDefinitionIndex, int itemLevel, int itemQuality, int entityIndex)
{
	if (vanilla_mode)
		return;
	if ((itemDefinitionIndex == 45 || itemDefinitionIndex == 1078) && GetClientTeam(client) == 2){
		//TF2Attrib_SetByDefIndex(entityIndex, 44, -1.0); //scattergun has knockback
	//	SDKHook(entityIndex, SDKHook_ReloadPost, OnWeaponReloadPost);
	//	SDKHook(entityIndex, SDKHook_Reload, OnWeaponReload);
	}
	if (!IsFakeClient(client)) {
		if (itemDefinitionIndex == 1180 && GetConVarBool(eoi_nerf_enabled) && strcmp(classname,"tf_weapon_jar_gas") == 0) {
			TF2Attrib_SetByName(entityIndex, "item_meter_charge_rate", 32.0);
			TF2Attrib_SetByName(entityIndex, "item_meter_damage_for_full_charge", 570.0);
		}
		else if (GetConVarFloat(medic_shield_nerf_enabled) != 1.0 && strcmp(classname,"tf_weapon_medigun") == 0) {
			TF2Attrib_SetByName(entityIndex, "increase buff duration HIDDEN", GetConVarFloat(medic_shield_nerf_enabled));
		}
		else if (GetConVarBool(caber_buff_enabled) && strcmp(classname,"tf_weapon_stickbomb") == 0) {
			TF2Attrib_SetByName(entityIndex, "fire rate penalty", 2.25);
			//TF2Attrib_SetByName(entityIndex, "dmg falloff decreased", 0.1);
			TF2Attrib_SetByName(entityIndex, "Blast radius increased", 1.3);
		}
		
		if ((itemDefinitionIndex == 442 || itemDefinitionIndex == 588) && GetUserAdmin(client) != INVALID_ADMIN_ID) {
			TF2Attrib_SetByName(entityIndex, "set item tint RGB", view_as<float>(0x08FF00));
			TF2Attrib_SetByName(entityIndex, "SPELL: set item tint RGB", view_as<float>(2));
		}

		/*if (itemDefinitionIndex == 1153 && GetConVarBool(old_panic_attack_enabled) && strncmp(classname,"tf_weapon_shotgun",17) == 0) {
			TF2Attrib_SetByName(entityIndex, "damage penalty", 1.0);
			TF2Attrib_SetByName(entityIndex, "bullets per shot bonus", 1.0);
			TF2Attrib_SetByName(client, "fixed_shot_pattern", -1.0);
			TF2Attrib_SetByName(client, "mult_spread_scales_consecutive", -1.0);
			TF2Attrib_SetByName(entityIndex, "panic_attack", 1.0);
			TF2Attrib_SetByName(entityIndex, "panic_attack_negative", 2.5);
			TF2Attrib_SetByName(entityIndex, "auto fires full clip penalty", 1.0);
			TF2Attrib_SetByName(entityIndex, "fire rate bonus with reduced health", 0.5);
			TF2Attrib_SetByName(entityIndex, "fire rate bonus HIDDEN", 0.7);
			TF2Attrib_SetByName(entityIndex, "reload time decreased", 0.5);
			TF2Attrib_SetByName(entityIndex, "clip size penalty HIDDEN", 0.67);
			TF2Attrib_SetByName(entityIndex, "single wep deploy time decreased", 0.5);
			SetEntProp(entityIndex, Prop_Send, "m_iClip1", 0);
		}*/

	}
	// int attrdef[16];
	// float attrval[16];
	// int attribcount = TF2Attrib_GetSOCAttribs(entityIndex,attrdef,attrval,16);
	// PrintToServer("item given %s %d ",classname, itemDefinitionIndex);
	// for (int i = 0; i < attribcount; i++) {
	// 	PrintToServer("SOC Attribute %d %f %d",attrdef[i], attrval[i],view_as<int>(attrval[i]));
	// }
	// attribcount = TF2Attrib_GetStaticAttribs(itemDefinitionIndex,attrdef,attrval,16);
	// for (int i = 0; i < attribcount; i++) {
	// 	PrintToServer("Static Attribute %d %f %d",attrdef[i], attrval[i],view_as<int>(attrval[i]));
	// }

	// old Panic attack attributes
	
}

/*public Action TF2Items_OnGiveNamedItem(int client, char[] classname, int iItemDefinitionIndex, Handle &hItemOverride)
{
	if (vanilla_mode)
		return Plugin_Continue;
	if (iItemDefinitionIndex == 1153 && GetClientTeam(client) == 2 && !IsFakeClient(client) && GetConVarBool(old_panic_attack_enabled) && strncmp(classname,"tf_weapon_shotgun",17) == 0) {
		Handle hItem = TF2Items_CreateItem(OVERRIDE_ATTRIBUTES);

		if (hItem != INVALID_HANDLE)
		{
			
			TF2Items_SetNumAttributes(hItem, 9);
			TF2Items_SetAttribute(hItem,0,708,1.0);
			TF2Items_SetAttribute(hItem,1,709,2.5);
			TF2Items_SetAttribute(hItem,2,710,1.0);
			TF2Items_SetAttribute(hItem,3,651,0.5);
			TF2Items_SetAttribute(hItem,4,348,0.7);
			TF2Items_SetAttribute(hItem,5,97,0.5);
			TF2Items_SetAttribute(hItem,6,424,0.67);
			TF2Items_SetAttribute(hItem,7,773,0.5);

			hItemOverride = hItem;
			return Plugin_Changed;
		}
	}
	// None found, use default values.
	return Plugin_Continue;
}*/

public int BurnClient(int client, int inflictor, int weapon, float duration)
{
	if (!IsClientInGame(client) || burn_prep == null)
	{
		return -1;
	}

	int shared = FindSendPropInfo("CTFPlayer", "m_Shared");
	int entity = SDKCall(burn_prep, GetEntityAddress(client) + view_as<Address>(shared), inflictor, weapon, duration);
	return entity;
	
}

// IsValidClient stocks
//bool IsValidClient(int client)
//{
//    return
//    (
//        (0 < client <= MaxClients)
//        && IsClientInGame(client)
//        && !IsClientInKickQueue(client)
//    );
//}

