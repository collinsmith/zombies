#include <amxmodx>
#include <logger>

#include "include/stocks/param_stocks.inc"

#include "include/commands/commands.inc"

#include "include/zm/zm_classes.inc"
#include "include/zm/zm_teams.inc"
#include "include/zm/zombies.inc"

#if defined ZM_COMPILE_FOR_DEBUG
  #define DEBUG_NATIVES
  //#define DEBUG_FORWARDS
  //#define DEBUG_CONSTRUCTION
  #define DEBUG_PERSONALIZATION
  #define DEBUG_SELECTION
  #define DEBUG_DISPLAY
  #define DEBUG_GET_CLASSES
#else
  //#define DEBUG_NATIVES
  //#define DEBUG_FORWARDS
  //#define DEBUG_CONSTRUCTION
  //#define DEBUG_PERSONALIZATION
  //#define DEBUG_SELECTION
  //#define DEBUG_DISPLAY
  //#define DEBUG_GET_CLASSES
#endif

#define EXTENSION_NAME "Class Menu"
#define VERSION_STRING "1.0.0"

#define MENU_ITEM_LENGTH 63
#define CACHE_MENU_ITEMS

static fwReturn = 0;
static onBeforeClassMenuDisplayed = INVALID_HANDLE;
static onClassMenuDisplayed = INVALID_HANDLE;
static onClassSelected = INVALID_HANDLE;
static isClassEnabled = INVALID_HANDLE;

static classMenu = INVALID_HANDLE;
static classMenuItem = INVALID_HANDLE;

#if defined CACHE_MENU_ITEMS
static Array: menuItems;
#endif

public plugin_natives() {
  register_library("zm_class_menu");

  register_native("zm_showClassMenu", "native_showClassMenu");
  register_native("zm_getUserClasses", "native_getUserClasses");
}

public zm_onInit() {
  LoadLogger(zm_getPluginId());

  classMenu = menu_create(NULL, "onItemSelected");
  classMenuItem = menu_makecallback("isItemEnabled");
#if defined DEBUG_CONSTRUCTION
  logd("classMenu=%d", classMenu);
  logd("classMenuItem=%d", classMenuItem);
#endif
}

public zm_onInitExtension() {
  new name[32];
  formatex(name, charsmax(name), "[%L] %s", LANG_SERVER, ZM_NAME_SHORT, EXTENSION_NAME);
  register_plugin(name, VERSION_STRING, "Tirant");

  new buildId[32];
  getBuildId(buildId, charsmax(buildId));
  zm_registerExtension(
      .name = EXTENSION_NAME,
      .version = buildId,
      .desc = "Manages custom commands");

  new dictionary[] = "common.txt";
  register_dictionary(dictionary);
#if defined DEBUG_I18N
  logd("Registering dictionary file \"%s\"", dictionary);
#endif

  cmd_registerCommand(
      .alias = "class",
      .handle = "onClassMenu",
      .desc = "Displays the class selection menu");

  zm_registerConCmd(
      .command = "class",
      .callback = "onClassMenu",
      .desc = "Displays the class selection menu");
}

stock getBuildId(buildId[], len) {
  return formatex(buildId, len, "%s [%s]", VERSION_STRING, __DATE__);
}

public zm_onClassRegistered(const name[], const Trie: class) {
  menu_additem(classMenu, .name=name, .info=name, .callback=classMenuItem);

#if defined CACHE_MENU_ITEMS
  if (!menuItems) {
    menuItems = ArrayCreate();
#if defined DEBUG_CONSTRUCTION
    logd("Initialized menuItems container as cellarray %d", menuItems);
#endif
  }
  
#if defined DEBUG_CONSTRUCTION
  new item =
#endif
  ArrayPushCell(menuItems, class);
#endif

#if defined DEBUG_CONSTRUCTION
  logd("Added \"%s\" to class menu", name);
#if defined CACHE_MENU_ITEMS
  new access, tmp[class_prop_key_length + 1], callback;
  menu_item_getinfo(classMenu, item, access, tmp, charsmax(tmp), .callback=callback);
  assert equal(name, tmp);
#endif  
#endif
}

public onItemSelected(id, menu, item) {
  assert menu == classMenu;
  if (item == MENU_EXIT) {
    return PLUGIN_HANDLED;
  }

#if defined CACHE_MENU_ITEMS
  new const Trie: class = ArrayGetCell(menuItems, item);
#else
  new name[class_prop_key_length + 1];
  new access, callback;
  menu_item_getinfo(classMenu, item, access, name, charsmax(name), .callback=callback);
  new const Trie: class = zm_findClass(name);
#endif

#if defined DEBUG_SELECTION
#if !defined name
  new name[class_prop_key_length + 1];
#endif
  // FIXME: This might cause problems with other extensions
  zm_getClassProperty(class, ZM_CLASS_NAME, name, charsmax(name));
  logd("%N selected \"%s\" (%d)", id, name, class);
  zm_setUserClass(id, class, true);
#else
  zm_setUserClass(id, class);
#endif
  zm_onClassSelected(id, class, name);
  return PLUGIN_HANDLED;
}

