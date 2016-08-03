/**
* CREDITS:
* 	Safety1st for 'Uncommon Knife WarmUP' plugin, I took some ideas from his plugin.
* 	Adidasmen for help with ReApi.
* 	gyxoBka for the first version of the plugin.
* 	wopox1337 ,a2 for tests & some help.
 
* Official Support topic: goldsrc.ru/topic/930/

Warmup modes:
	warmup_mode = 0 - "Free Buy"
	warmup_mode = 1 - "Only Knife"
	warmup_mode = 2 - "Equip Menu"
	warmup_mode = 3 - "Auto Equip"
	warmup_mode = 4 - "Random Weapon"
	warmup_mode = 5 - "Random Mode" (0, 4)
**/

#include <amxmodx>
#include <hamsandwich>
#include <reapi>

enum _:WEAPON_DATA { szMenuItemName[64], any:iWeaponID,	iAmmo, any:iTeam }
const TEAM_ALL = 4


/**■■■■■■■■■■■■■■■■■■■■■■■■■■■■ CONFIG START ■■■■■■■■■■■■■■■■■■■■■■■■■■■■*/

#define RESPAWN_TIME 		1	// через сколько секунд игрок возродится
#define PROTECTION_TIME 	2	// сколько секунд действует защита после возрождения

#define RESPAWN_BAR							// закомментируйте, чтобы не показывать полосу после смерти (опционально)
#define PROTECTION_ICON						// закомментируйте, чтобы не показывать иконку во время защиты (опционально)

#define HUD_COLOR_RGB 		67, 218, 231	// цвет RGB худа
#define HUD_MSG_POS 		-1.0, 0.90		// Позиция HUD сообщения о разминке

#define RED_TEAM_COLOUR   	255, 0, 0    	// цвет RGB во время защиты для ТТ ( рендеринг )
#define BLUE_TEAM_COLOUR   	0, 0, 255		// цвет RGB во время защиты для CT ( рендеринг )
#define GLOW_THICK         	10				// "Плотность" цвета защиты (опционально)

#define NODRAW_CORPSES						//  (опционально)
#define AUTO_RELOAD_WEAPON					// AUTO_RELOAD_WEAPON on kill (опционально)
#define INFINITE_AMMO						// unlimited bp ammo (опционально)

// #define KNIFE_MODE_SET_HEALTH 	32		//  (опционально)
#define FREE_BUY_MODE_MONEY		7000		// max give money (опционально)

/** FORMAT: "Menu Name" "Weapon ID" "BackPack Ammo" "Team" */
// note! param "Team" work with AUTO_EQUIP mode
new g_eWeapons[][WEAPON_DATA] = { /* Эту НЕ ТРОГАЙ! :D */ {"", 0, 0, 0}

	// ,{"IMI Galil", WEAPON_GALIL, 90, TEAM_TERRORIST}
	// ,{"GIAT FAMAS", WEAPON_FAMAS, 90, TEAM_CT}
	,{"AK-47", WEAPON_AK47, 90, TEAM_TERRORIST}
	,{"Colt M4A1", WEAPON_M4A1, 90, TEAM_CT}
	// ,{"Steyr Scout", WEAPON_SCOUT, 90, TEAM_ALL}
	// ,{"AI Arctic Warfare Magnum", WEAPON_AWP, 30, TEAM_ALL}
	// ,{"FN Minimi M249 Para", WEAPON_M249, 200, TEAM_ALL}
	// ,{"MP5 Navy", WEAPON_MP5N, 120, TEAM_ALL}
	// ,{"Desert Eagle", WEAPON_DEAGLE, 35, TEAM_ALL}
}

#define USE_API // (опционально)
#define TIME_MIN 	30 	// 30 sec
#define TIME_MAX 	600	// 10 min

/**■■■■■■■■■■■■■■■■■■■■■■■■■■■■■ CONFIG END ■■■■■■■■■■■■■■■■■■■■■■■■■■■■■*/

#define VERSION "1.0.0"

#if !defined Ham_CS_Player_ResetMaxSpeed
	#define Ham_CS_Player_ResetMaxSpeed Ham_Item_PreFrame
