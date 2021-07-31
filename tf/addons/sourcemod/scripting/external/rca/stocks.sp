char g_BaseChatColor[6];

int g_Quality[MAXQUALITIES][QualityEnum];
int g_Unusual[MAXUNUSUALS][UnusualEnum];
int g_Attributes[MAXATTRIBUTES][AttributeEnum];
char g_AttrGroupValues[MAXATTRGROUPS][MAXAGROUPVALUES][64];
int g_CustomAttrGroupUse[MAXATTRGROUPS];
int Items[MAXITEMS][ItemCacheEnum];
Handle g_Collections[MAXCOLLECTIONS];

Handle g_cvWeaponsBlue;
Handle g_cvWeaponsRed;
Handle g_cvPets;

char TokenChars[] = "aAbBcCdDeEfFgGhHiIjJkKlLmMnNoOpPqQrRsStTuUvVwWxXyYzZ0123456789";

char g_Broadcast[][]={
	//"\x05[INFO] \x01Активируйте контракт на сайте \x05creators.tf\x01 во вкладке КонТракер",
	"\x05[INFO] \x01Напишите \x05!pack\x01, чтобы открыть серверный инвентарь",
	"\x05[INFO] \x01Обменять полученные \x05МунКоины\x01 на предметы можно в \x05!store",
	"\x05[INFO] \x01Чтобы посмотреть текущий прогресс сбора тыкв напишите \x05!collect",
	"\x05[INFO] \x01Интересно почему это вдруг у нас тут теперь хеллоуин? Читать тут: \x05http://creators.tf/s/tac2"
};

char GiveStrings[][]= {
	"\x05%s \x03has received \x07%s%s%s \x03from staff",
	"\x05%N \x03has purchased \x07%s%s%s \x03from \x07%s%s",
	"\x05%N \x03has opened \x07%s%s%s \x03and received \x07%s%s%s",
	"\x05%N \x03has received \x07%s%s%s \x03as a timed drop",
	"\x05%N \x03has completed '\x05%s' \x03and received \x07%s%s%s"
};

char g_SoundsQuest[][] = {
	"Quest.StatusTickNovice",
	"Quest.StatusTickAdvanced",
	"Quest.StatusTickExpert"
};

char g_SoundsQuestCompleted[][] = {
	"Quest.StatusTickNoviceComplete",
	"Quest.StatusTickAdvancedComplete",
	"Quest.StatusTickExpertComplete"
};

stock FindTargetBySteamID(char[] steamid)
{
	for (new i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && IsClientAuthorized(i))
		{
			char szAuth[256];
			GetClientAuthId(i,AuthId_SteamID64, szAuth, sizeof(szAuth));
			if (StrEqual(szAuth, steamid))return i;
		}
	}
	return -1;
}

stock IsPlayerSpectator(int client)
{
	if (DEBUG == 1)PrintToServer("IsPlayerSpectator");
	if(0<client<MaxClients && IsClientInGame(client))
	{
		if (GetClientTeam(client) == 1)return true;
		if (GetClientTeam(client) == 0)return true;
		return false;
	}
	return false;
}

public bool IsInteger(char[] buffer)
{
    int len = strlen(buffer);
    for (new i = 0; i < len; i++)
    {
        if ( !IsCharNumeric(buffer[i]) )
            return false;
    }

    return true;    
}

public int Pack_GetRandomUnusual(int type)
{
	if (DEBUG == 1)PrintToServer("Pack_GetRandomUnusual");
	Handle coll = CreateArray();
	for (new i = 1; i < MAXUNUSUALS; i++)
	{
		if (g_Unusual[i][iIndex] != i)continue;
		if (g_Unusual[i][iType] != type)continue;
		PushArrayCell(coll, i);
	}
	return GetArrayCell(coll, GetRandomInt(0, GetArraySize(coll) - 1));
}

stock Generate_UserToken(char[] string, int size = 32)
{
	if (DEBUG == 1)PrintToServer("Generate_UserToken");
	new iStringSize = sizeof(TokenChars) - 1;
	new String:buffer[size+1];
	for (new i = 0; i < size; i++) {
		new iRandom = GetRandomInt(0, iStringSize);
		Format(buffer, size+1, "%s%c", buffer, TokenChars[iRandom]);
	}
	strcopy(string, 32, buffer);
}
OffsetLocation(Float:pos[3], float offset = 128.0)
{
	pos[0] += GetRandomFloat(-offset, offset);
	pos[1] += GetRandomFloat(-offset, offset);
}

