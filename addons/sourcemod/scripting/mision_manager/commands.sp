bool MM_TryGetRequestedGamemode(int client, int argIndex, int args, int &gamemode)
{
	gamemode = GAMEMODE_UNKNOWN;
	if (args < argIndex)
	{
		return true;
	}

	char gamemodeName[LEN_GAMEMODE_NAME];
	GetCmdArg(argIndex, gamemodeName, sizeof(gamemodeName));
	if (MM_InternalTryParseGamemodeArg(gamemodeName, gamemode))
	{
		return true;
	}

	ReplyToCommand(client, "Invalid gamemode: %s", gamemodeName);
	return false;
}

public Action Command_List(int client, int args)
{
	if (args < 1)
	{
		for (int i = 0; i < COUNT_MM_GAMEMODE; i++)
		{
			DumpMissionInfo(client, MM_InternalGamemodeFromIndex(i));
		}
	}
	else {
		char gamemodeName[LEN_GAMEMODE_NAME];
		GetCmdArg(1, gamemodeName, sizeof(gamemodeName));

		if (StrEqual("invalid", gamemodeName, false))
		{
			int missionCount = L4D2MM_GetNumberOfInvalidMissions();
			ReplyToCommand(client, "Invalid missions (count:%d):", missionCount);
			for (int iMission = 0; iMission < missionCount; iMission++)
			{
				char missionName[LEN_MISSION_NAME];
				L4D2MM_GetInvalidMissionName(iMission, missionName, sizeof(missionName));
				ReplyToCommand(client, ", %s", missionName);
			}
		}
		else {
			int gamemode;
			if (!MM_InternalTryParseGamemodeArg(gamemodeName, gamemode))
			{
				ReplyToCommand(client, "Invalid gamemode: %s", gamemodeName);
				return Plugin_Handled;
			}

			DumpMissionInfo(client, gamemode);
		}
	}
	return Plugin_Handled;
}

public Action Command_MissionInfo(int client, int args)
{
	int requestedGamemode;
	char query[LEN_LOCALIZED_NAME];
	query[0] = '\0';

	if (args >= 1)
	{
		GetCmdArg(1, query, sizeof(query));
	}

	if (!MM_TryGetRequestedGamemode(client, 2, args, requestedGamemode))
		return Plugin_Handled;

	int foundGamemode = GAMEMODE_UNKNOWN;
	int missionIndex = -1;
	if (query[0] == '\0')
	{
		if (!MM_FindCurrentMissionInfo(requestedGamemode, foundGamemode, missionIndex))
		{
			ReplyToCommand(client, "Could not resolve the current mission.");
			return Plugin_Handled;
		}
	}
	else if (!MM_FindMissionInfo(query, requestedGamemode, client, foundGamemode, missionIndex))
	{
		ReplyToCommand(client, "Mission not found: %s", query);
		return Plugin_Handled;
	}

	DumpMissionDetails(client, foundGamemode, missionIndex);
	return Plugin_Handled;
}

public Action Command_MapInfo(int client, int args)
{
	int requestedGamemode;
	char mapName[LEN_MAP_FILENAME];
	mapName[0] = '\0';

	if (args >= 1)
	{
		GetCmdArg(1, mapName, sizeof(mapName));
	}

	if (!MM_TryGetRequestedGamemode(client, 2, args, requestedGamemode))
		return Plugin_Handled;

	int foundGamemode = GAMEMODE_UNKNOWN;
	int missionIndex = -1;
	int mapIndex = -1;
	if (mapName[0] == '\0')
	{
		if (!MM_FindCurrentMissionInfo(requestedGamemode, foundGamemode, missionIndex, mapIndex))
		{
			ReplyToCommand(client, "Could not resolve the current map.");
			return Plugin_Handled;
		}
	}
	else {
		String_ToLower(mapName, mapName, sizeof(mapName));
		if (!MM_FindMapInfo(mapName, requestedGamemode, foundGamemode, missionIndex, mapIndex))
		{
			ReplyToCommand(client, "Map not found: %s", mapName);
			return Plugin_Handled;
		}
	}

	DumpMapDetails(client, foundGamemode, missionIndex, mapIndex);
	return Plugin_Handled;
}

