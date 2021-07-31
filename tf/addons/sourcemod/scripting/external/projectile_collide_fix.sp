#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <dhooks>

#pragma semicolon 1
#pragma newdecls required

#define PLUGIN_NAME "TF2 Projectile Collision Fix"
#define PLUGIN_DESC "Fixes some projectiles colliding incorrectly with map geometry"
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

enum struct Projectile {
	int entity;
	float position[3];
}

Projectile projectiles[20];
Handle dhook_CTFProjectileOrnament_ProjectileTouch;
Handle dhook_CTFProjectileEnergyRing_ProjectileTouch;
Handle dhook_CTFProjectileBallOfFire_ProjectileTouch;

public void OnPluginStart() {
	Handle conf;
	
	CreateConVar("sm_projectile_collide_fix__version", PLUGIN_VERSION, (PLUGIN_NAME ... " - Version"), (FCVAR_NOTIFY|FCVAR_DONTRECORD));
	
	conf = LoadGameConfigFile("projectile_collide_fix");
	
	if (conf == null) {
		SetFailState("Failed to load conf");
	}
	
	dhook_CTFProjectileOrnament_ProjectileTouch = DHookCreateFromConf(conf, "CTFBall_Ornament::PipebombTouch");
	dhook_CTFProjectileEnergyRing_ProjectileTouch = DHookCreateFromConf(conf, "CTFProjectile_EnergyRing::ProjectileTouch");
	dhook_CTFProjectileBallOfFire_ProjectileTouch = DHookCreateFromConf(conf, "CTFProjectile_BallOfFire::RocketTouch");
	
	CloseHandle(conf);
	
	if (dhook_CTFProjectileOrnament_ProjectileTouch == null) SetFailState("Failed to create dhook_CTFProjectileOrnament_ProjectileTouch");
	if (dhook_CTFProjectileEnergyRing_ProjectileTouch == null) SetFailState("Failed to create dhook_CTFProjectileEnergyRing_ProjectileTouch");
	if (dhook_CTFProjectileBallOfFire_ProjectileTouch == null) SetFailState("Failed to create dhook_CTFProjectileBallOfFire_ProjectileTouch");
	
	DHookEnableDetour(dhook_CTFProjectileOrnament_ProjectileTouch, false, DHookCallback_ProjectileTouch);
	DHookEnableDetour(dhook_CTFProjectileEnergyRing_ProjectileTouch, false, DHookCallback_ProjectileTouch);
	DHookEnableDetour(dhook_CTFProjectileBallOfFire_ProjectileTouch, false, DHookCallback_ProjectileTouch);
}

public void OnGameFrame() {
	int idx;
	
	for (idx = 0; idx < sizeof(projectiles); idx++) {
		if (projectiles[idx].entity != 0) {
			// save the projectile's position for this frame
			GetEntPropVector(projectiles[idx].entity, Prop_Send, "m_vecOrigin", projectiles[idx].position);
		}
	}
}

public void OnEntityCreated(int entity, const char[] class) {
	int idx;
	
	if (
		StrEqual(class, "tf_projectile_ball_ornament") ||
		StrEqual(class, "tf_projectile_energy_ring") ||
		StrEqual(class, "tf_projectile_balloffire")
	) {
		for (idx = 0; idx < sizeof(projectiles); idx++) {
			if (projectiles[idx].entity == 0) {
				// add this projectile to the list and keep track of it
				projectiles[idx].entity = entity;
				SDKHook(entity, SDKHook_Spawn, SDKHookCB_Spawn);
				break;
			}
		}
	}
}

public void OnEntityDestroyed(int entity) {
	int idx;
	
	for (idx = 0; idx < sizeof(projectiles); idx++) {
		if (projectiles[idx].entity == entity) {
			projectiles[idx].entity = 0;
		}
	}
}

Action SDKHookCB_Spawn(int entity) {
	int idx;
	
	for (idx = 0; idx < sizeof(projectiles); idx++) {
		if (projectiles[idx].entity == entity) {
			// in case the entity collides immediately after spawning
			GetEntPropVector(entity, Prop_Send, "m_vecOrigin", projectiles[idx].position);
			break;
		}
	}
}

MRESReturn DHookCallback_ProjectileTouch(int entity, Handle params) {
	int idx;
	int other;
	float pos1[3];
	float pos2[3];
	float hull_mins[3];
	float hull_maxs[3];
	
	other = DHookGetParam(params, 1);
	
	if (other > MaxClients) {
		for (idx = 0; idx < sizeof(projectiles); idx++) {
			if (projectiles[idx].entity == entity) {
				GetEntPropVector(entity, Prop_Send, "m_vecOrigin", pos1);
				
				// roughly predict the projectile's next position, based on last and current position
				SubtractVectors(pos1, projectiles[idx].position, pos2);
				ScaleVector(pos2, 1.3);
				AddVectors(pos1, pos2, pos2);
				
				hull_maxs[0] = 5.0;
				hull_mins[0] = (0.0 - hull_maxs[0]);
				hull_maxs[1] = hull_maxs[0]; hull_maxs[2] = hull_maxs[0];
				hull_mins[1] = hull_mins[0]; hull_mins[2] = hull_mins[0];
				
				// check if the projectile will collide with this entity in its next position
				TR_TraceHullFilter(pos1, pos2, hull_mins, hull_maxs, MASK_SOLID, TraceFilter_IncludeSingle, other);
				
				if (TR_DidHit() == false) {
					// trace did not hit, cancel the collision
					return MRES_Supercede;
				}
				
				break;
			}
		}
	}
	
	return MRES_Ignored;
}

bool TraceFilter_IncludeSingle(int entity, int contentsmask, any data) {
	return (entity == data);
}
