#pragma semicolon 1
#pragma newdecls required

KeyValues m_hConfig = null;

public Plugin myinfo =
{
	name = "Creators.TF",
	author = "Creators.TF Team",
	description = "Creators.TF Economy Core Plugin",
	version = "1.0",
	url = "https://creators.tf"
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	RegPluginLibrary("mapnames");

	CreateNative("GetPrettyMapName", Native_GetPrettyMapName);
	return APLRes_Success;
}

public void OnMapStart()
{
    char sLoc[96];
    BuildPath(Path_SM, sLoc, 96, "configs/mapname_library.cfg");

    m_hConfig = new KeyValues("MapNames");
    m_hConfig.ImportFromFile(sLoc);
}

public any Native_GetPrettyMapName(Handle plugin, int numParams)
{
	if(!IsHndlValid(m_hConfig)) return;
	
	char sMapName[128];
	GetNativeString(1, sMapName, sizeof(sMapName));
	
	int size = GetNativeCell(3);
	char[] buffer = new char[size + 1];
	
	char sBuff[1][32], prefix[32];
	ExplodeString(sMapName, "_", sBuff, sizeof(sBuff), sizeof(sBuff[]));
	strcopy(prefix, sizeof(prefix), sBuff[0]);
	
	m_hConfig.GetString(sMapName, buffer, size);
	/*
	if (StrEqual(prefix, "cp"))		Format(buffer, size, "CP %s", buffer);
	if (StrEqual(prefix, "plr"))	Format(buffer, size, "PLR %s", buffer);
	if (StrEqual(prefix, "pl"))		Format(buffer, size, "PL %s", buffer);
	if (StrEqual(prefix, "koth"))	Format(buffer, size, "KotH %s", buffer);
	if (StrEqual(prefix, "pd"))		Format(buffer, size, "PD %s", buffer);
	if (StrEqual(prefix, "rd"))		Format(buffer, size, "RD %s", buffer);
	if (StrEqual(prefix, "mvm"))	Format(buffer, size, "MvM %s", buffer);
	if (StrEqual(prefix, "sd"))		Format(buffer, size, "SD %s", buffer);
	if (StrEqual(prefix, "ctf"))	Format(buffer, size, "CtF %s", buffer);*/
    
	if(StrEqual(buffer, ""))
	{
		strcopy(buffer, size, sMapName);
	}
	SetNativeString(2, buffer, size);
}

public bool IsHndlValid(Handle hndl)
{
    return hndl != null && hndl != INVALID_HANDLE;
}
