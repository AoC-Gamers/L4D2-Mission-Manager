#if defined _l4d2_mission_controller_core_included
	#endinput
#endif
#define _l4d2_mission_controller_core_included

public Action MC_CommandMissionMenu(int client, int args)
{
	if (!MC_IsValidHumanClient(client))
	{
		CPrintToChat(client, "%t %t", "Tag", "InGameOnly");
		return Plugin_Handled;
	}

	MC_ShowMissionListMenu(client, MENU_MODE_INSTANT);
	return Plugin_Handled;
}

public Action MC_CommandMissionVote(int client, int args)
{
	if (!MC_IsValidHumanClient(client))
	{
		CPrintToChat(client, "%t %t", "Tag", "InGameOnly");
		return Plugin_Handled;
	}

	MC_ShowMissionListMenu(client, MENU_MODE_VOTE);
	return Plugin_Handled;
}

public Action MC_CommandMatchExtendVote(int client, int args)
{
	if (!MC_IsValidHumanClient(client))
	{
		CPrintToChat(client, "%t %t", "Tag", "InGameOnly");
		return Plugin_Handled;
	}

	if (!MC_CanExtendCurrentCampaign())
	{
		CPrintToChat(client, "%t %t", "Tag", "ExtendVoteUnavailable");
		return Plugin_Handled;
	}

	if (!MC_StartExtendMatchVote(client))
		return Plugin_Handled;

	return Plugin_Handled;
}

public Action MC_CommandMatchEndMapOverride(int client, int args)
{
	if (args < 1)
	{
		MC_ReplyMatchEndMapOverrideStatus(client);
		return Plugin_Handled;
	}

	char arg[16];
	GetCmdArg(1, arg, sizeof(arg));

	if (StrEqual(arg, "off", false) || StrEqual(arg, "disable", false))
	{
		if (!MC_DisableMatchEndMapLimitForCurrentCampaign(true))
		{
			if (g_bMatchEndMapOverrideDisabled)
				CReplyToCommand(client, "%T %T", "Tag", client, "MatchEndMapOverrideDisabled", client);
			else
				CReplyToCommand(client, "%T %T", "Tag", client, "MatchEndMapOverrideStatusUnset", client);
			return Plugin_Handled;
		}
		CReplyToCommand(client, "%T %T", "Tag", client, "MatchEndMapOverrideDisabled", client);
		return Plugin_Handled;
	}

	if (StrEqual(arg, "on", false) || StrEqual(arg, "enable", false))
	{
		char voteOverrideMap[LEN_MAP_FILENAME];
		bool hadVoteOverride = g_bHasVoteOverride && g_sVoteNextMap[0] != '\0';
		if (hadVoteOverride)
			strcopy(voteOverrideMap, sizeof(voteOverrideMap), g_sVoteNextMap);

		g_bMatchEndMapOverrideDisabled = false;
		g_sMatchEndOverrideCampaign[0] = '\0';
		MC_InitializeAutoChangeState();
		if (hadVoteOverride)
			MC_ApplyVoteNextMapOverride(voteOverrideMap);
		MC_AnnounceMatchEndMapLimitEnabledToAll();
		CReplyToCommand(client, "%T %T", "Tag", client, "MatchEndMapOverrideEnabled", client);
		return Plugin_Handled;
	}

	if (StrEqual(arg, "status", false))
	{
		MC_ReplyMatchEndMapOverrideStatus(client);
		return Plugin_Handled;
	}

	CReplyToCommand(client, "%T %T", "Tag", client, "MatchEndMapOverrideUsage", client);
	return Plugin_Handled;
}

public Action MC_CommandNextTarget(int client, int args)
{
	if (g_sNextMap[0] == '\0')
	{
		if (g_iAnnouncementType == ANNOUNCEMENT_INVALID_MAP)
			MC_ReplyNextTarget(client, true, g_sAnnounceMap);
		else
			MC_ReplyMissingNextTarget(client);
		return Plugin_Handled;
	}

	char announceTarget[LEN_LOCALIZED_NAME];
	MC_BuildClientAnnouncementTarget(client, announceTarget, sizeof(announceTarget));
	MC_ReplyNextTarget(client, false, announceTarget);
	return Plugin_Handled;
}

bool MC_IsValidHumanClient(int client)
{
	return client > 0 && client <= MaxClients && IsClientInGame(client) && !IsFakeClient(client);
}