#endif

#if defined USE_API
	#include <re_warmup_api>
	new g_iFwdWarmupStart, g_iFwdWarmupEnd
#else
	enum WarmupModes { FREE_BUY = 0, ONLY_KNIFE, EQUIP_MENU, AUTO_EQUIP, RANDOM_WEAPON }
#endif

const STATUSICON_HIDE =	0
const STATUSICON_SHOW = 1
const STATUSICON_FLASH = 2

#define TASK_RESPAWN_ID		13232
#define TASK_PROTECTION_ID	33464
#define TASK_STATE_ID		59737

enum Forwards
{
	HookChain:Spawn,
	HookChain:Killed,
	HookChain:DeadPlayerWeapons,
	HookChain:GiveC4,
	HookChain:FPlayerCanRespawn,
	HookChain:RestartRound
}

#if defined INFINITE_AMMO
	new mp_refill_bpammo_weapons, g_pOldCvarRefillWeapons
#endif
new HamHook:g_hDefuseSpawn, HookChain:g_hChainList[Forwards]
new g_iPreviousItem[MAX_CLIENTS+1], bool:g_bIsUserBot[MAX_CLIENTS+1], bool:g_bShowHelp[MAX_CLIENTS+1]
new g_iCountdown, g_iMsgHookRoundTime, g_iHudSync
new g_pCvarWarmupTime, g_pCvarWarmupMode, bool:g_bFristRestart, bool:g_bWarmupStarted
new g_iMsgIdScenarioIcon, g_iMsgIdRoundTime, g_iMsgIdBarTime, g_iMsgIdStatusIcon, g_iMsgIdBuyClose
new WarmupModes:g_iWarmupMode, g_iEquipMenuID, g_iTotalWeapons

new const g_szWeaponName[any:WEAPON_P90+1][] = {
	"","weapon_p228","","weapon_scout","weapon_hegrenade","weapon_xm1014","weapon_c4",
	"weapon_mac10","weapon_aug","weapon_smokegrenade","weapon_elite","weapon_fiveseven","weapon_ump45",
	"weapon_sg550","weapon_galil","weapon_famas","weapon_usp","weapon_glock18","weapon_awp",
	"weapon_mp5navy","weapon_m249","weapon_m3","weapon_m4a1","weapon_tmp","weapon_g3sg1",
	"weapon_flashbang","weapon_deagle","weapon_sg552","weapon_ak47","weapon_knife","weapon_p90"
}

new const g_szModes[WarmupModes][] = {
	"Free Buy",
	"Only Knife",
	"Equip Menu",
	"Auto Equip",
	"Random Weapon"
}

public plugin_pause()
{
	if(g_bWarmupStarted)
	{
		WarmupEnd(.bSvRestart = false)
	}
}

public plugin_end()
{
#if defined INFINITE_AMMO
	set_pcvar_num(mp_refill_bpammo_weapons, g_pOldCvarRefillWeapons)
#endif
#if defined USE_API
	DestroyForward(g_iFwdWarmupStart)
	DestroyForward(g_iFwdWarmupEnd)
}

public plugin_natives()
{
	register_library("re_warmup_api")
	register_native("GetWarmupState", "NativeGetWarmupState")
	register_native("GetWarmupMode", "NativeGetWarmupMode")
	register_native("SetWarmupMode", "NativeSetWarmupMode")
}

public NativeGetWarmupState(iPlugin, iParams)
{
	return bool:g_bWarmupStarted
}

public WarmupModes:NativeGetWarmupMode(iPlugin, iParams)
{
	return g_iWarmupMode
}

public NativeSetWarmupMode(iPlugin, iParams)
{
	new iTime = get_param(2)
	(iTime <= 0) ? WarmupEnd(.bNotify = true) : WarmupStart(WarmupModes:clamp(get_param(1), 0, 5), clamp((iTime), TIME_MIN, TIME_MAX))
#endif
}

