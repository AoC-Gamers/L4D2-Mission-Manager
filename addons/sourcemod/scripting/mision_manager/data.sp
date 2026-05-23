ArrayList g_hStr_InvalidMissionNames;

ArrayList g_hStr_MissionNames[COUNT_MM_GAMEMODE];
ArrayList g_hInt_Entries[COUNT_MM_GAMEMODE];
ArrayList g_hStr_Maps[COUNT_MM_GAMEMODE];

void MM_LoadCustomMapOverrides()
{
	char path[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, path, sizeof(path), MM_CUSTOM_MAPS_CONFIG);

	delete g_smCustomMaps;
	g_smCustomMaps = new StringMap();
	delete g_smIgnoredInvalidMaps;
	g_smIgnoredInvalidMaps = new StringMap();

	KeyValues kv = new KeyValues("MissionManagerCustomMaps");
	if (!kv.ImportFromFile(path))
	{
		MM_DebugLog("Custom map override config not found path=%s", path);
		delete kv;
		return;
	}

	int loaded = 0;
	if (kv.JumpToKey("missions", false) && kv.GotoFirstSubKey(false))
	{
		char missionName[LEN_MISSION_NAME];
		do
		{
			kv.GetSectionName(missionName, sizeof(missionName));
			loaded += MM_LoadCustomMapsFromScope(kv, missionName, "");
			loaded += MM_LoadIgnoredInvalidMapsFromScope(kv, missionName, "");
			loaded += MM_LoadCustomMapsFromGamemodeScopes(kv, missionName);
			loaded += MM_LoadIgnoredInvalidMapsFromGamemodeScopes(kv, missionName);
		}
		while (kv.GotoNextKey(false));
	}

	delete kv;
	MM_DebugLog("Loaded custom map overrides count=%d path=%s", loaded, path);
}

int MM_LoadCustomMapsFromGamemodeScopes(KeyValues kv, const char[] missionName)
{
	int loaded = 0;
	char gamemodeName[LEN_GAMEMODE_NAME];

	for (int i = 0; i < COUNT_MM_GAMEMODE; i++)
	{
		MM_InternalGamemodeToString(MM_InternalGamemodeFromIndex(i), gamemodeName, sizeof(gamemodeName));
		if (!kv.JumpToKey(gamemodeName, false))
		{
			continue;
		}

		loaded += MM_LoadCustomMapsFromScope(kv, missionName, gamemodeName);
		kv.GoBack();
	}

	return loaded;
}

int MM_LoadIgnoredInvalidMapsFromGamemodeScopes(KeyValues kv, const char[] missionName)
{
	int loaded = 0;
	char gamemodeName[LEN_GAMEMODE_NAME];

	for (int i = 0; i < COUNT_MM_GAMEMODE; i++)
	{
		MM_InternalGamemodeToString(MM_InternalGamemodeFromIndex(i), gamemodeName, sizeof(gamemodeName));
		if (!kv.JumpToKey(gamemodeName, false))
		{
			continue;
		}

		loaded += MM_LoadIgnoredInvalidMapsFromScope(kv, missionName, gamemodeName);
		kv.GoBack();
	}

	return loaded;
}

int MM_LoadCustomMapsFromScope(KeyValues kv, const char[] missionName, const char[] gamemodeName)
{
	if (!kv.JumpToKey("maps", false))
	{
		return 0;
	}

	int loaded = 0;
	if (kv.GotoFirstSubKey(false))
	{
		char mapName[LEN_MAP_FILENAME];
		do
		{
			kv.GetSectionName(mapName, sizeof(mapName));
			MM_RegisterCustomMapOverride(mapName, missionName, gamemodeName);
			loaded++;
		}
		while (kv.GotoNextKey(false));

		kv.GoBack();
	}

	kv.GoBack();
	return loaded;
}

int MM_LoadIgnoredInvalidMapsFromScope(KeyValues kv, const char[] missionName, const char[] gamemodeName)
{
	if (!kv.JumpToKey("ignore_invalid_maps", false))
	{
		return 0;
	}

	int loaded = 0;
	if (kv.GotoFirstSubKey(false))
	{
		char mapName[LEN_MAP_FILENAME];
		do
		{
			kv.GetSectionName(mapName, sizeof(mapName));
			MM_RegisterIgnoredInvalidMap(mapName, missionName, gamemodeName);
			loaded++;
		}
		while (kv.GotoNextKey(false));

		kv.GoBack();
	}

	kv.GoBack();
	return loaded;
}

void MM_RegisterCustomMapOverride(const char[] mapFile, const char[] missionName = "", const char[] gamemodeName = "")
{
	MM_RegisterScopedMapKey(g_smCustomMaps, mapFile, missionName, gamemodeName);
}

