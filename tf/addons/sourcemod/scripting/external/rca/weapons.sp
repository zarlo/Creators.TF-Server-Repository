#include <tf2attributes>
#include <tf2items>

enum WeaponEnum{
	iDef,
	String:sClassName[64],
	iSlot,
	iMaxAmmo,
	iClass,
	String:AttribsTF2[128],
	String:sWorldModel[512],
	String:sViewModel[512]
}

new g_WeaponID[2049];
new g_WeaponQuality[2049];
new g_WeaponAttributes[2049][MAXATTRIBUTES];
new g_WeaponOwner[2049];
new g_WeaponIndex[2049];

new Weapons[MAXITEMS][WeaponEnum];

stock SpawnWeapon(client,String:name[],index,level,qual,String:att[])
{
	if (DEBUG == 1)PrintToServer("SpawnWeapon");
	new Handle:hWeapon = TF2Items_CreateItem(OVERRIDE_ALL|FORCE_GENERATION);
	TF2Items_SetClassname(hWeapon, name);
	TF2Items_SetItemIndex(hWeapon, index);
	TF2Items_SetLevel(hWeapon, level);
	TF2Items_SetQuality(hWeapon, qual);
	new String:atts[32][32];
	new count = ExplodeString(att, " ; ", atts, 32, 32);
	if (count > 1)
	{
		TF2Items_SetNumAttributes(hWeapon, count/2);
		new i2 = 0;
		for (new i = 0; i < count; i+=2)
		{
			TF2Items_SetAttribute(hWeapon, i2, StringToInt(atts[i]), StringToFloat(atts[i+1]));
			i2++;
		}
		TF2Items_SetAttribute(hWeapon, i2, 214, 3475.0);
	}
	else
		TF2Items_SetNumAttributes(hWeapon, 0);
	if (hWeapon==INVALID_HANDLE)
		return -1;
	new entity = TF2Items_GiveNamedItem(client, hWeapon);
	CloseHandle(hWeapon);
	if( IsValidEdict( entity ) )
	{
		SetEntProp(entity, Prop_Send, "m_fEffects", GetEntProp(entity, Prop_Send, "m_fEffects") | 32);
		SetEntProp(entity, Prop_Send, "m_bValidatedAttachedEntity", 1);
		EquipPlayerWeapon( client, entity );
	}	
	return entity;
}

