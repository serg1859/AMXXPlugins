/** Copyright © 2016 Vaqtincha
 *
 * CSDM include file.
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

const CSDM_VERSION_NUM = 005
stock const CSDM_VERSION_STRING[] = "0.0.5b"
stock const CSDM_PLUGIN_NAME[] = "CSDM Core"

stock const g_szMainDir[] = "csdm"
stock const g_szExtraCfgDir[] = "extraconfigs"
stock const g_szSpawnDir[] = "spawns"

stock const g_szDefaultCfgFile[] = "config.ini"
stock const g_szMainSection[] = "[settings]"

// config
const MAX_CONFIG_PATH_LEN =	128
// configdata
const MAX_LINE_LEN = 64
const MAX_KEY_LEN = 32
const MAX_VALUE_LEN = 32
const MAX_SECTION_LEN = 32


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

/** Player spawned.
*
* @param pPlayer			Player id
* @param bIsBot				Is player bot ?
* @param iNumSpawns			Total spawns
* 
* @note						alive check not necessary
*/
forward CSDM_PlayerSpawned(const pPlayer, const bool:bIsBot, const iNumSpawns)

/** Player killed.
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
* forward params: public my_config_handler(const szLineData[], const iSectionID)
*
* @param szSectionName 		Section name defined in config.
* @param szHandler 			Name of the handler function.
* @param iSectionID 		section Index. (for multiple handler support)
*
* @return  					Index of section item. 
*/
native CSDM_RegisterConfig(const szSectionName[], const szHandler[])

/** Gets config keyvalue.
*
* @param szKey				Keyname
* @param szValue			The variable to store the value in.	
* @param iLen				Lenght
*
* @return					true/false
*/
native bool:CSDM_GetConfigKeyValue(const szKey[], szValue[], iLen)

/** Is this player allowed to respawn now?
*
* @param pPlayer			0 = global value	
*
* @return					true/false
*/
native bool:CSDM_GetCanRespawn(const pPlayer = 0)

/** Is this player allowed to respawn now? (true by default)
*
* @param pPlayer			0 = all
* @param bCanRespawn		true/false
*
* @noreturn
*/
native CSDM_SetCanRespawn(const pPlayer = 0, const bool:bCanRespawn)

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

// cfg
#define ContainFlag(%1,%2) 			(containi(%1, %2) != -1)
#define ParseConfigKey(%1,%2,%3,%4) (parse(%1, %2, charsmax(%2), %3, charsmax(%3), %4, charsmax(%4)) == 3 && %3[0] == '=')
#define IsCommentLine(%1) 			(%1[0] == ';' || %1[0] == '#' || (%1[0] == '/' && %1[1] == '/'))

#define IsPlayerDead(%1)			(is_user_connected(%1) && get_entvar(%1, var_deadflag) != DEAD_NO)
#define IsValidTeam(%1) 			(TEAM_TERRORIST <= get_member(%1, m_iTeam) <= TEAM_CT)
#define IsValidWeaponID(%1) 		(any:WEAPON_P228 <= %1 <= any:WEAPON_P90 && !(INVALID_WEAPONS_BS & (1<<any:%1)))

#define ArraySet(%1,%2)				arrayset(_:%1, _:%2, sizeof(%1))
#define CSDM_LOADED()				(is_plugin_loaded(CSDM_PLUGIN_NAME) != INVALID_PLUGIN_ID)
#define Vector(%1,%2,%3)			(Float:{%1.0, %2.0, %3.0})
#define VECTOR_ZERO 				Float:{0.0, 0.0, 0.0}

#define GetEntityKeyID(%1)			get_entvar(%1, var_impulse)
#define SetEntityKeyID(%1,%2)		set_entvar(%1, var_impulse, %2)

// fakemeta
#if !defined _fakemeta_included
	#define ENTITY_THINK(%1) 		dllfunc(DLLFunc_Think, %1)
	#define SPAWN_ENTITY(%1) 		dllfunc(DLLFunc_Spawn, %1)
	#define REMOVE_ENTITY(%1) 		engfunc(EngFunc_RemoveEntity, %1)
	#define SET_ORIGIN(%1,%2) 		engfunc(EngFunc_SetOrigin, %1, %2)
	#define SET_SIZE(%1,%2,%3) 		engfunc(EngFunc_SetSize, %1, %2, %3)
	#define SET_MODEL(%1,%2)		engfunc(EngFunc_SetModel, %1, %2)
#endif

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

stock CSDM_SetFailState(const szMessage[], any:...)
{
	new szErrorMsg[191]
	vformat(szErrorMsg, charsmax(szErrorMsg), szMessage, 2)

	set_fail_state(szErrorMsg)
}

stock MakeDir(const szDirName[], bool:bPrint = true)
{
	if(!dir_exists(szDirName))
	{
		if(bPrint)
		{
			server_print("[CSDM] Directory ^"%s^" not exist, will be created automatically.", szDirName)
		}
		if(mkdir(szDirName))
		{
			server_print("[CSDM] Failed to create directory ^"%s^"", szDirName)
		}
	}
}

// Fix: rg_give_item
stock rg_give_item_ex(const index, const pszName[], any:iId, GiveType:type = GT_APPEND)
{
	const PRIMARY_BS = 
	(
		1<<CSW_SCOUT|1<<CSW_XM1014|1<<CSW_MAC10|1<<CSW_AUG|1<<CSW_UMP45|1<<CSW_SG550|1<<CSW_GALIL|1<<CSW_FAMAS|1<<CSW_AWP|
		1<<CSW_MP5NAVY|1<<CSW_M249|1<<CSW_M3|1<<CSW_M4A1|1<<CSW_TMP|1<<CSW_G3SG1|1<<CSW_SG552|1<<CSW_AK47|1<<CSW_P90
	)
	if(type != GT_APPEND)
	{
		// new iId = get_weaponid(pszName)
		if(((PRIMARY_BS & 1<<iId) || iId == CSW_ELITE) && get_member(index, m_bOwnsShield))
		{
			rg_remove_item(index, "weapon_shield")
		}
		else if(equal(pszName, "weapon_shield") && user_has_weapon(index, CSW_ELITE))
		{
			rg_remove_item(index, "weapon_elite")
		}
	}
	rg_give_item(index, pszName, type)
}

stock rg_set_rendering(const pEntity, const fx = kRenderFxNone, const Float:flColor[] = {0.0, 0.0, 0.0}, const Float:iAmount = 0.0)
{
	set_entvar(pEntity, var_renderfx, fx)
	set_entvar(pEntity, var_rendercolor, flColor)
	set_entvar(pEntity, var_renderamt, iAmount)
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
