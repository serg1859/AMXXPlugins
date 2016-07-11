// Copyright © 2016 Vaqtincha

/*******************************************************
*	Support forum:
*		http://goldsrc.ru
*
*	Credits:
*	- wopox1337 - for: pieces of advice and testing
*	- a2 - for: testing
*	- Safety1st - for: Code "Menu Obeying BuyZone sample" & "Drop Pistol Without Shield"
*	- Exolent[jNr] for: Tutorial "Dynamic Items in Menu and Plugin API"
*	- ConnorMcLeod - for: Method checking buytime
*	- xPaw - for: Code ScoreBoard "VIP" string
*	- КАПИТАН - for: testing
*
********************************************************/

//■■■■■■■■■■■■■■■■■■■■■■■ CONFIG START ■■■■■■■■■■■■■■■■■■■■■■■//

new const MAIN_MENU_CMD[] = 		"mainmenu"
new const MAIN_MENU_SAY_CMD[] = 	"say /mm"
new const WEAPON_MENU_CMD[] = 		"weaponmenu"
new const WEAPON_MENU_SAY_CMD[] = 	"say /wm"
new const BUY_MENU_CMD[] = 			"buymenu"
new const BUY_MENU_SAY_CMD[] =		"say /bm"
new const REBUY_CMD[] = 			"vrebuy"
new const REBUY_SAY_CMD[] = 		"say /rebuy"

#define CS_DEFAULT_BUY_SYSTEM		// buying time & buyzone check
// #define DONT_CLOSE_MENU			//
// #define WEAPON_STRIP				//
// #define VAULT_EXPIRE_DAYS		1	// save user settings

// #define DEBUG					// console info

//■■■■■■■■■■■■■■■■■■■■■■■■ CONFIG END ■■■■■■■■■■■■■■■■■■■■■■■■//

#define VERSION "2.0.9"
new const CONFIG_FILE[] = "/vip_environment.ini"


#include <amxmodx>
#include <fun>
#include <fakemeta>
#include <hamsandwich>
#include <vip_environment>

#define IsPlayer(%1)				(1 <= %1 <= g_iMaxPlayers)

#define SetUserSurvived(%1)			(g_bNotKilled |=  (1<<(%1 & 31)))
#define ClearUserSurvived(%1)		(g_bNotKilled &= ~(1<<(%1 & 31)))
#define IsUserSurvived(%1)			(g_bNotKilled &   (1<<(%1 & 31)))

const CONFIG_PATH_LEN = 128
const MAX_WEAPON_NAME_LEN = 20
const MAX_COMMAND_LEN = 16
const MAX_MENU_TEXT_LEN = 64

const REFILL_CLIP = 1<<0
const GIVE_AMMO = 1<<1
const TASKID_MENUCLOSE = 12138
const Menu_Buy = 4
const Menu_BuyItem = 10
const SCOREATTRIB_VIP = 1<<2
const ScoreAttrib_PlayerID = 1
const ScoreAttrib_Flags = 2


enum /* _:MENU_TYPES */
{
	MENU_OFF,
	MENU_MAIN,
	MENU_WEAPON
}

enum _:WEAPON_DATA
{
	szWeaponName[MAX_WEAPON_NAME_LEN],// weapon/item name
	szMenuName[MAX_MENU_TEXT_LEN],	// menu item name
	iWeaponID,				// weapon id
	iAmount,				// bpammo/amount
	iCounter,				// counter
	iItemTeam				// team
}

enum _:BUYMENU_DATA
{
    szItemName[MAX_MENU_TEXT_LEN], 
    szItemCmd[MAX_COMMAND_LEN], 
	iItemCost,
	iTeam,
	iPluginID,
	iFuncID
}

enum _:PLAYER_DATA
{
	iUsedCounter,
	iSpawnCounter,
	Float:flLastUsedTime,
	iInMenu,
	iInBuyMenu,
	iPreviousItem,
	iPreviousBuy,
	bool:bGiveSpawnWeapon,
	iShowMenu
}

new bool:g_bMapHasBombTarget, bool:g_bSpawnWeaponAdded, g_iRoundCounter, g_iMaxPlayers
new g_iMsgIdScoreAttrib, g_iMsgIdBlinkAcct, g_iMsgHookScoreAttrib, g_bNotKilled
new mp_buytime, mp_freezetime, Float:g_flEndOfBuyTime, g_szBuyTime[3], bool:g_bBuyTime
// player arrays
new g_ePlayerData[MAX_PLAYERS+1][PLAYER_DATA]
// dynamic arrays
new Array:g_aDataBuyMenuItems, g_iNumBuyMenuItems
new Array:g_aDataSpawnItems, g_iNumSpawnItems
new Array:g_aDataMenuItems, g_iNumMenuItems
// menus
new g_iMainMenuID, g_iMainMenuCB, g_iWeaponMenuID, g_iWeaponMenuCB
// custom forwards
new g_iFwdSpawn, g_iFwdKill, g_iFwdCfgReload, g_iFwdSetModel
// configs
new g_iReloadWeaponFlags, g_iCounterType, g_iMaxUse, g_iResetType, g_iResetTime
new bool:g_bIsAllowedMap, bool:g_bScoreBoardFlag, g_iMenuAuto, g_iMenuCloseTime
new g_iAccessWeaponMenu, g_iAccessBuyMenu, g_iAccessSpawnItems, g_iAccessOther


public plugin_precache()
{
	g_aDataSpawnItems = ArrayCreate(WEAPON_DATA)
	g_aDataMenuItems = ArrayCreate(WEAPON_DATA)
	g_aDataBuyMenuItems = ArrayCreate(BUYMENU_DATA)
	new eBuyData[BUYMENU_DATA]
	ArrayPushArray(g_aDataBuyMenuItems, eBuyData)  // empty holder so id's start at 1
	g_iNumBuyMenuItems++
}

#if defined VAULT_EXPIRE_DAYS
#include <nvault>

const MAX_AUTHID_LEN = 32
new g_iVaultData
new g_szAuthid[MAX_PLAYERS+1][MAX_AUTHID_LEN]

GetNvault()
{
	g_iVaultData = nvault_open("vip_environment_vault")
	if(g_iVaultData == INVALID_HANDLE)
	{
		set_fail_state("[V.I.P] ERROR: Opening nVault failed!")
	}else{
		nvault_prune(g_iVaultData, 0, get_systime() - (86400 * VAULT_EXPIRE_DAYS))
	}
}

public client_authorized(id)
{
	new iFlags = get_user_flags(id)
	if(iFlags & g_iAccessWeaponMenu || iFlags & g_iAccessSpawnItems)
	{
		new szKey[MAX_AUTHID_LEN+15]
		get_user_authid(id, g_szAuthid[id], MAX_AUTHID_LEN -1)

		formatex(szKey, charsmax(szKey), "%s_iShowMenu", g_szAuthid[id][10]) // strip STEAM_0:0:
		new nShowMenu = nvault_get(g_iVaultData, szKey)
		if(nShowMenu)
		{
			g_ePlayerData[id][iShowMenu] = nShowMenu == 1 ? MENU_OFF : nShowMenu == 2 ? MENU_MAIN : MENU_WEAPON
		}else{
			g_ePlayerData[id][iShowMenu] = MENU_MAIN
		}

		formatex(szKey, charsmax(szKey), "%s_bSpawnWeapon", g_szAuthid[id][10]) // strip STEAM_0:0:
		new nSpawnWeapon = nvault_get(g_iVaultData, szKey)
		if(nSpawnWeapon)
		{
			g_ePlayerData[id][bGiveSpawnWeapon] = bool:(nSpawnWeapon == 2)
		}else{
			g_ePlayerData[id][bGiveSpawnWeapon] = true
		}
	}
}
#endif

