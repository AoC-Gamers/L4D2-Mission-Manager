#pragma semicolon 1
#pragma newdecls required

#include <campaign_manager>
#include <l4d2_mission_manager>
#include <left4dhooks>
#include <sdktools>
#include <sourcemod>

char g_sLogPath[PLATFORM_MAX_PATH];

#define LOG_FILE "logs/sm_mm.log"
#define PHRASES_FILE "l4d2_mission_manager.phrases"
#define MM_MAX_MISSION_FILE_SIZE 16384
#define MM_CUSTOM_MAPS_CONFIG "data/l4d2_mission_manager_custom_maps.txt"
#define COUNT_MM_GAMEMODE 4

ConVar g_cvDebug = null;
GlobalForward g_fwdOnL4D2MMUpdateList = null;
StringMap g_smCustomMaps = null;
StringMap g_smIgnoredInvalidMaps = null;
Localizer g_hMissionManagerLocalizer = null;

enum MMDebugCategory
{
	MM_Debug_None		 = 0,
	MM_Debug_Core		 = 1 << 0,
	MM_Debug_Parse		 = 1 << 1,
	MM_Debug_Data		 = 1 << 2,
	MM_Debug_Api		 = 1 << 3,
	MM_Debug_Command	 = 1 << 4,
	MM_Debug_Localization = 1 << 5
}

#include "mision_manager/gamemode.sp"
#include "mision_manager/utils.sp"
#include "mision_manager/data.sp"
#include "mision_manager/parser.sp"
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
	RegPluginLibrary(LIBRARY_L4D2MISSIONMANAGER);

	BuildPath(Path_SM, g_sLogPath, sizeof(g_sLogPath), LOG_FILE);
	return APLRes_Success;
}

public void OnPluginStart()
{
	LoadTranslations(PHRASES_FILE);
	g_cvDebug = CreateConVar("sm_mm_debug", "0", "Debug bitmask for l4d2_mission_manager. 0=None 1=Core 2=Parse 4=Data 8=Api 16=Command 32=Localization 63=all.", FCVAR_NOTIFY, true, 0.0, true, 63.0);
	g_hMissionManagerLocalizer = new Localizer(LC_INSTALL_MODE_FULLCACHE);
	MM_InitLists();
	MM_LoadCustomMapOverrides();
	ParseMissions();

	MM_FireEvent_OnL4D2MMUpdateList();

	RegConsoleCmd("sm_mm_list", Command_List, "Usage: sm_mm_list [<coop|versus|scavenge|survival|invalid>]");
	RegConsoleCmd("sm_mm_mission", Command_MissionInfo, "Usage: sm_mm_mission [<mission_code_or_localized_name>] [<coop|versus|scavenge|survival>]");
	RegConsoleCmd("sm_mm_map", Command_MapInfo, "Usage: sm_mm_map [<map_code>] [<coop|versus|scavenge|survival>]");
	RegConsoleCmd("sm_mm_help", Command_Help, "Display available mission manager commands.");

	MM_Debug(MM_Debug_Core, "Lifecycle: OnPluginStart");
}

bool MM_IsDebugEnabled(MMDebugCategory category)
{
	if (g_cvDebug == null)
	{
		return false;
	}

	int mask = g_cvDebug.IntValue;
	return (mask & view_as<int>(category)) != 0;
}

void MM_Debug(MMDebugCategory category, const char[] format, any ...)
{
	if (!MM_IsDebugEnabled(category))
	{
		return;
	}

	char buffer[512];
	VFormat(buffer, sizeof(buffer), format, 3);
	LogToFileEx(g_sLogPath, "tick=%d %s", GetGameTickCount(), buffer);
}

public void OnPluginEnd()
{
	MM_Debug(MM_Debug_Core, "Lifecycle: OnPluginEnd");
	MM_FreeLists();
	delete g_fwdOnL4D2MMUpdateList;
	delete g_hMissionManagerLocalizer;
	delete g_smIgnoredInvalidMaps;
	delete g_smCustomMaps;

	g_fwdOnL4D2MMUpdateList = null;
	g_hMissionManagerLocalizer = null;
	g_smIgnoredInvalidMaps = null;
	g_smCustomMaps = null;
}
