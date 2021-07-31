#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <tf2>
#include <tf2_stocks>
#include <usermessages>
#include <tf2attributes>
#include <clients>

#pragma newdecls required

char mapname[128];
public Plugin myinfo = 
{
    name = "Feedback",
    author = "rafradek",
    description = "Basic Communication Commands",
    version = SOURCEMOD_VERSION,
    url = "http://www.sourcemod.net/"
};
ConVar restart_game;
Handle data_mvm;
Handle add_cash_handle;
Handle add_cash_no_player_handle;
//Handle alloc_pooled_string_handle;
Handle jump_wave_handle;
Handle equip_wearable_handle;
// ***REPLACED SRC PASSWORD***
bool set_timescale = false;
char old_password[64];
int models_given[34];
int models_given_idwearable[34];

int g_lsprite;

public void OnPluginStart()
{
    LoadTranslations("common.phrases");
    RegAdminCmd("sm_wave_restart", Command_Wave_Restart,ADMFLAG_GENERIC, "Restarts the wave");
    RegAdminCmd("sm_addcash_all", Command_Addcash_All,ADMFLAG_GENERIC, "Adds credits to all connected players");
    RegAdminCmd("sm_popfile", Command_Population,ADMFLAG_GENERIC, "Sets the population file");
    RegAdminCmd("sm_mission", Command_Population,ADMFLAG_GENERIC, "Sets the population file");
    RegAdminCmd("sm_mission_menu", Command_MissionMenu,ADMFLAG_GENERIC, "Sets the population file");
    RegAdminCmd("sm_addcash", Command_Addcash,ADMFLAG_GENERIC, "Adds credits to specified player");
    RegAdminCmd("sm_wave", Command_JumpToWave,ADMFLAG_GENERIC, "Sets the wave");
    RegAdminCmd("sm_wave_start", Command_Wave_Start,ADMFLAG_GENERIC, "Force starts the wave");
    RegAdminCmd("sm_collect_cash", Command_Collect_Cash,ADMFLAG_GENERIC, "Collects all cash on the map");
    RegAdminCmd("sm_panic", Command_Panic,ADMFLAG_GENERIC, "Kills all bots and tanks on the map");
    RegAdminCmd("sm_ent_fire", Command_Ent_Fire,ADMFLAG_GENERIC, "Activates input on specified entity/classname");
    RegAdminCmd("sm_ent_create", Command_Ent_Create,ADMFLAG_GENERIC, "Creates specified entity classname with keyvalues");
    RegAdminCmd("sm_ent_fire_player", Command_Ent_Fire_Player,ADMFLAG_GENERIC, "Activates input on a player name");
    RegAdminCmd("sm_addcond", Command_Addcond,ADMFLAG_GENERIC, "Adds condition to a player");
    RegAdminCmd("sm_removecond", Command_Removecond,ADMFLAG_GENERIC, "Removes condition from a player");
    RegAdminCmd("sm_team", Command_Team ,ADMFLAG_GENERIC, "Sets player team");
    RegAdminCmd("sm_password", Command_Password ,ADMFLAG_GENERIC, "Sets server password for the map duration until the server empties. Pass no arguments to clear password");
    RegAdminCmd("sm_addattr", Command_AddAttr ,ADMFLAG_GENERIC, "Adds attribute to a player");
    RegAdminCmd("sm_removeattr", Command_RemoveAttr ,ADMFLAG_GENERIC, "Removes attribute from a player");
    RegAdminCmd("sm_teleport", Command_Teleport ,ADMFLAG_GENERIC, "Teleports player to you");
    RegAdminCmd("sm_tp", Command_Teleport ,ADMFLAG_GENERIC, "Removes attribute from a player");
    RegAdminCmd("sm_max_players", Command_Max_Players ,ADMFLAG_GENERIC, "Sets max number of players");
    RegAdminCmd("sm_equip_wearable_model", Command_Equip_Wearable_Model ,ADMFLAG_GENERIC, "Sets max number of players");
    RegAdminCmd("sm_change_bonemerge_model", Command_Change_Bonemerge_Model ,ADMFLAG_GENERIC, "Sets max number of players");
    //RegAdminCmd("sm_list_entities", Command_List_Entities, ADMFLAG_GENERIC, "List entities on the map");
    RegAdminCmd("sm_kill_tank", Command_Kill_Tank, ADMFLAG_GENERIC,"Shows info about tanks and kills them");
    RegAdminCmd("sm_toggle_ready", Command_Force_Ready ,ADMFLAG_GENERIC, "Forces ready state");
    RegAdminCmd("sm_respec", Command_Respec, ADMFLAG_GENERIC, "Removes all upgrades from the player");
    RegAdminCmd("sm_anim", Command_Anim, ADMFLAG_GENERIC, "Plays animation on player");
    RegAdminCmd("sm_timescale", Command_Timescale, ADMFLAG_GENERIC, "Sets server timescale");
    RegConsoleCmd("sm_pos", Command_Pos, "Get player & look position");
    RegAdminCmd("sm_bbox", Command_BBox, ADMFLAG_GENERIC, "Draw bounding box at position");

    restart_game = FindConVar("mp_restartgame_immediate");
    data_mvm = LoadGameConfigFile("tf2.mvm");

    StartPrepSDKCall(SDKCall_GameRules);
    PrepSDKCall_SetFromConf(data_mvm,SDKConf_Signature,"CTFGameRules::DistributeCurrencyAmount");
    PrepSDKCall_AddParameter(SDKType_PlainOldData,SDKPass_Plain);
    PrepSDKCall_AddParameter(SDKType_CBasePlayer,SDKPass_Pointer,VDECODE_FLAG_ALLOWNULL);
    PrepSDKCall_AddParameter(SDKType_PlainOldData,SDKPass_Plain);
    PrepSDKCall_AddParameter(SDKType_PlainOldData,SDKPass_Plain);
    PrepSDKCall_AddParameter(SDKType_PlainOldData,SDKPass_Plain);
    add_cash_handle=EndPrepSDKCall();

    StartPrepSDKCall(SDKCall_GameRules);
    PrepSDKCall_SetFromConf(data_mvm,SDKConf_Signature,"CTFGameRules::DistributeCurrencyAmount");
    PrepSDKCall_AddParameter(SDKType_PlainOldData,SDKPass_Plain);
    add_cash_no_player_handle=EndPrepSDKCall();

    StartPrepSDKCall(SDKCall_Entity);
    PrepSDKCall_SetFromConf(data_mvm,SDKConf_Signature,"CPopulationManager::JumpToWave");
    PrepSDKCall_AddParameter(SDKType_PlainOldData,SDKPass_Plain);
    PrepSDKCall_AddParameter(SDKType_PlainOldData,SDKPass_Plain);
    jump_wave_handle=EndPrepSDKCall();

    StartPrepSDKCall(SDKCall_Player);
    PrepSDKCall_SetFromConf(data_mvm, SDKConf_Virtual, "CTFPlayer::EquipWearable");
    PrepSDKCall_AddParameter(SDKType_CBaseEntity, SDKPass_Pointer);
    equip_wearable_handle = EndPrepSDKCall();

    StartPrepSDKCall(SDKCall_Static);
    PrepSDKCall_SetFromConf(data_mvm, SDKConf_Signature, "AllocPooledString");
    PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
    PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
    //alloc_pooled_string_handle = EndPrepSDKCall();

    //HookUserMessage(GetUserMessageId("VoteSetup"),UserMsg_CallVote,false,ntf);

    AutoExecConfig();

    HookEvent("player_spawn", EventPlayerSpawn);

    g_lsprite = PrecacheModel("materials/sprites/laser.vmt");
}

