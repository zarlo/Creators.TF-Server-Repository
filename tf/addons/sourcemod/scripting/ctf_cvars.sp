public void OnPluginStart()
{
    CreateConVar("ce_environment",  " " , "Creators.TF Environment");
    CreateConVar("ce_region",       " " , "Creators.TF Server Region");
    CreateConVar("ce_server_index", "-1", "Creators.TF Server Index");
    CreateConVar("ce_type",         " " , "Creators.TF Server Type");

    LogMessage("\n\n[CTF CVARS] -> CREATED CTF CONVARS\n");
}
