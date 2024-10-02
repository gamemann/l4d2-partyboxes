#include <sourcemod>
#include <sdktools>

#include <l4d2pb-core>

#define PL_VERSION "1.0.0"

#define BOX_NAME "vomit"
#define BOX_DISPLAY "Vomit"

#define GAMEDATA "l4d2pb-box-vomit"

public Plugin myinfo = {
    name = "L4D2 Party Boxes - Box - Vomit",
    author = "Christian Deacon (Gamemann)",
    description = "A vomit box for L4D2-PB.",
    version = PL_VERSION,
    url = "ModdingCommunity.com"
};

// ConVars
ConVar gCvEnabled = null;

ConVar gCvAnnounce = null;

ConVar gCvVomitSound = null;

ConVar gCvRadiusMin = null;
ConVar gCvRadiusMax = null;

// ConVar values
bool gEnabled;

bool gAnnounce;

char gVomitSound[PLATFORM_MAX_PATH];

float gRadiusMin;
float gRadiusMax;

// Other global variables
bool gCoreEnabled = false;
bool gLoaded = false;

Handle gGameData = null;

Handle gVomitUpon = null;

public APLRes AskPluginLoad2(Handle hdl, bool late, char[] err, int errMax) {
    RegPluginLibrary("l4d2pb-box-vomit");

    return APLRes_Success;
}

public void OnLibraryAdded(const char[] name) {
	if (StrEqual(name, "l4d2pb"))
        gCoreEnabled = true;
}

public void OnPluginStart() {
    // Load gamedata.
    char gdPath[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, gdPath, sizeof(gdPath), "gamedata/%s.txt", GAMEDATA);

    if(!FileExists(gdPath))
        SetFailState("Failed to load gamedata file '%s' for L4D2PB-Box-Vomit :: File doesn't exist.", gdPath);

    gGameData = LoadGameConfigFile(GAMEDATA);

    if (gGameData == null)
        SetFailState("Failed to load gamedata file '%s' for L4D2PB-Box-Vomit :: LoadGameConfigFile() failed.");

    // Load OnVomitedUpon function.
    StartPrepSDKCall(SDKCall_Player);

    PrepSDKCall_SetFromConf(gGameData, SDKConf_Signature, "CTerrorPlayer_OnVomitedUpon");

    PrepSDKCall_AddParameter(SDKType_CBasePlayer, SDKPass_Pointer);
    PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);

    gVomitUpon = EndPrepSDKCall();

    if(gVomitUpon == null)
        SetFailState("Failed to load 'CTerrorPlayer_OnVomitedUpon' signature for L4D2PB-Box-Vomit");

    // Create convars.
    gCvEnabled = CreateConVar("l4d2pb_box_vomit_enabled", "1", "Enables the vomit box", _, true, 0.0, true, 1.0);
    HookConVarChange(gCvEnabled, CVar_Changed);

    gCvAnnounce = CreateConVar("l4d2pb_box_vomit_announce", "1", "Announces to players affected by vomit.", _, true, 0.0, true, 1.0);
    HookConVarChange(gCvAnnounce, CVar_Changed);

    gCvVomitSound = CreateConVar("l4d2pb_box_vomit_vomit_sound", "", "If non-empty, will play this sound file when a player is vomited on (treated as a path).");
    HookConVarChange(gCvVomitSound, CVar_Changed);

    gCvRadiusMin = CreateConVar("l4d2pb_box_vomit_radius_min", "200", "The minimum radius to vomit players in.", _, true, 0.0);
    HookConVarChange(gCvRadiusMin, CVar_Changed);

    gCvRadiusMax = CreateConVar("l4d2pb_box_vomit_radius_max", "500", "The maximum radius to vomit players in. 0 = Disables other players being impacted.", _, true, 0.0);
    HookConVarChange(gCvRadiusMax, CVar_Changed);

    CreateConVar("l4d2pb_box_vomit_version", PL_VERSION, "The vomit box's version.");

    // Load translations.
    LoadTranslations("l4d2pb.phrases.txt");
    LoadTranslations("l4d2pb-box-vomit.phrases.txt");

    // Create config.
    AutoExecConfig(true, "plugin.l4d2pb-box-vomit");
}

stock LoadBox() {
    if (gCoreEnabled) {
        if (!gEnabled && gLoaded) {
            L4D2PB_DebugMsg(2, "Found vomit box loaded, but not enabled. Unloading now!");

            L4D2PB_UnloadBox(BOX_NAME);

            gLoaded = false;
        } else if (gEnabled && !gLoaded) {
            L4D2PB_DebugMsg(2, "Loading vomit box!");

            L4D2PB_RegisterBox(BOXTYPE_BAD, BOX_NAME, BOX_DISPLAY);

            gLoaded = true;
        }
    }
}

stock SetCVars() {
    gEnabled = GetConVarBool(gCvEnabled);

    gAnnounce = GetConVarBool(gCvAnnounce);

    GetConVarString(gCvVomitSound, gVomitSound, sizeof(gVomitSound));

    gRadiusMin = GetConVarFloat(gCvRadiusMin);
    gRadiusMax = GetConVarFloat(gCvRadiusMax);

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

stock void VomitPlayer (int client, int user) {
    if (GetClientTeam(client) != 2 || !IsPlayerAlive(client))
        return;
    
    SDKCall(gVomitUpon, client, user, false);

    // Play sound if configured.
    if (strlen(gVomitSound) > 0)
        EmitSoundToClient(client, gVomitSound);
}

stock void Activate(int userId) {
    // Get client index.
    int client = GetClientOfUserId(userId);

    // Get random radius.
    float radius = GetRandomFloat(gRadiusMin, gRadiusMax);

    // Vomit user.
    VomitPlayer(client, client);

    // Check radius.
    if (radius > 0.0) {
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

            // Vomit on player if within radius.
            if (distSq <= radiusSq)
                VomitPlayer(i, client);
        }
    }
}

public void L4D2PB_OnBoxOpened(int type, const char[] boxName, int userId) {
    if (strcmp(boxName, BOX_NAME, false) == 0)
        Activate(userId);
}
