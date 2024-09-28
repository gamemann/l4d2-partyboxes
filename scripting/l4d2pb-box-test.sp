#include <sourcemod>

#include <l4d2pb-core>

#define PL_VERSION "1.0.0"

#define BOX_NAME "test"

public Plugin myinfo = {
    name = "L4D2 Party Boxes - Box - Test",
    author = "Christian Deacon (Gamemann)",
    description = "A test box for L4D2-PB.",
    version = PL_VERSION,
    url = "ModdingCommunity.com"
};

ConVar gCvEnabled = null;

bool gEnabled = false;

bool gLoaded = false;

public void OnPluginStart() {
    gCvEnabled = CreateConVar("l4d2pb_box_test_enabled", "0", "Enables the test box", _, true, 0.0, true, 1.0);
    HookConVarChange(gCvEnabled, CVar_Changed);

    LoadTranslations("l4d2pb.phrases.txt");
    LoadTranslations("l4d2pb-box-test.phrases.txt");

    AutoExecConfig(true, "plugin.l4d2pb-box-test");
}

public void OnConfigsExecuted() {
    gEnabled = GetConVarBool(gCvEnabled);

    if (!gLoaded && gEnabled) {
        RegisterBox(1, BOX_NAME);

        PrintToChatAll("Found test box not loaded. Loading now!");

        gLoaded = true;
    } else if (gLoaded && !gEnabled) {
        PrintToChatAll("Found test box loaded, but not enabled. Unloading now!");

        UnloadBox(1, BOX_NAME);

        gLoaded = false;
    }
}

public void CVar_Changed(Handle cv, const char[] oldV, const char[] newV) {
    OnConfigsExecuted();
}

public void Activate() {
    PrintToChatAll("%t %t", "Tag", "Activated");
}

public void BoxOpened(int type, const char[] boxName) {
    PrintToChatAll("Got BoxOpened() event! Box name => %s", boxName);

    if (strcmp(boxName, BOX_NAME, false) == 0)
        Activate();
}
