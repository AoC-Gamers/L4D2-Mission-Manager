enum MissionParserState
{
	MPS_UNKNOWN = -1,
	MPS_ROOT = 0,
	MPS_MISSION = 1,
	MPS_MODES = 2,
	MPS_GAMEMODE = 3,
	MPS_MAP = 4
};

int g_MissionParser_UnknownCurLayer;
MissionParserState g_MissionParser_UnknownPreState;
MissionParserState g_MissionParser_State;

int g_MissionParser_CurGameMode;
char g_MissionParser_MissionName[LEN_MISSION_NAME];
int g_MissionParser_CurMapID;
ArrayList g_hIntMap_Index;
ArrayList g_hStrMap_FileName;

public SMCResult MissionParser_NewSection(SMCParser smc, const char[] name, bool opt_quotes)
{
	switch (g_MissionParser_State)
	{
		case MPS_ROOT:
		{
			if (strcmp("mission", name, false) == 0)
			{
				g_MissionParser_State = MPS_MISSION;
			}
			else {
				g_MissionParser_UnknownPreState = g_MissionParser_State;
				g_MissionParser_UnknownCurLayer = 1;
				g_MissionParser_State = MPS_UNKNOWN;
			}
		}
		case MPS_MISSION:
		{
			if (StrEqual("modes", name, false))
			{
				g_MissionParser_State = MPS_MODES;
			}
			else {
				g_MissionParser_UnknownPreState = g_MissionParser_State;
				g_MissionParser_UnknownCurLayer = 1;
				g_MissionParser_State = MPS_UNKNOWN;
			}
		}
		case MPS_MODES:
		{
			g_MissionParser_CurGameMode = MM_InternalResolveBasicGamemode(name);
			if (g_MissionParser_CurGameMode == GAMEMODE_UNKNOWN)
			{
				g_MissionParser_UnknownPreState = g_MissionParser_State;
				g_MissionParser_UnknownCurLayer = 1;
				g_MissionParser_State = MPS_UNKNOWN;
			}
			else {
				g_hIntMap_Index.Clear();
				g_hStrMap_FileName.Clear();
				g_MissionParser_State = MPS_GAMEMODE;
			}
		}
		case MPS_GAMEMODE:
		{
			int mapID = StringToInt(name);
			if (mapID > 0)
			{
				g_MissionParser_State = MPS_MAP;
				g_MissionParser_CurMapID = mapID;
			}
			else {
				g_MissionParser_UnknownPreState = g_MissionParser_State;
				g_MissionParser_UnknownCurLayer = 1;
				g_MissionParser_State = MPS_UNKNOWN;
			}
		}
		case MPS_MAP:
		{
			g_MissionParser_UnknownPreState = g_MissionParser_State;
			g_MissionParser_UnknownCurLayer = 1;
			g_MissionParser_State = MPS_UNKNOWN;
		}
		case MPS_UNKNOWN:
		{
			g_MissionParser_UnknownCurLayer++;
		}
	}

	return SMCParse_Continue;
}

public SMCResult MissionParser_KeyValue(SMCParser smc, const char[] key, const char[] value, bool key_quotes, bool value_quotes)
{
	switch (g_MissionParser_State)
	{
		case MPS_MISSION:
		{
			if (strcmp("Name", key, false) == 0)
			{
				strcopy(g_MissionParser_MissionName, LEN_MISSION_NAME, value);
			}
		}
		case MPS_MAP:
		{
			if (StrEqual("Map", key, false))
			{
				g_hIntMap_Index.Push(g_MissionParser_CurMapID);
				char mapFileName[LEN_MAP_FILENAME];
				String_ToLower(value, mapFileName, sizeof(mapFileName));
				g_hStrMap_FileName.PushString(mapFileName);
			}
		}
	}

	return SMCParse_Continue;
}

