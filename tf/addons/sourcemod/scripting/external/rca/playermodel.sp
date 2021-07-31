enum PlayermodelEnum{
	String:sPath[64],
	iClass
}
int Playermodels[MAXITEMS][PlayermodelEnum];


stock Pack_EquipPlayermodel(client, index, char[] sAttribTF2, char[] sAttribCustom, int iMainIndex, int iQuality = 6)
{	
	if (DEBUG == 1)PrintToServer("Pack_EquipPlayermodel");
	if (!p_InRespawn[client])return;
	if (IsPlayerSpectator(client))return;
	if (!IsPlayerAlive(client))return;
	if (_:TF2_GetPlayerClass(client) != Playermodels[index][iClass])return;
	
	SetVariantString(Playermodels[index][sPath]);
	AcceptEntityInput(client, "SetCustomModel");
	SetEntProp(client, Prop_Send, "m_bCustomModelRotates", 1);
	SetEntProp(client, Prop_Send, "m_bUseClassAnimations", 1);
	//RemoveValveHat
	if(Pack_GetAttributeValue(Items[index][AttribsCustom], sAttribCustom, 29) > 0)
		RemoveValveHat(client);
}

stock Pack_HolsterPlayermodel(client)
{
}