public plugin_init()
{
	register_plugin("Re WarmUp", VERSION, "")
	register_logevent("EventGameCommencing", 2, "0=World triggered", "1=Game_Commencing")
	register_cvar("warmup_version", VERSION, FCVAR_SERVER|FCVAR_SPONLY|FCVAR_UNLOGGED)
	register_concmd("warmup_set", "ConCmd_WarmupStart", ADMIN_CFG, "< time | 0 = off >")

	register_clcmd("client_buy_open", "ClCmd_ShowMenu") // VGUI menu
	register_clcmd("buy", "ClCmd_ShowMenu")

	DisableHamForward(g_hDefuseSpawn = RegisterHam(Ham_Spawn, "item_thighpack", "DefuserSpawned", .Post = false))
	DisableHookChain(g_hChainList[Spawn] = RegisterHookChain(RG_CBasePlayer_Spawn, "CBasePlayer_Spawn", .post = true))
	DisableHookChain(g_hChainList[Killed] = RegisterHookChain(RG_CBasePlayer_Killed, "CBasePlayer_Killed", .post = true))
	DisableHookChain(g_hChainList[DeadPlayerWeapons] = RegisterHookChain(RG_CSGameRules_DeadPlayerWeapons, "CSGameRules_DeadPlayerWeapons", .post = false))
	DisableHookChain(g_hChainList[GiveC4] = RegisterHookChain(RG_CSGameRules_GiveC4, "CSGameRules_GiveC4", .post = false))
	// new
	DisableHookChain(g_hChainList[FPlayerCanRespawn] = RegisterHookChain(RG_CSGameRules_FPlayerCanRespawn, "CSGameRules_FPlayerCanRespawn", .post = false))
	DisableHookChain(g_hChainList[RestartRound] = RegisterHookChain(RG_CSGameRules_RestartRound, "CSGameRules_RestartRound", .post = true))

	g_pCvarWarmupTime = register_cvar("warmup_time", "120")
	g_pCvarWarmupMode = register_cvar("warmup_mode", "2")
#if defined USE_API
	g_iFwdWarmupStart = CreateMultiForward("WarmupStarted", ET_STOP, FP_CELL, FP_CELL)
	g_iFwdWarmupEnd = CreateMultiForward("WarmupEnded", ET_IGNORE)
#endif
#if defined INFINITE_AMMO
	mp_refill_bpammo_weapons = get_cvar_pointer("mp_refill_bpammo_weapons")
	g_pOldCvarRefillWeapons = get_pcvar_num(mp_refill_bpammo_weapons)
#endif
	g_iMsgIdScenarioIcon = get_user_msgid("Scenario")
	g_iMsgIdRoundTime = get_user_msgid("RoundTime")
	g_iMsgIdBarTime = get_user_msgid("BarTime")
	g_iMsgIdStatusIcon = get_user_msgid("StatusIcon")
	g_iMsgIdBuyClose = get_user_msgid("BuyClose")

	g_iHudSync = CreateHudSyncObj()
	buildmenu()
}

public ClCmd_ShowMenu(id)
{
	if(!g_bWarmupStarted || g_iWarmupMode != EQUIP_MENU || !is_user_alive(id))
	{
		return PLUGIN_CONTINUE
	}
	if(get_member(id, m_bVGUIMenus))
	{
		message_begin(MSG_ONE, g_iMsgIdBuyClose, .player = id)
		message_end()
	}

	menu_display(id, g_iEquipMenuID, 0)

	return PLUGIN_HANDLED
}

public ConCmd_WarmupStart(id, level)
{
	if(~get_user_flags(id) & level)
	{
		return PLUGIN_HANDLED
	}

	if(read_argc() < 2)
	{
		WarmupStart(WarmupModes:clamp(get_pcvar_num(g_pCvarWarmupMode), 0, 5), clamp(get_pcvar_num(g_pCvarWarmupTime), TIME_MIN, TIME_MAX))
	}else{
		new szArg[5]
		read_argv(1, szArg, charsmax(szArg))
		new iTime = str_to_num(szArg)

		(iTime <= 0) ? WarmupEnd(.bNotify = true) : WarmupStart(WarmupModes:clamp(get_pcvar_num(g_pCvarWarmupMode), 0, 5), clamp((iTime), TIME_MIN, TIME_MAX))
	}

	return PLUGIN_HANDLED
}

