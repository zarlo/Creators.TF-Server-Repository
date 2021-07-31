#pragma semicolon 1
#pragma newdecls required

#include <cecon>
#include <cecon_items>

public Plugin myinfo =
{
	name = "[CE Attribute] kick on kill",
	author = "Creators.TF Team",
	description = "kick on kill",
	version = "1.00",
	url = "https://creators.tf"
};

public void OnPluginStart()
{
	HookEvent("player_death", player_death);
}

public Action player_death(Event hEvent, const char[] sName, bool bDontBroadcast)
{
	int attacker = GetClientOfUserId(hEvent.GetInt("attacker"));
	int client = GetClientOfUserId(hEvent.GetInt("userid"));
	
	if (!IsClientValid(client))return Plugin_Continue;
	if (!IsClientValid(attacker))return Plugin_Continue;
	if (client == attacker)return Plugin_Continue;
	
	int iWeapon = CEcon_GetLastUsedWeapon(attacker);
	if(IsValidEntity(iWeapon))
	{
		if (CEconItems_GetEntityAttributeBool(iWeapon, "kick on kill"))
		{
			char sMessage[PLATFORM_MAX_PATH];
			CEconItems_GetEntityAttributeString(iWeapon, "kick on kill message", sMessage, sizeof(sMessage));
			
			if(StrEqual(sMessage, ""))
			{
				strcopy(sMessage, sizeof(sMessage), "Kicked by a weapon");
			}
			
			KickClient(client, sMessage);
		}
	}
	return Plugin_Continue;
}

public bool IsClientValid(int client)
{
	if (client <= 0 || client > MaxClients)return false;
	if (!IsClientInGame(client))return false;
	if (!IsClientAuthorized(client))return false;
	return true;
}