public plugin_end()
{
#if defined VAULT_EXPIRE_DAYS
	nvault_close(g_iVaultData)
#endif
	ArrayDestroy(g_aDataSpawnItems)
	ArrayDestroy(g_aDataMenuItems)
	ArrayDestroy(g_aDataBuyMenuItems)
	DestroyForward(g_iFwdSpawn)
	DestroyForward(g_iFwdCfgReload)
	DestroyForward(g_iFwdSetModel)
	DestroyForward(g_iFwdKill)
}

// ================== Custom Natives ==================
public plugin_natives()
{
	register_library("vip_environment")
	register_native("RegisterCustomItem", "__add_custom_item")
	register_native("GetUserAccess", "__get_user_access")
	register_native("GetCurrentRound", "__get_round_counter")
	register_native("GetUserSpawns", "__get_user_spawns")
	register_native("IsAllowedMap", "__check_allowed_map")
	register_native("GetCounterType", "__get_counter_type")
}

public __add_custom_item(iPlugin, iParams)
{
	new eBuyData[BUYMENU_DATA], szHandler[64]

	get_string(1, eBuyData[szItemName], charsmax(eBuyData[szItemName]))
	get_string(2, eBuyData[szItemCmd], charsmax(eBuyData[szItemCmd]))
	eBuyData[iPluginID] = iPlugin
	get_string(3, szHandler, charsmax(szHandler))
	if(!szHandler[0])
	{
		log_error(AMX_ERR_NATIVE, "[V.I.P] ERROR: Invalid callback specified for allowed!")
		return 0
	}
	eBuyData[iFuncID] = get_func_id(szHandler, iPlugin)
	if(eBuyData[iFuncID] < 0)
	{
		log_error(AMX_ERR_NOTFOUND, "[V.I.P] ERROR: Public function ^"%s^" was not found!", szHandler)
		return 0
	}
	eBuyData[iItemCost] = get_param(4)
	if(eBuyData[iItemCost] < FREE_ITEM)
	{
		log_error(AMX_ERR_NATIVE, "[V.I.P] ERROR: Wrong item price ^"%d^"", eBuyData[iItemCost])
		return 0
	}
	eBuyData[iTeam] = get_param(5)
	if(!(TEAM_TT <= eBuyData[iTeam] <= TEAM_ALL))
	{
		log_error(AMX_ERR_NATIVE, "[V.I.P] ERROR: Wrong team option ^"%d^"", eBuyData[iTeam])
		return 0
	}
	ArrayPushArray(g_aDataBuyMenuItems, eBuyData)
	g_iNumBuyMenuItems++

	return (g_iNumBuyMenuItems - 1)
}

public __get_round_counter()
{
	return g_iRoundCounter
}

public __get_counter_type()
{
	return g_iCounterType
}

public __get_user_spawns()
{
	new id = get_param(1)
	if(!IsPlayer(id))
	{
		log_error(AMX_ERR_NATIVE, "[V.I.P] ERROR: Invalid index %d", id)
		return 0
	}
	return g_ePlayerData[id][iSpawnCounter]
}

public __check_allowed_map()
{
	return bool:g_bIsAllowedMap
}

public __get_user_access()
{
	new id = get_param(1)
	if(!IsPlayer(id))
	{
		log_error(AMX_ERR_NATIVE, "[V.I.P] ERROR: Invalid index %d", id)
		return 0
	}

	if(is_user_connected(id))
	{
		new iAccess = 0, iFlags = get_user_flags(id)

		iFlags & g_iAccessSpawnItems ? (iAccess |= ACCESS_SPAWN_ITEMS) : 0
		iFlags & g_iAccessWeaponMenu ? (iAccess |= ACCESS_WEAPON_MENU) : 0
		iFlags & g_iAccessBuyMenu ? (iAccess |= ACCESS_BUY_MENU) : 0
		iFlags & g_iAccessOther ? (iAccess |= ACCESS_OTHER) : 0
	
		return iAccess
	}
	return 0
}

public plugin_init()
{
	LoadConfig()
#if defined VAULT_EXPIRE_DAYS
	GetNvault()
#endif
	register_plugin(PLUGIN_NAME, VERSION, "Vaqtincha")
	register_cvar("vip_environment_version", VERSION, FCVAR_SERVER|FCVAR_EXTDLL|FCVAR_SPONLY)
	register_concmd("vip_reloadcfg", "ConCmd_CfgReload", ADMIN_CFG, "< reload config >")

	register_clcmd(MAIN_MENU_CMD, "ClCmd_MainMenu")
	register_clcmd(WEAPON_MENU_CMD, "ClCmd_WeaponMenu")
	register_clcmd(BUY_MENU_CMD, "ClCmd_BuyMenu")
	register_clcmd(REBUY_CMD, "ClCmd_Rebuy")

	register_clcmd(MAIN_MENU_SAY_CMD, "ClCmd_MainMenu")
	register_clcmd(WEAPON_MENU_SAY_CMD, "ClCmd_WeaponMenu")
	register_clcmd(BUY_MENU_SAY_CMD, "ClCmd_BuyMenu")
	register_clcmd(REBUY_SAY_CMD, "ClCmd_Rebuy")

	register_event("HLTV", "Event_NewRound", "a", "1=0", "2=0")
	register_event("TextMsg", "Event_NewGame", "a", "2=#Game_will_restart_in", "2=#Game_Commencing")
#if defined CS_DEFAULT_BUY_SYSTEM
	register_event("StatusIcon", "Event_HideStatusIcon", "b", "1=0", "2=buyzone")
#endif
	RegisterHam(Ham_Spawn, "player", "PlayerSpawn_Pre", .Post = false)
	RegisterHam(Ham_Spawn, "player", "PlayerSpawn_Post", .Post = true)
	RegisterHam(Ham_Killed, "player", "PlayerKilled_Pre", .Post = false)
	
	g_iFwdSpawn = CreateMultiForward("UserPostSpawn", ET_IGNORE, FP_CELL)
	g_iFwdKill = CreateMultiForward("UserPreKilled", ET_CONTINUE, FP_CELL, FP_CELL, FP_CELL, FP_CELL)
	g_iFwdCfgReload = CreateMultiForward("ConfigReloaded", ET_IGNORE)
	g_iFwdSetModel = CreateMultiForward("SetWeaponWorldModel", ET_CONTINUE, FP_CELL, FP_CELL, FP_CELL, FP_CELL, FP_STRING)

	g_bMapHasBombTarget = bool:IsBombDefuseMap()
	g_iMaxPlayers = get_maxplayers()
	g_iMsgIdBlinkAcct = get_user_msgid("BlinkAcct")
	mp_buytime = get_cvar_pointer("mp_buytime")
	mp_freezetime = get_cvar_pointer("mp_freezetime")

	Event_NewRound()
}