public client_putinserver(id) 
{
	g_iPreviousItem[id] = 0
	g_bIsUserBot[id] = bool:is_user_bot(id)
	g_bShowHelp[id] = true
	remove_task(id + TASK_RESPAWN_ID)
	remove_task(id + TASK_PROTECTION_ID)
}

// Main
public EventGameCommencing()
{
	if(!g_bFristRestart)
	{
		WarmupStart(WarmupModes:clamp(get_pcvar_num(g_pCvarWarmupMode), 0, 5), clamp(get_pcvar_num(g_pCvarWarmupTime), TIME_MIN, TIME_MAX), false)
		g_bFristRestart = true
	}
}

WarmupStart(WarmupModes:iMode, iWarmupTime, bool:bSvRestart = true)
{
	if(g_bWarmupStarted)
	{
		server_print("Warmup already started!")
		return 0
	}

	switch(iMode)
	{
		case FREE_BUY: g_iWarmupMode = FREE_BUY
		case ONLY_KNIFE: g_iWarmupMode = ONLY_KNIFE
		case EQUIP_MENU: g_iWarmupMode = CheckModeCount(EQUIP_MENU) ? EQUIP_MENU : FREE_BUY
		case AUTO_EQUIP: g_iWarmupMode = CheckTotalCount() ? AUTO_EQUIP : FREE_BUY
		case RANDOM_WEAPON: g_iWarmupMode = CheckModeCount(RANDOM_WEAPON) ? RANDOM_WEAPON : FREE_BUY
		case 5: g_iWarmupMode = GetRandomMode()
		// default: return 0 // used clamp
	}
#if defined USE_API
	new iRet
	ExecuteForward(g_iFwdWarmupStart, iRet, g_iWarmupMode, iWarmupTime)
	if(iRet == PLUGIN_HANDLED)
	{
		return 0
	}
#endif

	if(!g_iMsgHookRoundTime)
		g_iMsgHookRoundTime = register_message(g_iMsgIdRoundTime, "Message_RoundTime")
	
	EnableHamForward(g_hDefuseSpawn)
	EnableHookChain(g_hChainList[Spawn])
	EnableHookChain(g_hChainList[Killed])
	EnableHookChain(g_hChainList[GiveC4])
	EnableHookChain(g_hChainList[FPlayerCanRespawn])
	EnableHookChain(g_hChainList[RestartRound])

	if(g_iWarmupMode != ONLY_KNIFE)
	{
		EnableHookChain(g_hChainList[DeadPlayerWeapons])
	}
	if(g_iWarmupMode != FREE_BUY)
	{
		set_member_game(m_bCTCantBuy, true)
		set_member_game(m_bTCantBuy, true)
	}
#if defined INFINITE_AMMO
	set_pcvar_num(mp_refill_bpammo_weapons, 2)
#endif
	g_iCountdown = iWarmupTime
	g_bWarmupStarted = true

	remove_task(TASK_STATE_ID)
	set_task(1.0, "TaskCountdownRestart", TASK_STATE_ID, _, _, "a", g_iCountdown)

	if(bSvRestart)
		server_cmd("sv_restart 1")

	return 1
}

WarmupEnd(bool:bSvRestart = true, bool:bNotify = false)
{
	if(!g_bWarmupStarted)
	{
		if(bNotify)
			server_print("Warmup NOT started!")
		return 0
	}

	show_menu(0, 0, "^n", 1)  // thaks a2
	unregister_message(g_iMsgIdRoundTime, g_iMsgHookRoundTime)
	g_iMsgHookRoundTime = 0
	g_iCountdown = 0
#if defined INFINITE_AMMO
	set_pcvar_num(mp_refill_bpammo_weapons, g_pOldCvarRefillWeapons)
#endif

	DisableHamForward(g_hDefuseSpawn)
	DisableHookChain(g_hChainList[Spawn])
	DisableHookChain(g_hChainList[Killed])
	DisableHookChain(g_hChainList[GiveC4])
	DisableHookChain(g_hChainList[FPlayerCanRespawn])
	DisableHookChain(g_hChainList[RestartRound])
	if(g_hChainList[DeadPlayerWeapons])
		DisableHookChain(g_hChainList[DeadPlayerWeapons])

	if(g_iWarmupMode == ONLY_KNIFE)
		SendScenarioIcon(0, STATUSICON_HIDE)

	if(g_iWarmupMode != FREE_BUY)
	{
		set_member_game(m_bCTCantBuy, false)
		set_member_game(m_bTCantBuy, false)
	}
#if defined USE_API
	new iRet
	ExecuteForward(g_iFwdWarmupEnd, iRet)
#endif
	remove_task(TASK_STATE_ID)
	g_bWarmupStarted = false
	
	if(bSvRestart)
		server_cmd("sv_restart 1")

	return 1
}