stock any:Math_Clamp(any:value, any:min, any:max) // Thanks to SMLIB for this stock!
{
	value = Math_Min(value, min);
	value = Math_Max(value, max);

	return value;
}

stock any:Math_Min(any:value, any:min) // Thanks to SMLIB for this stock!
{
	if (value < min) {
		value = min;
	}
	
	return value;
}

stock any:Math_Max(any:value, any:max) // Thanks to SMLIB for this stock!
{	
	if (value > max) {
		value = max;
	}
	
	return value;
}

stock int GetSlotForMulticlass(int class, int slot)
{
	if (DEBUG == 1)PrintToServer("GetSlotForMulticlass");
	if(slot == 0){
		switch(class){
			case TFClass_Scout:return _:SLOT_SCOUT_PRIMARY;
			case TFClass_Soldier:return _:SLOT_SOLDIER_PRIMARY;
			case TFClass_Pyro:return _:SLOT_PYRO_PRIMARY;
			case TFClass_DemoMan:return _:SLOT_DEMOMAN_PRIMARY;
			case TFClass_Heavy:return _:SLOT_HEAVY_PRIMARY;
			case TFClass_Engineer:return _:SLOT_ENGINEER_PRIMARY;
			case TFClass_Medic:return _:SLOT_MEDIC_PRIMARY;
			case TFClass_Sniper:return _:SLOT_SNIPER_PRIMARY;
			case TFClass_Spy:return _:SLOT_SPY_PRIMARY;
		}	
	}else if(slot == 1){
		switch(class){
			case TFClass_Scout:return _:SLOT_SCOUT_SECONDARY;
			case TFClass_Soldier:return _:SLOT_SOLDIER_SECONDARY;
			case TFClass_Pyro:return _:SLOT_PYRO_SECONDARY;
			case TFClass_DemoMan:return _:SLOT_DEMOMAN_SECONDARY;
			case TFClass_Heavy:return _:SLOT_HEAVY_SECONDARY;
			case TFClass_Engineer:return _:SLOT_ENGINEER_SECONDARY;
			case TFClass_Medic:return _:SLOT_MEDIC_SECONDARY;
			case TFClass_Sniper:return _:SLOT_SNIPER_SECONDARY;
			case TFClass_Spy:return _:SLOT_SPY_SECONDARY;
		}	
	}else if(slot == 2){
		switch(class){
			case TFClass_Scout:return _:SLOT_SCOUT_MELEE;
			case TFClass_Soldier:return _:SLOT_SOLDIER_MELEE;
			case TFClass_Pyro:return _:SLOT_PYRO_MELEE;
			case TFClass_DemoMan:return _:SLOT_DEMOMAN_MELEE;
			case TFClass_Heavy:return _:SLOT_HEAVY_MELEE;
			case TFClass_Engineer:return _:SLOT_ENGINEER_MELEE;
			case TFClass_Medic:return _:SLOT_MEDIC_MELEE;
			case TFClass_Sniper:return _:SLOT_SNIPER_MELEE;
			case TFClass_Spy:return _:SLOT_SPY_MELEE;
		}	
	}else if(slot == 3){
		switch(class){
			case TFClass_Scout:return -1;
			case TFClass_Soldier:return -1;
			case TFClass_Pyro:return -1;
			case TFClass_DemoMan:return -1;
			case TFClass_Heavy:return -1;
			case TFClass_Engineer:return _:SLOT_ENGINEER_PDA;
			case TFClass_Medic:return -1;
			case TFClass_Sniper:return -1;
			case TFClass_Spy:return _:SLOT_SPY_SAPPER;
		}	
	}else if(slot == 4)
	{
		switch(class){
			case TFClass_Scout:return _:SLOT_SCOUT_PLAYERMODEL;
			case TFClass_Soldier:return _:SLOT_SOLDIER_PLAYERMODEL;
			case TFClass_Pyro:return _:SLOT_PYRO_PLAYERMODEL;
			case TFClass_DemoMan:return _:SLOT_DEMOMAN_PLAYERMODEL;
			case TFClass_Heavy:return _:SLOT_HEAVY_PLAYERMODEL;
			case TFClass_Engineer:return _:SLOT_ENGINEER_PLAYERMODEL;
			case TFClass_Medic:return _:SLOT_MEDIC_PLAYERMODEL;
			case TFClass_Sniper:return _:SLOT_SNIPER_PLAYERMODEL;
			case TFClass_Spy:return _:SLOT_SPY_PLAYERMODEL;
		}	
	}
	return -1;
}

