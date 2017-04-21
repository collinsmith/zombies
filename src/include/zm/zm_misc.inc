#if defined _zm_misc_included
  #endinput
#endif
#define _zm_misc_included

#include "include/stocks/misc_stocks.inc"
#include "include/stocks/string_stocks.inc"

#include "include/zm/zm_debug.inc"
#include "include/zm/zm_i18n.inc"

/**
 * Registers and logs a console command. {@code command} will automatically be
 * prefixed with {@code "zm."}.
 * 
 * @param command  The command, which when typed in the console, will call the
 *                   function specified by {@code callback}. The command will
 *                   automatically be prepended with {@code "zm."}, so commands
 *                   are of the format {@code "zm.${command}"}. Additionally,
 *                   multiple aliases can be entered, separated by a comma,
 *                   e.g., {@code "cmd,command"}.
 * @param callback The name of the function to call when the command is executed
 * @param desc     A brief description of the command
 * @param access   The required privileges to execute the command
 * @param logger   The logger which to log the event to
 * 
 * @return The idenfitifier assigned to the command by {@link #register_concmd},
 *         or {@code 0} on failure. If multiple aliases are registered at once,
 *         then the identifier for the first successfully registered one is
 *         returned.
 * 
 * @throws IllegalArgumentException if {@code command} or {@code callback} is
 *         empty.
 */
stock zm_registerConCmd(const command[], const callback[], const desc[],
                        access = ADMIN_CFG, Logger: logger = Invalid_Logger) {
  new zm[8];
  formatex(zm, charsmax(zm), "%L", LANG_SERVER, ZM_NAME_SHORT);
  strtolower(zm);
#if defined DEBUG_COMMANDS
  return registerConCmd(zm, command, callback, desc, access, logger);
#else
  #pragma unused logger
  return registerConCmd(zm, command, callback, desc, access, Invalid_Logger);
#endif
}

/** The size of the buffer used for printing. */
#define ZM_PRINT_BUFFER_LENGTH 191

/** i18n key for the header for the print messages. (default: {@code "[%L] "}) */
stock const ZM_PRINT_COLOR_HEADER[] = "ZM_PRINT_COLOR_HEADER";

/**
 * Returns the header (including color format bytes) used for print messages.
 */
stock zm_getPrintColorHeader(dst[], len) {
  return formatex(dst, len, "%L", ZM_PRINT_COLOR_HEADER);
}

/**
 * Returns the number of cells useable by clients for print message contents.
 */
stock zm_getPrintColorBufferLength() {
  new tmp[32];
  new const headerLen = zm_getPrintColorHeader(tmp, charsmax(tmp));
  return ZM_PRINT_BUFFER_LENGTH - headerLen;
}

/**
 * Prints a chat message to the specified client, headed with the ZM chat header.
 */
stock zm_printColor(const id, const message[], any: ...) {
  static buffer[ZM_PRINT_BUFFER_LENGTH + 1], offset;
  if (isStringEmpty(buffer)) {
    offset = formatex(buffer, ZM_PRINT_BUFFER_LENGTH, "%L ",
        id, ZM_PRINT_COLOR_HEADER, id, ZM_NAME_SHORT);
  }

  new len = offset;
  switch (numargs()) {
    case 2: len += copy(buffer[len], ZM_PRINT_BUFFER_LENGTH - len, message);
    default: len += vformat(buffer[len], ZM_PRINT_BUFFER_LENGTH - len, message, 3);
  }

  client_print_color(id, print_team_default, buffer);
}
