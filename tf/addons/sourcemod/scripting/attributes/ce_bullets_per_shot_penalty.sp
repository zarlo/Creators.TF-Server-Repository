#pragma semicolon 1
#pragma newdecls required

#include <cecon_items>
#include <tf2attributes>

public Plugin myinfo =
{
	name = "[CE Attribute] weapon maxammo",
	author = "Creators.TF Team",
	description = "weapon maxammo",
	version = "1.00",
	url = "https://creators.tf"
};

public void CEconItems_OnItemIsEquipped(int client, int entity, CEItem xItem, const char[] type)
{
	if(IsValidEntity(entity) && HasEntProp(entity, Prop_Send, "m_iItemDefinitionIndex"))
	{
		float flPenalty = CEconItems_GetEntityAttributeFloat(entity, "bullets per shot penalty");
		if(flPenalty > 0.0)
		{
			TF2Attrib_SetByName(entity, "bullets per shot bonus", flPenalty);
		}
	}
}
