#if defined _zm_internal_utils_included
  #endinput
#endif
#define _zm_internal_utils_included

#include <logger>

#include "include/stocks/simple_logger_stocks.inc"

stock bool: ExecuteForwardOnce(const name[], stop_type = ET_IGNORE, &ret = 0) {
#if defined DEBUG_FORWARDS
  logd("Forwarding %s", name);
#endif
  new const handle = CreateMultiForward(name, stop_type);
  new const bool: executed = ExecuteForward(handle, ret) == 1;
  DestroyForward(handle);
  return executed;
}

stock registerNativeFast(const pre[], const name[]) {
  register_native(fmt("%s_%s", pre, name), fmt("native_%s", name));
}

stock zm_registerNative(const name[]) {
  registerNativeFast("zm", name);
}
