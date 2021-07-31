/*
       This file is part of SourceIRC.

    SourceIRC is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    SourceIRC is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with SourceIRC.  If not, see <http://www.gnu.org/licenses/>.
*/

#define IRC_VERSION "0.3.19"

#define IRC_CMD_MAXLEN 64 // The maximum length of a command
#define IRC_NICK_MAXLEN 64 // The maximum length of a nickname
#define IRC_CHANNEL_MAXLEN 64 // The maximum length of a channel  name
#define IRC_MAXLEN 512 // The maximum length of a line from the server. IRC RFC says maximum line length is 512, there again it also says a nicknames max length is 9. This might not be right.

#define IRC_CMDFLAG_NOPREFIX 1<<0 // Allow command to be triggered even without a prefix. For example instead of typing "SourceIRC: command args" you could just type "command args"

public SharedPlugin __pl_sourceirc = {
	name = "sourceirc",
	file = "sourceirc.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
}

#if !defined REQUIRE_PLUGIN
public void __pl_sourceirc_SetNTVOptional() {
	MarkNativeAsOptional("IRC_RegCmd");
	MarkNativeAsOptional("IRC_RegAdminCmd");
	MarkNativeAsOptional("IRC_Send");
	MarkNativeAsOptional("IRC_ReplyToCommand");
	MarkNativeAsOptional("IRC_GetCmdArgString");
	MarkNativeAsOptional("IRC_GetCmdArg");
	MarkNativeAsOptional("IRC_GetEventArg");
	MarkNativeAsOptional("IRC_CleanUp");
	MarkNativeAsOptional("IRC_GetHostMask");
	MarkNativeAsOptional("IRC_HookEvent");
	MarkNativeAsOptional("IRC_GetNick");
	MarkNativeAsOptional("IRC_ChannelHasFlag");
	MarkNativeAsOptional("IRC_GetUserFlagBits");
	MarkNativeAsOptional("IRC_GetAdminFlag");
	MarkNativeAsOptional("IRC_GetTeamColor");
	MarkNativeAsOptional("IRC_MsgFlaggedChannels");
}
#endif

/**
 * Called when an IRC command is invoked.
 *
 * @param nick			The nickname of the user who invoked hte command
 * @param args			Number of arguments that were in the argument string.
 * @return				An Action value.  Not handling the command
 *						means that SourceIRC will report it as "Unknown Command."
 */

typedef IRCCmd = function Action(const char[] nick, int args);

/**
 * Called when an IRC event is fired.
 *
 * @param prefix		This is the hostmask for IRC events that are triggered by a user, otherwise blank.
 * @param args			Number of arguments that are in the argument string.
 * @return				Only Plugin_Stop has any effect here, as this is a post hook.
 */

typedef IRCEvent = function Action(const char[] prefix, int args);

/**
 * Registers a command people can use in IRC
 *
 * @param cmd			String containing command to register
 * @param callback		A Function to use as a callback for when the command is invoked
 * @param description	Optional description to use for help.
 * @param flags			Optional command flags.
 * @noreturn
 */

native void IRC_RegCmd(const char[] cmd, IRCCmd callback, const char[] description="", int flags=0);

/**
 * Creates an IRC command as an administrative command.
 * When this command is invoked, the access rights of the user are 
 * automatically checked before allowing it to continue.
 *
 * @param cmd			String containing command to register.
 * @param callback		A function to use as a callback for when the command is invoked.
 * @param adminflags	Administrative flags (bitstring) to use for permissions.
 * @param description	Optional description to use for help.
 * @param flags			Optional command flags.
 * @noreturn
 */

native void IRC_RegAdminCmd(const char[] cmd0, IRCCmd callback, int adminflags, const char[] description="", int flags=0);

/**
 * Sends a packet to the IRC Server. \r\n is automatically appended for you.
 * 
 * @param format		Formatting rules.
 * @param ...			Variable number of format parameters.
 * @noreturn
 * @error				String contains \r or \n.
 */

