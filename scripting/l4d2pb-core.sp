#include <sourcemod>

#define PL_CORE
#include <l4d2pb-core>

#define PL_VERSION "1.0.0"

#define BOX_MAX_TYPES 4
#define MSG_MAX_TYPES 4

public Plugin myinfo = {
    name = "L4D2 Party Boxes - Core",
    author = "Christian Deacon (Gamemann)",
    description = "Party boxes in Left 4 Dead 2!",
    version = PL_VERSION,
    url = "ModdingCommunity.com"
};

enum struct Box {
    BoxType type;
    char name[MAX_NAME_LENGTH];
    char display[MAX_NAME_LENGTH];
}

int gNoneBoxesOpened = 0;
int gGoodBoxesOpened = 0;
int gMidBoxesOpened = 0;
int gBadBoxesOpened = 0;

int gClNoneBoxesOpened[MAXPLAYERS + 1];
int gClGoodBoxesOpened[MAXPLAYERS + 1];
int gClMidBoxesOpened[MAXPLAYERS + 1];
int gClBadBoxesOpened[MAXPLAYERS + 1];

enum MsgType {
    MSG_CHAT = 0,
    MSG_SERVER,
    MSG_CONSOLE,
    MSG_HINT
}

enum MaxType {
    MAX_ROUND = 0,
    MAX_MAP
}

ConVar gCvEnabled = null;

ConVar gCvVerbose = null;
ConVar gCvVerboseType = null;

ConVar gCvAnnounce = null;
ConVar gCvAnnounceType = null;

ConVar gCvNoneChance = null;
ConVar gCvGoodChance = null;
ConVar gCvMidChance = null;
ConVar gCvBadChance = null;

ConVar gCvMaxType = null;
ConVar gCvMaxGoodBoxes = null;
ConVar gCvMaxMidBoxes = null;
ConVar gCvMaxBadBoxes = null;

ConVar gCvEndRoundStats = null;

bool gEnabled = true;

int gVerbose = 0;
int gVerboseType = view_as<int>(MSG_CHAT);

bool gAnnounce = true;
int gAnnounceType = view_as<int>(MSG_HINT);

float gNoneChance = 0.10;
float gGoodChance = 0.15;
float gMidChance = 0.50;
float gBadChance = 0.25;

int gMaxType = view_as<int>(MAX_ROUND);
int gMaxGoodBoxes = -1;
int gMaxMidBoxes = -1;
int gMaxBadBoxes = -1;

bool gEndRoundStats = true;

GlobalForward gGfBoxOpened;

ArrayList gBoxes;

public APLRes AskPluginLoad2(Handle hdl, bool late, char[] err, int errMax) {
    RegPluginLibrary("l4d2pb");

    // Natives.
    CreateNative("DebugMsg", Native_DebugMsg);

    CreateNative("RegisterBox", Native_RegisterBox);
    CreateNative("UnloadBox", Native_UnloadBox);

    return APLRes_Success;
}

