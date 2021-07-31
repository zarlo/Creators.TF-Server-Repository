public Action cPack(int client, int args){
	if(args >= 1)
	{
		char sArg1[MAX_NAME_LENGTH];
		GetCmdArg(1, sArg1, sizeof(sArg1));
		int iTarget = FindTarget(client, sArg1, false, true);
		if(IsValidEntity(iTarget) && IsClientInGame(iTarget)){
			OpenInventory(client,iTarget);
		}else{
			ReplyToCommand(client,"[SM] No players matching this criteria");
		}
	} else{
		OpenInventory(client);
	}
	
	return Plugin_Handled;
}
public Action cStore(int client, int args)
{
	OpenStores(client);
	return Plugin_Handled;
}

public Action cView(int client, int args){
 	if(args < 1 || args > 1){
		PrintToConsole(client, "Usage: sm_view <index>");
		return Plugin_Handled;
 	}
 	new String:sIndex[11];
 	GetCmdArg(1, sIndex, 11);
 	
 	OpenItemContext(client, StringToInt(sIndex));
	return Plugin_Handled;
}

public Action cConfDel(int client, int args){
 	if(args < 1 || args > 1){
		PrintToConsole(client, "Usage: sm_confdel <index>");
		return Plugin_Handled;
 	}
 	new String:sIndex[11];
 	GetCmdArg(1, sIndex, 11);
 	
 	if(Pack_DeleteItem(client, StringToInt(sIndex)) == -1){
 		PrintToChat(client, "Pack » Failed to delete this item");
 	}
	return Plugin_Handled;
}

public Action cDel(int client, int args){
 	if(args < 1 || args > 1){
		PrintToConsole(client, "Usage: sm_del <index>");
		return Plugin_Handled;
 	}
 	new String:sIndex[11];
 	GetCmdArg(1, sIndex, 11);
 	
 	if(Pack_OpenDeleteMenu(client, StringToInt(sIndex)) == -1){
 		PrintToChat(client, "Pack » Failed to delete this item");
 	}
 	
	return Plugin_Handled;
}
//cDelMenu
/*

*/


public Action cGiveItem(int client, int args){
 	if (args < 2)
	{
		ReplyToCommand(client, "[SM] Usage: sm_giveitem <#userid|name> <defid> [quality]");
		return Plugin_Handled;
	}

	char sArg1[20], sArg2[20], sArg3[20];
	int iArg1, iArg2, iArg3;
	iArg1 = GetCmdArg(1, sArg1, sizeof(sArg1));
	iArg2 = GetCmdArg(2, sArg2, sizeof(sArg2));
	iArg3 = GetCmdArg(3, sArg3, sizeof(sArg3));
	
	if(iArg1 == 0 || iArg2 == 0) {
		ReplyToCommand(client, "[SM] Usage: sm_giveitem <#userid|name> <defid> [quality]");
		return Plugin_Handled;
	}
	
	int iDefIndex, iQuality;
	iDefIndex = StringToInt(sArg2);
	iQuality = iArg3 == 0?6:StringToInt(sArg3);
	
	char target_name[MAX_TARGET_LENGTH];
	int target_list[MAXPLAYERS], target_count;
	bool tn_is_ml;
	
	if ((target_count = ProcessTargetString(
			sArg1,
			client,
			target_list,
			MAXPLAYERS,
			COMMAND_FILTER_NO_BOTS,
			target_name,
			sizeof(target_name),
			tn_is_ml)) <= 0)
	{
		ReplyToTargetError(client, target_count);
		return Plugin_Handled;
	}
	
	for (int i = 0; i < target_count; i++)
	{
		Pack_GiveItem(target_list[i], iDefIndex, iQuality);
	}
	PrintToChatAll(GiveStrings[_:STAFF_GIVEN], target_name, g_Quality[iQuality][sColor], g_Quality[iQuality][sName], Items[iDefIndex][sName]);

	return Plugin_Handled;
}

stock Pack_GiveItem(int client, int index, int quality, char[] sAt = "", char[] sAtTF2 = "")
{
	new String:szAuth[256];
	GetClientAuthId(client,AuthId_SteamID64, szAuth, sizeof(szAuth));
	new String:query[300];
	Format(query, 300, "INSERT INTO tf_pack (steamid,defid,quality,custom_attribs,tf2_attribs)VALUES('%s','%d','%d','%s','%s')",szAuth, index,quality,sAt,sAtTF2);
	SQL_FastQuery(g_hDB, query);
}