public int mBackpack(Menu menu, MenuAction action, int param1, int param2)
{
	if (DEBUG == 1)PrintToServer("mBackpack");
	if (action == MenuAction_Select)
	{
		//ClientCommand(param1,"playgamesound ui/buttonclick.wav");
		char info[32];
		menu.GetItem(param2, info, sizeof(info));
		if(StrContains(info,"view") != -1){
			new String:_strExploded[2][255];
			ExplodeString(info, "view", _strExploded, 2, 255);
			ClientCommand(param1, "sm_view %d",StringToInt(_strExploded[1]));
		}
		
		if(StrContains(info,"equip") != -1){
			new String:_strExploded[2][255];
			ExplodeString(info, "equip", _strExploded, 2, 255);
			//PrintToConsole(param1,"wooow");
			ClientCommand(param1, "sm_equip %d",StringToInt(_strExploded[1]));
		}
		
		if(StrContains(info,"holster") != -1){
			new String:_strExploded[2][255];
			ExplodeString(info, "holster", _strExploded, 2, 255);
			ClientCommand(param1, "sm_holster %d",StringToInt(_strExploded[1]));
		}
		
		if(StrContains(info,"buy") != -1){
			new String:_strExploded[3][255];
			ExplodeString(info, "buy", _strExploded, 3, 255);
			Pack_OpenBuyMenu(param1, StringToInt(_strExploded[1]), StringToInt(_strExploded[2]));
		}
		
		if(StrContains(info,"purc") != -1){
			new String:_strExploded[3][255];
			ExplodeString(info, "purc", _strExploded, 3, 255);
			Pack_BuyItem(param1, StringToInt(_strExploded[1]), StringToInt(_strExploded[2]));
		}
		
		if(StrContains(info,"crate") != -1){
			new String:_strExploded[3][255];
			ExplodeString(info, "crate", _strExploded, 3, 255);
			Pack_OpenCaseMenu(param1, StringToInt(_strExploded[1]), StringToInt(_strExploded[2]));
		}
		
		if(StrContains(info,"decode") != -1){
			new String:_strExploded[3][255];
			ExplodeString(info, "decode", _strExploded, 3, 255);
			Pack_OpenCase(param1, StringToInt(_strExploded[1]), StringToInt(_strExploded[2]));
		}
		
		if(StrContains(info,"delete") != -1){
			new String:_strExploded[2][255];
			ExplodeString(info, "delete", _strExploded, 2, 255);
			ClientCommand(param1, "sm_del %d",StringToInt(_strExploded[1]));
		}
		
		if(StrContains(info,"confdel") != -1){
			new String:_strExploded[2][255];
			ExplodeString(info, "confdel", _strExploded, 2, 255);
			ClientCommand(param1, "sm_confdel %d",StringToInt(_strExploded[1]));
		}
		
		if(StrContains(info,"backpack") != -1){
			ClientCommand(param1, "sm_pack");
		}
		
		if(StrContains(info,"store") != -1){
			new String:_strExploded[2][255];
			ExplodeString(info, "store", _strExploded, 2, 255);
			OpenStore(param1,StringToInt(_strExploded[1]));
		}
		
		if(StrEqual(info,"turnin")){
			Contracts_TurnIn(param1);
		}
	}
	/* If the menu was cancelled, print a message to the server about it. */
	else if (action == MenuAction_Cancel)
	{
		//PrintToServer("Client %d's menu was cancelled.  Reason: %d", param1, param2);
	}
	/* If the menu has ended, destroy it */
	else if (action == MenuAction_End)
	{
		delete menu;
	}
}

