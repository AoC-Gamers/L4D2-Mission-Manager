#if defined _l4d2_mission_controller_autochange_included
	#endinput
#endif
#define _l4d2_mission_controller_autochange_included

void MC_ClearChangeMapTimer()
{
	if (g_hChangeMapTimer != null)
	{
		delete g_hChangeMapTimer;
		g_hChangeMapTimer = null;
	}

	g_bChangeMapScheduled = false;
}

public void MC_EventRoundStart(Event event, const char[] name, bool dontBroadcast)
{
	g_bHasRoundEnd = false;
	MC_RefreshEffectiveFinalState();
	MC_DebugLog("event_round_start mode=%d final=%d effective=%d next=%s", g_iMode, g_bFinalMap, g_bEffectiveFinalMap, g_sNextMap);

	if (!MC_IsModeEnabled(g_iMode))
		return;

	if (g_sNextMap[0] == '\0')
		return;

	if (g_iMode == GAMEMODE_COOP)
		MC_HandleCoopRoundStartEvent();
	else if (g_iMode == GAMEMODE_SURVIVAL)
		MC_HandleSurvivalRoundStartEvent();
}

public void MC_EventRoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	if (g_bHasRoundEnd)
		return;

	g_bHasRoundEnd = true;
	MC_RefreshEffectiveFinalState();
	MC_DebugLog("event_round_end mode=%d final=%d effective=%d next=%s", g_iMode, g_bFinalMap, g_bEffectiveFinalMap, g_sNextMap);

	if (!MC_IsModeEnabled(g_iMode))
		return;

	if (g_sNextMap[0] == '\0')
		return;

	if (g_iMode == GAMEMODE_VERSUS)
		MC_HandleVersusRoundEndEvent();
	else if (g_iMode == GAMEMODE_SURVIVAL)
		MC_HandleSurvivalRoundEndEvent();
}

public void MC_EventMapTransition(Event event, const char[] name, bool dontBroadcast)
{
	MC_RefreshEffectiveFinalState();
	MC_DebugLog("event_map_transition mode=%d final=%d effective=%d next=%s", g_iMode, g_bFinalMap, g_bEffectiveFinalMap, g_sNextMap);

	if (!MC_IsModeEnabled(g_iMode))
		return;

	if (g_iMode != GAMEMODE_COOP || g_sNextMap[0] == '\0')
		return;

	if (!g_bEffectiveFinalMap || g_bFinalMap)
		return;

	MC_DebugLog("redirect_map_transition next=%s ext=%d", g_sNextMap, g_bChangeLevelAvailable);
	if (g_bChangeLevelAvailable)
		L4D2_ChangeLevel(g_sNextMap);
	else
		ServerCommand("changelevel %s", g_sNextMap);
}

public void MC_EventFinalWin(Event event, const char[] name, bool dontBroadcast)
{
	MC_RefreshEffectiveFinalState();
	MC_DebugLog("event_final_win mode=%d final=%d effective=%d next=%s", g_iMode, g_bFinalMap, g_bEffectiveFinalMap, g_sNextMap);

	if (MC_IsModeEnabled(g_iMode) && g_iMode == GAMEMODE_COOP && g_sNextMap[0] != '\0' && g_fCoopFinalDelay > 0.0)
		MC_QueueChangeMap(g_fCoopFinalDelay);
}

public void MC_EventMissionLost(Event event, const char[] name, bool dontBroadcast)
{
	MC_RefreshEffectiveFinalState();
	MC_DebugLog("event_mission_lost mode=%d final=%d effective=%d next=%s", g_iMode, g_bFinalMap, g_bEffectiveFinalMap, g_sNextMap);

	if (MC_IsModeEnabled(g_iMode) && g_iMode == GAMEMODE_COOP && g_sNextMap[0] != '\0')
		MC_HandleCoopMissionLostEvent();
}