public TaskCountdownRestart()
{
	if(--g_iCountdown == 0)
	{
		WarmupEnd()
		set_task(2.0, "EndHud")
	}else{
		set_hudmessage(HUD_COLOR_RGB, HUD_MSG_POS, .effects = 1, .holdtime = 1.0)
		ShowSyncHudMsg(0, g_iHudSync, "[Разминка] Режим: %s", g_szModes[g_iWarmupMode])
		// set_member_game(m_fRoundCount, get_gametime())
	}
}

public EndHud()
{
	set_hudmessage(HUD_COLOR_RGB, -1.0, 0.3, .holdtime = 4.0)
	ShowSyncHudMsg(0, g_iHudSync, "СПАСИБО ЗА РАЗМИНКУ!^nПРИЯТНОЙ ИГРЫ!")
}

public Message_RoundTime(iMesgId, iMsgType, iMsgEnt) 
{
	const ARG_TIME_REMAINING = 1
	/* Msg is sent at player spawn, Round_Start and during HUD initialization in UpdateClientData().
	   Just fake the timer, it is easier than adjusting of 'mp_roundtime' cvar */
	set_msg_arg_int(ARG_TIME_REMAINING, ARG_SHORT, g_iCountdown)
}

public WeaponMenuHandler(id, iMenu, iItem)
{
	if(iItem == MENU_EXIT || iItem < 0)
	{
		return PLUGIN_HANDLED
	}

	new szNum[3], iAccess, hCallback
	menu_item_getinfo(iMenu, iItem, iAccess, szNum, charsmax(szNum), _, _, hCallback)
	new iIndex = str_to_num(szNum)
	GiveWeapon(id, iIndex)

	g_iPreviousItem[id] = iIndex

	if(g_bShowHelp[id])
	{
		client_print(id, print_chat, "Нажмите ^"B^" чтобы открыть меню снова")
		g_bShowHelp[id] = false
	}

	return PLUGIN_HANDLED
}

public DefuserSpawned(iEnt)
{
	return HAM_SUPERCEDE
}

// CBase
public CSGameRules_GiveC4()
{
	return HC_SUPERCEDE
}

public CSGameRules_RestartRound()
{
	set_member_game(m_iRoundWinStatus, WINSTATUS_DRAW) // hack infinite round :D
	set_member_game(m_bFreezePeriod, false)// hack freezetime round :D

	new iPlayers[32], iNum, i
	get_players(iPlayers, iNum, "ah")

	for(i = 0; i < iNum; i++)
	{
		ExecuteHam(Ham_CS_Player_ResetMaxSpeed, iPlayers[i])
	}
}

public CSGameRules_FPlayerCanRespawn(const index)
{
	SetHookChainReturn(ATYPE_INTEGER, true)
	return HC_OVERRIDE
}

public CSGameRules_DeadPlayerWeapons(const index)
{
	SetHookChainReturn(ATYPE_INTEGER, GR_PLR_DROP_GUN_NO)
	return HC_SUPERCEDE
}