public void OnPluginStart() {

    // Check for game engine.
    EngineVersion eng = GetEngineVersion();

    if (eng != Engine_Left4Dead2)
        SetFailState("%t Server not running Left 4 Dead 2. Aborting...", "Tag");

    // Create convars.
    gCvEnabled = CreateConVar("l4d2pb_enabled", "1", "Enables or disables L4D2 Party Boxes plugin.", _, true, 0.0, true, 1.0);
    HookConVarChange(gCvEnabled, CVar_Changed);

    gCvVerbose = CreateConVar("l4d2pb_verbose", "0", "The plugin's verbose level.", _, true, 0.0);
    HookConVarChange(gCvVerbose, CVar_Changed);

    gCvVerboseType = CreateConVar("l4d2pb_verbose_type", "0", "The type of verbose messages. 0 = prints to chat. 1 = prints to server console. 2 = prints to client's console.", _, true, 0.0);
    HookConVarChange(gCvVerboseType, CVar_Changed);

    gCvAnnounce = CreateConVar("l4d2pb_announce", "1", "Whether to announce who opens boxes.", _, true, 0.0, true, 1.0);
    HookConVarChange(gCvAnnounce, CVar_Changed);

    gCvAnnounceType = CreateConVar("l4d2pb_announce_type", "3", "What type of printing to do for announcing. 0 = chat. 1 = server console. 2 = client console. 3 = hint.", _, true, 0.0);
    HookConVarChange(gCvAnnounceType, CVar_Changed);

    gCvNoneChance = CreateConVar("l4d2pb_chance_none", "0.10", "The chances of getting no fun boxes when opened.", _, true, 0.0, true, 1.0);
    HookConVarChange(gCvNoneChance, CVar_Changed);

    gCvGoodChance = CreateConVar("l4d2pb_chance_good", "0.15", "The chances of a good box being opened.", _, true, 0.0, true, 1.0);
    HookConVarChange(gCvGoodChance, CVar_Changed);

    gCvMidChance = CreateConVar("l4d2pb_chance_mid", "0.50", "The chances of a mid box being opened.", _, true, 0.0, true, 1.0);
    HookConVarChange(gCvMidChance, CVar_Changed);

    gCvBadChance = CreateConVar("l4d2pb_chance_bad", "0.25", "The chances of a bad box being opened.", _, true, 0.0, true, 1.0);
    HookConVarChange(gCvBadChance, CVar_Changed);

    gCvMaxType = CreateConVar("l4d2pb_max_type", "0", "The type of max limits. 0 = round-based. 1 = map-based.", _, true, 0.0, true, 2.0);
    HookConVarChange(gCvMaxType, CVar_Changed);

    gCvMaxGoodBoxes = CreateConVar("l4d2pb_max_good_boxes", "-1", "The maximum amount of good boxes that can be opened per round. 0 = disables good boxes. -1 = no limit.");
    HookConVarChange(gCvMaxGoodBoxes, CVar_Changed);

    gCvMaxMidBoxes = CreateConVar("l4d2pb_max_mid_boxes", "-1", "The maximum amount of mid boxes that can be opened per round. 0 = disables mid boxes. -1 = no limit.");
    HookConVarChange(gCvMaxMidBoxes, CVar_Changed);

    gCvMaxBadBoxes = CreateConVar("l4d2_max_bad_boxes", "-1", "The maximum amount of bad boxes that can be opened per round. 0 = disables bad boxes. -1 = no limit.");
    HookConVarChange(gCvMaxBadBoxes, CVar_Changed);

    gCvEndRoundStats = CreateConVar("l4d2pb_end_round_stats", "1", "Whether to display stats in chat on round end.", _, true, 0.0, true, 1.0);
    HookConVarChange(gCvEndRoundStats, CVar_Changed);

    CreateConVar("l4d2pb_version", PL_VERSION, "The plugin's version.");

    // Forwards.
    gGfBoxOpened = new GlobalForward("BoxOpened", ET_Ignore, Param_Cell, Param_String, Param_Cell);

    // Events.
    HookEvent("upgrade_pack_used", Event_UpgradePackUsed);
    HookEvent("round_end", Event_RoundEnd);

    // Commands.
    RegConsoleCmd("sm_l4d2pb_stats", Command_Stats, "Prints stats and information.");

    RegAdminCmd("sm_l4d2pb_open", Command_OpenBox, ADMFLAG_ROOT, "Opens a specified box.");
    
    // Load translactions file.
    LoadTranslations("l4d2pb.phrases.txt");

    // Execute SourceMod config.
    AutoExecConfig(true, "plugin.l4d2pb");

    gBoxes = new ArrayList(sizeof(Box));
}

public void OnConfigsExecuted() {
    gEnabled = GetConVarBool(gCvEnabled);

    gVerbose = GetConVarInt(gCvVerbose);
    gVerboseType = GetConVarInt(gCvVerboseType);

    gAnnounce = GetConVarBool(gCvAnnounce);
    gAnnounceType = GetConVarInt(gCvAnnounceType);
    
    gNoneChance = GetConVarFloat(gCvNoneChance);
    gGoodChance = GetConVarFloat(gCvGoodChance);
    gMidChance = GetConVarFloat(gCvMidChance);
    gBadChance = GetConVarFloat(gCvBadChance);

    gMaxType = GetConVarInt(gCvMaxType);
    gMaxGoodBoxes = GetConVarInt(gCvMaxGoodBoxes);
    gMaxMidBoxes = GetConVarInt(gCvMaxMidBoxes);
    gMaxBadBoxes = GetConVarInt(gCvMaxBadBoxes);

    gEndRoundStats = GetConVarBool(gCvEndRoundStats);
}