public void MC_EventScavengeMatchFinished(Event event, const char[] name, bool dontBroadcast)
{
	MC_RefreshEffectiveFinalState();
	MC_DebugLog("event_scavenge_match_finished mode=%d final=%d effective=%d next=%s", g_iMode, g_bFinalMap, g_bEffectiveFinalMap, g_sNextMap);

	if (MC_IsModeEnabled(g_iMode) && g_iMode == GAMEMODE_SCAVENGE && g_sNextMap[0] != '\0' && g_fVersusDelay > 0.0)
		MC_QueueChangeMap(g_fVersusDelay);
}

public Action MC_TimerAnnounce(Handle timer, int client)
{
	MC_RefreshEffectiveFinalState();

	if (!MC_IsModeEnabled(g_iMode))
		return Plugin_Stop;

	if (g_sNextMap[0] == '\0')
		return Plugin_Stop;

	if (!IsClientInGame(client) || IsFakeClient(client))
		return Plugin_Stop;

	if (!MC_ShouldAnnounceNextMapToClient())
		return Plugin_Stop;

	char announceTarget[LEN_LOCALIZED_NAME];
	MC_BuildClientAnnouncementTarget(client, announceTarget, sizeof(announceTarget));

	switch (g_iMode)
	{
		case GAMEMODE_COOP, GAMEMODE_VERSUS:
			CPrintToChat(client, "%T %T", "Tag", client, "AnnounceMission", client, announceTarget);
		case GAMEMODE_SURVIVAL, GAMEMODE_SCAVENGE:
			CPrintToChat(client, "%T %T", "Tag", client, "AnnounceMap", client, announceTarget);
		default:
			CPrintToChat(client, "%T %T", "Tag", client, "AnnounceTarget", client, announceTarget);
	}

	if (g_iMode == GAMEMODE_COOP || g_iMode == GAMEMODE_VERSUS)
		CPrintToChat(client, "%T %T", "Tag", client, "AnnounceVoteHint", client);

	return Plugin_Stop;
}

void MC_InitializeAutoChangeState()
{
	KeyValues settings = new KeyValues("MissionControllerSettings");
	if (settings == null)
		SetFailState("Unable to allocate KeyValues for Mission Controller settings.");

	if (!FileExists(g_sSettingsPath))
		SetFailState("data/l4d2_mission_controller.txt does not exist.");

	if (!settings.ImportFromFile(g_sSettingsPath))
		SetFailState("Unable to load mission controller settings.");

	MC_ResolveAutoChangeState(settings);
	delete settings;
}

void MC_ClearAutoChangeState()
{
	g_sCurrentMap[0]		= '\0';
	g_sConfiguredNextMap[0] = '\0';
	g_sNextMap[0]			= '\0';
	g_sAnnounceMap[0]		= '\0';
	g_bFinalMap				= false;
	g_bEffectiveFinalMap	= false;
	g_iAnnouncementType		= ANNOUNCEMENT_NONE;
	g_iCurrentMissionIndex	= -1;
	g_iCurrentMapIndex		= -1;
}

void MC_NotifyNextMapChanged()
{
	if (g_fwdOnNextMapChanged == null)
		return;

	Call_StartForward(g_fwdOnNextMapChanged);
	Call_PushString(g_sNextMap);
	Call_PushCell(g_bHasVoteOverride);
	Call_Finish();
}

void MC_ApplyVoteNextMapOverride(const char[] mapName)
{
	if (mapName[0] == '\0')
		return;

	if (!IsMapValid(mapName))
		return;

	strcopy(g_sVoteNextMap, sizeof(g_sVoteNextMap), mapName);
	g_sVoteOverrideCampaign[0] = '\0';
	Campaign_ExtractCampaignCode(g_sCurrentMap, g_sVoteOverrideCampaign, sizeof(g_sVoteOverrideCampaign));
	strcopy(g_sNextMap, sizeof(g_sNextMap), mapName);
	strcopy(g_sAnnounceMap, sizeof(g_sAnnounceMap), mapName);
	g_bHasVoteOverride	= true;
	g_iAnnouncementType = ANNOUNCEMENT_NEXT_MAP;
	MC_DebugLog("apply_vote_override current=%s mode=%d next=%s", g_sCurrentMap, g_iMode, g_sNextMap);
	MC_NotifyNextMapChanged();
}

