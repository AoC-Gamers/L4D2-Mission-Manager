#if defined _l4d2_mission_controller_state_included
	#endinput
#endif
#define _l4d2_mission_controller_state_included

void MC_ClearAutoChangeState()
{
	g_sCurrentMap[0]		  = '\0';
	g_sConfiguredNextMap[0] = '\0';
	g_sNextMap[0]			  = '\0';
	g_sAnnounceMap[0]		  = '\0';
	g_bFinalMap			  = false;
	g_bEffectiveFinalMap	  = false;
	g_iAnnouncementType	  = ANNOUNCEMENT_NONE;
	g_iCurrentMissionIndex   = -1;
	g_iCurrentMapIndex		  = -1;

	g_MC_LifecycleState.gamemode = GAMEMODE_UNKNOWN;
	g_MC_LifecycleState.phase = MC_PHASE_UNKNOWN;
	g_MC_LifecycleState.live = false;
	g_MC_LifecycleState.overtime = false;
	g_MC_LifecycleState.hasNextTarget = false;
	g_MC_LifecycleState.hasVoteOverride = false;
	g_MC_LifecycleState.finalMap = false;
	g_MC_LifecycleState.effectiveFinalMap = false;
	g_MC_LifecycleState.syntheticCompetitiveFinale = false;
	g_MC_LifecycleState.competitiveFinaleConfigured = false;
	g_MC_LifecycleState.competitiveFinaleDisabled = false;
	g_MC_LifecycleState.competitiveFinaleMapNumber = -1;
	g_MC_LifecycleState.currentMap[0] = '\0';
	g_MC_LifecycleState.configuredNextMap[0] = '\0';
	g_MC_LifecycleState.effectiveNextMap[0] = '\0';
	g_MC_LifecycleState.announceMap[0] = '\0';
	g_MC_LifecycleState.configuredNaturalEnd[0] = '\0';
	g_MC_LifecycleState.configuredTargetScope[0] = '\0';

	g_MC_EventState.Reset();
	g_MC_RoundEndContext.Reset();
	g_MC_CompetitiveFinale.Reset();
	g_MC_LastNotifiedCompetitiveFinale.Reset();
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
	g_bHasVoteOverride = true;
	g_iAnnouncementType = ANNOUNCEMENT_NEXT_MAP;
	g_MC_LifecycleState.hasVoteOverride = true;
	g_MC_LifecycleState.hasNextTarget = true;
	strcopy(g_MC_LifecycleState.effectiveNextMap, sizeof(g_MC_LifecycleState.effectiveNextMap), g_sNextMap);
	strcopy(g_MC_LifecycleState.announceMap, sizeof(g_MC_LifecycleState.announceMap), g_sAnnounceMap);
	MC_Debug(MC_Debug_State, "apply_vote_override current=%s mode=%d next=%s", g_sCurrentMap, g_iMode, g_sNextMap);
	MC_NotifyNextMapChanged();
}

void MC_ClearVoteNextMapOverride()
{
	if (!g_bHasVoteOverride && g_sVoteNextMap[0] == '\0')
		return;

	g_bHasVoteOverride = false;
	g_sVoteNextMap[0] = '\0';
	g_sVoteOverrideCampaign[0] = '\0';

	if (g_sConfiguredNextMap[0] != '\0')
	{
		strcopy(g_sNextMap, sizeof(g_sNextMap), g_sConfiguredNextMap);
		strcopy(g_sAnnounceMap, sizeof(g_sAnnounceMap), g_sConfiguredNextMap);
		g_iAnnouncementType = ANNOUNCEMENT_NEXT_MAP;
	}
	else
	{
		g_sNextMap[0] = '\0';
		g_sAnnounceMap[0] = '\0';
		g_iAnnouncementType = ANNOUNCEMENT_NONE;
	}

	g_MC_LifecycleState.hasVoteOverride = false;
	g_MC_LifecycleState.hasNextTarget = g_sNextMap[0] != '\0';
	strcopy(g_MC_LifecycleState.effectiveNextMap, sizeof(g_MC_LifecycleState.effectiveNextMap), g_sNextMap);
	strcopy(g_MC_LifecycleState.announceMap, sizeof(g_MC_LifecycleState.announceMap), g_sAnnounceMap);
	MC_Debug(MC_Debug_State, "clear_vote_override current=%s mode=%d next=%s", g_sCurrentMap, g_iMode, g_sNextMap);
	MC_NotifyNextMapChanged();
}

void MC_UpdateCompetitiveFinaleOverrideState()
{
	if (!g_bCompetitiveFinaleDisabled || g_sCompetitiveFinaleOverrideCampaign[0] == '\0')
		return;

	char currentCampaign[8];
	if (!Campaign_ExtractCampaignCode(g_sCurrentMap, currentCampaign, sizeof(currentCampaign)))
		return;

	if (!StrEqual(currentCampaign, g_sCompetitiveFinaleOverrideCampaign))
	{
		g_bCompetitiveFinaleDisabled = false;
		g_sCompetitiveFinaleOverrideCampaign[0] = '\0';
		MC_Debug(MC_Debug_State, "competitive_finale_override_reset current=%s", g_sCurrentMap);
		MC_SyncCompetitiveFinaleState();
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
		MC_Debug(MC_Debug_State, "vote_override_consumed current=%s previous_campaign=%s", g_sCurrentMap, g_sVoteOverrideCampaign);
		MC_ClearVoteNextMapOverride();
	}
}

bool MC_HasConfiguredCompetitiveFinale()
{
	return g_cvCompetitiveFinale != null
		&& !g_bCompetitiveFinaleDisabled
		&& g_iMode == GAMEMODE_VERSUS
		&& g_cvCompetitiveFinale.BoolValue;
}

bool MC_ResolveCurrentMissionMapPosition(int &missionIndex, int &mapIndex)
{
	missionIndex = -1;
	mapIndex = -1;

	if (g_sCurrentMap[0] == '\0')
		return false;

	mapIndex = L4D2MM_FindMapIndexByName(g_iMode, missionIndex, g_sCurrentMap);
	return missionIndex >= 0 && mapIndex >= 0;
}

bool MC_CanQueryMissionFinalState()
{
	return g_ServerRuntime.hasLeft4DHooks && g_ServerRuntime.mapReady;
}

void MC_RefreshEffectiveFinalState()
{
	GetCurrentMap(g_sCurrentMap, sizeof(g_sCurrentMap));
	MC_UpdateCompetitiveFinaleOverrideState();
	g_bFinalMap = MC_CanQueryMissionFinalState() ? L4D_IsMissionFinalMap() : false;
	g_bEffectiveFinalMap = g_bFinalMap;
	g_iCurrentMissionIndex = -1;
	g_iCurrentMapIndex = -1;

	if (g_iMode != GAMEMODE_VERSUS)
		return;

	if (!MC_ResolveCurrentMissionMapPosition(g_iCurrentMissionIndex, g_iCurrentMapIndex))
		return;

	if (!MC_HasConfiguredCompetitiveFinale())
		return;

	int configuredCompetitiveFinaleMap = MC_COMPETITIVE_FINALE_MAP_NUMBER;
	int mapCount = L4D2MM_GetNumberOfMaps(g_iMode, g_iCurrentMissionIndex);

	if (configuredCompetitiveFinaleMap > 0 && configuredCompetitiveFinaleMap <= mapCount && (g_iCurrentMapIndex + 1) == configuredCompetitiveFinaleMap)
	{
		g_bEffectiveFinalMap = true;
	}

	MC_Lifecycle_SyncState();
	MC_SyncCompetitiveFinaleState();
}
