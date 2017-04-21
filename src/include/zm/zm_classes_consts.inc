#if defined _zm_classes_consts_included
  #endinput
#endif
#define _zm_classes_consts_included

#include <celltrie>

#include "include/zm/zm_i18n.inc"

#define Class: Trie:

#define class_prop_key_length 31
#define class_prop_value_length 511

stock const ZM_CLASS_NAME[] = "class_name";
stock const ZM_CLASS_DESC[] = "class_desc";
stock const ZM_CLASS_MODEL[] = "class_model";
stock const ZM_CLASS_HEALTH[] = "class_health";
stock const ZM_CLASS_MAXSPEED[] = "class_maxspeed";
stock const ZM_CLASS_GRAVITY[] = "class_gravity";
stock const ZM_CLASS_WEAPONS[] = "class_weapons";

stock zm_parseClassResource(const Trie: class, const property[], res[], len, id = LANG_SERVER) {
  TrieGetString(class, property, res, len);
  zm_parseResourceFast(res, len, id);
}

stock zm_getClassPropertyName(const Class: class, const property[], res[], len) {
  TrieGetString(class, property, res, len);
}

stock bool: zm_getClassProperty(const Class: class, const property[], res[], len, id = LANG_SERVER) {
  new const bool: keyExists = TrieGetString(class, property, res, len);
  zm_parseResourceFast(res, len, id);
  return keyExists;
}