void MM_RegisterIgnoredInvalidMap(const char[] mapFile, const char[] missionName = "", const char[] gamemodeName = "")
{
	MM_RegisterScopedMapKey(g_smIgnoredInvalidMaps, mapFile, missionName, gamemodeName);
}

void MM_RegisterScopedMapKey(StringMap store, const char[] mapFile, const char[] missionName = "", const char[] gamemodeName = "")
{
	char normalizedMap[LEN_MAP_FILENAME];
	char normalizedMission[LEN_MISSION_NAME];
	char normalizedGamemode[LEN_GAMEMODE_NAME];
	char overrideKey[192];

	String_ToLower(mapFile, normalizedMap, sizeof(normalizedMap));
	String_ToLower(missionName, normalizedMission, sizeof(normalizedMission));
	String_ToLower(gamemodeName, normalizedGamemode, sizeof(normalizedGamemode));

	if (normalizedMission[0] != '\0' && normalizedGamemode[0] != '\0')
	{
		FormatEx(overrideKey, sizeof(overrideKey), "mode:%s:%s:%s", normalizedMission, normalizedGamemode, normalizedMap);
	}
	else if (normalizedMission[0] != '\0')
	{
		FormatEx(overrideKey, sizeof(overrideKey), "mission:%s:%s", normalizedMission, normalizedMap);
	}
	else {
		return;
	}

	store.SetValue(overrideKey, 1, true);
}

bool MM_HasScopedMapKey(StringMap store, const char[] mapFile, const char[] missionName, int gamemode)
{
	if (store == null)
	{
		return false;
	}

	char normalizedMap[LEN_MAP_FILENAME];
	char normalizedMission[LEN_MISSION_NAME];
	char gamemodeName[LEN_GAMEMODE_NAME];
	char overrideKey[192];
	int dummy = 0;

	String_ToLower(mapFile, normalizedMap, sizeof(normalizedMap));
	String_ToLower(missionName, normalizedMission, sizeof(normalizedMission));

	if (gamemode != GAMEMODE_UNKNOWN && MM_InternalGamemodeToString(gamemode, gamemodeName, sizeof(gamemodeName)))
	{
		String_ToLower(gamemodeName, gamemodeName, sizeof(gamemodeName));
		FormatEx(overrideKey, sizeof(overrideKey), "mode:%s:%s:%s", normalizedMission, gamemodeName, normalizedMap);
		if (store.GetValue(overrideKey, dummy))
		{
			return true;
		}
	}

	FormatEx(overrideKey, sizeof(overrideKey), "mission:%s:%s", normalizedMission, normalizedMap);
	return store.GetValue(overrideKey, dummy);
}

bool MM_IsKnownMap(const char[] mapFile, const char[] missionName, int gamemode)
{
	if (IsMapValid(mapFile))
	{
		return true;
	}

	return MM_HasScopedMapKey(g_smCustomMaps, mapFile, missionName, gamemode);
}

bool MM_ShouldIgnoreInvalidMap(const char[] mapFile, const char[] missionName, int gamemode)
{
	return MM_HasScopedMapKey(g_smIgnoredInvalidMaps, mapFile, missionName, gamemode);
}

void MM_InitLists()
{
	g_hStr_InvalidMissionNames = new ArrayList(LEN_MISSION_NAME);

	for (int i = 0; i < COUNT_MM_GAMEMODE; i++)
	{
		g_hStr_MissionNames[i] = new ArrayList(LEN_MISSION_NAME);
		g_hInt_Entries[i] = new ArrayList(1);
		g_hInt_Entries[i].Push(0);
		g_hStr_Maps[i] = new ArrayList(LEN_MAP_FILENAME);
	}
}

void MM_FreeLists()
{
	delete g_hStr_InvalidMissionNames;
	g_hStr_InvalidMissionNames = null;

	for (int i = 0; i < COUNT_MM_GAMEMODE; i++)
	{
		delete g_hStr_MissionNames[i];
		delete g_hInt_Entries[i];
		delete g_hStr_Maps[i];
		g_hStr_MissionNames[i] = null;
		g_hInt_Entries[i] = null;
		g_hStr_Maps[i] = null;
	}
}

ArrayList MM_GetMissionNameList(int gamemode)
{
	return g_hStr_MissionNames[MM_InternalGamemodeToIndex(gamemode)];
}

ArrayList MM_GetEntryList(int gamemode)
{
	return g_hInt_Entries[MM_InternalGamemodeToIndex(gamemode)];
}

ArrayList MM_GetMapList(int gamemode)
{
	return g_hStr_Maps[MM_InternalGamemodeToIndex(gamemode)];
}

