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

#undef REQUIRE_PLUGIN
#include <left4dhooks>
#define REQUIRE_PLUGIN

#undef REQUIRE_PLUGIN
#include <confogl>
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
#define MC_COMPETITIVE_FINALE_MAP_NUMBER  4

#define LIBRARY_L4D2CHANGELEVEL "l4d2_changelevel"
#define LIBRARY_ADMINMENU "adminmenu"
#define LIBRARY_CONFOGL "confogl"
#define LIBRARY_LEFT4DHOOKS "left4dhooks"
#define DATA_FILE "data/l4d2_mission_controller.txt"
#define DEBUG_LOG_FILE "logs/sm_mc.log"
#define PHRASES_FILE "l4d2_mission_controller.phrases"

ConVar		  g_cvRoundCounterCoop		= null;
ConVar		  g_cvRoundCounterCoopFinal = null;
ConVar		  g_cvRoundCounterSurvival	= null;
ConVar		  g_cvCompetitiveFinale		= null;
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
char		  g_sCompetitiveFinaleOverrideCampaign[8];
char		  g_sVoteOverrideCampaign[8];

bool		  g_bHasRoundEnd				 = false;
bool		  g_bChangeMapScheduled			 = false;
bool		  g_bFinalMap					 = false;
bool		  g_bEffectiveFinalMap			 = false;
bool		  g_bHasVoteOverride			 = false;
bool		  g_bCompetitiveFinaleDisabled = false;

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

enum MCDebugCategory
{
	MC_Debug_None		= 0,
	MC_Debug_Core		= 1 << 0,
	MC_Debug_Event		= 1 << 1,
	MC_Debug_State		= 1 << 2,
	MC_Debug_Policy		= 1 << 3,
	MC_Debug_Resolution = 1 << 4,
	MC_Debug_Announce	= 1 << 5,
	MC_Debug_Validate	= 1 << 6,
	MC_Debug_Action		= 1 << 7
}

enum struct ServerRuntimeState
{
	bool hasChangeLevel;
	bool hasAdminMenu;
	bool hasConfogl;
	bool hasLeft4DHooks;
	bool competitiveMatchModeLoaded;
	bool mapReady;
	bool lateload;

	/**
	 * @brief Resets runtime capability flags.
	 *
	 * @noreturn
	 */
	void Reset()
	{
		this.hasChangeLevel = false;
		this.hasAdminMenu = false;
		this.hasConfogl = false;
		this.hasLeft4DHooks = false;
		this.competitiveMatchModeLoaded = false;
		this.mapReady = false;
		this.lateload = false;
	}
}

ServerRuntimeState g_ServerRuntime;

#include "mission_controller/core.sp"
#include "mission_controller/actions.sp"
#include "mission_controller/competitive_finale.sp"
#include "mission_controller/lifecycle.sp"
#include "mission_controller/policy.sp"
#include "mission_controller/resolution.sp"
#include "mission_controller/validation.sp"
#include "mission_controller/state.sp"
#include "mission_controller/presentation.sp"
#include "mission_controller/limits.sp"
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
	CreateNative("L4D2MC_IsCompetitiveFinaleEnabled", Native_IsCompetitiveFinaleEnabled);
	CreateNative("L4D2MC_WillApplyCompetitiveFinale", Native_WillApplyCompetitiveFinale);
	CreateNative("L4D2MC_IsCurrentMapCompetitiveFinale", Native_IsCurrentMapCompetitiveFinale);
	CreateNative("L4D2MC_SetCompetitiveFinaleDisabled", Native_SetCompetitiveFinaleDisabled);

	g_fwdOnNextMapChanged = new GlobalForward("L4D2MC_OnNextMapChanged", ET_Ignore, Param_String, Param_Cell);
	g_fwdOnCompetitiveFinaleChanged = new GlobalForward("L4D2MC_OnCompetitiveFinaleChanged", ET_Ignore, Param_Cell, Param_Cell, Param_Cell, Param_Cell);
	RegPluginLibrary(LIBRARY_L4D2MISSIONCONTROLLER);

	g_ServerRuntime.Reset();
	g_ServerRuntime.lateload = late;
	return APLRes_Success;
}

