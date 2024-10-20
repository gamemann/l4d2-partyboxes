#include <sourcemod>
#include <sdktools>

#include <l4d2pb-core>

#define PL_VERSION "1.0.0"

#define BOX_NAME "heal"
#define BOX_DISPLAY "Heal"

public Plugin myinfo = {
    name = "L4D2 Party Boxes - Box - Heal",
    author = "Christian Deacon (Gamemann)",
    description = "A heal box for L4D2-PB.",
    version = PL_VERSION,
    url = "ModdingCommunity.com"
};

// ConVars
ConVar gCvEnabled = null;
ConVar gCvWeight = null;

ConVar gCvAnnounce = null;

ConVar gCvMaxHp = null;

ConVar gCvRadiusMin = null;
ConVar gCvRadiusMax = null;

ConVar gCvHealsMin = null;
ConVar gCvHealsMax = null;

ConVar gCvHealAmountMin = null;
ConVar gCvHealAmountMax = null;
ConVar gCvHealAmountRandPerPlayer = null;
ConVar gCvHealRevive = null;

ConVar gCvHealIntervalMin = null;
ConVar gCvHealIntervalMax = null;

ConVar gCvHealSound = null;

// ConVar values.
bool gEnabled;
float gWeight;

bool gAnnounce;

int gMaxHp;

float gRadiusMin;
float gRadiusMax;

int gHealsMin;
int gHealsMax;

int gHealAmountMin;
int gHealAmountMax;
bool gHealAmountRandPerPlayer;
bool gHealRevive;

float gHealIntervalMin;
float gHealIntervalMax;

char gHealSound[PLATFORM_MAX_PATH];

// Global variables.
bool gCoreEnabled = false;
bool gLoaded = false;

public APLRes AskPluginLoad2(Handle hdl, bool late, char[] err, int errMax) {
    RegPluginLibrary("l4d2pb-box-heal");

    return APLRes_Success;
}

public void OnLibraryAdded(const char[] name) {
	if (StrEqual(name, "l4d2pb"))
        gCoreEnabled = true;
}

public void OnPluginStart() {
    gCvEnabled = CreateConVar("l4d2pb_box_heal_enabled", "1", "Enables the heal box", _, true, 0.0, true, 1.0);
    gCvEnabled.AddChangeHook(CVar_Changed);

    gCvWeight = CreateConVar("l4d2pb_box_heal_weight", "50.0", "The box's weight when being picked.");
    gCvWeight.AddChangeHook(CVar_Changed);

    gCvAnnounce = CreateConVar("l4d2pb_box_heal_announce", "1", "Whether to announce to players how much HP they've been healed with.", _, true, 0.0, true, 1.0);
    gCvAnnounce.AddChangeHook(CVar_Changed);

    gCvMaxHp = CreateConVar("l4d2pb_box_heal_max_hp", "100", "The maximum HP the user can have.", _, true, 1.0);
    gCvMaxHp.AddChangeHook(CVar_Changed);

    gCvRadiusMin = CreateConVar("l4d2pb_box_heal_radius_min", "100.0", "The minimum radius to heals players in.");
    gCvRadiusMin.AddChangeHook(CVar_Changed);

    gCvRadiusMax = CreateConVar("l4d2pb_box_heal_radius_max", "200.0", "The maximum radius to heal players in.");
    gCvRadiusMax.AddChangeHook(CVar_Changed);

    gCvHealsMin = CreateConVar("l4d2pb_box_heal_heals_min", "1", "The minimum amount of heals to perform.", _, true, 1.0);
    gCvHealsMin.AddChangeHook(CVar_Changed);

    gCvHealsMax = CreateConVar("l4d2pb_box_heal_heals_max", "3", "The maximum amount of heals to perform.", _, true, 1.0);
    gCvHealsMax.AddChangeHook(CVar_Changed);

    gCvHealAmountMin = CreateConVar("l4d2pb_box_heal_heal_amount_min", "5", "The minimum amount of heal amount to add.", _, true, 1.0);
    gCvHealAmountMin.AddChangeHook(CVar_Changed);

    gCvHealAmountMax = CreateConVar("l4d2pb_box_heal_heal_amount_max", "100", "The maximum amount of heal amount to add.", _, true, 1.0);
    gCvHealAmountMax.AddChangeHook(CVar_Changed);

    gCvHealAmountRandPerPlayer = CreateConVar("l4d2pb_box_heal_heal_amount_rand_per_player", "1", "Whether to apply a random amount of health to each player.", _, true, 0.0, true, 1.0);
    gCvHealAmountRandPerPlayer.AddChangeHook(CVar_Changed);

    gCvHealRevive = CreateConVar("l4d2pb_box_heal_heal_revive", "1", "If 1, will revive incapped players and set HP.", _, true, 0.0, true, 1.0);
    gCvHealRevive.AddChangeHook(CVar_Changed);

    gCvHealIntervalMin = CreateConVar("l4d2pb_box_heal_heal_interval_min", "1.0", "The minimum interval between heals.", _, true, 0.0);
    gCvHealIntervalMin.AddChangeHook(CVar_Changed);

    gCvHealIntervalMax = CreateConVar("l4d2pb_box_heal_heal_interval_max", "3.0", "The maximum interval between heals.", _, true, 0.0);
    gCvHealIntervalMax.AddChangeHook(CVar_Changed);

    gCvHealSound = CreateConVar("l4d2pb_box_heal_heal_sound", "items/suitchargeok1.wav", "The sound to play when a player is healed.");
    gCvHealSound.AddChangeHook(CVar_Changed);

    CreateConVar("l4d2pb_box_heal_version", PL_VERSION, "The heal box's version.");

    LoadTranslations("l4d2pb.phrases.txt");
    LoadTranslations("l4d2pb-box-heal.phrases.txt");

    AutoExecConfig(true, "plugin.l4d2pb-box-heal");
}

