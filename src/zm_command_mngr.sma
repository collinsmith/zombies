#define VERSION_STRING "1.0.0"
#define EXTENSION_NAME "ZM Command Manager"
#define ZM_COMMAND_MANAGER_TXT "zm_command_manager.txt"
#define PRINT_BUFFER_LENGTH 191

#include <amxmodx>
#include <amxmisc>
#include <cstrike>
#include <logger>

#include "include\\commandmanager-inc\\command_manager.inc"

#include "include\\zombiemod-inc\\zombiemod.inc"

#include "include\\stocks\\flag_stocks.inc"
#include "include\\stocks\\path_stocks.inc"
#include "include\\stocks\\string_stocks.inc"

public zm_onExtensionInit() {
    new name[32];
    formatex(name, charsmax(name),
            "[%L] %s",
            LANG_SERVER, ZM_NAME_SHORT,
            EXTENSION_NAME);

    new buildId[32];
    getBuildId(buildId);
    register_plugin(name, buildId, "Tirant");
    zm_registerExtension(
            .name = EXTENSION_NAME,
            .version = buildId,
            .description = "Manages custom commands");

    new Logger: logger = LoggerCreate();
#if defined ZM_COMPILE_FOR_DEBUG
    LoggerSetVerbosity(logger, Severity_Lowest);
    LoggerSetVerbosity(All_Loggers, Severity_Lowest);
#endif

    new dictionary[32];
    getPath(dictionary, _, ZM_COMMAND_MANAGER_TXT);
    register_dictionary(dictionary);
    LoggerLogDebug(logger, "Registering dictionary file \"%s\"", dictionary);

    LoggerDestroy(logger);
}

stock getBuildId(buildId[], len = sizeof buildId) {
    return formatex(buildId, len - 1, "%s [%s]", VERSION_STRING, __DATE__);
}