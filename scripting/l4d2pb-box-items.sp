#include <sourcemod>
#include <sdktools>

#include <l4d2pb-core>

#define PL_VERSION "1.0.0"

#define BOX_NAME "items"
#define BOX_DISPLAY "Items"

#define CONF_FILE "l4d2pb-box-items.cfg"

public Plugin myinfo = {
    name = "L4D2 Party Boxes - Box - Items",
    author = "Christian Deacon (Gamemann)",
    description = "An items spawn box for L4D2-PB.",
    version = PL_VERSION,
    url = "ModdingCommunity.com"
};

enum struct Item {
    float weight;
    char name[MAX_NAME_LENGTH];
    bool melee;
    char model[PLATFORM_MAX_PATH];
    bool preload;
}

// ConVars
ConVar gCvEnabled = null;

ConVar gCvAnnounce = null;

ConVar gCvMinItems = null;
ConVar gCvMaxItems = null;

ConVar gCvMinForce = null;
ConVar gCvMaxForce = null;
ConVar gCvRandomForcePerItem = null;

// ConVar values
bool gEnabled = false;

bool gAnnounce;

int gMinItems;
int gMaxItems;

float gMinForce;
float gMaxForce;
bool gRandomForcePerItem;

// Other global variables
bool gCoreEnabled = false;
bool gLoaded = false;

ArrayList gItemsArr;

public APLRes AskPluginLoad2(Handle hdl, bool late, char[] err, int errMax) {
    RegPluginLibrary("l4d2pb-box-items");

    return APLRes_Success;
}

public void OnLibraryAdded(const char[] name) {
	if (StrEqual(name, "l4d2pb"))
        gCoreEnabled = true;
}

public void OnPluginStart() {
    // ConVars.
    gCvEnabled = CreateConVar("l4d2pb_box_items_enabled", "1", "Enables the items box", _, true, 0.0, true, 1.0);
    gCvEnabled.AddChangeHook(CVar_Changed);

    gCvAnnounce = CreateConVar("l4d2pb_box_items_announce", "1", "Announces each item found from the items box.", _, true, 0.0, true, 1.0);
    gCvAnnounce.AddChangeHook(CVar_Changed);

    gCvMinItems = CreateConVar("l4d2pb_box_items_min", "1", "The Minimum amount of items to spawn", _, true, 0.0);
    gCvMinItems.AddChangeHook(CVar_Changed);

    gCvMaxItems = CreateConVar("l4d2pb_box_items_max", "5", "The maximum amount of items to spawn.", _, true, 1.0);
    gCvMaxItems.AddChangeHook(CVar_Changed);

    gCvMinForce = CreateConVar("l4d2pb_box_items_min_force", "0.0", "The mimimum amount of force to apply to items when spawned.", _, true, 0.0);
    gCvMinForce.AddChangeHook(CVar_Changed);

    gCvMaxForce = CreateConVar("l4d2pb_box_items_max_force", "100.0", "The maximum amount of force to apply to items when spawned", _, true, 0.0);
    gCvMaxForce.AddChangeHook(CVar_Changed);

    gCvRandomForcePerItem = CreateConVar("l4d2pb_box_items_random_force_per_item", "1", "Whether to apply random force per item.", _, true, 0.0, true, 1.0);
    gCvRandomForcePerItem.AddChangeHook(CVar_Changed);

    CreateConVar("l4d2pb_box_items_version", PL_VERSION, "The items box's version.");

    // Commands.
    RegAdminCmd("sm_l4d2pb_items_print", Command_ListItems, ADMFLAG_ROOT);

    // Load translations.
    LoadTranslations("l4d2pb.phrases.txt");
    LoadTranslations("l4d2pb-box-items.phrases.txt");

    // Load config.
    AutoExecConfig(true, "plugin.l4d2pb-box-items");

    // Create items array.
    gItemsArr = new ArrayList(sizeof(Item));
}

stock LoadBox() {
    if (gCoreEnabled) {
        if (!gEnabled && gLoaded) {
            L4D2PB_DebugMsg(2, "Found items box loaded, but not enabled. Unloading now!");

            L4D2PB_UnloadBox(BOX_NAME);

            gLoaded = false;
        } else if (gEnabled && !gLoaded) {
            L4D2PB_DebugMsg(2, "Loading items box!");

            L4D2PB_RegisterBox(BOXTYPE_GOOD, BOX_NAME, BOX_DISPLAY);

            gLoaded = true;
        }

        if (gEnabled)
            LoadItems();
    }
}

void LoadItems() {
    if (gItemsArr == null)
        return;

    // Clear our current list.
    gItemsArr.Clear();

    // Build CFG path.
    char cfgPath[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, cfgPath, sizeof(cfgPath), "configs/%s", CONF_FILE);

    if (!FileExists(cfgPath))
        SetFailState("%t Config file doesn't exist for items box (%s)", "Tag", cfgPath);

    // Create KeyValues.
    KeyValues kv = new KeyValues("Items");

    // Import config file.
    if (!kv.ImportFromFile(cfgPath))
        SetFailState("%t Error importing config file into KeyValues for items box", "Tag");

    // Go to first key.
    if (!kv.GotoFirstSubKey()) {
        delete kv;

        SetFailState("%t Failed to go to first subkey for items box.");
    }

    char itemName[MAX_NAME_LENGTH];

    do {
        // Create new item.
        Item newItem;

        // Get section name which indicates item name.
        kv.GetSectionName(itemName, sizeof(itemName));

        // Set new item values.
        newItem.weight = kv.GetFloat("weight", 1.0);
        strcopy(newItem.name, sizeof(newItem.name), itemName);

        // Check precache settings.
        kv.GetString("model", newItem.model, sizeof(newItem.model), "");

        int preload = kv.GetNum("preload", 1);

        newItem.preload = preload > 0 ? true : false;

        // Check for melee.
        int melee = kv.GetNum("melee", 0);

        if (melee > 0)
            newItem.melee = true;

        // Push to array.
        gItemsArr.PushArray(newItem);
    } while (kv.GotoNextKey());

    delete kv;
}

