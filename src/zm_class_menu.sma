#include <amxmodx>
#include <amxmisc>
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
#else
  //#define DEBUG_NATIVES
  //#define DEBUG_FORWARDS
  //#define DEBUG_CONSTRUCTION
  //#define DEBUG_PERSONALIZATION
  //#define DEBUG_SELECTION
  //#define DEBUG_DISPLAY
#endif

#define EXTENSION_NAME "Class Menu"
#define VERSION_STRING "1.0.0"

#define MENU_ITEM_LENGTH 63
#define CACHE_MENU_ITEMS

static Logger: logger = Invalid_Logger;

static fwReturn = 0;
static onBeforeClassMenuDisplayed = INVALID_HANDLE;
static onClassMenuDisplayed = INVALID_HANDLE;
static isClassEnabled = INVALID_HANDLE;

static classMenu = INVALID_HANDLE;
static classMenuItem = INVALID_HANDLE;

#if defined CACHE_MENU_ITEMS
static Array: menuItems;
#endif

public plugin_natives() {
  register_library("zm_class_menu");

  register_native("zm_showClassMenu", "native_showClassMenu");
}

public zm_onInit() {
  logger = zm_getLogger();

  classMenu = menu_create(NULL, "onItemSelected");
  classMenuItem = menu_makecallback("isItemEnabled");
#if defined DEBUG_CONSTRUCTION
  LoggerLogDebug(logger, "classMenu=%d", classMenu);
  LoggerLogDebug(logger, "classMenuItem=%d", classMenuItem);
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
  LoggerLogDebug(logger, "Registering dictionary file \"%s\"", dictionary);
#endif

  cmd_registerCommand(
      .alias = "class",
      .handle = "onClassMenu",
      .desc = "Displays the class selection menu");

  zm_registerConCmd(
      .command = "class",
      .callback = "onClassMenu",
      .desc = "Displays the class selection menu",
      .logger = logger);
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
    LoggerLogDebug(logger, "Initialized menuItems container as cellarray %d", menuItems);
#endif
  }
  
#if defined DEBUG_CONSTRUCTION
  new item =
#endif
  ArrayPushCell(menuItems, class);
#endif

#if defined DEBUG_CONSTRUCTION
  LoggerLogDebug(logger, "Added \"%s\" to class menu", name);
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

  new name[class_prop_key_length + 1];
#if defined CACHE_MENU_ITEMS
  new const Trie: class = ArrayGetCell(menuItems, item);
#else
  new access, callback;
  menu_item_getinfo(classMenu, item, access, name, charsmax(name), .callback=callback);
  new const Trie: class = zm_findClass(name);
#endif

#if defined DEBUG_SELECTION
  zm_getClassProperty(class, ZM_CLASS_NAME, name, charsmax(name));
  LoggerLogDebug(logger, "%N selected \"%s\" (%d)", id, name, class);
  zm_setUserClass(id, class, true);
#else
  // TODO: This is required for testing until respawn command is added
  zm_setUserClass(id, class);
#endif
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
  return fwReturn > ITEM_IGNORE ? fwReturn : ITEM_ENABLED;
}

zm_isClassEnabled(id, Trie: class, name[]) {
  if (isClassEnabled == INVALID_HANDLE) {
#if defined DEBUG_FORWARDS
    LoggerLogDebug(logger, "Creating forward for zm_isClassEnabled");
#endif
    isClassEnabled = CreateMultiForward(
        "zm_isClassEnabled", ET_STOP2,
        FP_CELL, FP_CELL, FP_STRING);
#if defined DEBUG_FORWARDS
    LoggerLogDebug(logger, "isClassEnabled = %d", isClassEnabled);
#endif
  }
  
#if defined DEBUG_FORWARDS
  LoggerLogDebug(logger, "Forwarding zm_isClassEnabled(%d, class=%d, \"%s\") for %N", id, class, name, id);
#endif
  ExecuteForward(isClassEnabled, fwReturn, id, class, name);
  return fwReturn;
}

