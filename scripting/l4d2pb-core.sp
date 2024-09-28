#include <sourcemod>

#define PL_VERSION "1.0.0"

#define BOX_MAX_TYPES 4

public Plugin myinfo = {
    name = "L4D2 Party Boxes - Core",
    author = "Christian Deacon (Gamemann)",
    description = "Party boxes in Left 4 Dead 2!",
    version = PL_VERSION,
    url = "ModdingCommunity.com"
};

enum BoxType {
    BOXTYPE_NONE = 0,
    BOXTYPE_GOOD,
    BOXTYPE_MID,
    BOXTYPE_BAD
}

enum struct Box {
    char name[MAX_NAME_LENGTH];
    char display[MAX_NAME_LENGTH];
    BoxType type;
}

int gNoneBoxesOpen[MAXPLAYERS + 1];
int gGoodBoxesOpen[MAXPLAYERS + 1];
int gMidBoxesOpen[MAXPLAYERS + 1];
int gBadBoxesOpen[MAXPLAYERS + 1];

ConVar gCvEnabled = null;

ConVar gCvNoneChance = null;
ConVar gCvGoodChance = null;
ConVar gCvMidChance = null;
ConVar gCvBadChance = null;

ConVar gCvMaxGoodBoxes = null;
ConVar gCvMaxMidBoxes = null;
ConVar gCvMaxBadBoxes = null;

ConVar gCvEndRoundStats = null;

bool gEnabled = true;

float gNoneChance = 0.10;
float gGoodChance = 0.15;
float gMidChance = 0.50;
float gBadChance = 0.25;

int gMaxGoodBoxes = -1;
int gMaxMidBoxes = -1;
int gMaxBadBoxes = -1;

bool gEndRoundStats = true;

GlobalForward gGfBoxOpened;

ArrayList gBoxes;

public APLRes AskPluginLoad2(Handle hdl, bool late, char[] err, int errMax) {
    RegPluginLibrary("l4d2pb");

    // Natives.
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

    gCvNoneChance = CreateConVar("l4d2pb_chance_none", "0.10", "The chances of getting no fun boxes when opened.", _, true, 0.0, true, 1.0);
    HookConVarChange(gCvNoneChance, CVar_Changed);

    gCvGoodChance = CreateConVar("l4d2pb_chance_good", "0.15", "The chances of a good box being opened.", _, true, 0.0, true, 1.0);
    HookConVarChange(gCvGoodChance, CVar_Changed);

    gCvMidChance = CreateConVar("l4d2pb_chance_mid", "0.50", "The chances of a mid box being opened.", _, true, 0.0, true, 1.0);
    HookConVarChange(gCvMidChance, CVar_Changed);

    gCvBadChance = CreateConVar("l4d2pb_chance_bad", "0.25", "The chances of a bad box being opened.", _, true, 0.0, true, 1.0);
    HookConVarChange(gCvBadChance, CVar_Changed);

    gCvMaxGoodBoxes = CreateConVar("l4d2pb_max_good_boxes", "-1", "The maximum amount of good boxes that can be opened per round. 0 = disables good boxes. -1 = no limit.");
    HookConVarChange(gCvMaxGoodBoxes, CVar_Changed);

    gCvMaxMidBoxes = CreateConVar("l4d2pb_max_mid_boxes", "-1", "The maximum amount of mid boxes that can be opened per round. 0 = disables mid boxes. -1 = no limit.");
    HookConVarChange(gCvMaxMidBoxes, CVar_Changed);

    gCvMaxBadBoxes = CreateConVar("l4d2_max_bad_boxes", "-1", "The maximum amount of bad boxes that can be opened per round. 0 = disables bad boxes. -1 = no limit.");
    HookConVarChange(gCvMaxBadBoxes, CVar_Changed);

    gCvEndRoundStats = CreateConVar("l4d2pb_end_round_stats", "1", "Whether to display stats in chat on round end.", _, true, 0.0, true, 1.0);
    HookConVarChange(gCvEndRoundStats, CVar_Changed);

    // Forwards.
    gGfBoxOpened = new GlobalForward("BoxOpened", ET_Ignore, Param_Cell, Param_String);

    // Events.
    HookEvent("upgrade_pack_used", Event_UpgradePackUsed);
    
    // Load translactions file.
    LoadTranslations("l4d2pb.phrases.txt");

    // Execute SourceMod config.
    AutoExecConfig(true, "plugin.l4d2pb");

    gBoxes = new ArrayList(sizeof(Box));
}

