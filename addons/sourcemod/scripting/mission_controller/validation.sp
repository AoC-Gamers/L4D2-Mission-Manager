#if defined _l4d2_mission_controller_validation_included
	#endinput
#endif
#define _l4d2_mission_controller_validation_included

bool MC_IsAllowedTargetScope(const char[] scope)
{
	return StrEqual(scope, "campaign", false) || StrEqual(scope, "map", false);
}

bool MC_IsAllowedNaturalEnd(const char[] modeKey, const char[] naturalEnd)
{
	if (naturalEnd[0] == '\0')
		return false;

	if (StrEqual(modeKey, "coop", false))
	{
		return StrEqual(naturalEnd, "finale_win", false)
			|| StrEqual(naturalEnd, "map_transition", false);
	}

	if (StrEqual(modeKey, "versus", false))
	{
		return StrEqual(naturalEnd, "round_end_second_half", false);
	}

	if (StrEqual(modeKey, "survival", false))
	{
		return StrEqual(naturalEnd, "round_end", false);
	}

	if (StrEqual(modeKey, "scavenge", false))
	{
		return StrEqual(naturalEnd, "scavenge_match_finished", false)
			|| StrEqual(naturalEnd, "scavenge_round_finished", false);
	}

	return false;
}

bool MC_ValidateModeConfig(KeyValues settings, const char[] mapName, const char[] modeKey)
{
	if (!settings.JumpToKey("target"))
	{
		MC_Debug(MC_Debug_Validate, "validate_missing_target current=%s mode=%s", mapName, modeKey);
		return false;
	}

	char targetMap[LEN_MAP_FILENAME];
	char targetScope[16];
	settings.GetString("map", targetMap, sizeof(targetMap), "");
	settings.GetString("scope", targetScope, sizeof(targetScope), "");
	settings.GoBack();

	if (targetMap[0] == '\0')
	{
		MC_Debug(MC_Debug_Validate, "validate_missing_target_map current=%s mode=%s", mapName, modeKey);
		return false;
	}

	if (!MC_IsAllowedTargetScope(targetScope))
	{
		MC_Debug(MC_Debug_Validate, "validate_invalid_scope current=%s mode=%s scope=%s", mapName, modeKey, targetScope);
		return false;
	}

	if (!settings.JumpToKey("lifecycle"))
	{
		MC_Debug(MC_Debug_Validate, "validate_missing_lifecycle current=%s mode=%s", mapName, modeKey);
		return false;
	}

	char naturalEnd[32];
	settings.GetString("natural_end", naturalEnd, sizeof(naturalEnd), "");
	settings.GoBack();

	if (!MC_IsAllowedNaturalEnd(modeKey, naturalEnd))
	{
		MC_Debug(MC_Debug_Validate, "validate_invalid_natural_end current=%s mode=%s natural_end=%s", mapName, modeKey, naturalEnd);
		return false;
	}

	return true;
}

void MC_ValidateSettingsOrFail(KeyValues settings)
{
	if (settings == null)
		SetFailState("Mission Controller settings are unavailable.");

	if (!settings.JumpToKey("maps"))
		SetFailState("Mission Controller settings must define a top-level maps section.");

	if (!settings.GotoFirstSubKey(false))
		SetFailState("Mission Controller settings must define at least one map entry.");

	char mapName[LEN_MAP_FILENAME];
	char modeKey[16];

	do
	{
		settings.GetSectionName(mapName, sizeof(mapName));

		if (!settings.JumpToKey("modes"))
			SetFailState("Mission Controller map entry is missing modes section.");

		if (!settings.GotoFirstSubKey(false))
			SetFailState("Mission Controller modes section must define at least one mode.");

		do
		{
			settings.GetSectionName(modeKey, sizeof(modeKey));
			if (!MC_ValidateModeConfig(settings, mapName, modeKey))
				SetFailState("Mission Controller settings contain an invalid mode configuration.");
		}
		while (settings.GotoNextKey(false));

		settings.GoBack();
		settings.GoBack();
	}
	while (settings.GotoNextKey(false));

	settings.Rewind();
}