zm_onBeforeClassMenuDisplayed(id, bool: exitable) {
  if (onBeforeClassMenuDisplayed == INVALID_HANDLE) {
#if defined DEBUG_FORWARDS
    LoggerLogDebug(logger, "Creating forward for zm_onBeforeClassMenuDisplayed");
#endif
    onBeforeClassMenuDisplayed = CreateMultiForward(
        "zm_onBeforeClassMenuDisplayed", ET_STOP,
        FP_CELL, FP_CELL);
#if defined DEBUG_FORWARDS
    LoggerLogDebug(logger, "onBeforeClassMenuDisplayed = %d", onBeforeClassMenuDisplayed);
#endif
  }
  
#if defined DEBUG_FORWARDS
  LoggerLogDebug(logger, "Forwarding zm_onBeforeClassMenuDisplayed(%d, exitable=%s) for %N", id, exitable ? TRUE : FALSE, id);
#endif
  ExecuteForward(onBeforeClassMenuDisplayed, fwReturn, id, exitable);
  return fwReturn;
}

zm_onClassMenuDisplayed(id, bool: exitable) {
  if (onClassMenuDisplayed == INVALID_HANDLE) {
#if defined DEBUG_FORWARDS
    LoggerLogDebug(logger, "Creating forward for zm_onClassMenuDisplayed");
#endif
    onClassMenuDisplayed = CreateMultiForward(
        "zm_onClassMenuDisplayed", ET_CONTINUE,
        FP_CELL, FP_CELL);
#if defined DEBUG_FORWARDS
    LoggerLogDebug(logger, "onClassMenuDisplayed = %d", onClassMenuDisplayed);
#endif
  }
  
#if defined DEBUG_FORWARDS
  LoggerLogDebug(logger, "Forwarding zm_onClassMenuDisplayed(%d, exitable=%s) for %N", id, exitable ? TRUE : FALSE, id);
#endif
  ExecuteForward(onClassMenuDisplayed, fwReturn, id, exitable);
}

bool: showClassMenu(id, bool: exitable) {
  new ZM_Team: team = zm_getUserTeam(id);
  if (team == ZM_TEAM_UNASSIGNED || team == ZM_TEAM_SPECTATOR) {
    ThrowIllegalStateException(logger, "%N must belong to a real team, currently: %s", id, ZM_Team_Names[team]);
    return false;
  }

  // FIXME: viewingMenu is 1 when using console command to call this function, expected 0
  new menuHandle, newMenuHandle;
  new viewingMenu = player_menu_info(id, menuHandle, newMenuHandle);
#if defined DEBUG_DISPLAY
    LoggerLogDebug(logger, "%N viewingMenu = %d", id, viewingMenu);
#endif
  if (viewingMenu && (menuHandle > 0 || newMenuHandle != INVALID_HANDLE)) {
#if defined DEBUG_DISPLAY
    LoggerLogDebug(logger, "%N already viewing menu: %d (menu=%d, newmenu=%d)",
        id, viewingMenu, menuHandle, newMenuHandle);
#endif
    return false;
  }

  fwReturn = zm_onBeforeClassMenuDisplayed(id, exitable);
  if (fwReturn == PLUGIN_HANDLED && exitable) {
#if defined DEBUG_DISPLAY
    LoggerLogDebug(logger, "Class menu blocked for %N", id);
#endif
    return false;
  }

  personalizeMenu(id, exitable);
  menu_display(id, classMenu);
#if defined DEBUG_DISPLAY
  LoggerLogDebug(logger, "Displaying class menu on %N", id);
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

//native bool: zm_showClassMenu(const id, const bool: exitable);
public bool: native_showClassMenu(plugin, numParams) {
  if (!numParamsEqual(2, numParams, logger)) {
    return false;
  }

  new const id = get_param(1);
  if (!isValidId(id)) {
    ThrowIllegalArgumentException(logger, "Invalid player id specified: %d", id);
    return false;
  }

  new bool: exitable = get_param(2);
  return showClassMenu(id, exitable);
}