native void IRC_Send(const char[] format, any ...);

/**
 * Replys to a message (Using a notice)
 * 
 * @param nick			Nickname of the user to message
 * @param format		Formatting rules.
 * @param ...			Variable number of format parameters.
 * @noreturn
 */

native void IRC_ReplyToCommand(const char[] nick, const char[] format, any ...);

/**
 * Retrieves the entire command argument string in one lump from the current 
 * IRC command.
 *
 * @param buffer		Buffer to use for storing the string.
 * @param maxlength		Maximum length of the buffer.
 * @return				Length of string written to buffer.
 */

native int IRC_GetCmdArgString(char[] buffer, int maxlength);

/**
 * Retrieves a command argument given its index, from the current IRC command.
 * @note Argument indexes start at 1; 0 retrieves the command name.
 *
 * @param argnum		Argument number to retrieve.
 * @param buffer		Buffer to use for storing the string.
 * @param maxlength		Maximum length of the buffer.
 * @return				Length of string written to buffer.
 */

native int IRC_GetCmdArg(int argnum, char[] buffer, int maxlength);


/**
 * Gets an event argument, note that this is different to SourceMods GetEvent*
 * function, and works more like GetCmdArg.
 *
 * @param argnum		Argument number to retrieve.
 * @param buffer			Buffer to use for storing the string.
 * @param maxlength		Maximum length of the buffer.
 * @return				Length of string written to buffer.
 */

native int IRC_GetEventArg(int argnum, char[] buffer, int maxlength);

/**
 * Sends a message to all channels with the given flag.
 *
 * @param flag			The flag channels must have to recieve this message.
 * @param format		Formatting rules.
 * @param ...			Variable number of format parameters.
 * @noreturn
 */

native void IRC_MsgFlaggedChannels(const char[] flag, const char[] format, any ...);

/**
 * If your plugin calls any of the IRC_Reg* functions
 * you must call this function upon unload otherwise you will cause errors
 * in the core.
 *
 * @noreturn
 */

native void IRC_CleanUp();

/**
 * Gets the hostmask (eg Nick!ident@address.com) for the user executing
 * a command, only valid inside a IRCCmd callback.
 * 
 * @param hostmask		String to store the hostmask in
 * @param maxlength		Maximum length of the buffer.
 * @noreturn
 */

native void IRC_GetHostMask(char[] hostmask, int maxlength);

/**
 * Creates a hook for when an IRC event is fired.
 *
 * @param name			Name of event.
 * @param callback		An IRCEvent function pointer.
 * @noreturn
 */

native void IRC_HookEvent(const char[] event, IRCEvent callback);

/**
 * Gets the bots current nickname
 * 
 * @param mynick		String to store the bots name in.
 * @param maxlength		Maximum length of the buffer.
 * @noreturn
 */

native void IRC_GetNick(char[] mynick, int maxlength);

/**
 * Checks if a channel has a flag.
 * 
 * @param channel		Channel to check.
 * @param flag			Flag to check.
 * @return				True if channel has flag, otherwise false.
 */

native int IRC_ChannelHasFlag(const char[] channel, const char[] flag);

/**
 * Returns users access flags. If the client is not an admin,
 * the result is always 0.
 * 
 * @param hostmask		hostmask of the user to check.
 * @return				Flags
 */

native int IRC_GetUserFlagBits(const char[] hostmask);

/**
 * Returns whether or not a flag is enabled on an admin.
 *
 * @param hostmask		hostmask of the user to check.
 * @param flag			Admin flag to use.
 * @return				True if enabled, false otherwise.
 */

native bool IRC_GetAdminFlag(const char[] hostmask, AdminFlag flag);

/**
 * Gets the IRC color number for a team as specified in sourceirc.cfg
 *
 * @param team			Team index
 * @return				Color code if available, otherwise -1.
 */

native int IRC_GetTeamColor(int team);

/**
 * Gets the servers domain/external IP as set in sourceirc.cfg
 * 
 * @param domain		String to store domain in
 * @param maxlength		Maximum length of the buffer.
 * @noreturn
 */