bool MC_IsModeEnabled(int gamemode)
{
	int enabledModes = g_cvEnableModes.IntValue;

	switch (gamemode)
	{
		case GAMEMODE_COOP:
			return (enabledModes & 1) != 0;
		case GAMEMODE_VERSUS:
			return (enabledModes & 2) != 0;
		case GAMEMODE_SURVIVAL:
			return (enabledModes & 4) != 0;
		case GAMEMODE_SCAVENGE:
			return (enabledModes & 8) != 0;
	}

	return false;
}

bool MC_CanExtendCurrentCampaign()
{
	return (g_iMode == GAMEMODE_COOP || g_iMode == GAMEMODE_VERSUS)
		&& g_cvMatchEndMap != null
		&& g_cvMatchEndMap.IntValue > 0
		&& !g_bMatchEndMapOverrideDisabled;
}

bool MC_DisableMatchEndMapLimitForCurrentCampaign(bool announce = false)
{
	if (!MC_CanExtendCurrentCampaign())
		return false;

	char voteOverrideMap[LEN_MAP_FILENAME];
	bool hadVoteOverride = g_bHasVoteOverride && g_sVoteNextMap[0] != '\0';
	if (hadVoteOverride)
		strcopy(voteOverrideMap, sizeof(voteOverrideMap), g_sVoteNextMap);

	GetCurrentMap(g_sCurrentMap, sizeof(g_sCurrentMap));
	g_bMatchEndMapOverrideDisabled = true;
	g_sMatchEndOverrideCampaign[0] = '\0';
	if (!Campaign_ExtractCampaignCode(g_sCurrentMap, g_sMatchEndOverrideCampaign, sizeof(g_sMatchEndOverrideCampaign)))
	{
		g_bMatchEndMapOverrideDisabled = false;
		return false;
	}

	MC_InitializeAutoChangeState();
	if (hadVoteOverride)
		MC_ApplyVoteNextMapOverride(voteOverrideMap);

	if (announce)
		MC_AnnounceMatchEndMapLimitDisabledToAll();

	return true;
}

void MC_ReplyMatchEndMapOverrideStatus(int client)
{
	int configuredMap = g_cvMatchEndMap != null ? g_cvMatchEndMap.IntValue : -1;
	if (configuredMap < 1)
	{
		CReplyToCommand(client, "%T %T", "Tag", client, "MatchEndMapOverrideStatusUnset", client);
		return;
	}

	if (g_bMatchEndMapOverrideDisabled)
		CReplyToCommand(client, "%T %T", "Tag", client, "MatchEndMapOverrideStatusDisabled", client, configuredMap);
	else
		CReplyToCommand(client, "%T %T", "Tag", client, "MatchEndMapOverrideStatusEnabled", client, configuredMap);
}

void MC_ReplyMissingNextTarget(int client)
{
	switch (g_iMode)
	{
		case GAMEMODE_COOP, GAMEMODE_VERSUS:
			CReplyToCommand(client, "%T %T", "Tag", client, "MCNextMissionMissing", client);
		case GAMEMODE_SURVIVAL, GAMEMODE_SCAVENGE:
			CReplyToCommand(client, "%T %T", "Tag", client, "MCNextMapMissing", client);
		default:
			CReplyToCommand(client, "%T %T", "Tag", client, "MCNextTargetMissing", client);
	}
}

void MC_ReplyNextTarget(int client, bool invalid, const char[] value)
{
	switch (g_iMode)
	{
		case GAMEMODE_COOP, GAMEMODE_VERSUS:
		{
			if (invalid)
				CReplyToCommand(client, "%T %T", "Tag", client, "MCNextMissionInvalid", client, value);
			else
				CReplyToCommand(client, "%T %T", "Tag", client, "MCNextMissionCurrent", client, value);
		}
		case GAMEMODE_SURVIVAL, GAMEMODE_SCAVENGE:
		{
			if (invalid)
				CReplyToCommand(client, "%T %T", "Tag", client, "MCNextMapInvalid", client, value);
			else
				CReplyToCommand(client, "%T %T", "Tag", client, "MCNextMapCurrent", client, value);
		}
		default:
		{
			if (invalid)
				CReplyToCommand(client, "%T %T", "Tag", client, "MCNextTargetInvalid", client, value);
			else
				CReplyToCommand(client, "%T %T", "Tag", client, "MCNextTargetCurrent", client, value);
		}
	}
}
