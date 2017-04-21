#if defined _extension_t_included
  #endinput
#endif
#define _extension_t_included

#define ext_Name_length 31
#define ext_Desc_length 127
#define ext_Version_length 31

#define ZM_Ext: ZM_Extension:
enum ZM_Extension { Invalid_Extension };

/**
 * Template defining the fields associated with an extension.
 */
enum extension_t {
  /** The plugin that registered the extension. */
  ext_PluginId,
  /** The name of the extension. */
  ext_Name[ext_Name_length + 1],
  /** A brief description of the extension. */
  ext_Desc[ext_Desc_length + 1],
  /** A string representation for the version of the extension. */
  ext_Version[ext_Version_length + 1],
};