#if defined _l4d2_mission_controller_menus_included
	#endinput
#endif
#define _l4d2_mission_controller_menus_included

void MC_ResetClientMenuState(int client)
{
	if (client < 1 || client > MaxClients)
		return;

	g_eSelectedGamemode[client]		= GAMEMODE_UNKNOWN;
	g_iSelectedMissionIndex[client] = -1;
	g_iSelectedMenuMode[client]		= MENU_MODE_INSTANT;
}

void MC_TryAttachAdminMenu()
{
	if (!g_ServerRuntime.hasAdminMenu)
		return;

	TopMenu topMenu = GetAdminTopMenu();
	if (topMenu == null)
		return;

	MC_RegisterAdminMenu(topMenu);
}

void MC_RegisterAdminMenu(TopMenu topMenu)
{
	if (topMenu == g_hTopMenu)
		return;

	g_hTopMenu = topMenu;
	g_hTopMenu.AddCategory("mission_controller", MC_AdminMenuCategoryHandler, "sm_mc_menu", ADMFLAG_CHANGEMAP);
}

public void OnAdminMenuReady(Handle topmenu)
{
	MC_RegisterAdminMenu(view_as<TopMenu>(topmenu));
}

public void MC_AdminMenuCategoryHandler(TopMenu topMenu, TopMenuAction action, TopMenuObject objectId, int param, char[] buffer, int maxlength)
{
	switch (action)
	{
		case TopMenuAction_DisplayTitle:
		{
			Format(buffer, maxlength, "Mission Controller");
		}
		case TopMenuAction_DisplayOption:
		{
			Format(buffer, maxlength, "Mission Controller");
		}
		case TopMenuAction_SelectOption:
		{
			MC_CommandMissionMenu(param, 0);
		}
	}
}

bool MC_HasValidMissionSelection(int client)
{
	int gamemode	 = g_eSelectedGamemode[client];
	int missionIndex = g_iSelectedMissionIndex[client];
	return gamemode != GAMEMODE_UNKNOWN
		&& missionIndex >= 0
		&& missionIndex < L4D2MM_GetNumberOfMissions(gamemode);
}

void MC_ResolveMissionDisplayName(int gamemode, int missionIndex, int client, char[] buffer, int maxlength)
{
	char missionName[LEN_MISSION_NAME];
	L4D2MM_GetMissionName(gamemode, missionIndex, missionName, sizeof(missionName));
	if (L4D2MM_GetMissionLocalizedName(gamemode, missionIndex, buffer, maxlength, client) <= 0)
	{
		strcopy(buffer, maxlength, missionName);
	}
}

void MC_ResolveMapDisplayName(int gamemode, int missionIndex, int mapIndex, int client, char[] buffer, int maxlength)
{
	char mapName[LEN_MAP_FILENAME];
	L4D2MM_GetMapName(gamemode, missionIndex, mapIndex, mapName, sizeof(mapName));
	if (L4D2MM_GetMapLocalizedName(gamemode, missionIndex, mapIndex, buffer, maxlength, client) <= 0)
	{
		strcopy(buffer, maxlength, mapName);
	}
}

void MC_ShowMissionListMenu(int client, int menuMode)
{
	int gamemode = L4D_GetGameModeType();
	if (gamemode == GAMEMODE_UNKNOWN)
	{
		CPrintToChat(client, "%t %t", "Tag", "GamemodeResolveFailed");
		return;
	}

	int missionCount = L4D2MM_GetNumberOfMissions(gamemode);
	if (missionCount < 1)
	{
		CPrintToChat(client, "%t %t", "Tag", "NoMissionsForGamemode");
		return;
	}

	Menu menu = new Menu(MC_MissionListMenuHandler);
	char gamemodeName[LEN_GAMEMODE_NAME];
	L4D2MM_GamemodeToString(gamemode, gamemodeName, sizeof(gamemodeName));
	if (menuMode == MENU_MODE_INSTANT)
		menu.SetTitle("Mission Controller (%s)", gamemodeName);
	else
		menu.SetTitle("Mission Vote (%s)", gamemodeName);

	for (int missionIndex = 0; missionIndex < missionCount; missionIndex++)
	{
		char missionDisplayName[LEN_LOCALIZED_NAME];
		char itemInfo[12];

		MC_ResolveMissionDisplayName(gamemode, missionIndex, client, missionDisplayName, sizeof(missionDisplayName));
		IntToString(missionIndex, itemInfo, sizeof(itemInfo));
		menu.AddItem(itemInfo, missionDisplayName);
	}

	menu.ExitBackButton = true;
	menu.ExitButton		= false;
	menu.Display(client, MENU_TIME_FOREVER);

	g_eSelectedGamemode[client]		= gamemode;
	g_iSelectedMissionIndex[client] = -1;
	g_iSelectedMenuMode[client]		= menuMode;
}