public Action cEquip(int client, int args){
 	if(args < 1 || args > 1){
		PrintToConsole(client, "Usage: sm_equip <index>");
		return Plugin_Handled;
 	}
 	new String:sIndex[11];
 	GetCmdArg(1, sIndex, 11);
 	
 	if(Pack_EquipItem(client, StringToInt(sIndex)) == -1){
 		PrintToChat(client, "Pack » Failed to equip this item");
 	}
	return Plugin_Handled;
}
public Action cHolster(int client, int args){
 	if(args < 1 || args > 1){
		PrintToConsole(client, "Usage: sm_holster <index>");
		return Plugin_Handled;
 	}
 	new String:sIndex[11];
 	GetCmdArg(1, sIndex, 11);
 	
 	if(Pack_HolsterItem(client, StringToInt(sIndex)) == -1){
 		PrintToChat(client, "Pack » Failed to holster this item");
 	}
	return Plugin_Handled;
}

stock int Pack_HolsterItem(client, index, save = true, silent = false)
{
	if (DEBUG == 1)PrintToServer("Pack_HolsterItem");
	new String:szAuth[256];
	GetClientAuthId(client,AuthId_SteamID64, szAuth, sizeof(szAuth));
	new String:query[300];	
	Format(query, 300, "SELECT * FROM `tf_pack` WHERE `id` = \'%d\' AND `steamid` = \'%s\'",index,szAuth);
	
	new Handle:queryH = SQL_Query(g_hDB, query);
	if (queryH == INVALID_HANDLE)return -1;
	if(SQL_GetRowCount(queryH) == 0)
	{
		return -1;
	}else{
		if(SQL_FetchRow(queryH)){
			new iDefIndex = SQL_FetchInt(queryH, 2);
			new iQuality = SQL_FetchInt(queryH, 3);
				
			switch(Items[iDefIndex][iType])
			{
				case TYPE_WEAPON:Pack_HolsterWeapon(client, iDefIndex);
				case TYPE_PET:Pack_HolsterPet(client);
				case TYPE_PLAYERMODEL:Pack_HolsterPlayermodel(client);
			}
			new iOld = g_PlayerLoadout[client][Items[iDefIndex][iSlot]];
			g_PlayerLoadout[client][Items[iDefIndex][iSlot]] = 0;
			
			if(save && iOld != g_PlayerLoadout[client][Items[iDefIndex][iSlot]])
			{
				Pack_SaveLoadout(client);
			}
			
	 		if(!silent)	PrintToChat(client, "\x07%sHolstered » \x07%s%s%s",g_BaseChatColor, g_Quality[iQuality][sColor], g_Quality[iQuality][sName], Items[iDefIndex][sName]);
	 		return iDefIndex;
		}
	}
	CloseHandle(queryH);
	if (DEBUG == 1)PrintToServer("Pack_HolsterItem - end");
	return -1;
}

stock int Pack_DeleteItem(client, index, save = true, silent = false)
{
	if (DEBUG == 1)PrintToServer("Pack_DeleteItem");
	new String:szAuth[256];
	GetClientAuthId(client,AuthId_SteamID64, szAuth, sizeof(szAuth));
	new String:query[300];	
	Format(query, 300, "SELECT * FROM `tf_pack` WHERE `id` = \'%d\' AND `steamid` = \'%s\'",index,szAuth);
	
	new Handle:queryH = SQL_Query(g_hDB, query);
	if (queryH == INVALID_HANDLE)return -1;
	if(SQL_GetRowCount(queryH) == 0)
	{
		return -1;
	}else{
		if(SQL_FetchRow(queryH)){
			new iItemIndex = SQL_FetchInt(queryH, 0);
			new iDefIndex = SQL_FetchInt(queryH, 2);
			new iQuality = SQL_FetchInt(queryH, 3);
			if (g_PlayerLoadout[client][Items[iDefIndex][iSlot]] == iItemIndex)Pack_HolsterItem(client, iItemIndex, save, false);
			
			Format(query, 300, "DELETE FROM `tf_pack` WHERE `id` = \'%d\'", iItemIndex);
			SQL_FastQuery(g_hDB, query);
			
			if(!silent)	PrintToChat(client, "\x07%sDeleted » \x07%s%s%s",g_BaseChatColor, g_Quality[iQuality][sColor], g_Quality[iQuality][sName], Items[iDefIndex][sName]);
	 		return iDefIndex;
		}
	}
	CloseHandle(queryH);
	if (DEBUG == 1)PrintToServer("Pack_DeleteItem - end");
	return -1;
}
stock int Pack_OpenDeleteMenu(client, index)
{
	if (DEBUG == 1)PrintToServer("Pack_OpenDeleteMenu");
	new String:szAuth[256];
	GetClientAuthId(client,AuthId_SteamID64, szAuth, sizeof(szAuth));
	new String:query[300];	
	Format(query, 300, "SELECT * FROM `tf_pack` WHERE `id` = \'%d\' AND `steamid` = \'%s\'",index,szAuth);
	
	new Handle:queryH = SQL_Query(g_hDB, query);
	if (queryH == INVALID_HANDLE)return -1;
	if(SQL_GetRowCount(queryH) == 0)
	{
		return -1;
	}else{
		if(SQL_FetchRow(queryH)){
			new iItemIndex = SQL_FetchInt(queryH, 0);
			new iDefIndex = SQL_FetchInt(queryH, 2);
			new iQuality = SQL_FetchInt(queryH, 3);
			
			
			Menu menu = new Menu(mBackpack);
			menu.SetTitle("Delete %s%s\n \nAre you sure you want\nto delete this item?\nThis action cannot be undone!\n ", g_Quality[iQuality][sName],Items[iDefIndex][sName]);

			new String:MenuItem[255];
			Format(MenuItem, 255, "view%d", iItemIndex);
			menu.AddItem(MenuItem, "No.");
			Format(MenuItem, 255, "confdel%d", iItemIndex);
			menu.AddItem(MenuItem, "Yes.");
			menu.ExitButton = true;
			menu.Display(client, 20);
	 		return iDefIndex;
		}
	}
	CloseHandle(queryH);
	if (DEBUG == 1)PrintToServer("Pack_OpenDeleteMenu - end");
	return -1;
}

