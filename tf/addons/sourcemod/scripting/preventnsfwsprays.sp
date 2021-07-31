#pragma semicolon 1

#define PLUGIN_AUTHOR "Nanochip"
#define PLUGIN_VERSION "1.00"

#include <sourcemod>
#include <sdktools>
#include <clientprefs>
#include <morecolors>

#pragma newdecls required

public Plugin myinfo = 
{
	name = "Prevent NSFW Sprays",
	author = PLUGIN_AUTHOR,
	description = "Helps prevent NSFW sprays.",
	version = PLUGIN_VERSION,
	url = "https://steamcommunity.com/id/xNanochip"
};

g_bUnderstood[MAXPLAYERS + 1];
Handle cookie;

public void OnPluginStart()
{
	AddTempEntHook("Player Decal", OnClientSpray);
	
	cookie = RegClientCookie("preventnsfw", "Prevent NSFW Sprays Cookie", CookieAccess_Private);
	
	for (int i = 1; i <= MaxClients; i++)
	{
		if (AreClientCookiesCached(i)) OnClientCookiesCached(i); //late load
	}
}

public void OnClientCookiesCached(int client)
{
	char info[16];
	GetClientCookie(client, cookie, info, sizeof(info));
	if (strcmp(info, "true") == 0) g_bUnderstood[client] = true;
}

public Action OnClientSpray(const char[] te_name, const int[] clients, int client_count, float delay)
{
	int client = TE_ReadNum("m_nPlayer");
	if (client && IsClientInGame(client))
	{
		if (!IsClientAuthorized(client) || IsFakeClient(client))
		{
			return Plugin_Handled;
		}
		if (!g_bUnderstood[client])
		{
			Panel panel = new Panel();
			panel.SetTitle("Before you can spray, please agree to our decal rule:");
			panel.DrawText(" ");
			panel.DrawText("Pornographic, hate speech, and real life gore, death, \nor abuse content (eg. sprays) is prohibited.");
			panel.DrawText(" ");
			panel.DrawText("By selecting 'I agree' below, I understand and agree \nto the decal rule otherwise I will be banned.");
			panel.DrawText(" ");
			panel.DrawItem("I agree.", ITEMDRAW_CONTROL);
			panel.DrawItem("I do not agree.", ITEMDRAW_CONTROL);
			
			panel.Send(client, PanelHandler, 20);
			delete panel;
			return Plugin_Handled;
		}
	}
	return Plugin_Continue;
}

public int PanelHandler(Menu menu, MenuAction action, int client, int param2)
{
	if (action == MenuAction_Select)
	{
		ClientCommand(client, "playgamesound \"%s\"", "ui\\panel_close.wav");
		switch (param2)
		{
			case 1:
			{
				g_bUnderstood[client] = true;
				SetClientCookie(client, cookie, "true");
				MC_PrintToChat(client, "[{creators}Creators.TF{default}] Thank you for agreeing to our decal rule. You may now spray decals.");
			}
			case 2:
			{
				MC_PrintToChat(client, "[{creators}Creators.TF{default}] You may not spray decals till you select 'I agree'. If you truly do not understand the decal rule, send a message in #help-desk on our discord: https://creators.tf/discord");
			}
		}
	}
}