stock LoadBox() {
    if (gCoreEnabled) {
        if (!gEnabled && gLoaded) {
            L4D2PB_DebugMsg(2, "Found heal box loaded, but not enabled. Unloading now!");

            L4D2PB_UnloadBox(BOX_NAME);

            gLoaded = false;
        } else if (gEnabled && !gLoaded) {
            L4D2PB_DebugMsg(2, "Loading heal box!");

            L4D2PB_RegisterBox(BOXTYPE_GOOD, BOX_NAME, BOX_DISPLAY, gWeight);

            gLoaded = true;
        }
    }
}

stock SetCVars() {
    gEnabled = gCvEnabled.BoolValue;
    gWeight = gCvWeight.FloatValue;

    gAnnounce = gCvAnnounce.BoolValue;

    gMaxHp = gCvMaxHp.IntValue;

    gRadiusMin = gCvRadiusMin.FloatValue;
    gRadiusMax = gCvRadiusMax.FloatValue;

    gHealsMin = gCvHealsMin.IntValue;
    gHealsMax = gCvHealsMax.IntValue;

    gHealAmountMin = gCvHealAmountMin.IntValue;
    gHealAmountMax = gCvHealAmountMax.IntValue;
    gHealAmountRandPerPlayer = gCvHealAmountRandPerPlayer.BoolValue;
    gHealRevive = gCvHealRevive.BoolValue;

    gHealIntervalMin = gCvHealIntervalMin.FloatValue;
    gHealIntervalMax = gCvHealIntervalMax.FloatValue;

    gCvHealSound.GetString(gHealSound, sizeof(gHealSound));

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

bool IsBeingRevived(int client) {
    return GetEntProp(client, Prop_Send, "m_reviveOwner") != 0;
}

bool IsIncapped(int client) {
    return GetEntProp(client, Prop_Send, "m_isIncapacitated") != 0;
}

void ReviveClient(int client, int hp = 50) {
    SetEntProp(client, Prop_Send, "m_isIncapacitated", 0);
    SetEntProp(client, Prop_Send, "m_iHealth", hp);
}

void HealClient(int client, int hp, const char[] userName) {
    // Get current HP.
    int curHp = GetClientHealth(client);
    int totHp = hp;
    int newHp = curHp + totHp;

    if (IsIncapped(client)) {
        // Revive player and set health.
        if (gHealRevive) {
            // Cancel existing revives.
            if (IsBeingRevived(client))
                SetEntProp(client, Prop_Send, "m_reviveOwner", 0);

            ReviveClient(client, hp);
        }
        else
            SetEntityHealth(client, curHp + totHp);
    } else {
        // Make sure we don't exceed max HP.
        if (newHp > gMaxHp) {
            // Get overflow and subtract from total HP.
            int overflow = newHp - gMaxHp;

            totHp = totHp - overflow;
        }

        if (totHp < 1)
            return;

        SetEntityHealth(client, curHp + totHp);
    }

    // Check if we want to play a sound.
    if (strlen(gHealSound) > 0)
        EmitSoundToClient(client, gHealSound);
    
    // Announce.
    if (strlen(userName) > 0 && gAnnounce)
        L4D2PB_PrintToChat(client, "%t%t", "Tag", "ClAnnounce", userName, totHp);
}

void HealAll(int userId, float radius, float interval, int left = 0) {
    // Get box opener index.
    int client = GetClientOfUserId(userId);

    if (!IsClientInGame(client) || !IsPlayerAlive(client))
        return;
    
    // Get opener team.
    int clTeam = GetClientTeam(client);

    // Get HP amount.
    int hp = GetRandomInt(gHealAmountMin, gHealAmountMax);

    // Heal opener.
    HealClient(client, hp, "");

    // Check radius.
    if (radius > 0.0) {
        // Get opener position.
        float tPos[3];
        GetClientAbsOrigin(client, tPos);

        char userName[MAX_NAME_LENGTH];

        if (gAnnounce)
            GetClientName(client, userName, sizeof(userName));

        // Get radius squared.
        float radiusSq = radius * radius;
        
        // Loop through all players,
        for (int i = 1; i <= MaxClients; i++) {
            if (i == client || !IsClientInGame(i) || !IsPlayerAlive(i) || clTeam != GetClientTeam(i))
                continue;

            // Get player position.
            float pos[3];
            GetClientAbsOrigin(i, pos);

            // Calculate position.
            float dx = pos[0] - tPos[0];
            float dy = pos[1] - tPos[1];
            float dz = pos[2] - tPos[2];

            float distSq = dx * dx + dy * dy + dz * dz;

            // Check if we're in the radius.
            if (distSq <= radiusSq) {
                // Check if we should get a random amount.
                if (gHealAmountRandPerPlayer)
                    hp = GetRandomInt(gHealAmountMin, gHealAmountMax);

                // Heal client.
                HealClient(i, hp, userName);
            }
        }
    }

    // Check if we have more heal rounds.
    if (left > 0) {
        // Create data pack.
        DataPack info = CreateDataPack();

        info.WriteCell(userId);
        info.WriteFloat(radius);
        info.WriteFloat(interval);
        info.WriteCell(left - 1);

        // Create a timer.
        CreateTimer(interval, Timer_HealAllTimer, info);
    }
}

public Action Timer_HealAllTimer(Handle hTimer, DataPack info) {
    ResetPack(info);

    // Get information.
    int userId = info.ReadCell();
    float radius = info.ReadFloat();
    float interval = info.ReadFloat();
    int left = info.ReadCell();

    // Close datapack.
    delete info;

    // Heal players.
    HealAll(userId, radius, interval, left);

    return Plugin_Stop;
}

public void Activate(int userId) {
    // Get radius.
    float radius = GetRandomFloat(gRadiusMin, gRadiusMax);

    // Get amount of heals we should perform.
    int heals = GetRandomInt(gHealsMin, gHealsMax);

    // Get random interval.
    float interval = GetRandomFloat(gHealIntervalMin, gHealIntervalMax);

    // Heal all.
    HealAll(userId, radius, interval, heals - 1);
}

public void L4D2PB_OnBoxOpened(int type, const char[] boxName, int userId) {
    if (strcmp(boxName, BOX_NAME, false) == 0)
        Activate(userId);
}