public plugin_cfg()
{
	BuildMenu() // build menu
	if(g_iNumBuyMenuItems <= 1)
	{
		return
	}

	register_forward(FM_SetModel, "SetModel_Pre", false)

	new eBuyData[BUYMENU_DATA]
	for(new i = 1; i < g_iNumBuyMenuItems; i++) 
	{
		ArrayGetArray(g_aDataBuyMenuItems, i, eBuyData)
	#if defined DEBUG
		server_print("BUY ITEMS (ItemName: ^"%s^" | ItemAlias: ^"%s^" | Cost: ^"%d^" | Team: ^"%d^")", eBuyData[szItemName], eBuyData[szItemCmd], eBuyData[iItemCost], eBuyData[iTeam])
	#endif
		if(eBuyData[szItemCmd][0] > 0) // skip ""
		{
			register_clcmd(eBuyData[szItemCmd], "ClCmd_Alias")
		}
	}
}

LoadConfig(bool:bReloadCfg = false)
{
	new szConfigFile[CONFIG_PATH_LEN], szMsg[CONFIG_PATH_LEN+60], szMapName[32]
	get_localinfo("amxx_configsdir", szConfigFile, charsmax(szConfigFile))
	add(szConfigFile, charsmax(szConfigFile), CONFIG_FILE)

	get_mapname(szMapName, charsmax(szMapName))

	if(!file_exists(szConfigFile))
	{
		formatex(szMsg, charsmax(szMsg), "[V.I.P] ERROR: Config file ^"%s^" not found!", szConfigFile)
		set_fail_state(szMsg)
		return 0
	}
	new iFilePointer = fopen(szConfigFile, "rt")
	if(!iFilePointer)
	{
		set_fail_state("[V.I.P] ERROR: Failed reading file!")
		return 0
	}
	if(bReloadCfg) // reset
	{
		new id
		for(id = 1; id < g_iMaxPlayers; id++)
		{
			g_ePlayerData[id][iPreviousItem] = 0 // error fix
		}

		ArrayClear(g_aDataSpawnItems)
		ArrayClear(g_aDataMenuItems)
		g_iNumSpawnItems = 0
		g_iNumMenuItems = 0
		g_iReloadWeaponFlags = 0
		g_bSpawnWeaponAdded = false
		menu_destroy(g_iWeaponMenuID)
	}

	new szDatas[64], szKey[32], szSign[2], szValue[5], eItemData[WEAPON_DATA], iSection, i
	new szClassName[MAX_WEAPON_NAME_LEN], szMenuText[MAX_MENU_TEXT_LEN], szAmount[4], szCounter[4]
	new Trie:tCheckWeaponName = TrieCreate()

	for(i = 0; i< sizeof(g_szWeaponName); i++)
	{
		TrieSetCell(tCheckWeaponName, g_szWeaponName[i], i)
	}
	TrieSetCell(tCheckWeaponName, "item_kevlar", i)
	TrieSetCell(tCheckWeaponName, "item_assaultsuit", i)
	TrieSetCell(tCheckWeaponName, "item_thighpack", i)

	ArrayPushArray(g_aDataMenuItems, eItemData) // empty holder so id's start at 1
	g_iNumMenuItems++

	while(!feof(iFilePointer))
	{
		fgets(iFilePointer, szDatas, charsmax(szDatas))
		trim(szDatas)
		if(!szDatas[0] || szDatas[0] == ';' || szDatas[0] == '#')
		{
			continue
		}
		if(szDatas[0] == '[')
		{
			if(equali(szDatas, "[settings]")){
				iSection = 1
			}else if(equali(szDatas, "[weaponmenu]")){
				iSection = 2
			}else if(equali(szDatas, "[spawnitems]")){
				iSection = 3
			}else if(equali(szDatas, "[maps]")){
				iSection = 4
			}else iSection = 0

			continue
		}

		switch(iSection)
		{
			case 1:{
				parse(szDatas, szKey, charsmax(szKey), szSign, charsmax(szSign), szValue, charsmax(szValue))

				if(szSign[0] == '=')
				{
					if(equali(szKey, "spawn_item_access_flags")){
						g_iAccessSpawnItems = read_flags(szValue)
					}else if(equali(szKey, "weapon_menu_access_flags")){
						g_iAccessWeaponMenu = read_flags(szValue)
					}else if(equali(szKey, "buy_menu_access_flags")){
						g_iAccessBuyMenu = read_flags(szValue)
					}else if(equali(szKey, "other_access_flags")){
						g_iAccessOther = read_flags(szValue)
					}else if(equali(szKey, "scoreboard_flag")){
						g_bScoreBoardFlag = bool:(szValue[0] == '1')
					}else if(equali(szKey, "reload_weapon_flags")){
						if(containi(szValue, "a") != INVALID_HANDLE)
						{
							g_iReloadWeaponFlags |= REFILL_CLIP
						}
						if(containi(szValue, "b") != INVALID_HANDLE)
						{
							g_iReloadWeaponFlags |= GIVE_AMMO
						}
					}else if(equali(szKey, "counter_type")){
						g_iCounterType = str_to_num(szValue)
					}else if(equali(szKey, "intelligent_menu")){
						g_iMenuAuto = str_to_num(szValue)
					}else if(equali(szKey, "close_delay")){
						g_iMenuCloseTime = str_to_num(szValue)
					}else if(equali(szKey, "option_max_use")){
						g_iMaxUse = str_to_num(szValue)
					}else if(equali(szKey, "reset_type")){
						g_iResetType = str_to_num(szValue)					
					}else if(equali(szKey, "reset_time")){
						g_iResetTime = str_to_num(szValue)
					}
				}
			}
			case 2:{
				parse(szDatas, szClassName, charsmax(szClassName), szMenuText, charsmax(szMenuText), szAmount, charsmax(szAmount), szCounter, charsmax(szCounter))
				strtolower(szClassName) // AbC > to > abs
				if(!szClassName[0] || !TrieGetCell(tCheckWeaponName, szClassName, i))
				{
					server_print("[V.I.P] WARNING: Invalid weapon name ^"%s^" will be skipped!", szClassName)
					continue
				}

				copy(eItemData[szWeaponName], charsmax(eItemData[szWeaponName]), szClassName)
				eItemData[iWeaponID] = get_weaponid(szClassName)
				eItemData[iAmount] = str_to_num(szAmount)
				eItemData[iCounter] = str_to_num(szCounter)
				copy(eItemData[szMenuName], charsmax(eItemData[szMenuName]), szMenuText) // weapon_
			#if defined DEBUG
				server_print("MENU ITEMS (WeaponName: ^"%s^" | WeaponID: ^"%d^" | Amount: ^"%d^" | Counter: ^"%d^" | MenuName: ^"%s^")", eItemData[szWeaponName], eItemData[iWeaponID], eItemData[iAmount], eItemData[iCounter], eItemData[szMenuName])
			#endif
				ArrayPushArray(g_aDataMenuItems, eItemData)
				g_iNumMenuItems++
			}
			case 3:{
				parse(szDatas, szClassName, charsmax(szClassName), szValue, charsmax(szValue), szAmount, charsmax(szAmount), szCounter, charsmax(szCounter))
				strtolower(szDatas) // AbC > to > abs
				if(!szClassName[0] || !TrieGetCell(tCheckWeaponName, szClassName, i))
				{
					server_print("[V.I.P] WARNING: Invalid weapon/item name ^"%s^" will be skipped!", szClassName)
					continue
				}

				copy(eItemData[szWeaponName], charsmax(eItemData[szWeaponName]), szClassName)
				eItemData[iWeaponID] = get_weaponid(szClassName)
				eItemData[iAmount] = str_to_num(szAmount)
				eItemData[iCounter] = str_to_num(szCounter)
				eItemData[iItemTeam] = szValue[0] == 't' ? TEAM_TT : szValue[0] == 'c' ? TEAM_CT : szValue[0] == 'a' ? TEAM_ALL : 0 
			#if defined DEBUG
				server_print("SPAWN ITEMS (WeaponName: ^"%s^" | WeaponID: ^"%d^" | Amount: ^"%d^" | Counter: ^"%d^" | Team: ^"%d^")", eItemData[szWeaponName], eItemData[iWeaponID], eItemData[iAmount], eItemData[iCounter], eItemData[iItemTeam])
			#endif
				if(!g_bSpawnWeaponAdded)
				{
					g_bSpawnWeaponAdded = bool:(1<<eItemData[iWeaponID] & SECONDARY_WEAPONS_BIT_SUM || 1<<eItemData[iWeaponID] & PRIMARY_WEAPONS_BIT_SUM)
				}
				ArrayPushArray(g_aDataSpawnItems, eItemData)
				g_iNumSpawnItems++
			}
			case 4:{
				if(!g_bIsAllowedMap && containi(szMapName, szDatas) != INVALID_HANDLE){
					g_bIsAllowedMap = true
				}else if(g_bIsAllowedMap && szDatas[0] == '@' && equali(szMapName, szDatas[1])){
					g_bIsAllowedMap = false
				}
			}
		}
	}
	fclose(iFilePointer)
	TrieDestroy(tCheckWeaponName)

	CheckRegisterMessage()
	CheckConfigValues()

	return 1
}

