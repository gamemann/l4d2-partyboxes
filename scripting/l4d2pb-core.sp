#include <sourcemod>
#include <sdktools>

#define PL_CORE
#include <l4d2pb-core>

//#define USE_COLORS

#if defined USE_COLORS
#include <multicolors>
#endif

//#define CHAT_USE_TAG
#define CHAT_EXTRA_BYTES 255

//#define TEST_CHATALL_CMD

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

// ConVars
ConVar gCvEnabled = null;

ConVar gCvVerbose = null;
ConVar gCvVerboseType = null;

ConVar gCvAnnounce = null;
ConVar gCvAnnounceType = null;

ConVar gCvRemoveOpened = null;

ConVar gCvNoneChance = null;
ConVar gCvGoodChance = null;
ConVar gCvMidChance = null;
ConVar gCvBadChance = null;

ConVar gCvMaxType = null;
ConVar gCvMaxGoodBoxes = null;
ConVar gCvMaxMidBoxes = null;
ConVar gCvMaxBadBoxes = null;

ConVar gCvEndRoundStats = null;

// ConVar values
bool gEnabled;

int gVerbose;
int gVerboseType;

bool gAnnounce;
int gAnnounceType;

bool gRemoveOpened;

float gNoneChance;
float gGoodChance;
float gMidChance;
float gBadChance;

int gMaxType;
int gMaxGoodBoxes;
int gMaxMidBoxes;
int gMaxBadBoxes;

bool gEndRoundStats;

// Forwards
GlobalForward gGfBoxOpened;

GlobalForward gGfCoreCfgsLoaded;
GlobalForward gGfCoreLoaded;
GlobalForward gGfCoreUnloaded;

// Other global variables
ArrayList gBoxes;
BoxType gLastBoxType = BOXTYPE_NONE;

public APLRes AskPluginLoad2(Handle hdl, bool late, char[] err, int errMax) {
    RegPluginLibrary("l4d2pb");

    // Natives.
    CreateNative("L4D2PB_RegisterBox", Native_RegisterBox);
    CreateNative("L4D2PB_UnloadBox", Native_UnloadBox);

    CreateNative("L4D2PB_DebugMsg", Native_DebugMsg);
    CreateNative("L4D2PB_PrintToChat", Native_PrintToChat);
    CreateNative("L4D2PB_PrintToChatAll", Native_PrintToChatAll);

    return APLRes_Success;
}

