#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <morecolors>
#include <geoipcity>

public Plugin myinfo =
{
    name        = "Client Info Grabber",
    author      = "lugui, steph&nie",
    description = "Allows admins to query cvars and GeoIP data on clients",
    version     = "2.0",
};

public void OnPluginStart()
{
    LoadTranslations("common.phrases");
    RegAdminCmd("sm_getcvar",   Command_GetCvar, ADMFLAG_GENERIC, "Get a client's cvar");
    RegAdminCmd("sm_query",     Command_GetCvar, ADMFLAG_GENERIC, "Get a client's cvar");
    RegAdminCmd("sm_netinfo",   Command_GetNetInfo, ADMFLAG_GENERIC, "Get a client's network info");
    RegAdminCmd("sm_netdata",   Command_GetNetInfo, ADMFLAG_GENERIC, "Get a client's network info");
    RegAdminCmd("sm_ip",        Command_GetIP, ADMFLAG_ROOT, "Get a client's GeoIP info");
    RegAdminCmd("sm_geoip",     Command_GetIP, ADMFLAG_ROOT, "Get a client's GeoIP info");
}

public Action Command_GetCvar(int client, int args)
{
    int user = client;
    if (args < 2)
    {
        MC_ReplyToCommand(client, "{white}Usage: sm_query {darkgray}<client>{white} {springgreen}<cvar>");
    }
    else
    {
        char arg1[32];
        char arg2[256];
        GetCmdArg(1, arg1, sizeof(arg1));
        GetCmdArg(2, arg2, sizeof(arg2));

        char target_name[MAX_TARGET_LENGTH];
        int target_list[MAXPLAYERS];
        int target_count;
        bool tn_is_ml;

        if
        (
            (
                target_count = ProcessTargetString
                (
                    arg1,
                    client,
                    target_list,
                    MAXPLAYERS,
                    COMMAND_FILTER_NO_BOTS,
                    target_name,
                    sizeof(target_name),
                    tn_is_ml
                )
            )
            <= 0
        )
        {
            ReplyToTargetError(client, target_count);
            return Plugin_Handled;
        }

        for (int i = 0; i < target_count; i++)
        {
            if (IsValidClient(target_list[i]))
            {
                QueryClientConVar(target_list[i], arg2, CheckCvar, user);
            }
        }
    }

    return Plugin_Handled;
}

public void CheckCvar(QueryCookie cookie, int client, ConVarQueryResult result, const char[] cvarName, const char[] cvarValue, int user)
{
    if (result == ConVarQuery_NotFound)
    {
        MC_PrintToChatEx
        (
            user,
            client,
            "{white}Cvar '{springgreen}%s{white}' was not found on {teamcolor}%N",
            cvarName,
            client
        );
    }
    else if (result == ConVarQuery_NotValid)
    {
        MC_PrintToChatEx
        (
            user,
            client,
            "{white}Cvar '{springgreen}%s{white}' was not valid on {teamcolor}%N{white} - '{springgreen}%s{white}' is probably a concommand!",
            cvarName,
            client,
            cvarName
        );
    }
    else if (result == ConVarQuery_Protected)
    {
        MC_PrintToChat
        (
            user,
            "{white}Cvar '{springgreen}%s{white}' is protected - {red}Cannot query!",
            cvarName
        );
    }
    else
    {
        MC_PrintToChatEx
        (
            user,
            client,
            "{white}Value of cvar '{springgreen}%s{white}' on {teamcolor}%N{white} is '{springgreen}%s{white}'",
            cvarName,
            client,
            cvarValue
        );
    }
}

