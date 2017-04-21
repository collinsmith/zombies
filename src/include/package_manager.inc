#if defined _package_manager_included
  #endinput
#endif
#define _package_manager_included

/**
 * Downloads the manifest located at the specified URL and processes it. This
 * will take time, however it is a non-blocking operation which uses curl along
 * with callbacks. The manifest file should be formatted as:
 * {@code <plugin.amxx> <version> <url> <md5 checksum>}
 * 
 * For example:
 * {@code
 * plugin1.amxx 1.0.0 https://example.com/plugin1.amxx "a05c584b6a485b552b087bb978a957a4"
 * plugin2.amxx 1.0.0 https://example.com/plugin2.amxx "a05c584b6a485b552b087bb978a957a4"
 * plugin3.amxx 1.0.0 https://example.com/plugin3.amxx "a05c584b6a485b552b087bb978a957a4"
 * plugin4.amxx 1.0.0 https://example.com/plugin4.amxx "a05c584b6a485b552b087bb978a957a4"
 * plugin5.amxx 1.0.0 https://example.com/plugin5.amxx "a05c584b6a485b552b087bb978a957a4"
 * }
 * 
 * The plugin file name should match that plugin file name on the server, and
 * version should be formatted the same way. Currently version only supports
 * the following regex {@code \d+(\.\d+)}, for example, {@code 1}, {@code 1.0}
 * and {@code 1.0.0} are all valid version codes that can be used. This version
 * code is used to determine if the file in the manifest at the specified url
 * is newer than the current file and needs to be downloaded.
 * 
 * The md5 checksum is used to verify that the received file is complete. Once
 * the file has been verified, it is copied over the exising plugin.
 */
native pkg_processManifest(const url[]);