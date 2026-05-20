#if defined _l4d2_mission_controller_included_
	#endinput
#endif
#define _l4d2_mission_controller_included_

#include <l4d2_mission_manager>

/**
 * Returns whether the controller currently has an effective next map target.
 *
 * @return              True if a next map target is available.
 */
native bool L4D2MC_HasNextMap();

/**
 * Retrieves the effective next map target currently used by the controller.
 *
 * This returns the active destination after applying any vote override.
 *
 * @param mapName       Buffer to receive the map code.
 * @param length        Maximum output buffer size.
 * @return              Number of bytes written, including null terminator, or 0 on failure.
 */
native int L4D2MC_GetNextMap(char[] mapName, int length);

/**
 * Retrieves the configured next map target read from the KV config.
 *
 * This does not include vote overrides.
 *
 * @param mapName       Buffer to receive the map code.
 * @param length        Maximum output buffer size.
 * @return              Number of bytes written, including null terminator, or 0 on failure.
 */
native int L4D2MC_GetConfiguredNextMap(char[] mapName, int length);

/**
 * Returns whether a vote override is currently active for the next map target.
 *
 * @return              True if a vote override is active.
 */
native bool L4D2MC_HasVoteOverride();

/**
 * Retrieves the map code currently forced by a vote override.
 *
 * @param mapName       Buffer to receive the map code.
 * @param length        Maximum output buffer size.
 * @return              Number of bytes written, including null terminator, or 0 on failure.
 */
native int L4D2MC_GetVoteOverrideMap(char[] mapName, int length);

/**
 * Applies a vote override to the next map target.
 *
 * The supplied map must be valid. The effective next target becomes this map
 * until the controller state is reset or the override is cleared.
 *
 * @param mapName       Map code to force as next target.
 * @return              True on success, false on validation failure.
 */
native bool L4D2MC_SetVoteOverrideNextMap(const char[] mapName);

/**
 * Clears the active vote override and restores the configured next target.
 */
native void L4D2MC_ClearVoteOverride();

/**
 * Disables the competitive match-end map limit for the current campaign.
 *
 * This is equivalent to allowing the real finale map to be played even when
 * `l4d2_mission_controller_match_end_map` is configured.
 *
 * @return              True on success, false if no campaign-local limit could be disabled.
 */
native bool L4D2MC_DisableMatchEndMapLimit();

/**
 * Fired whenever the effective next map target changes.
 *
 * @param mapName       Effective next map target. Empty if none exists.
 * @param voteOverride  True if the effective target comes from a vote override.
 */
forward void L4D2MC_OnNextMapChanged(const char[] mapName, bool voteOverride);

public SharedPlugin __pl_l4d2_mission_controller =
{
	name = "l4d2_mission_controller",
	file = "l4d2_mission_controller.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};

#if !defined REQUIRE_PLUGIN
public void __pl_l4d2_mission_controller_SetNTVOptional()
{
	MarkNativeAsOptional("L4D2MC_HasNextMap");
	MarkNativeAsOptional("L4D2MC_GetNextMap");
	MarkNativeAsOptional("L4D2MC_GetConfiguredNextMap");
	MarkNativeAsOptional("L4D2MC_HasVoteOverride");
	MarkNativeAsOptional("L4D2MC_GetVoteOverrideMap");
	MarkNativeAsOptional("L4D2MC_SetVoteOverrideNextMap");
	MarkNativeAsOptional("L4D2MC_ClearVoteOverride");
	MarkNativeAsOptional("L4D2MC_DisableMatchEndMapLimit");
}
#endif
