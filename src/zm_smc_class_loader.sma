#include <amxmisc>
#include <logger>

#include "include/zm/zm_classes.inc"
#include "include/zm/zombies.inc"

#define EXTENSION_NAME "Class Loader: smc"
#define VERSION_STRING "1.0.0"

#if defined ZM_COMPILE_FOR_DEBUG
  //#define DEBUG_LOADER
  //#define DEBUG_PARSER
#else
  //#define DEBUG_LOADER
  //#define DEBUG_PARSER
#endif

static Logger: logger = Invalid_Logger;

static Trie: class;
static classesLoaded;

public zm_onInit() {
  zm_registerClassLoader("onLoadClass", "smc");
  logger = zm_getLogger();
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
#if defined DEBUG_LOADER
  LoggerLogDebug(logger, "Attempting to parse \"%s\" as an SMC file...", path);
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
    LoggerLogError(logger, "Error at line %d, col %d: %s", line, col, errorMsg);
    return;
  }

#if defined DEBUG_LOADER
  LoggerLogDebug(logger, "Loaded %d classes", classesLoaded);
#endif
}

public SMCResult: onNewSection(SMCParser: handle, const name[]) {
  if (class) {
    LoggerLogError(logger, "class definitions cannot contain inner-sections", name);
    return SMCParse_HaltFail;
  }

  class = TrieCreate();
  TrieSetString(class, ZM_CLASS_NAME, name);
#if defined DEBUG_PARSER
  LoggerLogDebug(logger, "creating new class: %d [%s]", class, name);
#endif
  return SMCParse_Continue;
}

public SMCResult: onEndSection(SMCParser: handle) {
#if defined DEBUG_PARSER
  LoggerLogDebug(logger, "registering class %d", class);
#endif
  zm_registerClass(class);
  classesLoaded++;
  class = Invalid_Trie;
  return SMCParse_Continue;
}

public SMCResult: onKeyValue(SMCParser: handle, const key[], const value[]) {
  if (!class) {
    LoggerLogError(logger, "cannot have key-value pair outside of section");
    return SMCParse_HaltFail;
  }

  TrieSetString(class, key, value);
#if defined DEBUG_PARSER
  LoggerLogDebug(logger, "%d [%s]=\"%s\"", class, key, value);
#endif
  return SMCParse_Continue;
}
