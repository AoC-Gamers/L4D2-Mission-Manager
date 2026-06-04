#if defined _l4d2_mission_controller_limits_included
	#endinput
#endif
#define _l4d2_mission_controller_limits_included

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
	if (g_bEffectiveFinalMap && g_MC_EventState.isSecondHalf)
	{
		MC_ForceRoundEndMessage();
		MC_QueueChangeMap(g_fVersusDelay);
	}
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