void DumpMissionInfo(int client, int gamemode)
{
	char gamemodeName[LEN_GAMEMODE_NAME];
	MM_InternalGamemodeToString(gamemode, gamemodeName, sizeof(gamemodeName));

	int  missionCount = L4D2MM_GetNumberOfMissions(gamemode);
	char missionName[LEN_MISSION_NAME];
	char mapName[LEN_MAP_FILENAME];
	char localizedName[LEN_LOCALIZED_NAME];

	ReplyToCommand(client, "Gamemode = %s (%d missions)", gamemodeName, missionCount);

	for (int iMission = 0; iMission < missionCount; iMission++)
	{
		L4D2MM_GetMissionName(gamemode, iMission, missionName, sizeof(missionName));
		int mapCount = L4D2MM_GetNumberOfMaps(gamemode, iMission);
		if (L4D2MM_GetMissionLocalizedName(gamemode, iMission, localizedName, sizeof(localizedName), LANG_SERVER) > 0)
		{
			ReplyToCommand(client, "%d. %s <%s> %d maps", iMission + 1, missionName, localizedName, mapCount);
		}
		else {
			ReplyToCommand(client, "%d. !! <%s> (%d maps)", iMission + 1, missionName, mapCount);
		}

		for (int iMap = 0; iMap < mapCount; iMap++)
		{
			L4D2MM_GetMapName(gamemode, iMission, iMap, mapName, sizeof(mapName));
			if (L4D2MM_GetMapLocalizedName(gamemode, iMission, iMap, localizedName, sizeof(localizedName), LANG_SERVER) > 0)
			{
				ReplyToCommand(client, "> %d. %s <%s>", iMap + 1, localizedName, mapName);
			}
			else {
				ReplyToCommand(client, "> %d. !! <%s>", iMap + 1, mapName);
			}
		}
	}
	ReplyToCommand(client, "-------------------");
}

void DumpMissionDetails(int client, int gamemode, int missionIndex)
{
	char gamemodeName[LEN_GAMEMODE_NAME];
	char missionName[LEN_MISSION_NAME];
	char missionLocalized[LEN_LOCALIZED_NAME];
	char mapName[LEN_MAP_FILENAME];
	char mapLocalized[LEN_LOCALIZED_NAME];

	MM_InternalGamemodeToString(gamemode, gamemodeName, sizeof(gamemodeName));
	L4D2MM_GetMissionName(gamemode, missionIndex, missionName, sizeof(missionName));
	int mapCount = L4D2MM_GetNumberOfMaps(gamemode, missionIndex);
	bool hasMissionLocalized = L4D2MM_GetMissionLocalizedName(gamemode, missionIndex, missionLocalized, sizeof(missionLocalized), LANG_SERVER) > 0;

	ReplyToCommand(client, "Mission %s | gamemode=%s | index=%d | maps=%d", missionName, gamemodeName, missionIndex, mapCount);
	if (hasMissionLocalized)
	{
		ReplyToCommand(client, "Localized name: %s", missionLocalized);
	}

	for (int iMap = 0; iMap < mapCount; iMap++)
	{
		L4D2MM_GetMapName(gamemode, missionIndex, iMap, mapName, sizeof(mapName));
		if (L4D2MM_GetMapLocalizedName(gamemode, missionIndex, iMap, mapLocalized, sizeof(mapLocalized), LANG_SERVER) > 0)
		{
			ReplyToCommand(client, "%d. %s <%s>", iMap + 1, mapName, mapLocalized);
		}
		else {
			ReplyToCommand(client, "%d. %s", iMap + 1, mapName);
		}
	}
	ReplyToCommand(client, "-------------------");
}

