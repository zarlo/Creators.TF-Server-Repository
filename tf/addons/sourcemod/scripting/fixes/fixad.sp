#pragma semicolon 1;
#pragma newdecls required;

#include <sourcemod>
#include <sdktools>
#include <tf2>
#include <gamemode>

public Plugin myinfo =
{
    name             = "fix a/d timelimit",
    author           = "stephanie",
    description      = "",
    version          = "0.0.1",
    url              = "https://sappho.io"
}

public void OnMapStart()
{
    CreateTimer(5.0, CheckGamemode);
}

public Action CheckGamemode(Handle timer)
{
    TF2_GameMode gamemode = TF2_DetectGameMode();
    if (gamemode == TF2_GameMode_ADCP)
    {
        int ent = -1;
        while ((ent = FindEntityByClassname(ent, "tf_gamerules")) != -1)
        {
            SetVariantBool(false);
            AcceptEntityInput(ent, "SetStalemateOnTimelimit");
            LogMessage("fixed a/d map timelimit");
            continue;
        }
    }
}
