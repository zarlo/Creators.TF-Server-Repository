#include <sourcemod>

#pragma semicolon 1
#pragma newdecls required

#define PLUGIN_NAME "TF2 Pipebomb Hitbox Fix"
#define PLUGIN_DESC "Forces all pipebombs to have the same bounding box (Iron Bomber is larger by default)"
#define PLUGIN_AUTHOR "Bakugo"
#define PLUGIN_VERSION "1.0.0"
#define PLUGIN_URL "https://steamcommunity.com/profiles/76561198020610103"

public Plugin myinfo = {
	name = PLUGIN_NAME,
	description = PLUGIN_DESC,
	author = PLUGIN_AUTHOR,
	version = PLUGIN_VERSION,
	url = PLUGIN_URL
};

Handle cvar_enable;
Handle cvar_radius;
int pipes[10];

public void OnPluginStart() {
	CreateConVar("sm_pipe_hitbox_fix__version", PLUGIN_VERSION, (PLUGIN_NAME ... " - Version"), (FCVAR_NOTIFY|FCVAR_DONTRECORD));

	cvar_enable = CreateConVar("sm_pipe_hitbox_fix__enable", "1", (PLUGIN_NAME ... " - Enable plugin"), _, true, 0.0, true, 1.0);
	cvar_radius = CreateConVar("sm_pipe_hitbox_fix__radius", "2.0", (PLUGIN_NAME ... " - Hitbox radius (default is 2.0, IB uses 4.375)"), _, true, 1.0, true, 100.0);
}

public void OnGameFrame() {
	int idx;
	float vec[3];

	for (idx = 0; idx < sizeof(pipes); idx++) {
		if (pipes[idx] != 0) {
			if (GetConVarBool(cvar_enable)) {
				vec[0] = GetConVarFloat(cvar_radius);
				vec[1] = vec[0];
				vec[2] = vec[0];

				SetEntPropVector(pipes[idx], Prop_Data, "m_vecMaxs", vec);

				NegateVector(vec);

				SetEntPropVector(pipes[idx], Prop_Data, "m_vecMins", vec);
			}

			pipes[idx] = 0;
		}
	}
}

public void OnEntityCreated(int entity, const char[] class) {
	int idx;

	if (StrEqual(class, "tf_projectile_pipe")) {
		for (idx = 0; idx < sizeof(pipes); idx++) {
			if (pipes[idx] == 0) {
				pipes[idx] = entity;
				break;
			}
		}
	}
}

public void OnEntityDestroyed(int entity) {
	int idx;

	for (idx = 0; idx < sizeof(pipes); idx++) {
		if (pipes[idx] == entity) {
			pipes[idx] = 0;
		}
	}
}
