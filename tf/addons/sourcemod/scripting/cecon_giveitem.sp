#pragma semicolon 1
#pragma newdecls required

#include <cecon_items>
#include <sdktools>

public Plugin myinfo =
{
	name = "Give Creators.TF Item",
	author = "Creators.TF Team",
	description = "Gives Creators.TF Item",
	version = "1.00",
	url = "https://creators.tf"
};

public void OnPluginStart()
{
	RegAdminCmd("sm_giveitem", cGive, ADMFLAG_SLAY, "Gives a Creators.TF item");
}

public Action cGive(int client, int args)
{
	if(args < 2)
	{
		ReplyToCommand(client, "[SM] Invalid syntax: ce_giveitem <item name> <@target>");
		return Plugin_Handled;
	}

	char sTarget[65];
	GetCmdArg(1, sTarget, sizeof(sTarget));

	char sItem[65];
	GetCmdArg(2, sItem, sizeof(sItem));

	CEItemDefinition xDef;
	if(!CEconItems_GetItemDefinitionByName(sItem, xDef))
	{
		ReplyToCommand(client, "[SM] Definition for item \"%s\" is not found.", sItem);
		return Plugin_Handled;
	}

	char target_name[MAX_TARGET_LENGTH];
	int target_list[MAXPLAYERS], target_count;
	bool tn_is_ml;

	if ((target_count = ProcessTargetString(
			sTarget,
			client,
			target_list,
			MAXPLAYERS,
			COMMAND_FILTER_ALIVE | COMMAND_FILTER_NO_IMMUNITY,
			target_name,
			sizeof(target_name),
			tn_is_ml)) <= 0)
	{
		ReplyToCommand(client, "[SM] No matching clients were found.");
		return Plugin_Handled;
	}

	for (int i = 0; i < target_count; i++)
	{
		int target = target_list[i];

		CEItem xItem;
		if(CEconItems_CreateNamedItem(xItem, sItem, 6, null))
		{
			CEconItems_GiveItemToClient(target, xItem);
		}
	}

	ShowActivity2(client, "[SM] ", "Given item \"%s\" to %s", sItem, target_name);
	return Plugin_Handled;
}
