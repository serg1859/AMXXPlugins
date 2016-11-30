/** Copyright © 2016 Vaqtincha
 *
 * CSDM include file.
 *
 * Support forum:
 *		http://goldsrc.ru
 *
*/


#if defined _csdm_core_included
	#endinput
#endif

#define _csdm_core_included

#if AMXX_VERSION_NUM >= 175
	#pragma reqlib csdm_core
	#if !defined AMXMODX_NOAUTOLOAD
		#pragma loadlib csdm_core
	#endif
#else
	#pragma library csdm_core
#endif


#if !defined _reapi_included
	#include <reapi>
#endif

const CSDM_VERSION_NUM = 002
stock const CSDM_VERSION_STRING[] = "0.0.2b"
stock const CSDM_PLUGIN_NAME[] = "CSDM Core"

stock const g_szMainDir[] = "csdm"
stock const g_szExtraCfgDir[] = "extraconfigs"
stock const g_szSpawnDir[] = "spawns"

stock const g_szDefaultCfgFile[] = "config.ini"

const MAX_CONFIG_PATH_LEN =	128


enum ReadTypes
{
	CFG_READ,
	CFG_RELOAD
}

enum GameTypes
{
	NORMAL_HIT,
	HEADSHOTS_ONLY,
	ALWAYS_HIT_HEAD,
	AUTO_HEALER
}

enum EquipTypes
{
	AUTO_EQUIP,
	EQUIP_MENU,
	RANDOM_WEAPONS,
	FREE_BUY
}

enum ColorTypes
{
	DONT_CHANGE = 0,
	RED,
	BLUE,
	GREY	
}


//■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■ FORWARDS ■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■

/** Called when CSDM initializes.
*
* @param szVersion			It passes in a version string, or a blank string if some load failure occurred.
*/
forward CSDM_Initialized(const szVersion[])

/** Called when CSDM is ready to accept config hooks.
*
* @param iReadAction		See enum ReadTypes
*/
forward CSDM_ConfigurationLoad(const ReadTypes:iReadAction)

/** Called when CSDM is execute CVar values.
*/
forward CSDM_ExecuteCVarValues()

/** Called right before gamemode change.
*
* @param iCurrentMode		Current gameplay mode
* @param iNewMode			Changed to
*
* @note						return PLUGIN_HANDLED will block change
*/
forward CSDM_GamemodeChanged(const GameTypes:iCurrentMode, const GameTypes:iNewMode)

/** Called right before round is restarted.
*
* @param bNewGame			Is round restart
*/
forward CSDM_RestartRound(const bool:bNewGame)

/** 
* Player spawned.
*
* @param pPlayer			Player id
* @param bIsBot				Is player bot ?
* @param iNumSpawns			Total spawns
* 
* @note						alive check not necessary
*/
forward CSDM_PlayerSpawned(const pPlayer, const bool:bIsBot, const iNumSpawns)

/** 
* Player killed.
*
* @param pVictim			Victim id
* @param pKiller			Killer id
* @param iLastHitGroup		Last hitgroup
* 
* @note						pKiller == 0 if player was killed by world
* @note						return PLUGIN_HANDLED will block CSDM from doing any physical respawning
*/
forward CSDM_PlayerKilled(const pVictim, const pKiller, const HitBoxGroup:iLastHitGroup)


//■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■ NATIVES ■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■

/** Read config section.
*
* forward params: public my_config_handler(szLineData[], const iSectionID)
*
* @param szSectionName 		Section name defined in config.
* @param szHandler 			Name of the handler function.
* @param iSectionID 		section Index. (for multiple handler support)
*
* @return  					Index of section item. 
*/
native CSDM_RegisterConfig(const szSectionName[], const szHandler[])

/** Respawn player.
*
* @param flDelay			Delayed respawn
*
* @return					Failed/Seccess
*/
native bool:CSDM_RespawnPlayer(const pPlayer, const Float:flDelay = 0.0)

/** Gets gameplay mode.
*
* @return 					enum GameTypes
*/
native GameTypes:CSDM_GetGamemode()

/** Sets gameplay mode.
*
* @param iNewMode			See enum GameTypes
*
* @return 					Failed/Seccess
*/
native bool:CSDM_SetGamemode(const GameTypes:iNewMode)



//■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■ HELPER STUFF ■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■

