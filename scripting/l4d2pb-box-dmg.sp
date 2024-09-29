#include <sourcemod>
#include <sdkhooks>

#include <l4d2pb-core>

#define PL_VERSION "1.0.0"

#define BOX_NAME "damage"
#define BOX_DISPLAY "Damage"

public Plugin myinfo = {
    name = "L4D2 Party Boxes - Box - Damage",
    author = "Christian Deacon (Gamemann)",
    description = "A damage box for L4D2-PB.",
    version = PL_VERSION,
    url = "ModdingCommunity.com"
};

bool gCoreEnabled = false;
bool gLoaded = false;

ConVar gCvEnabled = null;

ConVar gCvRadiusMin = null;
ConVar gCvRadiusMax = null;

ConVar gCvDmgMin = null;
ConVar gCvDmgMax = null;

bool gEnabled = true;

float gRadiusMin = 200.0;
float gRadiusMax = 500.0;

float gDmgMin = 5.0;
float gDmgMax = 100.0;

public void OnLibraryAdded(const char[] name) {
	if (StrEqual(name, "l4d2pb"))
        gCoreEnabled = true;
}

public void OnPluginStart() {
    gCvEnabled = CreateConVar("l4d2pb_box_dmg_enabled", "1", "Enables the damage box", _, true, 0.0, true, 1.0);
    HookConVarChange(gCvEnabled, CVar_Changed);

    gCvRadiusMin = CreateConVar("l4d2pb_box_dmg_radius_min", "200.0", "The mimimum radius to damage survivors in.", _, true, 0.0);
    HookConVarChange(gCvRadiusMin, CVar_Changed);

    gCvRadiusMax = CreateConVar("l4d2pb_box_dmg_radius_max", "500.0", "The maximum radius to damage survivors in. 0 = disables damaging others.", _, true, 0.0);
    HookConVarChange(gCvRadiusMax, CVar_Changed);

    gCvDmgMin = CreateConVar("l4d2pb_box_dmg_min", "5.0", "The minimum damage to apply.", _, true, 1.0);
    HookConVarChange(gCvDmgMin, CVar_Changed);

    gCvDmgMax = CreateConVar("l4d2pb_box_dmg_max", "100.0", "The maximum damage to apply.", _, true, 1.0);
    HookConVarChange(gCvDmgMax, CVar_Changed);

    LoadTranslations("l4d2pb.phrases.txt");
    LoadTranslations("l4d2pb-box-dmg.phrases.txt");

    AutoExecConfig(true, "plugin.l4d2pb-box-dmg");
}

public void OnConfigsExecuted() {
    gEnabled = GetConVarBool(gCvEnabled);

    gRadiusMin = GetConVarFloat(gCvRadiusMin);
    gRadiusMax = GetConVarFloat(gCvRadiusMax);

    gDmgMin = GetConVarFloat(gCvDmgMin);
    gDmgMax = GetConVarFloat(gCvDmgMax);

    if (gCoreEnabled) {
        if (!gLoaded && gEnabled) {
            RegisterBox(BOXTYPE_BAD, BOX_NAME, BOX_DISPLAY);

            DebugMsg(2, "Found damage box not loaded. Loading now!");

            gLoaded = true;
        } else if (gLoaded && !gEnabled) {
            DebugMsg(1, "Found damage box loaded, but not enabled. Unloading now!");

            UnloadBox(BOX_NAME);

            gLoaded = false;
        }
    } else
        PrintToServer("%t Warning => L4D2-PB core not loaded!");
}

public void CVar_Changed(Handle cv, const char[] oldV, const char[] newV) {
    OnConfigsExecuted();
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
        DebugMsg(3, "Using damage radius %f", radius);

        // Get radius squared.
        float radiusSq = radius * radius;

        // Get user position.
        float tPos[3];
        GetClientAbsOrigin(client, tPos);

        DebugMsg(4, "Using target user position for damage: %f, %f, %f", tPos[0], tPos[1], tPos[2]);

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

            DebugMsg(5, "Checking against target position for damage: %f %f %f (%f <= %f)", pos[0], pos[1], pos[2], distSq, radiusSq);
            
            // Check if user is within radius.
            if (distSq <= radiusSq) {
                // Randomize damage again.
                dmg = GetRandomFloat(gDmgMin, gDmgMax);

                SDKHooks_TakeDamage(i, client, client, dmg, DMG_BULLET, -1, NULL_VECTOR, NULL_VECTOR, false);
            }
        }
    }
}

public void BoxOpened(int type, const char[] boxName, int userId) {
    if (strcmp(boxName, BOX_NAME, false) == 0)
        Activate(userId);
}