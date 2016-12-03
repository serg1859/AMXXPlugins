// Copyright © 2016 Vaqtincha

#include <amxmodx>
#include <fakemeta>
#include <csdm>


#define IsPlayer(%1)				(1 <= %1 <= g_iMaxPlayers)
#define PlayerTask(%1)				(%1 + RESPAWN_TASK_ID)
#define GetPlayerByTaskID(%1)		(%1 - RESPAWN_TASK_ID)

const Float:MIN_RESPAWN_TIME = 0.5
const Float:MAX_RESPAWN_TIME = 15.0

const RESPAWN_TASK_ID = 364815

enum config_s
{
	iSectionID,
	iPluginID,
	iPluginFuncID
}

enum forwardlist_e
{
	iFwdRestartRound,
	iFwdPlayerSpawned,
	iFwdPlayerKilled,
	iFwdConfigLoad,
	iFwdInitialized,
	iFwdExecuteCVarVal,
	iFwdGamemodeChanged
}

new HookChain:g_hFPlayerCanRespawn, HookChain:g_hTraceAttack
new Array:g_aConfigData, Trie:g_tConfigSections, Trie:g_tConfigValues
new g_eCustomForwards[forwardlist_e]
new g_iIgnoreReturn, g_iMaxPlayers, g_iFwdEmitSound, g_iTotalItems

new Float:g_flRespawnDelay = MIN_RESPAWN_TIME, GameTypes:g_iGamemode
new bool:g_bShowRespawnBar, bool:g_bFreeForAll, bool:g_bBlockGunpickupSound
new bool:g_bIsBot[MAX_CLIENTS + 1], bool:g_bFirstSpawn[MAX_CLIENTS + 1], g_iNumSpawns[MAX_CLIENTS + 1]
new bool:g_bFPlayerCanRespawn[MAX_CLIENTS + 1], bool:g_bAllowRespawn = true

public plugin_precache()
{
	g_aConfigData = ArrayCreate(config_s)
	g_tConfigSections = TrieCreate()
	g_tConfigValues = TrieCreate()

	g_eCustomForwards[iFwdRestartRound] = CreateMultiForward("CSDM_RestartRound", ET_IGNORE, FP_CELL)
	g_eCustomForwards[iFwdPlayerSpawned] = CreateMultiForward("CSDM_PlayerSpawned", ET_IGNORE, FP_CELL, FP_CELL, FP_CELL)
	g_eCustomForwards[iFwdPlayerKilled] = CreateMultiForward("CSDM_PlayerKilled", ET_CONTINUE, FP_CELL, FP_CELL, FP_CELL)
	g_eCustomForwards[iFwdConfigLoad] = CreateMultiForward("CSDM_ConfigurationLoad", ET_IGNORE, FP_CELL)
	g_eCustomForwards[iFwdExecuteCVarVal] = CreateMultiForward("CSDM_ExecuteCVarValues", ET_IGNORE)
	g_eCustomForwards[iFwdInitialized] = CreateMultiForward("CSDM_Initialized", ET_IGNORE, FP_STRING)
	g_eCustomForwards[iFwdGamemodeChanged] = CreateMultiForward("CSDM_GamemodeChanged", ET_STOP, FP_CELL, FP_CELL)

	LoadSettings()
}


public plugin_natives()
{
	register_library("csdm_core")
	register_native("CSDM_RegisterConfig", "native_register_config")
	register_native("CSDM_GetConfigKeyValue", "native_get_config_keyvalue")
	register_native("CSDM_GetCanRespawn", "native_get_can_respawn")
	register_native("CSDM_SetCanRespawn", "native_set_can_respawn")
	register_native("CSDM_RespawnPlayer", "native_respawn_player")
	register_native("CSDM_GetGamemode", "native_get_gamemode")
	register_native("CSDM_SetGamemode", "native_set_gamemode")
}

public plugin_end()
{
	if(g_tConfigSections)
		TrieDestroy(g_tConfigSections)
	if(g_tConfigValues)
		TrieDestroy(g_tConfigValues)
}