public CBasePlayer_Killed(id, pevAttacker, iGib)
{
	set_task(RESPAWN_TIME.0, "Respawn", TASK_RESPAWN_ID + id)
#if defined NODRAW_CORPSES
	set_entvar(id, var_effects, EF_NODRAW)
#endif
#if defined RESPAWN_BAR
	ShowBar(id, RESPAWN_TIME)
#else
	client_print(id, print_center, "Через %d секунды Вы возродитесь", RESPAWN_TIME)
#endif

#if defined AUTO_RELOAD_WEAPON
	if(g_iWarmupMode != ONLY_KNIFE && id != pevAttacker && is_user_alive(pevAttacker))
	{
		new iActiveWeapon = get_member(pevAttacker, m_pActiveItem)
		if(iActiveWeapon > 0)
			rg_instant_reload_weapons(pevAttacker, iActiveWeapon)
	}
#endif
}

public CBasePlayer_Spawn(id)
{
	set_member_game(m_fRoundCount, get_gametime()) // hack buytime :D

	if(!is_user_alive(id))
		return

	new iUserTeam = get_member(id, m_iTeam)
	SetProtection(id, iUserTeam)

	switch(g_iWarmupMode)
	{
		case FREE_BUY: rg_add_account(id, FREE_BUY_MODE_MONEY, AS_SET, true)
		case ONLY_KNIFE:{
			StripWeapons(id)
			SendScenarioIcon(id, STATUSICON_SHOW)
		#if defined KNIFE_MODE_SET_HEALTH
			set_entvar(id, var_health, KNIFE_MODE_SET_HEALTH.0)
		#endif
		}
		case EQUIP_MENU:{
			g_bIsUserBot[id] ? GiveRandomWeapon(id) : g_iPreviousItem[id] ? GiveWeapon(id, g_iPreviousItem[id]) : menu_display(id, g_iEquipMenuID, 0)
		}
		case AUTO_EQUIP:{
			StripWeapons(id)
			GiveTeamWeapon(id, iUserTeam)
		}
		case RANDOM_WEAPON: {
			StripWeapons(id)
			GiveRandomWeapon(id)
		}
		default: return
	}
}

public Respawn(TaskID) 
{
	new id = TaskID - TASK_RESPAWN_ID

	if(!is_user_connected(id)) 
		return

	if(TEAM_TERRORIST <= get_member(id, m_iTeam) <= TEAM_CT && !is_user_alive(id))
	{
		ExecuteHam(Ham_CS_RoundRespawn, id)
	}
}

public SetProtection(id, iUserTeam)
{
	set_entvar(id, var_takedamage, DAMAGE_NO)
#if defined PROTECTION_ICON
	SendStatusIcon(id, STATUSICON_FLASH)
#endif
#if defined GLOW_THICK
	switch(iUserTeam)
	{
		case TEAM_TERRORIST: rm_set_rendering(id, kRenderFxGlowShell, RED_TEAM_COLOUR, GLOW_THICK)
		case TEAM_CT: rm_set_rendering(id, kRenderFxGlowShell, BLUE_TEAM_COLOUR, GLOW_THICK )
	}
#endif

	remove_task(TASK_PROTECTION_ID + id)
	set_task( PROTECTION_TIME.0, "EndProtection", TASK_PROTECTION_ID + id)
}

public EndProtection(TaskID)
{
	new id = TaskID - TASK_PROTECTION_ID

	if(!is_user_connected(id)) 
		return

	SendStatusIcon(id) // hide
	set_entvar(id, var_takedamage, DAMAGE_AIM)

#if defined GLOW_THICK
	rm_set_rendering(id) // reset
#endif
}

// functions
buildmenu()
{
	g_iEquipMenuID = menu_create("Weapons Menu", "WeaponMenuHandler")
	menu_setprop(g_iEquipMenuID, MPROP_EXIT, MEXIT_NEVER)
	menu_setprop(g_iEquipMenuID, MPROP_PERPAGE, 0)
	menu_setprop(g_iEquipMenuID, MPROP_NUMBER_COLOR, "\y")

	new szNum[3], i
	for(i = 1; i < sizeof(g_eWeapons); i++)
	{
		num_to_str(i, szNum, charsmax(szNum))
		menu_additem(g_iEquipMenuID, g_eWeapons[i][szMenuItemName], szNum)
		g_iTotalWeapons++
		if(i >= 9) break
	}
}

