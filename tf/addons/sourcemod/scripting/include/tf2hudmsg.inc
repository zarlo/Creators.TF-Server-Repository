#if defined _inc_tf2hudmsg
#endinput
#endif
#define _inc_tf2hudmsg

// --== NATIVES ==--

/**
 * Displays a HudNotification (centered, bottom half) for the client
 * This element will NOT show with minimal hud!
 * https://forums.alliedmods.net/showthread.php?t=155911
 * @param client  The target player
 * @param icon    Icon name taken from mod_textures.txt (does not always resize correctly)
 * @param background (Use a TFTeam or -1 for client team color)
 * @param stripMoreColors set true to remove colors that might have been used in translation files
 * @param message (+ format)
 */
native void TF2_HudNotificationCustom(int client, const char[] icon="voice_self", int background=-1, bool stripMoreColors=false, const char[] message, any ...);
/**
 * Displays a HudNotification (centered, bottom half) for all client
 * This element will NOT show with minimal hud!
 * https://forums.alliedmods.net/showthread.php?t=155911
 * @param icon    Icon name taken from mod_textures.txt (does not always resize correctly)
 * @param background (Use a TFTeam or -1 for client team color)
 * @param stripMoreColors set true to remove colors that might have been used in translation files
 * @param message (+ format)
 */
native void TF2_HudNotificationCustomAll(const char[] icon="voice_self", int background=-1, bool stripMoreColors=false, const char[] message, any ...);

// --== Yay, CursorAnnotations for everyone ==--

/** Maximum length of an annotation message */
#define MAX_ANNOTATION_LENGTH 256

/**
 * While an annotation is not a handle, you can remove it by calling Close. You can not however use delete.
 * Changing any values will require you to call send, in order for the clients to receive the updated information.
 */
methodmap CursorAnnotation {
	
	/**
	 * Only use index and reset if you know what you're doing!
	 * 
	 * @param index  -1 to automatically find initialize an unused index, otherwise re-wraps the index
	 * @param reset  if index > 0 and the annotation is in use it will reset all values anyways
	 */
	public native CursorAnnotation(int index = -1, bool reset=false);
	
	public native void Close();
	property bool IsValid { 
		public native get();
	}
	
	/**
	 * set the visibility for a specific player;
	 */
	public native void SetVisibilityFor(int client, bool visible=true);
	/**
	 * set the visibility of this annotation for all players
	 */
	public native void SetVisibilityAll(bool visible);
	/**
	 * with a maximum of 32 players, this bitmask represents the client that can see this annotation
	 */
	property int VisibilityBitmask {
		public native get();
		public native set(int value);
	}
	/**
	 * Some additional data you can attach to the annotation
	 */
	property any Data {
		public native get();
		public native set(any value);
	}
	/** 
	 * Set the text for this annotation. Checks if the new message differs from the previously buffered to prevent flickering.
	 * @return true if the supplied text was different
	 */
	public native bool SetText(const char[] text);
	/**
	 * Set the position of this cursor annotation. Dunno if it can be used as offset to the parent entity.
	 */
	public native void SetPosition(const float vec[3]);
	/**
	 * Get the position of this cursor annotation. Dunno if it can be used as offset to the parent entity.
	 */
	public native void GetPosition(float vec[3]);
	/**
	 * Set the lifetime for this annotation in seconds. 
	 * Set it super high if you don't want it to go away. (1800.0 = 30 min)
	 */
	public native void SetLifetime(float lifetime);
	/**
	 * The Parent Entity is the Entity that this annotation follows
	 */
	property int ParentEntity {
		public native get();
		public native set(int value);
	}
	
	/** 
	 * Tries to estimate whether this annotation is currently "delivered"/playing
	 * using the annotations lifetime and the update/hide methods
	 */
	property bool IsPlaying { 
		public native get();
	}
	/**
	 * Update and show the annotation according to the currently set up data
	 * 
	 * @param sound the sound to play along the annotation
	 * @param showEffect emits a green radial becon
	 */
	public native void Update(const char[] sound = "misc/null.wav", bool showEffect=false);
	/**
	 * hides this annotation form all, until Update is called again
	 */
	public native void Hide();
}

public SharedPlugin __pl_tf2hudmsg = {
    name = "tf2hudmsg",
    file = "tf2hudmsg.smx",
#if defined REQUIRE_PLUGIN
    required = 1,
#else
    required = 0,
#endif
};

#if !defined REQUIRE_PLUGIN
public void __pl_tf2hudmsg_SetNTVOptional() {
	MarkNativeAsOptional("CursorAnnotation.CursorAnnotation");
	MarkNativeAsOptional("CursorAnnotation.Close");
	MarkNativeAsOptional("CursorAnnotation.IsValid.get");
	MarkNativeAsOptional("CursorAnnotation.SetVisibilityFor");
	MarkNativeAsOptional("CursorAnnotation.SetVisibilityAll");
	MarkNativeAsOptional("CursorAnnotation.VisibilityBitmask.get",Native_CursorAnnotation_VisibilityBitmask_Get);
	MarkNativeAsOptional("CursorAnnotation.VisibilityBitmask.set",Native_CursorAnnotation_VisibilityBitmask_Set);
	MarkNativeAsOptional("CursorAnnotation.Data.get");
	MarkNativeAsOptional("CursorAnnotation.Data.set");
	MarkNativeAsOptional("CursorAnnotation.SetText");
	MarkNativeAsOptional("CursorAnnotation.SetPosition");
	MarkNativeAsOptional("CursorAnnotation.GetPosition");
	MarkNativeAsOptional("CursorAnnotation.SetLifetime");
	MarkNativeAsOptional("CursorAnnotation.ParentEntity.get");
	MarkNativeAsOptional("CursorAnnotation.ParentEntity.set");
	MarkNativeAsOptional("CursorAnnotation.IsPlaying.get");
	MarkNativeAsOptional("CursorAnnotation.Update");
	MarkNativeAsOptional("CursorAnnotation.Hide");
	MarkNativeAsOptional("TF2_HudNotificationCustom");
	MarkNativeAsOptional("TF2_HudNotificationCustomAll");
}
#endif