public void CVar_Changed(ConVar cv, const char[] oldV, const char[] newV) {
    OnConfigsExecuted();
}

stock void DebugMsg(int req, const char[] msg, any...) {
    if (req > gVerbose)
        return;

    // We need to format the message.
    int len = strlen(msg) + 255;
    char[] fMsg = new char[len];

    VFormat(fMsg, len, msg, 3);

    switch (view_as<MsgType>(gVerboseType)) {
        case MSG_CHAT:
            PrintToChatAll("%t %s", "Tag", fMsg);

        case MSG_CONSOLE:
            PrintToConsoleAll("%t %s", "Tag", fMsg);

        case MSG_SERVER:
            PrintToServer("%t %s", "Tag", fMsg);
    }
}

stock void ResetBoxCounters() {
    gNoneBoxesOpened = 0;
    gGoodBoxesOpened = 0;
    gMidBoxesOpened = 0;
    gBadBoxesOpened = 0;

    for (int i = 0; i < MaxClients; i++) {
        gClNoneBoxesOpened[i] = 0;
        gClGoodBoxesOpened[i] = 0;
        gClMidBoxesOpened[i] = 0;
        gClBadBoxesOpened[i] = 0;
    }
}

stock void PrintStats() {
    int totalBoxes = gGoodBoxesOpened + gMidBoxesOpened + gBadBoxesOpened;

    // To Do: Calculate individual stats.

    PrintToChatAll("%t A total of %d boxes were opened! Good boxes => %d. Mid boxes => %d. Bad boxes => %d.", "Tag", totalBoxes, gGoodBoxesOpened, gMidBoxesOpened, gBadBoxesOpened);
}

stock void AnnounceBox(int client, Box box) {
    char msg[256];

    Format(msg, sizeof(msg), "%N opened the '%s' box!", client, box.display);

    switch (view_as<MsgType>(gAnnounceType)) {
        case MSG_CHAT:
            PrintToChatAll("%t %s", "Tag", msg);

        case MSG_SERVER:
            PrintToServer("%t %s", "Tag", msg);

        case MSG_CONSOLE:
            PrintToConsoleAll("%t %s", "Tag", msg);

        case MSG_HINT:
            PrintHintTextToAll("%s", msg);
    }
}

stock Box GetBox(const char[] name) {
    Box ret;

    // Loop through all boxes and see if we find box.
    for (int i = 0; i < gBoxes.Length; i++) {
        Box cur;

        gBoxes.GetArray(i, cur);

        if (strcmp(cur.name, name, false) == 0) {
            ret = cur;

            break;
        }
    }
    
    return ret;
}

stock int BoxGetIdx(const char[] name) {
    int idx = -1;

    for (int i = 0; i < gBoxes.Length; i++) {
        Box cur;

        gBoxes.GetArray(i, cur);

        if (strcmp(cur.name, name, false) == 0) {
            idx = i;

            break;
        }
    }

    return idx;
}

stock bool BoxExists(const char[] name) {
    bool found = false;

    for (int i = 0; i < gBoxes.Length; i++) {
        Box cur;

        gBoxes.GetArray(i, cur);

        if (strcmp(cur.name, name, false) == 0) {
            found = true;

            break;
        }
    }

    return found;
}

stock void BoxRemoveDups(const char[] name) {
    for (int i = 0; i < gBoxes.Length; i++) {
        Box cur;

        gBoxes.GetArray(i, cur);

        if (strcmp(cur.name, name, false) == 0)
            gBoxes.Erase(i);
    }
}