public plugin_init()
{
	register_plugin(CSDM_PLUGIN_NAME, CSDM_VERSION_STRING, "Vaqtincha")

	RegisterHookChain(RG_CSGameRules_RestartRound, "CSGameRules_RestartRound", .post = false)
	RegisterHookChain(RG_CSGameRules_DeadPlayerWeapons, "CSGameRules_DeadPlayerWeapons", .post = false)
	RegisterHookChain(RG_CBasePlayer_Killed, "CSGameRules_PlayerKilled", .post = false)
	RegisterHookChain(RG_CBasePlayer_Spawn, "CBasePlayer_Spawn", .post = true)
	RegisterHookChain(RG_HandleMenu_ChooseAppearance, "HandleMenu_ChooseAppearance", .post = true)
	RegisterHookChain(RG_CBasePlayer_RoundRespawn, "CBasePlayer_RoundRespawn", .post = false)
	RegisterHookChain(RG_RoundEnd, "RoundEnd", .post = false)
	DisableHookChain(g_hTraceAttack = RegisterHookChain(RG_CBasePlayer_TraceAttack, "CBasePlayer_TraceAttack", .post = false))
	DisableHookChain(g_hFPlayerCanRespawn = RegisterHookChain(RG_CSGameRules_FPlayerCanRespawn, "CSGameRules_FPlayerCanRespawn", .post = false))

	set_msg_block(get_user_msgid("HudTextArgs"), BLOCK_SET)
	set_msg_block(get_user_msgid("ClCorpse"), BLOCK_SET)

	g_iMaxPlayers = get_maxplayers()
	ExecuteForward(g_eCustomForwards[iFwdInitialized], g_iIgnoreReturn, CSDM_VERSION_STRING)
}

public plugin_cfg()
{
	CheckForwards()
}

public GameTypes:native_get_gamemode(iPlugin, iParams)
{
	return g_iGamemode
}

public bool:native_set_gamemode(iPlugin, iParams)
{
	if(!CheckNativeParams(iParams, 1, 1))
		return false

	new GameTypes:iNewGamemode = GameTypes:clamp(get_param(1), _:NORMAL_HIT, _:AUTO_HEALER)
	if(g_iGamemode == iNewGamemode)
	{
		server_print("[CSDM] Already set ^"%s^" mode!", g_szGamemodes[iNewGamemode])
		return false
	}

	new iRet
	ExecuteForward(g_eCustomForwards[iFwdGamemodeChanged], g_iIgnoreReturn, g_iGamemode, iNewGamemode)

	if(iRet == PLUGIN_HANDLED)
	{
		server_print("[CSDM] Not allowed to change ^"%s^" mode!", g_szGamemodes[iNewGamemode])
		return false
	}

	server_print("[CSDM] Gamemode ^"%s^" changed to ^"%s^"", g_szGamemodes[g_iGamemode], g_szGamemodes[iNewGamemode])
	g_iGamemode = iNewGamemode
	CheckForwards()

	return true
}

public bool:native_get_config_keyvalue(iPlugin, iParams)
{
	if(!CheckNativeParams(iParams, 1, 3))
		return false

	new szKey[MAX_KEY_LEN], szValue[MAX_VALUE_LEN]
	get_string(1, szKey, charsmax(szKey))
	if(!szKey[0])
	{
		log_error(AMX_ERR_NATIVE, "[CSDM] ERROR: Invalid key name!")
		return false
	}

	strtolower(szKey)
	if(!TrieGetString(g_tConfigValues, szKey, szValue, charsmax(szValue)))
	{
		server_print("[CSDM] ERROR: Key name ^"%s^" was not found!", szKey)
		return false
	}

	set_string(2, szValue, get_param(3)/* iLen */)
	return true
}

public native_register_config(iPlugin, iParams)
{
	if(!CheckNativeParams(iParams, 1, 2))
		return INVALID_INDEX

	new eArrayData[config_s], szHandler[64], szSection[MAX_SECTION_LEN]

	get_string(1, szSection, charsmax(szSection))
	if(!szSection[0])
	{
		log_error(AMX_ERR_NATIVE, "[CSDM] ERROR: Invalid section name!")
		return INVALID_INDEX
	}

	strtolower(szSection)
	format(szSection, charsmax(szSection), "[%s]", szSection)

	get_string(2, szHandler, charsmax(szHandler))
	if(!szHandler[0])
	{
		log_error(AMX_ERR_NATIVE, "[CSDM] ERROR: Invalid callback specified for allowed!")
		return INVALID_INDEX
	}

	eArrayData[iPluginID] = iPlugin
	eArrayData[iPluginFuncID] = get_func_id(szHandler, iPlugin)
	if(eArrayData[iPluginFuncID] < 0)
	{
		log_error(AMX_ERR_NOTFOUND, "[CSDM] ERROR: Function ^"%s^" was not found!", szHandler)
		return INVALID_INDEX
	}

	new iItemIndex = eArrayData[iSectionID] = g_iTotalItems++
	ArrayPushArray(g_aConfigData, eArrayData)
	TrieSetCell(g_tConfigSections, szSection, iItemIndex)

	return iItemIndex
}

