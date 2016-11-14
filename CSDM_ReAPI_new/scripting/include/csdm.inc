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

stock const g_szDirectory[] = "csdm"
stock const CSDM_VERSION[] = "0.0.1b"
const CSDM_VERSION_NUM = 1

const INVALID_INDEX = -1
const MAX_CONFIG_PATH_LEN =	128

enum ReadTypes
{
	CFG_READ = 0,
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

//■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■ FORWARDS ■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■


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
* @param CurrentMode		Current gameplay mode
* @param NewMode			Changed to
*
* @note						return PLUGIN_HANDLED will block change
*/
forward CSDM_GamemodeChanged(const GameTypes:CurrentMode, const GameTypes:NewMode)

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
* @param Mode				See enum GameTypes
*
* @return 					Failed/Seccess
*/
native bool:CSDM_SetGamemode(const GameTypes:Mode)



//■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■ HELPER STUFF ■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■

#define IsPlayerDead(%1)			(is_user_connected(%1) && get_entvar(%1, var_deadflag) != DEAD_NO)
#define IsValidTeam(%1) 			(TEAM_TERRORIST <= get_member(%1, m_iTeam) <= TEAM_CT)
#define ContainFlag(%1,%2) 			(containi(%1,%2) != -1)
#define ArraySet(%1,%2)				arrayset(_:%1, _:%2, sizeof(%1))
#define ParseConfigKey(%1,%2,%3,%4) (parse(%1, %2, charsmax(%2), %3, charsmax(%3), %4, charsmax(%4)) == 3 && %3[0] == '=')
#define CSDM_LOADED()				(is_plugin_loaded("CSDM Core") != INVALID_PLUGIN_ID)

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

stock CSDM_GetGamemodeName(const GameTypes:Mode, szName[], iLen)
{
	formatex(szName, iLen, "%s", (NORMAL_HIT <= Mode <= AUTO_HEALER) ? g_szGamemodes[Mode] : "UNKNOWN")
}

stock CSDM_SetFailState(const szMessage[], any:...)
{
	new szErrorMsg[191]
	vformat(szErrorMsg, charsmax(szErrorMsg), szMessage, 2)

	set_fail_state(szErrorMsg)
}

stock CSDM_PrintChat(const pPlayer, const szMessage[], any:...)
{
	if(!is_user_connected(pPlayer))
		return

	static szMsg[191], iMsgIdSayText
	vformat(szMsg, charsmax(szMsg), szMessage, 3)

	if(iMsgIdSayText || (iMsgIdSayText = get_user_msgid("SayText")))
	{
		message_begin(MSG_ONE, iMsgIdSayText, .player = pPlayer)
		write_byte(pPlayer)
		write_string(szMsg)
		message_end()
	}
}




