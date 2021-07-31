#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <tf2_stocks>

public Plugin myinfo =
{
    name             =  "StuckSpec",
    author           =  "steph&nie",
    description      =  "Free players stuck in spec without having to have them retry to the server!",
    version          =  "0.0.2",
    url              =  "https://steph.anie.dev/"
}

public void OnPluginStart()
{
    RegConsoleCmd("sm_stuckspec", StuckSpecCalled, "Put clients on a team if stuck in spectator!");
    RegConsoleCmd("sm_stuck", StuckSpecCalled, "Put clients on a team if stuck in spectator!");
}

public Action StuckSpecCalled(int client, int args)
{
    if (client == 0)
    {
        ReplyToCommand(client, "This command cannot be run by the console!");
        return;
    }

    if (TF2_GetClientTeam(client) != TFTeam_Unassigned && TF2_GetClientTeam(client) != TFTeam_Spectator)
    {
        ReplyToCommand(client, "You are not in spectator!");
        return;
    }

    ClientCommand(client, "autoteam");

    ReplyToCommand(client, "You have been freed from spectator!");
}