public bool:native_get_can_respawn(iPlugin, iParams)
{
	if(!CheckNativeParams(iParams, 1, 1))
		return false

	new pPlayer = get_param(1)
	return IsPlayer(pPlayer) ? g_bFPlayerCanRespawn[pPlayer] : g_bAllowRespawn
}

public native_set_can_respawn(iPlugin, iParams)
{
	if(!CheckNativeParams(iParams, 1, 2))
		return

	new pPlayer = get_param(1)
	new bool:bCanRespawn = bool:get_param(2)
	if(IsPlayer(pPlayer))
	{
		g_bFPlayerCanRespawn[pPlayer] = bCanRespawn
	}
	else
	{
		ArraySet(g_bFPlayerCanRespawn, bCanRespawn)
		g_bAllowRespawn = bCanRespawn
	}
}

public bool:native_respawn_player(iPlugin, iParams)
{
	if(!CheckNativeParams(iParams, 1, 2))
		return false

	new pPlayer = get_param(1)
	if(!IsPlayer(pPlayer))
	{
		log_error(AMX_ERR_NATIVE, "Invalid client index %d", pPlayer)
		return false
	}

	TaskRespawnStart(pPlayer, floatclamp(get_param_f(2), 0.0, MAX_RESPAWN_TIME))
	return true
}


public client_putinserver(pPlayer)
{
	remove_task(PlayerTask(pPlayer))
	g_bIsBot[pPlayer] = bool:is_user_bot(pPlayer)
	g_iNumSpawns[pPlayer] = 0

	g_bFirstSpawn[pPlayer] = true
	g_bFPlayerCanRespawn[pPlayer] = g_bAllowRespawn
}

public CBasePlayer_RoundRespawn(const pPlayer)
{
	return g_bFPlayerCanRespawn[pPlayer] ? HC_CONTINUE : HC_SUPERCEDE
}

public CBasePlayer_Spawn(const pPlayer)
{
	if(!is_user_alive(pPlayer))
		return

	g_iNumSpawns[pPlayer]++
	ExecuteForward(g_eCustomForwards[iFwdPlayerSpawned], g_iIgnoreReturn, pPlayer, bool:g_bIsBot[pPlayer], g_iNumSpawns[pPlayer])
}

public CSGameRules_PlayerKilled(const pPlayer, const pKiller, const iGibs)
{
	new iRet
	ExecuteForward(g_eCustomForwards[iFwdPlayerKilled], iRet, pPlayer, IsPlayer(pKiller) ? pKiller : 0, get_member(pPlayer, m_LastHitGroup))

	if(get_member(pPlayer, m_bHasDefuser))
	{
		rg_remove_item(pPlayer, "item_thighpack")
	}

	if(iRet != PLUGIN_HANDLED || g_bFPlayerCanRespawn[pPlayer])
	{
		TaskRespawnStart(pPlayer, g_flRespawnDelay)
	}
}

public CBasePlayer_TraceAttack(const pPlayer, pevAttacker, Float:flDamage, Float:vecDir[3], tracehandle, bitsDamageType)
{
	if(!IsPlayer(pevAttacker) || pPlayer == pevAttacker)
		return HC_CONTINUE

	switch(g_iGamemode)
	{
		case HEADSHOTS_ONLY:
		{
			if(get_tr2(tracehandle, TR_iHitgroup) != HIT_HEAD && get_user_weapon(pevAttacker) != CSW_KNIFE)
				return HC_SUPERCEDE
		}
		case ALWAYS_HIT_HEAD:
		{
			if(get_tr2(tracehandle, TR_iHitgroup) != HIT_HEAD && get_user_weapon(pevAttacker) != CSW_KNIFE)
				set_tr2(tracehandle, TR_iHitgroup, HIT_HEAD)
		}
		case AUTO_HEALER:
		{
			set_member(pPlayer, m_idrowndmg, 100)
			set_member(pPlayer, m_idrownrestored, 0)
			// SetHookChainArg(6, ATYPE_INTEGER, bitsDamageType | DMG_DROWNRECOVER)
		}
		default: return HC_CONTINUE
	}

	return HC_CONTINUE
}

public HandleMenu_ChooseAppearance(const pPlayer, const slot)
{
	if(g_bFirstSpawn[pPlayer])
	{
		EnableHookChain(g_hFPlayerCanRespawn)
		g_bFirstSpawn[pPlayer] = false
	}
	else if(!g_bFPlayerCanRespawn[pPlayer])
	{
		TaskRespawnStart(pPlayer, 0.5)
	}
}

