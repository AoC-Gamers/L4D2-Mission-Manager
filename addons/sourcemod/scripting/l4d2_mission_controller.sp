#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <colors>
#include <adminmenu>
#include <builtinvotes>
#include <l4d2_mission_controller>
#include <l4d2_mission_manager>
#include <campaign_manager>
#include <left4dhooks>

#undef REQUIRE_PLUGIN
#include <l4d2_changelevel>
#define REQUIRE_PLUGIN

#define MENU_MODE_INSTANT				  0
#define MENU_MODE_VOTE					  1

#define ANNOUNCEMENT_NONE				  0
#define ANNOUNCEMENT_NEXT_MAP			  1
#define ANNOUNCEMENT_INVALID_MAP		  2
#define ANNOUNCEMENT_NEXT_LEVEL_NOT_FOUND 3

#define VOTE_TYPE_NONE					  0
#define VOTE_TYPE_NEXT_TARGET			  1
#define VOTE_TYPE_EXTEND_MATCH			  2

ConVar		  g_cvRoundCounterCoop		= null;
ConVar		  g_cvRoundCounterCoopFinal = null;
ConVar		  g_cvRoundCounterSurvival	= null;
ConVar		  g_cvMatchEndMap			= null;
ConVar		  g_cvEnableModes			= null;
ConVar		  g_cvDebug					= null;
ConVar		  g_cvAnnounce				= null;

char		  g_sSettingsPath[PLATFORM_MAX_PATH];
char		  g_sDebugLogPath[PLATFORM_MAX_PATH];
char		  g_sCurrentMap[LEN_MISSION_NAME];
char		  g_sConfiguredNextMap[LEN_MISSION_NAME];
char		  g_sNextMap[LEN_MISSION_NAME];
char		  g_sAnnounceMap[LEN_MISSION_NAME];
char		  g_sVoteNextMap[LEN_MISSION_NAME];
char		  g_sMatchEndOverrideCampaign[8];
char		  g_sVoteOverrideCampaign[8];

bool		  g_bHasRoundEnd				 = false;
bool		  g_bChangeMapScheduled			 = false;
bool		  g_bChangeLevelAvailable		 = false;
bool		  g_bAdminMenuAvailable			 = false;
bool		  g_bFinalMap					 = false;
bool		  g_bEffectiveFinalMap			 = false;
bool		  g_bLateload					 = false;
bool		  g_bHasVoteOverride			 = false;
bool		  g_bMatchEndMapOverrideDisabled = false;

float		  g_fVersusDelay				 = 13.0;
float		  g_fCoopFinalDelay				 = 15.0;
float		  g_fSurvivalDelay				 = 15.0;

int			  g_iRoundEndCounter			 = 0;
int			  g_iCurrentMissionIndex		 = -1;
int			  g_iCurrentMapIndex			 = -1;

TopMenu		  g_hTopMenu					 = null;
Localizer	  g_hLocalizer					 = null;
Handle		  g_hChangeMapTimer				 = null;
Handle		  g_hVote						 = null;
GlobalForward g_fwdOnNextMapChanged			 = null;
int			  g_iMode						 = GAMEMODE_UNKNOWN;
int			  g_iAnnouncementType			 = ANNOUNCEMENT_NONE;
int			  g_iVoteType					 = VOTE_TYPE_NONE;

char		  g_sVoteMap[LEN_MAP_FILENAME];

int			  g_eSelectedGamemode[MAXPLAYERS + 1];
int			  g_iSelectedMissionIndex[MAXPLAYERS + 1];
int			  g_iSelectedMenuMode[MAXPLAYERS + 1];

#include "mission_controller/core.sp"
#include "mission_controller/menus.sp"
#include "mission_controller/autochange.sp"

