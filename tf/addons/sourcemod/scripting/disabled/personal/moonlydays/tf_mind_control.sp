#include <sourcemod>
#include <sdktools>
#include <tf2>
#include <tf2_stocks>

public Plugin myinfo =
{
	name = "Mind Control",
	author = "Mind Control",
	description = "Mind Control",
	version = "1.0",
	url = "https://steamcommunity.com/profiles/76561197963998743"
}

float m_flVel[MAXPLAYERS + 1][3];
bool m_bJumping;

public void OnPluginStart()
{
	HookEvent("post_inventory_application", post_inventory_application);
	RegConsoleCmd("sm_jump", cJump);
}

public Action cJump(int client, int args)
{
	PrintToChatAll("pog");
}

public Action post_inventory_application(Handle hEvent, const char[] szName, bool bDontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(hEvent, "userid"));
	
	if(!IsFakeClient(client))
	{
		TF2_RemoveAllWeapons(client);
		
		SetEntProp(client, Prop_Send, "m_iObserverMode", 4);
		SetEntPropEnt(client, Prop_Send, "m_hObserverTarget", 2);
	}
	

	return Plugin_Continue;
}

#define MOVEMENT_RAMP_UP 30.0
#define MOVEMENT_RAMP_DOWN 15.0

public Action OnPlayerRunCmd(int client, int &buttons)
{
	if(IsFakeClient(client))
	{
		if(m_bJumping)
		{
			PrintToChatAll("jumping");
			buttons |= IN_JUMP;
		}
	} else {
		int iTarget = GetEntPropEnt(client, Prop_Send, "m_hObserverTarget");
		if(IsValidEntity(iTarget) && IsClientInGame(iTarget))
		{
			float flVec[3];
			if(buttons & IN_FORWARD)
			{
				if(m_flVel[iTarget][0] < 300.0)
				{
					m_flVel[iTarget][0] += MOVEMENT_RAMP_UP;
				}
			} else {
				if(m_flVel[iTarget][0] > 0)
				{
					m_flVel[iTarget][0] -= MOVEMENT_RAMP_DOWN;
				}
			}
			if(buttons & IN_BACK)
			{
				if(m_flVel[iTarget][0] > -300.0)
				{
					m_flVel[iTarget][0] -= MOVEMENT_RAMP_UP;
				}
			} else {
				if(m_flVel[iTarget][0] < 0)
				{
					m_flVel[iTarget][0] += MOVEMENT_RAMP_DOWN;
				}
			}
			if(buttons & IN_MOVELEFT)
			{
				if(m_flVel[iTarget][1] < 300.0)
				{
					m_flVel[iTarget][1] += MOVEMENT_RAMP_UP;
				}
			} else {
				if(m_flVel[iTarget][1] > 0)
				{
					m_flVel[iTarget][1] -= MOVEMENT_RAMP_DOWN;
				}
			}
			if(buttons & IN_MOVERIGHT)
			{
				if(m_flVel[iTarget][1] > -300.0)
				{
					m_flVel[iTarget][1] -= MOVEMENT_RAMP_UP;
				}
			} else {
				if(m_flVel[iTarget][1] < 0)
				{
					m_flVel[iTarget][1] += MOVEMENT_RAMP_DOWN;
				}
			}
			
			if(buttons & IN_JUMP)
			{
				PrintToChatAll("jumping");
				buttons &= ~IN_JUMP;
				m_bJumping = true;
			} else {
				m_bJumping = false;
			}
			
			if(buttons & IN_DUCK)
			{
				buttons &= ~IN_DUCK;
			}
			TeleportEntity(iTarget, NULL_VECTOR, NULL_VECTOR, m_flVel[iTarget]);
		}
	}
	return Plugin_Continue;
}