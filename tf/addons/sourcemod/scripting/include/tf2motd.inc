// Opens a specific URL to a client as MOTD
native int TF2Motd_OpenURL(int client, const char[] url, const char[] errormsg);

public SharedPlugin __pl_tf2motd = 
{
    name = "tf2motd",
    file = "tf2motd.smx",
#if defined REQUIRE_PLUGIN
    required = 1,
#else
    required = 0,
#endif
};