public void OnAllPluginsLoaded()
{
	g_ServerRuntime.hasChangeLevel = LibraryExists(LIBRARY_L4D2CHANGELEVEL);
	g_ServerRuntime.hasAdminMenu   = LibraryExists(LIBRARY_ADMINMENU);
	g_ServerRuntime.hasConfogl     = LibraryExists(LIBRARY_CONFOGL);
	g_ServerRuntime.hasLeft4DHooks = LibraryExists(LIBRARY_LEFT4DHOOKS);
	g_ServerRuntime.competitiveMatchModeLoaded = g_ServerRuntime.hasConfogl && LGO_IsMatchModeLoaded();
	MC_TryAttachAdminMenu();
}

public void OnLibraryAdded(const char[] library)
{
	if (StrEqual(library, LIBRARY_ADMINMENU))
	{
		g_ServerRuntime.hasAdminMenu = true;
		MC_TryAttachAdminMenu();
	}
	if (StrEqual(library, LIBRARY_L4D2CHANGELEVEL))
	{
		g_ServerRuntime.hasChangeLevel = true;
	}
	if (StrEqual(library, LIBRARY_CONFOGL))
	{
		g_ServerRuntime.hasConfogl = true;
		g_ServerRuntime.competitiveMatchModeLoaded = LGO_IsMatchModeLoaded();
		if (g_ServerRuntime.mapReady)
		{
			MC_InitializeAutoChangeState();
		}
	}
	if (StrEqual(library, LIBRARY_LEFT4DHOOKS))
	{
		g_ServerRuntime.hasLeft4DHooks = true;
		if (g_ServerRuntime.mapReady)
		{
			MC_InitializeAutoChangeState();
		}
	}
}

public void OnLibraryRemoved(const char[] library)
{
	if (StrEqual(library, LIBRARY_ADMINMENU))
	{
		g_hTopMenu			  = null;
		g_ServerRuntime.hasAdminMenu = false;
	}
	if (StrEqual(library, LIBRARY_L4D2CHANGELEVEL))
	{
		g_ServerRuntime.hasChangeLevel = false;
	}
	if (StrEqual(library, LIBRARY_CONFOGL))
	{
		g_ServerRuntime.hasConfogl = false;
		g_ServerRuntime.competitiveMatchModeLoaded = false;
		if (g_ServerRuntime.mapReady)
		{
			MC_InitializeAutoChangeState();
		}
	}
	if (StrEqual(library, LIBRARY_LEFT4DHOOKS))
	{
		g_ServerRuntime.hasLeft4DHooks = false;
		if (g_ServerRuntime.mapReady)
		{
			MC_InitializeAutoChangeState();
		}
	}
}

