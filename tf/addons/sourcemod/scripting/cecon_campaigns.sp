
//============= Copyright Amper Software, All rights reserved. ============//
//
// Purpose: Campaigns handler for Creators.TF Economy.
//
//=========================================================================//

#include <steamtools>

#pragma semicolon 1
#pragma tabsize 0
#pragma newdecls required

#include <cecon_http>
#include <cecon_campaign>
#include <cecon>

#define SECONDS_TO_DAYS 1.0 / 60 / 60 / 24

#define BACKEND_CAMPAIGN_UPDATE_INTERVAL 30.0 // Every 30 seconds.
#define BACKEND_CAMPAIGN_UPDATE_LIMIT 20 // Dont allow more than 20 campaign quests to be updated at the same time.

public Plugin myinfo =
{
	name = "Creators.TF Economy - Campaigns Handler",
	author = "Creators.TF Team",
	description = "Creators.TF Economy Campaigns Handler",
	version = "1.0",
	url = "https://creators.tf"
}

ConVar ce_campaign_force_activate;

ArrayList m_hCampaigns;

public void OnPluginStart()
{
	RegServerCmd("ce_campaign_dump", cDump, "");

	ce_campaign_force_activate = CreateConVar("ce_campaign_force_activate", "", "Force activates a campaign, ignores the time limit.", FCVAR_PROTECTED);
	HookConVarChange(ce_campaign_force_activate, ce_campaign_force_activate__CHANGED);

	// In a local build of the economy, the users will have their campaign
	// progress update, but it won't be written to the database via an
	// HTTP request to the website.
#if !defined LOCAL_BUILD
	CreateTimer(BACKEND_CAMPAIGN_UPDATE_INTERVAL, Timer_BackendUpdateInterval, _, TIMER_REPEAT);
#endif

	HookEvent("teamplay_round_win", teamplay_round_win);
}

public void OnAllPluginsLoaded()
{
	ParseCampaignList(CEcon_GetEconomySchema());
}

public void OnMapStart()
{
	ParseCampaignList(CEcon_GetEconomySchema());
}

public void CEcon_OnSchemaUpdated(KeyValues hSchema)
{
	ParseCampaignList(hSchema);
}

public void ce_campaign_force_activate__CHANGED(ConVar convar, const char[] oldValue, const char[] newValue)
{
	ParseCampaignList(CEcon_GetEconomySchema());
}

public void ParseCampaignList(KeyValues kv)
{
	delete m_hCampaigns;
	m_hCampaigns = new ArrayList(sizeof(CECampaign));

	if (kv == null)return;

	char sCvarValue[64];
	ce_campaign_force_activate.GetString(sCvarValue, sizeof(sCvarValue));

	if(kv.JumpToKey("Contracker/Campaigns", false))
	{
		if(kv.GotoFirstSubKey())
		{
			do {
				char sTime[128], sTitle[64];
				kv.GetString("title", sTitle, sizeof(sTitle));

				if(!StrEqual(sTitle, sCvarValue))
				{
					kv.GetString("start_time", sTime, sizeof(sTime));
					if(StrEqual(sTime, "")) continue;
					int iStartTime = TimeFromString("YYYY-MM-DD hh:mm:ss", sTime);

					kv.GetString("end_time", sTime, sizeof(sTime));
					if(StrEqual(sTime, "")) continue;
					int iEndTime = TimeFromString("YYYY-MM-DD hh:mm:ss", sTime);

					if (!(GetTime() > iStartTime && GetTime() < iEndTime))continue;

					LogMessage("Campaign \"%s\" will last for %d more days.", sTitle, RoundToFloor(float(iEndTime - GetTime()) * SECONDS_TO_DAYS));
				}

				// There is no point in storing a campaign in memory, if
				// we're not going to track it.
				char sEvent[128];
				kv.GetString("event", sEvent, sizeof(sEvent));
				if (StrEqual(sEvent, ""))continue;

				CECampaign xCampaign;
				strcopy(xCampaign.m_sTitle, sizeof(xCampaign.m_sTitle), sTitle);
				strcopy(xCampaign.m_sEvent, sizeof(xCampaign.m_sEvent), sEvent);
				kv.GetString("name", xCampaign.m_sName, sizeof(xCampaign.m_sName));

				m_hCampaigns.PushArray(xCampaign);
			} while (kv.GotoNextKey());
		}
	}

	kv.Rewind();
}

public void CEcon_OnClientEvent(int client, const char[] name, int add, int unique_id)
{
	for (int i = 0; i < m_hCampaigns.Length; i++)
	{
		CECampaign xCampaign;
		m_hCampaigns.GetArray(i, xCampaign);

		if (!StrEqual(xCampaign.m_sEvent, name))continue;

		AddUpdateBatch(client, xCampaign.m_sTitle, add);
	}
}

