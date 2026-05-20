ArrayList g_hBool_MissionNameLocalized[COUNT_MM_GAMEMODE];
ArrayList g_hBool_MapNameLocalized[COUNT_MM_GAMEMODE];

void MM_NewLocalizedList(int gamemode)
{
	ArrayList missionLocalizedList = new ArrayList(1, L4D2MM_GetNumberOfMissions(gamemode));
	ArrayList mapLocalizedList = new ArrayList(1, MM_GetMapList(gamemode).Length);

	g_hBool_MissionNameLocalized[MM_InternalGamemodeToIndex(gamemode)] = missionLocalizedList;
	g_hBool_MapNameLocalized[MM_InternalGamemodeToIndex(gamemode)] = mapLocalizedList;

	for (int i = 0; i < missionLocalizedList.Length; i++)
	{
		missionLocalizedList.Set(i, 0, 0);
	}

	for (int i = 0; i < mapLocalizedList.Length; i++)
	{
		mapLocalizedList.Set(i, 0, 0);
	}
}

void MM_FreeLocalizedLists()
{
	for (int gamemode = 0; gamemode < COUNT_MM_GAMEMODE; gamemode++)
	{
		delete g_hBool_MissionNameLocalized[gamemode];
		delete g_hBool_MapNameLocalized[gamemode];
		g_hBool_MissionNameLocalized[gamemode] = null;
		g_hBool_MapNameLocalized[gamemode] = null;
	}
}

ArrayList MM_GetMissionLocalizedList(int gamemode)
{
	return g_hBool_MissionNameLocalized[MM_InternalGamemodeToIndex(gamemode)];
}

ArrayList MM_GetMapLocalizedList(int gamemode)
{
	return g_hBool_MapNameLocalized[MM_InternalGamemodeToIndex(gamemode)];
}

enum LocalizationParserState
{
	MNLS_UNKNOWN = -1,
	MNLS_ROOT = 0,
	MNLS_PHRASES = 1
};

int g_MissionNameLocalization_Gamemode;
LocalizationParserState g_MissionNameLocalization_State;
int g_MissionNameLocalization_UnknownCurLayer;
LocalizationParserState g_MissionNameLocalization_UnknownPreState;

public SMCResult LocalizationParser_NewSection(SMCParser smc, const char[] name, bool opt_quotes)
{
	switch (g_MissionNameLocalization_State)
	{
		case MNLS_ROOT:
		{
			if (strcmp("Phrases", name, false) == 0)
			{
				g_MissionNameLocalization_State = MNLS_PHRASES;
			}
			else {
				g_MissionNameLocalization_UnknownPreState = g_MissionNameLocalization_State;
				g_MissionNameLocalization_UnknownCurLayer = 1;
				g_MissionNameLocalization_State = MNLS_UNKNOWN;
			}
		}
		case MNLS_PHRASES:
		{
			int missionIndex;
			int mapIndex = L4D2MM_FindMapIndexByName(g_MissionNameLocalization_Gamemode, missionIndex, name);
			if (mapIndex > -1 && missionIndex > -1)
			{
				ArrayList entryList = MM_GetEntryList(g_MissionNameLocalization_Gamemode);
				ArrayList mapLocalizationList = MM_GetMapLocalizedList(g_MissionNameLocalization_Gamemode);
				int offset = entryList.Get(missionIndex);
				mapLocalizationList.Set(offset + mapIndex, 1, 0);
			}

			g_MissionNameLocalization_UnknownPreState = g_MissionNameLocalization_State;
			g_MissionNameLocalization_UnknownCurLayer = 1;
			g_MissionNameLocalization_State = MNLS_UNKNOWN;
		}
		case MNLS_UNKNOWN:
		{
			g_MissionNameLocalization_UnknownCurLayer++;
		}
	}

	return SMCParse_Continue;
}

public SMCResult LocalizationParser_KeyValue(SMCParser smc, const char[] key, const char[] value, bool key_quotes, bool value_quotes)
{
	return SMCParse_Continue;
}

public SMCResult LocalizationParser_EndSection(SMCParser parser)
{
	switch (g_MissionNameLocalization_State)
	{
		case MNLS_PHRASES:
		{
			return SMCParse_Halt;
		}
		case MNLS_UNKNOWN:
		{
			g_MissionNameLocalization_UnknownCurLayer--;
			if (g_MissionNameLocalization_UnknownCurLayer == 0)
			{
				g_MissionNameLocalization_State = g_MissionNameLocalization_UnknownPreState;
			}
		}
	}

	return SMCParse_Continue;
}

void ParseLocalization(int gamemode)
{
	char mapsPhrasesEnglish[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, mapsPhrasesEnglish, sizeof(mapsPhrasesEnglish), "translations/maps.phrases.txt");

	if (!FileExists(mapsPhrasesEnglish))
	{
		LogToFile(g_sLogPath, "Map name localization file %s does not exist!", mapsPhrasesEnglish);
	}

	LoadTranslations("maps.phrases");

	MM_NewLocalizedList(gamemode);

	SMCParser parser = SMC_CreateParser();
	parser.OnEnterSection = LocalizationParser_NewSection;
	parser.OnKeyValue = LocalizationParser_KeyValue;
	parser.OnLeaveSection = LocalizationParser_EndSection;

	g_MissionNameLocalization_Gamemode = gamemode;
	g_MissionNameLocalization_State = MNLS_ROOT;

	SMCError err = parser.ParseFile(mapsPhrasesEnglish);
	if (err != SMCError_Okay)
	{
		LogToFile(g_sLogPath, "An error occured while parsing maps.phrases.txt(English), code:%d", err);
	}

	delete parser;
}