public Plugin myinfo =
{
	name		= "[L4D2] Mission Controller",
	author		= "lechuga",
	description = "Unified mission control: auto change, mission menu and vote flows.",
	version		= "1.0.0",
	url			= "https://github.com/AoC-Gamers/AoC-L4D2-Competitive"
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	EngineVersion engine = GetEngineVersion();
	if (engine != Engine_Left4Dead2)
	{
		strcopy(error, err_max, "Plugin only supports Left 4 Dead 2.");
		return APLRes_SilentFailure;
	}

	CreateNative("L4D2MC_HasNextMap", Native_HasNextMap);
	CreateNative("L4D2MC_GetNextMap", Native_GetNextMap);
	CreateNative("L4D2MC_GetConfiguredNextMap", Native_GetConfiguredNextMap);
	CreateNative("L4D2MC_HasVoteOverride", Native_HasVoteOverride);
	CreateNative("L4D2MC_GetVoteOverrideMap", Native_GetVoteOverrideMap);
	CreateNative("L4D2MC_SetVoteOverrideNextMap", Native_SetVoteOverrideNextMap);
	CreateNative("L4D2MC_ClearVoteOverride", Native_ClearVoteOverride);
	CreateNative("L4D2MC_DisableMatchEndMapLimit", Native_DisableMatchEndMapLimit);

	g_fwdOnNextMapChanged = new GlobalForward("L4D2MC_OnNextMapChanged", ET_Ignore, Param_String, Param_Cell);

	g_bLateload			  = late;
	return APLRes_Success;
}

public void OnAllPluginsLoaded()
{
	g_bChangeLevelAvailable = LibraryExists("l4d2_changelevel");
	g_bAdminMenuAvailable	= LibraryExists("adminmenu");
	MC_TryAttachAdminMenu();
}

public void OnLibraryAdded(const char[] library)
{
	if (StrEqual(library, "adminmenu"))
	{
		g_bAdminMenuAvailable = true;
		MC_TryAttachAdminMenu();
	}
	if (StrEqual(library, "l4d2_changelevel"))
	{
		g_bChangeLevelAvailable = true;
	}
}

public void OnLibraryRemoved(const char[] library)
{
	if (StrEqual(library, "adminmenu"))
	{
		g_hTopMenu			  = null;
		g_bAdminMenuAvailable = false;
	}
	if (StrEqual(library, "l4d2_changelevel"))
	{
		g_bChangeLevelAvailable = false;
	}
}