stock GetActivePlayerSlot(iClient)
{
	if (DEBUG == 1)PrintToServer("GetActivePlayerSlot");
    for (new i = 0; i <= 5; i++)
    {
        if (GetEntPropEnt(iClient, Prop_Send, "m_hActiveWeapon") == GetPlayerWeaponSlot(iClient, i))
        {
            return i;
        }
    }
    return -1;
}  

stock IsValidPlayer(int client)
{
	if (DEBUG == 1)PrintToServer("IsValidPlayer");
	if (0 < client <= MaxClients)return true;
	return false;
}


stock Pack_ParseAttributes(char[] buffer, int size, char[] sBaseAttributes, char[] sOverlapAttributes)
{
	if (DEBUG == 1)PrintToServer("Pack_ParseAttributes");
	new String:pre[size];
	new t_AttrsValues[MAXATTRIBUTES];
	new String:atts[MAXATTRIBUTES][11];
	new count = ExplodeString(sBaseAttributes, " ; ", atts, MAXATTRIBUTES, 11);
	if (count > 0)
	{
		for (new i = 0; i < count; i+=2)
		{
			t_AttrsValues[StringToInt(atts[i])] = StringToInt(atts[i + 1]);
		}
	}
	count = ExplodeString(sOverlapAttributes, " ; ", atts, MAXATTRIBUTES, 11);
	if (count > 0)
	{
		for (new i = 0; i < count; i+=2)
		{
			t_AttrsValues[StringToInt(atts[i])] = StringToInt(atts[i + 1]);
		}
	}
	for (new i = 1; i < MAXATTRIBUTES; i++)
	{
		if(t_AttrsValues[i]>0 && !g_Attributes[i][bHidden]){
			new String:_format[128];
			new String:_value[64];
			if(g_Attributes[i][iGroup]>0){
				if(g_CustomAttrGroupUse[g_Attributes[i][iGroup]] == _:USE_ITEM_NAMES){
					//PrintToChatAll("%s", Items[t_AttrsValues[i]][sName]);
					Format(_value, 64, "%s", Items[t_AttrsValues[i]][sName]);
				}else if(g_CustomAttrGroupUse[g_Attributes[i][iGroup]] == _:USE_UNUSUAL_NAMES){
					Format(_value, 64, "%s", g_Unusual[t_AttrsValues[i]][sName]);
				}else{
					Format(_value, 64, "%s", g_AttrGroupValues[g_Attributes[i][iGroup]][t_AttrsValues[i]]);
				}
			}else{
				Format(_value, 64, "%d", t_AttrsValues[i]);
			}
			Format(_format, 128, g_Attributes[i][sDesc], _value);
			Format(pre, size, "%s%s\n", pre,_format);
		}
	}
	ReplaceString(pre, size, "\\n", "\n");
	ReplaceString(pre, size, "%", "%%%");
	StrCat(pre, size, "\n ");
	strcopy(buffer, size, pre);
}

public bool IsValidLink(int entity)
{
	if (DEBUG == 1)PrintToServer("IsValidLink");
	if (entity > 0)
	{
		char strName[16];
		GetEntPropString(entity, Prop_Data, "m_iName", strName, 16);
		if (StrEqual(strName, "tf2_playerlink", true))
		{
			return true;
		}
	}
	return false;
}

stock int CreateRootLink(int iClient)
{
	if (DEBUG == 1)PrintToServer("CreateRootLink");
    float flPos[3];
    GetClientAbsOrigin(iClient, flPos);
	int iLink = CreateEntityByName("tf_taunt_prop");
	DispatchKeyValue(iLink, "targetname", "tf2_playerlink");
	DispatchSpawn(iLink); 
	SetEntityModel(iLink, "models/player/scout.mdl");
	SetEntProp(iLink, Prop_Send, "m_fEffects", 16|64);
	TeleportEntity(iLink, flPos, NULL_VECTOR, NULL_VECTOR);
	SetVariantString("!activator"); 
	AcceptEntityInput(iLink, "SetParent", iClient); 
	return iLink;
}

