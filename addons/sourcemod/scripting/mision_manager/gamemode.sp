enum struct MM_InternalGamemodeInfo
{
	int mode;
	char name[LEN_GAMEMODE_NAME];
}

MM_InternalGamemodeInfo g_MMInternalGamemodes[COUNT_MM_GAMEMODE] =
{
	{ GAMEMODE_COOP, "coop" },
	{ GAMEMODE_VERSUS, "versus" },
	{ GAMEMODE_SCAVENGE, "scavenge" },
	{ GAMEMODE_SURVIVAL, "survival" }
};

bool MM_InternalIsValidGamemode(int gamemode)
{
	for (int i = 0; i < COUNT_MM_GAMEMODE; i++)
	{
		if (g_MMInternalGamemodes[i].mode == gamemode)
		{
			return true;
		}
	}

	return false;
}

int MM_InternalGamemodeToIndex(int gamemode)
{
	for (int i = 0; i < COUNT_MM_GAMEMODE; i++)
	{
		if (g_MMInternalGamemodes[i].mode == gamemode)
		{
			return i;
		}
	}

	return -1;
}

int MM_InternalGamemodeFromIndex(int index)
{
	if (index >= 0 && index < COUNT_MM_GAMEMODE)
	{
		return g_MMInternalGamemodes[index].mode;
	}

	return GAMEMODE_UNKNOWN;
}

bool MM_InternalTryParseGamemodeArg(const char[] gamemodeName, int &gamemode)
{
	gamemode = MM_InternalResolveBasicGamemode(gamemodeName);
	return MM_InternalIsValidGamemode(gamemode);
}

int MM_InternalResolveBasicGamemode(const char[] gamemodeName)
{
	for (int i = 0; i < COUNT_MM_GAMEMODE; i++)
	{
		if (StrEqual(gamemodeName, g_MMInternalGamemodes[i].name, false))
		{
			return g_MMInternalGamemodes[i].mode;
		}
	}

	return GAMEMODE_UNKNOWN;
}

bool MM_InternalGamemodeToString(int gamemode, char[] gamemodeName, int length)
{
	for (int i = 0; i < COUNT_MM_GAMEMODE; i++)
	{
		if (g_MMInternalGamemodes[i].mode == gamemode)
		{
			strcopy(gamemodeName, length, g_MMInternalGamemodes[i].name);
			return true;
		}
	}

	strcopy(gamemodeName, length, "unknown");
	return false;
}

void MM_FireEvent_OnL4D2MMUpdateList()
{
	Call_StartForward(g_fwdOnL4D2MMUpdateList);
	Call_Finish();
}

public int Native_StringToGamemode(Handle plugin, int numParams)
{
	if (numParams < 1)
		return -1;

	int length;
	GetNativeStringLength(1, length);
	char[] gamemodeName = new char[length + 1];
	GetNativeString(1, gamemodeName, length + 1);

	int gamemode;
	return MM_InternalTryParseGamemodeArg(gamemodeName, gamemode) ? gamemode : GAMEMODE_UNKNOWN;
}

public int Native_GamemodeToString(Handle plugin, int numParams)
{
	if (numParams < 1)
		return -1;

	int gamemode = GetNativeCell(1);
	if (!MM_InternalIsValidGamemode(gamemode))
		return -1;
	int length = GetNativeCell(3);
	char gamemodeName[LEN_GAMEMODE_NAME];

	MM_InternalGamemodeToString(gamemode, gamemodeName, sizeof(gamemodeName));

	if (SetNativeString(2, gamemodeName, length, false) != SP_ERROR_NONE)
		return -1;

	return 0;
}