public int Pack_UseCase(int client, int iCaseId, int iCaseDef, int iDefKey)
{	
	if (DEBUG == 1)PrintToServer("Pack_UseCase");
	Menu menu = new Menu(mBackpack);
	menu.SetTitle("Use %s with:", Items[iCaseDef][sName]);
	new String:szAuth[256];
	GetClientAuthId(client,AuthId_SteamID64, szAuth, sizeof(szAuth));
	new String:query[200];
	
	Format(query, 200, "SELECT * FROM `tf_pack` WHERE `steamid` = \'%s\' AND `defid` = \'%d\'",szAuth,iDefKey);
	new Handle:queryH = SQL_Query(g_hDB, query);
	
	if(queryH != INVALID_HANDLE)
	{   
		new row = 0;
		while (SQL_FetchRow(queryH))
		{
			row++;
			new iItemIndex = SQL_FetchInt(queryH, 0);
			new iDefIndex = SQL_FetchInt(queryH, 2);
			new iQuality = SQL_FetchInt(queryH, 3);
			
			new String:MenuItemName[255];
			new String:MenuItem[255];
			Format(MenuItem, 255, "%s%s", g_Quality[iQuality][sName], Items[iDefIndex][sName]);
			Format(MenuItemName, 255, "crate%dcrate%d", iItemIndex,iCaseId);
			menu.AddItem(MenuItemName, MenuItem);
		}
		if(row == 0){
			menu.AddItem("plain", "You have no items matching criteria",ITEMDRAW_DISABLED);
		}
	}
	menu.ExitButton = true;
	menu.Display(client, 20);
	if (DEBUG == 1)PrintToServer("Pack_UseCase - end");
	CloseHandle(queryH);
	return;
}

public OpenStore(int client, int shop)
{
	if (DEBUG == 1)PrintToServer("OpenStore");
	new String:loc[96];
	BuildPath(Path_SM, loc, 96, "configs/items.cfg");
	new Handle:kv = CreateKeyValues("Items");
	FileToKeyValues(kv,loc);
	Menu menu = new Menu(mBackpack);
	if(KvJumpToKey(kv,"Stores",false))
	{
		char Index[11];
		IntToString(shop,Index,sizeof(Index));
		if(KvJumpToKey(kv,Index,false)){
			if (KvGetNum(kv, "enabled", 0) == 0)return;
			char sStoreName[128];
			//float mult = KvGetFloat(kv, "discount", 1.0);
			KvGetString(kv,"name",sStoreName,128);
			menu.SetTitle(sStoreName);
			if(KvJumpToKey(kv, "items",false))
			{
				for (new i = 1; i < MAXSTOREGOODS; i++){
					IntToString(i,Index,sizeof(Index));
					if (KvJumpToKey(kv, Index, false)){
						int iID = KvGetNum(kv, "id");
						//int iPrice = RoundToCeil(float(KvGetNum(kv, "price")) * mult);
						int iQuality = KvGetNum(kv, "quality", 6);
						char sLink[32];
						char sItem[64];
						Format(sItem, 64, "%s%s", g_Quality[iQuality][sName], Items[iID][sName]);
						Format(sLink, 32, "buy%dbuy%d", shop, i);
						menu.AddItem(sLink, sItem);
					}
					KvGoBack(kv);
				}
			}
			KvGoBack(kv);
		}
		KvGoBack(kv);
		menu.ExitButton = true;
		menu.Display(client, 20);
	}
	if (DEBUG == 1)PrintToServer("OpenStore - end");
	CloseHandle(kv);
}