public isItemEnabled(id, menu, item) {
  assert menu == classMenu;
  new name[class_prop_key_length + 1];
#if defined CACHE_MENU_ITEMS
  new const Trie: class = ArrayGetCell(menuItems, item);
#else
  new access, callback;
  menu_item_getinfo(menu, item, access, name, charsmax(name), .callback=callback);
  new const Trie: class = zm_findClass(name);
#endif

  zm_getClassPropertyName(class, ZM_CLASS_NAME, name, charsmax(name));
  fwReturn = zm_isClassEnabled(id, class, name);
  if (class == zm_getUserClass(id)) {
    
  }
  return fwReturn > ITEM_IGNORE ? fwReturn : ITEM_ENABLED;
}

zm_isClassEnabled(id, Trie: class, name[]) {
  if (isClassEnabled == INVALID_HANDLE) {
#if defined DEBUG_FORWARDS
    logd("Creating forward for zm_isClassEnabled");
#endif
    isClassEnabled = CreateMultiForward(
        "zm_isClassEnabled", ET_STOP2,
        FP_CELL, FP_CELL, FP_STRING);
#if defined DEBUG_FORWARDS
    logd("isClassEnabled = %d", isClassEnabled);
#endif
  }
  
#if defined DEBUG_FORWARDS
  logd("Forwarding zm_isClassEnabled(%d, class=%d, \"%s\") for %N", id, class, name, id);
#endif
  ExecuteForward(isClassEnabled, fwReturn, id, class, name);
  return fwReturn;
}

zm_onBeforeClassMenuDisplayed(id, bool: exitable) {
  if (onBeforeClassMenuDisplayed == INVALID_HANDLE) {
#if defined DEBUG_FORWARDS
    logd("Creating forward for zm_onBeforeClassMenuDisplayed");
#endif
    onBeforeClassMenuDisplayed = CreateMultiForward(
        "zm_onBeforeClassMenuDisplayed", ET_STOP,
        FP_CELL, FP_CELL);
#if defined DEBUG_FORWARDS
    logd("onBeforeClassMenuDisplayed = %d", onBeforeClassMenuDisplayed);
#endif
  }
  
#if defined DEBUG_FORWARDS
  logd("Forwarding zm_onBeforeClassMenuDisplayed(%d, exitable=%s) for %N", id, exitable ? TRUE : FALSE, id);
#endif
  ExecuteForward(onBeforeClassMenuDisplayed, fwReturn, id, exitable);
  return fwReturn;
}

zm_onClassMenuDisplayed(id, bool: exitable) {
  if (onClassMenuDisplayed == INVALID_HANDLE) {
#if defined DEBUG_FORWARDS
    logd("Creating forward for zm_onClassMenuDisplayed");
#endif
    onClassMenuDisplayed = CreateMultiForward(
        "zm_onClassMenuDisplayed", ET_CONTINUE,
        FP_CELL, FP_CELL);
#if defined DEBUG_FORWARDS
    logd("onClassMenuDisplayed = %d", onClassMenuDisplayed);
#endif
  }
  
#if defined DEBUG_FORWARDS
  logd("Forwarding zm_onClassMenuDisplayed(%d, exitable=%s) for %N", id, exitable ? TRUE : FALSE, id);
#endif
  ExecuteForward(onClassMenuDisplayed, fwReturn, id, exitable);
}

zm_onClassSelected(id, Class: class, name[]) {
  if (onClassSelected == INVALID_HANDLE) {
#if defined DEBUG_FORWARDS
    logd("Creating forward for zm_onClassSelected");
#endif
    onClassSelected = CreateMultiForward(
        "zm_onClassSelected", ET_CONTINUE,
        FP_CELL, FP_CELL, FP_STRING);
#if defined DEBUG_FORWARDS
    logd("onClassSelected = %d", onClassSelected);
#endif
  }
  
#if defined DEBUG_FORWARDS
  logd("Forwarding zm_onClassSelected(%d, class=%s, \"%s\") for %N", id, class, name, id);
#endif
  ExecuteForward(onClassSelected, fwReturn, id, class, name);
}

