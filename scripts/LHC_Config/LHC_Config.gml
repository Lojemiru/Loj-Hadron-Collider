// This script is a collection of user-configurable macros used to determine LHC behavior.

// LHC_WRITELOGS: Whether or not to write optional logs to the standard debug output.
// It is highly recommended that you only enable this for debugging purposes,
// as show_debug_message is not async in some scenarios and will cause some overhead regardless.
// A few logs during library loading will be displayed independently of this setting.
#macro LHC_WRITELOGS true