BuildMenu()
{
	g_iMainMenuID = menu_create("Main Menu", "MainMenuHandler") // static menu
	g_iMainMenuCB = menu_makecallback("MainMenuCallback")
	// menu_setprop(g_iMainMenuID, MPROP_NUMBER_COLOR, "\y")

	if(g_iNumBuyMenuItems > 1)
	{
		menu_additem(g_iMainMenuID, "Weapon Menu", "1", g_iAccessWeaponMenu, g_iMainMenuCB)
		menu_additem(g_iMainMenuID, "Buy Menu^n", "2", g_iAccessBuyMenu, g_iMainMenuCB)
		menu_additem(g_iMainMenuID, "Previous Item: [NONE]", "3", g_iAccessWeaponMenu, g_iMainMenuCB)
		menu_additem(g_iMainMenuID, "Previous Buy: [NONE]^n^n", "4", g_iAccessBuyMenu, g_iMainMenuCB)
	}else{
		menu_additem(g_iMainMenuID, "Weapon Menu^n", "1", g_iAccessWeaponMenu, g_iMainMenuCB)
		menu_additem(g_iMainMenuID, "Previous Item: [NONE]^n^n", "3", g_iAccessWeaponMenu, g_iMainMenuCB)
	}
	
	if(g_iMenuAuto > 0)
	{
		menu_additem(g_iMainMenuID, "Show Menu: [DISABLED]", "5", g_iAccessWeaponMenu, g_iMainMenuCB)
	}
	if(g_bSpawnWeaponAdded)
	{
		menu_additem(g_iMainMenuID, "Spawn Weapons: [DISABLED]", "6", g_iAccessSpawnItems, g_iMainMenuCB)
	}
	new szMenuText[MAX_MENU_TEXT_LEN]
	switch(g_iCounterType)
	{
		case COUNTER_ROUND: formatex(szMenuText, charsmax(szMenuText), "Weapons Menu\RRound^t")
		case COUNTER_SPAWN: formatex(szMenuText, charsmax(szMenuText), "Weapons Menu\RSpawn^t")
		case COUNTER_FRAG: formatex(szMenuText, charsmax(szMenuText), "Weapons Menu\RFrag^t")
		default: formatex(szMenuText, charsmax(szMenuText), "\yWeapons Menu\RCounter^t")
	}
	g_iWeaponMenuID = menu_create(szMenuText, "WeaponMenuHandler") // static menu
	// menu_setprop(g_iWeaponMenuID, MPROP_NUMBER_COLOR, "\y")
  	g_iWeaponMenuCB = menu_makecallback("WeaponMenuCallback")
	if(g_iNumMenuItems <= 1)
	{
		return
	}
	new eMenuData[WEAPON_DATA], szNum[3], i
	for(i = 1; i < g_iNumMenuItems; i++)
	{
		ArrayGetArray(g_aDataMenuItems, i, eMenuData)
		formatex(szMenuText, charsmax(szMenuText), "%s\R\y%d%s", eMenuData[szMenuName], eMenuData[iCounter], g_iNumMenuItems > 8 ? "^t^t^t^t" : "^t")
		num_to_str(i, szNum, charsmax(szNum))
		menu_additem(g_iWeaponMenuID, szMenuText, szNum, 0, g_iWeaponMenuCB)
	}
}


public client_putinserver(id)
{
	ResetAll(id)
}

public client_disconnect(id)
{
	ResetAll(id)
}

// ================== Events & Messages ==================
public Event_HideStatusIcon(id) 
{
	CloseMenu(id, g_ePlayerData[id][iInBuyMenu])
}

public Event_MenuAutoClose(taskid)
{
	new id = taskid - TASKID_MENUCLOSE
	CloseMenu(id, g_ePlayerData[id][iInMenu])
}

public Event_NewGame()
{
	new id
	for(id = 1; id < g_iMaxPlayers; id++)
	{
		g_ePlayerData[id][iUsedCounter] = 0
		g_ePlayerData[id][flLastUsedTime] = 0
		g_ePlayerData[id][iSpawnCounter] = 0
	}
	g_iRoundCounter = 0
}

public Event_NewRound()
{
	if(g_iResetType == RESET_ROUND)
	{
		new id
		for(id = 1; id < g_iMaxPlayers; id++)
		{
			g_ePlayerData[id][iUsedCounter] = 0
		}
	}

	g_bBuyTime = true
	new Float:flBuyTime = floatmax(get_pcvar_float(mp_buytime), 0.0) * 60
	g_flEndOfBuyTime = get_gametime() + flBuyTime + get_pcvar_float(mp_freezetime)
	num_to_str(floatround(flBuyTime), g_szBuyTime, charsmax(g_szBuyTime))

	g_iRoundCounter++
}

public SetModel_Pre(iEnt, const szModel[])
{
	if(/* pev_valid(iEnt) || */ (strlen(szModel) > MAX_WEAPON_NAME_LEN && (szModel[17] == 'x')))
	{
		return FMRES_IGNORED
	}
	new szClassName[MAX_WEAPON_NAME_LEN]
	pev(iEnt, pev_classname, szClassName, charsmax(szClassName))

	if(szClassName[8] != 'x') // checks for weaponbox
	{
		return FMRES_IGNORED
	}

	new wEnt, iSlot, iRet, iImpulse, iOwner = pev(iEnt, pev_owner)
	for(iSlot = 1; iSlot<= 2; iSlot++) // only primary & secondary
	{
		wEnt = get_pdata_cbase(iEnt, m_rgpPlayerItems_CWeaponBox[iSlot], XO_WEAPON)
		if(wEnt > 0 && IsPlayer(iOwner))
		{
			iImpulse = pev(wEnt, pev_impulse)
		#if defined DEBUG
			server_print("EntityID: ^"%d^" | WeaponEntityID: ^"%d^" | WeaponImpulse: ^"%d^" | OwnerID: ^"%d^" | Model: ^"%s^"", iEnt, wEnt, iImpulse, iOwner, szModel)
		#endif
			ExecuteForward(g_iFwdSetModel, iRet, iEnt, wEnt, iImpulse, iOwner, szModel)
			return iRet
		}
	}
	return FMRES_IGNORED
}