public CSGameRules_FPlayerCanRespawn(const pPlayer)
{
	DisableHookChain(g_hFPlayerCanRespawn)

	SetHookChainReturn(ATYPE_INTEGER, g_bFPlayerCanRespawn[pPlayer])
	return HC_SUPERCEDE
}

public CSGameRules_DeadPlayerWeapons(const pPlayer)
{
	SetHookChainReturn(ATYPE_INTEGER, GR_PLR_DROP_GUN_NO)
	return HC_SUPERCEDE
}

public CSGameRules_RestartRound()
{
	new bool:bIsNewGame = bool:get_member_game(m_bCompleteReset)
	if(bIsNewGame)
	{
		ArraySet(g_iNumSpawns, 0)
	}

	ExecuteForward(g_eCustomForwards[iFwdRestartRound], g_iIgnoreReturn, bool:bIsNewGame)
}

public RoundEnd(WinStatus:status, ScenarioEventEndRound:event, Float:tmDelay)
{
	if(event != ROUND_GAME_COMMENCE)
	{
		SetHookChainReturn(ATYPE_INTEGER, false)
		return HC_SUPERCEDE
	}

	return HC_CONTINUE
}

public EmitSound(const pEntity, const iChannel, const szSample[], Float:fVol, Float:fAttn, iFlags, iPitch)
{
	return (iChannel == CHAN_ITEM && szSample[0] == 'i' && szSample[6] == 'g') ? FMRES_SUPERCEDE : FMRES_IGNORED
}

TaskRespawnStart(const pPlayer, const Float:flDelay = 0.0)
{
	if(flDelay < MIN_RESPAWN_TIME)
	{
		remove_task(PlayerTask(pPlayer))
		RespawnPlayer(pPlayer)
	}
	else
	{
		new iTaskID = PlayerTask(pPlayer)
		if(task_exists(iTaskID))
		{
			change_task(iTaskID, flDelay)
		}
		else
		{
			set_task(flDelay, "TaskRespawnEnd", iTaskID)
		}
		if(g_bShowRespawnBar && flDelay >= 1.5 && !(Menu_ChooseTeam <= get_member(pPlayer, m_iMenu) <= Menu_ChooseAppearance))
		{
			rg_send_bartime(pPlayer, floatround(flDelay), false)
		}
	}
}

public TaskRespawnEnd(const iTaskID) 
{
	RespawnPlayer(GetPlayerByTaskID(iTaskID))
}

RespawnPlayer(const pPlayer)
{
	if(IsPlayerDead(pPlayer) && IsValidTeam(pPlayer))
	{
		rg_round_respawn(pPlayer)
	}
}

public SetCVarValues()
{
	if(g_bFreeForAll)
	{
		set_cvar_num("mp_freeforall", 1)
	}
	// set_cvar_string("mp_round_infinite", "acdefg")

	ExecuteForward(g_eCustomForwards[iFwdExecuteCVarVal], g_iIgnoreReturn)
}

LoadSettings(const ReadTypes:iReadAction = CFG_READ)
{
	new szLineData[MAX_LINE_LEN], eArrayData[config_s], pFile, iItemIndex = INVALID_INDEX, bool:bMainSettings
	new szKey[MAX_KEY_LEN], szValue[MAX_VALUE_LEN], szSign[2]

	if(!(pFile = OpenConfigFile()))
		return

	ExecuteForward(g_eCustomForwards[iFwdConfigLoad], g_iIgnoreReturn, iReadAction)
	set_task(1.0, "SetCVarValues")

	while(!feof(pFile))
	{
		fgets(pFile, szLineData, charsmax(szLineData))
		trim(szLineData)

		if(IsEmptyLine(szLineData) || IsCommentLine(szLineData))
			continue

		if(szLineData[0] == '[')
		{
			bMainSettings = bool:(equali(szLineData, g_szMainSection))
			strtolower(szLineData)
			if(g_iTotalItems && !TrieGetCell(g_tConfigSections, szLineData, iItemIndex))
			{
				iItemIndex = INVALID_INDEX
			}
			continue
		}

		if(g_iTotalItems && iItemIndex != INVALID_INDEX)
		{
			ArrayGetArray(g_aConfigData, iItemIndex, eArrayData)
			PluginCallFunc(eArrayData, szLineData)
		}

		if(!ParseConfigKey(szLineData, szKey, szSign, szValue))
			continue

		strtolower(szKey)
		TrieSetString(g_tConfigValues, szKey, szValue)

		if(bMainSettings)
		{
			if(equali(szKey, "respawn_delay"))
			{
				g_flRespawnDelay = floatclamp(str_to_float(szValue), MIN_RESPAWN_TIME, MAX_RESPAWN_TIME)
			}
			else if(equali(szKey, "show_respawn_bar"))
			{
				g_bShowRespawnBar = bool:(str_to_num(szValue))
			}
			else if(equali(szKey, "block_gunpickup_sound"))
			{
				g_bBlockGunpickupSound = bool:(str_to_num(szValue))
			}
			else if(equali(szKey, "free_for_all"))
			{
				g_bFreeForAll = bool:(str_to_num(szValue))
			}
			else if(equali(szKey, "gameplay_mode"))
			{
				g_iGamemode = GameTypes:clamp(str_to_num(szValue), _:NORMAL_HIT, _:AUTO_HEALER)
			}
		}
	}

	fclose(pFile)
}

