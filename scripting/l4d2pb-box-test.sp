#include <sourcemod>

#include <l4d2pb-core>

#define PL_VERSION "1.0.0"

#define BOX_NAME "test"
#define BOX_DISPLAY "Test"

public Plugin myinfo = {
    name = "L4D2 Party Boxes - Box - Test",
    author = "Christian Deacon (Gamemann)",
    description = "A test box for L4D2-PB.",
    version = PL_VERSION,
    url = "ModdingCommunity.com"
};

ConVar gCvEnabled = null;

bool gEnabled = false;
bool gCoreEnabled = false;

bool gLoaded = false;

public APLRes AskPluginLoad2(Handle hdl, bool late, char[] err, int errMax) {
    RegPluginLibrary("l4d2pb-box-test");

    return APLRes_Success;
}

public void OnLibraryAdded(const char[] name) {
	if (StrEqual(name, "l4d2pb"))
        gCoreEnabled = true;
}

public void OnPluginStart() {
    gCvEnabled = CreateConVar("l4d2pb_box_test_enabled", "0", "Enables the test box", _, true, 0.0, true, 1.0);
    HookConVarChange(gCvEnabled, CVar_Changed);

    LoadTranslations("l4d2pb.phrases.txt");
    LoadTranslations("l4d2pb-box-test.phrases.txt");

    AutoExecConfig(true, "plugin.l4d2pb-box-test");
}

stock LoadBox() {
    if (gCoreEnabled) {
        if (!gEnabled && gLoaded) {
            L4D2PB_DebugMsg(2, "Found test box loaded, but not enabled. Unloading now!");

            L4D2PB_UnloadBox(BOX_NAME);

            gLoaded = false;
        } else if (gEnabled && !gLoaded) {
            L4D2PB_DebugMsg(2, "Loading test box!");

            L4D2PB_RegisterBox(BOXTYPE_MID, BOX_NAME, BOX_DISPLAY);

            gLoaded = true;
        }
    }
}

stock SetCVars() {
    gEnabled = GetConVarBool(gCvEnabled);

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

public void Activate() {
    PrintToChatAll("%t %t", "Tag", "Activated");
}

public void L4D2PB_OnBoxOpened(int type, const char[] boxName, int userId) {
    L4D2PB_DebugMsg(4, "Got BoxOpened() event! Box name => %s. Box opener => %N", boxName, GetClientOfUserId(userId));

    if (strcmp(boxName, BOX_NAME, false) == 0)
        Activate();
}
