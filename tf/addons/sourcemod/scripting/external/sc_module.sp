/*
 * Server Crontab Main Module - www.sourcemod.net
 *
 * Plugin licensed under the GPLv3
 *
 * Coded by dubbeh - www.dubbeh.net
 *
 */


#include <sourcemod>
#include <scrontab>

#pragma semicolon 1
#pragma newdecls required

#define JOB_MINUTE				0
#define JOB_HOUR				1
#define JOB_DAY_OF_THE_MONTH	2
#define JOB_MONTH				3
#define JOB_DAY_OF_THE_WEEK		4
#define JOB_TIME_SIZE			5

Handle g_cVarEnableLogging = null;
Handle g_cVarAdjustTimezone = null;
Handle g_hJobsTimeArray = null;
Handle g_hJobsTaskArray = null;
Handle g_hJobsTimer = null;
Handle g_hCronCallForward = null;

char g_szConfigFile[PLATFORM_MAX_PATH] = "sourcemod/sc_module.cfg";

public Plugin ServerCrontabModule = 
{
	name = "Server Crontab Module", 
	author = "dubbeh", 
	description = "Run specific server jobs at certain times in SourceMod", 
	version = SCRONTAB_VERSION, 
	url = "http://dubbeh.net/"
};


public void OnPluginStart()
{
	CreateConVar("sc_module_version", SCRONTAB_VERSION, "Server Crontab Module version", FCVAR_SPONLY | FCVAR_REPLICATED | FCVAR_NOTIFY);
	g_cVarEnableLogging = CreateConVar("sc_module_jobslog", "1.0", "Enable the console output for ran jobs", 0, true, 0.0, true, 1.0);
	g_cVarAdjustTimezone = CreateConVar("sc_module_hour_adjust", "0.0", "Adjust the hour value positively or negatively by this amount - Min -23 - Max +23", 0, true, -23.0, true, 23.0);
	
	if (((g_hJobsTaskArray = CreateArray(MAX_JOB_LEN, 0)) != null) && 
		((g_hJobsTimeArray = CreateArray(JOB_TIME_SIZE, 0)) != null) &&
		(g_cVarEnableLogging != null) && 
		(g_cVarAdjustTimezone != null))
	{
		g_hCronCallForward = CreateGlobalForward("OnCronCall", ET_Event, Param_Cell, Param_String);
		g_hJobsTimer = CreateTimer(60.0, CrontabTimer, _, TIMER_REPEAT);
	}
	else
	{
		SetFailState("SC Module Error - Unable to create the arrays or cVars");
	}
	
	/* Create the delayed config execute timer */
	CreateTimer(10.0, OnPluginStart_Delayed);
}

public Action OnPluginStart_Delayed(Handle timer)
{
	/* Run delayed startup timer. Thanks to FlyingMongoose/sslice for the idea :) */
	/* We want to execute the jobs config file here */
	ServerCommand("exec %s", g_szConfigFile);
	return Plugin_Stop;
}

public void OnPluginEnd()
{
	if (g_hJobsTimer != null)
	{
		KillTimer(g_hJobsTimer);
		g_hJobsTimer = null;
	}
	if (g_hJobsTimeArray != null)
	{
		ClearArray(g_hJobsTimeArray);
		CloseHandle(g_hJobsTimeArray);
		g_hJobsTimeArray = null;
	}
	if (g_hJobsTaskArray != null)
	{
		ClearArray(g_hJobsTaskArray);
		CloseHandle(g_hJobsTaskArray);
		g_hJobsTaskArray = null;
	}
	if (g_hCronCallForward != null)
	{
		CloseHandle(g_hCronCallForward);
		g_hCronCallForward = null;
	}
}

public APLRes AskPluginLoad2(Handle myself, bool late, char []error, int err_max)
{
	CreateNative("SC_AddCronJob", Native_AddCronJob);
	CreateNative("SC_RemoveCronJob", Native_RemoveCronJob);
	CreateNative("SC_SearchCronJobId", Native_SearchCronJobId);
	CreateNative("SC_GetNumberOfCronJobs", Native_GetNumberOfCronJobs);
	CreateNative("SC_GetCronJobFromId", Native_GetCronJobFromId);
	CreateNative("SC_RemoveAllCronJobs", Native_RemoveAllCronJobs);
	CreateNative("SC_DoesCronJobExist", Native_DoesCronJobExist);
	return APLRes_Success;
}

