#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <tf2>

#define PLUGIN_VERSION "1.0.1"

bool bAllowSliding;

public Plugin myinfo = {
	name = "[TF2] Sliding Taunt Patch",
	author = "FlaminSarge",
	description = "Fixes the tf_allow_sliding_taunt cvar to function properly",
	version = PLUGIN_VERSION,
	url = "https://github.com/FlaminSarge"
}

public void OnPluginStart() {
	CreateConVar("tf_allow_sliding_taunt_version", PLUGIN_VERSION, "[TF2] Sliding Taunt Patch version", FCVAR_NOTIFY|FCVAR_DONTRECORD);

	ConVar cvSliding = FindConVar("tf_allow_sliding_taunt");
	cvSliding.AddChangeHook(CvhookSliding);
	bAllowSliding = cvSliding.BoolValue;
}

public void CvhookSliding(ConVar cvar, const char[] oldVal, const char[] newVal) {
	bAllowSliding = cvar.BoolValue;
}

public void TF2_OnConditionAdded(int client, TFCond condition) {
	if (!bAllowSliding) {
		return;
	}
	if (condition != TFCond_Taunting) {
		return;
	}
	int offs = GetEntSendPropOffs(client, "m_flVehicleReverseTime");
	if (offs <= 0) {
		return;
	}
	offs = offs + 8;	//"taunt move speed" attr sets this when taunt starts
	float speed = GetEntDataFloat(client, offs);
	float maxSpeed = GetEntPropFloat(client, Prop_Send, "m_flMaxspeed");
	if (speed == 0 && speed != maxSpeed) {
		SetEntDataFloat(client, offs, maxSpeed);
	}
}