public Action Command_GetNetInfo(int client, int args)
{
    int user = client;
    if (args != 1)
    {
        MC_ReplyToCommand(client, "{white}Usage: sm_netinfo {darkgray}<client>");
    }
    else
    {
        char arg1[32];
        GetCmdArg(1, arg1, sizeof(arg1));

        char target_name[MAX_TARGET_LENGTH];
        int target_list[MAXPLAYERS];
        int target_count;
        bool tn_is_ml;

        if
        (
            (
                target_count = ProcessTargetString
                (
                    arg1,
                    client,
                    target_list,
                    MAXPLAYERS,
                    COMMAND_FILTER_NO_BOTS,
                    target_name,
                    sizeof(target_name),
                    tn_is_ml
                )
            )
            <= 0
        )
        {
            ReplyToTargetError(client, target_count);
            return Plugin_Handled;
        }

        for (int i = 0; i < target_count; i++)
        {
            int Cl = target_list[i];
            if (IsValidClient(Cl))
            {
                // percentages
                float loss      = GetClientAvgLoss   (Cl, NetFlow_Both) * 100.0;
                float choke     = GetClientAvgChoke  (Cl, NetFlow_Both) * 100.0;
                float inchoke   = GetClientAvgChoke  (Cl, NetFlow_Incoming) * 100.0;
                float outchoke  = GetClientAvgChoke  (Cl, NetFlow_Outgoing) * 100.0;
                // ms
                float avgping   = GetClientAvgLatency(Cl, NetFlow_Both) * 1000.0;
                float ping      = GetClientLatency   (Cl, NetFlow_Both) * 1000.0;

                // bytes/sec
                float avgdata   = GetClientAvgData   (Cl, NetFlow_Both);

                if (user != 0)
                {
                    MC_PrintToChatEx
                    (
                        user,
                        Cl,
                        "\n{white}Network info for {teamcolor}%N{white}:\
                        \nloss: {springgreen}%.2f{white}%%\
                        \nchoke: {springgreen}%.2f{white}%%\
                        \ninchoke: {springgreen}%.2f{white}%%\
                        \noutchoke: {springgreen}%.2f{white}%%",
                        Cl,
                        loss,
                        choke,
                        inchoke,
                        outchoke
                    );
                    MC_PrintToChatEx
                    (
                        user,
                        Cl,
                        "{white}MORE network info for {teamcolor}%N{white}:\
                        \navgping: {springgreen}%.2f{white}ms\
                        \nping: {springgreen}%.2f{white}ms\
                        \navgdata rate: {springgreen}%.2f{white} Bytes/sec",
                        Cl,
                        avgping,
                        ping,
                        avgdata
                    );
                }
                else
                {
                    LogMessage
                    (
                        "\nNetwork info for %N:\
                        \n loss:     %.2f%%\
                        \n choke:    %.2f%%\
                        \n inchoke:  %.2f%%\
                        \n outchoke: %.2f%%\
                        ",
                        Cl,
                        loss,
                        choke,
                        inchoke,
                        outchoke
                    );
                    LogMessage
                    (
                        "MORE network info for %N:\
                        \n avgping: %.2fms\
                        \n ping: %.2fms\
                        \n avgdata rate: %.2f Bytes/sec\
                        ",
                        Cl,
                        avgping,
                        ping,
                        avgdata
                    );
                }
            }
        }
    }
    return Plugin_Handled;
}

public Action Command_GetIP(int client, int args)
{
    int user = client;
    if (args != 1)
    {
        MC_ReplyToCommand(client, "{white}Usage: sm_ip {darkgray}<client>");
    }
    else
    {
        char arg1[32];
        GetCmdArg(1, arg1, sizeof(arg1));

        char target_name[MAX_TARGET_LENGTH];
        int target_list[MAXPLAYERS];
        int target_count;
        bool tn_is_ml;

        if
        (
            (
                target_count = ProcessTargetString
                (
                    arg1,
                    client,
                    target_list,
                    MAXPLAYERS,
                    COMMAND_FILTER_NO_BOTS,
                    target_name,
                    sizeof(target_name),
                    tn_is_ml
                )
            )
            <= 0
        )
        {
            ReplyToTargetError(client, target_count);
            return Plugin_Handled;
        }

        for (int i = 0; i < target_count; i++)
        {
            int Cl = target_list[i];
            if (IsValidClient(Cl))
            {
                QueryClientConVar(Cl, "clientport", ClientPortQueryFinished, user);
            }
        }
    }
    return Plugin_Handled;
}

void ClientPortQueryFinished(QueryCookie cookie, int Cl, ConVarQueryResult result, const char[] cvarName, const char[] cvarValue, int user)
{
    char ip[48];
    GetClientIP(Cl, ip, sizeof(ip));
    char city[45];
    char region[45];
    char country_name[45];
    char country_code[3];
    char country_code3[4];

    GeoipGetRecord(ip, city, region, country_name, country_code, country_code3);
    MC_PrintToChatEx
    (
        user,
        Cl,
        "\n{white}GeoIP info for {teamcolor}%N{white}:\
        \n{white}IP address: {springgreen}%s\
        \n{white}Port: {springgreen}%s\
        \n{white}City: {springgreen}%s\
        \n{white}Region: {springgreen}%s\
        \n{white}Country Name: {springgreen}%s",
        Cl,
        ip,
        cvarValue,
        city,
        region,
        country_name
    );
}

bool IsValidClient(int client)
{
    return
    (
        (0 < client <= MaxClients)
        && IsClientInGame(client)
        && !IsFakeClient(client)
    );
}