public OpenStores(int client)
{
	if (DEBUG == 1)PrintToServer("OpenStores");
	new String:loc[96];
	BuildPath(Path_SM, loc, 96, "configs/items.cfg");
	new Handle:kv = CreateKeyValues("Items");
	FileToKeyValues(kv,loc);
	Menu menu = new Menu(mBackpack);
	menu.SetTitle("Item Stores");
	if(KvJumpToKey(kv,"Stores",false))
	{
		for(new i = 1;i<MAXSTORES;i++){
			new String:Index[11];
			IntToString(i,Index,sizeof(Index));
			if(KvJumpToKey(kv,Index,false)){
				if(KvGetNum(kv,"enabled",0) == 1){
					char sStoreName[128];
					char sStoreLink[32];
					KvGetString(kv,"name",sStoreName,128);
					Format(sStoreLink, 32, "store%d", i);
					menu.AddItem(sStoreLink, sStoreName);
				}
			}
			KvGoBack(kv);
		}
		menu.ExitButton = true;
		menu.Display(client, 20);
	}
	if (DEBUG == 1)PrintToServer("OpenStores - end");
}
public int Pack_UseKey(int client, int iKeyId, int iKeyDef, int iDefCase)
{	
	if (DEBUG == 1)PrintToServer("Pack_UseKey");
	Menu menu = new Menu(mBackpack);
	menu.SetTitle("Use %s with:", Items[iKeyDef][sName]);
	new String:szAuth[256];
	GetClientAuthId(client,AuthId_SteamID64, szAuth, sizeof(szAuth));
	new String:query[200];
	
	Format(query, 200, "SELECT * FROM `tf_pack` WHERE `steamid` = \'%s\' AND `defid` = \'%d\'",szAuth,iDefCase);
	new Handle:queryH = SQL_Query(g_hDB, query);
	
	if(queryH != INVALID_HANDLE)
	{   
		new row = 0;
		while (SQL_FetchRow(queryH))
		{
			row++;
			new iItemIndex = SQL_FetchInt(queryH, 0);
			new iDefIndex = SQL_FetchInt(queryH, 2);
			new iQuality = SQL_FetchInt(queryH, 3);
			
			new String:MenuItemName[255];
			new String:MenuItem[255];
			Format(MenuItem, 255, "%s%s", g_Quality[iQuality][sName], Items[iDefIndex][sName]);
			Format(MenuItemName, 255, "crate%dcrate%d", iKeyId,iItemIndex);
			menu.AddItem(MenuItemName, MenuItem);
		}
		if(row == 0){
			menu.AddItem("plain", "You have no items matching criteria",ITEMDRAW_DISABLED);
		}
	}
	menu.ExitButton = true;
	menu.Display(client, 20);
	CloseHandle(queryH);
	if (DEBUG == 1)PrintToServer("Pack_UseKey - end");
	return;
}