void MC_ClearVoteNextMapOverride()
{
	if (!g_bHasVoteOverride && g_sVoteNextMap[0] == '\0')
		return;

	g_bHasVoteOverride = false;
	g_sVoteNextMap[0]  = '\0';
	g_sVoteOverrideCampaign[0] = '\0';

	if (g_sConfiguredNextMap[0] != '\0')
	{
		strcopy(g_sNextMap, sizeof(g_sNextMap), g_sConfiguredNextMap);
		strcopy(g_sAnnounceMap, sizeof(g_sAnnounceMap), g_sConfiguredNextMap);
		g_iAnnouncementType = ANNOUNCEMENT_NEXT_MAP;
	}
	else
	{
		g_sNextMap[0]		= '\0';
		g_sAnnounceMap[0]	= '\0';
		g_iAnnouncementType = ANNOUNCEMENT_NONE;
	}

	MC_DebugLog("clear_vote_override current=%s mode=%d next=%s", g_sCurrentMap, g_iMode, g_sNextMap);
	MC_NotifyNextMapChanged();
}

void MC_ResolveAutoChangeState(KeyValues settings)
{
	MC_ClearAutoChangeState();
	GetCurrentMap(g_sCurrentMap, sizeof(g_sCurrentMap));

	MC_UpdateMatchEndMapOverrideState();
	MC_UpdateVoteOverrideState();
	MC_RefreshEffectiveFinalState();

	if (!MC_IsModeEnabled(g_iMode))
	{
		return;
	}

	char sourceMap[LEN_MAP_FILENAME];
	strcopy(sourceMap, sizeof(sourceMap), g_sCurrentMap);

	if (!settings.JumpToKey(sourceMap))
	{
		if (!MC_TryResolveTransitionSourceMap(settings, sourceMap, sizeof(sourceMap)))
		{
			MC_DebugLog("resolve_state_missing_map_section current=%s mode=%d", g_sCurrentMap, g_iMode);
			return;
		}

		if (!settings.JumpToKey(sourceMap))
		{
			MC_DebugLog("resolve_state_missing_source_map_section current=%s source=%s mode=%d", g_sCurrentMap, sourceMap, g_iMode);
			return;
		}
	}

	char modeKey[16];
	char nextTargetKey[32];

	switch (g_iMode)
	{
		case GAMEMODE_COOP:
		{
			strcopy(modeKey, sizeof(modeKey), "coop");
			strcopy(nextTargetKey, sizeof(nextTargetKey), "next_mission_map");
		}
		case GAMEMODE_VERSUS:
		{
			strcopy(modeKey, sizeof(modeKey), "versus");
			strcopy(nextTargetKey, sizeof(nextTargetKey), "next_mission_map");
		}
		case GAMEMODE_SURVIVAL:
		{
			strcopy(modeKey, sizeof(modeKey), "survival");
			strcopy(nextTargetKey, sizeof(nextTargetKey), "next_map");
		}
		case GAMEMODE_SCAVENGE:
		{
			strcopy(modeKey, sizeof(modeKey), "scavenge");
			strcopy(nextTargetKey, sizeof(nextTargetKey), "next_map");
		}
		default:
		{
			modeKey[0]		 = '\0';
			nextTargetKey[0] = '\0';
		}
	}

	if (modeKey[0] == '\0')
	{
		return;
	}

	if (!settings.JumpToKey(modeKey))
	{
		MC_DebugLog("resolve_state_missing_mode_section current=%s mode=%d modekey=%s", g_sCurrentMap, g_iMode, modeKey);
		settings.Rewind();
		return;
	}

	if (nextTargetKey[0] == '\0')
	{
		MC_DebugLog("resolve_state_missing_target_key current=%s mode=%d modekey=%s", g_sCurrentMap, g_iMode, modeKey);
		settings.Rewind();
		return;
	}
	settings.GetString(nextTargetKey, g_sConfiguredNextMap, sizeof(g_sConfiguredNextMap), "");
	if (g_sConfiguredNextMap[0] == '\0' && (g_iMode == GAMEMODE_COOP || g_iMode == GAMEMODE_VERSUS))
		settings.GetString("next_mission", g_sConfiguredNextMap, sizeof(g_sConfiguredNextMap), "");
	if (g_sConfiguredNextMap[0] == '\0')
		settings.GetString("next mission map", g_sConfiguredNextMap, sizeof(g_sConfiguredNextMap), "");

	if (g_sConfiguredNextMap[0] == '\0')
		MC_DebugLog("resolve_state_empty_target current=%s mode=%d modekey=%s targetkey=%s", g_sCurrentMap, g_iMode, modeKey, nextTargetKey);

	settings.Rewind();

	if (g_sConfiguredNextMap[0] != '\0' && !IsMapValid(g_sConfiguredNextMap))
	{
		MC_DebugLog("invalid_next_map current=%s mode=%d next=%s", g_sCurrentMap, g_iMode, g_sConfiguredNextMap);
		strcopy(g_sAnnounceMap, sizeof(g_sAnnounceMap), g_sConfiguredNextMap);
		g_iAnnouncementType		= ANNOUNCEMENT_INVALID_MAP;
		g_sConfiguredNextMap[0] = '\0';
		g_sNextMap[0]			= '\0';
		return;
	}

	if (g_sConfiguredNextMap[0] != '\0')
	{
		strcopy(g_sAnnounceMap, sizeof(g_sAnnounceMap), g_sConfiguredNextMap);
		g_iAnnouncementType = ANNOUNCEMENT_NEXT_MAP;
	}

	if (g_bHasVoteOverride && g_sVoteNextMap[0] != '\0')
		strcopy(g_sNextMap, sizeof(g_sNextMap), g_sVoteNextMap);
	else
		strcopy(g_sNextMap, sizeof(g_sNextMap), g_sConfiguredNextMap);

	MC_DebugLog("resolved_state current=%s source=%s mode=%d final=%d effective=%d mapnum=%d configured_end=%d disabled=%d next=%s configured=%s override=%d", g_sCurrentMap, sourceMap, g_iMode, g_bFinalMap, g_bEffectiveFinalMap, g_iCurrentMapIndex + 1, g_cvMatchEndMap != null ? g_cvMatchEndMap.IntValue : -1, g_bMatchEndMapOverrideDisabled, g_sNextMap, g_sConfiguredNextMap, g_bHasVoteOverride);
	MC_NotifyNextMapChanged();
}

