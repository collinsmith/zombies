#include <amxmodx>
#include <logger>

#include "include/classloader/classloader.inc"

#include "include/zm/zm_classes.inc"
#include "include/zm/zombies.inc"

#define EXTENSION_NAME "ZM Classes Class Loader: smc"
#define VERSION_STRING "1.0.0"

#if defined ZM_COMPILE_FOR_DEBUG
  #define DEBUG_LOADER
  //#define DEBUG_PARSER
#else
  //#define DEBUG_LOADER
  //#define DEBUG_PARSER
#endif

static Trie: class;
static classesLoaded;

public zm_onInit() {
  LoadLogger(zm_getPluginId());
  cl_registerClassLoader("onLoadClass", "smc");
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
      .desc = "Loads classes from SMC files");
}

stock getBuildId(buildId[], len) {
  return formatex(buildId, len, "%s [%s]", VERSION_STRING, __DATE__);
}

public onLoadClass(const path[], const extension[]) {
  // TODO: This can maybe be cleaned up a bit
  new tmp[PLATFORM_MAX_PATH];
  getFileParentPath(tmp, charsmax(tmp), path);
  getFileName(tmp, charsmax(tmp), tmp);
  if (!equal(tmp, "classes")) {
    return;
  }
  
#if defined DEBUG_LOADER
  logd("Attempting to parse \"%s\" as an SMC class file...", path);
#endif

  classesLoaded = 0;
  new SMCParser: parser = SMC_CreateParser();
  SMC_SetReaders(parser, "onKeyValue", "onNewSection", "onEndSection");

  new line, col;
  new SMCError: error = SMC_ParseFile(parser, path, line, col);
  SMC_DestroyParser(parser);
  if (error) {
    new errorMsg[256];
    SMC_GetErrorString(error, errorMsg, charsmax(errorMsg));
    loge("Error at line %d, col %d: %s", line, col, errorMsg);
    return;
  }

#if defined DEBUG_LOADER
  logd("Loaded %d classes", classesLoaded);
#endif
}

public SMCResult: onNewSection(SMCParser: handle, const name[]) {
  if (class) {
    loge("class definitions cannot contain inner-sections");
    return SMCParse_HaltFail;
  }

  class = TrieCreate();
  TrieSetString(class, ZM_CLASS_NAME, name);
#if defined DEBUG_PARSER
  logd("creating new class: %d [%s]", class, name);
#endif
  return SMCParse_Continue;
}

public SMCResult: onEndSection(SMCParser: handle) {
#if defined DEBUG_PARSER
  logd("registering class %d", class);
#endif
  zm_registerClass(class);
  classesLoaded++;
  class = Invalid_Trie;
  return SMCParse_Continue;
}

public SMCResult: onKeyValue(SMCParser: handle, const key[], const value[]) {
  if (!class) {
    loge("cannot have key-value pair outside of section");
    return SMCParse_HaltFail;
  }

  TrieSetString(class, key, value);
#if defined DEBUG_PARSER
  logd("%d [%s]=\"%s\"", class, key, value);
#endif
  return SMCParse_Continue;
}
