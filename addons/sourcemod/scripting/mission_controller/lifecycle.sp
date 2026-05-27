#if defined _l4d2_mission_controller_lifecycle_included
	#endinput
#endif
#define _l4d2_mission_controller_lifecycle_included

enum MC_LifecycleSignal
{
	MC_SIGNAL_NONE = 0,
	MC_SIGNAL_ROUND_START,
	MC_SIGNAL_ROUND_END,
	MC_SIGNAL_MAP_TRANSITION,
	MC_SIGNAL_FINAL_WIN,
	MC_SIGNAL_MISSION_LOST,
	MC_SIGNAL_SCAVENGE_MATCH_FINISHED,
	MC_SIGNAL_SCAVENGE_ROUND_START,
	MC_SIGNAL_SCAVENGE_ROUND_HALFTIME,
	MC_SIGNAL_SCAVENGE_ROUND_FINISHED,
	MC_SIGNAL_BEGIN_SCAVENGE_OVERTIME,
	MC_SIGNAL_SCAVENGE_SCORE_TIED,
	MC_SIGNAL_SURVIVAL_ROUND_START,
	MC_SIGNAL_VERSUS_ROUND_START
}

enum MC_LifecycleAction
{
	MC_ACTION_NONE = 0,
	MC_ACTION_QUEUE_CHANGE,
	MC_ACTION_CHANGE_IMMEDIATE
}

enum MC_LifecyclePhase
{
	MC_PHASE_UNKNOWN = 0,
	MC_PHASE_PRELIVE,
	MC_PHASE_LIVE,
	MC_PHASE_HALFTIME,
	MC_PHASE_POSTROUND,
	MC_PHASE_MATCH_END
}

enum struct MC_EventState
{
	MC_LifecycleSignal lastSignal;
	bool hasRoundEndObserved;
	bool isSecondHalf;
	bool overtime;
	bool scoreTied;

	void Reset()
	{
		this.lastSignal = MC_SIGNAL_NONE;
		this.hasRoundEndObserved = false;
		this.isSecondHalf = false;
		this.overtime = false;
		this.scoreTied = false;
	}
}

enum struct MC_LifecycleState
{
	int gamemode;
	MC_LifecyclePhase phase;
	bool live;
	bool overtime;
	bool hasNextTarget;
	bool hasVoteOverride;
	bool finalMap;
	bool effectiveFinalMap;
	bool syntheticCompetitiveFinale;
	bool competitiveFinaleConfigured;
	bool competitiveFinaleDisabled;
	int competitiveFinaleMapNumber;
	char currentMap[LEN_MAP_FILENAME];
	char configuredNextMap[LEN_MAP_FILENAME];
	char effectiveNextMap[LEN_MAP_FILENAME];
	char announceMap[LEN_MAP_FILENAME];
	char configuredNaturalEnd[32];
	char configuredTargetScope[16];
}

MC_LifecycleState g_MC_LifecycleState;
MC_EventState g_MC_EventState;

bool MC_Lifecycle_IsModeLiveGamemode(int gamemode)
{
	return gamemode == GAMEMODE_COOP
		|| gamemode == GAMEMODE_VERSUS
		|| gamemode == GAMEMODE_SURVIVAL
		|| gamemode == GAMEMODE_SCAVENGE;
}

MC_LifecycleSignal MC_Lifecycle_SignalFromEventName(const char[] eventName)
{
	if (StrEqual(eventName, "round_start", false))
		return MC_SIGNAL_ROUND_START;
	if (StrEqual(eventName, "round_end", false))
		return MC_SIGNAL_ROUND_END;
	if (StrEqual(eventName, "map_transition", false))
		return MC_SIGNAL_MAP_TRANSITION;
	if (StrEqual(eventName, "finale_win", false))
		return MC_SIGNAL_FINAL_WIN;
	if (StrEqual(eventName, "mission_lost", false))
		return MC_SIGNAL_MISSION_LOST;
	if (StrEqual(eventName, "scavenge_match_finished", false))
		return MC_SIGNAL_SCAVENGE_MATCH_FINISHED;
	if (StrEqual(eventName, "scavenge_round_start", false))
		return MC_SIGNAL_SCAVENGE_ROUND_START;
	if (StrEqual(eventName, "scavenge_round_halftime", false))
		return MC_SIGNAL_SCAVENGE_ROUND_HALFTIME;
	if (StrEqual(eventName, "scavenge_round_finished", false))
		return MC_SIGNAL_SCAVENGE_ROUND_FINISHED;
	if (StrEqual(eventName, "begin_scavenge_overtime", false))
		return MC_SIGNAL_BEGIN_SCAVENGE_OVERTIME;
	if (StrEqual(eventName, "scavenge_score_tied", false))
		return MC_SIGNAL_SCAVENGE_SCORE_TIED;
	if (StrEqual(eventName, "survival_round_start", false))
		return MC_SIGNAL_SURVIVAL_ROUND_START;
	if (StrEqual(eventName, "versus_round_start", false))
		return MC_SIGNAL_VERSUS_ROUND_START;

	return MC_SIGNAL_NONE;
}