bool MC_ShouldAnnounceNextMapToClient()
{
	return g_iMode == GAMEMODE_SURVIVAL || g_iMode == GAMEMODE_SCAVENGE || g_bEffectiveFinalMap;
}

void MC_UpdateMatchEndMapOverrideState()
{
	if (!g_bMatchEndMapOverrideDisabled || g_sMatchEndOverrideCampaign[0] == '\0')
		return;

	char currentCampaign[8];
	if (!Campaign_ExtractCampaignCode(g_sCurrentMap, currentCampaign, sizeof(currentCampaign)))
		return;

	if (!StrEqual(currentCampaign, g_sMatchEndOverrideCampaign))
	{
		g_bMatchEndMapOverrideDisabled = false;
		g_sMatchEndOverrideCampaign[0] = '\0';
		MC_DebugLog("match_end_override_reset current=%s", g_sCurrentMap);
	}
}

void MC_UpdateVoteOverrideState()
{
	if (!g_bHasVoteOverride || g_sVoteNextMap[0] == '\0' || g_sVoteOverrideCampaign[0] == '\0')
		return;

	char currentCampaign[8];
	if (!Campaign_ExtractCampaignCode(g_sCurrentMap, currentCampaign, sizeof(currentCampaign)))
		return;

	if (!StrEqual(currentCampaign, g_sVoteOverrideCampaign))
	{
		MC_DebugLog("vote_override_consumed current=%s previous_campaign=%s", g_sCurrentMap, g_sVoteOverrideCampaign);
		MC_ClearVoteNextMapOverride();
	}
}

