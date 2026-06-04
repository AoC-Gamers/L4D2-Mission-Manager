#if defined _l4d2_mission_controller_included_
	#endinput
#endif
#define _l4d2_mission_controller_included_

#include <l4d2_mission_manager>

#define LIBRARY_L4D2MISSIONCONTROLLER "l4d2_mission_controller"

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
 * Returns whether the competitive finale feature is enabled by cvar.
 *
 * @return              True if the feature is enabled.
 */
native bool L4D2MC_IsCompetitiveFinaleEnabled();

/**
 * Returns whether the competitive finale will apply on the current map flow.
 *
 * This requires:
 * - Versus mode
 * - Confogl match mode loaded
 * - `sm_mc_competitive_finale` enabled
 * - no admin or vote override disabling it for the current campaign
 *
 * @return              True if the competitive finale will apply.
 */
native bool L4D2MC_WillApplyCompetitiveFinale();

/**
 * Returns whether the current map is the competitive finale map.
 *
 * @return              True if the current map is treated as the competitive finale.
 */
native bool L4D2MC_IsCurrentMapCompetitiveFinale();

/**
 * Enables or disables the competitive finale for the current campaign.
 *
 * Passing true disables the competitive finale locally for the active campaign.
 * Passing false restores it.
 *
 * @param disabled      Whether to disable the competitive finale for the current campaign.
 * @return              True on success.
 */
native bool L4D2MC_SetCompetitiveFinaleDisabled(bool disabled);

/**
 * Fired whenever the effective next map target changes.
 *
 * @param mapName       Effective next map target. Empty if none exists.
 * @param voteOverride  True if the effective target comes from a vote override.
 */
forward void L4D2MC_OnNextMapChanged(const char[] mapName, bool voteOverride);

/**
 * Fired whenever the competitive finale state changes.
 *
 * @param enabled                   True if the competitive finale feature is enabled by cvar.
 * @param active                    True if the competitive finale will apply in the current context.
 * @param disabled                  True if the competitive finale is disabled for the current campaign.
 * @param currentMapCompetitiveFinale True if the current map is the competitive finale.
 */
forward void L4D2MC_OnCompetitiveFinaleChanged(bool enabled, bool active, bool disabled, bool currentMapCompetitiveFinale);

public SharedPlugin __pl_l4d2_mission_controller =
{
	name = LIBRARY_L4D2MISSIONCONTROLLER,
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
	MarkNativeAsOptional("L4D2MC_IsCompetitiveFinaleEnabled");
	MarkNativeAsOptional("L4D2MC_WillApplyCompetitiveFinale");
	MarkNativeAsOptional("L4D2MC_IsCurrentMapCompetitiveFinale");
	MarkNativeAsOptional("L4D2MC_SetCompetitiveFinaleDisabled");
}
#endif
