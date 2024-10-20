#include <sourcemod>
#include <sdktools>

#include <l4d2pb-core>

#define PL_VERSION "1.0.0"

#define BOX_NAME "acid"
#define BOX_DISPLAY "Acid"

#define GAMEDATA "l4d2pb-box-acid"

public Plugin myinfo = {
    name = "L4D2 Party Boxes - Box - Acid",
    author = "Christian Deacon (Gamemann)",
    description = "An acid box for L4D2-PB.",
    version = PL_VERSION,
    url = "ModdingCommunity.com"
};

// ConVars
ConVar gCvEnabled = null;
ConVar gCvWeight = null;

ConVar gCvAng = null;
ConVar gCvVel = null;
ConVar gCvRot = null;

/*
ConVar gCvRadiusMin = null;
ConVar gCvRadiusMax = null;

ConVar gCvTimeMin = null;
ConVar gCvTimeMax = null;
*/

// ConVar values
bool gEnabled;
float gWeight;

char gAng[24];
char gVel[24];
char gRot[24];

/*
float gRadiusMin;
float gRadiusMax;

float gTimeMin;
float gTimeMax;
*/

// Other global variables
bool gCoreEnabled = false;
bool gLoaded = false;

Handle gGameData = null;
Handle gSpitterProjectileCreate = null;

public APLRes AskPluginLoad2(Handle hdl, bool late, char[] err, int errMax) {
    RegPluginLibrary("l4d2pb-box-acid");

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

    if (!FileExists(gdPath))
        SetFailState("Failed to load gamedata file '%' for L4d2PB-Box-Acid :: File doesn't exist.", gdPath);

    gGameData = LoadGameConfigFile(GAMEDATA);

    if (gGameData == null)
        SetFailState("Failed to load gamedata file '%s' for L4D2PB-Box-Acid :: LoadGameConfigFile() failed.", gdPath);

    // Load CSpitterProjectile::Create().
    StartPrepSDKCall(SDKCall_Static);

    if (PrepSDKCall_SetFromConf(gGameData, SDKConf_Signature, "CSpitterProjectile::Create") == false)
        SetFailState("Failed to find signature for 'CSpitterProjectile::Create()'.");
    else {
        PrepSDKCall_AddParameter(SDKType_Vector, SDKPass_ByRef);
        PrepSDKCall_AddParameter(SDKType_Vector, SDKPass_ByRef);
        PrepSDKCall_AddParameter(SDKType_Vector, SDKPass_ByRef);
        PrepSDKCall_AddParameter(SDKType_Vector, SDKPass_ByRef);
        PrepSDKCall_AddParameter(SDKType_CBaseEntity, SDKPass_Pointer, VDECODE_FLAG_ALLOWWORLD);
        PrepSDKCall_SetReturnInfo(SDKType_CBaseEntity, SDKPass_Pointer);

        gSpitterProjectileCreate = EndPrepSDKCall();

        if (gSpitterProjectileCreate == null)
            SetFailState("Failed to create SDKCall for 'CSpitterProjectile::Create'.");
    }

    gCvEnabled = CreateConVar("l4d2pb_box_acid_enabled", "1", "Enables the acid box", _, true, 0.0, true, 1.0);
    gCvEnabled.AddChangeHook(CVar_Changed);

    gCvWeight = CreateConVar("l4d2pb_box_acid_weight", "50.0", "The box's weight when being picked.");
    gCvWeight.AddChangeHook(CVar_Changed);

    gCvAng = CreateConVar("l4d2pb_box_acid_ang", "", "If non-empty, sets the angle for the spitter projectile (empty = uses client's angles). Separate each float by a space.");
    gCvAng.AddChangeHook(CVar_Changed);

    gCvVel = CreateConVar("l4d2pb_box_acid_vel", "", "If non-empty, sets the velocity of the spitter projectile (empty = uses angles result). Separate each float by a space.");
    gCvVel.AddChangeHook(CVar_Changed);

    gCvRot = CreateConVar("l4d2pb_box_acid_rot", "", "If non-empty, sets the rotation of the spitter projectile (empty = uses angles result). Separate each float by a space.");
    gCvRot.AddChangeHook(CVar_Changed);

/*
    gCvRadiusMin = CreateConVar("l4d2pb_box_acid_radius_min", "200", "The minimum radius of the acid.", _, true, 1.0);
    gCvRadiusMin.AddChangeHook(CVar_Changed);

    gCvRadiusMax = CreateConVar("l4d2pb_box_acid_radius_max", "500", "The maximum radius of the acid. 0 = Disables other players being impacted.", _, true, 1.0);
    gCvRadiusMax.AddChangeHook(CVar_Changed);

    gCvTimeMin = CreateConVar("l4d2pb_box_acid_time_min", "3.0", "The minimum amount of time in seconds the acid lasts for.", _, true, 0.0);
    gCvTimeMin.AddChangeHook(CVar_Changed);

    gCvTimeMax = CreateConVar("l4d2pb_box_acid_time_max", "15.0", "The maximum amount of time in seconds the acid lasts for.", _, true, 0.0);
    gCvTimeMax.AddChangeHook(CVar_Changed);
*/

    CreateConVar("l4d2pb_box_acid_version", PL_VERSION, "The acid box's version.");

    // Load translations.
    LoadTranslations("l4d2pb.phrases.txt");

    // Create config.
    AutoExecConfig(true, "plugin.l4d2pb-box-acid");
}

