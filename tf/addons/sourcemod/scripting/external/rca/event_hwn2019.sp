enum E_HWN2019_PickupEnum
{
	iId,
	Float:flPos[3],
}
#define HWN2019_MAXPICKUPS 128
#define HWN2019_MODEL "models/props_halloween/jackolantern_02.mdl"
#define EF_ITEM_BLINK 0x100

bool g_HWN2019_Collectables[MAXPLAYERS + 1][HWN2019_MAXPICKUPS];
int g_HWN2019_Items[5][E_HWN2019_PickupEnum];

public int Event_HWN2019_LoadData(int client)
{
	if(0<client<MaxClients && IsClientInGame(client))
	{
		for (new i = 0; i < HWN2019_MAXPICKUPS; i++)
		{
			g_HWN2019_Collectables[client][i] = false;
		}
		new String:szAuth[256];
		GetClientAuthId(client,AuthId_SteamID64, szAuth, sizeof(szAuth));
		new String:query[300];	
		Format(query, 300, "SELECT * FROM `tf_event_hwn2019` WHERE `steamid` = \'%s\'",szAuth);
	
		Handle queryH = SQL_Query(g_hDB, query);
		
		if(queryH != INVALID_HANDLE)
		{   
			while (SQL_FetchRow(queryH))
			{
				int Index = SQL_FetchInt(queryH, 1);
				g_HWN2019_Collectables[client][Index] = true;
			}
		}
	}
}

public int Event_HWN2019_CreateItem(Float:pos[3], int index)
{
	int ent = CreateEntityByName("prop_dynamic_override");
	if (IsValidEdict(ent))
	{
		TeleportEntity(ent, pos, NULL_VECTOR, NULL_VECTOR);
		PrecacheModel(HWN2019_MODEL);
		SetEntityModel(ent, HWN2019_MODEL);
		SetEntProp(ent, Prop_Data, "m_CollisionGroup", 2);
		SetEntProp(ent, Prop_Send, "m_nSolidType", 6);
		//SetEntProp(ent, Prop_Send, "m_fEffects", EF_ITEM_BLINK);
		char _name[16];
		Format(_name, 16, "tf2_collect_%d", index);
		DispatchKeyValue(ent, "targetname", _name);
		DispatchSpawn(ent);
		ActivateEntity(ent);
		SetEntPropFloat(ent, Prop_Data, "m_flModelScale", 0.4);
		SDKHook(ent, SDKHook_SetTransmit, Event_HWN2019_OnTransmit);
		return ent;
	}
	return 0;
}

public Action Event_HWN2019_OnTransmit(item, client) 
{ 
	if(g_HWN2019_Collectables[client][Event_HWN2019_GetItemIndex(item)])
	{
		return Plugin_Handled;
	}
    return Plugin_Continue;  
} 

public int Event_HWN2019_GetItemIndex(entity)
{
	if (entity > 0 && IsValidEdict(entity))
	{
		char strName[16];
		GetEntPropString(entity, Prop_Data, "m_iName", strName, 16);
		char _Buffer[2][11];
		ExplodeString(strName, "tf2_collect_", _Buffer, 2, 11);
		return StringToInt(_Buffer[1]);
	}
	return false;
}

public void Event_HWN2019_SpawnEggs()
{
	for (int i = 0; i < 5; i++)
	{
		if (g_HWN2019_Items[i][iId] == 0)break;
		float pos[3]; 
		pos[0] = g_HWN2019_Items[i][flPos][0];
		pos[1] = g_HWN2019_Items[i][flPos][1];
		pos[2] = g_HWN2019_Items[i][flPos][2];
		Event_HWN2019_CreateItem(pos, g_HWN2019_Items[i][iId]);
	}
}