public Action EventPlayerSpawn(Handle hEvent, char[] strName, bool bDontBroadcast)
{
    int client = GetClientOfUserId(GetEventInt(hEvent, "userid"));

    if (models_given[client] != 0)
        EquipWearable(client,models_given[client]);

    return Plugin_Continue;
}

/*public void ntf(UserMsg id, bool send)
  {

  }

  public Action UserMsg_CallVote(UserMsg msg, BfRead buf, const int[] players, int playernum, bool reliable, bool init)
  {
  PrintToServer("Message %d %d ",reliable,init);
  char bufstr[512];
  int cursorpos=0;
  while(buf.BytesLeft > 0){
  int byte =buf.ReadByte();

  Format(bufstr[cursorpos],512,"%02x",byte);
  cursorpos+=2;
  }
  PrintToServer(bufstr);
  }*/
char lastcommand[12];
bool override = false;
public Action OnClientCommand(int client, int args)
{
    char command[64];
    GetCmdArg(0,command,64);
    if (strcmp(command, "noclip") == 0 && strcmp(lastcommand, "sm_noclip") != 0 && !override){
        FakeClientCommand(client,"sm_noclip @me");
        override = true;
        return Plugin_Handled;
    }
    else if (strcmp(command, "sm_noclip") == 0 && strcmp(lastcommand, "noclip") != 0){
        return Plugin_Handled;
    }
    else if (strcmp(command, "addcond") == 0){
        char arg[8];
        GetCmdArg(1,arg,8);
        FakeClientCommand(client,"sm_addcond @me %s", arg);
        return Plugin_Handled;
    }
    else if (strcmp(command, "removecond") == 0){
        char arg[8];
        GetCmdArg(1,arg,8);
        FakeClientCommand(client,"sm_removecond @me %s", arg);
        return Plugin_Handled;
    }
    else if (strcmp(command, "currency_give") == 0){
        char arg[8];
        GetCmdArg(1,arg,8);
        FakeClientCommand(client,"sm_addcash_all %s", arg);
        return Plugin_Handled;
    }
    else if (strcmp(command, "tf_mvm_jump_to_wave") == 0){
        char arg[8];
        GetCmdArg(1,arg,8);
        FakeClientCommand(client,"sm_wave %s", arg);
        return Plugin_Handled;
    }
    else if (strcmp(command, "ent_fire") == 0){
        char arg[256];
        GetCmdArgString(arg, 256);
        FakeClientCommand(client,"sm_ent_fire %s", arg);
        return Plugin_Handled;
    }
    else if (strcmp(command, "ent_remove") == 0){
        char arg[256];
        GetCmdArg(1,arg,256);
        FakeClientCommand(client,"sm_ent_fire !picker kill", arg);
        return Plugin_Handled;
    }
    else if (strcmp(command, "ent_remove_all") == 0){
        char arg[256];
        GetCmdArg(1,arg,256);
        FakeClientCommand(client,"sm_ent_fire %s kill", arg);
        return Plugin_Handled;
    }
    else if (strcmp(command, "ent_create") == 0){
        char arg[256];
        GetCmdArgString(arg, 256);
        FakeClientCommand(client,"sm_ent_create %s", arg);
        return Plugin_Handled;
    }
    override = false;
    strcopy(lastcommand,12,command);
    return Plugin_Continue;
}

