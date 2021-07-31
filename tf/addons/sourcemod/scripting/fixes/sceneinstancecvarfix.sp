#include <sourcemod>

#define PLUGIN_NAME "Scene Instance cvar fix"
#define PLUGIN_DESC "Adds snd_mixahead cvar to stop cvar lookups when scene instances are created"
#define PLUGIN_AUTHOR "rafradek"
#define PLUGIN_VERSION "1.0.0"
#define PLUGIN_URL ""

public Plugin myinfo = {
	name = PLUGIN_NAME,
	description = PLUGIN_DESC,
	author = PLUGIN_AUTHOR,
	version = PLUGIN_VERSION,
	url = PLUGIN_URL
};

public void OnPluginStart() {
    if (FindConVar("snd_mixahead") == null)
	    CreateConVar("snd_mixahead", "0.1", "Sound system latency");
}