native void IRC_GetServerDomain(char[] domain, int maxlength);

forward void IRC_Connected();

forward void IRC_RetrieveUserFlagBits(const char[] hostmask, int &flagbits);

/**
 * Performs a standard IRC Like wildcard match, useful for hostmasks.
 *
 * @param str			String to check
 * @param wildcard		Wildcard to check against string
 * @return				true if match, false otherwise.
 */

stock bool IsWildCardMatch(const char[] str, const char[] wildcard) {
	int wildpos = 0;
	for (int a = 0; a <= strlen(str); a++) { 		
		if (wildcard[wildpos] == '*') {
			if (wildpos == strlen(wildcard)) {
				return true;
			}
			if (CharToLower(str[a]) == CharToLower(wildcard[wildpos+1])) {
				wildpos += 2;
			}
		}
		else if (wildcard[wildpos] == '?') {
			wildpos++;
		}
		else if (CharToLower(str[a]) == CharToLower(wildcard[wildpos])) {
			wildpos++;
		}
		else {
			return false;
		}
	}
	return (wildpos != strlen(wildcard));
}

/**
 * Breaks a string into pieces and stores each piece into an adt_array of buffers.
 *
 * @param text				The string to split.
 * @param split				The string to use as a split delimiter.
 * @param adt_array			An adt_array of string buffers.
 * @param maxlength			Maximum length of each string buffer.
 * @return					Number of strings retrieved.
 */

stock int ExplodeString_Array(const char[] source, const char[] split, ArrayList adt_array, int maxlength) {
	adt_array.Clear();
	char[] arg = new char[maxlength];
	int strpos = 0;
	for (int i = 0; i <= strlen(source); i++) {
		if (!strncmp(source[i], split, strlen(split))) {
			arg[strpos] = '\x00';
			adt_array.PushString(arg);

			strpos = 0;
			i += strlen(split);
		}
		if (strpos < maxlength) {
			arg[strpos] = source[i];
		}
		strpos++;
	}
	arg[strpos] = '\x00';
	adt_array.PushString(arg);
	return adt_array.Length;
}

/**
 * Wraps ProcessTargetString() and handles producing error messages for
 * bad targets.
 *
 * @param client	Client who issued command
 * @param target	Client's target argument
 * @param nobots	Optional. Set to true if bots should NOT be targetted
 * @param immunity	Optional. Set to false to ignore target immunity.
 * @return			Index of target client, or -1 on error.
 */
stock int IRC_FindTarget(const char[] nick, const char[] target, bool nobots = false, bool immunity = true) {
	char target_name[MAX_TARGET_LENGTH];
	int target_list[1]
		, target_count
		, flags = COMMAND_FILTER_NO_MULTI;
	bool tn_is_ml;

	if (nobots) {
		flags |= COMMAND_FILTER_NO_BOTS;
	}
	if (!immunity) {
		flags |= COMMAND_FILTER_NO_IMMUNITY;
	}
	
	if ((target_count = ProcessTargetString(
			target,
			0, 
			target_list, 
			1, 
			flags,
			target_name,
			sizeof(target_name),
			tn_is_ml)) > 0) {
		return target_list[0];
	}
	else {
		IRC_ReplyToTargetError(nick, target_count);
		return -1;
	}
}

/**
 * Replies to a client with a given message describing a targetting 
 * failure reason.
 *
 * Note: The translation phrases are found in common.phrases.txt.
 *
 * @param client		Client index, or 0 for server.
 * @param reason		COMMAND_TARGET reason.
 * @noreturn
 */