stock LoadBox() {
    if (gCoreEnabled) {
        if (!gEnabled && gLoaded) {
            L4D2PB_DebugMsg(2, "Found acid box loaded, but not enabled. Unloading now!");

            L4D2PB_UnloadBox(BOX_NAME);

            gLoaded = false;
        } else if (gEnabled && !gLoaded) {
            L4D2PB_DebugMsg(2, "Loading acid box!");

            L4D2PB_RegisterBox(BOXTYPE_BAD, BOX_NAME, BOX_DISPLAY, gWeight);

            gLoaded = true;
        }
    }
}

stock SetCVars() {
    gEnabled = gCvEnabled.BoolValue;
    gWeight = gCvWeight.FloatValue;

    gCvAng.GetString(gAng, sizeof(gAng));
    gCvVel.GetString(gVel, sizeof(gVel));
    gCvRot.GetString(gRot, sizeof(gRot));

/*
    gRadiusMin = gCvRadiusMin.FloatValue;
    gRadiusMax = gCvRadiusMax.FloatValue;

    gTimeMin = gCvTimeMin.FloatValue;
    gTimeMax = gCvTimeMax.FloatValue;
*/

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

int GetVectorFromStr(const char[] str, float vec[3]) {
    char buffer[3][24];

    int explode = ExplodeString(str, " ", buffer, 3, 24);

    if (explode < 1)
        return 1;

    if (explode >= 1)
        vec[0] = StringToFloat(buffer[0]);

    if (explode >= 2)
        vec[1] = StringToFloat(buffer[1]);

    if (explode >= 3)
        vec[2] = StringToFloat(buffer[2]);

    return 0;
}

stock void Activate(int userId) {
    // Get client index.
    int client = GetClientOfUserId(userId);

    if (!IsClientInGame(client) || !IsPlayerAlive(client))
        return;

    // Get random radius.
    //float radius = GetRandomFloat(gRadiusMin, gRadiusMax);

    // Get random duration.
    //float duration = GetRandomFloat(gTimeMin, gTimeMax);

    // Get client position.
    float pos[3];
    GetClientAbsOrigin(client, pos);

    float ang[3];
    float vel[3];
    float rot[3];

    if (strlen(gAng) > 0)
        GetVectorFromStr(gAng, ang);
    else
        GetClientAbsAngles(client, ang);

    if (strlen(gVel) > 0)
        GetVectorFromStr(gVel, vel);
    else
        vel = ang;

    if (strlen(gRot) > 0)
        GetVectorFromStr(gRot, rot);
    else
        rot = ang;

    int ent = SDKCall(gSpitterProjectileCreate, pos, ang, vel, rot, client);

    if (ent == -1)
        LogError("Failed to create spitter projectile (entity is -1)");
/*
    else {
        SetEntPropFloat(ent, Prop_Send, "m_DmgRadius", radius);
        float rad = GetEntPropFloat(ent, Prop_Send, "m_DmgRadius");

        PrintToChatAll("Spitter dmg radius => %f", rad);
    }
*/
}

public void L4D2PB_OnBoxOpened(int type, const char[] boxName, int userId) {
    if (strcmp(boxName, BOX_NAME, false) == 0)
        Activate(userId);
}