public Pack_OpenCase(client, iKeyId, iCaseId)
{
	if (DEBUG == 1)PrintToServer("Pack_OpenCase");
	new String:szAuth[256];
	GetClientAuthId(client,AuthId_SteamID64, szAuth, sizeof(szAuth));
	new String:query[300];	
	Format(query, 300, "SELECT `id`,`defid`,`quality`,`custom_attribs` FROM `tf_pack` WHERE (`id` = '%d' OR `id` = '%d') AND `steamid` = %s",iKeyId,iCaseId,szAuth);
	new Handle:queryH = SQL_Query(g_hDB, query);
	
	if (queryH == INVALID_HANDLE)return;
	if(SQL_GetRowCount(queryH) < 2)
	{
		return;
	}else{
		int iCaseQuality, iCaseDefId,iLootQuality;
		char sAttribCustom[128];
		while (SQL_FetchRow(queryH))
		{
			if(SQL_FetchInt(queryH, 0) == iCaseId)
			{
				iCaseDefId = SQL_FetchInt(queryH, 1);
				iCaseQuality = SQL_FetchInt(queryH, 2);
				SQL_FetchString(queryH, 3, sAttribCustom, 128);
			}
		}
		Format(query, 300, "DELETE FROM `tf_pack` WHERE (`id` = '%d' OR `id` = '%d') AND `steamid` = %s",iKeyId,iCaseId,szAuth);
		SQL_FastQuery(g_hDB, query);
		int iColl = Pack_GetAttributeValue(Items[iCaseDefId][AttribsCustom], sAttribCustom, 18);
		Handle hColl = g_Collections[iColl];
		int iLoot = GetArrayCell(hColl, GetRandomInt(0, GetArraySize(hColl) - 1));
		char sAttachAttributes[32] = "";
		iLootQuality = 6;
		if(Pack_GetAttributeValue(Items[iCaseDefId][AttribsCustom], sAttribCustom, 22))
		{
			int iQualityChance = GetRandomInt(1, GetConVarInt(g_cvUnusualChance));
			if(iQualityChance == 1)
			{
				iLootQuality = 5;
				Format(sAttachAttributes, 32, "13 ; %d", Pack_GetRandomUnusual(Items[iLoot][iUType]));
			}
		}
		
		PrintToChatAll(GiveStrings[_:CASE], 
			client,
			g_Quality[iCaseQuality][sColor], g_Quality[iCaseQuality][sName], Items[iCaseDefId][sName],
			g_Quality[iLootQuality][sColor], g_Quality[iLootQuality][sName], Items[iLoot][sName]
		);
		
		Pack_GiveItem(client, iLoot, iLootQuality, sAttachAttributes);
	}
	CloseHandle(queryH);
	if (DEBUG == 1)PrintToServer("Pack_OpenCase - end");
	return;
}
public Pack_OpenCaseMenu(client, iKeyId, iCaseId)
{
	if (DEBUG == 1)PrintToServer("Pack_OpenCaseMenu");
	new String:szAuth[256];
	GetClientAuthId(client,AuthId_SteamID64, szAuth, sizeof(szAuth));
	new String:query[300];	
	Format(query, 300, "SELECT `id`,`defid`,`quality` FROM `tf_pack` WHERE (`id` = '%d' OR `id` = '%d') AND `steamid` = %s",iKeyId,iCaseId,szAuth);
	new Handle:queryH = SQL_Query(g_hDB, query);
	
	if (queryH == INVALID_HANDLE)return;
	if(SQL_GetRowCount(queryH) < 2)
	{
		return;
	}else{
		int iKeyQuality, iCaseQuality, iKeyDefId, iCaseDefId;
		while (SQL_FetchRow(queryH))
		{
			if(SQL_FetchInt(queryH, 0) == iKeyId)
			{
				iKeyDefId = SQL_FetchInt(queryH, 1);
				iKeyQuality = SQL_FetchInt(queryH, 2);
			}
			if(SQL_FetchInt(queryH, 0) == iCaseId)
			{
				iCaseDefId = SQL_FetchInt(queryH, 1);
				iCaseQuality = SQL_FetchInt(queryH, 2);
			}
		}
		Menu menu = new Menu(mBackpack);
		menu.SetTitle("You are about to open:\n \n%s%s\nwith\n%s%s\n \nAre you sure?", g_Quality[iCaseQuality][sName], Items[iCaseDefId][sName], g_Quality[iKeyQuality][sName], Items[iKeyDefId][sName]);
		menu.AddItem("backpack", "No.");
		char sMenuItem[255];
		Format(sMenuItem, 255, "decode%ddecode%d", iKeyId,iCaseId);
		menu.AddItem(sMenuItem, "Yes.");
		menu.ExitButton = true;
		menu.Display(client, 20);
	}
	if (DEBUG == 1)PrintToServer("Pack_OpenCaseMenu - end");
	CloseHandle(queryH);
	return;
}

public Pack_BuyItem(client, store, item)
{
	if (DEBUG == 1)PrintToServer("Pack_BuyItem");
	new String:loc[96];
	BuildPath(Path_SM, loc, 96, "configs/items.cfg");
	new Handle:kv = CreateKeyValues("Items");
	FileToKeyValues(kv,loc);
	Menu menu = new Menu(mBackpack);
	if(KvJumpToKey(kv,"Stores",false))
	{
		char Index[11];
		IntToString(store,Index,sizeof(Index));
		if(KvJumpToKey(kv,Index,false)){
			char sStoreName[128];
			float mult = KvGetFloat(kv, "discount", 1.0);
			char sStoreColor[7];
			KvGetString(kv,"color",sStoreColor, 7, "ffffff");
			KvGetString(kv,"name",sStoreName,128);
			if(KvJumpToKey(kv, "items",false))
			{
				IntToString(item,Index,sizeof(Index));
				if (KvJumpToKey(kv, Index, false)){
					int iID = KvGetNum(kv, "id");
					int iPrice = RoundToCeil(float(KvGetNum(kv, "price")) * mult);
					if (Players[client][iCredit] < iPrice)return;
					int iQuality = KvGetNum(kv, "quality",6);
					Exp_AddCredit(client, -iPrice, true, "buying",false);
					PrintToChatAll(GiveStrings[_:BOUGHT], 
						client,
						g_Quality[iQuality][sColor], g_Quality[iQuality][sName], Items[iID][sName],
						sStoreColor, sStoreName
					);
					
					Pack_GiveItem(client, iID, iQuality);
				}
			}
			KvGoBack(kv);
		}
		KvGoBack(kv);
		menu.ExitButton = true;
		menu.Display(client, 20);
	}
	if (DEBUG == 1)PrintToServer("Pack_BuyItem - end");
}

