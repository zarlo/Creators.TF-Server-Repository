#define MAXITEMS 2048
#define MAXQUALITIES 16
#define MAXUNUSUALS 256
#define MAXATTRIBUTES 256
#define MAXATTRGROUPS 32
#define MAXAGROUPVALUES 2048
#define MAXCOLLECTIONS 32
#define MAXSTORES 32
#define MAXSTOREGOODS 64

#define MAXQUESTS 256
#define MAXQUESTTASKS 3

char TeamColors[4][7] = {
	"FFFFFF",
	"FFFFFF",
	"FF4040",
	"99CCFF"
};

enum PlayerCounters{
	COUNTER_KILLS,
	SENTRY_KILLS
}

enum PlayerBuildables{
	OBJ_SENTRYGUN,
	OBJ_DISPENSER,
	OBJ_TELEPORTER_ENTR,
	OBJ_TELEPORTER_EXIT
}

enum QuestConds{
	QUEST_COND_NO_COND,
	// 0
	QUEST_COND_KILL,
	QUEST_COND_DOMINATE,
	QUEST_COND_MVP,
	QUEST_COND_KILL_IN_KART,
	QUEST_COND_KILL_IN_HELL,
	// 5
	QUEST_COND_ESCAPE_HELL,
	QUEST_COND_PUMPKIN_GRAB,
	QUEST_COND_PUMPKIN_KILL,
	QUEST_COND_CRUMPKIN_KILL,
	QUEST_COND_DEPOSIT_SOUL,
	// 10
	QUEST_COND_PICKUP_SOUL,
	QUEST_COND_KILLING_SCARED,
	QUEST_COND_ESCAPE_LOOT_ISLAND,
	QUEST_COND_KILL_IN_PURGATORY,
	QUEST_COND_SCORE,
	// 15
	QUEST_COND_SAPPER_REMOVE,
	QUEST_COND_5_KILLS_IN_LIFE,
	QUEST_COND_6_KILLS_SG,
	QUEST_COND_FLAG_CAPTURE
}

enum QuestTask {
	String:sName[64],
	QuestConds:iCond,
	iLimit,
	iCP,
	iDifficulty,
	String:sMap[32],
	iClass
}

enum QuestReward {
	iItem,
	iItemQuality,
	iCredit
}

enum Quest{
	String:sName[64],
	iId,
	iCampaign,
	iReward[QuestReward],
	bool:bUpdated,
	bool:bCreated,
	bool:bTurned
}

enum UnusualType {
	UNUSUAL_SMALL,
	UNUSUAL_BIG,
	UNUSUAL_WEAPON,
	UNUSUAL_SPECIFIC
}

enum OriginType
{
	STAFF_GIVEN,
	BOUGHT,
	CASE,
	DROP,
	QUEST
}

enum AttrGroupUse{
	USE_NOTHING,
	USE_ITEM_NAMES,
	USE_UNUSUAL_NAMES
}

enum AttributeEnum{
	iIndex,
	String:sDesc[128],
	iGroup,
	iGroupUse,
	String:sName[64],
	bool:bHidden
}

enum QualityEnum{
	iIndex,
	String:sName[16],
	String:sColor[6],
	iColor[3]
}

enum UnusualEnum{
	iIndex,
	String:sSystem[64],
	String:sName[32],
	String:sFile[64],
	iDef,
	iType
}

enum ItemTypesEnum {
	TYPE_WEAPON,
	TYPE_SENTRYHAT,
	TYPE_DISPENSERHAT,
	TYPE_PET,
	TYPE_EMOTE,
	TYPE_TOOL,
	TYPE_PLAYERMODEL
}

enum PlayerDataEnum {
	bool:bLogged,
	iUID,
	String:sSteamID[32],
	String:sToken[32],
	String:sLoadout[512],
	iExp,
	iCredit,
	iVerified,
	iCExp,
	iKillstreak,
	iContract
}

enum EquipSlotsEnum {
	// 0
	SLOT_NONE,
	SLOT_SCOUT_PRIMARY,
	SLOT_SCOUT_SECONDARY,
	SLOT_SCOUT_MELEE,
	SLOT_SOLDIER_PRIMARY,
	SLOT_SOLDIER_SECONDARY,
	// 5
	SLOT_SOLDIER_MELEE,
	SLOT_PYRO_PRIMARY,
	SLOT_PYRO_SECONDARY,
	SLOT_PYRO_MELEE,
	SLOT_DEMOMAN_PRIMARY,
	// 10
	SLOT_DEMOMAN_SECONDARY,
	SLOT_DEMOMAN_MELEE,
	SLOT_HEAVY_PRIMARY,
	SLOT_HEAVY_SECONDARY,
	SLOT_HEAVY_MELEE,
	// 15
	SLOT_ENGINEER_PRIMARY,
	SLOT_ENGINEER_SECONDARY,
	SLOT_ENGINEER_MELEE,
	SLOT_ENGINEER_PDA,
	SLOT_MEDIC_PRIMARY,
	// 20
	SLOT_MEDIC_SECONDARY,
	SLOT_MEDIC_MELEE,
	SLOT_SNIPER_PRIMARY,
	SLOT_SNIPER_SECONDARY,
	SLOT_SNIPER_MELEE,
	// 25
	SLOT_SPY_PRIMARY,
	SLOT_SPY_SECONDARY,
	SLOT_SPY_MELEE,
	SLOT_SPY_SAPPER,
	SLOT_MULTI_PET,
	// 30
	SLOT_ENGINEER_SENTRYHAT,
	SLOT_ENGINEER_DISPENSERHAT,
	SLOT_SCOUT_PLAYERMODEL,
	SLOT_SOLDIER_PLAYERMODEL,
	SLOT_PYRO_PLAYERMODEL,
	// 35
	SLOT_DEMOMAN_PLAYERMODEL,
	SLOT_HEAVY_PLAYERMODEL,
	SLOT_ENGINEER_PLAYERMODEL,
	SLOT_MEDIC_PLAYERMODEL,
	SLOT_SNIPER_PLAYERMODEL,
	// 40
	SLOT_SPY_PLAYERMODEL
}

enum ItemCacheEnum {
	iDef,
	iType,
	String:sName[64],
	String:sDesc[1024],
	String:AttribsCustom[128],
	iUType
}