bool MC_HasConfiguredMatchEndMap()
{
	return g_cvMatchEndMap != null
		&& !g_bMatchEndMapOverrideDisabled
		&& (g_iMode == GAMEMODE_COOP || g_iMode == GAMEMODE_VERSUS)
		&& g_cvMatchEndMap.IntValue > 0;
}

bool MC_TryResolveTransitionSourceMap(KeyValues settings, char[] sourceMap, int maxlength)
{
	if (!g_bEffectiveFinalMap || g_bFinalMap)
		return false;

	if (g_iMode != GAMEMODE_COOP && g_iMode != GAMEMODE_VERSUS)
		return false;

	char currentCampaign[8];
	if (!Campaign_ExtractCampaignCode(g_sCurrentMap, currentCampaign, sizeof(currentCampaign)))
		return false;

	char modeKey[16];
	switch (g_iMode)
	{
		case GAMEMODE_COOP:
			strcopy(modeKey, sizeof(modeKey), "coop");
		case GAMEMODE_VERSUS:
			strcopy(modeKey, sizeof(modeKey), "versus");
		default:
			modeKey[0] = '\0';
	}

	if (modeKey[0] == '\0')
		return false;

	settings.Rewind();
	if (!settings.GotoFirstSubKey(false))
		return false;

	char sectionName[LEN_MAP_FILENAME];
	char sectionCampaign[8];
	bool foundSource = false;

	do
	{
		settings.GetSectionName(sectionName, sizeof(sectionName));
		if (!Campaign_ExtractCampaignCode(sectionName, sectionCampaign, sizeof(sectionCampaign)))
			continue;

		if (!StrEqual(sectionCampaign, currentCampaign))
			continue;

		if (!settings.JumpToKey(modeKey))
		{
			settings.GoBack();
			continue;
		}

		strcopy(sourceMap, maxlength, sectionName);
		settings.GoBack();
		foundSource = true;
		MC_DebugLog("resolve_state_fallback_source current=%s source=%s mode=%d campaign=%s", g_sCurrentMap, sourceMap, g_iMode, currentCampaign);
		break;
	}
	while (settings.GotoNextKey(false));

	settings.Rewind();

	if (!foundSource)
	{
		return false;
	}

	return true;
}

void MC_RefreshEffectiveFinalState()
{
	GetCurrentMap(g_sCurrentMap, sizeof(g_sCurrentMap));
	MC_UpdateMatchEndMapOverrideState();
	g_bFinalMap			   = L4D_IsMissionFinalMap();
	g_bEffectiveFinalMap   = g_bFinalMap;
	g_iCurrentMissionIndex = -1;
	g_iCurrentMapIndex	   = -1;

	if (g_iMode != GAMEMODE_COOP && g_iMode != GAMEMODE_VERSUS)
		return;

	if (!MC_ResolveCurrentMissionMapPosition(g_iCurrentMissionIndex, g_iCurrentMapIndex))
		return;

	if (!MC_HasConfiguredMatchEndMap())
		return;

	int configuredMatchEndMap = g_cvMatchEndMap.IntValue;
	int mapCount			  = L4D2MM_GetNumberOfMaps(g_iMode, g_iCurrentMissionIndex);

	if (configuredMatchEndMap > 0 && configuredMatchEndMap <= mapCount && (g_iCurrentMapIndex + 1) >= configuredMatchEndMap)
	{
		g_bEffectiveFinalMap = true;
	}
}