public void OnPluginStart() {

    // Check for game engine.
    EngineVersion eng = GetEngineVersion();

    if (eng != Engine_Left4Dead2)
        SetFailState("%t Server not running Left 4 Dead 2. Aborting...", "Tag");

    // Create convars.
    gCvEnabled = CreateConVar("l4d2pb_enabled", "1", "Enables or disables L4D2 Party Boxes plugin.", _, true, 0.0, true, 1.0);
    gCvEnabled.AddChangeHook(CVar_Changed);

    gCvVerbose = CreateConVar("l4d2pb_verbose", "0", "The plugin's verbose level.", _, true, 0.0);
    gCvVerbose.AddChangeHook(CVar_Changed);

    gCvVerboseType = CreateConVar("l4d2pb_verbose_type", "0", "The type of verbose messages. 0 = prints to chat. 1 = prints to server console. 2 = prints to client's console.", _, true, 0.0);
    gCvVerboseType.AddChangeHook(CVar_Changed);

    gCvAnnounce = CreateConVar("l4d2pb_announce", "1", "Whether to announce who opens boxes.", _, true, 0.0, true, 1.0);
    gCvAnnounce.AddChangeHook(CVar_Changed);

    gCvAnnounceType = CreateConVar("l4d2pb_announce_type", "3", "What type of printing to do for announcing. 0 = chat. 1 = server console. 2 = client console. 3 = hint.", _, true, 0.0);
    gCvAnnounceType.AddChangeHook(CVar_Changed);

    gCvRemoveOpened = CreateConVar("l4d2pb_remove_opened", "1", "If 1, any boxes that are opened (and not none type) are removed immediately when opened.", _, true, 0.0, true, 1.0);
    gCvRemoveOpened.AddChangeHook(CVar_Changed);

    gCvNoneChance = CreateConVar("l4d2pb_chance_none", "0.10", "The chances of getting no fun boxes when opened.", _, true, 0.0, true, 1.0);
    gCvNoneChance.AddChangeHook(CVar_Changed);

    gCvGoodChance = CreateConVar("l4d2pb_chance_good", "0.15", "The chances of a good box being opened.", _, true, 0.0, true, 1.0);
    gCvGoodChance.AddChangeHook(CVar_Changed);

    gCvMidChance = CreateConVar("l4d2pb_chance_mid", "0.50", "The chances of a mid box being opened.", _, true, 0.0, true, 1.0);
    gCvMidChance.AddChangeHook(CVar_Changed);

    gCvBadChance = CreateConVar("l4d2pb_chance_bad", "0.25", "The chances of a bad box being opened.", _, true, 0.0, true, 1.0);
    gCvBadChance.AddChangeHook(CVar_Changed);

    gCvMaxType = CreateConVar("l4d2pb_max_type", "0", "The type of max limits. 0 = round-based. 1 = map-based.", _, true, 0.0, true, 2.0);
    gCvMaxType.AddChangeHook(CVar_Changed);

    gCvMaxGoodBoxes = CreateConVar("l4d2pb_max_good_boxes", "-1", "The maximum amount of good boxes that can be opened per round. 0 = disables good boxes. -1 = no limit.");
    gCvMaxGoodBoxes.AddChangeHook(CVar_Changed);

    gCvMaxMidBoxes = CreateConVar("l4d2pb_max_mid_boxes", "-1", "The maximum amount of mid boxes that can be opened per round. 0 = disables mid boxes. -1 = no limit.");
    gCvMaxMidBoxes.AddChangeHook(CVar_Changed);

    gCvMaxBadBoxes = CreateConVar("l4d2_max_bad_boxes", "-1", "The maximum amount of bad boxes that can be opened per round. 0 = disables bad boxes. -1 = no limit.");
    gCvMaxBadBoxes.AddChangeHook(CVar_Changed);

    gCvEndRoundStats = CreateConVar("l4d2pb_end_round_stats", "1", "Whether to display stats in chat on round end.", _, true, 0.0, true, 1.0);
    gCvEndRoundStats.AddChangeHook(CVar_Changed);

    CreateConVar("l4d2pb_version", PL_VERSION, "The plugin's version.");

    // Forwards.
    gGfCoreLoaded = new GlobalForward("L4D2PB_OnCoreLoaded", ET_Ignore);
    gGfCoreCfgsLoaded = new GlobalForward("L4D2PB_OnCoreCfgsLoaded", ET_Ignore);
    gGfCoreUnloaded = new GlobalForward("L4D2PB_OnCoreUnloaded", ET_Ignore);

    gGfBoxOpened = new GlobalForward("L4D2PB_OnBoxOpened", ET_Ignore, Param_Cell, Param_String, Param_Cell);

    // Events.
    HookEvent("upgrade_pack_used", Event_UpgradePackUsed);
    HookEvent("round_end", Event_RoundEnd);

    // Commands.
    RegConsoleCmd("sm_l4d2pb_stats", Command_Stats, "Prints stats and information.");

    RegAdminCmd("sm_l4d2pb_open", Command_OpenBox, ADMFLAG_ROOT, "Opens a specified box.");

#if defined TEST_CHATALL_CMD
    RegAdminCmd("sm_l4d2pb_test", Command_Test, ADMFLAG_ROOT);
#endif
    
    // Load translactions file.
    LoadTranslations("l4d2pb.phrases.txt");

    // Execute SourceMod config.
    AutoExecConfig(true, "plugin.l4d2pb");

    gBoxes = new ArrayList(sizeof(Box));

    // Call L4D2PB_OnCoreLoaded().
    Call_StartForward(gGfCoreLoaded);
    Call_Finish();

    // Reset box counters now so they start at 0.
    ResetBoxCounters();
}

public void OnPluginEnd() {
    // Call L4D2PB_OnCoreUnloaded().
    Call_StartForward(gGfCoreUnloaded);
    Call_Finish();
}

