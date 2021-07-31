#if defined __tf_persist_item_included
	#endinput
#endif

#define __tf_persist_item_included

/**
 * Called when the server is checking for loadout items.
 * 
 * Return Plugin_Handled or higher to keep the current item, otherwise it will be replaced with
 * whatever's active in the player's inventory.
 * 
 * @param client        Player being checked.
 * @param item          Currently active item.
 */
forward Action TF2_OnReplaceItem(int client, int item);

public SharedPlugin __pl_tf_persist_item = {
	name = "tf_persist_item",
	file = "tf_persist_item.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};