#define IsPlayerDead(%1)			(is_user_connected(%1) && get_entvar(%1, var_deadflag) != DEAD_NO)
#define IsValidTeam(%1) 			(TEAM_TERRORIST <= get_member(%1, m_iTeam) <= TEAM_CT)
#define IsValidWeaponID(%1) 		(any:WEAPON_P228 <= %1 <= any:WEAPON_P90 && !(INVALID_WEAPONS_BS & (1<<any:%1)))
#define ContainFlag(%1,%2) 			(containi(%1,%2) != -1)
#define ArraySet(%1,%2)				arrayset(_:%1, _:%2, sizeof(%1))
#define ParseConfigKey(%1,%2,%3,%4) (parse(%1, %2, charsmax(%2), %3, charsmax(%3), %4, charsmax(%4)) == 3 && %3[0] == '=')
#define CSDM_LOADED()				(is_plugin_loaded(CSDM_PLUGIN_NAME) != INVALID_PLUGIN_ID)
#define Vector(%1,%2,%3)			(Float:{%1.0, %2.0, %3.0})
#define VECTOR_ZERO 				Float:{0.0, 0.0, 0.0}
#define GetEntityKeyID(%1)			get_entvar(%1, var_impulse)
#define SetEntityKeyID(%1,%2)		set_entvar(%1, var_impulse, %2)

const GRENADE_BS = ((1<<_:WEAPON_HEGRENADE)|(1<<_:WEAPON_SMOKEGRENADE)|(1<<_:WEAPON_FLASHBANG))
const INVALID_WEAPONS_BS = ((1<<_:WEAPON_NONE)|(1<<_:WEAPON_GLOCK)|(1<<_:WEAPON_KNIFE)|(1<<_:WEAPON_C4))

const INVALID_INDEX = -1
const FORCE_VIEW_ANGLES = 1
const COLOR_CLIENT_INDEX = 34

stock const g_szTeamNames[ColorTypes][] =
{
	"UNASSIGNED",
	"TERRORIST",
	"CT",
	"SPECTATOR"
}

stock const g_szGamemodes[GameTypes][] = 
{
	"Normal Hit",
	"Headshots Only",
	"Always Hit Head",
	"Auto Healer"
}

stock const g_szEquipModes[EquipTypes][] = 
{
	"Auto Equip",
	"Equip Menu",
	"Random Weapons",
	"Free buy"
}

stock const g_iMaxBPAmmo[any:WEAPON_P90 + 1] = 
{
	-1, 52, -1, 90, 1, 32, 1, 100, 90, 1, 120, 100, 100, 90, 90, 90, 
	100, 120, 30, 120, 200, 32, 90, 120, 90, 2, 35, 90, 90, -1, 100
}

stock CSDM_SetFailState(const szMessage[], any:...)
{
	new szErrorMsg[191]
	vformat(szErrorMsg, charsmax(szErrorMsg), szMessage, 2)

	set_fail_state(szErrorMsg)
}

stock CSDM_PrintChat(const pPlayer, const ColorTypes:color, const fmt[], any:...)
{
	if(!is_user_connected(pPlayer))
		return

	new szMessage[191]
	if(numargs() == 3)
	{
		copy(szMessage, charsmax(szMessage), fmt)
	}
	else
	{
		vformat(szMessage, charsmax(szMessage), fmt, 4)
	}

	if(get_member(pPlayer, m_iTeam) != color && color != DONT_CHANGE)
	{
		SendTeamInfo(pPlayer, g_szTeamNames[color])
		SendSayText(pPlayer, szMessage, true)
	}
	else
	{
		SendSayText(pPlayer, szMessage)
	}
}

stock SendTeamInfo(const pPlayer, const szTeam[])
{
	static iMsgIdTeamInfo
	if(iMsgIdTeamInfo || (iMsgIdTeamInfo = get_user_msgid("TeamInfo")))
	{
		message_begin(MSG_ONE, iMsgIdTeamInfo, .player = pPlayer)
		write_byte(COLOR_CLIENT_INDEX)
		write_string(szTeam)
		message_end()
	}
}

stock SendSayText(const pPlayer, szMessage[], const bool:bColored = false)
{
	static iMsgIdSayText
	if(iMsgIdSayText || (iMsgIdSayText = get_user_msgid("SayText")))
	{
		message_begin(MSG_ONE, iMsgIdSayText, .player = pPlayer)
		write_byte(bColored ? COLOR_CLIENT_INDEX : pPlayer)
		if(szMessage[0] > 4)
		{
			write_byte(1)
			szMessage[192 - 2 - 1] = 0	// Two write_byte + string terminator
			write_string(szMessage)
		}
		else
		{
			szMessage[192 - 1 - 1] = 0	// One write_byte + string terminator
			write_string(szMessage)
		}
		message_end()
	}
}