public void OnPluginStart()
{
	LoadTranslations("l4d2_mission_controller.phrases");
	BuildPath(Path_SM, g_sSettingsPath, sizeof(g_sSettingsPath), "data/l4d2_mission_controller.txt");

	g_hLocalizer = new Localizer(LC_INSTALL_MODE_FULLCACHE);

	HookEvent("round_start", MC_EventRoundStart);
	HookEvent("round_end", MC_EventRoundEnd);
	HookEvent("map_transition", MC_EventMapTransition);
	HookEvent("finale_win", MC_EventFinalWin);
	HookEvent("mission_lost", MC_EventMissionLost);
	HookEvent("scavenge_match_finished", MC_EventScavengeMatchFinished);

	g_cvRoundCounterCoop	  = CreateConVar("l4d2_mission_controller_crec_coop_map", "3", "Rounds before force map pass on non-final coop maps. 0=off.", FCVAR_NOTIFY, true, 0.0);
	g_cvRoundCounterCoopFinal = CreateConVar("l4d2_mission_controller_crec_coop_final", "3", "Rounds before force campaign pass on final coop maps. 0=off.", FCVAR_NOTIFY, true, 0.0);
	g_cvRoundCounterSurvival  = CreateConVar("l4d2_mission_controller_crec_survival_map", "5", "Rounds before force map pass in survival. 0=off.", FCVAR_NOTIFY, true, 0.0);
	g_cvMatchEndMap			  = CreateConVar("l4d2_mission_controller_match_end_map", "-1", "Competitive match-ending map number for coop/versus. -1=disabled, 1=first map, 4=fourth map. When reached, Mission Controller treats the current map as the effective finale.", FCVAR_NOTIFY, true, -1.0);
	g_cvEnableModes			  = CreateConVar("l4d2_mission_controller_enable_modes", "15", "Enable modes bitmask: 1=coop/realism, 2=versus, 4=survival, 8=scavenge, 15=all.", FCVAR_NOTIFY, true, 0.0, true, 15.0);
	g_cvDebug				  = CreateConVar("l4d2_mission_controller_debug", "0", "Enable debug log for l4d2_mission_controller.", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_cvAnnounce			  = CreateConVar("l4d2_mission_controller_announce", "1", "Enable mission controller announcements.", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	AutoExecConfig(true, "l4d2_mission_controller");

	RegAdminCmd("sm_mc_menu", MC_CommandMissionMenu, ADMFLAG_CHANGEMAP, "Open mission controller menu.");
	RegAdminCmd("sm_mc_endmap", MC_CommandMatchEndMapOverride, ADMFLAG_CHANGEMAP, "Manage competitive match-end override: off|on|status.");
	RegConsoleCmd("sm_mc_vote", MC_CommandMissionVote, "Open mission vote menu.");
	RegConsoleCmd("sm_mc_extend", MC_CommandMatchExtendVote, "Start a vote to remove the competitive match-end limit for this campaign.");
	RegConsoleCmd("sm_mc_next", MC_CommandNextTarget, "Display the next configured mission/map target.");

	if (g_bLateload)
	{
		g_bChangeLevelAvailable = LibraryExists("l4d2_changelevel");
		g_bAdminMenuAvailable	= LibraryExists("adminmenu");
	}

	MC_TryAttachAdminMenu();
}

public void OnPluginEnd()
{
	MC_ClearChangeMapTimer();
	MC_ClearAutoChangeState();

	for (int client = 1; client <= MaxClients; client++)
	{
		MC_ResetClientMenuState(client);
	}

	if (g_hLocalizer != null)
	{
		delete g_hLocalizer;
		g_hLocalizer = null;
	}

	if (g_fwdOnNextMapChanged != null)
	{
		delete g_fwdOnNextMapChanged;
		g_fwdOnNextMapChanged = null;
	}

	g_hTopMenu					   = null;
	g_bChangeLevelAvailable		   = false;
	g_bHasRoundEnd				   = false;
	g_iRoundEndCounter			   = 0;
	g_iMode						   = GAMEMODE_UNKNOWN;
	g_bEffectiveFinalMap		   = false;
	g_bMatchEndMapOverrideDisabled = false;
}

public void OnMapStart()
{
	MC_ClearChangeMapTimer();
	g_iRoundEndCounter = 0;
}

public void OnConfigsExecuted()
{
	g_iMode = L4D_GetGameModeType();
	MC_InitializeAutoChangeState();
}

public void OnMapEnd()
{
	MC_ClearChangeMapTimer();
}

public void OnClientPutInServer(int client)
{
	if (!MC_IsValidHumanClient(client))
		return;

	if (g_cvAnnounce != null && !g_cvAnnounce.BoolValue)
		return;

	CreateTimer(10.0, MC_TimerAnnounce, client, TIMER_FLAG_NO_MAPCHANGE);
}

public void OnClientDisconnect(int client)
{
	MC_ResetClientMenuState(client);
}

public void L4D_OnGameModeChange(int gamemode)
{
	g_iMode = L4D_GetGameModeType();
	MC_InitializeAutoChangeState();
}

public int Native_HasNextMap(Handle plugin, int numParams)
{
	return g_sNextMap[0] != '\0';
}

public int Native_GetNextMap(Handle plugin, int numParams)
{
	return SetNativeString(1, g_sNextMap, GetNativeCell(2), true);
}

public int Native_GetConfiguredNextMap(Handle plugin, int numParams)
{
	return SetNativeString(1, g_sConfiguredNextMap, GetNativeCell(2), true);
}

public int Native_HasVoteOverride(Handle plugin, int numParams)
{
	return g_bHasVoteOverride;
}

public int Native_GetVoteOverrideMap(Handle plugin, int numParams)
{
	return SetNativeString(1, g_sVoteNextMap, GetNativeCell(2), true);
}

public int Native_SetVoteOverrideNextMap(Handle plugin, int numParams)
{
	char mapName[LEN_MAP_FILENAME];
	GetNativeString(1, mapName, sizeof(mapName));

	if (!IsMapValid(mapName))
		return false;

	MC_ApplyVoteNextMapOverride(mapName);
	return true;
}

public int Native_ClearVoteOverride(Handle plugin, int numParams)
{
	MC_ClearVoteNextMapOverride();
	return 0;
}

public int Native_DisableMatchEndMapLimit(Handle plugin, int numParams)
{
	return MC_DisableMatchEndMapLimitForCurrentCampaign();
}

void MC_DebugLog(const char[] format, any...)
{
	if (g_cvDebug == null || !g_cvDebug.BoolValue)
		return;

	if (g_sDebugLogPath[0] == '\0')
		BuildPath(Path_SM, g_sDebugLogPath, sizeof(g_sDebugLogPath), "logs/l4d2_mission_controller_debug.log");

	char message[256];
	VFormat(message, sizeof(message), format, 2);
	LogToFileEx(g_sDebugLogPath, "%s", message);
}