OpenConfigFile()
{
	new szConfigDir[MAX_CONFIG_PATH_LEN], szConfigFile[MAX_CONFIG_PATH_LEN + 32]
	new szMapName[32], szMapPrefix[6], pFile

	get_localinfo("amxx_configsdir", szConfigDir, charsmax(szConfigDir))
	get_mapname(szMapName, charsmax(szMapName))

	if(szMapName[0] == '$') // support: $1000$, $2000$, $3000$ ...
		copy(szMapPrefix, charsmax(szMapPrefix), "$")
	else
		copyc(szMapPrefix, charsmax(szMapPrefix), szMapName, '_')

	formatex(szConfigFile, charsmax(szConfigFile), "%s/%s/%s", szConfigDir, g_szMainDir, g_szExtraCfgDir)
	MakeDir(szConfigFile)

	formatex(szConfigFile, charsmax(szConfigFile), "%s/%s/%s/%s.ini", szConfigDir, g_szMainDir, g_szExtraCfgDir, szMapName)
	if((pFile = fopen(szConfigFile, "rt"))) // extra config
	{
		server_print("[CSDM] Extra map config successfully loaded for map ^"%s^"", szMapName)
		return pFile
	}

	formatex(szConfigFile, charsmax(szConfigFile), "%s/%s/%s/prefix_%s.ini", szConfigDir, g_szMainDir, g_szExtraCfgDir, szMapPrefix)
	if((pFile = fopen(szConfigFile, "rt"))) // prefix config
	{
		server_print("[CSDM] Prefix ^"%s^" map config successfully loaded for map ^"%s^"", szMapPrefix, szMapName)
		return pFile
	}

	formatex(szConfigFile, charsmax(szConfigFile), "%s/%s/%s", szConfigDir, g_szMainDir, g_szDefaultCfgFile)
	if((pFile = fopen(szConfigFile, "rt"))) // default config
	{
		server_print("[CSDM] Default config successfully loaded.")		
		return pFile
	}

	ExecuteForward(g_eCustomForwards[iFwdInitialized], g_iIgnoreReturn, "")
	CSDM_SetFailState("[CSDM] ERROR: Config file ^"%s^" not found!", szConfigFile)
	return 0
}

PluginCallFunc(const eArrayData[config_s], const szLineData[])
{
	if(callfunc_begin_i(eArrayData[iPluginFuncID], eArrayData[iPluginID]) == INVALID_HANDLE)
	{
		server_print("[CSDM] ERROR: Called dynanative into a paused plugin!")
		return
	}

	callfunc_push_str(szLineData, .copyback = false)
	callfunc_push_int(eArrayData[iSectionID])
	callfunc_end()
}

CheckForwards()
{
	if(g_iGamemode != NORMAL_HIT)
	{
		EnableHookChain(g_hTraceAttack)
	}
	else
	{
		DisableHookChain(g_hTraceAttack)
	}

	if(g_bBlockGunpickupSound && !g_iFwdEmitSound)
	{
		g_iFwdEmitSound = register_forward(FM_EmitSound, "EmitSound", ._post = false)
	}
	else if(!g_bBlockGunpickupSound && g_iFwdEmitSound)
	{
		unregister_forward(FM_EmitSound, g_iFwdEmitSound, .post = false)
		g_iFwdEmitSound = 0
	}
}

bool:CheckNativeParams(const iParams, const iMin, const iMax)
{
	if(iMin == iMax ? iParams != iMax : !(iMin <= iParams <= iMax)) // max params
	{
		log_error(AMX_ERR_PARAMS, "[CSDM] ERROR: Bad arg count!")
		return false
	}
	return true
}