public Pack_OpenBuyMenu(client, store, item)
{
	if (DEBUG == 1)PrintToServer("Pack_OpenBuyMenu");
	new String:loc[96];
	BuildPath(Path_SM, loc, 96, "configs/items.cfg");
	new Handle:kv = CreateKeyValues("Items");
	FileToKeyValues(kv,loc);
	Menu menu = new Menu(mBackpack);
	if(KvJumpToKey(kv,"Stores",false))
	{
		char Index[11];
		IntToString(store,Index,sizeof(Index));
		if(KvJumpToKey(kv,Index,false)){
			char sStoreName[128];
			float mult = KvGetFloat(kv, "discount", 1.0);
			KvGetString(kv,"name",sStoreName,128);
			if(KvJumpToKey(kv, "items",false))
			{
				IntToString(item,Index,sizeof(Index));
				if (KvJumpToKey(kv, Index, false)){
					int iID = KvGetNum(kv, "id");
					int iPrice = RoundToCeil(float(KvGetNum(kv, "price")) * mult);
					int iQuality = KvGetNum(kv, "quality",6);
					menu.SetTitle("You are about to buy:\n \n%s%s\nfor\n%d MC\nfrom\n%s\n \nAre you sure?",g_Quality[iQuality][sName], Items[iID][sName], iPrice, sStoreName);
					char sLink[32], sLinkNo[32];
					Format(sLink, 32, "purc%dpurc%d", store, item);
					Format(sLinkNo, 32, "store%d", store);
					menu.AddItem(sLinkNo,"No.");
					menu.AddItem(sLink,"Yes.",Players[client][iCredit] >= iPrice?ITEMDRAW_DEFAULT:ITEMDRAW_DISABLED);
				}
			}
			KvGoBack(kv);
		}
		KvGoBack(kv);
		menu.ExitButton = true;
		menu.Display(client, 20);
	}
	if (DEBUG == 1)PrintToServer("Pack_OpenBuyMenu - end");
}

stock int Pack_EquipItem(client, index, save = true, silent = false)
{
	if (DEBUG == 1)PrintToServer("Pack_EquipItem %N", client);
	new String:szAuth[256];
	GetClientAuthId(client,AuthId_SteamID64, szAuth, sizeof(szAuth));
	new String:query[300];	
	Format(query, 300, "SELECT * FROM `tf_pack` WHERE `id` = \'%d\' AND `steamid` = \'%s\'",index,szAuth);
	
	new Handle:queryH = SQL_Query(g_hDB, query);
	if (queryH == INVALID_HANDLE)return -1;
	if(SQL_GetRowCount(queryH) == 0)
	{
		return -1;
	}else{
		if(SQL_FetchRow(queryH)){
			new iItemIndex = SQL_FetchInt(queryH, 0);
			new iDefIndex = SQL_FetchInt(queryH, 2);
			new iQuality = SQL_FetchInt(queryH, 3);
			new String:sAttribTF2[128];
			new String:sAttribCustom[128];
			SQL_FetchString(queryH, 5, sAttribTF2, 128);
			SQL_FetchString(queryH, 6, sAttribCustom, 128);
			switch(Items[iDefIndex][iType])
			{
				case TYPE_WEAPON:Pack_EquipWeapon(client, iDefIndex, sAttribTF2, sAttribCustom,iItemIndex, iQuality);
				case TYPE_PET: Pack_EquipPet(client, iDefIndex, sAttribTF2, sAttribCustom,iItemIndex, iQuality);
				case TYPE_PLAYERMODEL: Pack_EquipPlayermodel(client, iDefIndex, sAttribTF2, sAttribCustom,iItemIndex, iQuality);
			}
			if(Items[iDefIndex][iType] == _:TYPE_EMOTE)
			{
				//SpawnEmote(client, Emotes[iDefIndex][sMaterial]);
			}else if(Items[iDefIndex][iType] == _:TYPE_TOOL){
				int iValue;
				if((iValue = Pack_GetAttributeValue(Items[iDefIndex][AttribsCustom], sAttribCustom, 21)) > 0)
				{
					Pack_UseKey(client, iItemIndex, iDefIndex, iValue);
				}
				else if((iValue = Pack_GetAttributeValue(Items[iDefIndex][AttribsCustom], sAttribCustom, 17)) > 0)
				{
					Pack_UseCase(client, iItemIndex, iDefIndex, iValue);
				}
			}else{
				new iOld = g_PlayerLoadout[client][Items[iDefIndex][iSlot]];
				g_PlayerLoadout[client][Items[iDefIndex][iSlot]] = iItemIndex;
				
				if(save && iOld != g_PlayerLoadout[client][Items[iDefIndex][iSlot]])
				{
					Pack_SaveLoadout(client);
				}
				
				if(!silent)	PrintToChat(client, "\x07%sEquipped » \x07%s%s%s",g_BaseChatColor, g_Quality[iQuality][sColor], g_Quality[iQuality][sName], Items[iDefIndex][sName]);
			}
	 		return iDefIndex;
		}
	}
	if (DEBUG == 1)PrintToServer("Pack_EquipItem - end");
	CloseHandle(queryH);
	return -1;
}