public SMCResult MissionParser_EndSection(SMCParser smc)
{
	switch (g_MissionParser_State)
	{
		case MPS_MISSION:
		{
			g_MissionParser_State = MPS_ROOT;
		}
		case MPS_MODES:
		{
			g_MissionParser_State = MPS_MISSION;
		}
		case MPS_GAMEMODE:
		{
			g_MissionParser_State = MPS_MODES;

			int numOfValidMaps = 0;
			int numOfIgnoredInvalidMaps = 0;
			char mapFile[LEN_MAP_FILENAME];
			int mapCount = g_hIntMap_Index.Length;

			for (int mapArrayIndex = 0; mapArrayIndex < mapCount; mapArrayIndex++)
			{
				int expectedMapIndex = mapArrayIndex + 1;
				if (g_hIntMap_Index.Get(mapArrayIndex) != expectedMapIndex)
				{
					char gamemodeName[LEN_GAMEMODE_NAME];
					MM_InternalGamemodeToString(g_MissionParser_CurGameMode, gamemodeName, sizeof(gamemodeName));
					if (g_hStr_InvalidMissionNames.FindString(g_MissionParser_MissionName) < 0)
					{
						g_hStr_InvalidMissionNames.PushString(g_MissionParser_MissionName);
					}
					LogToFile(g_sLogPath, "Mission %s contains invalid \"%s\" section", g_MissionParser_MissionName, gamemodeName);
					return SMCParse_HaltFail;
				}

				g_hStrMap_FileName.GetString(mapArrayIndex, mapFile, sizeof(mapFile));
				if (!MM_IsKnownMap(mapFile, g_MissionParser_MissionName, g_MissionParser_CurGameMode))
				{
					if (MM_ShouldIgnoreInvalidMap(mapFile, g_MissionParser_MissionName, g_MissionParser_CurGameMode))
					{
						numOfIgnoredInvalidMaps++;
						continue;
					}

					char gamemodeName[LEN_GAMEMODE_NAME];
					MM_InternalGamemodeToString(g_MissionParser_CurGameMode, gamemodeName, sizeof(gamemodeName));
					if (g_hStr_InvalidMissionNames.FindString(g_MissionParser_MissionName) < 0)
					{
						g_hStr_InvalidMissionNames.PushString(g_MissionParser_MissionName);
					}
					LogToFile(g_sLogPath, "Mission %s contains invalid map not allowed by overrides: \"%s\", gamemode: \"%s\"", g_MissionParser_MissionName, mapFile, gamemodeName);
					return SMCParse_HaltFail;
				}
				numOfValidMaps++;
			}

			if (numOfValidMaps < 1)
			{
				if (numOfIgnoredInvalidMaps > 0)
				{
					return SMCParse_Continue;
				}

				char gamemodeName[LEN_GAMEMODE_NAME];
				MM_InternalGamemodeToString(g_MissionParser_CurGameMode, gamemodeName, sizeof(gamemodeName));
				LogToFile(g_sLogPath, "Mission %s does not contain any valid map in gamemode: \"%s\"", g_MissionParser_MissionName, gamemodeName);
				return SMCParse_Continue;
			}

			ArrayList mapList = MM_GetMapList(g_MissionParser_CurGameMode);

			for (int mapArrayIndex = 0; mapArrayIndex < mapCount; mapArrayIndex++)
			{
				g_hStrMap_FileName.GetString(mapArrayIndex, mapFile, sizeof(mapFile));
				if (!MM_IsKnownMap(mapFile, g_MissionParser_MissionName, g_MissionParser_CurGameMode)
					&& MM_ShouldIgnoreInvalidMap(mapFile, g_MissionParser_MissionName, g_MissionParser_CurGameMode))
				{
					continue;
				}
				mapList.PushString(mapFile);
			}

			ArrayList entryList = MM_GetEntryList(g_MissionParser_CurGameMode);
			int lastOffset = entryList.Get(entryList.Length - 1);
			entryList.Push(lastOffset + mapCount);

			ArrayList missionName = MM_GetMissionNameList(g_MissionParser_CurGameMode);
			missionName.PushString(g_MissionParser_MissionName);
		}
		case MPS_MAP:
		{
			g_MissionParser_State = MPS_GAMEMODE;
		}
		case MPS_UNKNOWN:
		{
			g_MissionParser_UnknownCurLayer--;
			if (g_MissionParser_UnknownCurLayer == 0)
			{
				g_MissionParser_State = g_MissionParser_UnknownPreState;
			}
		}
	}

	return SMCParse_Continue;
}

void ParseMissions()
{
	DirectoryListing dirList;
	dirList = OpenDirectory("missions", true, NULL_STRING);
	MM_Debug(MM_Debug_Parse, "OpenDirectory path=missions use_valve_fs=1 success=%d", dirList != null);

	if (dirList == null)
	{
		LogToFile(g_sLogPath, "[SM] Plugin is not running! Could not locate mission folder");
		SetFailState("Could not locate mission folder");
	}
	else {
		SMCParser parser = SMC_CreateParser();
		parser.OnEnterSection = MissionParser_NewSection;
		parser.OnLeaveSection = MissionParser_EndSection;
		parser.OnKeyValue = MissionParser_KeyValue;

		g_hIntMap_Index = new ArrayList(1);
		g_hStrMap_FileName = new ArrayList(LEN_MAP_FILENAME);

		char missionPath[PLATFORM_MAX_PATH];
		char missionFileName[PLATFORM_MAX_PATH];
		FileType fileType;
		while (dirList.GetNext(missionFileName, PLATFORM_MAX_PATH, fileType))
		{
			if (fileType == FileType_File && strcmp("credits.txt", missionFileName, false) != 0)
			{
				FormatEx(missionPath, sizeof(missionPath), "missions/%s", missionFileName);

				if (MM_IsDebugEnabled(MM_Debug_Parse))
				{
					File missionFileFs = OpenFile(missionPath, "rt", false);
					File missionFileValve = OpenFile(missionPath, "rt", true);
					MM_Debug(
						MM_Debug_Parse,
						"Mission parse candidate name=%s path=%s exists_fs=%d open_fs=%d open_valve=%d",
						missionFileName,
						missionPath,
						FileExists(missionPath, false),
						missionFileFs != null,
						missionFileValve != null
					);
					delete missionFileFs;
					delete missionFileValve;
				}

				g_MissionParser_State = MPS_ROOT;
				int line = 0;
				int col = 0;
				SMCError err = MM_ParseValveFsFile(parser, missionPath, line, col);
				if (err != SMCError_Okay)
				{
					g_hStr_InvalidMissionNames.PushString(missionPath);
					LogToFile(g_sLogPath, "An error occured while parsing %s, code:%d, line:%d, col:%d", missionPath, err, line, col);
				}
				else
				{
					MM_Debug(MM_Debug_Parse, "Mission parsed successfully path=%s", missionPath);
				}
			}
		}

		delete parser;
		delete g_hIntMap_Index;
		delete g_hStrMap_FileName;
		delete dirList;
		g_hIntMap_Index = null;
		g_hStrMap_FileName = null;
	}
}