public int Native_AddCronJob(Handle hPlugin, int iNumParams)
{
	static char szJobTask[MAX_JOB_LEN] = "";
	static int iLen = 0, iJobTime[JOB_TIME_SIZE];
	
	iJobTime[JOB_MINUTE] = GetNativeCell(1);
	if (!SC_IsMinuteValid(iJobTime[JOB_MINUTE]))
		return ThrowNativeError(SP_ERROR_NATIVE, "Minute value is out of range - Maximum value is 59");
	
	iJobTime[JOB_HOUR] = GetNativeCell(2);
	if (!SC_IsHourValid(iJobTime[JOB_HOUR]))
		return ThrowNativeError(SP_ERROR_NATIVE, "Hour value is out of range - Maximum value is 23");
	
	iJobTime[JOB_DAY_OF_THE_MONTH] = GetNativeCell(3);
	if (!SC_IsDayOfTheMonthValid(iJobTime[JOB_DAY_OF_THE_MONTH]))
		return ThrowNativeError(SP_ERROR_NATIVE, "Day of the month value is out of range - Minumum 1 - Maximum 31");
	
	iJobTime[JOB_MONTH] = GetNativeCell(4);
	if (!SC_IsMonthValid(iJobTime[JOB_MONTH]))
		return ThrowNativeError(SP_ERROR_NATIVE, "Month value is out of range - Minumum 1 - Maximum 12");
	
	iJobTime[JOB_DAY_OF_THE_WEEK] = GetNativeCell(5);
	if (!SC_IsDayOfTheWeekValid(iJobTime[JOB_DAY_OF_THE_WEEK]))
		return ThrowNativeError(SP_ERROR_NATIVE, "Day of the week value is out of range - Min 0 (Sunday) - Max 6 (Sat)");
	
	GetNativeStringLength(6, iLen);
	GetNativeString(6, szJobTask, iLen + 1);
	if (szJobTask[0] == '\0')
		return ThrowNativeError(SP_ERROR_NATIVE, "No cronjob specified");
	
	PushArrayArray(g_hJobsTimeArray, iJobTime);
	return PushArrayString(g_hJobsTaskArray, szJobTask);
}

public int Native_SearchCronJobId(Handle hPlugin, int iNumParams)
{
	static int iSearchJobTime[JOB_TIME_SIZE], iLen, iArraySize, iArrayIndex, iJobTime[JOB_TIME_SIZE];
	static char szSearchJob[MAX_JOB_LEN] = "", szCronJob[MAX_JOB_LEN] = "";
	
	iSearchJobTime[JOB_MINUTE] = GetNativeCell(1);
	if (!SC_IsMinuteValid(iSearchJobTime[JOB_MINUTE]))
		return -1;
	
	iSearchJobTime[JOB_HOUR] = GetNativeCell(2);
	if (!SC_IsHourValid(iSearchJobTime[JOB_HOUR]))
		return -1;
	
	iSearchJobTime[JOB_DAY_OF_THE_MONTH] = GetNativeCell(3);
	if (!SC_IsDayOfTheMonthValid(iSearchJobTime[JOB_DAY_OF_THE_MONTH]))
		return -1;
	
	iSearchJobTime[JOB_MONTH] = GetNativeCell(4);
	if (!SC_IsMinuteValid(iSearchJobTime[JOB_MONTH]))
		return -1;
	
	iSearchJobTime[JOB_DAY_OF_THE_WEEK] = GetNativeCell(5);
	if (!SC_IsDayOfTheWeekValid(iSearchJobTime[JOB_DAY_OF_THE_WEEK]))
		return -1;
	
	GetNativeStringLength(6, iLen);
	GetNativeString(6, szSearchJob, iLen + 1);
	
	iArraySize = GetArraySize(g_hJobsTimeArray);
	
	if (iArraySize > 0)
	{
		iArrayIndex = 0;
		while (iArrayIndex < iArraySize)
		{
			GetArrayArray(g_hJobsTimeArray, iArrayIndex, iJobTime);
			
			if ((iSearchJobTime[JOB_MINUTE] == iJobTime[JOB_MINUTE]) && 
				(iSearchJobTime[JOB_HOUR] == iJobTime[JOB_HOUR]) &&
				(iSearchJobTime[JOB_DAY_OF_THE_MONTH] == iJobTime[JOB_DAY_OF_THE_MONTH]) &&
				(iSearchJobTime[JOB_MONTH] == iJobTime[JOB_MONTH]) &&
				(iSearchJobTime[JOB_DAY_OF_THE_WEEK] == iJobTime[JOB_DAY_OF_THE_WEEK]))
			{
				GetArrayString(g_hJobsTaskArray, iArrayIndex, szCronJob, sizeof(szCronJob));
				if (!strcmp(szSearchJob, szCronJob, false))
					return iArrayIndex;
			}
			
			iArrayIndex++;
		}
	}
	
	return -1;
}