void MC_Lifecycle_SyncState()
{
	g_MC_LifecycleState.gamemode = g_iMode;
	g_MC_LifecycleState.live = MC_Lifecycle_IsModeLiveGamemode(g_iMode);
	g_MC_LifecycleState.overtime = g_MC_EventState.overtime;
	g_MC_LifecycleState.hasNextTarget = g_sNextMap[0] != '\0';
	g_MC_LifecycleState.hasVoteOverride = g_bHasVoteOverride;
	g_MC_LifecycleState.finalMap = g_bFinalMap;
	g_MC_LifecycleState.effectiveFinalMap = g_bEffectiveFinalMap;
	g_MC_LifecycleState.syntheticCompetitiveFinale = MC_IsCurrentMapSyntheticCompetitiveFinale();
	g_MC_LifecycleState.competitiveFinaleConfigured = MC_IsCompetitiveFinaleEnabled();
	g_MC_LifecycleState.competitiveFinaleDisabled = MC_IsCompetitiveFinaleDisabled();
	g_MC_LifecycleState.competitiveFinaleMapNumber = MC_IsCompetitiveFinaleEnabled() ? MC_COMPETITIVE_FINALE_MAP_NUMBER : -1;
	strcopy(g_MC_LifecycleState.currentMap, sizeof(g_MC_LifecycleState.currentMap), g_sCurrentMap);
	strcopy(g_MC_LifecycleState.configuredNextMap, sizeof(g_MC_LifecycleState.configuredNextMap), g_sConfiguredNextMap);
	strcopy(g_MC_LifecycleState.effectiveNextMap, sizeof(g_MC_LifecycleState.effectiveNextMap), g_sNextMap);
	strcopy(g_MC_LifecycleState.announceMap, sizeof(g_MC_LifecycleState.announceMap), g_sAnnounceMap);
}

void MC_Lifecycle_DebugSignal(const char[] eventName)
{
	MC_Lifecycle_SyncState();
	MC_Debug(
		MC_Debug_Event,
		"lifecycle_event name=%s signal=%d mode=%d final=%d effective=%d synthetic=%d competitive_finale=%d finale_map=%d finale_disabled=%d next=%s configured=%s override=%d phase=%d live=%d overtime=%d second_half=%d tied=%d natural_end=%s scope=%s",
		eventName,
		g_MC_EventState.lastSignal,
		g_MC_LifecycleState.gamemode,
		g_MC_LifecycleState.finalMap,
		g_MC_LifecycleState.effectiveFinalMap,
		g_MC_LifecycleState.syntheticCompetitiveFinale,
		g_MC_LifecycleState.competitiveFinaleConfigured,
		g_MC_LifecycleState.competitiveFinaleMapNumber,
		g_MC_LifecycleState.competitiveFinaleDisabled,
		g_MC_LifecycleState.effectiveNextMap,
		g_MC_LifecycleState.configuredNextMap,
		g_MC_LifecycleState.hasVoteOverride,
		g_MC_LifecycleState.phase,
		g_MC_LifecycleState.live,
		g_MC_LifecycleState.overtime,
		g_MC_EventState.isSecondHalf,
		g_MC_EventState.scoreTied,
		g_MC_LifecycleState.configuredNaturalEnd,
		g_MC_LifecycleState.configuredTargetScope
	);
}

