#include <sourcemod>
#include <sdktools>

#include <l4d2pb-core>

#define PL_VERSION "1.0.0"

#define BOX_NAME "freeze"
#define BOX_DISPLAY "Freeze"

#define RGBA_LEN 32

public Plugin myinfo = {
    name = "L4D2 Party Boxes - Box - Freeze",
    author = "Christian Deacon (Gamemann)",
    description = "A freeze box for L4D2-PB.",
    version = PL_VERSION,
    url = "ModdingCommunity.com"
};

// ConVars
ConVar gCvEnabled = null;
ConVar gCvWeight = null;

ConVar gCvAnnounce = null;

ConVar gCvFreezeSound = null;
ConVar gCvUnfreezeSound = null;

ConVar gCvRadiusMin = null;
ConVar gCvRadiusMax = null;

ConVar gCvTimeMin = null;
ConVar gCvTimeMax = null;

ConVar gCvTimeRandPerPlayer = null;

ConVar gCvFreezeRgba = null;
ConVar gCvUnfreezeRgba = null;

// ConVar values
bool gEnabled;
float gWeight;

bool gAnnounce;

char gFreezeSound[PLATFORM_MAX_PATH];
char gUnfreezeSound[PLATFORM_MAX_PATH];

float gRadiusMin;
float gRadiusMax;

float gTimeMin;
float gTimeMax;

bool gTimeRandPerPlayer;

char gFreezeRgba[RGBA_LEN];
char gUnfreezeRgba[RGBA_LEN];

// Forwards
GlobalForward gGfUnfrozen;

// Other global variables
bool gCoreEnabled = false;
bool gLoaded = false;

public APLRes AskPluginLoad2(Handle hdl, bool late, char[] err, int errMax) {
    RegPluginLibrary("l4d2pb-box-freeze");

    return APLRes_Success;
}

public void OnLibraryAdded(const char[] name) {
	if (StrEqual(name, "l4d2pb"))
        gCoreEnabled = true;
}

public void OnPluginStart() {
    gCvEnabled = CreateConVar("l4d2pb_box_freeze_enabled", "1", "Enables the freeze box", _, true, 0.0, true, 1.0);
    gCvEnabled.AddChangeHook(CVar_Changed);

    gCvWeight = CreateConVar("l4d2pb_box_freeze_weight", "50.0", "The box's weight when being picked.");
    gCvWeight.AddChangeHook(CVar_Changed);

    gCvAnnounce = CreateConVar("l4d2pb_box_freeze_announce", "1", "Announces to players affected by freeze.", _, true, 0.0, true, 1.0);
    gCvAnnounce.AddChangeHook(CVar_Changed);

    gCvFreezeSound = CreateConVar("l4d2pb_box_freeze_freeze_sound", "physics/glass/glass_impact_bullet1.wav", "If non-empty, will play this sound file when a player is frozen (treated as a path).");
    gCvFreezeSound.AddChangeHook(CVar_Changed);

    gCvUnfreezeSound = CreateConVar("l4d2pb_box_freeze_unfreeze_sound", "physics/glass/glass_largesheet_break1.wav", "If non-empty, will play this sound file when a player is unfrozen (treated as a path).");
    gCvUnfreezeSound.AddChangeHook(CVar_Changed);

    gCvRadiusMin = CreateConVar("l4d2pb_box_freeze_radius_min", "200", "The minimum radius to freeze players in.", _, true, 0.0);
    gCvRadiusMin.AddChangeHook(CVar_Changed);

    gCvRadiusMax = CreateConVar("l4d2pb_box_freeze_radius_max", "500", "The maximum radius to freeze players in. 0 = Disables other players being impacted.", _, true, 0.0);
    gCvRadiusMax.AddChangeHook(CVar_Changed);

    gCvTimeMin = CreateConVar("l4d2pb_box_freeze_time_min", "3.0", "The minimum amount of time in seconds to freeze players for.", _, true, 0.0);
    gCvTimeMin.AddChangeHook(CVar_Changed);

    gCvTimeMax = CreateConVar("l4d2pb_box_freeze_time_max", "15.0", "The maximum amount of time in seconds to freezep layers for.", _, true, 0.0);
    gCvTimeMax.AddChangeHook(CVar_Changed);

    gCvTimeRandPerPlayer = CreateConVar("l4d2pb_box_freeze_time_rand_per_player", "0.0", "Whether to pick a random freeze time for each person affected.", _, true, 0.0, true, 1.0);
    gCvTimeRandPerPlayer.AddChangeHook(CVar_Changed);

    gCvFreezeRgba = CreateConVar("l4d2pb_box_freeze_rgba", "0 0 0 174", "The RGBA color to set the player when frozen (red green blue alpha).");
    gCvFreezeRgba.AddChangeHook(CVar_Changed);

    gCvUnfreezeRgba = CreateConVar("l4d2pb_box_freeze_unfreeze_rgba", "255 255 255 255", "The RGBA color to set the player when frozen (red green blue alpha)");
    gCvUnfreezeRgba.AddChangeHook(CVar_Changed);

    CreateConVar("l4d2pb_box_freeze_version", PL_VERSION, "The freeze box's version.");

    // Load translations.
    LoadTranslations("l4d2pb.phrases.txt");
    LoadTranslations("l4d2pb-box-freeze.phrases.txt");

    // Forwards.
    gGfUnfrozen = new GlobalForward("L4D2PB_Freeze_OnUnfrozen", ET_Ignore, Param_Cell);

    // Create config.
    AutoExecConfig(true, "plugin.l4d2pb-box-freeze");
}