public Message_ScoreAttrib(MsgId, MsgType, MsgEnt)
{
	if(get_msg_arg_int(ScoreAttrib_Flags) || ~get_user_flags(get_msg_arg_int(ScoreAttrib_PlayerID)) & g_iAccessOther)
	{
		return
	}
	
	set_msg_arg_int(ScoreAttrib_Flags, ARG_BYTE, SCOREATTRIB_VIP)
}

public PlayerKilled_Pre(id, killer)
{
	if(g_iResetType == RESET_DEATH)
	{
		g_ePlayerData[id][iUsedCounter] = 0
	}

	new iRet
	ExecuteForward(g_iFwdKill, iRet, id, IsPlayer(killer) ? killer : 0, get_user_last_hitgroup(id), cs_get_user_team(id) == cs_get_user_team(killer))

	return iRet
}

public PlayerSpawn_Pre(id)
{
	if(/* pev_valid(id) == PDATA_SAFE && */ TEAM_TT <= cs_get_user_team(id) <= TEAM_CT)
	{
		get_pdata_int(id, m_fHasSurvivedLastRound) ? SetUserSurvived(id) : ClearUserSurvived(id)
	}
}

public PlayerSpawn_Post(id)
{
	set_task(0.1, "Spawned", id) // delay
}

public Spawned(id)
{
	if(!is_user_alive(id))
	{
		return
	}

	new iRet
	ExecuteForward(g_iFwdSpawn, iRet, id)

	g_ePlayerData[id][iSpawnCounter]++
	if(g_iResetType == RESET_SPAWN)
	{
		g_ePlayerData[id][iUsedCounter] = 0
	}

	new iFlags = get_user_flags(id)
	if(iFlags & g_iAccessOther && g_iReloadWeaponFlags > 0)
	{
		WeaponsReload(id)
	}

	if(!g_bIsAllowedMap || !CheckConfigValues())
	{
		return
	}
	if(iFlags & g_iAccessWeaponMenu)
	{
		OpenWeaponMenu(id)
	}
	if(~iFlags & g_iAccessSpawnItems || !g_iNumSpawnItems)
	{
		return
	}

	new eItemData[WEAPON_DATA], i, iUserTeam = cs_get_user_team(id)

	for(i = 0; i < g_iNumSpawnItems; i++) 
	{
		ArrayGetArray(g_aDataSpawnItems, i, eItemData)
		// except item_thighpack (defuser) non target maps
		if(!g_bMapHasBombTarget && (eItemData[szWeaponName][0] == 'i' && eItemData[szWeaponName][5] == 't'))
		{
			continue
		}
		if(!eItemData[iItemTeam] || (iUserTeam != eItemData[iItemTeam] && eItemData[iItemTeam] != TEAM_ALL))
		{
			continue
		}
		if(!g_ePlayerData[id][bGiveSpawnWeapon] && (1<<eItemData[iWeaponID] & SECONDARY_WEAPONS_BIT_SUM || 1<<eItemData[iWeaponID] & PRIMARY_WEAPONS_BIT_SUM))
		{
			continue
		}
		if(GetItemAllowed(id, eItemData[iCounter]))
		{
			GiveItem(id, eItemData, .bNotify = false)
		}
	}
}

OpenWeaponMenu(id)
{
	if(!g_iMenuAuto || !g_ePlayerData[id][iShowMenu] || (g_iMenuAuto == 1 && IsUserSurvived(id)) || (g_iMenuAuto == 2 && cs_get_user_hasprim(id)))
	{
		return
	}
	new eItemData[WEAPON_DATA], i
	for(i = 1; i < g_iNumMenuItems; i++) 
	{
		ArrayGetArray(g_aDataMenuItems, i, eItemData)
		if(GetItemAllowed(id, eItemData[iCounter]))
		{
			switch(g_ePlayerData[id][iShowMenu]) // always open
			{
				case MENU_OFF: return
				case MENU_MAIN: menu_display(id, g_iMainMenuID, 0)
				case MENU_WEAPON: ShowWeaponMenu(id, .iPage = 0, .bNotify = false)
				// default: return
			}
		}
		break
	}
}
// ================== Commands ==================
public ConCmd_CfgReload(id, level)
{
	if(~get_user_flags(id) & level)
	{
		return PLUGIN_HANDLED
	}
	show_menu(0, 0, "^n", 1)
	if(LoadConfig(.bReloadCfg = true))
	{
		BuildMenu() // rebuild menu

		if(id)
		{
			client_print(id, print_console, "[V.I.P] Configuration reloaded successfully")
		}else{
			server_print("[V.I.P] Configuration reloaded successfully")
		}

		new iRet
		ExecuteForward(g_iFwdCfgReload, iRet)
	}
	return PLUGIN_HANDLED
}

public ClCmd_Alias(id)
{
	if(!g_bIsAllowedMap || !is_user_alive(id) || ~get_user_flags(id) & g_iAccessBuyMenu)
	{
		return PLUGIN_HANDLED
	}
#if defined CS_DEFAULT_BUY_SYSTEM
	if(!cs_get_user_buyzone(id))
	{
		client_print(id, print_center, "You are outside the buyzone!")
		return PLUGIN_HANDLED
	}
#endif
	new eBuyData[BUYMENU_DATA], szCommand[MAX_COMMAND_LEN]
	read_argv(0, szCommand, charsmax(szCommand))

	for(new i = 1; i < g_iNumBuyMenuItems; i++)
	{
		ArrayGetArray(g_aDataBuyMenuItems, i, eBuyData)
		if(equali(eBuyData[szItemCmd], szCommand))
		{
			if(cs_get_user_team(id) != eBuyData[iTeam] && eBuyData[iTeam] != TEAM_ALL)
			{
				client_print_center(id, "#Alias_Not_Avail", eBuyData[szItemName])
				return PLUGIN_HANDLED
			}
			if(BuyItem(id, eBuyData))
			{
				g_ePlayerData[id][iPreviousBuy] = i
			}
			break
		}
	}
	return PLUGIN_HANDLED
}

public ClCmd_Rebuy(id)
{
	if(!g_bIsAllowedMap || !g_ePlayerData[id][iPreviousBuy] || !is_user_alive(id) || ~get_user_flags(id) & g_iAccessBuyMenu)
	{
		return PLUGIN_HANDLED
	}

	PreviousBuy(id)

	return PLUGIN_HANDLED
}

