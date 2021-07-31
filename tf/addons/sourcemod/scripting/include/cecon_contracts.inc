#define MAX_OBJECTIVES 10
#define MAX_HOOKS 4

enum CEQuestActions
{
	CEQuestAction_Singlefire,
	CEQuestAction_Increment,
	CEQuestAction_Reset,
	CEQuestAction_Subtract,
	CEQuestAction_Set
}

enum struct CEQuestDefinition
{
	int m_iIndex;

	char m_sName[128];
	char m_sPostfix[5];

	bool m_bBackground;
	bool m_bDisableEventSharing;

	int m_iObjectivesCount;
	int m_Objectives[MAX_OBJECTIVES];

	// Map restrictions.
	char m_sRestrictedToMap[64];
	char m_sStrictRestrictedToMap[64];

	// TF2 class restriction.
	TFClassType m_nRestrictedToClass;

	// Active weapon restriction.
	char m_sRestrictedToItemName[64];
	char m_sRestrictedToClassname[64];
	int m_nRestrictedToWeaponSlot;

	// Item Restriction
	char m_sRestrictedToItemClassname[48];
	char m_sRestrictedToItemItemName[64];
	
	// Used for optimization purposes.
	// Allows to check if we need to run a specific event 
	// even without going through events.
	char m_sAggregatedEvents[512];
}

enum struct CEQuestObjectiveDefinition
{
	int m_iIndex;
	int m_iQuestIndex;

	char m_sName[128];

	int m_iPoints; 	// Points multiplier for every event
	int m_iLimit; 	// Maximum amount of points
	int m_iEnd;		// Amount of points to trigger objective with non-singlefire event.

	int m_iHooksCount;
	int m_Hooks[MAX_HOOKS];

	// Active weapon restriction.
	char m_sRestrictedToItemName[64];
	char m_sRestrictedToClassname[64];
	int m_nRestrictedToWeaponSlot;
	
	// Item Restriction
	char m_sRestrictedToItemClassname[48];
	char m_sRestrictedToItemItemName[64];
}

enum struct CEQuestObjectiveHookDefinition
{
	int m_iIndex;
	int m_iObjectiveIndex;
	int m_iQuestIndex;

	char m_sEvent[64];

	float m_flDelay;
	float m_flSubtractIn;

	CEQuestActions m_Action;
}

enum struct CEQuestClientProgress
{
	int m_iClient;
	int m_iQuest;

	int m_iProgress[MAX_OBJECTIVES + 1];
	int m_iVariable[MAX_OBJECTIVES + 1];

	int m_iSource;
}
