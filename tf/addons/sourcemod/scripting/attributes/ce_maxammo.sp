#pragma semicolon 1
#pragma newdecls required

#include <cecon_items>
#include <tf2attributes>
#include <tf_econ_data>

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
		int idx = GetEntProp(entity, Prop_Send, "m_iItemDefinitionIndex");
		int iSlot = TF2Econ_GetItemSlot(idx, TF2_GetPlayerClass(client));
		
		if(iSlot > -1)
		{
			float flBonus = CEconItems_GetEntityAttributeFloat(entity, "weapon maxammo bonus");
			if(flBonus > 0.0)
			{
				switch(iSlot)
				{
					case 0: TF2Attrib_SetByName(entity, "hidden primary max ammo bonus", flBonus);
					case 1: TF2Attrib_SetByName(entity, "hidden secondary max ammo penalty", flBonus);
				}

			}

			float flPenalty = CEconItems_GetEntityAttributeFloat(entity, "weapon maxammo penalty");
			if(flPenalty > 0.0)
			{
				switch(iSlot)
				{
					case 0: TF2Attrib_SetByName(entity, "hidden primary max ammo bonus", flPenalty);
					case 1: TF2Attrib_SetByName(entity, "hidden secondary max ammo penalty", flPenalty);
				}
			}
		}
	}
}