public int Native_GetNumberOfMissions(Handle plugin, int numParams)
{
	if (numParams < 1)
		return -1;

	int gamemode = GetNativeCell(1);
	if (!MM_InternalIsValidGamemode(gamemode))
		return -1;

	return g_hStr_MissionNames[MM_InternalGamemodeToIndex(gamemode)].Length;
}

public int Native_FindMissionIndexByName(Handle plugin, int numParams)
{
	if (numParams < 2)
		return -1;

	int gamemode = GetNativeCell(1);
	if (!MM_InternalIsValidGamemode(gamemode))
		return -1;
	int length;
	GetNativeStringLength(2, length);
	char[] missionName = new char[length + 1];
	GetNativeString(2, missionName, length + 1);

	ArrayList missionNameList = MM_GetMissionNameList(gamemode);
	if (missionNameList == null)
		return -1;

	return missionNameList.FindString(missionName);
}

public int Native_GetMissionName(Handle plugin, int numParams)
{
	if (numParams < 4)
		return -1;

	int gamemode = GetNativeCell(1);
	if (!MM_InternalIsValidGamemode(gamemode))
		return -1;
	int missionIndex = GetNativeCell(2);
	int length = GetNativeCell(4);

	ArrayList missionNameList = MM_GetMissionNameList(gamemode);
	if (missionNameList == null)
		return -1;

	char missionName[LEN_MISSION_NAME];
	missionNameList.GetString(missionIndex, missionName, sizeof(missionName));

	if (SetNativeString(3, missionName, length, false) != SP_ERROR_NONE)
		return -1;

	return 0;
}

public int Native_GetMissionLocalizedName(Handle plugin, int numParams)
{
	if (numParams < 4)
		return -1;

	int gamemode = GetNativeCell(1);
	if (!MM_InternalIsValidGamemode(gamemode))
		return -1;
	int missionIndex = GetNativeCell(2);
	int length = GetNativeCell(4);
	int client = GetNativeCell(5);

	ArrayList missionNameList = MM_GetMissionNameList(gamemode);
	if (missionNameList == null)
		return -1;

	char missionName[LEN_MISSION_NAME];
	missionNameList.GetString(missionIndex, missionName, sizeof(missionName));

	char localizedName[LEN_LOCALIZED_NAME];
	if (MM_TryGetLocalizedPhrase(missionName, client, localizedName, sizeof(localizedName)))
	{
		if (SetNativeString(3, localizedName, length, false) != SP_ERROR_NONE)
			return -1;
		return 1;
	}

	if (SetNativeString(3, missionName, length, false) != SP_ERROR_NONE)
		return -1;
	return 0;
}

public int Native_GetNumberOfMaps(Handle plugin, int numParams)
{
	if (numParams < 2)
		return -1;

	int gamemode = GetNativeCell(1);
	if (!MM_InternalIsValidGamemode(gamemode))
		return -1;
	int missionIndex = GetNativeCell(2);

	ArrayList entryList = MM_GetEntryList(gamemode);
	if (entryList == null)
		return -1;

	if (missionIndex > entryList.Length - 1)
		return -1;

	int startMapIndex = entryList.Get(missionIndex);
	int endMapIndex = entryList.Get(missionIndex + 1);

	return endMapIndex - startMapIndex;
}

public int Native_FindMapIndexByName(Handle plugin, int numParams)
{
	if (numParams < 3)
		return -1;

	int gamemode = GetNativeCell(1);
	if (!MM_InternalIsValidGamemode(gamemode))
		return -1;
	int length;
	GetNativeStringLength(3, length);
	char[] mapName = new char[length + 1];
	GetNativeString(3, mapName, length + 1);

	String_ToLower(mapName, mapName, length + 1);

	ArrayList mapList = MM_GetMapList(gamemode);
	if (mapList == null)
		return -1;

	ArrayList entryList = MM_GetEntryList(gamemode);

	int mapPos = mapList.FindString(mapName);
	if (mapPos < 0)
		return -1;

	int startMapIndex = 0;
	for (int nextMissionIndex = 1; nextMissionIndex < mapList.Length + 1; nextMissionIndex++)
	{
		int nextStartMapIndex = entryList.Get(nextMissionIndex);

		if (startMapIndex <= mapPos && mapPos < nextStartMapIndex)
		{
			SetNativeCellRef(2, nextMissionIndex - 1);
			return mapPos - startMapIndex;
		}

		startMapIndex = nextStartMapIndex;
	}

	return -1;
}