stock void OpenInventory(client, target = -1)
{
	if (DEBUG == 1)PrintToServer("OpenInventory");
	if (target == -1)target = client;
	
	Menu menu = new Menu(mBackpack);
	menu.SetTitle("%N\'s backpack", target);
	new String:szAuth[256];
	GetClientAuthId(target,AuthId_SteamID64, szAuth, sizeof(szAuth));
	new String:query[200];
	
	Format(query, 200, "SELECT * FROM `tf_pack` WHERE `steamid` = \'%s\'",szAuth);
	new Handle:queryH = SQL_Query(g_hDB, query);
	
	if(queryH != INVALID_HANDLE)
	{   
		new row = 0;
		while (SQL_FetchRow(queryH))
		{
			row++;
			new iItemIndex = SQL_FetchInt(queryH, 0);
			new iDefIndex = SQL_FetchInt(queryH, 2);
			new iQuality = SQL_FetchInt(queryH, 3);
			
			new String:MenuItemName[255];
			new String:MenuItem[255];
			Format(MenuItem, 255, "%s%s", g_Quality[iQuality][sName], Items[iDefIndex][sName]);
			if(g_PlayerLoadout[target][Items[iDefIndex][iSlot]] == iItemIndex){
				Format(MenuItem, 255, "[E] %s", MenuItem);
			}
			Format(MenuItemName, 255, "view%d", iItemIndex);
			menu.AddItem(MenuItemName, MenuItem);
		}
		if(row == 0){
			menu.AddItem("plain", "There is nothing here... yet",ITEMDRAW_DISABLED);
		}
	}
	menu.ExitButton = true;
	menu.Display(client, 20);
	CloseHandle(queryH);
	if (DEBUG == 1)PrintToServer("OpenInventory - end");
	return;
}

stock OpenItemContext(int client, int item, bool bDeathView = false, iKiller = -1)
{
	if (DEBUG == 1)PrintToServer("OpenItemContext");
	new String:szAuth[256];
	GetClientAuthId(client,AuthId_SteamID64, szAuth, sizeof(szAuth));
	new String:query[200];
	Format(query, 200, "SELECT * FROM `tf_pack` WHERE `id` = \'%d\'",item);
	new Handle:queryH = SQL_Query(g_hDB, query);
	if(queryH != INVALID_HANDLE)
	{
		SQL_FetchRow(queryH);
		
		new iItemIndex = SQL_FetchInt(queryH, 0);
		new iDefIndex = SQL_FetchInt(queryH, 2);
		new iQuality = SQL_FetchInt(queryH, 3);
		new String:sAttribTF2[128];
		new String:sAttribCustom[128];
		new String:szAuth2[128];
		SQL_FetchString(queryH, 1, szAuth2, 128);
		SQL_FetchString(queryH, 5, sAttribTF2, 128);
		SQL_FetchString(queryH, 6, sAttribCustom, 128);
			
		Menu menu = new Menu(mBackpack);
		new String:_title[2048];
		Pack_ParseAttributes(_title, 2048, Items[iDefIndex][AttribsCustom], sAttribCustom);
		if(bDeathView)
		{
			Format(_title, 2048,"%N carried:\n%s%s\n \n%s", iKiller, g_Quality[iQuality][sName], Items[iDefIndex][sName], _title);
		}else{
			Format(_title, 2048, "%s%s\n \n%s", g_Quality[iQuality][sName], Items[iDefIndex][sName], _title);
		}
		menu.SetTitle(_title);
		if(bDeathView)
		{
			menu.AddItem("000", "Close");
			menu.ExitButton = false;
		}else{
			if(Items[iDefIndex][iType] == _:TYPE_EMOTE)
			{
				if(StrEqual(szAuth2, szAuth)){
					new String:_name[255];
					Format(_name, 255, "equip%d", iItemIndex);
					menu.AddItem(_name, "Spawn");
				}
			}else if(Items[iDefIndex][iType] == _:TYPE_TOOL)
			{
				if(StrEqual(szAuth2, szAuth)){
					new String:_name[255];
					Format(_name, 255, "equip%d", iItemIndex);
					menu.AddItem(_name, "Use");
				}
			}else{
				if(g_PlayerLoadout[client][Items[iDefIndex][iSlot]] == iItemIndex)
				{
					if(StrEqual(szAuth2, szAuth)){
						new String:_name[255];
						Format(_name, 255, "holster%d", iItemIndex);
						menu.AddItem(_name, "Holster");
					}
				}else{
					if(StrEqual(szAuth2, szAuth)){
						new String:_name[255];
						Format(_name, 255, "equip%d", iItemIndex);
						menu.AddItem(_name, "Equip");
					}
				}
			}
			menu.AddItem("backpack", "Back");
			if(StrEqual(szAuth2, szAuth)){
				new String:_name[255];
				Format(_name, 255, "delete%d", iItemIndex);
				menu.AddItem(_name, "Delete");
			}
			menu.ExitButton = true;
		}
		menu.Display(client, 20);
		return;	
	}	
	CloseHandle(queryH);
	if (DEBUG == 1)PrintToServer("OpenItemContext - end");
	return;	
}

