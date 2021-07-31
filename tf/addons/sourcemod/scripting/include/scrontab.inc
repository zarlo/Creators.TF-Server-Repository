
#if defined _sc_module_included
 #endinput
#endif
#define _sc_module_included

public SharedPlugin __pl_sc_module =
{
    name = "sc_module",
    file = "sc_module.smx",
#if defined REQUIRE_PLUGIN
    required = 1,
#else
    required = 0,
#endif
};

// Server Crontab global version
#define SCRONTAB_VERSION "2.0.0.0"

// Maximum size a cron job can be
#define MAX_JOB_LEN		255

// Wildcard "*" to skip checking the minute, hour, day of the month, month and day of the week
#define JOB_WILDCARD	0x2a

/*
 * Add a new cron job
 *
 * @param 	iMinute = The minute the job runs (0-59)
 * @param 	iHour = The hour the job runs (0-59) 
 * @param 	iDayOfTheMonth = The day of the month the job runs (1-31)
 * @param 	iMonth = The month the job runs (1-12) 
 * @param 	iDayOfTheWeek = The day of the week the job runs ((0-Sunday)-(6-Saturday))
 * @param	szCronJob = The job to be run
 * @return	Cron job ID The Cron Job Identifier - Watch out because this can change over time. With adding and removing jobs.
 *
 */

native int SC_AddCronJob (int iMinute = -1, int iHour = -1, int iDayOfTheMonth = -1, int iMonth = -1, int iDayOfTheWeek = -1, const char []szCronJob = "");


/*
 * Find the index for a specific cron job
 *  
 * This is important when using arrays and removing jobs to grab the current index
 *
 * @param 	iMinute = The minute the job runs (0-59)
 * @param 	iHour = The hour the job runs (0-59) 
 * @param 	iDayOfTheMonth = The day of the month the job runs (1-31)
 * @param 	iMonth = The month the job runs (1-12) 
 * @param 	iDayOfTheWeek = The day of the week the job runs ((0-Sunday)-(6-Saturday))
 * @param	szCronJob = The job to be run
 * @return	The cron job Id
 *
 */

native int SC_SearchCronJobId (int iMinute = -1, int iHour = -1, int iDayOfTheMonth = -1, int iMonth = -1, int iDayOfTheWeek = -1, const char []szCronJob = "");


/*
 * Remove a cron job
 *
 * @param 	iCronId = The cron job ID to remove
 * @return	true - If the job was removed sucessfully
 *
 */

native bool SC_RemoveCronJob (int iCronId = -1);


/*
 * Called just before the cron job is run
 * 
 * Allows a cron job to be skipped
 *  
 * @param   iCronId = The cron job ID 
 * @param	szCronJob = The job to be run
 * @return	Plugin_Handled to skip the cron job or Plugin_Continue to run it
 */

forward Action SC_OnCronCall (int iCronId, const char []szCronJob);


/*
 * Get the current number of cron jobs
 *
 * @return The number of current cron jobs
 *
 */

native int SC_GetNumberOfCronJobs ();


/*
 * Get the cron job for the current ID
 *
 * @param 	iCronId = The cron job ID to retrieve
 * @param 	iMinute = The minute the job runs (0-59)
 * @param 	iHour = The hour the job runs (0-59) 
 * @param 	iDayOfTheMonth = The day of the month the job runs (1-31)
 * @param 	iMonth = The month the job runs (1-12) 
 * @param 	iDayOfTheWeek = The day of the week the job runs ((0-Sunday)-(6-Saturday))
 * @param 	szCronJob = Place to store the cron job task
 * @return 	true if the job id was found or false if the job id is out of range
 *
 */

native bool SC_GetCronJobFromId (int iCronId = -1, int &iMinute, int &iHour, int &iDayOfTheMonth, int &iMonth, int &iDayOfTheWeek, const char []szCronJob);


/*
 * Remove all the current cron jobs 
 */
native void SC_RemoveAllCronJobs ();


/*
 * Check if a cron job you're about to add, already exists in the jobs array - saves duplicate jobs getting added
 *
 * @param 	iMinute = The minute the job runs (0-59)
 * @param 	iHour = The hour the job runs (0-59) 
 * @param 	iDayOfTheMonth = The day of the month the job runs (1-31)
 * @param 	iMonth = The month the job runs (1-12) 
 * @param 	iDayOfTheWeek = The day of the week the job runs ((0-Sunday)-(6-Saturday))
 * @param	szCronJob = The job to be run
 * @return	Cron job ID (This will return -1 if no matching job was found, or the job ID if a duplicate was found)
 *
 */

native int SC_DoesCronJobExist (int iMinute = -1, int iHour = -1, int iDayOfTheMonth = -1, int iMonth = -1, int iDayOfTheWeek = -1, const char []szCronJob = "");

/*
 * Check the minute is in range
 */  
stock bool SC_IsMinuteValid (int iMinute)
{
    if ((iMinute > 59) && (iMinute != JOB_WILDCARD))
        return false;
    return true;
}

/*
 * Check the hour is in range
 */
stock bool SC_IsHourValid (int iHour)
{
    if ((iHour > 23)  && (iHour != JOB_WILDCARD))
        return false;
    return true;
}

/*
 * Check the day of the month is in range
 */
stock bool SC_IsDayOfTheMonthValid (int iDayOfTheMonth)
{
    if (((iDayOfTheMonth < 1) || (iDayOfTheMonth > 31 ))  && (iDayOfTheMonth != JOB_WILDCARD))
        return false;
    return true;
}

stock bool SC_IsMonthValid (int iMonth)
{
	if (((iMonth < 1) || (iMonth > 12)) && (iMonth != JOB_WILDCARD))
	    return false;
	return true;
}

/*
 * Check the weekday is in range
 */  
stock bool SC_IsDayOfTheWeekValid (int iWeekday)
{
    if ((iWeekday > 6) && (iWeekday != JOB_WILDCARD))
        return false;
    return true;
}