void MC_Lifecycle_HandleSignal(const char[] eventName, MC_LifecycleSignal signal)
{
	g_MC_EventState.lastSignal = signal;
	MC_Lifecycle_DebugSignal(eventName);

	if (!MC_IsModeEnabled(g_iMode))
		return;

	if (g_sNextMap[0] == '\0')
		return;

	switch (signal)
	{
		case MC_SIGNAL_ROUND_START:
		{
			g_bHasRoundEnd = false;
			g_MC_EventState.hasRoundEndObserved = false;
			g_MC_EventState.scoreTied = false;
			g_MC_RoundEndContext.Reset();
			g_MC_LifecycleState.phase = MC_PHASE_PRELIVE;
			g_MC_EventState.overtime = false;
			MC_RefreshEffectiveFinalState();
			MC_Policy_OnRoundStart();
		}
		case MC_SIGNAL_ROUND_END:
		{
			if (g_bHasRoundEnd)
				return;

			g_bHasRoundEnd = true;
			g_MC_EventState.hasRoundEndObserved = true;
			g_MC_EventState.isSecondHalf = view_as<bool>(GameRules_GetProp("m_bInSecondHalfOfRound"));
			g_MC_LifecycleState.phase = MC_PHASE_POSTROUND;
			MC_RefreshEffectiveFinalState();

			MC_Policy_OnRoundEnd();
		}
		case MC_SIGNAL_MAP_TRANSITION:
		{
			g_MC_LifecycleState.phase = MC_PHASE_MATCH_END;
			MC_RefreshEffectiveFinalState();

			MC_Policy_OnNaturalMapAdvance();
		}
		case MC_SIGNAL_FINAL_WIN:
		{
			g_MC_LifecycleState.phase = MC_PHASE_MATCH_END;
			MC_RefreshEffectiveFinalState();

			MC_Policy_OnFinalWin();
		}
		case MC_SIGNAL_MISSION_LOST:
		{
			g_MC_LifecycleState.phase = MC_PHASE_MATCH_END;
			MC_RefreshEffectiveFinalState();

			MC_Policy_OnMissionLost();
		}
		case MC_SIGNAL_SCAVENGE_MATCH_FINISHED:
		{
			g_MC_LifecycleState.phase = MC_PHASE_MATCH_END;
			MC_RefreshEffectiveFinalState();

			MC_Policy_OnScavengeMatchFinished();
		}
		case MC_SIGNAL_SCAVENGE_ROUND_START:
		{
			g_bHasRoundEnd = false;
			g_MC_EventState.hasRoundEndObserved = false;
			g_MC_EventState.scoreTied = false;
			g_MC_LifecycleState.phase = MC_PHASE_PRELIVE;
			g_MC_EventState.overtime = false;
			MC_RefreshEffectiveFinalState();
		}
		case MC_SIGNAL_SCAVENGE_ROUND_HALFTIME:
		{
			g_MC_LifecycleState.phase = MC_PHASE_HALFTIME;
			MC_RefreshEffectiveFinalState();
		}
		case MC_SIGNAL_SCAVENGE_ROUND_FINISHED:
		{
			g_MC_LifecycleState.phase = MC_PHASE_POSTROUND;
			MC_RefreshEffectiveFinalState();
			MC_Policy_OnScavengeRoundFinished();
		}
		case MC_SIGNAL_BEGIN_SCAVENGE_OVERTIME:
		{
			g_MC_EventState.overtime = true;
			MC_RefreshEffectiveFinalState();
		}
		case MC_SIGNAL_SCAVENGE_SCORE_TIED:
		{
			g_MC_EventState.scoreTied = true;
			MC_RefreshEffectiveFinalState();
		}
		case MC_SIGNAL_SURVIVAL_ROUND_START:
		{
			g_bHasRoundEnd = false;
			g_MC_EventState.hasRoundEndObserved = false;
			g_MC_EventState.scoreTied = false;
			g_MC_LifecycleState.phase = MC_PHASE_PRELIVE;
			g_MC_EventState.overtime = false;
			MC_RefreshEffectiveFinalState();
			MC_Policy_OnRoundStart();
		}
		case MC_SIGNAL_VERSUS_ROUND_START:
		{
			g_bHasRoundEnd = false;
			g_MC_EventState.hasRoundEndObserved = false;
			g_MC_LifecycleState.phase = MC_PHASE_PRELIVE;
			MC_RefreshEffectiveFinalState();
		}
		case MC_SIGNAL_NONE:
		{
		}
	}
}
