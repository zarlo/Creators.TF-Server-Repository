enum PetEnum{
	iDef,
	Float:offPos[3],
	Float:offRot[3],
	Float:offParticle[3],
	String:sModelPath[64],
	Float:flModelScale,
	String:sIdleSequence[32],
	String:sWalkSequence[32],
	String:sJumpSequence[32]
}

enum PetStates{
	PETSTATE_IDLE,
	PETSTATE_WALK,
	PETSTATE_JUMP
}

new g_PetID[2049];
new g_PetOwner[2049];
new g_PetIndex[2049];
new g_PetQuality[2049];
PetStates g_PetState[2049];
new g_PetAttributes[2049][MAXATTRIBUTES];

new g_ClientPets[MAXPLAYERS + 1];

new Pets[MAXITEMS][PetEnum];


stock SpawnPet(client,char[] model, float scale, char[] sequence)
{
	if (DEBUG == 1)PrintToServer("SpawnPet");
	float flPos[3];
	GetClientAbsOrigin(client, flPos);
	OffsetLocation(flPos);
	
	int iEnt = CreateEntityByName("prop_dynamic_override");
	SetEntityModel(iEnt, model);
	
	DispatchKeyValue(iEnt, "targetname", "tf_pet");
	DispatchSpawn(iEnt);
	if(!StrEqual(sequence, "")){
		SetVariantString(sequence);
		AcceptEntityInput(iEnt, "SetAnimation", -1, -1, 0); 
	}
	
	TeleportEntity(iEnt, flPos, NULL_VECTOR, NULL_VECTOR);
	SetEntPropFloat(iEnt, Prop_Send, "m_flModelScale", scale);
	g_ClientPets[client] = iEnt;
	return iEnt;
}

stock Pack_EquipPet(client, index, char[] sAttribTF2, char[] sAttribCustom, int iMainIndex, int iQuality = 6)
{	
	if (DEBUG == 1)PrintToServer("Pack_EquipPet");
	if (!p_InRespawn[client])return;
	if (IsPlayerSpectator(client))return;
	if (!IsPlayerAlive(client))return;
	if (!GetConVarBool(g_cvPets))return;
	
	Pets_KillPet(client);
	new iPet = SpawnPet(client, Pets[index][sModelPath], Pets[index][flModelScale], Pets[index][sIdleSequence]);
	
	g_PetID[iPet] = index;
	g_PetQuality[iPet] = iQuality;
	g_PetOwner[iPet] = client;
	g_PetIndex[iPet] = iMainIndex;
	g_PetState[iPet] = PETSTATE_IDLE;
	
	for(int i = 0; i < MAXATTRIBUTES; i++) g_PetAttributes[iPet][i] = 0;
	
	int p_Unusual = 0;
	
	new String:atts[MAXATTRIBUTES][11];
	new count = ExplodeString(Items[index][AttribsCustom], " ; ", atts, MAXATTRIBUTES, 11);
	if (count > 1)
	{
		for (new i = 0; i < count; i+=2)
		{
			if(StringToInt(atts[i]) == 13) {
				p_Unusual = StringToInt(atts[i + 1]);
			}
			g_PetAttributes[iPet][StringToInt(atts[i])] = StringToInt(atts[i + 1]);
		}
	}
	count = ExplodeString(sAttribCustom, " ; ", atts, MAXATTRIBUTES, 11);
	if (count > 1)
	{
		for (new i = 0; i < count; i+=2)
		{
			if(StringToInt(atts[i]) == 13) {
				p_Unusual = StringToInt(atts[i + 1]);
			}
			g_PetAttributes[iPet][StringToInt(atts[i])] = StringToInt(atts[i + 1]);
		}
	}
	if (p_Unusual > 0) {
		float flPos[3];
		flPos[0] = Pets[index][offParticle][0];
		flPos[1] = Pets[index][offParticle][1];
		flPos[1] = Pets[index][offParticle][2];
		CreateParticleAttachment(iPet, g_Unusual[p_Unusual][sSystem], flPos);
	}
	SDKUnhook(client, SDKHook_PreThink, Pack_PetThink);
	SDKHook(client, SDKHook_PreThink, Pack_PetThink);
}