public int Native_RemoveCronJob(Handle hPlugin, int iNumParams)
{
	static int iJobIndex = 0;
	
	iJobIndex = GetNativeCell(1);
	if (iJobIndex < GetArraySize(g_hJobsTimeArray))
	{
		RemoveFromArray(g_hJobsTimeArray, iJobIndex);
		RemoveFromArray(g_hJobsTaskArray, iJobIndex);
		return true;
	}
	
	return false;
}

public int Native_GetNumberOfCronJobs(Handle hPlugin, int iNumParams)
{
	return GetArraySize(g_hJobsTimeArray) - 1;
}

public int Native_GetCronJobFromId(Handle hPlugin, int iNumParams)
{
	static int iCronJobId, iArraySize, iJobTime[JOB_TIME_SIZE];
	static char szCronJob[MAX_JOB_LEN] = "";
	
	iArraySize = GetArraySize(g_hJobsTimeArray);
	iCronJobId = GetNativeCell(1);
	
	if ((iArraySize == 0) || (iCronJobId > iArraySize))
		return false;
	
	GetArrayArray(g_hJobsTimeArray, iCronJobId, iJobTime);
	GetArrayString(g_hJobsTaskArray, iCronJobId, szCronJob, sizeof(szCronJob));
	SetNativeCellRef(2, iJobTime[JOB_MINUTE]);
	SetNativeCellRef(3, iJobTime[JOB_HOUR]);
	SetNativeCellRef(4, iJobTime[JOB_DAY_OF_THE_MONTH]);
	SetNativeCellRef(5, iJobTime[JOB_MONTH]);
	SetNativeCellRef(6, iJobTime[JOB_DAY_OF_THE_WEEK]);
	SetNativeString(7, szCronJob, sizeof(szCronJob));
	return true;
}

public int Native_RemoveAllCronJobs(Handle hPlugin, int iNumParams)
{
	if (g_hJobsTimeArray != INVALID_HANDLE)
	{
		ClearArray(g_hJobsTimeArray);
	}
	if (g_hJobsTaskArray != INVALID_HANDLE)
	{
		ClearArray(g_hJobsTaskArray);
	}
}

// This is basically the same as search cron job without the extra checks, so It's slightly faster
public int Native_DoesCronJobExist(Handle hPlugin, int iNumParams)
{
	static int iSearchJobTime[JOB_TIME_SIZE], iLen, iArraySize, iArrayIndex, iJobTime[JOB_TIME_SIZE];
	static char szSearchJob[MAX_JOB_LEN] = "", szCronJob[MAX_JOB_LEN] = "";
	
	if (iNumParams == 6)
	{
		iSearchJobTime[JOB_MINUTE] = GetNativeCell(1);
		iSearchJobTime[JOB_HOUR] = GetNativeCell(2);
		iSearchJobTime[JOB_DAY_OF_THE_MONTH] = GetNativeCell(3);
		iSearchJobTime[JOB_MONTH] = GetNativeCell(4);
		iSearchJobTime[JOB_DAY_OF_THE_WEEK] = GetNativeCell(5);
		
		GetNativeStringLength(6, iLen);
		GetNativeString(6, szSearchJob, iLen + 1);
		
		iArraySize = GetArraySize(g_hJobsTimeArray);
		
		if (iArraySize > 0)
		{
			iArrayIndex = 0;
			while (iArrayIndex < iArraySize)
			{
				GetArrayArray(g_hJobsTimeArray, iArrayIndex, iJobTime);
				
				if ((iSearchJobTime[JOB_MINUTE] == iJobTime[JOB_MINUTE]) && 
					(iSearchJobTime[JOB_HOUR] == iJobTime[JOB_HOUR]) &&
					(iSearchJobTime[JOB_DAY_OF_THE_MONTH] == iJobTime[JOB_DAY_OF_THE_MONTH]) &&
					(iSearchJobTime[JOB_MONTH] == iJobTime[JOB_MONTH]) &&
					(iSearchJobTime[JOB_DAY_OF_THE_WEEK] == iJobTime[JOB_DAY_OF_THE_WEEK]))
				{
					GetArrayString(g_hJobsTaskArray, iArrayIndex, szCronJob, sizeof(szCronJob));
					if (!strcmp(szSearchJob, szCronJob, false))
						return iArrayIndex;
				}
				
				iArrayIndex++;
			}
		}
	}
	
	return -1;
}

