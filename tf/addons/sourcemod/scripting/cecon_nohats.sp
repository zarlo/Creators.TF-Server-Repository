#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <cecon_items>
#include <morecolors>
#include <clientprefs>

#pragma semicolon 1
#pragma newdecls required

bool bShowHats[MAXPLAYERS+1] = true;
Handle ctfHatsCookie;

public Plugin myinfo =
{
    name        = "CreatorsTF Hat Removal",
    author      = "Jaro 'Monkeys' Vanderheijden, steph&",
    description = "Gives players the choice to locally toggle CreatorsTF hat visibility",
    version     = "1.0.0b",
    url         = ""
};

public void OnPluginStart()
{
    RegConsoleCmd("sm_cosmetics",       ToggleCTFHat, "Locally toggles Creators.TF custom cosmetic visibility");
    RegConsoleCmd("sm_noctfhats",       ToggleCTFHat, "Locally toggles Creators.TF custom cosmetic visibility");
    RegConsoleCmd("sm_togglectfhats",   ToggleCTFHat, "Locally toggles Creators.TF custom cosmetic visibility");
    RegConsoleCmd("sm_togglehats",      ToggleCTFHat, "Locally toggles Creators.TF custom cosmetic visibility");
    RegConsoleCmd("sm_ctfhats",         ToggleCTFHat, "Locally toggles Creators.TF custom cosmetic visibility");
    RegConsoleCmd("sm_nohats",          ToggleCTFHat, "Locally toggles Creators.TF custom cosmetic visibility");
    RegConsoleCmd("sm_hats",            ToggleCTFHat, "Locally toggles Creators.TF custom cosmetic visibility");

    ctfHatsCookie = RegClientCookie("CTF_ShowHats__", ".", CookieAccess_Protected);

    // loop thru clients
    for (int i = 1; i <= MaxClients; i++)
    {
        if (!AreClientCookiesCached(i))
        {
            continue;
        }

        // run OCCC for lateloading
        OnClientCookiesCached(i);
    }
}

public void OnClientCookiesCached(int client)
{
    char cookievalue[8];
    // get cookie value from db
    GetClientCookie(client, ctfHatsCookie, cookievalue, sizeof(cookievalue));
    // if we dont have a cookie value set it to 1
    if (!cookievalue[0])
    {
        cookievalue = "1";
    }

    // StringToIntToBool essentially, the bang bang double negates it, once to an inverted bool, twice to a proper bool
    bShowHats[client] = !!StringToInt(cookievalue);
}

// when a client runs sm_nohats etc
public Action ToggleCTFHat(int client, int args)
{
    // make sure we yell at the client if we dont have a connection to the db
    bool nosave;
    if (!AreClientCookiesCached(client))
    {
        nosave = true;
    }

    // toggle
    bShowHats[client] = !bShowHats[client];

    char cookievalue[8];
    if (bShowHats[client])
    {
        PrintToChat(client, "\x01* Toggled Creators.TF custom cosmetics \x03ON\x01!");
        cookievalue = "1";
    }
    else
    {
        PrintToChat(client, "\x01* Toggled Creators.TF custom cosmetics \x07FF0000OFF\x01! Be warned, this may cause invisible heads or feet for some cosmetics!");
        cookievalue = "0";
    }

    if (nosave)
    {
        PrintToChat(client, "\x01* Your settings will not be saved due to our cookie server being down.");
        return Plugin_Handled;
    }
    else
    {
        // save to cookie
        SetClientCookie(client, ctfHatsCookie, cookievalue);
    }

    return Plugin_Handled;
}

public void OnClientDisconnect(int client)
{
    bShowHats[client] = false;
}

public void CEconItems_OnItemIsEquipped(int client, int entity, CEItem item, const char[] type)
{
    // client equipped a ctf hat, hook it
    if (StrEqual(type, "cosmetic"))
    {
        RequestFrame(HookDelay, entity);
    }
}

void HookDelay(int entity)
{
    SDKHook(entity, SDKHook_SetTransmit, SetTransmitHat);
}

public Action SetTransmitHat(int entity, int client)
{
    if (bShowHats[client])
    {
        return Plugin_Continue;
    }
    else
    {
        return Plugin_Stop;
    }
}