stock BoxType PickRandomBoxType() {
    float randVal = GetRandomFloat();

    float prob = 0.0;

    for (int i = 0; i < BOX_MAX_TYPES; i++) {
        bool skip = false;

        BoxType type = view_as<BoxType>(i);

        if (type == BOXTYPE_NONE)
            prob += gNoneChance;
        else if (type == BOXTYPE_GOOD) {
            prob += gGoodChance;

            if (gMaxGoodBoxes == 0 || (gMaxGoodBoxes > 0 && gGoodBoxesOpened > gMaxGoodBoxes))
                skip = true;
        } else if (type == BOXTYPE_MID) {
            prob += gMidChance;

            if (gMaxMidBoxes == 0 || (gMaxMidBoxes > 0 && gMidBoxesOpened > gMaxMidBoxes))
                skip = true;
        } else if (type == BOXTYPE_BAD) {
            prob += gBadChance;

            if (gMaxBadBoxes == 0 || (gMaxBadBoxes > 0 && gBadBoxesOpened > gMaxBadBoxes))
                skip = true;
        }

        // Check if we should skip this box type.
        if (skip)
            continue;

        if (randVal <= prob)
            return view_as<BoxType>(i);
    }

    return BOXTYPE_NONE;
}

stock Box PickRandomBox(BoxType type) {
    ArrayList boxes = new ArrayList(sizeof(Box));

    for (int i = 0; i < gBoxes.Length; i++) {
        Box cur;

        gBoxes.GetArray(i, cur);

        DebugMsg(5, "Checking box at index %d (type %d == %d).", i, view_as<int>(cur.type), view_as<int>(type));

        if (cur.type == type)
            boxes.PushArray(cur);
    }

    // Choose random box.
    Box ret;
    
    if (boxes.Length > 0) {
        int idx = GetRandomInt(0, boxes.Length - 1);

        boxes.GetArray(idx, ret);

        DebugMsg(5, "Choosing random box at index %d!", idx, ret.name);
    }

    return ret;
}

public Action Command_Stats(int client, int args) {
    int totalBoxes = gGoodBoxesOpened + gMidBoxesOpened + gBadBoxesOpened;
    int clTotalBoxes = gClGoodBoxesOpened[client] + gClMidBoxesOpened[client] + gClBadBoxesOpened[client];

    PrintToChat(client, "%t A total of %d boxes have been opened so far. You've opened a total of %d boxes during this round/map. Total boxes => %d.", "Tag", totalBoxes, clTotalBoxes, gBoxes.Length);

    return Plugin_Handled;
}

public Action Command_OpenBox(int client, int args) {
    // Make sure we have a box name.
    if (args < 1) {
        PrintToChat(client, "Usage: sm_l4d2pb_open <box name>");

        return Plugin_Handled;
    }

    // Retrieve the box name.
    char boxName[MAX_NAME_LENGTH];

    GetCmdArg(1, boxName, sizeof(boxName));

    PrintToChat(client, "%t Opening box '%s' manually!", "Tag", boxName);

    // Call box opened forward with specified box name.
    Call_StartForward(gGfBoxOpened);

    Call_PushCell(0);
    Call_PushString(boxName);
    Call_PushCell(GetClientUserId(client));

    Call_Finish();

    // Check for announce.
    if (gAnnounce) {
        // First get box to pass to announce.
        Box box;
        box = GetBox(boxName);
        
        if (box.type != BOXTYPE_NONE)
            AnnounceBox(client, box);
    }

    return Plugin_Handled;
}

public void OnMapStart() {
    // We need to reset everything regardless.
    ResetBoxCounters();
}

