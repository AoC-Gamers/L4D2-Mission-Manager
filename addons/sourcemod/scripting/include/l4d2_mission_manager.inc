#if defined _l4d2_mission_manager_included_
	#endinput
#endif
#define _l4d2_mission_manager_included_

#include <left4dhooks>

#define LEN_MISSION_NAME 64		// e.g. L4D2C1
#define LEN_MAP_FILENAME 64		// e.g. c1m1_hotel
#define LEN_GAMEMODE_NAME 32	// e.g. coop, versus, scavenge, survival
#define LEN_LOCALIZED_NAME 64

/**
 * Converts a gamemode name string to an L4D2MM gamemode.
 *
 * @param name          Gamemode name to convert.
 * @return              Matching game mode, or GAMEMODE_UNKNOWN if the name is not recognized.
 */
native int L4D2MM_StringToGamemode(const char[] name);

/**
 * Converts an L4D2MM gamemode to its string representation.
 *
 * @param gamemode      Game mode to convert.
 * @param name          Buffer to store the gamemode name.
 * @param length        Maximum size of the output buffer.
 * @return              Number of bytes written to the buffer, including the null terminator, or 0 on failure.
 */
native int L4D2MM_GamemodeToString(int gamemode, char[] name, int length);

/**
 * Retrieves the number of missions available for a gamemode.
 *
 * @param gamemode      Gamemode to query.
 * @return              Number of missions for the gamemode, or 0 if the gamemode is invalid.
 */
native int L4D2MM_GetNumberOfMissions(int gamemode);

/**
 * Finds a mission index by mission name.
 *
 * @param gamemode      Gamemode to query.
 * @param missionName   Mission name to search for.
 * @return              Mission index on success, or -1 if the mission was not found.
 */
native int L4D2MM_FindMissionIndexByName(int gamemode, const char[] missionName);

/**
 * Retrieves the mission name for a mission index.
 *
 * @param gamemode      Gamemode to query.
 * @param missionIndex  Mission index to read.
 * @param missionName   Buffer to store the mission name.
 * @param length        Maximum size of the output buffer.
 * @return              Number of bytes written to the buffer, including the null terminator, or 0 on failure.
 */
native int L4D2MM_GetMissionName(int gamemode, int missionIndex, char[] missionName, int length);
/**
 * Retrieves the localized mission name for a mission index.
 *
 * @param gamemode      Gamemode to query.
 * @param missionIndex  Mission index to read.
 * @param missionName   Buffer to store the localized mission name.
 * @param length        Maximum size of the output buffer.
 * @param client        Client whose language should be used for localization.
 * @return              1 on success, 0 if no localization exists, or -1 on error.
 */
native int L4D2MM_GetMissionLocalizedName(int gamemode, int missionIndex, char[] missionName, int length, int client);

/**
 * Retrieves the number of maps in a mission.
 *
 * @param gamemode      Gamemode to query.
 * @param missionIndex  Mission index to query.
 * @return              Number of maps in the mission, or 0 on failure.
 */
native int L4D2MM_GetNumberOfMaps(int gamemode, int missionIndex);

/**
 * Finds a map index by map name and returns the corresponding mission index.
 *
 * @param gamemode      Gamemode to query.
 * @param missionIndex  Receives the mission index of the located map.
 * @param mapName       Map name to search for.
 * @return              Map index on success, or -1 if the map was not found.
 */
native int L4D2MM_FindMapIndexByName(int gamemode, int& missionIndex, const char[] mapName);

/**
 * Retrieves the map name for a mission/map index pair.
 *
 * @param gamemode      Gamemode to query.
 * @param missionIndex  Mission index to query.
 * @param mapIndex      Map index to read.
 * @param mapName       Buffer to store the map name.
 * @param length        Maximum size of the output buffer.
 * @return              Number of bytes written to the buffer, including the null terminator, or 0 on failure.
 */