public void OnPluginStart()
{
	LoadTranslations(PHRASES_FILE);
	BuildPath(Path_SM, g_sSettingsPath, sizeof(g_sSettingsPath), DATA_FILE);
	BuildPath(Path_SM, g_sDebugLogPath, sizeof(g_sDebugLogPath), DEBUG_LOG_FILE);

	g_hLocalizer = new Localizer(LC_INSTALL_MODE_FULLCACHE);

	HookEvent("round_start", MC_EventRoundStart);
	HookEvent("round_end", MC_EventRoundEnd);
	HookEvent("versus_round_start", MC_EventRoundStart);
	HookEvent("survival_round_start", MC_EventRoundStart);
	HookEvent("scavenge_round_start", MC_EventRoundStart);
	HookEvent("scavenge_round_halftime", MC_EventRoundEnd);
	HookEvent("scavenge_round_finished", MC_EventRoundEnd);
	HookEvent("begin_scavenge_overtime", MC_EventRoundEnd);
	HookEvent("scavenge_score_tied", MC_EventRoundEnd);
	HookEvent("map_transition", MC_EventMapTransition);
	HookEvent("finale_win", MC_EventFinalWin);
	HookEvent("mission_lost", MC_EventMissionLost);
	HookEvent("scavenge_match_finished", MC_EventScavengeMatchFinished);

	g_cvDebug				  = CreateConVar("sm_mc_debug", "0", "Debug bitmask for l4d2_mission_controller. 0=None 1=Core 2=Event 4=State 8=Policy 16=Resolution 32=Announce 64=Validate 128=Action 255=all.", FCVAR_NOTIFY, true, 0.0, true, 255.0);
	g_cvRoundCounterCoop	  = CreateConVar("sm_mc_crec_coop_map", "0", "Rounds before force map pass on non-final coop maps. 0=off.", FCVAR_NOTIFY, true, 0.0);
	g_cvRoundCounterCoopFinal = CreateConVar("sm_mc_crec_coop_final", "0", "Rounds before force campaign pass on final coop maps. 0=off.", FCVAR_NOTIFY, true, 0.0);
	g_cvRoundCounterSurvival  = CreateConVar("sm_mc_crec_survival_map", "0", "Rounds before force map pass in survival. 0=off.", FCVAR_NOTIFY, true, 0.0);
	g_cvCompetitiveFinale	  = CreateConVar("sm_mc_competitive_finale", "1", "Enable the Versus competitive finale rule. When active during a Confogl match, Mission Controller treats map 4 as the effective finale even if the mission files define a later real finale.", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_cvEnableModes			  = CreateConVar("sm_mc_enable_modes", "15", "Enable modes bitmask: 1=coop, 2=versus, 4=survival, 8=scavenge, 15=all.", FCVAR_NOTIFY, true, 0.0, true, 15.0);
	g_cvAnnounce			  = CreateConVar("sm_mc_announce", "1", "Enable mission controller announcements.", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	AutoExecConfig(true, LIBRARY_L4D2MISSIONCONTROLLER);

	RegAdminCmd("sm_mc_menu", MC_CommandMissionMenu, ADMFLAG_CHANGEMAP, "Open mission controller menu.");
	RegAdminCmd("sm_mc_finale", MC_CommandFinale, ADMFLAG_CHANGEMAP, "Manage competitive finale override: off|on|status.");
	RegConsoleCmd("sm_mc_vote", MC_CommandMissionVote, "Open mission vote menu.");
	RegConsoleCmd("sm_mc_extend", MC_CommandMatchExtendVote, "Start a vote to remove the competitive finale for this campaign.");
	RegConsoleCmd("sm_mc_next", MC_CommandNextTarget, "Display the next configured mission/map target.");
	RegConsoleCmd("sm_mc_help", MC_CommandHelp, "Display available mission controller commands.");

	if (g_ServerRuntime.lateload)
	{
		g_ServerRuntime.hasChangeLevel = LibraryExists(LIBRARY_L4D2CHANGELEVEL);
		g_ServerRuntime.hasAdminMenu   = LibraryExists(LIBRARY_ADMINMENU);
		g_ServerRuntime.hasConfogl     = LibraryExists(LIBRARY_CONFOGL);
		g_ServerRuntime.hasLeft4DHooks = LibraryExists(LIBRARY_LEFT4DHOOKS);
		g_ServerRuntime.competitiveMatchModeLoaded = g_ServerRuntime.hasConfogl && LGO_IsMatchModeLoaded();
		RequestFrame(MC_OnMapReadyFrame);
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

	if (g_fwdOnCompetitiveFinaleChanged != null)
	{
		delete g_fwdOnCompetitiveFinaleChanged;
		g_fwdOnCompetitiveFinaleChanged = null;
	}

	g_hTopMenu					    = null;
	g_ServerRuntime.hasChangeLevel = false;
	g_ServerRuntime.hasAdminMenu   = false;
	g_ServerRuntime.lateload       = false;
	g_bHasRoundEnd				    = false;
	g_iRoundEndCounter			    = 0;
	g_iMode						    = GAMEMODE_UNKNOWN;
	g_bEffectiveFinalMap			= false;
	g_bCompetitiveFinaleDisabled	= false;
	g_ServerRuntime.Reset();
}

public void LGO_OnMatchModeLoaded()
{
	g_ServerRuntime.competitiveMatchModeLoaded = true;
	MC_Debug(MC_Debug_Core, "Lifecycle: LGO_OnMatchModeLoaded");
	if (g_ServerRuntime.mapReady)
	{
		MC_InitializeAutoChangeState();
	}
}

public void LGO_OnMatchModeUnloaded()
{
	g_ServerRuntime.competitiveMatchModeLoaded = false;
	MC_Debug(MC_Debug_Core, "Lifecycle: LGO_OnMatchModeUnloaded");
	if (g_ServerRuntime.mapReady)
	{
		MC_InitializeAutoChangeState();
	}
}

public void OnMapStart()
{
	MC_ClearChangeMapTimer();
	g_iRoundEndCounter = 0;
	g_ServerRuntime.mapReady = false;
	MC_Debug(MC_Debug_Core, "Lifecycle: OnMapStart map=%s mode=%d", g_sCurrentMap, g_iMode);
	RequestFrame(MC_OnMapReadyFrame);
}

public void OnConfigsExecuted()
{
	g_iMode = L4D_GetGameModeType();
	MC_Debug(MC_Debug_Core, "Lifecycle: OnConfigsExecuted mode=%d", g_iMode);
	if (g_ServerRuntime.mapReady)
	{
		MC_InitializeAutoChangeState();
	}
}

public void OnMapEnd()
{
	MC_ClearChangeMapTimer();
	g_ServerRuntime.mapReady = false;
	MC_Debug(MC_Debug_Core, "Lifecycle: OnMapEnd map=%s mode=%d", g_sCurrentMap, g_iMode);
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
	MC_Debug(MC_Debug_Core, "Lifecycle: L4D_OnGameModeChange requested=%d resolved=%d", gamemode, g_iMode);
	if (g_ServerRuntime.mapReady)
	{
		MC_InitializeAutoChangeState();
	}
}

void MC_OnMapReadyFrame()
{
	g_ServerRuntime.mapReady = true;
	MC_Debug(MC_Debug_Core, "Lifecycle: map_ready left4dhooks=%d confogl=%d", g_ServerRuntime.hasLeft4DHooks, g_ServerRuntime.hasConfogl);
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

public int Native_IsCompetitiveFinaleEnabled(Handle plugin, int numParams)
{
	return MC_IsCompetitiveFinaleEnabled();
}

public int Native_WillApplyCompetitiveFinale(Handle plugin, int numParams)
{
	return MC_ShouldApplyCompetitiveFinale();
}

public int Native_IsCurrentMapCompetitiveFinale(Handle plugin, int numParams)
{
	return MC_IsCurrentMapCompetitiveFinale();
}

public int Native_SetCompetitiveFinaleDisabled(Handle plugin, int numParams)
{
	return MC_SetCompetitiveFinaleDisabledForCurrentCampaign(view_as<bool>(GetNativeCell(1)));
}

bool MC_IsDebugEnabled(MCDebugCategory category)
{
	if (g_cvDebug == null)
	{
		return false;
	}

	int mask = g_cvDebug.IntValue;
	return (mask & view_as<int>(category)) != 0;
}

void MC_Debug(MCDebugCategory category, const char[] format, any...)
{
	if (!MC_IsDebugEnabled(category))
	{
		return;
	}

	char message[256];
	VFormat(message, sizeof(message), format, 3);
	LogToFileEx(g_sDebugLogPath, "tick=%d %s", GetGameTickCount(), message);
}