public Action CrontabTimer(Handle timer)
{
	static int iArrayIndex, iArraySize, iJob[JOB_TIME_SIZE], iMinute, iHour, iDayOfTheWeek, iDayOfTheMonth, iMonth;
	static Action aResult = Plugin_Continue;
	static char szCronJob[MAX_JOB_LEN] = "";
	
	iArraySize = GetArraySize(g_hJobsTimeArray);
	
	if (iArraySize > 0)
	{
		iMinute = getMinute();
		iHour = getHour();
		iDayOfTheMonth = getDayOfTheMonth();
		iMonth = getMonth();
		iDayOfTheWeek = getDayOfTheWeek();
		
		// Adjust the hour value based on the sc_module_hour_adjust cVar
		AdjustHourValue(iHour);
		
		iArrayIndex = 0;
		while (iArrayIndex < iArraySize)
		{
			GetArrayArray(g_hJobsTimeArray, iArrayIndex, iJob);
			
			if (((iJob[JOB_MINUTE] == iMinute) || (iJob[JOB_MINUTE] == JOB_WILDCARD)) && 
			    ((iJob[JOB_HOUR] == iHour) || (iJob[JOB_HOUR] == JOB_WILDCARD)) && 
			    ((iJob[JOB_DAY_OF_THE_MONTH] == iDayOfTheMonth) || (iJob[JOB_DAY_OF_THE_MONTH] == JOB_WILDCARD)) && 
			    ((iJob[JOB_MONTH] == iMonth) || (iJob[JOB_MONTH] == JOB_WILDCARD)) && 
			    ((iJob[JOB_DAY_OF_THE_WEEK] == iDayOfTheWeek) || (iJob[JOB_DAY_OF_THE_WEEK] == JOB_WILDCARD)))
			{
				GetArrayString(g_hJobsTaskArray, iArrayIndex, szCronJob, sizeof(szCronJob));
						
				aResult = Plugin_Continue;
				Call_StartForward(g_hCronCallForward);
				Call_PushCell(iArrayIndex);
				Call_PushString(szCronJob);
				Call_Finish(aResult);

				if (aResult < Plugin_Handled)
				{
					if (GetConVarBool(g_cVarEnableLogging))
						LogMessage("Running cron job \"%s\"", szCronJob);
					ServerCommand(szCronJob);
				}
				else
				{
					if (GetConVarBool(g_cVarEnableLogging))
						LogMessage("Skipping cron job \"%s\"", szCronJob);
				}
			}
			
			iArrayIndex++;
		}
	}
	
	return Plugin_Continue;
}

stock int getMinute()
{
	static char szMinute[3] = "";
	
	FormatTime(szMinute, sizeof(szMinute), "%M");
	return StringToInt(szMinute);
}

stock int getHour()
{
	static char szHour[3] = "";
	
	FormatTime(szHour, sizeof(szHour), "%H");
	return StringToInt(szHour);
}

stock void AdjustHourValue (int iHour)
{
	iHour += GetConVarInt(g_cVarAdjustTimezone);
	
	/* Check if hour value is overflowing out of the 0-23 range */
	if (iHour > 23)
	    iHour -= 24;
	else if (iHour < 0)
	    iHour += 24;
}

stock int getDayOfTheWeek()
{
	static char szDayOfTheWeek[3] = "";
	
	FormatTime(szDayOfTheWeek, sizeof(szDayOfTheWeek), "%w");
	return StringToInt(szDayOfTheWeek);
}

stock int getMonth()
{
	static char szMonth[3] = "";
	
	FormatTime(szMonth, sizeof(szMonth), "%m");
	return StringToInt(szMonth);
}

stock int getDayOfTheMonth()
{
	static char szDayOfMonth[3] = "";
	
	FormatTime(szDayOfMonth, sizeof(szDayOfMonth), "%d");
	return StringToInt(szDayOfMonth);
}

