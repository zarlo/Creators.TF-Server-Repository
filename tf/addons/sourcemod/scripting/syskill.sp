#include <sourcemod>
#include <system2>

public void OnPluginStart()
{
    RegServerCmd("sm_syskill", syskill, "kill server's process id with system2_execute");
}

Action syskill(int args)
{
    char dummy[256];
    // $PPID = Parent Process ID
    // Works on my machine, not tested with anything other than bash/zsh/fsh etc
    System2_Execute(dummy, sizeof(dummy), "kill $PPID");
}