stock LoadBox() {
    if (gCoreEnabled) {
        if (!gEnabled && gLoaded) {
            L4D2PB_DebugMsg(2, "Found freeze box loaded, but not enabled. Unloading now!");

            L4D2PB_UnloadBox(BOX_NAME);

            gLoaded = false;
        } else if (gEnabled && !gLoaded) {
            L4D2PB_DebugMsg(2, "Loading freeze box!");

            L4D2PB_RegisterBox(BOXTYPE_BAD, BOX_NAME, BOX_DISPLAY, gWeight);

            gLoaded = true;
        }
    }
}

stock SetCVars() {
    gEnabled = gCvEnabled.BoolValue;
    gWeight = gCvWeight.FloatValue;

    gAnnounce = gCvAnnounce.BoolValue;

    gCvFreezeSound.GetString(gFreezeSound, sizeof(gFreezeSound));
    gCvUnfreezeSound.GetString(gUnfreezeSound, sizeof(gUnfreezeSound));

    gRadiusMin = gCvRadiusMin.FloatValue;
    gRadiusMax = gCvRadiusMax.FloatValue;

    gTimeMin = gCvTimeMin.FloatValue;
    gTimeMax = gCvTimeMax.FloatValue;
    gTimeRandPerPlayer = gCvTimeRandPerPlayer.BoolValue;

    gCvFreezeRgba.GetString(gFreezeRgba, sizeof(gFreezeRgba));
    gCvUnfreezeRgba.GetString(gUnfreezeRgba, sizeof(gUnfreezeRgba));

    LoadBox();
}

public void OnConfigsExecuted() {
    SetCVars();
}

public void L4D2PB_OnCoreCfgsLoaded() {
    if (!gCoreEnabled)
        gCoreEnabled = true;
    
    // Load box.
    LoadBox();
}

public void L4D2PB_OnCoreUnloaded() {
    gLoaded = false;
    gCoreEnabled = false;
}

public void CVar_Changed(Handle cv, const char[] oldV, const char[] newV) {
    SetCVars();
}

stock int GetRgbaFromString(const char[] val, int res[4]) {
    char buffer[4][4];

    int explode = ExplodeString(val, " ", buffer, 4, 4);

    // Make sure we have at least one value.
    if (explode < 1)
        return 1;

    // Check for red.
    if (explode >= 1)
        res[0] = StringToInt(buffer[0]);
    
    // Check for green.
    if (explode >= 2)
        res[1] = StringToInt(buffer[1]);

    // Check for blue.
    if (explode >= 3)
        res[2] = StringToInt(buffer[2]);

    // Check for alpha.
    if (explode >= 4)
        res[3] = StringToInt(buffer[3]);
    else
        res[3] = 255;

    return 0;
}

