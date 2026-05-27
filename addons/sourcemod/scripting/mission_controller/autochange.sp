#if defined _l4d2_mission_controller_autochange_included
	#endinput
#endif
#define _l4d2_mission_controller_autochange_included

public void MC_EventRoundStart(Event event, const char[] name, bool dontBroadcast)
{
	MC_Lifecycle_HandleSignal(name, MC_Lifecycle_SignalFromEventName(name));
}

public void MC_EventRoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	MC_CaptureRoundEndContext(name, event);
	MC_Lifecycle_HandleSignal(name, MC_Lifecycle_SignalFromEventName(name));
}

public void MC_EventMapTransition(Event event, const char[] name, bool dontBroadcast)
{
	MC_Lifecycle_HandleSignal(name, MC_Lifecycle_SignalFromEventName(name));
}

public void MC_EventFinalWin(Event event, const char[] name, bool dontBroadcast)
{
	MC_Lifecycle_HandleSignal(name, MC_Lifecycle_SignalFromEventName(name));
}

public void MC_EventMissionLost(Event event, const char[] name, bool dontBroadcast)
{
	MC_Lifecycle_HandleSignal(name, MC_Lifecycle_SignalFromEventName(name));
}

public void MC_EventScavengeMatchFinished(Event event, const char[] name, bool dontBroadcast)
{
	MC_Lifecycle_HandleSignal(name, MC_Lifecycle_SignalFromEventName(name));
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

	MC_ValidateSettingsOrFail(settings);
	MC_ResolveAutoChangeState(settings);
	delete settings;
}

void MC_ResolveAutoChangeState(KeyValues settings)
{
	MC_ClearAutoChangeState();
	GetCurrentMap(g_sCurrentMap, sizeof(g_sCurrentMap));
	strcopy(g_MC_LifecycleState.currentMap, sizeof(g_MC_LifecycleState.currentMap), g_sCurrentMap);

	MC_UpdateCompetitiveFinaleOverrideState();
	MC_UpdateVoteOverrideState();
	MC_RefreshEffectiveFinalState();
	MC_Lifecycle_SyncState();

	if (!MC_IsModeEnabled(g_iMode))
	{
		return;
	}

	if (!MC_ResolveConfiguredNextTarget(settings))
	{
		MC_Debug(MC_Debug_Core, "resolve_state_missing_target current=%s mode=%d", g_sCurrentMap, g_iMode);
		return;
	}

	MC_Debug(
		MC_Debug_Core,
		"resolved_state current=%s mode=%d final=%d effective=%d mapnum=%d configured_campaign_final=%d disabled=%d next=%s configured=%s override=%d",
		g_sCurrentMap,
		g_iMode,
		g_bFinalMap,
		g_bEffectiveFinalMap,
		g_iCurrentMapIndex + 1,
		MC_IsCompetitiveFinaleEnabled() ? MC_COMPETITIVE_FINALE_MAP_NUMBER : -1,
		g_bCompetitiveFinaleDisabled,
		g_sNextMap,
		g_sConfiguredNextMap,
		g_bHasVoteOverride
	);
	MC_Lifecycle_SyncState();
	MC_NotifyNextMapChanged();
}