bool MC_ResolveCurrentMissionMapPosition(int &missionIndex, int &mapIndex)
{
	missionIndex = -1;
	mapIndex	 = -1;

	if (g_sCurrentMap[0] == '\0')
		return false;

	mapIndex = L4D2MM_FindMapIndexByName(g_iMode, missionIndex, g_sCurrentMap);
	return missionIndex >= 0 && mapIndex >= 0;
}

bool MC_ResolveLocalizedMapName(int client, const char[] mapName, char[] buffer, int maxlength)
{
	if (mapName[0] == '\0')
		return false;

	if (g_hLocalizer == null || !g_hLocalizer.IsReady())
		return false;

	return Chapter_GetLocalizedName(mapName, client, buffer, maxlength, g_hLocalizer);
}

bool MC_ResolveLocalizedCampaignName(int client, const char[] mapName, char[] buffer, int maxlength)
{
	if (mapName[0] == '\0')
		return false;

	if (g_hLocalizer != null && g_hLocalizer.IsReady() && Campaign_GetLocalizedNameFromMapCode(mapName, client, buffer, maxlength, g_hLocalizer))
		return true;

	char campaignCode[8];
	if (!Campaign_ExtractCampaignCode(mapName, campaignCode, sizeof(campaignCode)))
		return false;

	strcopy(buffer, maxlength, campaignCode);
	return false;
}

bool MC_BuildLocalizedMapAndCampaign(int client, const char[] mapName, char[] buffer, int maxlength)
{
	char chapterName[LEN_LOCALIZED_NAME];
	char campaignName[LEN_LOCALIZED_NAME];

	bool hasChapter	 = MC_ResolveLocalizedMapName(client, mapName, chapterName, sizeof(chapterName));
	bool hasCampaign = MC_ResolveLocalizedCampaignName(client, mapName, campaignName, sizeof(campaignName));

	if (hasChapter && hasCampaign)
	{
		Format(buffer, maxlength, "%s (%s)", chapterName, campaignName);
		return true;
	}

	if (hasChapter)
	{
		strcopy(buffer, maxlength, chapterName);
		return true;
	}

	if (hasCampaign)
	{
		strcopy(buffer, maxlength, campaignName);
		return true;
	}

	return false;
}

void MC_BuildClientAnnouncementTarget(int client, char[] buffer, int maxlength)
{
	if (g_sNextMap[0] == '\0')
	{
		strcopy(buffer, maxlength, g_sAnnounceMap);
		return;
	}

	switch (g_iMode)
	{
		case GAMEMODE_COOP, GAMEMODE_VERSUS:
		{
			if (MC_ResolveLocalizedCampaignName(client, g_sNextMap, buffer, maxlength))
				return;
		}
		case GAMEMODE_SURVIVAL, GAMEMODE_SCAVENGE:
		{
			if (MC_BuildLocalizedMapAndCampaign(client, g_sNextMap, buffer, maxlength))
				return;
		}
	}

	strcopy(buffer, maxlength, g_sAnnounceMap);
}

void MC_QueueChangeMap(float delay)
{
	if (delay <= 0.0 || g_sNextMap[0] == '\0' || g_bChangeMapScheduled)
		return;

	g_bChangeMapScheduled = true;
	g_hChangeMapTimer	  = CreateTimer(delay, MC_TimerChangeMap, _, TIMER_FLAG_NO_MAPCHANGE);
	MC_DebugLog("queue_change_map delay=%.1f next=%s", delay, g_sNextMap);
}

public Action MC_TimerChangeMap(Handle timer)
{
	g_hChangeMapTimer	  = null;
	g_bChangeMapScheduled = false;

	MC_DebugLog("timer_change_map next=%s ext=%d", g_sNextMap, g_bChangeLevelAvailable);
	if (g_bChangeLevelAvailable)
		L4D2_ChangeLevel(g_sNextMap);
	else
		ServerCommand("changelevel %s", g_sNextMap);

	return Plugin_Stop;
}