public ClCmd_MainMenu(id)
{
	if(!g_bIsAllowedMap || !is_user_alive(id))
	{
		return PLUGIN_HANDLED
	}

	new iFlags = get_user_flags(id)
	if(iFlags & g_iAccessWeaponMenu || iFlags & g_iAccessBuyMenu)
	{
		// menu fix
#if AMXX_VERSION_NUM < 183
		cs_set_user_menu(id, 0)
#endif
		menu_display(id, g_iMainMenuID, 0)
		g_ePlayerData[id][iInMenu] = g_iMainMenuID

		if(g_iMenuCloseTime > 0)
		{
			remove_task(TASKID_MENUCLOSE + id)
			set_task(float(g_iMenuCloseTime), "Event_MenuAutoClose", TASKID_MENUCLOSE + id)
		}
	}
	return PLUGIN_HANDLED
}

public ClCmd_BuyMenu(id)
{
	if(!g_bIsAllowedMap || !is_user_alive(id) || ~get_user_flags(id) & g_iAccessBuyMenu)
	{
		return PLUGIN_HANDLED
	}
	ShowBuyMenu(id, .iPage = 0)

	return PLUGIN_HANDLED
}

public ClCmd_WeaponMenu(id)
{
	if(!g_bIsAllowedMap || !is_user_alive(id) || ~get_user_flags(id) & g_iAccessWeaponMenu)
	{
		return PLUGIN_HANDLED
	}
	ShowWeaponMenu(id, .iPage = 0)

	return PLUGIN_HANDLED
}

// ================== Menus ==================
ShowBuyMenu(id, iPage)
{
	if(g_iNumBuyMenuItems <= 1)
	{
		return
	}
#if defined CS_DEFAULT_BUY_SYSTEM
	if(!cs_get_user_buyzone(id))
	{
		client_print(id, print_center, "You are outside the buyzone!")
		return
	}
#endif
	iPage = clamp(iPage, 0, (g_iNumBuyMenuItems - 1) / 7)

	new iBuyMenuID = menu_create("Buy Menu\R$^t^tCost", "BuyMenuHandler") // dynamic menu
	// menu_setprop(iBuyMenuID, MPROP_NUMBER_COLOR, "\y")
	new eBuyData[BUYMENU_DATA], szItem[MAX_MENU_TEXT_LEN], szNum[3]
	new iMoney = cs_get_user_money(id), iUserTeam = cs_get_user_team(id)

	for(new i = 1; i < g_iNumBuyMenuItems; i++) 
	{
		ArrayGetArray(g_aDataBuyMenuItems, i, eBuyData)

		if(iUserTeam != eBuyData[iTeam] && eBuyData[iTeam] != TEAM_ALL)
		{
			continue
		}
		if(eBuyData[iItemCost] == FREE_ITEM)
		{
			formatex(szItem, charsmax(szItem), "%s\R\yFREE%s", eBuyData[szItemName], g_iNumBuyMenuItems > 8 ? "^t^t^t^t" : "")
		}else{
			if((iMoney - eBuyData[iItemCost]) < 0)
			{
				formatex(szItem, charsmax(szItem), "\d%s\R\r%d%s", eBuyData[szItemName], eBuyData[iItemCost], g_iNumBuyMenuItems > 8 ? "^t^t^t^t" : "")
			}else{
				formatex(szItem, charsmax(szItem), "%s\R\y%d%s", eBuyData[szItemName], eBuyData[iItemCost], g_iNumBuyMenuItems > 8 ? "^t^t^t^t" : "")
			}
		}
		num_to_str(i, szNum, charsmax(szNum))
		menu_additem(iBuyMenuID, szItem, szNum)
    }
	// menu fix
#if AMXX_VERSION_NUM < 183
	cs_set_user_menu(id, 0)
#endif
	menu_display(id, iBuyMenuID, iPage)
	g_ePlayerData[id][iInBuyMenu] = iBuyMenuID
}

ShowWeaponMenu(id, iPage, bool:bNotify = true)
{
	if(!CheckConfigValues())
	{
		return
	}
	if(!g_iMaxUse || g_iNumMenuItems <= 1)
	{
		if(bNotify)
		{
			client_print(id, print_center, "Menu disabled!")
		}
		return
	}
	if(g_ePlayerData[id][iUsedCounter] >= g_iMaxUse && !CheckResetType(id, bNotify))
	{
		return
	}
	iPage = clamp(iPage, 0, (g_iNumMenuItems - 1) / 7)
	// menu fix
#if AMXX_VERSION_NUM < 183
	cs_set_user_menu(id, 0)
#endif
	menu_display(id, g_iWeaponMenuID, iPage)
	g_ePlayerData[id][iInMenu] = g_iWeaponMenuID

	if(g_iMenuCloseTime > 0)
	{
		remove_task(TASKID_MENUCLOSE + id)
		set_task(float(g_iMenuCloseTime), "Event_MenuAutoClose", TASKID_MENUCLOSE + id)
	}
}

public MainMenuHandler(id, iMenu, iItem)
{
	g_ePlayerData[id][iInMenu] = -1
	if(g_iMenuCloseTime > 0)
	{
		remove_task(TASKID_MENUCLOSE + id)
	}
	if(iItem == MENU_EXIT || iItem < 0) 
	{
		return PLUGIN_HANDLED
	}
	new szNum[3], iAccess, hCallback
	menu_item_getinfo(iMenu, iItem, iAccess, szNum, charsmax(szNum), _, _, hCallback)

	switch(str_to_num(szNum))
	{
		case 1: ShowWeaponMenu(id, .iPage = 0)
		case 2: ShowBuyMenu(id, .iPage = 0)
		case 3: PreviousItem(id)
		case 4: PreviousBuy(id)
		case 5:{
			g_ePlayerData[id][iShowMenu] = g_ePlayerData[id][iShowMenu] == MENU_OFF ? MENU_MAIN : g_ePlayerData[id][iShowMenu] == MENU_MAIN ? MENU_WEAPON : MENU_OFF
		#if defined VAULT_EXPIRE_DAYS
			new szKey[MAX_AUTHID_LEN+15]
			formatex(szKey, charsmax(szKey), "%s_iShowMenu", g_szAuthid[id][10]) // strip STEAM_0:0:
			nvault_set(g_iVaultData, szKey, !g_ePlayerData[id][iShowMenu] ? "1" : g_ePlayerData[id][iShowMenu] == MENU_MAIN ? "2" : "3") // +1
		#endif
			menu_display(id, g_iMainMenuID, 0)
		}
		case 6:{
			g_ePlayerData[id][bGiveSpawnWeapon] = g_ePlayerData[id][bGiveSpawnWeapon] ? false : true
		#if defined VAULT_EXPIRE_DAYS
			new szKey[MAX_AUTHID_LEN+15]
			formatex(szKey, charsmax(szKey), "%s_bSpawnWeapon", g_szAuthid[id][10]) // strip STEAM_0:0:
			nvault_set(g_iVaultData, szKey, g_ePlayerData[id][bGiveSpawnWeapon] ? "2" : "1") // "1" == false, "2" == true
		#endif
			menu_display(id, g_iMainMenuID, 0)
		}
	}
	return PLUGIN_HANDLED
}