stock Pack_EquipWeapon(client, index, char[] sAttribTF2, char[] sAttribCustom, int iMainIndex, int iQuality = 6)
{	
	if (DEBUG == 1)PrintToServer("Pack_EquipWeapon");
	if (GetClientTeam(client) == 2 && !GetConVarBool(g_cvWeaponsRed))return;
	if (GetClientTeam(client) == 3 && !GetConVarBool(g_cvWeaponsBlue))return;
	if (!p_InRespawn[client])return;
	if (_:TF2_GetPlayerClass(client) != Weapons[index][iClass])return;
	
	TF2_RemoveWeaponSlot(client, Weapons[index][iSlot]);
	
	if(Weapons[index][iSlot] < 2){
		new ao = FindSendPropInfo("CTFPlayer", "m_iAmmo");
		SetEntData(client, ao +(Weapons[1][iSlot] == 0?4:8), Weapons[index][iMaxAmmo]);
	}
	new wep = SpawnWeapon(client, Weapons[index][sClassName], Weapons[index][iDef], 0, iQuality, Weapons[index][AttribsTF2]);
	g_WeaponID[wep] = index;
	g_WeaponQuality[wep] = iQuality;
	g_WeaponOwner[wep] = client;
	g_WeaponIndex[wep] = iMainIndex;
	
	for(int i = 0; i < MAXATTRIBUTES; i++) g_WeaponAttributes[wep][i] = 0;
	
	new String:atts[MAXATTRIBUTES][11];
	new count = ExplodeString(sAttribTF2, " ; ", atts, MAXATTRIBUTES, 11);
	if (count > 1)
	{
		for (new i = 0; i < count; i+=2)
		{
			TF2Attrib_SetByDefIndex(wep, StringToInt(atts[i]), StringToFloat(atts[i + 1]));
		}
	}
	count = ExplodeString(Items[index][AttribsCustom], " ; ", atts, MAXATTRIBUTES, 11);
	if (count > 1)
	{
		for (new i = 0; i < count; i+=2)
		{
			if(StringToInt(atts[i]) == 13) {
				TF2Attrib_SetByDefIndex(wep, 134, float(g_Unusual[StringToInt(atts[i + 1])][iDef]));
			}
			g_WeaponAttributes[wep][StringToInt(atts[i])] = StringToInt(atts[i + 1]);
		}
	}
	count = ExplodeString(sAttribCustom, " ; ", atts, MAXATTRIBUTES, 11);
	if (count > 1)
	{
		for (new i = 0; i < count; i+=2)
		{
			if(StringToInt(atts[i]) == 13) {
				TF2Attrib_SetByDefIndex(wep, 134, float(g_Unusual[StringToInt(atts[i + 1])][iDef]));
			}
			g_WeaponAttributes[wep][StringToInt(atts[i])] = StringToInt(atts[i + 1]);
		}
	}
	if(!StrEqual(Weapons[index][sWorldModel], ""))
	{
		int iWorldModel = PrecacheModel(Weapons[index][sWorldModel]);
		SetEntProp(wep, Prop_Send, "m_iWorldModelIndex", iWorldModel);
		SetEntProp(wep, Prop_Send, "m_nModelIndexOverrides", iWorldModel, _, 0);
	}
	if(!StrEqual(Weapons[index][sViewModel], ""))
	{
		int iViewModel = PrecacheModel(Weapons[index][sViewModel]);
		SetEntProp(wep, Prop_Send, "m_iViewModelIndex", iViewModel);
				int vm = EquipWearable(client, Weapons[index][sViewModel], true, wep, true);
	
				char arms[PLATFORM_MAX_PATH];
				switch (TF2_GetPlayerClass(client))
				{
				case TFClass_Scout: Format(arms, sizeof(arms), "models/weapons/c_models/c_scout_arms.mdl");
				case TFClass_Soldier: Format(arms, sizeof(arms), "models/weapons/c_models/c_soldier_arms.mdl");
				case TFClass_Pyro: Format(arms, sizeof(arms), "models/weapons/c_models/c_pyro_arms.mdl");
				case TFClass_DemoMan: Format(arms, sizeof(arms), "models/weapons/c_models/c_demo_arms.mdl");
				case TFClass_Heavy: Format(arms, sizeof(arms), "models/weapons/c_models/c_heavy_arms.mdl");
				case TFClass_Engineer: Format(arms, sizeof(arms), "models/weapons/c_models/c_engineer_arms.mdl");
				case TFClass_Medic: Format(arms, sizeof(arms), "models/weapons/c_models/c_medic_arms.mdl");
				case TFClass_Sniper: Format(arms, sizeof(arms), "models/weapons/c_models/c_sniper_arms.mdl");
				case TFClass_Spy: Format(arms, sizeof(arms), "models/weapons/c_models/c_spy_arms.mdl");
				}
	
				if (strlen(arms) > 0 && FileExists(arms, true))
				{
					PrecacheModel(arms, true);
					int armsVm = EquipWearable(client, arms, true, wep, true);
				}
			}
	
	
	if(GetActivePlayerSlot(client) == Weapons[index][iSlot]){
		SetEntPropEnt(client, Prop_Send, "m_hActiveWeapon", wep);
	}
	return;
}

public void OnWeaponSwitch(int client, int weapon)
{
	PrintToChatAll("- %N -", client);
	SetEntProp(GetEntPropEnt(client, Prop_Send, "m_hViewModel"), Prop_Send, "m_fEffects", 32);
}


stock Pack_HolsterWeapon(client,index)
{
	// Nothing yet needed.
}

public Action Timer_ShowEquippedText(Handle timer, any data)
{
	if (DEBUG == 1)PrintToServer("Timer_ShowEquippedText");
	for (new i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i) || !IsPlayerAlive(i))continue;		
		new iWep = GetEntPropEnt(i, Prop_Send, "m_hActiveWeapon");
		if (iWep < 0 || iWep > 2048)continue;	
		if(g_WeaponID[iWep]>0){
			SetHudTextParams(1.0, 0.7, 1.0, g_Quality[g_WeaponQuality[iWep]][iColor][0], g_Quality[g_WeaponQuality[iWep]][iColor][1], g_Quality[g_WeaponQuality[iWep]][iColor][2], 255);
			ShowHudText(i, -1, "%s%s  ",g_Quality[g_WeaponQuality[iWep]][sName],Items[g_WeaponID[iWep]][sName]);
		}
	}
	return Plugin_Continue;
}


public void BlockPhysicsGunDrop(int entity)
{
	if (DEBUG == 1)PrintToServer("BlockPhysicsGunDrop");
	if(IsValidEntity(entity) && IsCustomWeapon(entity))
	{
		AcceptEntityInput(entity, "Kill");
	}
}

bool IsCustomWeapon(int entity) 
{
	if (DEBUG == 1)PrintToServer("IsCustomWeapon");
	return (GetEntProp(entity, Prop_Send, "m_iEntityLevel") == 0);
}
