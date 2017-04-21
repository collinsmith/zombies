#if defined _zm_i18n_included
  #endinput
#endif
#define _zm_i18n_included

#include <amxconst>

#include "include/zm/zm_debug.inc"

#if defined DEBUG_I18N
  #include <logger>
#endif

/** The dictionary file of zombies. */
#define ZOMBIES_DICTIONARY "zombiemod.txt"

/** The name of ZM (default: {@code "Zombie Mod"}). */
stock const ZM_NAME[] = "ZM_NAME";
/** The short name of ZM (default: {@code "ZM"}). */
stock const ZM_NAME_SHORT[] = "ZM_NAME_SHORT";

/**
 * Returns the path to the zombies dictionary.
 */
stock zm_getDictionary(dst[], len) {
  return copy(dst, len, ZOMBIES_DICTIONARY);
}

/**
 * Parses the given string and outputs the resolved value.
 * 
 * @param res The resource string to parse
 * @param dst The resolved value
 * @param len The maximum length of the resolved value
 * @param id  A player index or {@code LANG_SERVER} used to determine the
 *              language that the resource should be translated to
 */
stock zm_parseResource(const res[], dst[], len, id = LANG_SERVER) {
#if defined DEBUG_I18N
  new tmp[32];
  copy(tmp, charsmax(tmp), res);
#endif
  if (res[0] == '@') {
    new type[32];
    new const offset = copyc(type, charsmax(type), res[1], '/') + 2;
    if (equal(type, "string")) {
      // TODO: Not found should display something else than ML trans key
      LookupLangKey(dst, len, res[offset], id);
#if defined DEBUG_I18N
      // Cannot use zm_getLogger() here, causes bad things to happen
      server_print("%s -> \"%s\"", tmp, dst);
#endif
    } else {
      copy(dst, len, res);
    }
  }
}

stock zm_parseResourceFast(res[], len, id = LANG_SERVER) {
  zm_parseResource(res, res, len, id);
}
