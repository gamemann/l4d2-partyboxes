#include <sourcemod>
#include <sdkhooks>

#include <l4d2pb-core>

#define PL_VERSION "1.0.0"

#define BOX_NAME "damage"
#define BOX_DISPLAY "Damage"

#define DEFAULT_DAMAGE_IDX -1

public Plugin myinfo = {
    name = "L4D2 Party Boxes - Box - Damage",
    author = "Christian Deacon (Gamemann)",
    description = "A damage box for L4D2-PB.",
    version = PL_VERSION,
    url = "ModdingCommunity.com"
};

// ConVars
ConVar gCvEnabled = null;

ConVar gCvAnnounce = null;

ConVar gCvRadiusMin = null;
ConVar gCvRadiusMax = null;

ConVar gCvDmgMin = null;
ConVar gCvDmgMax = null;
ConVar gCvDmgRandPerPlayer = null;

ConVar gCvBypassOnTakeDamage = null;

ConVar gCvUseUserAsInflictor = null;
ConVar gCvUseUserAsAttacker = null;
ConVar gCvUseUserPos = null;

// ConVar values
bool gEnabled;

bool gAnnounce;

float gRadiusMin;
float gRadiusMax;

float gDmgMin;
float gDmgMax;
bool gDmgRandPerPlayer;

bool gBypassOnTakeDamage;

bool gUseUserAsInflictor;
bool gUseUserAsAttacker;
bool gUseUserPos;

// Other global variables
bool gCoreEnabled = false;
bool gLoaded = false;

public APLRes AskPluginLoad2(Handle hdl, bool late, char[] err, int errMax) {
    RegPluginLibrary("l4d2pb-box-dmg");

    return APLRes_Success;
}

public void OnLibraryAdded(const char[] name) {
	if (StrEqual(name, "l4d2pb"))
        gCoreEnabled = true;
}

public void OnPluginStart() {
    gCvEnabled = CreateConVar("l4d2pb_box_dmg_enabled", "1", "Enables the damage box", _, true, 0.0, true, 1.0);
    gCvEnabled.AddChangeHook(CVar_Changed);

    gCvAnnounce = CreateConVar("l4d2pb_box_dmg_announce", "1", "Announces to damaged players who opened the box and the amount it damaged them for.", _, true, 0.0, true, 1.0);
    gCvAnnounce.AddChangeHook(CVar_Changed);

    gCvRadiusMin = CreateConVar("l4d2pb_box_dmg_radius_min", "200.0", "The mimimum radius to damage survivors in.", _, true, 0.0);
    gCvRadiusMin.AddChangeHook(CVar_Changed);

    gCvRadiusMax = CreateConVar("l4d2pb_box_dmg_radius_max", "500.0", "The maximum radius to damage survivors in. 0 = disables damaging others.", _, true, 0.0);
    gCvRadiusMax.AddChangeHook(CVar_Changed);

    gCvDmgMin = CreateConVar("l4d2pb_box_dmg_min", "5.0", "The minimum damage to apply.", _, true, 1.0);
    gCvDmgMin.AddChangeHook(CVar_Changed);

    gCvDmgMax = CreateConVar("l4d2pb_box_dmg_max", "100.0", "The maximum damage to apply.", _, true, 1.0);
    gCvDmgMax.AddChangeHook(CVar_Changed);

    gCvDmgRandPerPlayer = CreateConVar("l4d2pb_box_dmg_rand_per_player", "1", "If 1, when damage is applied, each player affected receives a random damage count.", _, true, 0.0, true, 1.0);
    gCvDmgRandPerPlayer.AddChangeHook(CVar_Changed);

    gCvBypassOnTakeDamage = CreateConVar("l4d2pb_box_dmg_bypass_ontakedamage", "0", "If 1, bypasses the SDKHooks_OnTakeDamage() hook when damaging users.", _, true, 0.0, true, 1.0);
    gCvBypassOnTakeDamage.AddChangeHook(CVar_Changed);

    gCvUseUserAsInflictor = CreateConVar("l4d2pb_box_dmg_use_user_as_inflictor", "1", "If 1, the user who opened the damage box is used as the inflictor when damaging players.", _, true, 0.0, true, 1.0);
    gCvUseUserAsInflictor.AddChangeHook(CVar_Changed);

    gCvUseUserAsAttacker = CreateConVar("l4d2pb_box_dmg_use_user_as_attacker", "1", "If 1, the uesr who opened the damage box is used as the attacker when damaging players.", _, true, 0.0, true, 1.0);
    gCvUseUserAsAttacker.AddChangeHook(CVar_Changed);

    gCvUseUserPos = CreateConVar("l4d2pb_box_dmg_use_user_pos", "0", "If 1, uses the position of who opened the box as the damage position.", _, true, 0.0, true, 1.0);
    gCvUseUserPos.AddChangeHook(CVar_Changed);

    CreateConVar("l4d2pb_box_dmg_version", PL_VERSION, "The damage box's version.");

    LoadTranslations("l4d2pb.phrases.txt");
    LoadTranslations("l4d2pb-box-dmg.phrases.txt");

    AutoExecConfig(true, "plugin.l4d2pb-box-dmg");
}

