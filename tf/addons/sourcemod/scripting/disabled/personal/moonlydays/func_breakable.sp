#include <sourcemod>
#include <sdktools>

public Plugin myinfo =
{
	name = "1111",
	author = "111",
	description = "111",
	version = "1.0",
	url = "https://steamcommunity.com/profiles/76561197963998743"
}

public void OnPluginStart()
{
	RegAdminCmd("sm_yomama", cYoMama, ADMFLAG_ROOT, "Reloads balance changes");
}

public Action cYoMama(int client, int args)
{
	int edict;
	while((edict = FindEntityByClassname(edict, "func_breakable")) != -1)
	{
		AcceptEntityInput(edict, "Break");
	}
}