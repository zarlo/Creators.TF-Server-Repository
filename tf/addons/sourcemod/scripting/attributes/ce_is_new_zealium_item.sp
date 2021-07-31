#pragma semicolon 1
#pragma newdecls required

#include <cecon_items>

public Plugin myinfo =
{
	name = "[CE Attribute] is new zealium item",
	author = "Creators.TF Team",
	description = "is new zealium item",
	version = "1.00",
	url = "https://creators.tf"
};

public void CEconItems_OnItemIsEquipped(int client, int entity, CEItem xItem, const char[] type)
{
	// But if we dont check this, we may create australium cosmetics :thinking:
	if (strcmp(type, "weapon") != 0) return;
	
	if (CEconItems_GetEntityAttributeBool(entity, "is new zealium item"))
	{
		CEconItems_SetCustomEntityStyle(entity, 1);
	}
}