stock int CreateLink(int iClient, char attach[] = "flag")
{
	if (DEBUG == 1)PrintToServer("CreateLink");
	int iLink = CreateEntityByName("tf_taunt_prop");
	DispatchKeyValue(iLink, "targetname", "tf2_playerlink");
	DispatchSpawn(iLink); 
	SetEntityModel(iLink, "models/empty.mdl");
	SetEntProp(iLink, Prop_Send, "m_fEffects", 16|64);
	SetVariantString("!activator"); 
	AcceptEntityInput(iLink, "SetParent", iClient); 
	SetVariantString(attach);
	AcceptEntityInput(iLink, "SetParentAttachment", iClient);
	float flAng[3] = { 0.0, 0.0, 90.0 };
	TeleportEntity(iLink, NULL_VECTOR, flAng, NULL_VECTOR);
	
	return iLink;
}

stock CreateParticleAttachment(int entity, String:particle[], Float:offset[3])
{
	if (DEBUG == 1)PrintToServer("CreateParticleAttachment");
	int iParticle = CreateEntityByName("info_particle_system"); 
	if (IsValidEdict(iParticle)) 
	{ 
		float flPos[3];
		GetEntPropVector(entity, Prop_Send, "m_vecOrigin", flPos);
		flPos[0]+= offset[0];
		flPos[1]+= offset[1];
		flPos[2]+= offset[2];
		TeleportEntity(iParticle, flPos, NULL_VECTOR, NULL_VECTOR);
		
		DispatchKeyValue(iParticle, "targetname", "tf_pet_particle"); 
		DispatchKeyValue(iParticle, "effect_name", particle); 

		SetVariantString("!activator");
		AcceptEntityInput(iParticle, "SetParent", entity, entity);
		DispatchSpawn(iParticle); 
		ActivateEntity(iParticle);
		AcceptEntityInput(iParticle, "Start"); 
    } 
	return iParticle; 
}

public SQLT_Fast(Handle:hOwner, Handle:hQuery, const String:sError[], any data)
{
	if (DEBUG == 1)PrintToServer("SQLT_Fast");
    if (hQuery == INVALID_HANDLE) {
        LogError("[Database] SQL-Query failed! Error: %s", sError);
    } else {
        PrintToServer("[Database] Query success");
    }
	if (hQuery != INVALID_HANDLE) {
        CloseHandle(hQuery);
        hQuery = INVALID_HANDLE;
    }
	return;
}

stock int PrecacheParticleSystem(const char[] particleSystem)
{
    static int particleEffectNames = INVALID_STRING_TABLE;

    if (particleEffectNames == INVALID_STRING_TABLE) {
        if ((particleEffectNames = FindStringTable("ParticleEffectNames")) == INVALID_STRING_TABLE) {
            return INVALID_STRING_INDEX;
        }
    }

    int index = FindStringIndex2(particleEffectNames, particleSystem);
    if (index == INVALID_STRING_INDEX) {
        int numStrings = GetStringTableNumStrings(particleEffectNames);
        if (numStrings >= GetStringTableMaxStrings(particleEffectNames)) {
            return INVALID_STRING_INDEX;
        }
        
        AddToStringTable(particleEffectNames, particleSystem);
        index = numStrings;
    }
    
    return index;
}

stock int FindStringIndex2(int tableidx, const char[] str)
{
    char buf[1024];
    
    int numStrings = GetStringTableNumStrings(tableidx);
    for (int i=0; i < numStrings; i++) {
        ReadStringTable(tableidx, i, buf, sizeof(buf));
        
        if (StrEqual(buf, str)) {
            return i;
        }
    }
    
    return INVALID_STRING_INDEX;
}


stock RemoveValveHat(client, bool:unhide = false)
{
	new edict = MaxClients+1;
	while((edict = FindEntityByClassnameSafe(edict, "tf_wearable")) != -1)
	{
		decl String:netclass[32];
		if (GetEntityNetClass(edict, netclass, sizeof(netclass)) && strcmp(netclass, "CTFWearable") == 0)
		{
			new idx = GetEntProp(edict, Prop_Send, "m_iItemDefinitionIndex");
			if (idx != 57 && idx != 133 && idx != 231 && idx != 444 && idx != 405 && idx != 608 && idx != 642 && GetEntPropEnt(edict, Prop_Send, "m_hOwnerEntity") == client)
			{
				AcceptEntityInput(edict, "kill");
			}
		}
	}
	edict = MaxClients+1;
	while((edict = FindEntityByClassnameSafe(edict, "tf_powerup_bottle")) != -1)
	{
		decl String:netclass[32];
		if (GetEntityNetClass(edict, netclass, sizeof(netclass)) && strcmp(netclass, "CTFPowerupBottle") == 0)
		{
			new idx = GetEntProp(edict, Prop_Send, "m_iItemDefinitionIndex");
			if (idx != 57 && idx != 133 && idx != 231 && idx != 444 && idx != 405 && idx != 608 && idx != 642 && GetEntPropEnt(edict, Prop_Send, "m_hOwnerEntity") == client)
			{
				AcceptEntityInput(edict, "kill");
			}
		}
	}
}

