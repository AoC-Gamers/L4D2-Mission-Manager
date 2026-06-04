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

int MC_GetReplyLanguage(int client)
{
	return client > 0 ? client : LANG_SERVER;
}

bool MC_CommandCameFromChat(int client)
{
	return client > 0 && IsChatTrigger();
}

ReplySource MC_BeginConsoleCommandOutput(int client, bool &fromChat)
{
	fromChat = MC_CommandCameFromChat(client);
	return SetCmdReplySource(SM_REPLY_TO_CONSOLE);
}

void MC_EndConsoleCommandOutput(int client, ReplySource previous, bool fromChat)
{
	SetCmdReplySource(previous);

	if (fromChat)
	{
		CPrintToChat(client, "%t %t", "Tag", "MCHelpSentToConsole");
	}
}

void MC_ReplyHelp(int client)
{
	int language = MC_GetReplyLanguage(client);
	CReplyToCommand(client, "%T %T", "Tag", language, "MCHelpHeader", language);
	CReplyToCommand(client, "%T %T", "Tag", language, "MCHelpMenu", language);
	CReplyToCommand(client, "%T %T", "Tag", language, "MCHelpVote", language);
	CReplyToCommand(client, "%T %T", "Tag", language, "MCHelpExtend", language);
	CReplyToCommand(client, "%T %T", "Tag", language, "MCHelpNext", language);
	CReplyToCommand(client, "%T %T", "Tag", language, "MCHelpCompetitiveFinale", language);
	CReplyToCommand(client, "%T %T", "Tag", language, "MCHelpHelp", language);
}

public Action MC_CommandHelp(int client, int args)
{
	MC_Debug(MC_Debug_Announce, "command_help client=%d args=%d", client, args);
	bool fromChat;
	ReplySource previous = MC_BeginConsoleCommandOutput(client, fromChat);
	MC_ReplyHelp(client);
	MC_EndConsoleCommandOutput(client, previous, fromChat);
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

	if (!MC_CanDisableCompetitiveFinaleForCurrentCampaign())
	{
		CPrintToChat(client, "%t %t", "Tag", "CompetitiveFinaleUnavailable");
		return Plugin_Handled;
	}

	if (!MC_StartExtendMatchVote(client))
		return Plugin_Handled;

	return Plugin_Handled;
}

public Action MC_CommandFinale(int client, int args)
{
	if (args < 1)
	{
		bool fromChat;
		ReplySource previous = MC_BeginConsoleCommandOutput(client, fromChat);
		MC_ReplyCompetitiveFinaleStatus(client);
		MC_EndConsoleCommandOutput(client, previous, fromChat);
		return Plugin_Handled;
	}

	char arg[16];
	GetCmdArg(1, arg, sizeof(arg));

	if (StrEqual(arg, "off", false) || StrEqual(arg, "disable", false))
	{
		bool fromChat;
		ReplySource previous = MC_BeginConsoleCommandOutput(client, fromChat);

		if (!MC_SetCompetitiveFinaleDisabledForCurrentCampaign(true, true))
		{
			if (g_bCompetitiveFinaleDisabled)
				CReplyToCommand(client, "%T %T", "Tag", client, "CompetitiveFinaleDisabled", client);
			else
				CReplyToCommand(client, "%T %T", "Tag", client, "CompetitiveFinaleStatusUnset", client);
			MC_EndConsoleCommandOutput(client, previous, fromChat);
			return Plugin_Handled;
		}
		CReplyToCommand(client, "%T %T", "Tag", client, "CompetitiveFinaleDisabled", client);
		MC_EndConsoleCommandOutput(client, previous, fromChat);
		return Plugin_Handled;
	}

	if (StrEqual(arg, "on", false) || StrEqual(arg, "enable", false))
	{
		bool fromChat;
		ReplySource previous = MC_BeginConsoleCommandOutput(client, fromChat);
		if (!MC_SetCompetitiveFinaleDisabledForCurrentCampaign(false, true))
			CReplyToCommand(client, "%T %T", "Tag", client, "CompetitiveFinaleStatusUnset", client);
		else
			CReplyToCommand(client, "%T %T", "Tag", client, "CompetitiveFinaleEnabled", client);
		MC_EndConsoleCommandOutput(client, previous, fromChat);
		return Plugin_Handled;
	}

	if (StrEqual(arg, "status", false))
	{
		bool fromChat;
		ReplySource previous = MC_BeginConsoleCommandOutput(client, fromChat);
		MC_ReplyCompetitiveFinaleStatus(client);
		MC_EndConsoleCommandOutput(client, previous, fromChat);
		return Plugin_Handled;
	}

	bool fromChat;
	ReplySource previous = MC_BeginConsoleCommandOutput(client, fromChat);
	CReplyToCommand(client, "%T %T", "Tag", client, "CompetitiveFinaleUsage", client);
	MC_EndConsoleCommandOutput(client, previous, fromChat);
	return Plugin_Handled;
}

