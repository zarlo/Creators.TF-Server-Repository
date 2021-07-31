/*
 * Server Crontab - www.sourcemod.net
 *
 * Plugin licensed under the GPLv3
 *
 * Coded by dubbeh - www.dubbeh.net
 *
 */

#pragma semicolon 1
#pragma newdecls required

#define REQUIRE_PLUGIN
#include <sourcemod>
#undef REQUIRE_PLUGIN
#include <scrontab>


public Plugin ServerCrontab = 
{
	name = "Server Crontab", 
	author = "dubbeh", 
	description = "Run specific server tasks at certain times", 
	version = SCRONTAB_VERSION, 
	url = "http://dubbeh.net/"
};

char g_szConfigFile[PLATFORM_MAX_PATH] = "sourcemod/sc_jobs.cfg";


public void OnPluginStart()
{
	/* Create the version console variable */
	CreateConVar("sc_version", SCRONTAB_VERSION, "Server Crontab version", FCVAR_SPONLY | FCVAR_REPLICATED | FCVAR_NOTIFY);
	
	/* Register all the admin commands */
	RegAdminCmd("sc_addjob", Command_AddCronJob, ADMFLAG_ROOT, "sc_addjob minute hour day_of_the_month month day_of_the_week \"cronjob\" - Adds a new cronjob");
	RegAdminCmd("sc_removejob", Command_RemoveCronJob, ADMFLAG_ROOT, "sc_removejob cronjob_id - Removes a job using cronjob_id");
	RegAdminCmd("sc_removealljobs", Command_RemoveAllCronJobs, ADMFLAG_ROOT, "sc_removealljobs - Removes all crontab jobs");
	RegAdminCmd("sc_printjobs", Command_PrintCronJobs, ADMFLAG_ROOT, "sc_printjobs - Prints out all the current cron jobs in the console");
	
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

public Action Command_AddCronJob(int client, int args)
{
	static char szTempBuffer[MAX_JOB_LEN] = "";
	static int iMinute = 0, iHour = 0, iDayOfTheMonth = 0, iMonth = 0, iDayOfTheWeek = 0;
	
	/* Staged the checks to avoid using GetCmdArg multiple times at the start
	   Using nested Ifs to reduce CPU cycles and reply for invalid input feedback */
	if (args == 6)
	{
		GetCmdArg(1, szTempBuffer, sizeof(szTempBuffer));
		iMinute = CronStringToInt(szTempBuffer);
		if (SC_IsMinuteValid(iMinute))
		{
			GetCmdArg(2, szTempBuffer, sizeof(szTempBuffer));
			iHour = CronStringToInt(szTempBuffer);
			if (SC_IsHourValid(iHour))
			{
				GetCmdArg(3, szTempBuffer, sizeof(szTempBuffer));
				iDayOfTheMonth = CronStringToInt(szTempBuffer);
				if (SC_IsDayOfTheMonthValid(iDayOfTheMonth))
				{
					GetCmdArg(4, szTempBuffer, sizeof(szTempBuffer));
					iMonth = CronStringToInt(szTempBuffer);
					if (SC_IsMonthValid(iMonth))
					{
						GetCmdArg(5, szTempBuffer, sizeof(szTempBuffer));
						iDayOfTheWeek = CronStringToInt(szTempBuffer);
						if (SC_IsDayOfTheWeekValid(iDayOfTheWeek))
						{
							GetCmdArg(6, szTempBuffer, sizeof(szTempBuffer));
							
							if ((SC_DoesCronJobExist(iMinute, iHour, iDayOfTheMonth, iMonth, iDayOfTheWeek, szTempBuffer)) != -1)
								ReplyToCommand(client, "[SC] Cron job \"%s\" already exists in the jobs array", szTempBuffer);
							else if ((SC_AddCronJob(iMinute, iHour, iDayOfTheMonth, iMonth, iDayOfTheWeek, szTempBuffer)) != -1)
								ReplyToCommand(client, "[SC] Cron job \"%s\" added successfully", szTempBuffer);
							else
								ReplyToCommand(client, "[SC] Unknown error adding \"%s\" to the jobs array", szTempBuffer);
						}
						else
						{
							ReplyToCommand(client, "[SC] Add job error - Day of the week value is invalid - Minimum 0 (Sunday) - Maximum 6 (Saturday)");
						}
					}
					else
					{
						ReplyToCommand(client, "[SC] Add job error - Month value is invalid - Minumum 1 - Maximum 12");
					}
				}
				else
				{
					ReplyToCommand(client, "[SC] Add job error - Day of the Month value is invalid - Minumum 1 - Maximum 31");
				}
			}
			else
			{
				ReplyToCommand(client, "[SC] Add job error - Hour value is invalid - Maximum value is 23");
			}
		}
		else
		{
			ReplyToCommand(client, "[SC] Add job error - Minute value is invalid - Maximum value is 59");
		}
	}
	else
	{
		ReplyToCommand(client, "[SC] sc_addjob - Invalid usage");
		ReplyToCommand(client, "[SC] Usage: sc_addjob minute hour day_of_the_month month day_of_the_week \"cronjob\"");
	}
	
	return Plugin_Handled;
}

/* Removes a cronjob from the cronjobs array - If the ID is valid */
public Action Command_RemoveCronJob(int client, int args)
{
	char szTempBuffer[8] = "";
	static int iJobId = 0;
	
	if (args == 1)
	{
		GetCmdArg(1, szTempBuffer, sizeof(szTempBuffer));
		iJobId = StringToInt(szTempBuffer);
		if (iJobId <= SC_GetNumberOfCronJobs())
		{
			SC_RemoveCronJob(iJobId);
			ReplyToCommand(client, "[SC] Removed cron job %d successfully", iJobId);
		}
		else
		{
			ReplyToCommand(client, "[SC] Invalid Cronjob Id");
		}
	}
	else
	{
		ReplyToCommand(client, "[SC] sc_removejob - Invalid usage");
		ReplyToCommand(client, "[SC] Usage: sc_removejob CronjobID");
	}
	
	return Plugin_Handled;
}

/* Removes all cronjobs */
public Action Command_RemoveAllCronJobs(int client, int args)
{
	SC_RemoveAllCronJobs();
	ReplyToCommand(client, "[SC] All cron jobs removed");
	return Plugin_Handled;
}

/* prints all current cronjobs to the console */
public Action Command_PrintCronJobs(int client, int args)
{
	static int iNumOfJobs = 0, iJob = 0, iJobMinute = 0,
	    iJobHour = 0, iJobDayOfTheMonth = 0, iJobMonth = 0, iJobDayOfTheWeek = 0;
	
	static char szCronJob[MAX_JOB_LEN], szJobMinute[4], szJobHour[4],
	    szJobDayOfTheMonth[4], szJobMonth[4], szJobDayOfTheWeek[4];
	
	ReplyToCommand(client, "Id\tMinute\tHour\tDayOfTheMonth\tMonth\tDayOfTheWeek\tJob");
	iNumOfJobs = SC_GetNumberOfCronJobs();
	for (iJob = 0; iJob <= iNumOfJobs; iJob++)
	{
		SC_GetCronJobFromId(iJob, iJobMinute, iJobHour, iJobDayOfTheMonth, iJobMonth, iJobDayOfTheWeek, szCronJob);
		CronIntToString(iJobMinute, szJobMinute, sizeof(szJobMinute));
		CronIntToString(iJobHour, szJobHour, sizeof(szJobHour));
		CronIntToString(iJobDayOfTheMonth, szJobDayOfTheMonth, sizeof(szJobDayOfTheMonth));
		CronIntToString(iJobMonth, szJobMonth, sizeof(szJobMonth));
		CronIntToString(iJobDayOfTheWeek, szJobDayOfTheWeek, sizeof(szJobDayOfTheWeek));
		ReplyToCommand(client, "%d\t%s\t%s\t%s\t\t%s\t%s\t\t%s", iJob, szJobMinute, szJobHour, szJobDayOfTheMonth, szJobMonth, szJobDayOfTheWeek, szCronJob);
	}
	
	return Plugin_Handled;
}

int CronStringToInt(char []szStr)
{
	if (szStr[0] == JOB_WILDCARD)
		return JOB_WILDCARD;
	return StringToInt(szStr);
}

void CronIntToString(int iNum, char []szOutBuffer, int iOutBufferSize)
{
	if (iNum == JOB_WILDCARD)
	{
		szOutBuffer[0] = JOB_WILDCARD;
		szOutBuffer[1] = 0;
	}
	else
	{
		IntToString(iNum, szOutBuffer, iOutBufferSize);
	}
}

