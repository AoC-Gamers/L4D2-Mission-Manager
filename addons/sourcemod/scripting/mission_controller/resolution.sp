#if defined _l4d2_mission_controller_resolution_included
	#endinput
#endif
#define _l4d2_mission_controller_resolution_included

bool MC_ResolveModeConfigKey(char[] modeKey, int modeKeyLength)
{
	switch (g_iMode)
	{
		case GAMEMODE_COOP:
			strcopy(modeKey, modeKeyLength, "coop");
		case GAMEMODE_VERSUS:
			strcopy(modeKey, modeKeyLength, "versus");
		case GAMEMODE_SURVIVAL:
			strcopy(modeKey, modeKeyLength, "survival");
		case GAMEMODE_SCAVENGE:
			strcopy(modeKey, modeKeyLength, "scavenge");
		default:
			modeKey[0] = '\0';
	}

	return modeKey[0] != '\0';
}

bool MC_ResolveConfiguredNextTarget(KeyValues settings)
{
	if (settings == null)
		return false;

	char modeKey[16];
	if (!MC_ResolveModeConfigKey(modeKey, sizeof(modeKey)))
		return false;

	if (!settings.JumpToKey("maps"))
	{
		MC_Debug(MC_Debug_Resolution, "resolve_missing_maps_root current=%s mode=%d", g_sCurrentMap, g_iMode);
		return false;
	}

	if (!settings.JumpToKey(g_sCurrentMap))
	{
		MC_Debug(MC_Debug_Resolution, "resolve_missing_current_section current=%s mode=%d", g_sCurrentMap, g_iMode);
		settings.Rewind();
		return false;
	}

	if (!settings.JumpToKey("modes"))
	{
		MC_Debug(MC_Debug_Resolution, "resolve_missing_modes_section current=%s mode=%d", g_sCurrentMap, g_iMode);
		settings.Rewind();
		return false;
	}

	if (!settings.JumpToKey(modeKey))
	{
		MC_Debug(MC_Debug_Resolution, "resolve_missing_mode_section current=%s mode=%d modekey=%s", g_sCurrentMap, g_iMode, modeKey);
		settings.Rewind();
		return false;
	}

	g_sConfiguredNextMap[0] = '\0';
	g_sAnnounceMap[0] = '\0';
	g_sNextMap[0] = '\0';
	g_iAnnouncementType = ANNOUNCEMENT_NONE;
	g_MC_LifecycleState.configuredNaturalEnd[0] = '\0';
	g_MC_LifecycleState.configuredTargetScope[0] = '\0';

	if (settings.JumpToKey("target"))
	{
		settings.GetString("map", g_sConfiguredNextMap, sizeof(g_sConfiguredNextMap), "");
		settings.GetString("scope", g_MC_LifecycleState.configuredTargetScope, sizeof(g_MC_LifecycleState.configuredTargetScope), "");
		settings.GoBack();
	}

	if (settings.JumpToKey("lifecycle"))
	{
		settings.GetString("natural_end", g_MC_LifecycleState.configuredNaturalEnd, sizeof(g_MC_LifecycleState.configuredNaturalEnd), "");
		settings.GoBack();
	}

	settings.Rewind();

	if (g_sConfiguredNextMap[0] == '\0')
	{
		MC_Debug(MC_Debug_Resolution, "resolve_missing_target current=%s mode=%d modekey=%s", g_sCurrentMap, g_iMode, modeKey);
		return false;
	}

	if (!IsMapValid(g_sConfiguredNextMap))
	{
		MC_Debug(MC_Debug_Resolution, "resolve_invalid_target current=%s mode=%d next=%s", g_sCurrentMap, g_iMode, g_sConfiguredNextMap);
		strcopy(g_sAnnounceMap, sizeof(g_sAnnounceMap), g_sConfiguredNextMap);
		g_iAnnouncementType = ANNOUNCEMENT_INVALID_MAP;
		return true;
	}

	strcopy(g_sAnnounceMap, sizeof(g_sAnnounceMap), g_sConfiguredNextMap);
	g_iAnnouncementType = ANNOUNCEMENT_NEXT_MAP;

	if (g_bHasVoteOverride && g_sVoteNextMap[0] != '\0')
		strcopy(g_sNextMap, sizeof(g_sNextMap), g_sVoteNextMap);
	else
		strcopy(g_sNextMap, sizeof(g_sNextMap), g_sConfiguredNextMap);

	return true;
}
