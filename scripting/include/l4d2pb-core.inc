#if defined _mynatives_included_
  #endinput
#endif
#define _mynatives_included_

enum BoxType {
    BOXTYPE_NONE = 0,
    BOXTYPE_GOOD,
    BOXTYPE_MID,
    BOXTYPE_BAD
}

#if !defined PL_CORE
/**
 * Prints a debug message from the core plugin.
 *
 * @param req      The required verbose level from the core plugin.
 * @param msg      The debug message to send.
 * @param ...      Formatted arguments for msg.
 *
 * @return void
 */
native void L4D2PB_DebugMsg(int req, const char[] msg, any...);

/**
 * Registers a box to core and adds it to the box rotation.
 *
 * @param type      The box type (BoxType enum).
 * @param name      A short/code name for the box.
 * @param display   The box display name.      
 *
 * @return 0 on success or 1 on error.
 */
native int L4D2PB_RegisterBox(BoxType type, const char[] name, const char[] display);

/**
 * Unloads a box from the core.
 *
 * @param name      A short/code name for the box.
 *
 * @return 0 on success or 1 on error.
 */
native int L4D2PB_UnloadBox(const char[] name);
#endif