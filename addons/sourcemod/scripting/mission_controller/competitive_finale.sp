#if defined _l4d2_mission_controller_competitive_finale_included
	#endinput
#endif
#define _l4d2_mission_controller_competitive_finale_included

enum struct MCCompetitiveFinaleSnapshot
{
	bool enabled;
	bool active;
	bool disabled;
	bool currentMapIsCompetitiveFinale;

	void Reset()
	{
		this.enabled = false;
		this.active = false;
		this.disabled = false;
		this.currentMapIsCompetitiveFinale = false;
	}
}

enum struct MCRoundEndContext
{
	bool captured;
	int winner;
	int reason;
	char message[128];

	void Reset()
	{
		this.captured = false;
		this.winner = 0;
		this.reason = 0;
		this.message[0] = '\0';
	}
}

MCCompetitiveFinaleSnapshot g_MC_CompetitiveFinale;
MCCompetitiveFinaleSnapshot g_MC_LastNotifiedCompetitiveFinale;
MCRoundEndContext g_MC_RoundEndContext;
GlobalForward g_fwdOnCompetitiveFinaleChanged = null;

bool MC_IsCompetitiveMatchContext()
{
	return g_iMode == GAMEMODE_VERSUS
		&& g_ServerRuntime.hasConfogl
		&& g_ServerRuntime.competitiveMatchModeLoaded;
}

bool MC_IsCompetitiveFinaleEnabled()
{
	return g_cvCompetitiveFinale != null && g_cvCompetitiveFinale.BoolValue;
}

bool MC_IsCompetitiveFinaleDisabled()
{
	return g_bCompetitiveFinaleDisabled;
}

bool MC_HasCompetitiveFinaleBoundaryInCurrentMission()
{
	if (g_iCurrentMissionIndex < 0)
	{
		return false;
	}

	int mapCount = L4D2MM_GetNumberOfMaps(g_iMode, g_iCurrentMissionIndex);
	return mapCount >= MC_COMPETITIVE_FINALE_MAP_NUMBER;
}

bool MC_ShouldApplyCompetitiveFinale()
{
	return MC_IsCompetitiveMatchContext()
		&& MC_IsCompetitiveFinaleEnabled()
		&& !MC_IsCompetitiveFinaleDisabled()
		&& MC_HasCompetitiveFinaleBoundaryInCurrentMission();
}

bool MC_IsCurrentMapCompetitiveFinale()
{
	return MC_ShouldApplyCompetitiveFinale()
		&& g_iCurrentMapIndex >= 0
		&& (g_iCurrentMapIndex + 1) == MC_COMPETITIVE_FINALE_MAP_NUMBER;
}

bool MC_IsCurrentMapSyntheticCompetitiveFinale()
{
	return MC_IsCurrentMapCompetitiveFinale() && g_bEffectiveFinalMap && !g_bFinalMap;
}

void MC_CaptureRoundEndContext(const char[] eventName, Event event)
{
	if (!StrEqual(eventName, "round_end", false))
	{
		return;
	}

	g_MC_RoundEndContext.captured = true;
	g_MC_RoundEndContext.winner = event.GetInt("winner");
	g_MC_RoundEndContext.reason = event.GetInt("reason");
	event.GetString("message", g_MC_RoundEndContext.message, sizeof(g_MC_RoundEndContext.message), "");

	MC_Debug(
		MC_Debug_Event,
		"capture_round_end_context winner=%d reason=%d message=%s",
		g_MC_RoundEndContext.winner,
		g_MC_RoundEndContext.reason,
		g_MC_RoundEndContext.message
	);
}