public Action cDump(int args)
{
	LogMessage("Dumping precached data");
	for (int i = 0; i < m_hCampaigns.Length; i++)
	{
		CECampaign xCampaign;
		m_hCampaigns.GetArray(i, xCampaign);

		LogMessage("CECampaign");
		LogMessage("{");
		LogMessage("  m_sName = \"%s\"", xCampaign.m_sName);
		LogMessage("  m_sTitle = \"%s\"", xCampaign.m_sTitle);
		LogMessage("  m_sEvent = \"%s\"", xCampaign.m_sEvent);
		LogMessage("}");

	}

	LogMessage("");
	LogMessage("CECampaign Count: %d", m_hCampaigns.Length);
}


// Logic is taken from CRTime::RTime32FromFmtString method.
public int TimeFromString(const char[] sFormat, const char[] sValue)
{
    enum tm:
    {
        m_iYear,
        m_iMon,
        m_iDay,
        m_iHour,
        m_iMin,
        m_iSec,
        m_iMAX,
    }

    int time[m_iMAX];

	int iFormatLen = strlen(sFormat);
	int iValueLen = strlen(sValue);
	if(iFormatLen != iValueLen || iFormatLen < 4)
	{
		LogError("Format size should be bigger than 4 symbols.");
		return -1;
	}

	int iPosYYYY = StrContains(sFormat, "YYYY");
	int iPosYY = StrContains(sFormat, "YY");
	int iPosMM = StrContains(sFormat, "MM");
	int iPosMnt = StrContains(sFormat, "Mnt");
	int iPosDD = StrContains(sFormat, "DD");
	int iPosThh = StrContains(sFormat, "hh");
	int iPosTmm = StrContains(sFormat, "mm");
	int iPosTss = StrContains(sFormat, "ss");

	if(iPosYYYY > -1)
	{
		char sYYYY[5];
		strcopy(sYYYY, sizeof(sYYYY), sValue[iPosYYYY]);
		time[m_iYear] = StringToInt(sYYYY) - 1900;

	} else if(iPosYY > -1)
	{

		char sYY[3];
		strcopy(sYY, sizeof(sYY), sValue[iPosYY]);
		time[m_iYear] = StringToInt(sYY) + 100;

	} else {

		return -1; // Must have a year.
	}

	time[m_iYear] -= 70; // Substracting this, so we have 1970 as the base year.

	if(iPosMM > -1)
	{
		char sMM[3];
		strcopy(sMM, sizeof(sMM), sValue[iPosMM]);
		time[m_iMon] = StringToInt(sMM) - 1;
	}

	if(iPosMnt > -1)
	{
		char sMonthNames[][] =  { "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec" };

		char sMnt[4];
		strcopy(sMnt, sizeof(sMnt), sValue[iPosMnt]);

		int i;
		for (i = 0; i < 12; i++)
		{
			if (StrEqual(sMonthNames[i], sMnt))break;
		}

		if(i < 12)
		{
			time[m_iMon] = i;
		}
	}

	if(iPosDD > -1)
	{
		char sDD[3];
		strcopy(sDD, sizeof(sDD), sValue[iPosDD]);
		time[m_iDay] = StringToInt(sDD);
	}

	if(iPosThh > -1)
	{
		char sHH[3];
		strcopy(sHH, sizeof(sHH), sValue[iPosThh]);
		time[m_iHour] = StringToInt(sHH);
	}

	if(iPosTmm > -1)
	{
		char sMM[3];
		strcopy(sMM, sizeof(sMM), sValue[iPosTmm]);
		time[m_iMin] = StringToInt(sMM);
	}

	if(iPosTss > -1)
	{
		char sSS[3];
		strcopy(sSS, sizeof(sSS), sValue[iPosTss]);
		time[m_iSec] = StringToInt(sSS);
	}

	int iTime = 0;
	iTime += YearToDays(time[m_iYear]) * 24 * 60 * 60;
	iTime += MonthToDays(time[m_iMon]) * 24 * 60 * 60;
	iTime += time[m_iDay] * 24 * 60 * 60;
	iTime += time[m_iHour] * 60 * 60;
	iTime += time[m_iMin] * 60;
	iTime += time[m_iSec];

	return iTime;
}

public int YearToDays(int year)
{
	int iDays = year * 365;
	iDays += RoundToFloor(float(year - 2) / 4.0) + 1; // Every 4 years we have 366 days.
	return iDays;
}

public int MonthToDays(int month)
{
	int iDays = 0;
	for (int i = 0; i < month; i++)
	{
		if (i == 1)iDays += 28; // February has 28 days.
		else if (i & 2 == 0)iDays += 31;
		else iDays += 30;
	}
	return iDays;
}

#if !defined LOCAL_BUILD
enum struct CECampaignUpdateBatch
{
	char m_sSteamID[64];
	char m_sCampaign[128];

	int m_iPoints;
}

bool m_bIsUpdatingBatch;
bool m_bWasUpdatedWhileUpdating;

ArrayList m_CampaignUpdateBatches;
#endif