public bool Pack_SaveLoadout(client)
{
	if (DEBUG == 1)PrintToServer("Pack_SaveLoadout");
	new String:szAuth[256];
	GetClientAuthId(client,AuthId_SteamID64, szAuth, sizeof(szAuth));
	
	new String:sLoadoutString[512];
	for (new i = 0; i < _:EquipSlotsEnum; i++) {
		Format(sLoadoutString, 512, "%s%d;", sLoadoutString, g_PlayerLoadout[client][i]);
	}
	new String:query[600];
	Format(query, 600, "UPDATE `tf_users` SET `loadout` = \'%s\' WHERE `steamid` = \'%s\'", sLoadoutString, szAuth);
	new Handle:queryH = SQL_Query(g_hDB, query);
	if(queryH == INVALID_HANDLE){
		return false;
	}	
	CloseHandle(queryH);
	if (DEBUG == 1)PrintToServer("Pack_SaveLoadout - end");
	return true;
}

public bool Pack_LoadLoadout(client)
{
	if (DEBUG == 1)PrintToServer("Pack_LoadLoadout");
	new String:szAuth[256];
	GetClientAuthId(client,AuthId_SteamID64,szAuth, sizeof(szAuth));
	new String:query[200];
	Format(query, 200, "SELECT `loadout` FROM `tf_users` WHERE `steamid` = \'%s\'", szAuth);
	new Handle:queryH = SQL_Query(g_hDB, query);
	if(queryH == INVALID_HANDLE){
		return false;
	}
	if(SQL_FetchRow(queryH)){
		SQL_FetchString(queryH, 0, Players[client][sLoadout], 512);
		Pack_ParseLoadoutString(Players[client][sLoadout], client);
		return true;
	}
	CloseHandle(queryH);
	if (DEBUG == 1)PrintToServer("Pack_LoadLoadout - end");
	return false;
}

public Pack_ParseLoadoutString(char[] string, int client)
{
	new String:items[128][11];
	new count = ExplodeString(string, ";", items, 128, 11);
	if (count > 0)
	{
		for (new i = 0; i < _:EquipSlotsEnum; i++)
		{
			g_PlayerLoadout[client][i] = StringToInt(items[i]);	
		}
	}
}

public Pack_UserHasItemIndex(int client, int index)
{
	new String:szAuth[256];
	GetClientAuthId(client,AuthId_SteamID64,szAuth, sizeof(szAuth));
	new String:query[200];
	Format(query, 200, "SELECT `id` FROM `tf_pack` WHERE `steamid` = \'%s\' AND `defid` = \'%d\'", szAuth, index);
	new Handle:queryH = SQL_Query(g_hDB, query);
	int iRows = SQL_GetRowCount(queryH);
	CloseHandle(queryH);
	return iRows > 0;
}

public int Pack_GetAttributeValue(char[] sAttribs, char[] sAttribsCustom, int index)
{
	//return 0;
	int iValue = 0;
	char sAtts[MAXATTRIBUTES][11];
	int iCount = ExplodeString(sAttribs, " ; ", sAtts, MAXATTRIBUTES, 11);
	if (iCount > 0)
	{
		for (new i = 0; i < iCount; i+=2)
		{
			if(StringToInt(sAtts[i]) == index) iValue = StringToInt(sAtts[i + 1]);
		}
	}
	iCount = ExplodeString(sAttribsCustom, " ; ", sAtts, MAXATTRIBUTES, 11);
	if (iCount > 0)
	{
		for (new i = 0; i < iCount; i+=2)
		{
			if(StringToInt(sAtts[i]) == index) iValue = StringToInt(sAtts[i + 1]);
		}
	}
	return iValue;
}