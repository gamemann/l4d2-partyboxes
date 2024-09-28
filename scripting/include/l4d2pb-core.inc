#if defined _mynatives_included_
  #endinput
#endif
#define _mynatives_included_

/**
 * Prints a debug message from the core plugin.
 *
 * @param req      The required verbose level from the core plugin.
 * @param msg      The debug message to send.
 * @param ...      Formatted arguments for msg.
 *
 * @return void
 */
native void DebugMsg(int req, const char[] msg, any...);

/**
 * Registers a box to core and adds it to the box rotation.
 *
 * @param type      The box type (1 = Good, 2 = Mid, 3 = Bad))
 * @param name      A short/code name for the box.
 * @param display   The box display name.      
 *
 * @return 0 on success or 1 on error.
 */
native int RegisterBox(int type, const char[] name, const char[] display);

/**
 * Unloads a box from the core.
 *
 * @param type      The box type (1 = Good, 2 = Mid, 3 = Bad))
 * @param name      A short/code name for the box.
 *
 * @return 0 on success or 1 on error.
 */
native int UnloadBox(int type, const char[] name);