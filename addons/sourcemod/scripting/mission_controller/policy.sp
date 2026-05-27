#if defined _l4d2_mission_controller_policy_included
	#endinput
#endif
#define _l4d2_mission_controller_policy_included

bool MC_Policy_UsesNaturalEnd(const char[] naturalEnd)
{
	bool matches = naturalEnd[0] != '\0' && StrEqual(g_MC_LifecycleState.configuredNaturalEnd, naturalEnd, false);
	MC_Debug(
		MC_Debug_Policy,
		"policy_check_natural_end configured=%s expected=%s matches=%d",
		g_MC_LifecycleState.configuredNaturalEnd,
		naturalEnd,
		matches
	);
	return matches;
}

void MC_Policy_ChangeToConfiguredTarget()
{
	if (g_sNextMap[0] == '\0')
	{
		MC_Debug(MC_Debug_Policy, "policy_change_target_skipped reason=no_next_map");
		return;
	}

	MC_Debug(MC_Debug_Policy, "policy_change_target next=%s ext=%d", g_sNextMap, g_ServerRuntime.hasChangeLevel);
	if (g_ServerRuntime.hasChangeLevel)
		L4D2_ChangeLevel(g_sNextMap);
	else
		ServerCommand("changelevel %s", g_sNextMap);
}

void MC_Policy_OnRoundStart()
{
	MC_Debug(MC_Debug_Policy, "policy_round_start mode=%d phase=%d", g_iMode, g_MC_LifecycleState.phase);

	switch (g_iMode)
	{
		case GAMEMODE_COOP:
			MC_HandleCoopRoundStartEvent();
		case GAMEMODE_SURVIVAL:
			MC_HandleSurvivalRoundStartEvent();
	}
}

void MC_Policy_OnRoundEnd()
{
	MC_Debug(
		MC_Debug_Policy,
		"policy_round_end mode=%d phase=%d second_half=%d natural_end=%s",
		g_iMode,
		g_MC_LifecycleState.phase,
		g_MC_EventState.isSecondHalf,
		g_MC_LifecycleState.configuredNaturalEnd
	);

	switch (g_iMode)
	{
		case GAMEMODE_VERSUS:
		{
			if (!MC_Policy_UsesNaturalEnd("round_end_second_half"))
			{
				MC_Debug(MC_Debug_Policy, "policy_round_end_ignored mode=versus reason=natural_end_mismatch");
				return;
			}

			MC_Debug(MC_Debug_Policy, "policy_round_end_apply mode=versus");
			MC_HandleVersusRoundEndEvent();
		}
		case GAMEMODE_SURVIVAL:
		{
			if (!MC_Policy_UsesNaturalEnd("round_end"))
			{
				MC_Debug(MC_Debug_Policy, "policy_round_end_ignored mode=survival reason=natural_end_mismatch");
				return;
			}

			MC_Debug(MC_Debug_Policy, "policy_round_end_apply mode=survival");
			MC_HandleSurvivalRoundEndEvent();
		}
	}
}

void MC_Policy_OnNaturalMapAdvance()
{
	if (!MC_Policy_UsesNaturalEnd("map_transition"))
	{
		MC_Debug(MC_Debug_Policy, "policy_map_advance_ignored reason=natural_end_mismatch");
		return;
	}

	if (!g_bEffectiveFinalMap || g_bFinalMap)
	{
		MC_Debug(
			MC_Debug_Policy,
			"policy_map_advance_ignored reason=final_state effective=%d final=%d",
			g_bEffectiveFinalMap,
			g_bFinalMap
		);
		return;
	}

	MC_Debug(MC_Debug_Policy, "policy_map_advance_apply next=%s", g_sNextMap);
	MC_Policy_ChangeToConfiguredTarget();
}

void MC_Policy_OnFinalWin()
{
	bool usesNaturalEnd = MC_Policy_UsesNaturalEnd("finale_win");
	MC_Debug(
		MC_Debug_Policy,
		"policy_final_win natural_end_match=%d delay=%.1f next=%s",
		usesNaturalEnd,
		g_fCoopFinalDelay,
		g_sNextMap
	);

	if (usesNaturalEnd && g_fCoopFinalDelay > 0.0)
	{
		MC_Debug(MC_Debug_Policy, "policy_final_win_queue delay=%.1f", g_fCoopFinalDelay);
		MC_QueueChangeMap(g_fCoopFinalDelay);
	}
}

void MC_Policy_OnMissionLost()
{
	if (g_iMode == GAMEMODE_COOP)
	{
		MC_Debug(MC_Debug_Policy, "policy_mission_lost_apply mode=coop");
		MC_HandleCoopMissionLostEvent();
	}
	else
	{
		MC_Debug(MC_Debug_Policy, "policy_mission_lost_ignored mode=%d", g_iMode);
	}
}

void MC_Policy_OnScavengeMatchFinished()
{
	bool usesNaturalEnd = MC_Policy_UsesNaturalEnd("scavenge_match_finished");
	MC_Debug(
		MC_Debug_Policy,
		"policy_scavenge_match_finished natural_end_match=%d delay=%.1f overtime=%d tied=%d",
		usesNaturalEnd,
		g_fVersusDelay,
		g_MC_EventState.overtime,
		g_MC_EventState.scoreTied
	);

	if (usesNaturalEnd && g_fVersusDelay > 0.0)
	{
		MC_Debug(MC_Debug_Policy, "policy_scavenge_match_finished_queue delay=%.1f", g_fVersusDelay);
		MC_QueueChangeMap(g_fVersusDelay);
	}
}

void MC_Policy_OnScavengeRoundFinished()
{
	bool usesNaturalEnd = MC_Policy_UsesNaturalEnd("scavenge_round_finished");
	MC_Debug(
		MC_Debug_Policy,
		"policy_scavenge_round_finished natural_end_match=%d delay=%.1f overtime=%d tied=%d second_half=%d",
		usesNaturalEnd,
		g_fVersusDelay,
		g_MC_EventState.overtime,
		g_MC_EventState.scoreTied,
		g_MC_EventState.isSecondHalf
	);

	if (usesNaturalEnd && g_fVersusDelay > 0.0)
	{
		MC_Debug(MC_Debug_Policy, "policy_scavenge_round_finished_queue delay=%.1f", g_fVersusDelay);
		MC_QueueChangeMap(g_fVersusDelay);
	}
}