public Pack_PetThink(client) 
{
	if(!IsValidPet(g_ClientPets[client]))
	{
		SDKUnhook(client, SDKHook_PreThink, Pack_PetThink);
		return;
	}
	
	// Get locations, angles, distances
	decl Float:pos[3], Float:clientPos[3];
	float ang[3] =  { 0.0, 0.0, 0.0 };
	GetEntPropVector(g_ClientPets[client], Prop_Data, "m_vecOrigin", pos);
	GetClientAbsOrigin(client, clientPos);

	new Float:dist = GetVectorDistance(clientPos, pos);
	new Float:distX = clientPos[0] - pos[0];
	new Float:distY = clientPos[1] - pos[1];
	new Float:speed = (dist - 64.0) / 54;
	Math_Clamp(speed, -4.0, 4.0);
	if(FloatAbs(speed) < 0.3)
		speed *= 0.1;
	
	// Teleport to owner if too far
	if(dist > 1024.0)
	{
		decl Float:posTmp[3];
		GetClientAbsOrigin(client, posTmp);
		OffsetLocation(posTmp);
		TeleportEntity(g_ClientPets[client], posTmp, NULL_VECTOR, NULL_VECTOR);
		GetEntPropVector(g_ClientPets[client], Prop_Data, "m_vecOrigin", pos);
	}
	// Set new location data	
	//if(dist > 30)
	//{
		if(pos[0] < clientPos[0])	pos[0] += speed;
		if(pos[0] > clientPos[0])	pos[0] -= speed;
		if(pos[1] < clientPos[1])	pos[1] += speed;
		if(pos[1] > clientPos[1])	pos[1] -= speed;
	//}
	//PrintToChat(client, "%f", speed);
	pos[2] = clientPos[2];
	if(!(GetEntityFlags(client) & FL_ONGROUND))
		SetPetState(g_ClientPets[client], PETSTATE_JUMP, speed);
	else if(FloatAbs(speed) > 0.2)
		SetPetState(g_ClientPets[client], PETSTATE_WALK, speed);
	else
		SetPetState(g_ClientPets[client], PETSTATE_IDLE, speed);
		
	// Look at owner
	ang[1] = (ArcTangent2(distY, distX) * 180) / 3.14;
	
	pos[0] += Pets[g_PetID[g_ClientPets[client]]][offPos][0];
	pos[1] += Pets[g_PetID[g_ClientPets[client]]][offPos][1];
	pos[2] += Pets[g_PetID[g_ClientPets[client]]][offPos][2];
	ang[0] += Pets[g_PetID[g_ClientPets[client]]][offRot][0];
	ang[1] += Pets[g_PetID[g_ClientPets[client]]][offRot][1];
	ang[2] += Pets[g_PetID[g_ClientPets[client]]][offRot][2];
	TeleportEntity(g_ClientPets[client], pos, ang, NULL_VECTOR);
}
	
SetPetState(iEnt, PetStates status, float speed = 1.0)
{ 
	speed = speed*1.0;
	// This was meant to disable warning on compile, and left in case I need it.
	if(g_PetState[iEnt] == status) return;
	switch(status)
	{
		case PETSTATE_IDLE: {
			SetEntPropFloat(iEnt, Prop_Data, "m_flPoseParameter", 0.0, 4);
			if (!StrEqual(Pets[g_PetID[iEnt]][sIdleSequence], ""))SetPetAnim(iEnt, Pets[g_PetID[iEnt]][sIdleSequence]);
		}
		case PETSTATE_WALK: {
			SetEntPropFloat(iEnt, Prop_Data, "m_flPoseParameter", 1.0, 4);
			if (!StrEqual(Pets[g_PetID[iEnt]][sWalkSequence], ""))SetPetAnim(iEnt, Pets[g_PetID[iEnt]][sWalkSequence]);
		}
		case PETSTATE_JUMP: {
			if (!StrEqual(Pets[g_PetID[iEnt]][sJumpSequence], ""))SetPetAnim(iEnt, Pets[g_PetID[iEnt]][sJumpSequence]);
		} 
	}
	g_PetState[iEnt] = status;
}

SetPetAnim(iEnt, const String:anim[])
{
	SetVariantString(anim);
	AcceptEntityInput(iEnt, "SetAnimation");
}

stock Pack_HolsterPet(client)
{
	if (DEBUG == 1)PrintToServer("Pack_HolsterPet");
	Pets_KillPet(client);	
}

stock Pets_KillPet(client)
{
	if (DEBUG == 1)PrintToServer("Pets_KillPet");
	if(IsValidPet(g_ClientPets[client]))
	{
		AcceptEntityInput(g_ClientPets[client], "kill");
		g_ClientPets[client] = 0;
	}
}

public bool IsValidPet(int entity)
{
	if (entity > 0 && IsValidEdict(entity))
	{
		char tName[16];
		GetEntPropString(entity, Prop_Data, "m_iName", tName, 16);
		if (StrContains(tName, "tf_pet") != -1)
		{
			return true;
		}
	}
	return false;
}