public void AddUpdateBatch(int client, const char[] campaign, int points)
{
	// In a local build of the economy, the users will have their campaign
	// progress update, but it won't be written to the database via an
	// HTTP request to the website.
#if defined LOCAL_BUILD
	return;
#else
	if(m_CampaignUpdateBatches == null)
	{
		m_CampaignUpdateBatches = new ArrayList(sizeof(CECampaignUpdateBatch));
	}

	char sSteamID[64];
	GetClientAuthId(client, AuthId_SteamID64, sSteamID, sizeof(sSteamID));

	int iPrevPoints = 0;
	for (int i = 0; i < m_CampaignUpdateBatches.Length; i++)
	{
		CECampaignUpdateBatch xBatch;
		m_CampaignUpdateBatches.GetArray(i, xBatch);

		if (!StrEqual(xBatch.m_sSteamID, sSteamID))continue;
		if (!StrEqual(xBatch.m_sCampaign, campaign))continue;

		iPrevPoints += xBatch.m_iPoints;

		m_CampaignUpdateBatches.Erase(i);
		i--;
	}

	CECampaignUpdateBatch xBatch;
	xBatch.m_iPoints 	= iPrevPoints + points;
	strcopy(xBatch.m_sSteamID, sizeof(xBatch.m_sSteamID), sSteamID);
	strcopy(xBatch.m_sCampaign, sizeof(xBatch.m_sCampaign), campaign);
	m_CampaignUpdateBatches.PushArray(xBatch);
	
	if (m_bIsUpdatingBatch)m_bWasUpdatedWhileUpdating = true;
#endif
}

public Action Timer_BackendUpdateInterval(Handle timer, any data)
{
	// In a local build of the economy, the users will have their campaign
	// progress update, but it won't be written to the database via an
	// HTTP request to the website.
#if defined LOCAL_BUILD
	return;
#else
	if (m_CampaignUpdateBatches == null)return;
	if (m_CampaignUpdateBatches.Length == 0)return;

	HTTPRequestHandle hRequest = CEconHTTP_CreateBaseHTTPRequest("/api/IEconomySDK/UserCampaigns", HTTPMethod_POST);
	
	int iCount = 0;

	for (int i = 0; i < m_CampaignUpdateBatches.Length; i++)
	{
		if (iCount >= BACKEND_CAMPAIGN_UPDATE_LIMIT) break;
		
		CECampaignUpdateBatch xBatch;
		m_CampaignUpdateBatches.GetArray(i, xBatch);

		char sKey[128];
		Format(sKey, sizeof(sKey), "campaigns[%s][%s]", xBatch.m_sSteamID, xBatch.m_sCampaign);

		char sValue[11];
		IntToString(xBatch.m_iPoints, sValue, sizeof(sValue));

		Steam_SetHTTPRequestGetOrPostParameter(hRequest, sKey, sValue);
	}
	
	LogMessage("Sending a batch of %d quests. (%d left in the queue.)", iCount, m_CampaignUpdateBatches.Length);

	Steam_SendHTTPRequest(hRequest, BackendUpdate_Callback);
	m_bIsUpdatingBatch = true;
#endif
}

public void BackendUpdate_Callback(HTTPRequestHandle request, bool success, HTTPStatusCode code, any count)
{
	// In a local build of the economy, the users will have their campaign
	// progress update, but it won't be written to the database via an
	// HTTP request to the website.
#if defined LOCAL_BUILD
	return;
#else
	m_bIsUpdatingBatch = false;
	bool bUpdated = m_bWasUpdatedWhileUpdating;
	m_bWasUpdatedWhileUpdating = false;
	
	Steam_ReleaseHTTPRequest(request);
	int iCount = count;

	// If request was not succesful, return.
	if (!success || code != HTTPStatusCode_OK)
	{
		LogMessage("Sending batch request returned with %d error. Try to send the next time. (Buffer remaining: %d, Batches affected: %d)", code, m_CampaignUpdateBatches.Length, iCount);
		return;
	}

	if (m_CampaignUpdateBatches == null)return;

	// Cool, we've updated everything.
	
	// If nothing has changed while we're making the request, remove the N batches at the bottom of the list.
	if(!bUpdated)
	{
		// Remove the batch updates that we just 
		for (int i = 0; i < iCount; i++)
		{
			if (i >= m_CampaignUpdateBatches.Length)break;
			
			m_CampaignUpdateBatches.Erase(i);
			i--;
			iCount--;
		}
	} else {	
		LogMessage("Batch order has been updated while request was made. We are not sure if we can remove them now.");
	}
	
	LogMessage("Succesfully updated %d batches. %d left in the queue.", count, m_CampaignUpdateBatches.Length);
	
	// If it's empty - delete it.
	if(m_CampaignUpdateBatches.Length == 0)
	{
		delete m_CampaignUpdateBatches;
	}
#endif
}

public Action teamplay_round_win(Event event, const char[] name, bool dontBroadcast)
{
	// In a local build of the economy, the users will have their campaign
	// progress update, but it won't be written to the database via an
	// HTTP request to the website.
#if defined LOCAL_BUILD
	return;
#else
	// Update progress immediately when round ends.
	// Players usually will look up their progress after they've done playing the game.
	// And it'll be frustrating to see their progress not being updated immediately.
	CreateTimer(0.1, Timer_BackendUpdateInterval);
#endif
}
