#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <cecon_items>
#include <morecolors>
#include <clientprefs>

#pragma semicolon 1
#pragma newdecls required


bool bHatsOff[MAXPLAYERS+1];
Handle ctfHatsCookie;

public Plugin myinfo =
{
    name        = "CreatorsTF Hat Removal",
    author      = "Jaro 'Monkeys' Vanderheijden, steph&",
    description = "Gives players the choice to locally toggle CreatorsTF hat visibility",
    version     = "0.0.6",
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

    ctfHatsCookie = RegClientCookie("ctfHatsTransmitCookie_", "Cookie for determining if Creators.TF hats are visible to player or not.", CookieAccess_Public);
}

public void OnClientCookiesCached(int client)
{
    char sValue[8];
    // Gets stored value for specific client and stores in sValue
    GetClientCookie(client, ctfHatsCookie, sValue, sizeof(sValue));
    // If the string is null, it'll be set to false - we want hats defaulted on, and the bool determines if hats are OFF
    // 0 = on, 1 = off
    if (!sValue[0])
    {
        // set string to 0
        sValue = "0";
        // save to cookie
        SetClientCookie(client, ctfHatsCookie, sValue);
        // convert cookie value to string and save it to the plugin bool
        bHatsOff[client] = (StringToInt(sValue) != 0);
    }
    else
    {
        // convert cookie value to string
        bHatsOff[client] = (StringToInt(sValue) != 0);
    }
}

public Action ToggleCTFHat(int client, int args)
{
    // toggle
    bHatsOff[client] = !bHatsOff[client];

    if (bHatsOff[client])
    {
        PrintToChat(client, "\x01* Toggled Creators.TF custom cosmetics \x07FF0000OFF\x01! Be warned, this may cause invisible heads or feet for some cosmetics!");
    }
    else
    {
        PrintToChat(client, "\x01* Toggled Creators.TF custom cosmetics \x03ON\x01!");
    }

    if (AreClientCookiesCached(client))
    {
        char sValue[8];
        GetClientCookie(client, ctfHatsCookie, sValue, sizeof(sValue));
        // convert cookie value to string
        IntToString(bHatsOff[client], sValue, sizeof(sValue));
        // save to cookie
        SetClientCookie(client, ctfHatsCookie, sValue);
    }

    return Plugin_Handled;
}

public void OnClientDisconnect(int client)
{
    bHatsOff[client] = false;
}

public void OnEntityCreated(int entity, const char[] classname)
{
    if (StrEqual(classname, "tf_wearable"))
    {
        CreateTimer(0.1, timerHookDelay, entity);
    }
}

public Action timerHookDelay(Handle Timer, int entity)
{
    if (IsValidEdict(entity) && IsValidEntity(entity))
    {
        char sClass[32];
        GetEntityNetClass(entity, sClass, sizeof(sClass));
        if (StrContains(sClass, "CTFWearable") != -1)
        {
            if (CEconItems_IsEntityCustomEconItem(entity))
            {
                SDKHook(entity, SDKHook_SetTransmit, SetTransmitHat);
            }
        }
    }
}

public Action SetTransmitHat(int entity, int client)
{
    //Transmit when plugin's off OR if the player didn't turn it on
    if (!bHatsOff[client])
    {
        return Plugin_Continue;
    }
    else
    {
        return Plugin_Handled;
    }
}