public void OnMapStart() {
    // Check if we need to precache models.
    if (gItemsArr == null || gItemsArr.Length < 1)
        return;

    for (int i = 0; i < gItemsArr.Length; i++) {
        Item item;

        gItemsArr.GetArray(i, item);

        if (strlen(item.model) > 0 && !IsModelPrecached(item.model))
            PrecacheModel(item.model, item.preload);
    }
}

stock SetCVars() {
    gEnabled = gCvEnabled.BoolValue;

    gAnnounce = gCvAnnounce.BoolValue;

    gMinItems = gCvMinItems.IntValue;
    gMaxItems = gCvMaxItems.IntValue;

    gMinForce = gCvMinForce.FloatValue;
    gMaxForce = gCvMaxForce.FloatValue;
    gRandomForcePerItem = gCvRandomForcePerItem.BoolValue;

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

public Action Command_ListItems(int client, int args) {
    if (gItemsArr == null) {
        ReplyToCommand(client, "%t Items array is null.", "Tag");

        return Plugin_Handled;
    }

    for (int i = 0; i < gItemsArr.Length; i++) {
        Item item;

        gItemsArr.GetArray(i, item);

        L4D2PB_PrintToChat(client, "%t %s => Weight: %.2f", "Tag", item.name, item.weight);
    }

    return Plugin_Handled;
}

Item PickRandomItem() {
    float sum = 0.0;

    // We need to add up the total sums.
    for (int i = 0; i < gItemsArr.Length; i++) {
        Item item;

        gItemsArr.GetArray(i, item);

        sum += item.weight;
    }

    // Pick random float.
    float rand = GetRandomFloat(0.0, sum);

    float cWeight = 0.0;

    // Iterate again to find the item corresponding to the random weight
    for (int i = 0; i < gItemsArr.Length; i++) {
        Item item;
        gItemsArr.GetArray(i, item);

        cWeight += item.weight;

        if (rand <= cWeight)
            return item;
    }

    // Fallback to random item.
    // Note - It should never get here.
    int randIdx = GetRandomInt(0, gItemsArr.Length - 1);

    Item item;
    gItemsArr.GetArray(randIdx, item);

    return item;
}

int SpawnItem(Item item, float pos[3], float ang[3], float force) {
    // Create item and check.
    int ent = -1;

    if (item.melee)
        ent = CreateEntityByName("weapon_melee")
    else
        ent = CreateEntityByName(item.name);

    if (ent == -1) {
        L4D2PB_DebugMsg(3, "%t Failed to create '%s' (entity index -1).", "Tag", item.name);

        return 1;
    }

    float vel[3];

    if (force > 0.0) {
        L4D2PB_DebugMsg(4, "%t Using random force %.2f on '%s'!", "Tag", force, item.name);

        // Get random direction.
        vel[0] = GetRandomFloat(-1.0, 1.0);
        vel[1] = GetRandomFloat(-1.0, 1.0);
        vel[2] = GetRandomFloat(-1.0, 1.0);

        // Normalize the vector.
        NormalizeVector(vel, vel);

        // Scale vector.
        ScaleVector(vel, force);
    }

    // Teleport entity.
    TeleportEntity(ent, pos, ang, force > 0.0 ? vel : NULL_VECTOR);

    // Check for melee script.
    if (item.melee)
        DispatchKeyValue(ent, "melee_script_name", item.name);

    // Dispatch spawn.
    DispatchSpawn(ent);

    AcceptEntityInput(ent, "Activate");

    return 0;
}

public void Activate(int userId) {
    L4D2PB_DebugMsg(4, "%t Items box activated!", "Tag");

    // Get client index.
    int client = GetClientOfUserId(userId);

    if (!IsClientInGame(client) || !IsPlayerAlive(client))
        return;

    // Get client position.
    float pos[3];
    GetClientAbsOrigin(client, pos);

    // Get client angles.
    float ang[3];
    GetClientAbsAngles(client, ang);

    // Get random item count.
    int itemCnt = GetRandomInt(gMinItems, gMaxItems);

    L4D2PB_DebugMsg(3, "%t Spawning %d random items!", "Tag", itemCnt);

    if (itemCnt > 0) {
        float force = GetRandomFloat(gMinForce, gMaxForce);

        for (int i = 0; i < itemCnt; i++) {
            // Pick random item.
            Item item;
            item = PickRandomItem();

            L4D2PB_DebugMsg(3, "%t Picked random item '%s' with weight %.2f", "Tag", item.name, item.weight);

            // Check if we should get random force.
            if (gRandomForcePerItem)
                force = GetRandomFloat(gMinForce, gMaxForce);

            // Spawn item.
            if (SpawnItem(item, pos, ang, force) == 0 && gAnnounce) {
                // Get opener name.
                char userName[MAX_NAME_LENGTH];
                GetClientName(client, userName, sizeof(userName));

                // Get item name from translation.
                char itemDisplay[MAX_NAME_LENGTH];
                Format(itemDisplay, sizeof(itemDisplay), "%t", item.name);

                // Announce.
                L4D2PB_PrintToChatAll("%t %t", "Tag", "ItemAnnounce", userName, itemDisplay);
            }
        }
    }
}

public void L4D2PB_OnBoxOpened(int type, const char[] boxName, int userId) {
    if (strcmp(boxName, BOX_NAME, false) == 0)
        Activate(userId);
}