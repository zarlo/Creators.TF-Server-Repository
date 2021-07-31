#include <sourcemod>
#include <tf2>
#include <tf2_stocks>
#undef REQUIRE_PLUGIN
#include <adminmenu>

#define VERSION "1.2-creators"

new Handle:hAdminMenu = INVALID_HANDLE;
new Handle:hPlayerSelectMenu = INVALID_HANDLE;
new Handle:hAmountSelectMenu = INVALID_HANDLE;

public Plugin:myinfo = 
{
	name = "MvM Set/Add Money",
	author = "Chefe, Potatofactory",
	description = "Add/set players amount of cash",
	version = VERSION,
	url = "http://forums.alliedmods.net/showthread.php?t=197909"
}

public OnPluginStart()
{
	RegAdminCmd("sm_setmoney", Command_SetMoney, ADMFLAG_SLAY, "Set money of specifed userid");
	RegAdminCmd("sm_addmoney", Command_AddMoney, ADMFLAG_SLAY, "Set money of specifed userid");
	CreateConVar("sm_setaddmoney_version", VERSION, "Version of the Plugin", FCVAR_NOTIFY);
	
	AutoExecConfig(true);
	
	Handle topmenu;
	if (LibraryExists("adminmenu") && ((topmenu = GetAdminTopMenu()) != INVALID_HANDLE))
	{
		OnAdminMenuReady(topmenu);
	}
}


public OnLibraryRemoved(const String:name[])
{
	if (StrEqual(name, "adminmenu"))
	{
		hAdminMenu = INVALID_HANDLE;
	}
}

public OnAdminMenuReady(Handle:topmenu)
{
	/* Block us from being called twice */
	if (topmenu == hAdminMenu)
	{
		return;
	}
	
	hAdminMenu = topmenu;
	/* If the category is third party, it will have its own unique name. */
	new TopMenuObject:player_commands = FindTopMenuCategory(hAdminMenu, ADMINMENU_PLAYERCOMMANDS);
 
	if (player_commands == INVALID_TOPMENUOBJECT)
	{
		/* Error! */
		return;
	}
 
	AddToTopMenu(hAdminMenu, "sm_addmoney", TopMenuObject_Item, AdminMenu_AddMoney, player_commands, "sm_addmoney", ADMFLAG_SLAY);
}

public AdminMenu_AddMoney(Handle:topmenu, TopMenuAction:action, TopMenuObject:object_id, param, String:buffer[], maxlength)
{
	if (action == TopMenuAction_DisplayOption)
	{
		Format(buffer, maxlength, "Add Money (MvM)");
	}
	else if (action == TopMenuAction_SelectOption)
	{
		hPlayerSelectMenu = CreateMenu(Menu_PlayerSelect);
		SetMenuTitle(hPlayerSelectMenu, "Select Target");
		
		for (new i=1; i<=MaxClients; i++)
		{
			if (!IsClientInGame(i))
			{
				continue;
			}
			else if (IsFakeClient(i))
			{
				continue;
			}
			
			new String:infostr[128];
			Format(infostr, sizeof(infostr), "%N (%i)", i, GetClientCash(i));
			
			new String:indexstr[32];
			IntToString(i, indexstr, sizeof(indexstr)); 
			
			AddMenuItem(hPlayerSelectMenu,indexstr, infostr);
		}
		
		InsertMenuItem(hPlayerSelectMenu, 0, "red", "Team Red");
		InsertMenuItem(hPlayerSelectMenu, 1, "blue", "Team Blu");
		InsertMenuItem(hPlayerSelectMenu, 2, "all", "All Player");
		
		SetMenuExitButton(hPlayerSelectMenu, true);
		DisplayMenu(hPlayerSelectMenu, param, MENU_TIME_FOREVER);
	}
}

public Menu_PlayerSelect(Handle:menu, MenuAction:action, param1, param2)
{
	/* If an option was selected, tell the client about the item. */
	if (action == MenuAction_Select)
	{
		new String:info[32];
		GetMenuItem(menu, param2, info, sizeof(info));
		
		hAmountSelectMenu = CreateMenu(Menu_AmountSelect);
		SetMenuTitle(hAmountSelectMenu, "Select Amount");
		
		AddMenuItem(hAmountSelectMenu, "50", "50");
		AddMenuItem(hAmountSelectMenu, "100", "100");
		AddMenuItem(hAmountSelectMenu, "500", "500");
		AddMenuItem(hAmountSelectMenu, "1000", "1000");
		AddMenuItem(hAmountSelectMenu, "5000", "5000");
		AddMenuItem(hAmountSelectMenu, "10000", "10000");
		AddMenuItem(hAmountSelectMenu, "30000", "30000");
		
		AddMenuItem(hAmountSelectMenu, info, "", ITEMDRAW_IGNORE);
		
		SetMenuExitButton(hAmountSelectMenu, true);
		DisplayMenu(hAmountSelectMenu, param1, MENU_TIME_FOREVER);
	}
	/* If the menu was cancelled, print a message to the server about it. */
	else if (action == MenuAction_Cancel)
	{
		
	}
	/* If the menu has ended, destroy it */
	else if (action == MenuAction_End)
	{
		CloseHandle(menu);
	}
}

