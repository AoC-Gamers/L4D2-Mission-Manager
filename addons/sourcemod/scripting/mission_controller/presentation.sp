#if defined _l4d2_mission_controller_presentation_included
	#endinput
#endif
#define _l4d2_mission_controller_presentation_included

bool MC_ShouldAnnounceNextMapToClient()
{
	return g_iMode == GAMEMODE_SURVIVAL || g_iMode == GAMEMODE_SCAVENGE || g_bEffectiveFinalMap;
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

	bool hasChapter = MC_ResolveLocalizedMapName(client, mapName, chapterName, sizeof(chapterName));
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

void MC_AnnounceCompetitiveFinaleDisabledToAll()
{
	if (g_cvAnnounce != null && !g_cvAnnounce.BoolValue)
		return;

	CPrintToChatAll("%t %t", "Tag", "CompetitiveFinaleAnnounceDisabled");
}

void MC_AnnounceCompetitiveFinaleEnabledToAll()
{
	if (g_cvAnnounce != null && !g_cvAnnounce.BoolValue)
		return;

	CPrintToChatAll("%t %t", "Tag", "CompetitiveFinaleAnnounceEnabled");
}