stock LoadBox() {
    if (gCoreEnabled) {
        if (!gEnabled && gLoaded) {
            L4D2PB_DebugMsg(1, "Found damage box loaded, but not enabled. Unloading now!");

            L4D2PB_UnloadBox(BOX_NAME);

            gLoaded = false;
        } else if (gEnabled && !gLoaded) {
            L4D2PB_RegisterBox(BOXTYPE_BAD, BOX_NAME, BOX_DISPLAY);

            L4D2PB_DebugMsg(2, "Found damage box not loaded. Loading now!");

            gLoaded = true;
        }
    }
}

stock SetCVars() {
    gEnabled = gCvEnabled.BoolValue;

    gAnnounce = gCvAnnounce.BoolValue;

    gRadiusMin = gCvRadiusMin.FloatValue;
    gRadiusMax = gCvRadiusMax.FloatValue;

    gDmgMin = gCvDmgMin.FloatValue;
    gDmgMax = gCvDmgMax.FloatValue;
    gDmgRandPerPlayer = gCvDmgRandPerPlayer.BoolValue;

    gBypassOnTakeDamage = gCvBypassOnTakeDamage.BoolValue;

    gUseUserAsInflictor = gCvUseUserAsInflictor.BoolValue;
    gUseUserAsAttacker = gCvUseUserAsAttacker.BoolValue;
    gUseUserPos = gCvUseUserPos.BoolValue;

    LoadBox();
}

public void OnConfigsExecuted() {
    // Set ConVars.
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

stock void Activate(int userId) {
    // Get client index.
    int client = GetClientOfUserId(userId);

    // Get random radius.
    float radius = GetRandomFloat(gRadiusMin, gRadiusMax);

    // Get random damage.
    float dmg = GetRandomFloat(gDmgMin, gDmgMax);

    // Apply damage to current player.
    if (IsClientInGame(client) && IsPlayerAlive(client))
        SDKHooks_TakeDamage(client, client, client, dmg, DMG_BULLET, -1, NULL_VECTOR, NULL_VECTOR, false);

    // Check if we need to damage others.
    if (radius > 0.0) {
        L4D2PB_DebugMsg(3, "Using damage radius %f", radius);

        // Get user name.
        char userName[MAX_NAME_LENGTH];

        if (gAnnounce)
            GetClientName(client, userName, sizeof(userName));

        // Get inflictor and attacker.
        int inflictor = DEFAULT_DAMAGE_IDX;

        if (gUseUserAsInflictor)
            inflictor = client;

        int attacker = DEFAULT_DAMAGE_IDX;

        if (gUseUserAsAttacker)
            attacker = client;

        // Get radius squared.
        float radiusSq = radius * radius;

        // Get user position.
        float tPos[3];
        GetClientAbsOrigin(client, tPos);

        L4D2PB_DebugMsg(4, "Using target user position for damage: %f, %f, %f", tPos[0], tPos[1], tPos[2]);

        for (int i = 1; i < MaxClients; i++) {
            if (i == client || !IsClientInGame(i) || !IsPlayerAlive(i))
                continue;

            // Check if we're in specify radius.
            float pos[3];
            GetClientAbsOrigin(i, pos);

            // Calculate position.
            float dx = pos[0] - tPos[0];
            float dy = pos[1] - tPos[1];
            float dz = pos[2] - tPos[2];

            float distSq = dx * dx + dy * dy + dz * dz;

            L4D2PB_DebugMsg(5, "Checking against target position for damage: %f %f %f (%f <= %f)", pos[0], pos[1], pos[2], distSq, radiusSq);
            
            // Check if user is within radius.
            if (distSq <= radiusSq) {
                // Randomize damage again if enabled.
                if (gDmgRandPerPlayer)
                    dmg = GetRandomFloat(gDmgMin, gDmgMax);

                SDKHooks_TakeDamage(i, inflictor, attacker, dmg, DMG_BULLET, -1, NULL_VECTOR, gUseUserPos ? tPos : NULL_VECTOR, gBypassOnTakeDamage);

                // Check for announce.
                if (gAnnounce)
                    L4D2PB_PrintToChat(i, "%t %t", "Tag", "DamageAnnounce", userName, dmg);
            }
        }
    }
}

public void L4D2PB_OnBoxOpened(int type, const char[] boxName, int userId) {
    if (strcmp(boxName, BOX_NAME, false) == 0)
        Activate(userId);
}