public void OnConfigsExecuted() {
    gEnabled = GetConVarBool(gCvEnabled);
    
    gNoneChance = GetConVarFloat(gCvNoneChance);
    gGoodChance = GetConVarFloat(gCvGoodChance);
    gMidChance = GetConVarFloat(gCvMidChance);
    gBadChance = GetConVarFloat(gCvBadChance);

    gMaxGoodBoxes = GetConVarInt(gCvMaxGoodBoxes);
    gMaxMidBoxes = GetConVarInt(gCvMaxMidBoxes);
    gMaxBadBoxes = GetConVarInt(gCvMaxBadBoxes);

    gEndRoundStats = GetConVarBool(gCvEndRoundStats);
}

public void CVar_Changed(ConVar cv, const char[] oldV, const char[] newV) {
    OnConfigsExecuted();
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
        switch (i) {
            case view_as<int>(BOXTYPE_NONE):
                prob += gNoneChance;

            case view_as<int>(BOXTYPE_GOOD):
                prob += gGoodChance;

            case view_as<int>(BOXTYPE_MID):
                prob += gMidChance;

            case view_as<int>(BOXTYPE_BAD):
                prob += gBadChance;
        }

        if (randVal <= prob)
            return view_as<BoxType>(i);
    }

    return BOXTYPE_NONE;
}

stock Box PickRandomBox(BoxType type) {
    ArrayList boxes = new ArrayList();

    for (int i = 0; i < gBoxes.Length; i++) {
        Box cur;

        gBoxes.GetArray(i, cur);

        PrintToChatAll("Checking box at index %d (%d == %d)", i, view_as<int>(cur.type), view_as<int>(type));

        if (cur.type == type)
            boxes.PushArray(cur);
    }

    // Choose random box.
    int idx = GetRandomInt(0, boxes.Length - 1);

    Box ret;

    boxes.GetArray(idx, ret);

    return ret;
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
        PrintToChatAll("No boxes found! (%d)", gBoxes.Length);

        return Plugin_Continue;
    }

    // Get random type.
    BoxType randType = PickRandomBoxType();

    PrintToChatAll("PICKED RANDOM TYPE %d.", view_as<int>(randType));

    if (randType == BOXTYPE_NONE)
        return Plugin_Continue;

    // Select random box from type.
    Box randBox;
    
    randBox = PickRandomBox(randType);

    PrintToChatAll("PICKED RANDOM BOX: %s", randBox.name);

    // Call box opened forward.
    Call_StartForward(gGfBoxOpened);

    Call_PushCell(randBox.type);
    Call_PushString(randBox.name);

    Call_Finish();

    // To Do: Print to chat, keep track of client, etc.

    return Plugin_Handled;
}

public int Native_RegisterBox(Handle pl, int paramsCnt) {
    int type = GetNativeCell(1);

    int nameLen;
    GetNativeStringLength(2, nameLen);

    if (nameLen <= 0)
        return 1;
        
    char[] name = new char[nameLen + 1];
    GetNativeString(2, name, nameLen + 1);

    // Create box.
    Box newBox;

    strcopy(newBox.name, sizeof(newBox.name), name);
    newBox.type = view_as<BoxType>(type);

    // Remove dups.
    BoxRemoveDups(name);

    // Add box to string map.
    int idx = gBoxes.PushArray(newBox);

    PrintToChatAll("%t Registing box %s (index %d)! Type => %d", "Tag", newBox.name, idx, view_as<int>(newBox.type));

    return 0;
}

public int Native_UnloadBox(Handle pl, int paramsCnt) {
    int type = GetNativeCell(1);

    int nameLen;
    GetNativeStringLength(2, nameLen);

    if (nameLen <= 0)
        return 1;
        
    char[] name = new char[nameLen + 1];
    GetNativeString(2, name, nameLen + 1);

    // Get index.
    int idx = BoxGetIdx(name);

    if (idx != -1)
        gBoxes.Erase(idx);

    return 0;
}