public MainMenuCallback(id, iMenu, iItem)
{
	if(iItem < 0)
	{
		return PLUGIN_HANDLED
	}

	new szNum[3], szMenuText[MAX_MENU_TEXT_LEN], iAccess, hCallback, iFlags = get_user_flags(id)
	menu_item_getinfo(iMenu, iItem, iAccess, szNum, charsmax(szNum), szMenuText, charsmax(szMenuText), hCallback)
	new eMenuData[WEAPON_DATA], eBuyData[BUYMENU_DATA]

	switch(szNum[0])
	{
		case '1':{
			if(!g_iMaxUse || g_iNumMenuItems <= 1 || ~iFlags & g_iAccessWeaponMenu)
			{
				return ITEM_DISABLED
			}
		}
		case '2':{
			if(~iFlags & g_iAccessBuyMenu)
			{
				return ITEM_DISABLED
			}
		}
		case '3':{
			if(!g_ePlayerData[id][iPreviousItem] || ~iFlags & g_iAccessWeaponMenu)
			{
				formatex(szMenuText, charsmax(szMenuText), (g_iNumBuyMenuItems > 1) ? "Previous Item: [NONE]" : "Previous Item: [NONE]^n^n")
				menu_item_setname(iMenu, iItem, szMenuText)
				return ITEM_DISABLED
			}

			ArrayGetArray(g_aDataMenuItems, g_ePlayerData[id][iPreviousItem], eMenuData)
			formatex(szMenuText, charsmax(szMenuText), (g_iNumBuyMenuItems > 1) ? "Previous Item: \y[\w%s\y]" : "Previous Item: \y[\w%s\y]^n^n", eMenuData[szMenuName])
			menu_item_setname(iMenu, iItem, szMenuText)
		}
		case '4':{
			if(!g_ePlayerData[id][iPreviousBuy] || ~iFlags & g_iAccessBuyMenu)
			{
				formatex(szMenuText, charsmax(szMenuText), "Previous Buy: [NONE]^n^n")
				menu_item_setname(iMenu, iItem, szMenuText)
				return ITEM_DISABLED
			}

			ArrayGetArray(g_aDataBuyMenuItems, g_ePlayerData[id][iPreviousBuy], eBuyData)
			formatex(szMenuText, charsmax(szMenuText), "Previous Buy: \y[\w%s\y]\R$^t%d^n^n", eBuyData[szItemName], eBuyData[iItemCost])
			menu_item_setname(iMenu, iItem, szMenuText)	
		}
		case '5':{
			if(~iFlags & g_iAccessWeaponMenu)
			{
				return ITEM_DISABLED
			}
			formatex(szMenuText, charsmax(szMenuText), "Show Menu: \y[%s\y]", !g_ePlayerData[id][iShowMenu] ? "\rDONT SHOW" : g_ePlayerData[id][iShowMenu] == MENU_MAIN ? "\wMAIN MENU" : "\wWEAPON MENU")
			menu_item_setname(iMenu, iItem, szMenuText)
		}
		case '6':{
			if(~iFlags & g_iAccessSpawnItems)
			{
				return ITEM_DISABLED
			}
			formatex(szMenuText, charsmax(szMenuText), "Spawn Weapons: \y[%s\y]", !g_ePlayerData[id][bGiveSpawnWeapon] ? "\rOFF" : "\wON")
			menu_item_setname(iMenu, iItem, szMenuText)
		}
	}

	return ITEM_IGNORE
}

public BuyMenuHandler(id, iMenu, iItem)
{
	g_ePlayerData[id][iInBuyMenu] = -1
	if(iItem == MENU_EXIT || iItem < 0) 
	{
		return menu_destroy(iMenu)
	}

	new szNum[3], iAccess, hCallback
	menu_item_getinfo(iMenu, iItem, iAccess, szNum, charsmax(szNum), _, _, hCallback)

	new iItemIndex = str_to_num(szNum)
	new eBuyData[BUYMENU_DATA]
	ArrayGetArray(g_aDataBuyMenuItems, iItemIndex, eBuyData)
	if(BuyItem(id, eBuyData))
	{
		g_ePlayerData[id][iPreviousBuy] = iItemIndex
	}
#if defined DONT_CLOSE_MENU
	ShowBuyMenu(id, .iPage = (iItem / 7))
#endif
	return menu_destroy(iMenu)
}

public WeaponMenuHandler(id, iMenu, iItem)
{
	g_ePlayerData[id][iInMenu] = -1
	if(g_iMenuCloseTime > 0)
	{
		remove_task(TASKID_MENUCLOSE + id)
	}
	if(iItem == MENU_EXIT || iItem < 0)
	{
		return PLUGIN_HANDLED
	}
	new szNum[3], iAccess, hCallback
	menu_item_getinfo(iMenu, iItem, iAccess, szNum, charsmax(szNum), _, _, hCallback)

	new iItemIndex = str_to_num(szNum)
	new eMenuData[WEAPON_DATA]
	ArrayGetArray(g_aDataMenuItems, iItemIndex, eMenuData)

	if(GiveItem(id, eMenuData))
	{
		g_ePlayerData[id][iPreviousItem] = iItemIndex
		g_ePlayerData[id][iUsedCounter]++
		if(g_iResetType == RESET_TIME && g_iResetTime > 0)
		{
			g_ePlayerData[id][flLastUsedTime] = _:get_gametime()
		}
	}
#if defined DONT_CLOSE_MENU
	ShowWeaponMenu(id, .iPage = (iItem / 7), .bNotify = false)
#endif
	return PLUGIN_HANDLED
}

public WeaponMenuCallback(id, iMenu, iItem)
{
	if(iItem < 0)
	{
		return PLUGIN_HANDLED
	}
	new szNum[3], iAccess, hCallback
	menu_item_getinfo(iMenu, iItem, iAccess, szNum, charsmax(szNum), _, _, hCallback)

	new eMenuData[WEAPON_DATA]
	ArrayGetArray(g_aDataMenuItems, str_to_num(szNum), eMenuData)

	if(!GetItemAllowed(id, eMenuData[iCounter]))
	{
		return ITEM_DISABLED
	}
	return ITEM_IGNORE
}

//================= Functions ================
WeaponsReload(id)
{
	new iSlot, wEnt, iId
	for(iSlot = 1; iSlot<= 2; iSlot++)
	{
		wEnt = get_pdata_cbase(id, m_rgpPlayerItems_CBasePlayer[iSlot])
		while(wEnt > 0)
		{
			iId = cs_get_weapon_id(wEnt)
			if(g_iReloadWeaponFlags & REFILL_CLIP && IsUserSurvived(id))
			{
				cs_set_weapon_ammo(wEnt, g_iMaxClip[iId])
			}
			if(g_iReloadWeaponFlags & GIVE_AMMO)
			{
				ExecuteHamB(Ham_GiveAmmo, id, g_iMaxBPAmmo[iId], g_szAmmoType[iId], g_iMaxBPAmmo[iId])
			}
			wEnt = get_pdata_cbase(wEnt, m_pNext, XO_WEAPON)
		}
	}
}

PreviousBuy(id)
{
#if defined CS_DEFAULT_BUY_SYSTEM
	if(!cs_get_user_buyzone(id))
	{
		client_print(id, print_center, "You are outside the buyzone!")
		return
	}
#endif
	new eBuyData[BUYMENU_DATA]
	ArrayGetArray(g_aDataBuyMenuItems, g_ePlayerData[id][iPreviousBuy], eBuyData)
	if(cs_get_user_team(id) != eBuyData[iTeam] && eBuyData[iTeam] != TEAM_ALL)
	{
		client_print_center(id, "#Alias_Not_Avail", eBuyData[szItemName])
		g_ePlayerData[id][iPreviousBuy] = 0
		return
	}
	BuyItem(id, eBuyData)
}

