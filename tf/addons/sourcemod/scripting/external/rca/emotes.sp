enum EmoteEnum{
	String:sCode[32],
	String:sMaterial[128]
}

new Emotes[MAXITEMS][EmoteEnum];
bool g_EmoteCooldown[MAXPLAYERS + 1];

stock SpawnEmote(client,char[] material)
{
	if (DEBUG == 1)PrintToServer("SpawnEmote");
	if (!IsPlayerAlive(client))return;
	if (g_EmoteCooldown[client])return;
	int iSprite = CreateEntityByName("env_sprite_oriented");
	float flPos[3];
	GetClientEyePosition(client, flPos);
	flPos[2] += 25.0;
	OffsetLocation(flPos, 0.0);
	DispatchKeyValue(iSprite, "spawnflags", "1");
	DispatchKeyValueFloat(iSprite, "scale", 0.35);
	DispatchKeyValue(iSprite, "model", material); 
	DispatchSpawn(iSprite);
	TeleportEntity(iSprite, flPos, NULL_VECTOR, NULL_VECTOR);
	
	int iLink = CreateLink(client,"prop_bone");
	DispatchKeyValue(iLink, "targetname", "tf_emote");
	SetVariantString("!activator");
	AcceptEntityInput(iSprite, "SetParent", iLink); 
	SetEntPropEnt(iSprite, Prop_Send, "m_hEffectEntity", iLink);
	
	CreateTimer(5.0, Action_KillEmote, iLink);
	g_EmoteCooldown[client] = true;
	CreateTimer(1.0, Emotes_DisableCooldown, client);
}

public Action Emotes_DisableCooldown(Handle timer, any client)
{
	if (DEBUG == 1)PrintToServer("Emotes_DisableCooldown");
	g_EmoteCooldown[client] = false;
}
public Action Action_KillEmote(Handle timer, any emote)
{
	if (DEBUG == 1)PrintToServer("Action_KillEmote");
	if(IsValidEmote(emote))
	{
		AcceptEntityInput(emote, "kill");
	}
}

public bool IsValidEmote(int entity)
{
	if (DEBUG == 1)PrintToServer("IsValidEmote");
	if (entity > 0 && IsValidEdict(entity))
	{
		char tName[16];
		GetEntPropString(entity, Prop_Data, "m_iName", tName, 16);
		if (StrContains(tName, "tf_emote") != -1)
		{
			return true;
		}
	}
	return false;
}

public Emotes_HookSay(int client, char[] str)
{
	if (DEBUG == 1)PrintToServer("Emotes_HookSay");
	int iEmoteIndex = Emotes_CheckString(str);
	if (iEmoteIndex == -1)return;
	if(Pack_UserHasItemIndex(client, iEmoteIndex))
	{
		SpawnEmote(client, Emotes[iEmoteIndex][sMaterial]);
	}
}

public int Emotes_CheckString(char[] str)
{
	if (DEBUG == 1)PrintToServer("Emotes_CheckString");
	for (new i = 0; i < MAXITEMS; i++)
	{
		if(!StrEqual(Emotes[i][sCode],"\0"))
		{
			if(StrContains(str, Emotes[i][sCode]) != -1)
			{
				return i;
			}
		}
	}
	return -1;
}