void MC_ForceRoundEndMessage()
{
	if (!MC_IsCurrentMapCompetitiveFinale() || g_bFinalMap)
	{
		MC_Debug(MC_Debug_Event, "force_round_end_message_skipped reason=not_competitive_finale");
		return;
	}

	if (!g_MC_RoundEndContext.captured)
	{
		MC_Debug(MC_Debug_Event, "force_round_end_message_skipped reason=no_round_end_context");
		return;
	}

	Event event = CreateEvent("round_end_message", true);
	if (event == null)
	{
		MC_Debug(MC_Debug_Event, "force_round_end_message_skipped reason=create_event_failed");
		return;
	}

	event.SetInt("winner", g_MC_RoundEndContext.winner);
	event.SetInt("reason", g_MC_RoundEndContext.reason);
	event.SetString("message", g_MC_RoundEndContext.message);
	FireEvent(event, true);

	MC_Debug(
		MC_Debug_Event,
		"force_round_end_message winner=%d reason=%d message=%s",
		g_MC_RoundEndContext.winner,
		g_MC_RoundEndContext.reason,
		g_MC_RoundEndContext.message
	);
}

void MC_NotifyCompetitiveFinaleChanged()
{
	if (g_fwdOnCompetitiveFinaleChanged == null)
	{
		return;
	}

	if (g_MC_LastNotifiedCompetitiveFinale.enabled == g_MC_CompetitiveFinale.enabled
		&& g_MC_LastNotifiedCompetitiveFinale.active == g_MC_CompetitiveFinale.active
		&& g_MC_LastNotifiedCompetitiveFinale.disabled == g_MC_CompetitiveFinale.disabled
		&& g_MC_LastNotifiedCompetitiveFinale.currentMapIsCompetitiveFinale == g_MC_CompetitiveFinale.currentMapIsCompetitiveFinale)
	{
		return;
	}

	Call_StartForward(g_fwdOnCompetitiveFinaleChanged);
	Call_PushCell(g_MC_CompetitiveFinale.enabled);
	Call_PushCell(g_MC_CompetitiveFinale.active);
	Call_PushCell(g_MC_CompetitiveFinale.disabled);
	Call_PushCell(g_MC_CompetitiveFinale.currentMapIsCompetitiveFinale);
	Call_Finish();

	g_MC_LastNotifiedCompetitiveFinale = g_MC_CompetitiveFinale;
}

void MC_SyncCompetitiveFinaleState()
{
	g_MC_CompetitiveFinale.enabled = MC_IsCompetitiveFinaleEnabled();
	g_MC_CompetitiveFinale.active = MC_ShouldApplyCompetitiveFinale();
	g_MC_CompetitiveFinale.disabled = MC_IsCompetitiveFinaleDisabled();
	g_MC_CompetitiveFinale.currentMapIsCompetitiveFinale = MC_IsCurrentMapCompetitiveFinale();
	MC_NotifyCompetitiveFinaleChanged();
}

bool MC_EnableCompetitiveFinaleForCurrentCampaign(bool announce = false)
{
	if (!MC_IsCompetitiveFinaleEnabled())
	{
		return false;
	}

	char voteOverrideMap[LEN_MAP_FILENAME];
	bool hadVoteOverride = g_bHasVoteOverride && g_sVoteNextMap[0] != '\0';
	if (hadVoteOverride)
	{
		strcopy(voteOverrideMap, sizeof(voteOverrideMap), g_sVoteNextMap);
	}

	g_bCompetitiveFinaleDisabled = false;
	g_sCompetitiveFinaleOverrideCampaign[0] = '\0';
	MC_InitializeAutoChangeState();
	if (hadVoteOverride)
	{
		MC_ApplyVoteNextMapOverride(voteOverrideMap);
	}

	if (announce)
	{
		MC_AnnounceCompetitiveFinaleEnabledToAll();
	}

	MC_SyncCompetitiveFinaleState();
	return true;
}

bool MC_SetCompetitiveFinaleDisabledForCurrentCampaign(bool disabled, bool announce = false)
{
	if (disabled)
	{
		bool result = MC_DisableCompetitiveFinaleForCurrentCampaign(announce);
		MC_SyncCompetitiveFinaleState();
		return result;
	}

	return MC_EnableCompetitiveFinaleForCurrentCampaign(announce);
}