PreviousItem(id)
{
	if(g_ePlayerData[id][iUsedCounter] >= g_iMaxUse && !CheckResetType(id, .bNotify = true))
	{
		return
	}

	new eMenuData[WEAPON_DATA]
	ArrayGetArray(g_aDataMenuItems, g_ePlayerData[id][iPreviousItem], eMenuData)
	if(GiveItem(id, eMenuData))
	{
		g_ePlayerData[id][iUsedCounter]++
		if(g_iResetType == RESET_TIME && g_iResetTime > 0)
		{
			g_ePlayerData[id][flLastUsedTime] = _:get_gametime()
		}
	}
}

ResetAll(id)
{
	g_ePlayerData[id][iUsedCounter] = 0
	g_ePlayerData[id][flLastUsedTime] = 0
	g_ePlayerData[id][iSpawnCounter] = 0
	g_ePlayerData[id][iInMenu] = -1
	g_ePlayerData[id][iInBuyMenu] = -1
	g_ePlayerData[id][iPreviousItem] = 0
	g_ePlayerData[id][iPreviousBuy] = 0
#if !defined VAULT_EXPIRE_DAYS
	g_ePlayerData[id][iShowMenu] = MENU_MAIN
	g_ePlayerData[id][bGiveSpawnWeapon] = true
#endif
	if(g_iMenuCloseTime > 0)
	{
		remove_task(TASKID_MENUCLOSE + id)
	}
	ClearUserSurvived(id)
}

CloseMenu(id, iMenu)
{
	if(is_user_connected(id) && !(Menu_Buy <= cs_get_user_menu(id) <= Menu_BuyItem))
	{
		new iOldMenu, iNewMenu
		player_menu_info(id, iOldMenu, iNewMenu) 
		if(iNewMenu != -1 && iNewMenu == iMenu) 
		{
			menu_cancel(id)
			show_menu(id, 0, "^n", 1)
		}
	}
}

CheckRegisterMessage()
{
	if(!g_iMsgIdScoreAttrib)
	{
		g_iMsgIdScoreAttrib = get_user_msgid("ScoreAttrib")
	}
	if(g_bScoreBoardFlag && !g_iMsgHookScoreAttrib)
	{
		g_iMsgHookScoreAttrib = register_message(g_iMsgIdScoreAttrib, "Message_ScoreAttrib")
	}else{
		unregister_message(g_iMsgIdScoreAttrib, g_iMsgHookScoreAttrib)
		g_iMsgHookScoreAttrib = 0
	}
}

GiveItem(id, Data[WEAPON_DATA], bool:bNotify = true)
{
	new iId = Data[iWeaponID]
	if(1<<iId & EXCP_WEAPONS_BIT_SUM || ~pev(id, pev_weapons) & 1<<iId)
	{
		DoDropWeapon(id, iId)
		give_item(id, Data[szWeaponName])
		if(Data[iAmount] > 0)
		{
			if(Data[szWeaponName][0] == 'w') // weapon_
			{
				ExecuteHamB(Ham_GiveAmmo, id, Data[iAmount], g_szAmmoType[iId], Data[iAmount])
			}
			// set armor value ( item_kevlar, item_assaultsuit )
			if(Data[szWeaponName][0] == 'i' && (Data[szWeaponName][5] == 'a' || Data[szWeaponName][5] == 'k'))
			{
				set_user_armor(id, Data[iAmount])
			}
		}
		return 1
	}
	if(bNotify)
	{
		client_print(id, print_center, "#Cstrike_Already_Own_Weapon")
	}
	return 0
}

BuyItem(id, eBuyData[BUYMENU_DATA])
{
#if defined CS_DEFAULT_BUY_SYSTEM
	if(!CheckBuytime(id))
	{
		return 0
	}
#endif
	new iMoney = cs_get_user_money(id) - eBuyData[iItemCost]
	if(iMoney < 0)
	{
		client_print(id, print_center, "You need $%d more to buy this item!", (iMoney * -1))
		message_begin(MSG_ONE_UNRELIABLE, g_iMsgIdBlinkAcct, .player = id)
		write_byte(2/*BlinkAmt*/)
		message_end()
		return 0
	}
	callfunc_begin_i(eBuyData[iFuncID], eBuyData[iPluginID])
	callfunc_push_int(id)
	if(callfunc_end() == BUY_SUCCESS)
	{
		cs_set_user_money(id, iMoney)
		return 1
	}
	return 0
}

// ==================== Stocks ====================
stock bool:GetItemAllowed(id, iItemCounter)
{
	switch(g_iCounterType)
	{
		case COUNTER_ROUND: return (g_iRoundCounter < iItemCounter) ? false : true
		case COUNTER_SPAWN: return (g_ePlayerData[id][iSpawnCounter] < iItemCounter) ? false : true
		case COUNTER_FRAG: return (get_user_frags(id) < iItemCounter) ? false : true
		default: return false
	}
	return false
}

stock bool:CheckConfigValues()
{
	if(!(COUNTER_ROUND <= g_iCounterType <= COUNTER_FRAG))
	{
		server_print("[V.I.P] WARNING: Invalid ^"counter_type^" value ^"%d^"", g_iCounterType)
		return false
	}
	if(!(RESET_RESTART <= g_iResetType <= RESET_TIME))
	{
		server_print("[V.I.P] WARNING: Invalid ^"reset_type^" value ^"%d^"", g_iResetType)
		return false
	}
	return true
}

stock bool:CheckResetType(id, bool:bNotify = false)
{
	new bool:bReturn
	switch(g_iResetType)
	{
		case RESET_RESTART:{
			if(bNotify)
			{
				client_print(id, print_center, "You can take %d time(s) per game", g_iMaxUse)
			}
			bReturn = false
		}
		case RESET_ROUND:{
			if(bNotify)
			{
				client_print(id, print_center, "You can take %d time(s) per round", g_iMaxUse)
			}
			bReturn = false
		}
		case RESET_DEATH:{
			if(bNotify)
			{
				client_print(id, print_center, "You can take %d time(s) per life", g_iMaxUse)
			}
			bReturn = false
		}
		case RESET_SPAWN:{
			if(bNotify)
			{
				client_print(id, print_center, "You can take %d time(s) per spawn", g_iMaxUse)
			}
			bReturn = false
		}
		case RESET_TIME:{
			new Float:flCurTime = get_gametime()
			new Float:flTime = (g_ePlayerData[id][flLastUsedTime] + g_iResetTime)
			if(flTime >= flCurTime)
			{
				new iSeconds = floatround(flTime - flCurTime)
				if(bNotify && iSeconds > 0)
				{
					client_print(id, print_center, "Is available after %d second(s)", iSeconds)
				}
				bReturn = false
			}
			if(flTime < flCurTime)
			{
				g_ePlayerData[id][iUsedCounter] = 0
				bReturn = true
			}
		}
	}
	return bReturn
}

stock bool:CheckBuytime(id)
{
	if(!g_bBuyTime || !(g_bBuyTime = get_gametime() < g_flEndOfBuyTime))
	{
		client_print_center(id, "#Cant_buy", g_szBuyTime)
		return false
	}
	return true
}


