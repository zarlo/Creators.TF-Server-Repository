#include <sdktools>

#pragma newdecls required

enum
{
    SENTRY_STATE_INACTIVE = 0,
    SENTRY_STATE_SEARCHING,
    SENTRY_STATE_ATTACKING,
    SENTRY_STATE_UPGRADING,

    SENTRY_NUM_STATES,
};

public Plugin myinfo =
{
    name = "[TF2] Smooth Sentry Construct & Upgrade Animations",
    author = "Pelipoika",
    description = "",
    version = "1.0",
    url = "http://www.sourcemod.net/plugins.php?author=Pelipoika&search=1"
};

ArrayList g_SentryList;

public void OnPluginStart()
{
    g_SentryList = new ArrayList();
}

public void OnMapStart()
{
    g_SentryList.Clear();
}

public void OnEntityCreated(int entity, const char[] classname)
{
    if (StrEqual(classname, "obj_sentrygun"))
    {
        RequestFrame(HookSentry, EntIndexToEntRef(entity));
    }
}

void HookSentry(int entityref)
{
    int entity = EntRefToEntIndex(entityref);
    if (IsValidEntity(entity))
    {
        g_SentryList.Push(entity);
    }
}

public void OnEntityDestroyed(int entity)
{
    if (IsValidEntity(entity))
    {
        char classname[16];
        GetEntityClassname(entity, classname, sizeof(classname));
        if (StrEqual(classname, "obj_sentrygun"))
        {
            int index = g_SentryList.FindValue(entity);
            // avoid exceptions
            if (index != -1)
            {
                g_SentryList.Erase(index);
            }
        }
    }
}

public void OnGameFrame()
{
    for (int i = 0; i < g_SentryList.Length; i++)
    {

        int iBuilding = g_SentryList.Get(i);

        if (!IsValidEntity(iBuilding)) {
            g_SentryList.Erase(i);
            i--;
            continue;
        }

        char classname[16];
        GetEntityClassname(iBuilding, classname, sizeof(classname));
        if (!StrEqual(classname, "obj_sentrygun"))
        {
            g_SentryList.Erase(i);
            i--;
            continue;
        }

        bool bClientSideAnim = !!GetEntProp(iBuilding, Prop_Send, "m_bClientSideAnimation");
        int iState = GetEntProp(iBuilding, Prop_Send, "m_iState");

    //  PrintToServer("bClientSideAnim %i iState %i", bClientSideAnim, iState);

        if (bClientSideAnim)
        {
            if (iState != SENTRY_STATE_UPGRADING && iState != SENTRY_STATE_INACTIVE)
            {
                SetEntProp(iBuilding, Prop_Send, "m_bClientSideAnimation", false);
            }
        }
        else
        {
            if (iState == SENTRY_STATE_UPGRADING || iState == SENTRY_STATE_INACTIVE)
            {
                SetEntProp(iBuilding, Prop_Send, "m_bClientSideAnimation", true);
            }
        }

        //if
        //(
        //    (
        //        iState == SENTRY_STATE_UPGRADING
        //        ||
        //        iState == SENTRY_STATE_INACTIVE
        //    )
        //    && !bClientSideAnim
        //)
        //{
        //    SetEntProp(iBuilding, Prop_Send, "m_bClientSideAnimation", true);
        //}
        //else if
        //(
        //       iState != SENTRY_STATE_UPGRADING
        //    && iState != SENTRY_STATE_INACTIVE
        //    && bClientSideAnim
        //)
        //{
        //    SetEntProp(iBuilding, Prop_Send, "m_bClientSideAnimation", false);
        //}
    }
}