stock void SetCVars() {
    gEnabled = gCvEnabled.BoolValue;

    gVerbose = gCvVerbose.IntValue;
    gVerboseType = gCvVerboseType.IntValue;

    gAnnounce = gCvAnnounce.BoolValue;
    gAnnounceType = gCvAnnounceType.IntValue;

    gRemoveOpened = gCvRemoveOpened.BoolValue;
    
    gNoneChance = gCvNoneChance.FloatValue;
    gGoodChance = gCvGoodChance.FloatValue;
    gMidChance = gCvMidChance.FloatValue;
    gBadChance = gCvBadChance.FloatValue;

    gMaxType = gCvMaxType.IntValue;
    gMaxGoodBoxes = gCvMaxGoodBoxes.IntValue;
    gMaxMidBoxes = gCvMaxMidBoxes.IntValue;
    gMaxBadBoxes = gCvMaxBadBoxes.IntValue;

    gEndRoundStats = gCvEndRoundStats.BoolValue;
}

public void OnConfigsExecuted() {
    // Set convar values.
    SetCVars();

    // Call L4D2PB_OnCoreCfgsLoaded();
    Call_StartForward(gGfCoreCfgsLoaded);
    Call_Finish();
}

public void CVar_Changed(ConVar cv, const char[] oldV, const char[] newV) {
    SetCVars();
}

stock void BPrintToChat(int client, const char[] msg, any...) {
    // We need to format the message.
    int len = strlen(msg) + CHAT_EXTRA_BYTES;
    char[] fMsg = new char[len];

    VFormat(fMsg, len, msg, 3);

#if defined CHAT_USE_TAG
    Format(fMsg, sizeof(fMsg), "%t %s", "Tag", fMsg);
#endif

#if defined USE_COLORS
    CPrintToChat(client, fMsg);
#else
    PrintToChat(client, fMsg);
#endif
}

stock void BPrintToChatAll(const char[] msg, any...) {
    // We need to format the message.
    int len = strlen(msg) + CHAT_EXTRA_BYTES;
    char[] fMsg = new char[len];

    VFormat(fMsg, len, msg, 2);

#if defined CHAT_USE_TAG
    Format(fMsg, sizeof(fMsg), "%t %s", "Tag", fMsg);
#endif

#if defined USE_COLORS
    CPrintToChatAll(fMsg);
#else
    PrintToChatAll(fMsg);
#endif
}

stock void DebugMsg(int req, const char[] msg, any...) {
    if (req > gVerbose)
        return;

    // We need to format the message.
    int len = strlen(msg) + CHAT_EXTRA_BYTES;
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

    for (int i = 1; i <= MaxClients; i++) {
        gClNoneBoxesOpened[i] = 0;
        gClGoodBoxesOpened[i] = 0;
        gClMidBoxesOpened[i] = 0;
        gClBadBoxesOpened[i] = 0;
    }
}

stock void PrintStats() {
    // Get individual stats.
    int mostGoodClient = -1;
    char mostGoodName[MAX_NAME_LENGTH];

    int mostMidClient = -1;
    char mostMidName[MAX_NAME_LENGTH];

    int mostBadClient = -1;
    char mostBadName[MAX_NAME_LENGTH];

    // Loop through all players.
    for (int i = 1; i <= MaxClients; i++) {
        if (!IsClientInGame(i))
            continue;

        // Check good boxes.
        if (mostGoodClient == -1 || gClGoodBoxesOpened[i] > gClGoodBoxesOpened[mostGoodClient])
            mostGoodClient = i;

        // Check mid boxes.
        if (mostMidClient == -1 || gClMidBoxesOpened[i] > gClMidBoxesOpened[mostMidClient])
            mostMidClient = i;

        // Check bad boxes.
        if (mostBadClient == -1 || gClBadBoxesOpened[i] > gClBadBoxesOpened[mostBadClient])
            mostBadClient = i;
    }

    // Print most good boxes if we have a count.
    if (mostGoodClient != -1 && gClGoodBoxesOpened[mostGoodClient] > 0) {
        GetClientName(mostGoodClient, mostGoodName, sizeof(mostGoodName));

        BPrintToChatAll("%t %t", "Tag", "EndRoundStatsGood", mostGoodName, gClGoodBoxesOpened[mostGoodClient]);
    }

    // Print most mid boxes if we have a count.
    if (mostMidClient != -1 && gClMidBoxesOpened[mostMidClient] > 0) {
        GetClientName(mostMidClient, mostMidName, sizeof(mostMidName));

        BPrintToChatAll("%t %t", "Tag", "EndRoundStatsMid", mostMidName, gClMidBoxesOpened[mostMidClient]);
    }

    // Print most bad boxes if we have a count.
    if (mostBadClient != -1 && gClBadBoxesOpened[mostBadClient] > 0) {
        GetClientName(mostBadClient, mostBadName, sizeof(mostBadName));

        BPrintToChatAll("%t %t", "Tag", "EndRoundStatsBad", mostBadName, gClBadBoxesOpened[mostBadClient]);
    }

    int totalBoxes = gGoodBoxesOpened + gMidBoxesOpened + gBadBoxesOpened;

    BPrintToChatAll("%t %t", "Tag", "EndRoundStatsGlobal", totalBoxes, gGoodBoxesOpened, gMidBoxesOpened, gBadBoxesOpened);
}