public Action MC_CommandNextTarget(int client, int args)
{
	bool fromChat;
	ReplySource previous = MC_BeginConsoleCommandOutput(client, fromChat);

	if (g_sNextMap[0] == '\0')
	{
		if (g_iAnnouncementType == ANNOUNCEMENT_INVALID_MAP)
			MC_ReplyNextTarget(client, true, g_sAnnounceMap);
		else
			MC_ReplyMissingNextTarget(client);
		MC_EndConsoleCommandOutput(client, previous, fromChat);
		return Plugin_Handled;
	}

	char announceTarget[LEN_LOCALIZED_NAME];
	MC_BuildClientAnnouncementTarget(client, announceTarget, sizeof(announceTarget));
	MC_ReplyNextTarget(client, false, announceTarget);
	MC_EndConsoleCommandOutput(client, previous, fromChat);
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

bool MC_CanDisableCompetitiveFinaleForCurrentCampaign()
{
	return g_iMode == GAMEMODE_VERSUS && MC_ShouldApplyCompetitiveFinale();
}

bool MC_DisableCompetitiveFinaleForCurrentCampaign(bool announce = false)
{
	if (!MC_CanDisableCompetitiveFinaleForCurrentCampaign())
		return false;

	char voteOverrideMap[LEN_MAP_FILENAME];
	bool hadVoteOverride = g_bHasVoteOverride && g_sVoteNextMap[0] != '\0';
	if (hadVoteOverride)
		strcopy(voteOverrideMap, sizeof(voteOverrideMap), g_sVoteNextMap);

	GetCurrentMap(g_sCurrentMap, sizeof(g_sCurrentMap));
	g_bCompetitiveFinaleDisabled = true;
	g_sCompetitiveFinaleOverrideCampaign[0] = '\0';
	if (!Campaign_ExtractCampaignCode(g_sCurrentMap, g_sCompetitiveFinaleOverrideCampaign, sizeof(g_sCompetitiveFinaleOverrideCampaign)))
	{
		g_bCompetitiveFinaleDisabled = false;
		return false;
	}

	MC_InitializeAutoChangeState();
	if (hadVoteOverride)
		MC_ApplyVoteNextMapOverride(voteOverrideMap);

	if (announce)
		MC_AnnounceCompetitiveFinaleDisabledToAll();

	MC_SyncCompetitiveFinaleState();
	return true;
}

void MC_ReplyCompetitiveFinaleStatus(int client)
{
	int configuredMap = MC_IsCompetitiveFinaleEnabled() ? MC_COMPETITIVE_FINALE_MAP_NUMBER : -1;
	if (configuredMap < 1)
	{
		CReplyToCommand(client, "%T %T", "Tag", client, "CompetitiveFinaleStatusUnset", client);
		return;
	}

	if (g_bCompetitiveFinaleDisabled)
		CReplyToCommand(client, "%T %T", "Tag", client, "CompetitiveFinaleStatusDisabled", client, configuredMap);
	else
		CReplyToCommand(client, "%T %T", "Tag", client, "CompetitiveFinaleStatusEnabled", client, configuredMap);
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
