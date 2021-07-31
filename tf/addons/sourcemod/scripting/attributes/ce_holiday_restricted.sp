#pragma semicolon 1

#include <sdkhooks>
#include <cecon_items>
#include <tf2_stocks>

public Plugin myinfo =
{
	name = "[CE Attribute] holiday restricted",
	author = "Creators.TF Team",
	description = "holiday restricted",
	version = "1.0",
	url = "https://creators.tf"
}

enum CEHoliday
{
	CEHoliday_Invalid,
	CEHoliday_Birthday,
	CEHoliday_Halloween,
	CEHoliday_HalloweenOrFullMoon,
	CEHoliday_AprilFools
}

public bool CEconItems_ShouldItemBeBlocked(int client, CEItem xItem, const char[] type)
{
	if (!StrEqual(type, "cosmetic"))return false;
	
	CEHoliday nHoliday = view_as<CEHoliday>(CEconItems_GetAttributeIntegerFromArray(xItem.m_Attributes, "holiday restricted"));
	
	switch(nHoliday)
	{
		case CEHoliday_Halloween:
		{
			return !TF2_IsHolidayActive(TFHoliday_Halloween); 
		}
		case CEHoliday_HalloweenOrFullMoon:
		{
			return !TF2_IsHolidayActive(TFHoliday_HalloweenOrFullMoon); 
		}
		case CEHoliday_AprilFools:
		{
			return !TF2_IsHolidayActive(TFHoliday_AprilFools); 
		}
	}
	
	return false;
}