bool: showClassMenu(id, bool: exitable) {
  new ZM_Team: team = zm_getUserTeam(id);
  if (team == ZM_TEAM_UNASSIGNED || team == ZM_TEAM_SPECTATOR) {
    ThrowIllegalStateException("%N must belong to a real team, currently: %s", id, ZM_Team_Names[team]);
    return false;
  }

  // FIXME: viewingMenu is 1 when using console command to call this function, expected 0
  new menuHandle, newMenuHandle;
  new viewingMenu = player_menu_info(id, menuHandle, newMenuHandle);
#if defined DEBUG_DISPLAY
    logd("%N viewingMenu = %d", id, viewingMenu);
#endif
  if (viewingMenu && (menuHandle > 0 || newMenuHandle != INVALID_HANDLE)) {
#if defined DEBUG_DISPLAY
    logd("%N already viewing menu: %d (menu=%d, newmenu=%d)",
        id, viewingMenu, menuHandle, newMenuHandle);
#endif
    return false;
  }

  fwReturn = zm_onBeforeClassMenuDisplayed(id, exitable);
  if (fwReturn == PLUGIN_HANDLED && exitable) {
#if defined DEBUG_DISPLAY
    logd("Class menu blocked for %N", id);
#endif
    return false;
  }

  personalizeMenu(id, exitable);
  menu_display(id, classMenu);
#if defined DEBUG_DISPLAY
  logd("Displaying class menu on %N", id);
#endif

  zm_onClassMenuDisplayed(id, exitable);
  return true;
}

personalizeMenu(id, bool: exitable) {
  new text[MENU_ITEM_LENGTH + 1];
  formatex(text, charsmax(text), "%L", id, "ZM_CLASS_MENU_TITLE");
  menu_setprop(classMenu, MPROP_TITLE, text);

  formatex(text, charsmax(text), "%L", id, "BACK");
  menu_setprop(classMenu, MPROP_BACKNAME, text);
  formatex(text, charsmax(text), "%L", id, "MORE");
  menu_setprop(classMenu, MPROP_NEXTNAME, text);
  if (exitable) {
    formatex(text, charsmax(text), "%L", id, "EXIT");
    menu_setprop(classMenu, MPROP_EXITNAME, text);
  } else {
    menu_setprop(classMenu, MPROP_EXIT, MEXIT_NEVER);
  }

  new name[class_prop_key_length + 1], desc[MENU_ITEM_LENGTH + 1];
  new const count = menu_items(classMenu);
  for (new item = 0, Trie: class; item < count; item++) {
#if defined CACHE_MENU_ITEMS
    class = ArrayGetCell(menuItems, item);
#else
    new access, callback;
    menu_item_getinfo(classMenu, item, access, name, charsmax(name), .callback=callback);
    class = zm_findClass(name);
#endif

    zm_getClassProperty(class, ZM_CLASS_NAME, name, charsmax(name));
    zm_getClassProperty(class, ZM_CLASS_DESC, desc, charsmax(desc));
    formatex(text, charsmax(text), "%s [\\y%s\\w]", name, desc);
    menu_item_setname(classMenu, item, text);
  }
}

/*******************************************************************************
 * Console Commands
 ******************************************************************************/

public onClassMenu(id) {
  showClassMenu(id, true);
  return PLUGIN_HANDLED;
}

/*******************************************************************************
 * Natives
 ******************************************************************************/

stock bool: operator=(value) return value > 0;

stock Array: toArray(value) return Array:(value);
stock Array: operator=(value) return toArray(value);

//native bool: zm_showClassMenu(const id, const bool: exitable);
public bool: native_showClassMenu(plugin, numParams) {
#if defined DEBUG_NATIVES
  if (!numParamsEqual(2, numParams)) {
    return false;
  }
#endif

  new const id = get_param(1);
  if (!isValidId(id)) {
    ThrowIllegalArgumentException("Invalid player id specified: %d", id);
    return false;
  }

  new const bool: exitable = get_param(2);
  return showClassMenu(id, exitable);
}

//native Array: zm_getUserClasses(const id, const Array: dst = Invalid_Array);
public Array: native_getUserClasses(plugin, numParams) {
#if defined DEBUG_NATIVES
  if (!numParamsEqual(2, numParams)) {
    return Invalid_Array;
  }
#endif

  new const id = get_param(1);
  if (!isValidId(id)) {
    ThrowIllegalArgumentException("Invalid player id specified: %d", id);
    return Invalid_Array;
  }

  new Array: dst = get_param(2);
  if (dst) {
#if defined DEBUG_GET_CLASSES
    logd("clearing input cellarray %d", dst);
#endif
    ArrayClear(dst);
  } else {
    dst = ArrayCreate();
#if defined DEBUG_GET_CLASSES
    logd("dst cellarray initialized as cellarray %d", dst);
#endif
  }

  new name[class_prop_key_length + 1];
#if defined DEBUG_GET_CLASSES
  new count = 0;
#endif
  new Array: classes = zm_getClasses(), Class: class;
  new const size = ArraySize(classes);
  for (new i = 0; i < size; i++) {
    class = ArrayGetCell(classes, i);
    zm_getClassPropertyName(class, ZM_CLASS_NAME, name, charsmax(name));
    fwReturn = zm_isClassEnabled(id, class, name);
    if (fwReturn == ITEM_ENABLED) {
      ArrayPushCell(dst, class);
#if defined DEBUG_GET_CLASSES
      logd("dst[%d]=%d:[%s]", count++, class, name);
#endif
    }
  }

  ArrayDestroy(classes);
  return dst;
}