public int MC_MissionListMenuHandler(Menu menu, MenuAction action, int client, int item)
{
	switch (action)
	{
		case MenuAction_End:
		{
			delete menu;
		}
		case MenuAction_Select:
		{
			char itemInfo[12];
			menu.GetItem(item, itemInfo, sizeof(itemInfo));
			g_iSelectedMissionIndex[client] = StringToInt(itemInfo);

			int gamemode					= g_eSelectedGamemode[client];
			if (g_iSelectedMenuMode[client] == MENU_MODE_VOTE
				&& (gamemode == GAMEMODE_COOP || gamemode == GAMEMODE_VERSUS))
			{
				MC_HandleMapSelection(client, 0);
			}
			else
			{
				MC_ShowMapListMenu(client);
			}
		}
		case MenuAction_Cancel:
		{
			if (item == MenuCancel_ExitBack && g_hTopMenu != null)
			{
				g_hTopMenu.Display(client, TopMenuPosition_LastCategory);
			}
		}
	}

	return 0;
}

void MC_ShowMapListMenu(int client)
{
	if (!MC_HasValidMissionSelection(client))
	{
		CPrintToChat(client, "%t %t", "Tag", "MissionSelectionInvalid");
		return;
	}

	int gamemode	 = g_eSelectedGamemode[client];
	int missionIndex = g_iSelectedMissionIndex[client];
	int mapCount	 = L4D2MM_GetNumberOfMaps(gamemode, missionIndex);
	if (mapCount < 1)
	{
		CPrintToChat(client, "%t %t", "Tag", "MissionHasNoMaps");
		return;
	}

	char missionDisplayName[LEN_LOCALIZED_NAME];
	MC_ResolveMissionDisplayName(gamemode, missionIndex, client, missionDisplayName, sizeof(missionDisplayName));

	Menu menu = new Menu(MC_MapListMenuHandler);
	menu.SetTitle("%s [Maps]", missionDisplayName);

	for (int mapIndex = 0; mapIndex < mapCount; mapIndex++)
	{
		char mapDisplayName[LEN_LOCALIZED_NAME];
		char itemInfo[12];
		char mapName[LEN_MAP_FILENAME];

		MC_ResolveMapDisplayName(gamemode, missionIndex, mapIndex, client, mapDisplayName, sizeof(mapDisplayName));
		L4D2MM_GetMapName(gamemode, missionIndex, mapIndex, mapName, sizeof(mapName));
		Format(mapDisplayName, sizeof(mapDisplayName), "%s [%s]", mapDisplayName, mapName);
		IntToString(mapIndex, itemInfo, sizeof(itemInfo));
		menu.AddItem(itemInfo, mapDisplayName);
	}

	menu.ExitBackButton = true;
	menu.ExitButton		= false;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int MC_MapListMenuHandler(Menu menu, MenuAction action, int client, int item)
{
	switch (action)
	{
		case MenuAction_End:
		{
			delete menu;
		}
		case MenuAction_Select:
		{
			char itemInfo[12];
			menu.GetItem(item, itemInfo, sizeof(itemInfo));
			MC_HandleMapSelection(client, StringToInt(itemInfo));
		}
		case MenuAction_Cancel:
		{
			if (item == MenuCancel_ExitBack)
			{
				MC_ShowMissionListMenu(client, g_iSelectedMenuMode[client]);
			}
		}
	}

	return 0;
}

void MC_HandleMapSelection(int client, int mapIndex)
{
	if (!MC_HasValidMissionSelection(client))
	{
		CPrintToChat(client, "%t %t", "Tag", "MissionSelectionInvalid");
		return;
	}

	int gamemode	 = g_eSelectedGamemode[client];
	int missionIndex = g_iSelectedMissionIndex[client];
	int mapCount	 = L4D2MM_GetNumberOfMaps(gamemode, missionIndex);
	if (mapIndex < 0 || mapIndex >= mapCount)
	{
		CPrintToChat(client, "%t %t", "Tag", "MapSelectionInvalid");
		return;
	}

	char mapName[LEN_MAP_FILENAME];
	L4D2MM_GetMapName(gamemode, missionIndex, mapIndex, mapName, sizeof(mapName));

	switch (g_iSelectedMenuMode[client])
	{
		case MENU_MODE_INSTANT:
		{
			MC_ApplyVoteNextMapOverride(mapName);
			MC_AnnounceNextTargetUpdateToAll();
		}
		case MENU_MODE_VOTE:
		{
			MC_StartChangeLevelVote(client, gamemode, missionIndex, mapIndex, mapName);
		}
	}
}

bool MC_StartChangeLevelVote(int client, int gamemode, int missionIndex, int mapIndex, const char[] mapName)
{
	if (GetClientTeam(client) <= 1)
	{
		CPrintToChat(client, "%t %t", "Tag", "InGameOnly");
		return false;
	}

	if (IsBuiltinVoteInProgress())
	{
		CPrintToChat(client, "%t %t", "Tag", "VoteAlreadyInProgress");
		return false;
	}

	int voteDelay = CheckBuiltinVoteDelay();
	if (voteDelay > 0)
	{
		CPrintToChat(client, "%t %t", "Tag", "VoteDelay", voteDelay);
		return false;
	}

	char voteTarget[LEN_LOCALIZED_NAME];
	MC_BuildVoteTargetLabel(client, gamemode, missionIndex, mapIndex, mapName, voteTarget, sizeof(voteTarget));

	char title[192];
	switch (gamemode)
	{
		case GAMEMODE_COOP, GAMEMODE_VERSUS:
			Format(title, sizeof(title), "%T", "VoteTitleMission", client, voteTarget);
		case GAMEMODE_SURVIVAL, GAMEMODE_SCAVENGE:
			Format(title, sizeof(title), "%T", "VoteTitleMap", client, voteTarget);
		default:
			Format(title, sizeof(title), "%T", "VoteTitleTarget", client, voteTarget);
	}

	g_hVote = CreateBuiltinVote(MC_BuiltinVoteActionHandler, BuiltinVoteType_Custom_YesNo, BuiltinVoteAction_Cancel | BuiltinVoteAction_VoteEnd | BuiltinVoteAction_End);
	if (g_hVote == null)
	{
		CPrintToChat(client, "%t %t", "Tag", "VoteCreateFailed");
		return false;
	}

	strcopy(g_sVoteMap, sizeof(g_sVoteMap), mapName);
	g_iVoteType = VOTE_TYPE_NEXT_TARGET;
	SetBuiltinVoteArgument(g_hVote, title);
	SetBuiltinVoteInitiator(g_hVote, client);
	SetBuiltinVoteResultCallback(g_hVote, MC_BuiltinVoteResultHandler);

	if (!DisplayBuiltinVoteToAllNonSpectators(g_hVote, FindConVar("sv_vote_timer_duration").IntValue))
	{
		delete g_hVote;
		g_hVote		  = null;
		g_sVoteMap[0] = '\0';
		CPrintToChat(client, "%t %t", "Tag", "VoteStartFailed");
		return false;
	}

	FakeClientCommand(client, "Vote Yes");
	return true;
}

bool MC_StartExtendMatchVote(int client)
{
	if (GetClientTeam(client) <= 1)
	{
		CPrintToChat(client, "%t %t", "Tag", "InGameOnly");
		return false;
	}

	if (IsBuiltinVoteInProgress())
	{
		CPrintToChat(client, "%t %t", "Tag", "VoteAlreadyInProgress");
		return false;
	}

	int voteDelay = CheckBuiltinVoteDelay();
	if (voteDelay > 0)
	{
		CPrintToChat(client, "%t %t", "Tag", "VoteDelay", voteDelay);
		return false;
	}

	char title[192];
	Format(title, sizeof(title), "%T", "VoteTitleCompetitiveFinale", client);

	g_hVote = CreateBuiltinVote(MC_BuiltinVoteActionHandler, BuiltinVoteType_Custom_YesNo, BuiltinVoteAction_Cancel | BuiltinVoteAction_VoteEnd | BuiltinVoteAction_End);
	if (g_hVote == null)
	{
		CPrintToChat(client, "%t %t", "Tag", "VoteCreateFailed");
		return false;
	}

	g_iVoteType = VOTE_TYPE_EXTEND_MATCH;
	g_sVoteMap[0] = '\0';
	SetBuiltinVoteArgument(g_hVote, title);
	SetBuiltinVoteInitiator(g_hVote, client);
	SetBuiltinVoteResultCallback(g_hVote, MC_BuiltinVoteResultHandler);

	if (!DisplayBuiltinVoteToAllNonSpectators(g_hVote, FindConVar("sv_vote_timer_duration").IntValue))
	{
		delete g_hVote;
		g_hVote = null;
		g_iVoteType = VOTE_TYPE_NONE;
		CPrintToChat(client, "%t %t", "Tag", "VoteStartFailed");
		return false;
	}

	FakeClientCommand(client, "Vote Yes");
	return true;
}

void MC_BuildVoteTargetLabel(int client, int gamemode, int missionIndex, int mapIndex, const char[] mapName, char[] buffer, int maxlength)
{
	switch (gamemode)
	{
		case GAMEMODE_COOP, GAMEMODE_VERSUS:
		{
			if (L4D2MM_GetMissionLocalizedName(gamemode, missionIndex, buffer, maxlength, client) > 0)
				return;

			char missionName[LEN_MISSION_NAME];
			if (L4D2MM_GetMissionName(gamemode, missionIndex, missionName, sizeof(missionName)) > 0)
			{
				strcopy(buffer, maxlength, missionName);
				return;
			}
		}
		case GAMEMODE_SURVIVAL, GAMEMODE_SCAVENGE:
		{
			char chapterName[LEN_LOCALIZED_NAME];
			char campaignName[LEN_LOCALIZED_NAME];
			bool hasChapter	 = L4D2MM_GetMapLocalizedName(gamemode, missionIndex, mapIndex, chapterName, sizeof(chapterName), client) > 0;
			bool hasCampaign = Campaign_GetLocalizedNameFromMapCode(mapName, client, campaignName, sizeof(campaignName), g_hLocalizer);

			if (hasChapter && hasCampaign)
			{
				Format(buffer, maxlength, "%s (%s)", chapterName, campaignName);
				return;
			}

			if (hasChapter)
			{
				strcopy(buffer, maxlength, chapterName);
				return;
			}
		}
	}

	strcopy(buffer, maxlength, mapName);
}

void MC_BuiltinVoteResultHandler(Handle vote, int num_votes, int num_clients, const int[][] client_info, int num_items, const int[][] item_info)
{
	for (int i = 0; i < num_items; i++)
	{
		if (item_info[i][BUILTINVOTEINFO_ITEM_INDEX] == BUILTINVOTES_VOTE_YES
			&& item_info[i][BUILTINVOTEINFO_ITEM_VOTES] > (num_votes / 2))
		{
			switch (g_iVoteType)
			{
				case VOTE_TYPE_EXTEND_MATCH:
				{
					char extendPassText[192];
					Format(extendPassText, sizeof(extendPassText), "%T", "VotePassCompetitiveFinale", LANG_SERVER);
					DisplayBuiltinVotePass(vote, extendPassText);
					if (MC_DisableCompetitiveFinaleForCurrentCampaign(true))
						MC_Debug(MC_Debug_Announce, "extend_vote_pass current=%s mode=%d", g_sCurrentMap, g_iMode);
				}
				case VOTE_TYPE_NEXT_TARGET:
				{
					DisplayBuiltinVotePass(vote, g_sVoteMap);
					MC_ApplyVoteNextMapOverride(g_sVoteMap);
					MC_AnnounceNextTargetUpdateToAll();
				}
			}
			return;
		}
	}

	DisplayBuiltinVoteFail(vote, BuiltinVoteFail_Loses);
}

void MC_BuiltinVoteActionHandler(Handle vote, BuiltinVoteAction action, int param1, int param2)
{
	switch (action)
	{
		case BuiltinVoteAction_End:
		{
			delete vote;
			g_hVote = null;
			g_iVoteType = VOTE_TYPE_NONE;
			g_sVoteMap[0] = '\0';
		}
		case BuiltinVoteAction_Cancel:
		{
			DisplayBuiltinVoteFail(vote, view_as<BuiltinVoteFailReason>(param1));
		}
	}
}