void DumpMapDetails(int client, int gamemode, int missionIndex, int mapIndex)
{
	char gamemodeName[LEN_GAMEMODE_NAME];
	char missionName[LEN_MISSION_NAME];
	char missionLocalized[LEN_LOCALIZED_NAME];
	char mapName[LEN_MAP_FILENAME];
	char mapLocalized[LEN_LOCALIZED_NAME];

	MM_InternalGamemodeToString(gamemode, gamemodeName, sizeof(gamemodeName));
	L4D2MM_GetMissionName(gamemode, missionIndex, missionName, sizeof(missionName));
	L4D2MM_GetMapName(gamemode, missionIndex, mapIndex, mapName, sizeof(mapName));
	int uniqueId = L4D2MM_GetMapUniqueID(gamemode, missionIndex, mapIndex);
	int mapCount = L4D2MM_GetNumberOfMaps(gamemode, missionIndex);

	ReplyToCommand(client, "Map %s | gamemode=%s | mission=%s | map_index=%d/%d | uid=%d", mapName, gamemodeName, missionName, mapIndex + 1, mapCount, uniqueId);
	if (L4D2MM_GetMissionLocalizedName(gamemode, missionIndex, missionLocalized, sizeof(missionLocalized), LANG_SERVER) > 0)
	{
		ReplyToCommand(client, "Mission localized: %s", missionLocalized);
	}
	if (L4D2MM_GetMapLocalizedName(gamemode, missionIndex, mapIndex, mapLocalized, sizeof(mapLocalized), LANG_SERVER) > 0)
	{
		ReplyToCommand(client, "Map localized: %s", mapLocalized);
	}
	ReplyToCommand(client, "-------------------");
}

bool MM_FindCurrentMissionInfo(int requestedGamemode, int &foundGamemode, int &missionIndex, int &mapIndex = -1)
{
	char currentMap[LEN_MAP_FILENAME];
	GetCurrentMap(currentMap, sizeof(currentMap));
	String_ToLower(currentMap, currentMap, sizeof(currentMap));

	return MM_FindMapInfo(currentMap, requestedGamemode, foundGamemode, missionIndex, mapIndex);
}

bool MM_FindMissionInfo(const char[] query, int requestedGamemode, int client, int &foundGamemode, int &missionIndex)
{
	char localizedName[LEN_LOCALIZED_NAME];
	char missionName[LEN_MISSION_NAME];

	for (int i = 0; i < COUNT_MM_GAMEMODE; i++)
	{
		int gamemode = MM_InternalGamemodeFromIndex(i);
		if (requestedGamemode != GAMEMODE_UNKNOWN && gamemode != requestedGamemode)
		{
			continue;
		}

		int missionCount = L4D2MM_GetNumberOfMissions(gamemode);
		for (int iMission = 0; iMission < missionCount; iMission++)
		{
			L4D2MM_GetMissionName(gamemode, iMission, missionName, sizeof(missionName));
			if (StrEqual(query, missionName, false))
			{
				foundGamemode = gamemode;
				missionIndex = iMission;
				return true;
			}

			if (L4D2MM_GetMissionLocalizedName(gamemode, iMission, localizedName, sizeof(localizedName), client) > 0
				&& StrEqual(query, localizedName, false))
			{
				foundGamemode = gamemode;
				missionIndex = iMission;
				return true;
			}
		}
	}

	return false;
}

bool MM_FindMapInfo(const char[] mapName, int requestedGamemode, int &foundGamemode, int &missionIndex, int &mapIndex)
{
	for (int i = 0; i < COUNT_MM_GAMEMODE; i++)
	{
		int gamemode = MM_InternalGamemodeFromIndex(i);
		if (requestedGamemode != GAMEMODE_UNKNOWN && gamemode != requestedGamemode)
		{
			continue;
		}

		int foundMissionIndex = -1;
		int foundMapIndex = L4D2MM_FindMapIndexByName(gamemode, foundMissionIndex, mapName);
		if (foundMapIndex > -1 && foundMissionIndex > -1)
		{
			foundGamemode = gamemode;
			missionIndex = foundMissionIndex;
			mapIndex = foundMapIndex;
			return true;
		}
	}

	return false;
}