public Action Event_UpgradePackUsed(Handle ev, const char[] name, bool dontBroadcast) {
    // Check if plugin is enabled.
    if (!gEnabled)
        return Plugin_Continue;

    // We need to check the type of upgrade.
    int upgradeId = GetEventInt(ev, "upgradeid", -1);

    if (upgradeId < 0)
        return Plugin_Continue;

    // Check box count.
    if (gBoxes.Length < 1) {
        DebugMsg(1, "Upgrade box used, but no boxes found!");

        return Plugin_Continue;
    }

    // Get user ID.
    int userId = GetEventInt(ev, "userid", -1);

    // Get client index.
    int client = GetClientOfUserId(userId);

    // Get random type.
    BoxType randType = PickRandomBoxType();

    // Increment box opened stats (global and client).
    if (randType == BOXTYPE_NONE) {
        gNoneBoxesOpened++;
        gClNoneBoxesOpened[client]++;
    } else if (randType == BOXTYPE_GOOD) {
        gGoodBoxesOpened++;
        gClGoodBoxesOpened[client]++;
    } else if (randType == BOXTYPE_MID) {
        gMidBoxesOpened++;
        gClMidBoxesOpened[client]++;
    } else if (randType == BOXTYPE_BAD) {
        gBadBoxesOpened++;
        gClBadBoxesOpened[client]++;
    }

    DebugMsg(3, "Upgrade box used and box type == %d!", view_as<int>(randType));

    // Check for none box.
    if (randType == BOXTYPE_NONE)
        return Plugin_Continue;

    // Select random box from type if we don't have a none box.
    Box randBox;
    
    // If the random box type is none, this is an invalid box.
    randBox = PickRandomBox(randType);

    DebugMsg(3, "Picked random box: %s!", randBox.name);

    // Make sure this is a valid box.
    if (randBox.type == BOXTYPE_NONE) {
        DebugMsg(1, "Random box picked, but box type is none indicating invalid box.", randBox.name, view_as<int>(randBox.type));

        return Plugin_Continue;
    }

    // Check for announce.
    if (gAnnounce)
        AnnounceBox(client, randBox);

    // Call box opened forward.
    Call_StartForward(gGfBoxOpened);

    Call_PushCell(view_as<int>(randBox.type));
    Call_PushString(randBox.name);
    Call_PushCell(userId);

    Call_Finish();

    // To Do: Print to chat, keep track of client, etc.

    return Plugin_Handled;
}

public Action Event_RoundEnd(Handle ev, const char[] name, bool dontBroadcast) {
    // Check if we need to print end-round stats.
    if (gEndRoundStats)
        PrintStats();

    // Check if we need to reset box counters.
    if (view_as<MaxType>(gMaxType) == MAX_ROUND)
        ResetBoxCounters();

    return Plugin_Continue;
}

public int Native_DebugMsg(Handle pl, int paramsCnt) {
    // Get required level.
    int req = GetNativeCell(1);

    int msgLen;
    GetNativeStringLength(2, msgLen);

    if (msgLen <= 0)
        return 1;

    char[] msg = new char[msgLen + 1];
    GetNativeString(2, msg, msgLen + 1);

    char fMsg[4096];
    FormatNativeString(0, 0, 3, sizeof(fMsg), _, fMsg, msg);

    DebugMsg(req, fMsg);
    
    return 0;
}

public int Native_RegisterBox(Handle pl, int paramsCnt) {
    // Get type.
    int type = GetNativeCell(1);

    // Get name.
    int nameLen;
    GetNativeStringLength(2, nameLen);

    if (nameLen <= 0)
        return 1;
        
    char[] name = new char[nameLen + 1];
    GetNativeString(2, name, nameLen + 1);

    // Get display name.
    int displayLen;
    GetNativeStringLength(3, displayLen);

    if (displayLen <= 0)
        return 1;

    char[] display = new char[displayLen + 1];
    GetNativeString(3, display, displayLen + 1);

    // Create box.
    Box newBox;

    strcopy(newBox.name, sizeof(newBox.name), name);
    strcopy(newBox.display, sizeof(newBox.display), display);
    newBox.type = view_as<BoxType>(type);

    // Remove dups.
    BoxRemoveDups(name);

    // Add box to string map.
    int idx = gBoxes.PushArray(newBox);

    DebugMsg(2, "Registing box '%s' (%s) at index %d! Box type => %d.", newBox.name, newBox.display, idx, view_as<int>(newBox.type));

    return 0;
}

public int Native_UnloadBox(Handle pl, int paramsCnt) {
    int nameLen;
    GetNativeStringLength(1, nameLen);

    if (nameLen <= 0)
        return 1;
        
    char[] name = new char[nameLen + 1];
    GetNativeString(1, name, nameLen + 1);

    // Get index.
    int idx = BoxGetIdx(name);

    if (idx != -1)
        gBoxes.Erase(idx);

    return 0;
}