native int L4D2MM_GetMapName(int gamemode, int missionIndex, int mapIndex, char[] mapName, int length);
/**
 * Retrieves the localized map name for a mission/map index pair.
 *
 * @param gamemode      Gamemode to query.
 * @param missionIndex  Mission index to query.
 * @param mapIndex      Map index to read.
 * @param mapName       Buffer to store the localized map name.
 * @param length        Maximum size of the output buffer.
 * @param client        Client whose language should be used for localization.
 * @return              1 on success, 0 if no localization exists, or -1 on error.
 * @note                Map names are normalized to lower case internally.
 * @note                Entries in maps.phrases.txt must use lower-case ASCII names.
 */
native int L4D2MM_GetMapLocalizedName(int gamemode, int missionIndex, int mapIndex, char[] mapName, int length, int client);
/**
 * Encodes a mission/map pair into a compact map unique ID.
 *
 * @param gamemode      Gamemode to query.
 * @param missionIndex  Mission index to encode.
 * @param mapIndex      Map index to encode.
 * @return              Encoded map unique ID, or -1 on failure.
 */
native int L4D2MM_GetMapUniqueID(int gamemode, int missionIndex, int mapIndex);
/**
 * Decodes a map unique ID back into mission and map indexes.
 *
 * @param gamemode      Gamemode to query.
 * @param missionIndex  Receives the decoded mission index.
 * @param mapUID        Encoded map unique ID.
 * @return              Decoded map index on success, or -1 on failure.
 */
native int L4D2MM_DecodeMapUniqueID(int gamemode, int& missionIndex, int mapUID);
/**
 * Retrieves the total number of unique map IDs for a gamemode.
 *
 * @param gamemode      Gamemode to query.
 * @return              Number of valid unique map IDs, or 0 on failure.
 */
native int L4D2MM_GetMapUniqueIDCount(int gamemode);

/**
 * Retrieves the number of invalid mission files detected during parsing.
 *
 * @return              Number of invalid missions.
 */
native int L4D2MM_GetNumberOfInvalidMissions();

/**
 * Retrieves the file name or identifier of an invalid mission entry.
 *
 * @param missionIndex  Invalid mission index to read.
 * @param mapName       Buffer to store the invalid mission name.
 * @param length        Maximum size of the output buffer.
 * @return              Number of bytes written to the buffer, including the null terminator, or 0 on failure.
 */
native int L4D2MM_GetInvalidMissionName(int missionIndex, char[] mapName, int length);

/**
 * Called after the mission and localization lists have been built.
 *
 * Do not assume L4D2MM natives are available from your own OnPluginStart(), since
 * your plugin may load before L4D2MM. The safe point to consume L4D2MM natives is
 * OnAllPluginsLoaded() or later, or after this forward has fired.
 */
forward void OnL4D2MMUpdateList();

public SharedPlugin __pl_l4d2_mission_manager =
{
	name = "l4d2_mission_manager",
	file = "l4d2_mission_manager.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};

#if !defined REQUIRE_PLUGIN
public void __pl_l4d2_mission_manager_SetNTVOptional()
{
	MarkNativeAsOptional("L4D2MM_StringToGamemode");
	MarkNativeAsOptional("L4D2MM_GamemodeToString");
	MarkNativeAsOptional("L4D2MM_GetNumberOfMissions");
	MarkNativeAsOptional("L4D2MM_FindMissionIndexByName");
	MarkNativeAsOptional("L4D2MM_GetMissionName");
	MarkNativeAsOptional("L4D2MM_GetMissionLocalizedName");
	MarkNativeAsOptional("L4D2MM_GetNumberOfMaps");
	MarkNativeAsOptional("L4D2MM_FindMapIndexByName");
	MarkNativeAsOptional("L4D2MM_GetMapName");
	MarkNativeAsOptional("L4D2MM_GetMapLocalizedName");
	MarkNativeAsOptional("L4D2MM_GetMapUniqueID");
	MarkNativeAsOptional("L4D2MM_DecodeMapUniqueID");
	MarkNativeAsOptional("L4D2MM_GetMapUniqueIDCount");
	MarkNativeAsOptional("L4D2MM_GetNumberOfInvalidMissions");
	MarkNativeAsOptional("L4D2MM_GetInvalidMissionName");
}
#endif