stock FindEntityByClassnameSafe(iStart, const String:strClassname[])
{
	while (iStart > -1 && !IsValidEntity(iStart)) iStart--;
	return FindEntityByClassname(iStart, strClassname);
}

public ReadFileFolder(String:path[]){
	new Handle:dirh = INVALID_HANDLE;
	new String:buffer[256];
	new String:tmp_path[256];
	new FileType:type = FileType_Unknown;
	new len;
	
	len = strlen(path);
	if (path[len-1] == '\n')
		path[--len] = '\0';

	TrimString(path);
	
	if(DirExists(path)){
		dirh = OpenDirectory(path);
		while(ReadDirEntry(dirh,buffer,sizeof(buffer),type)){
			len = strlen(buffer);
			if (buffer[len-1] == '\n')
				buffer[--len] = '\0';

			TrimString(buffer);

			if (!StrEqual(buffer,"",false) && !StrEqual(buffer,".",false) && !StrEqual(buffer,"..",false)){
				strcopy(tmp_path,255,path);
				StrCat(tmp_path,255,"/");
				StrCat(tmp_path,255,buffer);
				if(type == FileType_File){
					ReadItem(tmp_path);
				}
				else{
					ReadFileFolder(tmp_path);
				}
			}
		}
	}
	else{
		ReadItem(path);
	}
	if(dirh != INVALID_HANDLE){
		CloseHandle(dirh);
	}
}

public ReadItem(String:buffer[]){
	new len = strlen(buffer);
	if (buffer[len-1] == '\n')
		buffer[--len] = '\0';
	
	TrimString(buffer);
	
	if(len >= 2 && buffer[0] == '/' && buffer[1] == '/'){
		if(StrContains(buffer,"//") >= 0){
			ReplaceString(buffer,255,"//","");
		}
	}
	else if (!StrEqual(buffer,"",false) && FileExists(buffer))
	{
		AddFileToDownloadsTable(buffer);
	}
}

stock int EquipWearable(int client, char[] Mdl, bool vm, int weapon = 0, bool visactive = true)
{
	// ^ bad name probably
	int wearable = CreateWearable(client, Mdl, vm);
	SetEntProp(wearable, Prop_Send, "m_bValidatedAttachedEntity", 1);

	if (wearable == -1)
	{
		return -1;
	}

	return wearable;
}

stock int CreateWearable(int client, char[] model, bool vm) // Randomizer code :3
{
	PrintToChatAll(model);
	int entity = CreateEntityByName(vm ? "tf_wearable_vm" : "tf_wearable");

	if (!IsValidEntity(entity))
	{
		return -1;
	}
	
	SetEntProp(entity, Prop_Send, "m_nModelIndex", PrecacheModel(model));
	SetEntProp(entity, Prop_Send, "m_fEffects", 129);
	SetEntProp(entity, Prop_Send, "m_iTeamNum", GetClientTeam(client));
	SetEntProp(entity, Prop_Send, "m_usSolidFlags", 4);
	SetEntProp(entity, Prop_Send, "m_CollisionGroup", 11);

	DispatchSpawn(entity);

	SetVariantString("!activator");
	ActivateEntity(entity);

	TF2_EquipWearable(client, entity); // urg
	return entity;
}

void TF2_EquipWearable(int client, int entity)
{
	if (g_hSdkEquipWearable == null)
	{
		LogMessage("Error: Can't call EquipWearable, SDK functions not loaded!");
		return;
	}

	SDKCall(g_hSdkEquipWearable, client, entity);
}