public void OnClientDisconnect_Post(int client)
{
// ***REPLACED SRC PASSWORD***
        int players = 0;
        for (int i =1; i < 33; i++){
            if (IsClientInGame(i) && !IsFakeClient(i)){
                players++;
            }
        }
        if(players == 0) {
// ***REPLACED SRC PASSWORD***
            set_timescale = false;
// ***REPLACED SRC PASSWORD***
            SetConVarFloat(FindConVar("host_timescale"), 1.0);
        }
    }
}
public void OnMapStart()
{
    for (int i = 0; i < 33; i++) {
        models_given[i] = 0;
        models_given_idwearable[i] = 0;
    }
    char map[64];
    GetCurrentMap(map, sizeof(map));
    char time[32];
    FormatTime(time, sizeof(time), "%Y-%m-%d_%H-%M");
    char total[128];
    Format(total, sizeof(total), "feedback/%s-%s-fb.txt", time, map);
    strcopy(mapname, sizeof(mapname), total);
    if (set_password){
// ***REPLACED SRC PASSWORD***
// ***REPLACED SRC PASSWORD***
    }
    if (set_timescale){
        set_timescale = false;
        SetConVarFloat(FindConVar("host_timescale"), 1.0);
    }

    CreateTimer(1.0,RefreshBBoxTimer, 0, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
}

public Action Command_Wave_Restart(int client, int args)
{
    Wave_Restart();
    PrintToChatAll("[SM] Restarted the wave");
    return Plugin_Handled;
}

public Action Command_Teleport(int client, int args)
{
    if (args < 2)
    {
        ReplyToCommand(client, "[SM] Usage: sm_teleport <player> <destination>");
        return Plugin_Handled;
    }
    char target[64];
    GetCmdArg(1, target, 64);
    char destination[64];
    GetCmdArg(2, destination, 64);

    float pos[3];

    char target_name[MAX_TARGET_LENGTH];
    int target_list[MAXPLAYERS], target_count;
    bool tn_is_ml;
    //GetEntPropVector(destinationid,Prop_Send,"m_vecOrigin",pos,0);

    if ((target_count = ProcessTargetString(
                    target,
                    client,
                    target_list,
                    MAXPLAYERS,
                    COMMAND_FILTER_ALIVE,
                    target_name,
                    sizeof(target_name),
                    tn_is_ml)) <= 0)
    {
        ReplyToTargetError(client, target_count);
        return Plugin_Handled;
    }

    if (args == 4) {
        char xs[16];
        char ys[16];
        char zs[16];
        GetCmdArg(2, xs, 16);
        GetCmdArg(3, ys, 16);
        GetCmdArg(4, zs, 16);
        pos[0] = StringToFloat(xs);
        pos[1] = StringToFloat(ys);
        pos[2] = StringToFloat(zs);

        ShowActivity2(client,"[SM] ", "Teleported %s to %f %f %f", pos[0], pos[1], pos[2]);
    }
    else {
        int destinationid = FindTarget(client,destination,false,false);

        if (destinationid != -1) {

            char dest_name[64];
            GetClientName(destinationid, dest_name, 64);
            GetClientAbsOrigin(destinationid,pos);
            ShowActivity2(client,"[SM] ", "Teleported %s to %s position",target_name, dest_name);
        }
        else
        {
            ReplyToCommand(client, "[SM] Cannot find destination player %s", destination);
            return Plugin_Handled;
        }
    }

    for (int i = 0; i < target_count; i++)
    {
        TeleportEntity(target_list[i],pos,NULL_VECTOR,NULL_VECTOR);
        //SetEntPropVector(target_list[i],Prop_Send,"m_vecOrigin",pos,0);
    }
    return Plugin_Handled;
}

public Action Command_Force_Ready(int client, int args)
{
    if (args < 2)
    {
        ReplyToCommand(client, "[SM] Usage: sm_force_ready <target> <1/0>");
        return Plugin_Handled;
    }
    char target[64];
    GetCmdArg(1, target, 64);

    char on[3];
    GetCmdArg(2, on, 3);

    char target_name[MAX_TARGET_LENGTH];
    int target_list[MAXPLAYERS], target_count;
    bool tn_is_ml;

    if ((target_count = ProcessTargetString(
                    target,
                    client,
                    target_list,
                    MAXPLAYERS,
                    COMMAND_FILTER_ALIVE,
                    target_name,
                    sizeof(target_name),
                    tn_is_ml)) <= 0)
    {
        ReplyToTargetError(client, target_count);
        return Plugin_Handled;
    }

    for (int i = 0; i < target_count; i++)
    {
        FakeClientCommand(target_list[i],"tournament_player_readystate %s",on);
    }
    ShowActivity2(client,"[SM] ", "Enforced ready state of %s to %s",target_name,on);
    return Plugin_Handled;
}

public Action Command_Password(int client, int args)
{
    if (args > 0) {
        char password[128];
        GetCmdArg(1, password, 128);
        if (!set_password)
            GetConVarString(FindConVar("sv_password"),old_password,64);

        if (strcmp(password,old_password) != 0) {
// ***REPLACED SRC PASSWORD***
// ***REPLACED SRC PASSWORD***
        }
        else {
// ***REPLACED SRC PASSWORD***
// ***REPLACED SRC PASSWORD***
        }
    }
    else {
        if (set_password) {
            char passwordcur[128];
            GetConVarString(FindConVar("sv_password"),passwordcur,128);
// ***REPLACED SRC PASSWORD***
        }
        else
        {
            ReplyToCommand(client, "[SM] Password is not set");
        }
    }
    return Plugin_Handled;
}
public void Wave_Restart() {
    if (!IsDuringWave()) {
        SetConVarBool(restart_game,true, true, false);
    }
    CreateTimer(1.0, RestartGameTimer);

}

public Action Command_Wave_Start(int client, int args)
{
    if (!IsDuringWave()) {
        SetConVarBool(restart_game,true, true, false);
        ShowActivity2(client,"[SM] ", "Force started the wave");
    }
    else
    {
        ReplyToCommand(client,"[SM] Wave already started");
    }
    return Plugin_Handled;
}

public bool IsDuringWave()
{
    int resource = FindEntityByClassname(-1,"tf_objective_resource");
    return GetEntProp(resource, Prop_Send,"m_bMannVsMachineBetweenWaves") == 0;
}
public Action PlayerLoseTimer(Handle timer) {
    int game_win = CreateEntityByName("game_round_win");
    DispatchSpawn(game_win);
    SetVariantInt(3);
    AcceptEntityInput(game_win,"SetTeam",-1,-1,0);
    AcceptEntityInput(game_win,"RoundWin",-1,-1,0);
}

public Action RestartGameTimer(Handle timer) {
    SetConVarBool(restart_game,true, true, false);
}

public Action Command_Population(int client, int args)
{
    if (args < 1)
    {

        ReplyToCommand(client, "[SM] Usage: sm_popfile <filename>");
        int resource = FindEntityByClassname(-1,"tf_objective_resource");
        char missionname[256];
        GetEntPropString(resource, Prop_Send,"m_iszMvMPopfileName", missionname,256);
        ReplyToCommand(client, "[SM] Current mission %s", missionname[FindCharInString(missionname,'/',true)+1]);

        return Plugin_Handled;
    }
    char name[128];
    GetCmdArg(1, name, 128);
    ServerCommand("tf_mvm_popfile %s",name);
    ReplyToCommand(client,"[SM] Opened population file %s", name);
    return Plugin_Handled;
}

public Action Command_Max_Players(int client, int args)
{
    ConVar max_def_con = FindConVar("sm_max_defenders");
    if (args < 1)
    {
        ReplyToCommand(client, "[SM] Usage: sm_max_players <player count>");
        return Plugin_Handled;
    }
    char maxnum[3];
    GetCmdArg(1, maxnum, 3);
    SetConVarString(max_def_con, maxnum);

    ShowActivity2(client,"[SM] ", "Set max player count to %s", maxnum);
    return Plugin_Handled;
}

public Action Command_Kill_Tank(int client, int args)
{
    if (args < 1)
    {
        ReplyToCommand(client, "[SM] Tank list:");

        int i = 0;
        int entity = -1;
        while ((entity = FindEntityByClassname(entity,"tank_boss")) != -1) {
            i++;
            ReplyToCommand(client, "%d. HP: %d/%d", i, GetEntProp(entity,Prop_Data, "m_iHealth"), GetEntProp(entity,Prop_Data, "m_iMaxHealth"));
        }

        return Plugin_Handled;
    }
    else if (CheckCommandAccess(client,"sm_kill_tank",0,false)) {
        char id[5];
        GetCmdArg(1, id, 5);

        int i = 0;
        int entity = -1;
        while ((entity = FindEntityByClassname(entity,"tank_boss")) != -1) {
            i++;
            if (i == StringToInt(id)) {
                DestroyClassNotOfTeam("tank_boss",2);

                ShowActivity2(client,"[SM] ", "Killed tank %d", i);
            }
        }
    }
    return Plugin_Handled;
}

public int MissionSelectMenuAction(Menu menu, MenuAction action, int param1, int param2)
{
    if(action == MenuAction_Select) {
        char popfile[256];
        char popfile2[256];
        int style;

        if(menu.GetItem(param2,popfile,256, style,popfile2,256)){
            //PrintToChat(param1,"%s %s %d %d",popfile, popfile2, param1, param2);
            ServerCommand("tf_mvm_popfile %s",popfile);
            ShowActivity2(param1,"[SM] ", "Opened population file %s", popfile);
        }
        delete menu;
    }
    if (action == MenuAction_End)
        delete menu;
}
public Action Command_MissionMenu(int client, int args)
{
    DirectoryListing poplist = OpenDirectory("scripts/population",true,NULL_STRING);
    char filename[256];
    FileType type;

    Menu mission_menu = new Menu(MissionSelectMenuAction);
    mission_menu.SetTitle("Mission Menu");

    char map[128];
    GetCurrentMap(map, sizeof(map));
    while(poplist.GetNext(filename,256,type)) {
        //mission_menu.AddItem("file","dispf");
        if(type == FileType_File) {
            //mission_menu.AddItem(map,filename,ITEMDRAW_DEFAULT);
            if(strncmp(filename,map,strlen(map)) == 0 && strncmp(filename[strlen(filename)-4],".pop",4) == 0)
            {
                char noextname[256];
                strcopy(noextname,strlen(filename)-3,filename);

                mission_menu.AddItem(noextname,noextname[strlen(map)+1],ITEMDRAW_DEFAULT);
            }
        }
    }

    mission_menu.Display(client,40);

    return Plugin_Handled;

}

public Action Command_Addcash(int client, int args)
{
    if (args < 2)
    {
        ReplyToCommand(client, "[SM] Usage: sm_addcash <#userid|name> <credits>");
        return Plugin_Handled;
    }

    char moneys[7];
    GetCmdArg(2, moneys, 7);
    int money = StringToInt(moneys);

    char target_name[MAX_TARGET_LENGTH];
    GetCmdArg(1, target_name, MAX_TARGET_LENGTH);
    int target = FindTarget(client,target_name,false,true);

    /*char target_name[MAX_TARGET_LENGTH];
      int target_list[MAXPLAYERS], target_count;
      bool tn_is_ml;

      if ((target_count = ProcessTargetString(
      arg,
      client,
      target_list,
      MAXPLAYERS,
      COMMAND_FILTER_ALIVE,
      target_name,
      sizeof(target_name),
      tn_is_ml)) <= 0)
      {
      ReplyToTargetError(client, target_count);
      return Plugin_Handled;
      }

      for (int i = 0; i < target_count; i++)
      {
      PerformBeacon(client, target_list[i]);
      }*/
    if (IsClientConnected(target)){

        //SDKCall(add_cash_handle,money,target,false,true,false);
        SetEntProp(target, Prop_Send,"m_nCurrency",GetEntProp(target, Prop_Send,"m_nCurrency")+money);
    }
    ReplyToCommand(client,"[SM] Gave %i credits to %s", money, target_name);
    return Plugin_Handled;
}
public Action Command_Addcash_All(int client, int args)
{
    if (args < 1)
    {
        ReplyToCommand(client, "[SM] Usage: sm_addcash_all <credits>");
        return Plugin_Handled;
    }

    char moneys[6];
    GetCmdArg(1, moneys, 6);
    int money = StringToInt(moneys);
    SDKCall(add_cash_no_player_handle,money);
    ReplyToCommand(client,"[SM] Given %i credits to everybody", money);

    return Plugin_Handled;
}

public Action Command_JumpToWave(int client, int args)
{
    if (args < 1)
    {
        ReplyToCommand(client, "[SM] Usage: sm_wave <wave>");
        ReplyToCommand(client, "[SM] Current wave: %d", GetEntProp(FindEntityByClassname(-1,"tf_objective_resource"), Prop_Send,"m_nMannVsMachineWaveCount"));
        return Plugin_Handled;
    }
    char waves[4];
    GetCmdArg(1, waves, 4);
    int wave = StringToInt(waves)-1;

    int resource = FindEntityByClassname(-1,"tf_objective_resource");
    int max_wave = GetEntProp(resource, Prop_Send,"m_nMannVsMachineMaxWaveCount");

    if (wave < 0 || wave >= max_wave)
    {
        ReplyToCommand(client, "[SM] Wave number out of bounds [1,%d]",max_wave);
        return Plugin_Handled;
    }
    if (IsDuringWave()){
        SetConVarBool(restart_game,true, true, false);
        CreateTimer(1.0,JumpToWaveTimer, wave);
    }
    else{
        JumpToWave(wave);
    }

    ShowActivity2(client,"[SM] ", "Skipped to wave %i",wave+1);
    return Plugin_Handled;
}

public void JumpToWave(int wave){
    int info_populator = FindEntityByClassname(-1,"info_populator");
    SDKCall(jump_wave_handle, info_populator,wave, 1.0);
}

public Action JumpToWaveTimer(Handle timer, any wave) {
    JumpToWave(wave);
}

public Action Command_Collect_Cash(int client, int args)
{
    CollectCash();
    ShowActivity2(client,"[SM] ", "Collected all cash");
    return Plugin_Handled;
}

public Action CollectCash()
{
    int pack=0;
    int resource=FindEntityByClassname(-1,"tf_objective_resource");
    int worldmoney=GetEntProp(resource,Prop_Send,"m_nMvMWorldMoney");
    SDKCall(add_cash_handle,worldmoney,-1,true,false,false);
    SetEntProp(resource,Prop_Send,"m_nMvMWorldMoney",0);
    while((pack=FindEntityByClassname(pack,"item_currencypack_custom")) != -1){
        SetEntProp(pack, Prop_Send,"m_bDistributed",1);
        RemoveEntity(pack);
    }
}

public void DestroyClassNotOfTeam(char[] classname, int teamnum)
{
    int tank = 0;
    while((tank=FindEntityByClassname(tank,classname)) != -1){
        if (GetEntProp(tank,Prop_Send,"m_iTeamNum",1) != teamnum)
            SDKHooks_TakeDamage(tank, 0, 0, 999999.0, 0, -1);
    }
}

public Action Command_Panic(int client, int args)
{
    for (int i =1; i <= MaxClients; i++) {
        if (IsClientConnected(i) && IsFakeClient(i)){
            //SDKHooks_TakeDamage(i, 0, 0, 99999, 0, 0, -1);
            ForcePlayerSuicide(i);
        }
    }

    DestroyClassNotOfTeam("tank_boss",2);
    DestroyClassNotOfTeam("obj_sentrygun",2);
    DestroyClassNotOfTeam("obj_teleporter",2);
    DestroyClassNotOfTeam("obj_dispenser",2);

    CollectCash();
    ShowActivity2(client,"[SM] ", "Pressed the panic button");
    return Plugin_Handled;
}
public bool FilterPlayer(int entity, int contentsMosk, int shooter)
{
    return entity != shooter;
}
public Action Command_Ent_Fire(int client, int args)
{
    if (args < 2)
    {
        ReplyToCommand(client, "[SM] Usage: sm_ent_fire <target> <input> [param]");
        return Plugin_Handled;
    }

    char target[64];
    GetCmdArg(1, target, 64);
    char input[64];
    GetCmdArg(2, input, 64);
    char param[256];
    GetCmdArg(3, param, 256);

    if (strcmp(target, "!picker") == 0) {
        float start[3];
        float angle[3];
        float end[3];
        GetClientEyePosition(client, start); 
        GetClientEyeAngles(client, angle); 
        TR_TraceRayFilter(start, angle, MASK_SOLID, RayType_Infinite,FilterPlayer,client);
        int entity = TR_GetEntityIndex(INVALID_HANDLE);
        if (entity > 0) 
        { 
            TR_GetEndPosition(end, INVALID_HANDLE); 
            SetVariantString(param);
            AcceptEntityInput(entity,input,client,client);
        } 
    }
    else {
        int ref = CreateEntityByName("logic_relay");
        DispatchSpawn(ref);
        if (strcmp(target,"!self") == 0)
            target = "!activator";
        char addoutput[512];
        Format(addoutput,512,"%s,%s,%s,0,-1",target,input,param);
        DispatchKeyValue(ref, "ontrigger", addoutput);
        AcceptEntityInput(ref, "trigger",client,client);

        RemoveEntity(ref);
    }

    ReplyToCommand(client,"[SM] Activated input %s of %s",input,target);
    return Plugin_Handled;
}

public Action Command_Ent_Fire_Player(int client, int args)
{
    if (args < 2)
    {
        ReplyToCommand(client, "[SM] Usage: sm_ent_fire_player <target> <input> [param]");
        return Plugin_Handled;
    }
    char target[64];
    GetCmdArg(1, target, 64);
    char input[64];
    GetCmdArg(2, input, 64);
    char param[256];
    GetCmdArg(3, param, 256);
    char target_name[MAX_TARGET_LENGTH];
    int target_list[MAXPLAYERS], target_count;
    bool tn_is_ml;

    if ((target_count = ProcessTargetString(
                    target,
                    client,
                    target_list,
                    MAXPLAYERS,
                    COMMAND_FILTER_ALIVE,
                    target_name,
                    sizeof(target_name),
                    tn_is_ml)) <= 0)
    {
        ReplyToTargetError(client, target_count);
        return Plugin_Handled;
    }

    for (int i = 0; i < target_count; i++)
    {
        SetVariantString(param);
        AcceptEntityInput(target_list[i], input,client,client);
        if (strcmp(input,"setcustommodel", false) == 0) {
            SetEntProp(target_list[i], Prop_Send, "m_bUseClassAnimations",1);
        }
    }
    ReplyToCommand(client,"[SM] Activated input %s of %s",input,target_name);
    return Plugin_Handled;
}


public Action Command_Addcond(int client, int args)
{
    if (args < 1)
    {
        ReplyToCommand(client, "[SM] Usage: sm_addcond <target> <cond> [duration]");
        return Plugin_Handled;
    }
    char target[64];
    char conds[4];
    if (args > 1) {
        GetCmdArg(1, target, 64);
        GetCmdArg(2, conds, 4);
    }
    else {
        target = "@me";
        GetCmdArg(1, conds, 4);
    }

    int cond = StringToInt(conds);
    float time = TFCondDuration_Infinite;

    if (args > 2)
    {
        char times[8];
        GetCmdArg(3, times, 8);
        time = StringToFloat(times);
    }

    char target_name[MAX_TARGET_LENGTH];
    int target_list[MAXPLAYERS], target_count;
    bool tn_is_ml;

    if ((target_count = ProcessTargetString(
                    target,
                    client,
                    target_list,
                    MAXPLAYERS,
                    COMMAND_FILTER_ALIVE,
                    target_name,
                    sizeof(target_name),
                    tn_is_ml)) <= 0)
    {
        ReplyToTargetError(client, target_count);
        return Plugin_Handled;
    }

    for (int i = 0; i < target_count; i++)
    {
        TF2_AddCondition(target_list[i], view_as<TFCond>(cond), time, 0);
    }

    ReplyToCommand(client,"[SM] Added condition #%i to %s for a duration of %.0f seconds",cond,target_name,time);
    return Plugin_Handled;
}

public Action Command_Removecond(int client, int args)
{
    if (args < 2)
    {
        ReplyToCommand(client, "[SM] Usage: sm_removecond <target> <cond>");
        return Plugin_Handled;
    }
    char target[64];
    GetCmdArg(1, target, 64);
    char conds[4];
    GetCmdArg(2, conds, 4);
    int cond = StringToInt(conds);

    char target_name[MAX_TARGET_LENGTH];
    int target_list[MAXPLAYERS], target_count;
    bool tn_is_ml;

    if ((target_count = ProcessTargetString(
                    target,
                    client,
                    target_list,
                    MAXPLAYERS,
                    COMMAND_FILTER_ALIVE,
                    target_name,
                    sizeof(target_name),
                    tn_is_ml)) <= 0)
    {
        ReplyToTargetError(client, target_count);
        return Plugin_Handled;
    }

    for (int i = 0; i < target_count; i++)
    {
        TF2_RemoveCondition(target_list[i], view_as<TFCond>(cond));
    }
    ReplyToCommand(client,"[SM] ", "Removed condition #%i from %s",cond,target_name);
    return Plugin_Handled;
}

public Action Command_AddAttr(int client, int args)
{
    if (args < 3)
    {
        ReplyToCommand(client, "[SM] Usage: sm_addattr <target> <attribute index|name> <value> [weapon slot]");
        return Plugin_Handled;
    }
    char target[64];
    GetCmdArg(1, target, 64);
    char attrs[256];
    GetCmdArg(2, attrs, 256);
    int attr = StringToInt(attrs);

    char values[32];
    GetCmdArg(3, values, 32);
    float value = StringToFloat(values);

    int weaponslot = -1;
    if (args > 3){
        char slots[3];
        GetCmdArg(4, slots, 3);
        weaponslot = StringToInt(slots);
    }
    char target_name[MAX_TARGET_LENGTH];
    int target_list[MAXPLAYERS], target_count;
    bool tn_is_ml;

    if ((target_count = ProcessTargetString(
                    target,
                    client,
                    target_list,
                    MAXPLAYERS,
                    COMMAND_FILTER_ALIVE,
                    target_name,
                    sizeof(target_name),
                    tn_is_ml)) <= 0)
    {
        ReplyToTargetError(client, target_count);
        return Plugin_Handled;
    }

    //char inv[256];
    //inv = "input";

    //int outv = 0;
    //outv = SDKCall(alloc_pooled_string_handle,values);

    //PrintToChat(client,"fff%df",outv);

    for (int i = 0; i < target_count; i++)
    {
        int entindex = target_list[i];
        if (weaponslot != -1){
            entindex = GetPlayerWeaponSlot(entindex,weaponslot);
            if (entindex == -1)
                entindex = target_list[i];
        }
        if (attr == 0)
            TF2Attrib_SetByName(entindex,attrs,value);
        else {
            //TF2Attrib_SetByDefIndex(entindex,attr,view_as<float>(outv));
            if (TF2Attrib_IsIntegerValue(attr))
                TF2Attrib_SetByDefIndex(entindex,attr,view_as<float>(RoundFloat(value)));
            else
                TF2Attrib_SetByDefIndex(entindex,attr,value);
        }
    }
    ReplyToCommand(client,"[SM] ", "Added attribute %s = %f to %s",attrs,value,target_name);
    return Plugin_Handled;
}

public Action Command_RemoveAttr(int client, int args)
{
    if (args < 2)
    {
        ReplyToCommand(client, "[SM] Usage: sm_removeattr <target> <attribute index | attribute name | all> [weapon slot]");
        return Plugin_Handled;
    }
    char target[64];
    GetCmdArg(1, target, 64);
    char attrs[256];
    GetCmdArg(2, attrs, 256);
    int attr = StringToInt(attrs);

    int weaponslot = -1;
    if (args > 2){
        char slots[3];
        GetCmdArg(3, slots, 3);
        weaponslot = StringToInt(slots);
    }

    char target_name[MAX_TARGET_LENGTH];
    int target_list[MAXPLAYERS], target_count;
    bool tn_is_ml;

    if ((target_count = ProcessTargetString(
                    target,
                    client,
                    target_list,
                    MAXPLAYERS,
                    COMMAND_FILTER_ALIVE,
                    target_name,
                    sizeof(target_name),
                    tn_is_ml)) <= 0)
    {
        ReplyToTargetError(client, target_count);
        return Plugin_Handled;
    }

    for (int i = 0; i < target_count; i++)
    {
        int entindex = target_list[i];
        if (weaponslot != -1){
            entindex = GetPlayerWeaponSlot(entindex,weaponslot);
            if (entindex == -1)
                entindex = target_list[i];
        }
        if (strcmp(attrs,"all",false) == 0)
            TF2Attrib_RemoveAll(entindex);
        else{
            if (attr == 0)
                TF2Attrib_RemoveByName(entindex,attrs);
            else {
                TF2Attrib_RemoveByDefIndex(entindex,attr);
            }
        }
    }
    ReplyToCommand(client,"[SM] ", "Removed attribute %s from %s",attrs,target_name);
    return Plugin_Handled;
}

public Action Command_Team(int client, int args)
{
    if (args < 2)
    {
        ReplyToCommand(client, "[SM] Usage: sm_team <target> <team>");
        return Plugin_Handled;
    }
    char target[64];
    GetCmdArg(1, target, 64);
    char teams[16];
    GetCmdArg(2, teams, 16);

    int teamnum= FindTeamByName(teams);

    if (teamnum == -1) {
        ReplyToCommand(client, "[SM] Invalid team name");
        return Plugin_Handled;
    }

    char teamname[16];
    GetTeamName(teamnum,teamname,16);
    char target_name[MAX_TARGET_LENGTH];
    int target_list[MAXPLAYERS], target_count;
    bool tn_is_ml;



    if ((target_count = ProcessTargetString(
                    target,
                    client,
                    target_list,
                    MAXPLAYERS,
                    COMMAND_FILTER_CONNECTED,
                    target_name,
                    sizeof(target_name),
                    tn_is_ml)) <= 0)
    {
        ReplyToTargetError(client, target_count);
        return Plugin_Handled;
    }

    for (int i = 0; i < target_count; i++)
    {
        if (teamnum == 2) {
            if (TF2_GetClientTeam(target_list[i]) == TFTeam_Red) return Plugin_Handled;
            int targetnum[MAXPLAYERS + 1] = { -1, ... };
            int count = 0;
            for (int j = 1; j <= MaxClients; j++)
            {
                if (!IsClientInGame(j)) continue;
                if (TF2_GetClientTeam(j) == TFTeam_Red)
                {
                    targetnum[count] = j;
                    count++;
                }
            }
            for (int j = 0; j < (count - 5); j++)
            {
                if (targetnum[j] != -1) SetEntProp(targetnum[j], Prop_Send, "m_iTeamNum", TFTeam_Blue);
            }
            TF2_ChangeClientTeam(target_list[i], TFTeam_Red);
            for (int j = 0; j < (count - 5); j++)
            {
                if (targetnum[j] != -1)
                {
                    SetEntProp(targetnum[j], Prop_Send, "m_iTeamNum", TFTeam_Red);
                    int flag = GetEntPropEnt(targetnum[j], Prop_Send, "m_hItem");
                    if (flag > MaxClients && IsValidEntity(flag))
                    {
                        if (view_as<TFTeam>(GetEntProp(flag, Prop_Send, "m_iTeamNum")) != TFTeam_Red) AcceptEntityInput(flag, "ForceDrop");
                    }
                }
            }

            int classType = (GetEntProp(target_list[i], Prop_Send, "m_iDesiredPlayerClass"));
            if (view_as<TFClassType>(classType) == TFClass_Unknown)
                ShowVGUIPanel(
                    target_list[i],
                    TF2_GetClientTeam(target_list[i]) == TFTeam_Blue 
                        ? "class_blue" : "class_red"
                );
        }
        else {
            int flags = GetEntityFlags(target_list[i]);
            if (teamnum == 3)
                SetEntityFlags(target_list[i], flags | FL_FAKECLIENT);
            ChangeClientTeam(target_list[i], teamnum);
            if (teamnum == 3)
                SetEntityFlags(target_list[i], flags &~ FL_FAKECLIENT);
        }
        //ChangeClientTeam(target_list[i],teamnum);
    }
    ReplyToCommand(client,"[SM] Moved %s to %s team",target_name,teamname);
    return Plugin_Handled;
}

public Action Command_Taunt(int client, int args)
{

    char target[64];
    GetCmdArg(1, target, 64);

    char target_name[MAX_TARGET_LENGTH];
    int target_list[MAXPLAYERS], target_count;
    bool tn_is_ml;

    if ((target_count = ProcessTargetString(
                    target,
                    client,
                    target_list,
                    MAXPLAYERS,
                    COMMAND_FILTER_CONNECTED,
                    target_name,
                    sizeof(target_name),
                    tn_is_ml)) <= 0)
    {
        ReplyToTargetError(client, target_count);
        return Plugin_Handled;
    }

    for (int i = 0; i < target_count; i++)
    {
        FakeClientCommand(target_list[i],"voicemenu 0 0");
    }
    ShowActivity2(client,"[SM] ", "Moved %s to %s team",target_name);
    return Plugin_Handled;
}

public void EquipWearable(int client, int modelid) 
{
    if (models_given_idwearable[client] != 0) {
        if (IsValidEntity(models_given_idwearable[client]))
            RemoveEntity(models_given_idwearable[client]);
        models_given_idwearable[client] = 0;
        models_given[client] = 0;
    }

    int wearable = CreateEntityByName("tf_wearable");
    SetEntProp(wearable, Prop_Send, "m_nModelIndex", modelid);
    SetEntProp(wearable, Prop_Send, "m_fEffects", 129);
    SetEntProp(wearable, Prop_Send, "m_iTeamNum", GetClientTeam(client));
    SetEntProp(wearable, Prop_Send, "m_nSkin", GetClientTeam(client));
    SetEntProp(wearable, Prop_Send, "m_usSolidFlags", 4);
    SetEntProp(wearable, Prop_Send, "m_CollisionGroup", 11);
    SetEntProp(wearable, Prop_Send, "m_iEntityQuality", 1);
    SetEntProp(wearable, Prop_Send, "m_iEntityLevel", -1);
    SetEntProp(wearable, Prop_Send, "m_iItemIDLow", 2048);
    SetEntProp(wearable, Prop_Send, "m_iItemIDHigh", 0);
    SetEntProp(wearable, Prop_Send, "m_bValidatedAttachedEntity", 1);
    SetEntProp(wearable, Prop_Send, "m_bInitialized", 1);
    SetEntProp(wearable, Prop_Send, "m_iAccountID", GetSteamAccountID(client));
    //SetEntPropEnt(wearable, Prop_Send, "moveparent",client);
    SetEntPropEnt(wearable, Prop_Send, "m_hOwnerEntity", client);
    DispatchSpawn(wearable);
    ActivateEntity(wearable);
    models_given[client] = modelid;
    models_given_idwearable[client] = EntIndexToEntRef(wearable);
    SDKCall(equip_wearable_handle, client, wearable);
}
public Action Command_Equip_Wearable_Model(int client, int args)
{
    if (args < 2)
    {
        ReplyToCommand(client, "[SM] Usage: sm_equip_wearable_model <target> <model>");
        return Plugin_Handled;
    }

    char target[64];
    GetCmdArg(1, target, 64);

    char model[256];
    GetCmdArg(2, model, 256);
    int modelid = 0;
    if (strlen(model) != 0)
        modelid = PrecacheModel(model, false);

    char target_name[MAX_TARGET_LENGTH];
    int target_list[MAXPLAYERS], target_count;
    bool tn_is_ml;

    if ((target_count = ProcessTargetString(
                    target,
                    client,
                    target_list,
                    MAXPLAYERS,
                    COMMAND_FILTER_CONNECTED,
                    target_name,
                    sizeof(target_name),
                    tn_is_ml)) <= 0)
    {
        ReplyToTargetError(client, target_count);
        return Plugin_Handled;
    }

    for (int i = 0; i < target_count; i++)
    {
        if (modelid == 0 && models_given_idwearable[target_list[i]] != 0) {
            if (IsValidEntity(models_given_idwearable[target_list[i]]))
                RemoveEntity(models_given_idwearable[target_list[i]]);
            models_given_idwearable[target_list[i]] = 0;
            models_given[target_list[i]] = 0;
        }
        else
            EquipWearable(target_list[i],modelid);
    }

    ShowActivity2(client,"[SM] ", "Equipped model ",target_name);
    return Plugin_Handled;
}

public Action Command_Change_Bonemerge_Model(int client, int args)
{
    if (args < 2)
    {
        ReplyToCommand(client, "[SM] Usage: sm_change_bonemerge_model <target> <model vis> <model bones>");
        return Plugin_Handled;
    }

    char target[64];
    GetCmdArg(1, target, 64);

    char model[256];
    GetCmdArg(2, model, 256);
    int modelid = 0;
    if (strlen(model) != 0)
        modelid = PrecacheModel(model, false);

    char modelplayer[256];
    if (args > 2) {
        GetCmdArg(3, modelplayer, 256);
        //if (strlen(modelplayer) != 0)
        //	PrecacheModel(modelplayer, false);
    }
    //int modelid = PrecacheModel(model, false);

    char target_name[MAX_TARGET_LENGTH];
    int target_list[MAXPLAYERS], target_count;
    bool tn_is_ml;

    if ((target_count = ProcessTargetString(
                    target,
                    client,
                    target_list,
                    MAXPLAYERS,
                    COMMAND_FILTER_CONNECTED,
                    target_name,
                    sizeof(target_name),
                    tn_is_ml)) <= 0)
    {
        ReplyToTargetError(client, target_count);
        return Plugin_Handled;
    }

    for (int i = 0; i < target_count; i++)
    {
        if (modelid == 0 && models_given_idwearable[target_list[i]] != 0) {
            if (IsValidEntity(models_given_idwearable[target_list[i]]))
                RemoveEntity(models_given_idwearable[target_list[i]]);

            models_given_idwearable[target_list[i]] = 0;
            models_given[target_list[i]] = 0;
            SetVariantString("");
            AcceptEntityInput(target_list[i], "setcustommodel",target_list[i],target_list[i]);
            SetEntityRenderMode(target_list[i], RENDER_NORMAL);
            SetEntityRenderColor(target_list[i],255,255,255,255);
        }
        else {
            if (strlen(modelplayer) > 0) {
                SetVariantString(modelplayer);
                AcceptEntityInput(target_list[i], "setcustommodel",target_list[i],target_list[i]);
                SetEntProp(target_list[i], Prop_Send, "m_bUseClassAnimations",1);

                //SetEntityModel(target_list[i], modelplayer);
            }
            SetEntityRenderMode(target_list[i], RENDER_TRANSCOLOR);
            SetEntityRenderColor(target_list[i],255,255,255,0);
            EquipWearable(target_list[i],modelid);
        }
    }

    //ShowActivity2(client,"[SM] ", "Equipped model ",target_name);
    return Plugin_Handled;
}

/*
public Action Command_List_Entities(int client, int args)
{
    if (args < 1)
    {
        ReplyToCommand(client, "[SM] Usage: sm_list_entities <name>");
        return Plugin_Handled;
    }

    char target[64];

    for (int i = 0; i < GetMaxEntities(); i++)
        GetCmdArg(1, target, 64);
    //ShowActivity2(client,"[SM] ", "Equipped model ",target_name);
    return Plugin_Handled;
}
*/

public Action Command_Ent_Create(int client, int args)
{
    if (args < 1)
    {
        ReplyToCommand(client, "[SM] Usage: sm_ent_create <classname> [key] [value]");
        return Plugin_Handled;
    }

    char classname[64];
    GetCmdArg(1, classname, 64);

    float start[3];
    float angle[3];
    float end[3];
    GetClientEyePosition(client, start); 
    GetClientEyeAngles(client, angle); 
    TR_TraceRayFilter(start, angle, MASK_SOLID, RayType_Infinite,FilterPlayer,client);
    if (TR_DidHit(INVALID_HANDLE)) 
    { 
        TR_GetEndPosition(end, INVALID_HANDLE); 
    } 

    int entity =CreateEntityByName(classname);

    TeleportEntity(entity,end,NULL_VECTOR,NULL_VECTOR);

    char keyname[64];
    char keyvalue[128];
    for (int i = 3; i <= args; i+=2 ) {
        GetCmdArg(i, keyvalue, 128);
        GetCmdArg(i-1, keyname, 64);
        ReplyToCommand(client, "%s %s", keyname, keyvalue);
        DispatchKeyValue(entity, keyname, keyvalue);
    }

    DispatchSpawn(entity);
    ActivateEntity(entity);

    TeleportEntity(entity,end,NULL_VECTOR,NULL_VECTOR);

    float playerpos[3];
    GetEntPropVector(client, Prop_Send, "m_vecOrigin", playerpos);

    ReplyToCommand(client,"[SM] Created entity %s",classname);

    return Plugin_Handled;
}

public Action Command_Randomize_Name(int client, int args)
{
    char classname[64];
    GetCmdArg(1, classname, 64);

    int entity=-1;

    while ((entity=FindEntityByClassname(entity,classname)) != -1){
        char name[256];
        Format(name,256,"%s%d","random",GetURandomInt());
        DispatchKeyValue(entity,"targetname",name);
    }

    ShowActivity2(client,"[SM] ", "renamed all entities",classname);
    return Plugin_Handled;
}

public Action Command_Respec(int client, int args)
{

    char target[64];
    GetCmdArg(1, target, 64);

    char target_name[MAX_TARGET_LENGTH];
    int target_list[MAXPLAYERS], target_count;
    bool tn_is_ml;

    if ((target_count = ProcessTargetString(
                    target,
                    client,
                    target_list,
                    MAXPLAYERS,
                    COMMAND_FILTER_CONNECTED,
                    target_name,
                    sizeof(target_name),
                    tn_is_ml)) <= 0)
    {
        ReplyToTargetError(client, target_count);
        return Plugin_Handled;
    }

    for (int i = 0; i < target_count; i++)
    {
        SetEntProp(target_list[i],Prop_Send,"m_bInUpgradeZone",true);
        KeyValues kv = CreateKeyValues("MVM_Respec");
        FakeClientCommandKeyValues(target_list[i],kv);
        SetEntProp(target_list[i],Prop_Send,"m_bInUpgradeZone",false);
    }
    ShowActivity2(client,"[SM] ", "Refunded all upgrades of %s",target_name);
    return Plugin_Handled;
}

public Action Command_Anim(int client, int args)
{
    char arg1[255];
    GetCmdArg(1,arg1,255);
    char arg2[255];
    GetCmdArg(2,arg2,255);
    int sequence = StringToInt(arg1);
    int event = StringToInt(arg2);
    for (int i = 1; i < MaxClients; i++) {
        if (IsClientInGame(i)) {
            TE_Start("PlayerAnimEvent");
            TE_WriteNum("m_iPlayerIndex", i);
            TE_WriteNum("m_iEvent", event);
            TE_WriteNum("m_nData", sequence);
            TE_SendToAll();
        }
    }

    return Plugin_Handled;
}

public Action Command_Timescale(int client, int args)
{
    if (args < 1)
    {
        ReplyToCommand(client, "[SM] Usage: sm_timescale <timescale>");
        return Plugin_Handled;
    }
    char timescale[8];
    GetCmdArg(1, timescale, 8);

    float timescalef = StringToFloat(timescale);
    if (timescalef > 0.0) {
        SetConVarFloat(FindConVar("host_timescale"), timescalef);
        set_timescale = timescalef != 1.0;
    }
    return Plugin_Handled;
}

public Action Command_Pos(int client, int args)
{
    float start[3];
    float angle[3];
    float end[3];
    float pos[3];
    GetClientEyePosition(client, start); 
    GetClientEyeAngles(client, angle); 
    GetClientAbsOrigin(client, pos);

    ReplyToCommand(client, "Player origin:\n%f %f %f", pos[0], pos[1], pos[2]);

    TR_TraceRayFilter(start, angle, MASK_SOLID, RayType_Infinite,FilterPlayer,client);
    if (TR_DidHit(INVALID_HANDLE)) 
    { 
        TR_GetEndPosition(end, INVALID_HANDLE); 
        ReplyToCommand(client, "Aim target position:\n%f %f %f", end[0], end[1], end[2]);

        int sprite = PrecacheModel("materials/sprites/laser.vmt");
        int color[4] = {255, 255, 255, 255};
        TE_SetupBeamPoints(start, end, sprite, 0, 0, 0, 4.0, 3.0, 3.0, 7, 0.0, color, 0);
        TE_SendToClient(client);
        ReplyToCommand(client, "Mins:\n%f %f %f\nMaxs:\n%f %f %f\nSize:\n%f %f %f", start[0] < end[0] ? start[0] : end[0], start[1] < end[1] ? start[1] : end[1], start[2] < end[2] ? start[2] : end[2]
                , start[0] > end[0] ? start[0] : end[0], start[1] > end[1] ? start[1] : end[1], start[2] > end[2] ? start[2] : end[2]
                , FloatAbs(start[0] - end[0]), FloatAbs(start[1] - end[1]), FloatAbs(start[2] - end[2]));
    } 

    ReplyToCommand(client, "Look Angles:\n%f %f %f", angle[0], angle[1], angle[2]);

    return Plugin_Handled;
}

int g_lcolor[4] = {255, 255, 255, 255};
float g_bbox_pos1[3] = {0.0, 0.0, 0.0};
float g_bbox_pos2[3] = {0.0, 0.0, 0.0};
int g_bbox_client = 0;

public void AddLaser(float start[3], float end[3], int client)
{
    TE_SetupBeamPoints(start, end, g_lsprite, 0, 0, 0, 2.0, 3.0, 3.0, 1, 0.0, g_lcolor, 0);
    TE_SendToClient(client);
}

public Action Command_BBox(int client, int args)
{
    if (args == 0)
    {
        ReplyToCommand(client, "[SM] Usage: sm_bbox <look | clear> | <x1> <y1> <z1> <x2> <y2> <z2>");
        return Plugin_Handled;
    }

    if (args == 1)
    {
        char arg[16];
        GetCmdArg(1, arg, 16);
        if (strcmp(arg, "clear") == 0) {
            g_bbox_client = 0;
            ReplyToCommand(client, "[SM] Cleared bounding box");
            return Plugin_Handled;
        }
        else if(strcmp(arg, "look") == 0) {
            float angle[3];
            GetClientEyePosition(client, g_bbox_pos1); 
            GetClientEyeAngles(client, angle); 

            TR_TraceRayFilter(g_bbox_pos1, angle, MASK_SOLID, RayType_Infinite,FilterPlayer,client);
            if (TR_DidHit(INVALID_HANDLE)) 
            { 
                TR_GetEndPosition(g_bbox_pos2, INVALID_HANDLE);
                ReplyToCommand(client, "Mins:\n%f %f %f\nMaxs:\n%f %f %f\nSize:\n%f %f %f", g_bbox_pos1[0] < g_bbox_pos2[0] ? g_bbox_pos1[0] : g_bbox_pos2[0], g_bbox_pos1[1] < g_bbox_pos2[1] ? g_bbox_pos1[1] : g_bbox_pos2[1], g_bbox_pos1[2] < g_bbox_pos2[2] ? g_bbox_pos1[2] : g_bbox_pos2[2]
                        , g_bbox_pos1[0] > g_bbox_pos2[0] ? g_bbox_pos1[0] : g_bbox_pos2[0], g_bbox_pos1[1] > g_bbox_pos2[1] ? g_bbox_pos1[1] : g_bbox_pos2[1], g_bbox_pos1[2] > g_bbox_pos2[2] ? g_bbox_pos1[2] : g_bbox_pos2[2]
                        , FloatAbs(g_bbox_pos1[0] - g_bbox_pos2[0]), FloatAbs(g_bbox_pos1[1] - g_bbox_pos2[1]), FloatAbs(g_bbox_pos1[2] - g_bbox_pos2[2]));
            } 
        }
    }
    else
    {
        char xs[16];
        char ys[16];
        char zs[16];
        GetCmdArg(1, xs, 16);
        GetCmdArg(2, ys, 16);
        GetCmdArg(3, zs, 16);
        g_bbox_pos1[0] = StringToFloat(xs);
        g_bbox_pos1[1] = StringToFloat(ys);
        g_bbox_pos1[2] = StringToFloat(zs);

        GetCmdArg(4, xs, 16);
        GetCmdArg(5, ys, 16);
        GetCmdArg(6, zs, 16);

        g_bbox_pos2[0] = StringToFloat(xs); g_bbox_pos2[1] = StringToFloat(ys); g_bbox_pos2[2] = StringToFloat(zs);
    }

    g_bbox_client = client;

    return Plugin_Handled;
}

public Action RefreshBBoxTimer(Handle handle)
{
    if (g_bbox_client == 0 || (g_bbox_pos1[0] == g_bbox_pos2[0] && g_bbox_pos1[1] == g_bbox_pos2[1] && g_bbox_pos1[2] == g_bbox_pos2[2]))
        return Plugin_Continue;

    float pos1[3];
    float pos2[3];

    pos1[0] = g_bbox_pos1[0];
    pos1[1] = g_bbox_pos1[1];
    pos1[2] = g_bbox_pos1[2];
    pos2[0] = g_bbox_pos2[0];
    pos2[1] = g_bbox_pos1[1];
    pos2[2] = g_bbox_pos1[2];
    AddLaser(pos1, pos2, g_bbox_client);
    pos2[0] = g_bbox_pos1[0];
    pos2[1] = g_bbox_pos2[1];
    pos2[2] = g_bbox_pos1[2];
    AddLaser(pos1, pos2, g_bbox_client);
    pos2[0] = g_bbox_pos1[0];
    pos2[1] = g_bbox_pos1[1];
    pos2[2] = g_bbox_pos2[2];
    AddLaser(pos1, pos2, g_bbox_client);

    pos1[0] = g_bbox_pos2[0];
    pos1[1] = g_bbox_pos2[1];
    pos1[2] = g_bbox_pos2[2];
    pos2[0] = g_bbox_pos2[0];
    pos2[1] = g_bbox_pos2[1];
    pos2[2] = g_bbox_pos1[2];
    AddLaser(pos1, pos2, g_bbox_client);
    pos2[0] = g_bbox_pos1[0];
    pos2[1] = g_bbox_pos2[1];
    pos2[2] = g_bbox_pos2[2];
    AddLaser(pos1, pos2, g_bbox_client);
    pos2[0] = g_bbox_pos2[0];
    pos2[1] = g_bbox_pos1[1];
    pos2[2] = g_bbox_pos2[2];
    AddLaser(pos1, pos2, g_bbox_client);

    pos1[0] = g_bbox_pos1[0];
    pos1[1] = g_bbox_pos1[1];
    pos1[2] = g_bbox_pos2[2];
    pos2[0] = g_bbox_pos2[0];
    pos2[1] = g_bbox_pos1[1];
    pos2[2] = g_bbox_pos2[2];
    AddLaser(pos1, pos2, g_bbox_client);
    pos2[0] = g_bbox_pos1[0];
    pos2[1] = g_bbox_pos2[1];
    pos2[2] = g_bbox_pos2[2];
    AddLaser(pos1, pos2, g_bbox_client);

    pos1[0] = g_bbox_pos2[0];
    pos1[1] = g_bbox_pos2[1];
    pos1[2] = g_bbox_pos1[2];
    pos2[0] = g_bbox_pos1[0];
    pos2[1] = g_bbox_pos2[1];
    pos2[2] = g_bbox_pos1[2];
    AddLaser(pos1, pos2, g_bbox_client);
    pos2[0] = g_bbox_pos2[0];
    pos2[1] = g_bbox_pos1[1];
    pos2[2] = g_bbox_pos1[2];
    AddLaser(pos1, pos2, g_bbox_client);

    pos1[0] = g_bbox_pos2[0];
    pos1[1] = g_bbox_pos1[1];
    pos1[2] = g_bbox_pos1[2];
    pos2[0] = g_bbox_pos2[0];
    pos2[1] = g_bbox_pos1[1];
    pos2[2] = g_bbox_pos2[2];
    AddLaser(pos1, pos2, g_bbox_client);
    pos1[0] = g_bbox_pos1[0];
    pos1[1] = g_bbox_pos2[1];
    pos1[2] = g_bbox_pos1[2];
    pos2[0] = g_bbox_pos1[0];
    pos2[1] = g_bbox_pos2[1];
    pos2[2] = g_bbox_pos2[2];
    AddLaser(pos1, pos2, g_bbox_client);

    // Johnny 06/23/21, 16:00: I'm not sure if this is correct or not.
    //                         If BBox lasers suddenly stop working, this is why.
    return Plugin_Stop;
}