stock void IRC_ReplyToTargetError(const char[] nick, int reason) {
	switch (reason) {
		case COMMAND_TARGET_NONE: {
			IRC_ReplyToCommand(nick, "[SM] %t", "No matching client");
		}
		case COMMAND_TARGET_NOT_ALIVE: {
			IRC_ReplyToCommand(nick, "[SM] %t", "Target must be alive");
		}
		case COMMAND_TARGET_NOT_DEAD: {
			IRC_ReplyToCommand(nick, "[SM] %t", "Target must be dead");
		}
		case COMMAND_TARGET_NOT_IN_GAME: {
			IRC_ReplyToCommand(nick, "[SM] %t", "Target is not in game");
		}
		case COMMAND_TARGET_IMMUNE: {
			IRC_ReplyToCommand(nick, "[SM] %t", "Unable to target");
		}
		case COMMAND_TARGET_EMPTY_FILTER: {
			IRC_ReplyToCommand(nick, "[SM] %t", "No matching clients");
		}
		case COMMAND_TARGET_NOT_HUMAN: {
			IRC_ReplyToCommand(nick, "[SM] %t", "Cannot target bot");
		}
		case COMMAND_TARGET_AMBIGUOUS: {
			IRC_ReplyToCommand(nick, "[SM] %t", "More than one client matched");
		}
	}
}

/**
 * Extracts a nickname from a hostmask.
 *
 * @param hostmask			Hostmask to get the nickname from.
 * @param nick				String to store the nickname in.
 * @param maxlength			Maximum length of the nickname.
 * @noreturn
 */

stock void IRC_GetNickFromHostMask(const char[] hostmask, char[] nick, int maxlength) {
	for (int i = 0; i <= maxlength; i++) {
		if (hostmask[i] == '!') {
			nick[i] = '\x00';
			break;
		}
		nick[i] = hostmask[i];
	}
}

/**
 * Strips IRC Color codes from a string
 *
 * @param str				String to strip
 * @param maxlength			maximum length of str
 * @noreturn
 */

stock void IRC_Strip(char[] str, int maxlength) {
	for (int i = 0; i <= strlen(str); i++) {
		//  Underline           Reverse             Color codes off     Bold
		if (str[i] == '\x1F' || str[i] == '\x16' || str[i] == '\x0f' || str[i] == '\x02') {
			RemoveChar(str, maxlength, i);
		}
		// Strip color codes
		if (str[i] == '\x03') {
			RemoveChar(str, maxlength, i);
			//bool ignorelast = false;

			if (47 < str[i] < 58) {
				RemoveChar(str, maxlength, i);
				if ((47 < str[i] < 58) || str[i] == ',') {
					//if (str[i] == ',') {
					//	ignorelast = true;
					//}
					RemoveChar(str, maxlength, i);
					//if ((47 < str[i] < 58) || str[i] == ',') {
					//	PrintToChatAll("Removing 4 %s", str[i]);
					//	RemoveChar(str, maxlength, i);
					//	if (47 < str[i] < 58) {
					//		PrintToChatAll("Removing 5 %s", str[i]);
					//		RemoveChar(str, maxlength, i);
					//		if (47 < str[i] < 58 && !ignorelast) {
					//			PrintToChatAll("Removing 6 %s", str[i]);
					//			RemoveChar(str, maxlength, i);
					//		}
					//	}
					//}
				}
			}
			i--;
		}
	}
}

/**
 * Removes a character from a string.
 *
 * @param str				String to strip.
 * @param maxlength			maximum length of str.
 * @param c					character index to remove.
 * @noreturn
 */

stock void RemoveChar(char[] str, int maxlen, int c) {
	for (int i = c; i < maxlen-1; i++) {
		str[i] = str[i+1];
	}
	str[maxlen-1] = '\0';
}


/**
 * Strips Game Color codes from a string
 *
 * @param str				String to strip
 * @param maxlength			maximum length of str
 * @noreturn
 */

stock void IRC_StripGame(char[] str, int maxlen) {
	for (int i = 0; i <= strlen(str); i++) {
		//  Default             Team/LightGreen     Green               Olive
		if (str[i] == '\x01' || str[i] == '\x03' || str[i] == '\x04' || str[i] == '\x05') {
			RemoveChar(str, maxlen, i);
		}
	}
}
