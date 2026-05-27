#if defined _l4d2_mission_controller_actions_included
	#endinput
#endif
#define _l4d2_mission_controller_actions_included

void MC_ClearChangeMapTimer()
{
	if (g_hChangeMapTimer != null)
	{
		delete g_hChangeMapTimer;
		g_hChangeMapTimer = null;
	}

	g_bChangeMapScheduled = false;
}

void MC_QueueChangeMap(float delay)
{
	if (delay <= 0.0 || g_sNextMap[0] == '\0' || g_bChangeMapScheduled)
		return;

	g_bChangeMapScheduled = true;
	g_hChangeMapTimer = CreateTimer(delay, MC_TimerChangeMap, _, TIMER_FLAG_NO_MAPCHANGE);
	MC_Debug(MC_Debug_Action, "queue_change_map delay=%.1f next=%s", delay, g_sNextMap);
}

public Action MC_TimerChangeMap(Handle timer)
{
	g_hChangeMapTimer = null;
	g_bChangeMapScheduled = false;

	MC_Debug(MC_Debug_Action, "timer_change_map next=%s ext=%d", g_sNextMap, g_ServerRuntime.hasChangeLevel);
	if (g_ServerRuntime.hasChangeLevel)
		L4D2_ChangeLevel(g_sNextMap);
	else
		ServerCommand("changelevel %s", g_sNextMap);

	return Plugin_Stop;
}