void MC_PrintRemainingTries(const char[] phrase, int left)
{
	if ((g_cvAnnounce != null && !g_cvAnnounce.BoolValue) || left < 1)
		return;

	CPrintToChatAll("%t", phrase, left);
}

void MC_AnnounceNextTargetUpdateToAll()
{
	if ((g_cvAnnounce != null && !g_cvAnnounce.BoolValue) || g_sNextMap[0] == '\0')
		return;

	char announceTarget[LEN_LOCALIZED_NAME];
	MC_BuildClientAnnouncementTarget(LANG_SERVER, announceTarget, sizeof(announceTarget));

	switch (g_iMode)
	{
		case GAMEMODE_COOP, GAMEMODE_VERSUS:
			CPrintToChatAll("%t %t", "Tag", "VoteNextMissionUpdated", announceTarget);
		case GAMEMODE_SURVIVAL, GAMEMODE_SCAVENGE:
			CPrintToChatAll("%t %t", "Tag", "VoteNextMapUpdated", announceTarget);
		default:
			CPrintToChatAll("%t %t", "Tag", "VoteNextTargetUpdated", announceTarget);
	}
}

void MC_AnnounceMatchEndMapLimitDisabledToAll()
{
	if (g_cvAnnounce != null && !g_cvAnnounce.BoolValue)
		return;

	CPrintToChatAll("%t %t", "Tag", "MatchEndMapLimitDisabled");
}

void MC_AnnounceMatchEndMapLimitEnabledToAll()
{
	if (g_cvAnnounce != null && !g_cvAnnounce.BoolValue)
		return;

	CPrintToChatAll("%t %t", "Tag", "MatchEndMapLimitEnabled");
}

void MC_HandleCoopRoundStartEvent()
{
	int roundLimit = g_bEffectiveFinalMap ? g_cvRoundCounterCoopFinal.IntValue : g_cvRoundCounterCoop.IntValue;
	if (roundLimit < 1 || g_iRoundEndCounter < 1)
		return;

	int left = roundLimit - g_iRoundEndCounter;
	MC_PrintRemainingTries(g_bEffectiveFinalMap ? "FinaleTriesLeft" : "TriesLeft", left);
}

void MC_HandleSurvivalRoundStartEvent()
{
	int roundLimit = g_cvRoundCounterSurvival.IntValue;
	if (roundLimit < 1 || g_iRoundEndCounter < 1)
		return;

	int left = roundLimit - g_iRoundEndCounter;
	MC_PrintRemainingTries("TriesLeft", left);
}

void MC_HandleVersusRoundEndEvent()
{
	if (g_bEffectiveFinalMap && view_as<bool>(GameRules_GetProp("m_bInSecondHalfOfRound")))
		MC_QueueChangeMap(g_fVersusDelay);
}

void MC_HandleSurvivalRoundEndEvent()
{
	int roundLimit = g_cvRoundCounterSurvival.IntValue;
	g_iRoundEndCounter++;

	if (roundLimit < 1 || g_iRoundEndCounter < roundLimit)
		return;

	if (g_fSurvivalDelay <= 0.0)
		return;

	CPrintToChatAll("%t", "ForcePassMapNoTriesLeft", roundLimit);
	MC_QueueChangeMap(g_fSurvivalDelay);
}

void MC_HandleCoopMissionLostEvent()
{
	g_iRoundEndCounter++;

	int roundLimit = g_bEffectiveFinalMap ? g_cvRoundCounterCoopFinal.IntValue : g_cvRoundCounterCoop.IntValue;
	if (roundLimit < 1 || g_iRoundEndCounter < roundLimit)
		return;

	if (g_bEffectiveFinalMap)
		CPrintToChatAll("%t", "ForcePassCampaignNoTriesLeft", g_cvRoundCounterCoopFinal.IntValue);
	else
		CPrintToChatAll("%t", "ForcePassMapNoTriesLeft", g_cvRoundCounterCoop.IntValue);

	MC_QueueChangeMap(6.0);
}