stock void AnnounceBox(int client, Box box) {
    // Get client name,
    char name[MAX_NAME_LENGTH];
    GetClientName(client, name, sizeof(name));

    // Create and format message.
    char msg[256];

    Format(msg, sizeof(msg), "%t", "OpenAnnounce", name, box.display);

    switch (view_as<MsgType>(gAnnounceType)) {
        case MSG_CHAT:
            BPrintToChatAll("%t %s", "Tag", msg);

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

    BPrintToChat(client, "%t %t", "Tag", "CmdStatsGlobal", totalBoxes, clTotalBoxes, gBoxes.Length);

    return Plugin_Handled;
}

public Action Command_OpenBox(int client, int args) {
    // Make sure we have a box name.
    if (args < 1) {
        BPrintToChat(client, "Usage: sm_l4d2pb_open <box name>");

        return Plugin_Handled;
    }

    // Retrieve the box name.
    char boxName[MAX_NAME_LENGTH];

    GetCmdArg(1, boxName, sizeof(boxName));

    BPrintToChat(client, "%t %t", "Tag", "CmdOpenReply", boxName);

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

#if defined TEST_CHATALL_CMD
public Action Command_Test(int client, int args) {
    BPrintToChat(client, "{red} Test {default} message sent to {green}client {default}(%N)!", client);
    BPrintToChatAll("{red} Test {default} message sent to {green}all {default}clients!");

    PrintToChat(client, "Test done!");

    return Plugin_Handled;
} 
#endif

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

    // Assign last box type.
    gLastBoxType = randType;

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

public Action Timer_CheckBox(Handle timer, int en) {
    // Ignore if last box type is none.
    if (gLastBoxType == BOXTYPE_NONE)
        return Plugin_Stop;

    // Destroy entity.
    if (IsValidEdict(en))
        AcceptEntityInput(en, "kill");

    return Plugin_Stop;
    
}

public void OnEntityCreated(int en, const char[] className) {
    //DebugMsg(6, "Entity created (%d) => %s", en, className);

    // Check if we need to create a timer to destroy the entity if a valid box.
    // Note - Not sure if there is a better way to do this, but the upgrade used hook doesn't contain an entity index. So I can't think of any better way.
    if ((strcmp(className, "upgrade_ammo_incendiary", false) == 0 || strcmp(className, "upgrade_ammo_explosive", false) == 0) && gRemoveOpened)
        CreateTimer(0.1, Timer_CheckBox, en);
    
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

public int Native_PrintToChat(Handle pl, int paramsCnt) {
    // Get required level.
    int client = GetNativeCell(1);

    int msgLen;
    GetNativeStringLength(2, msgLen);

    if (msgLen <= 0)
        return 1;

    char[] msg = new char[msgLen + 1];
    GetNativeString(2, msg, msgLen + 1);

    char fMsg[4096];
    FormatNativeString(0, 0, 3, sizeof(fMsg), _, fMsg, msg);

    BPrintToChat(client, fMsg);
    
    return 0;
}

public int Native_PrintToChatAll(Handle pl, int paramsCnt) {
    int msgLen;
    GetNativeStringLength(1, msgLen);

    if (msgLen <= 0)
        return 1;

    char[] msg = new char[msgLen + 1];
    GetNativeString(1, msg, msgLen + 1);

    char fMsg[4096];
    FormatNativeString(0, 0, 2, sizeof(fMsg), _, fMsg, msg);

    BPrintToChatAll(fMsg);
    
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