WarmupModes:GetRandomMode()
{
	new WarmupModes:iRand = WarmupModes:random_num(any:FREE_BUY, any:RANDOM_WEAPON)
	switch(iRand)
	{
		case EQUIP_MENU: iRand = CheckModeCount(EQUIP_MENU) ? EQUIP_MENU : FREE_BUY
		case AUTO_EQUIP: iRand = CheckTotalCount() ? AUTO_EQUIP : FREE_BUY
		case RANDOM_WEAPON: iRand = CheckModeCount(RANDOM_WEAPON) ? RANDOM_WEAPON : FREE_BUY
		// default: return iRand
	}
	return iRand
}

bool:CheckTotalCount()
{
	if(g_iTotalWeapons < 1)
	{
		server_print("[WARMUP] WARNING: Empty array g_eWeapons! Will be used ^"Free Buy^" mode!")
		return false
	}
	return true
}

bool:CheckModeCount(WarmupModes:iMode)
{
	if(!CheckTotalCount())
	{
		return false
	}
	if((iMode == EQUIP_MENU || iMode == RANDOM_WEAPON) && g_iTotalWeapons < 2)
	{
		server_print("[WARMUP] WARNING: Need more weapons for ^"%s^" mode! Will be used ^"Free Buy^" mode!", g_szModes[iMode])
		return false
	}
	return true
}

// stocks
stock StripWeapons(id)
{
	rg_remove_all_items(id)
	rg_give_item(id, "weapon_knife")
}

stock GiveTeamWeapon(id, iUserTeam)
{
	new i
	for(i = 1; i < sizeof(g_eWeapons); i++)
	{
		if(g_iTotalWeapons == 1 || iUserTeam == g_eWeapons[i][iTeam] || TEAM_ALL == g_eWeapons[i][iTeam])
		{
			GiveWeapon(id, i)
		}
	}
}

stock GiveWeapon(id, iIndex)
{
	new iId = g_eWeapons[iIndex][iWeaponID]
	if(user_has_weapon(id, iId))
	{
		client_print(id, print_center, "У вас уже есть это оружие.")
		return 0
	}

	rg_give_item(id, g_szWeaponName[iId], GT_REPLACE)
	rg_set_user_bpammo(id, WeaponIdType:iId, g_eWeapons[iIndex][iAmmo])
	
	return 1
}

stock GiveRandomWeapon(id)
{
	new iIndex = random_num(1, g_iTotalWeapons)
	GiveWeapon(id, iIndex)
}

stock ShowBar(const id, const iTime)
{
	message_begin(MSG_ONE_UNRELIABLE, g_iMsgIdBarTime, .player = id)
	write_short(iTime)
	message_end()
}

stock SendScenarioIcon(id, status=STATUSICON_HIDE)
{
	if(id){
		// to show icon I use per player msgs to make sure every player will get msg
		message_begin(MSG_ONE, g_iMsgIdScenarioIcon, .player = id)
		write_byte(status)
		write_string("d_knife") // sprite name in hud.txt
		write_byte(0)	// no alpha value
		message_end()
	}else{
		// it is 'global' msg that I use to hide icon only
		message_begin(MSG_BROADCAST, g_iMsgIdScenarioIcon)
		write_byte(status)
		message_end()
	}
}

stock SendStatusIcon(id, status=STATUSICON_HIDE, r=0, g=160, b=0)
{
	message_begin(MSG_ONE_UNRELIABLE, g_iMsgIdStatusIcon, .player = id)
	write_byte(status) // status: 0 - off, 1 - on, 2 - flash
	write_string("suithelmet_full") // sprite name in hud.txt
	write_byte(r) // Color Red
	write_byte(g) // Color Green
	write_byte(b) // Color Blue
	message_end()
}

stock rm_set_rendering(index, fx = kRenderFxNone, r=255, g=255, b=255, amount=16) 
{
	new Float:RenderColor[3]
	RenderColor[0] = float(r)
	RenderColor[1] = float(g)
	RenderColor[2] = float(b)
	
	set_entvar(index, var_renderfx, fx)
	set_entvar(index, var_rendercolor, RenderColor)
	set_entvar(index, var_renderamt, float(amount))
	// return 1
}

