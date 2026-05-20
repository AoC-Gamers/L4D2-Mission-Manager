#pragma semicolon 1
#pragma newdecls required

#include <campaign_manager>
#include <l4d2_mission_manager>
#include <left4dhooks>
#include <sdktools>
#include <sourcemod>

char g_sLogPath[PLATFORM_MAX_PATH];

#define LOGNAME "mission_manager"
#define MM_MAX_MISSION_FILE_SIZE 16384
#define MM_CUSTOM_MAPS_CONFIG "data/l4d2_mission_manager_custom_maps.txt"
#define COUNT_MM_GAMEMODE 4

ConVar g_cvDebug = null;
GlobalForward g_fwdOnL4D2MMUpdateList = null;
StringMap g_smCustomMaps = null;
StringMap g_smIgnoredInvalidMaps = null;
Localizer g_hMissionManagerLocalizer = null;

#include "mision_manager/gamemode.sp"
#include "mision_manager/utils.sp"
#include "mision_manager/data.sp"
#include "mision_manager/parser.sp"
#include "mision_manager/localization.sp"
#include "mision_manager/commands.sp"

public Plugin myinfo =
{
	name        = "L4D2 Mission Manager",
	author      = "Rikka0w0, lechuga",
	description = "Mission manager for L4D2, provide information about map orders for other plugins",
	version     = "2.0.0",
	url         = "https://github.com/AoC-Gamers/AoC-L4D2-Competitive"

};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	EngineVersion engine = GetEngineVersion();
	if (engine != Engine_Left4Dead2)
	{
		strcopy(error, err_max, "Plugin only supports Left 4 Dead 2.");
		return APLRes_SilentFailure;
	}

	CreateNative("L4D2MM_StringToGamemode", Native_StringToGamemode);
	CreateNative("L4D2MM_GamemodeToString", Native_GamemodeToString);

	CreateNative("L4D2MM_GetNumberOfMissions", Native_GetNumberOfMissions);
	CreateNative("L4D2MM_FindMissionIndexByName", Native_FindMissionIndexByName);
	CreateNative("L4D2MM_GetMissionName", Native_GetMissionName);
	CreateNative("L4D2MM_GetMissionLocalizedName", Native_GetMissionLocalizedName);

	CreateNative("L4D2MM_GetNumberOfMaps", Native_GetNumberOfMaps);
	CreateNative("L4D2MM_FindMapIndexByName", Native_FindMapIndexByName);
	CreateNative("L4D2MM_GetMapName", Native_GetMapName);
	CreateNative("L4D2MM_GetMapLocalizedName", Native_GetMapLocalizedName);
	CreateNative("L4D2MM_GetMapUniqueID", Native_GetMapUniqueID);
	CreateNative("L4D2MM_DecodeMapUniqueID", Native_DecodeMapUniqueID);
	CreateNative("L4D2MM_GetMapUniqueIDCount", Native_GetMapUniqueIDCount);

	CreateNative("L4D2MM_GetNumberOfInvalidMissions", Native_GetNumberOfInvalidMissions);
	CreateNative("L4D2MM_GetInvalidMissionName", Native_GetInvalidMissionName);

	g_fwdOnL4D2MMUpdateList = CreateGlobalForward("OnL4D2MMUpdateList", ET_Ignore);
	RegPluginLibrary("l4d2_mission_manager");

	return APLRes_Success;
}

public void OnPluginStart()
{
	BuildPath(Path_SM, g_sLogPath, sizeof(g_sLogPath), "logs/%s.log", LOGNAME);
	g_cvDebug = CreateConVar("l4d2_mission_manager_debug", "0", "Enable debug logging for l4d2_mission_manager.", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_hMissionManagerLocalizer = new Localizer(LC_INSTALL_MODE_FULLCACHE);
	MM_InitLists();
	MM_LoadCustomMapOverrides();
	ParseMissions();
	ParseLocalization(GAMEMODE_COOP);
	ParseLocalization(GAMEMODE_VERSUS);
	ParseLocalization(GAMEMODE_SCAVENGE);
	ParseLocalization(GAMEMODE_SURVIVAL);

	MM_FireEvent_OnL4D2MMUpdateList();

	RegConsoleCmd("sm_mm_list", Command_List, "Usage: sm_mm_list [<coop|versus|scavenge|survival|invalid>]");
	RegConsoleCmd("sm_mm_mission", Command_MissionInfo, "Usage: sm_mm_mission [<mission_code_or_localized_name>] [<coop|versus|scavenge|survival>]");
	RegConsoleCmd("sm_mm_map", Command_MapInfo, "Usage: sm_mm_map [<map_code>] [<coop|versus|scavenge|survival>]");
}

void MM_DebugLog(const char[] format, any ...)
{
	if (!g_cvDebug.BoolValue)
	{
		return;
	}

	char buffer[512];
	VFormat(buffer, sizeof(buffer), format, 2);
	LogToFile(g_sLogPath, "[debug] %s", buffer);
}

public void OnPluginEnd()
{
	MM_FreeLists();
	MM_FreeLocalizedLists();
	delete g_fwdOnL4D2MMUpdateList;
	delete g_hMissionManagerLocalizer;
	delete g_smIgnoredInvalidMaps;
	delete g_smCustomMaps;

	g_fwdOnL4D2MMUpdateList = null;
	g_hMissionManagerLocalizer = null;
	g_smIgnoredInvalidMaps = null;
	g_smCustomMaps = null;
}