stock void FreezePlayer(int client) {
    SetEntPropFloat(client, Prop_Data, "m_flLaggedMovementValue", 0.0);

    // Set RGBA if configured.
    if (strlen(gFreezeRgba) > 0) {
        int rgba[4];

        if (GetRgbaFromString(gFreezeRgba, rgba) == 0)
            SetEntityRenderColor(client, rgba[0], rgba[1], rgba[2], rgba[3]);
    }

    // Play sound if configured.
    if (strlen(gFreezeSound) > 0)
        EmitSoundToClient(client, gFreezeSound);
}

stock void UnfreezePlayer(int client) {
    SetEntPropFloat(client, Prop_Data, "m_flLaggedMovementValue", 1.0);

    // Set RGBA if configured.
    if (strlen(gUnfreezeRgba) > 0) {
        int rgba[4];

        if (GetRgbaFromString(gUnfreezeRgba, rgba) == 0)
            SetEntityRenderColor(client, rgba[0], rgba[1], rgba[2], rgba[3]);
    }

    // Play sound if configured.
    if (strlen(gUnfreezeSound) > 0)
        EmitSoundToClient(client, gUnfreezeSound);
}

public Action Timer_UnfreezePlayer(Handle timer, int userId) {
    int client = GetClientOfUserId(userId);

    if (!IsClientInGame(client))
        return Plugin_Stop;

    UnfreezePlayer(client);

    // Call L4D2PB_Freeze_Unfrozen() forward.
    Call_StartForward(gGfUnfrozen);
    Call_PushCell(userId);
    Call_Finish();

    return Plugin_Stop;
}

stock void Activate(int userId) {
    // Get client index.
    int client = GetClientOfUserId(userId);

    // Get random radius.
    float radius = GetRandomFloat(gRadiusMin, gRadiusMax);

    // Get random freeze time.
    float fTime = GetRandomFloat(gTimeMin, gTimeMax);

    // Freeze user.
    FreezePlayer(client);

    // Create timer to unfreeze player.
    CreateTimer(fTime, Timer_UnfreezePlayer, userId);

    // Check radius.
    if (radius > 0.0) {
        // Get user name.
        char userName[MAX_NAME_LENGTH];

        if (gAnnounce)
            GetClientName(client, userName, sizeof(userName));

        // Get radius squared.
        float radiusSq = radius * radius;

        // Get user position.
        float tPos[3];
        GetClientAbsOrigin(client, tPos);

        for (int i = 1; i <= MaxClients; i++) {
            if (i == client || !IsClientInGame(i) || !IsPlayerAlive(i))
                continue;

            // Get client position.
            float pos[3];
            GetClientAbsOrigin(i, pos);

            // Calculate position.
            float dx = pos[0] - tPos[0];
            float dy = pos[1] - tPos[1];
            float dz = pos[2] - tPos[2];

            float distSq = dx * dx + dy * dy + dz * dz;

            if (distSq <= radiusSq) {
                // Get a new random time if needed.
                if (gTimeRandPerPlayer)
                    fTime = GetRandomFloat(gTimeMin, gTimeMax);

                // Freeze client.
                FreezePlayer(i);

                // Create timer that unfreezes player.
                CreateTimer(fTime, Timer_UnfreezePlayer, GetClientUserId(i));

                // Announce.
                if (gAnnounce)
                    L4D2PB_PrintToChat(i, "%t", "FreezeAnnounce", userName, view_as<int>(fTime));
            }
        }
    }
}

public void L4D2PB_OnBoxOpened(int type, const char[] boxName, int userId) {
    if (strcmp(boxName, BOX_NAME, false) == 0)
        Activate(userId);
}