public void Event_HWN2019_ReloadItems()
{
	for (int i = 0; i < 5; i++)
	{
		g_HWN2019_Items[i][iId] = 0;
	}
	char line[128];
	Handle hFile = OpenFile("cfg/hwn2019.cfg","r");
	bool _found;
	int i = 0;
	while(!IsEndOfFile(hFile) && ReadFileLine(hFile,line,sizeof(line)))
	{
		char ItemDataArray[6][256];
		ExplodeString(line, " ", ItemDataArray, 6, 256);
		if(!_found){
			if (!IsInteger(ItemDataArray[0])){
				if(StrContains(ItemDataArray[0],g_sMap)!=-1){
					_found = true;
				}
			}
		}else{
			if (IsInteger(ItemDataArray[0])){
				g_HWN2019_Items[i][flPos][0] = StringToFloat(ItemDataArray[1]);
				g_HWN2019_Items[i][flPos][1] = StringToFloat(ItemDataArray[2]);
				g_HWN2019_Items[i][flPos][2] = StringToFloat(ItemDataArray[3]);
				g_HWN2019_Items[i][iId] = StringToInt(ItemDataArray[0]);
				i++;
			} else { break;}
		}
	}
	CloseHandle(hFile);
}

public Action cEvent_HWN2019_Items(int client, int args)
{
	PrintToChat(client, "\x03Halloween | \x01У вас собрано \x5%d тыкв", Event_HWN2019_GetTotalPlayerEggs(client));
}

public Action Event_HWN2019_HitHook(int clients[64],
  int &numClients,
  char sample[PLATFORM_MAX_PATH],
  int &client,
  int &channel,
  float &volume,
  int &level,
  int &pitch,
  int &flags,
  char soundEntry[PLATFORM_MAX_PATH],
  int &seed)
{
	
	if(!(1<=client<=MaxClients) || !IsClientInGame(client))return Plugin_Continue;
	if(StrContains(sample, "hit", false ) != -1 || StrContains(sample, "impact", false) != -1)
	{
		int ent = GetClientAimTarget(client, false);

		if (IsValidEntity(ent))
		{
			float EntPos[3];
			float ClientPos[3];
			GetEntPropVector(ent, Prop_Send, "m_vecOrigin", EntPos);
			GetEntPropVector(client, Prop_Send, "m_vecOrigin", ClientPos);
			float Distance = GetVectorDistance(EntPos, ClientPos, false);
			if (Distance < 100.0) //Make sure they're close enough to the building, it's pretty easy to trigger the sound without being in range
			{
				if (Event_HWN2019_IsValidItem(ent))
				{
					int id = Event_HWN2019_GetItemIndex(ent);
					if(g_HWN2019_Collectables[client][id]) return Plugin_Continue;
					ClientCommand(client, "playgamesound Powerup.PickUpAgility");
					
					new String:szAuth[256];
					GetClientAuthId(client,AuthId_SteamID64, szAuth, sizeof(szAuth));
					new String:query[200];
					Format(query, 200, "INSERT INTO `tf_event_hwn2019` (`steamid`, `itemid`, `picked`) VALUES (\'%s\', \'%d\', NOW());",szAuth,id);
					SQL_FastQuery(g_hDB, query);
					g_HWN2019_Collectables[client][id] = true;
					PrintToChat(client, "\x03Halloween | \x01Вы собрали \x05%d / %d \x01тыкв на этой карте. Всего собрано тыкв: \x5%d", 
						Event_HWN2019_GetMapPlayerEggs(client),
						Event_HWN2019_EggsAmount(),
						Event_HWN2019_GetTotalPlayerEggs(client)
					);
				}
			}
		}
	}
	return Plugin_Continue;
}

public bool Event_HWN2019_IsValidItem(int entity)
{
	if (entity > 0 && IsValidEdict(entity))
	{
		char strName[16];
		GetEntPropString(entity, Prop_Data, "m_iName", strName, 16);
		if (StrContains(strName, "tf2_collect_", true) != -1)
		{
			return true;
		}
	}
	return false;
}



public int Event_HWN2019_GetTotalPlayerEggs(client)
{
	int num;
	for (new i = 0; i < HWN2019_MAXPICKUPS; i++)
	{
		if(g_HWN2019_Collectables[client][i]){
			num++;
		}
	}
	return num;
}

public int Event_HWN2019_GetMapPlayerEggs(client)
{
	int num;
	for(new i = 0; i < 5; i++){
		if(g_HWN2019_Collectables[client][g_HWN2019_Items[i][iId]]){
			num++;
		}		
	}
	return num;
}



public int Event_HWN2019_EggsAmount()
{
	int num;
	int egg;
	while((egg=FindEntityByClassname(egg, "prop_dynamic"))!=INVALID_ENT_REFERENCE)
	{
		if (Event_HWN2019_IsValidItem(egg))
		{
			num++;
		}
	}
	return num;
}