public Menu_AmountSelect(Handle:menu, MenuAction:action, param1, param2)
{
	/* If an option was selected, tell the client about the item. */
	if (action == MenuAction_Select)
	{
		new String:stramount[32];
		GetMenuItem(menu, param2, stramount, sizeof(stramount));
		new amount = StringToInt(stramount);
		
		new String:target[32];
		GetMenuItem(menu, GetMenuItemCount(menu)-1, target, sizeof(target));
		
		if (!StrEqual(target, "blue") && !StrEqual(target, "red") && !StrEqual(target, "all"))
		{
			new client = StringToInt(target);
			
			if (IsClientInGame(client))
			{
				AddClientCash(client, amount);
			}
		}
		else
		{
			if (StrEqual(target, "red") || StrEqual(target, "blue"))
			{
				new targetteam = FindTeamByName(target);
				
				for (new i=1; i <= MaxClients; i++)
				{
					if (!IsClientInGame(i))
					{
						continue;
					}
					else if (IsFakeClient(i))
					{
						continue;
					}
					
					if (GetClientTeam(i) == targetteam)
					{
						AddClientCash(i, amount);
					}
				}
			}
			else if (StrEqual(target, "all"))
			{
				for (new i=1; i<=MaxClients; i++)
				{
					if (!IsClientInGame(i))
					{
						continue;
					}
					else if (IsFakeClient(i))
					{
						continue;
					}
					
					AddClientCash(i, amount);
				}
			}
		}
	}
	/* If the menu was cancelled, print a message to the server about it. */
	else if (action == MenuAction_Cancel)
	{
		
	}
	/* If the menu has ended, destroy it */
	else if (action == MenuAction_End)
	{
		CloseHandle(menu);
	}
}

public Action:Command_SetMoney(client, args)
{
	if (!GameRules_GetProp("m_bPlayingMannVsMachine"))
	{
		return Plugin_Handled;
	}
	
	if (args < 1)
	{
		PrintToConsole(client, "[SM] Usage: sm_setmoney <#userid|name> <amount>");
		return Plugin_Handled;
	}
	
	decl String:amount[10], iAmount;
	GetCmdArg(2, amount, sizeof(amount));
	iAmount = StringToInt(amount);

	char targets[32];
	GetCmdArg(1, targets, sizeof(targets));

	decl arrTargetList[MAXPLAYERS], iCount;
	decl String:targetName[MAX_TARGET_LENGTH];
	decl bool:tn_is_m1;

	if ((iCount = ProcessTargetString( targets, client, arrTargetList, MAXPLAYERS, COMMAND_FILTER_ALIVE, targetName, sizeof(targetName), tn_is_m1)) <= 0)
	{
		ReplyToTargetError(client, iCount);
		return Plugin_Handled;
	}
	
	for (int i = 0; i < iCount; i++)
	{
	  SetClientCash(arrTargetList[i], iAmount);
	}
	
	return Plugin_Handled;
}

public Action:Command_AddMoney(client, args)
{
	if (!GameRules_GetProp("m_bPlayingMannVsMachine"))
	{
		return Plugin_Handled;
	}
	
	if (args < 1)
	{
		PrintToConsole(client, "[SM] Usage: sm_addmoney <#userid|name> <amount>");
		return Plugin_Handled;
	}
	
	decl String:amount[10], iAmount;
	GetCmdArg(2, amount, sizeof(amount));
	iAmount = StringToInt(amount);

	char targets[32];
	GetCmdArg(1, targets, sizeof(targets));
 
	decl arrTargetList[MAXPLAYERS], iCount;
	decl String:targetName[MAX_TARGET_LENGTH];
	decl bool:tn_is_m1;

	if ((iCount = ProcessTargetString( targets, client, arrTargetList, MAXPLAYERS, COMMAND_FILTER_ALIVE, targetName, sizeof(targetName), tn_is_m1)) <= 0)
	{
		ReplyToTargetError(client, iCount);
		return Plugin_Handled;
	}
	
	for (int i = 0; i < iCount; i++)
	{
	  AddClientCash(arrTargetList[i], iAmount);
	}
	
	return Plugin_Handled;
}

stock hClientCash(amount) 
{
	new maxClients = GetMaxClients();
	for (new i=1; i<=maxClients; i++)
	{
		if (!IsClientInGame(i))
		{
			continue;
		}
		
		if (!IsFakeClient(i))
		{
			AddClientCash(i, amount);
		}
	}
}

GetClientCash(iClient)
{
	return GetEntProp(iClient, Prop_Send, "m_nCurrency");
}

SetClientCash(iClient, iAmount)
{
	SetEntProp(iClient, Prop_Send, "m_nCurrency", iAmount);
}

AddClientCash(iClient, iAmount)
{
	SetClientCash(iClient, iAmount + GetClientCash(iClient));
}