public int Native_GetMapName(Handle plugin, int numParams)
{
	if (numParams < 5)
		return -1;

	int gamemode = GetNativeCell(1);
	if (!MM_InternalIsValidGamemode(gamemode))
		return -1;
	int missionIndex = GetNativeCell(2);
	int mapIndex = GetNativeCell(3);
	int length = GetNativeCell(5);

	ArrayList entryList = MM_GetEntryList(gamemode);
	if (entryList == null)
		return -1;

	if (missionIndex > entryList.Length - 1)
		return -1;

	int mapIndexOffset = entryList.Get(missionIndex);
	ArrayList mapList = MM_GetMapList(gamemode);

	char mapName[LEN_MAP_FILENAME];
	mapList.GetString(mapIndexOffset + mapIndex, mapName, sizeof(mapName));

	if (SetNativeString(4, mapName, length, false) != SP_ERROR_NONE)
		return -1;

	return 0;
}

public int Native_GetMapLocalizedName(Handle plugin, int numParams)
{
	if (numParams < 4)
		return -1;

	int gamemode = GetNativeCell(1);
	if (!MM_InternalIsValidGamemode(gamemode))
		return -1;
	int missionIndex = GetNativeCell(2);
	int mapIndex = GetNativeCell(3);
	int length = GetNativeCell(5);
	int client = GetNativeCell(6);

	ArrayList entryList = MM_GetEntryList(gamemode);
	if (entryList == null)
		return -1;

	ArrayList mapList = MM_GetMapList(gamemode);
	char mapFileName[LEN_MAP_FILENAME];
	int offset = entryList.Get(missionIndex);
	mapList.GetString(offset + mapIndex, mapFileName, sizeof(mapFileName));

	char localizedName[LEN_LOCALIZED_NAME];
	if (MM_TryGetLocalizedPhrase(mapFileName, client, localizedName, sizeof(localizedName)))
	{
		if (SetNativeString(4, localizedName, length, false) != SP_ERROR_NONE)
			return -1;
		return 1;
	}

	if (SetNativeString(4, mapFileName, length, false) != SP_ERROR_NONE)
		return -1;
	return 0;
}

public int Native_GetMapUniqueID(Handle plugin, int numParams)
{
	if (numParams < 3)
		return -1;

	int gamemode = GetNativeCell(1);
	if (!MM_InternalIsValidGamemode(gamemode))
		return -1;
	int missionIndex = GetNativeCell(2);
	int mapIndex = GetNativeCell(3);

	if (missionIndex < 0)
		return -1;

	ArrayList entryList = MM_GetEntryList(gamemode);
	if (entryList == null)
		return -1;

	if (missionIndex > entryList.Length - 2)
		return -1;

	int offset = entryList.Get(missionIndex);
	return offset + mapIndex;
}

public int Native_DecodeMapUniqueID(Handle plugin, int numParams)
{
	if (numParams < 3)
		return -1;

	int gamemode = GetNativeCell(1);
	if (!MM_InternalIsValidGamemode(gamemode))
		return -1;
	int mapPos = GetNativeCell(3);

	ArrayList mapList = MM_GetMapList(gamemode);
	if (mapList == null)
		return -1;

	ArrayList entryList = MM_GetEntryList(gamemode);

	int startMapIndex = 0;
	for (int nextMissionIndex = 1; nextMissionIndex < mapList.Length + 1; nextMissionIndex++)
	{
		int nextStartMapIndex = entryList.Get(nextMissionIndex);

		if (startMapIndex <= mapPos && mapPos < nextStartMapIndex)
		{
			SetNativeCellRef(2, nextMissionIndex - 1);
			return mapPos - startMapIndex;
		}

		startMapIndex = nextStartMapIndex;
	}

	return -1;
}

public int Native_GetMapUniqueIDCount(Handle plugin, int numParams)
{
	if (numParams < 1)
		return -1;

	int gamemode = GetNativeCell(1);
	if (!MM_InternalIsValidGamemode(gamemode))
		return -1;

	ArrayList mapList = MM_GetMapList(gamemode);
	if (mapList == null)
		return -1;

	return mapList.Length;
}

public int Native_GetNumberOfInvalidMissions(Handle plugin, int numParams)
{
	return g_hStr_InvalidMissionNames.Length;
}

public int Native_GetInvalidMissionName(Handle plugin, int numParams)
{
	if (numParams < 2)
		return -1;

	int missionIndex = GetNativeCell(1);
	int length = GetNativeCell(3);

	char missionName[LEN_MISSION_NAME];
	g_hStr_InvalidMissionNames.GetString(missionIndex, missionName, sizeof(missionName));

	if (SetNativeString(2, missionName, length, false) != SP_ERROR_NONE)
		return -1;

	return 0;
}

