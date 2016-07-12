/**
* CREDITS:
* 	Safety1st for his 'Spawn Protection' plugin, I took idea with bar
*  Adidasmen for help with ReApi
*  a2 for tests

update: 0.9 (wopox1337)
	- Убраны лишние дефайны;
	- Добавлен квар warmup_time (Сколько длится разминка);
	- Добавлен квар warmup_mode:
		0 - 16000$ на респауне и покупка любого оружия,
		1 - Режим только на ножах.
	- Добавлен Knife Icon (Scenario), при режиме 1;
	- Добавлен дефайн позиции HUD сообщения разминки;
	- Добавлено Время раунда на разминке отображает время разминки;
	update:0.9a
	- На время разминки бомба не выдаётся.
	
	Спасибо Safety1st за плагин Uncommon Knife Warmup, некоторые идеи были взяты у него.

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

#define RESPAWN_TIME 		1				// через сколько секунд игрок возродится
#define PROTECTION_TIME 	2				// сколько секунд действует защита после возрождения

// #define RESPAWN_BAR						// закомментируйте, чтобы не показывать полосу после смерти
#define PROTECTION_ICON						// закомментируйте, чтобы не показывать иконку во время защиты

#define HUD_COLOR_RGB 		67, 218, 231	// цвет RGB худа
#define HUD_MSG_POS 		-1.0, 0.90		// Позиция HUD сообщения о разминке

#define RED_TEAM_COLOUR   	255, 0, 0    	// цвет RGB во время защиты для ТТ ( рендеринг )
#define BLUE_TEAM_COLOUR   	0, 0, 255		// цвет RGB во время защиты для CT ( рендеринг )
#define GLOW_THICK         	10				// "Плотность" цвета защиты

#define NODRAW_CORPSES						// 
#define AUTO_RELOAD_WEAPON					//
// #define KNIFE_MODE_SET_HEALTH 	32		// 
#define FREE_BUY_MODE_MONEY		7000		// 

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

#define USE_API
#define TIME_MIN 	30 	// 30 sec
#define TIME_MAX 	600	// 10 min

/**■■■■■■■■■■■■■■■■■■■■■■■■■■■■■ CONFIG END ■■■■■■■■■■■■■■■■■■■■■■■■■■■■■*/

new const PLUGIN[] = "Re WarmUp"
new const VERSION[] = "0.9a"
new const AUTHOR[] = "gyxoBka"

#if defined USE_API
	#include <re_warmup_api>
	new g_iFwdWarmupStart, g_iFwdWarmupEnd
#else
	enum WarmupModes { FREE_BUY = 0, ONLY_KNIFE, EQUIP_MENU, AUTO_EQUIP, RANDOM_WEAPON }
#endif

#define TASK_RESPAWN_ID		13232
#define TASK_PROTECTION_ID	33464
#define TASK_STATE_ID		59737

enum Forwards
{
	HookChain:Spawn,
	HookChain:Killed,
	HookChain:DeadPlayerWeapons,
	HookChain:GiveC4,
	HookChain:ChooseAppearance
}

new HamHook:g_hDefuseSpawn
new HookChain:g_hChainList[Forwards], g_iPreviousItem[MAX_CLIENTS+1]
new bool:g_bIsUserBot[MAX_CLIENTS+1], bool:g_bFirstSpawn[MAX_CLIENTS+1]
// old cvar values
new mp_round_infinite, mp_roundrespawn_time, mp_freezetime, mp_refill_bpammo_weapons

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
		// back_cvar_values()
		WarmupEnd(.bSvRestart = false, .bNotify = false)
	}
}

public plugin_end()
{
	back_cvar_values()
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
	(iTime <= 0) ? WarmupEnd(.bSvRestart = true, .bNotify = true) : WarmupStart(WarmupModes:clamp(get_param(1), 0, 5), clamp((iTime), TIME_MIN, TIME_MAX))
#endif
}

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR)
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
	DisableHookChain(g_hChainList[ChooseAppearance] = RegisterHookChain(RG_HandleMenu_ChooseAppearance, "HandleMenu_ChooseAppearance", .post = true))

	g_pCvarWarmupTime = register_cvar("warmup_time", "120")
	g_pCvarWarmupMode = register_cvar("warmup_mode", "2")
#if defined USE_API
	g_iFwdWarmupStart = CreateMultiForward("WarmupStarted", ET_STOP, FP_CELL, FP_CELL)
	g_iFwdWarmupEnd = CreateMultiForward("WarmupEnded", ET_IGNORE)
#endif

	mp_roundrespawn_time = get_cvar_num("mp_roundrespawn_time")
	mp_round_infinite = get_cvar_num("mp_round_infinite")
	mp_freezetime = get_cvar_num("mp_freezetime")
	mp_refill_bpammo_weapons = get_cvar_num("mp_refill_bpammo_weapons")

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

		(iTime <= 0) ? WarmupEnd(.bSvRestart = true, .bNotify = true) : WarmupStart(WarmupModes:clamp(get_pcvar_num(g_pCvarWarmupMode), 0, 5), clamp((iTime), TIME_MIN, TIME_MAX))
	}

	return PLUGIN_HANDLED
}

public client_putinserver(id) 
{
	g_iPreviousItem[id] = 0
	g_bIsUserBot[id] = bool:is_user_bot(id)
	g_bFirstSpawn[id] = true
	remove_task(id + TASK_RESPAWN_ID)
	remove_task(id + TASK_PROTECTION_ID)
}

// Main
public EventGameCommencing()
{
	if(!g_bFristRestart)
	{
		WarmupStart(WarmupModes:clamp(get_pcvar_num(g_pCvarWarmupMode), 0, 5), clamp(get_pcvar_num(g_pCvarWarmupTime), TIME_MIN, TIME_MAX))
		g_bFristRestart = true
	}
}

public WarmupStart(WarmupModes:iMode, iWarmupTime)
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

	EnableHookChain(g_hChainList[Spawn])
	EnableHookChain(g_hChainList[Killed])
	EnableHookChain(g_hChainList[GiveC4])
	EnableHookChain(g_hChainList[ChooseAppearance])
	EnableHamForward(g_hDefuseSpawn)

	if(g_iWarmupMode != ONLY_KNIFE)
	{
		EnableHookChain(g_hChainList[DeadPlayerWeapons])
	}
	if(g_iWarmupMode != FREE_BUY)
	{
		set_member_game(m_bCTCantBuy, true)
		set_member_game(m_bTCantBuy, true)
	}

	set_cvar_num("mp_roundrespawn_time", iWarmupTime)
	set_cvar_num("mp_round_infinite", 1)
	set_cvar_num("mp_freezetime", 0)
	set_cvar_num("mp_refill_bpammo_weapons", 2)
	g_iCountdown = iWarmupTime

	remove_task(TASK_STATE_ID)
	set_task(1.0, "TaskCountdownRestart", TASK_STATE_ID, _, _, "a", g_iCountdown)
	g_bWarmupStarted = true
	server_cmd("sv_restart 1")

	return 1
}

public WarmupEnd(bool:bSvRestart, bool:bNotify)
{
	if(!g_bWarmupStarted)
	{
		if(bNotify)
			server_print("Warmup NOT started!")
		return 0
	}

	unregister_message(g_iMsgIdRoundTime, g_iMsgHookRoundTime)
	show_menu(0, 0, "^n", 1)  // thaks a2

	g_iMsgHookRoundTime = 0
	g_iCountdown = 0
	back_cvar_values()
	SendStatusIcon(0)

	DisableHookChain(g_hChainList[Spawn])
	DisableHookChain(g_hChainList[Killed])
	DisableHookChain(g_hChainList[GiveC4])
	DisableHookChain(g_hChainList[ChooseAppearance])
	if(g_hChainList[DeadPlayerWeapons])
		DisableHookChain(g_hChainList[DeadPlayerWeapons])
	if(g_hDefuseSpawn)
		DisableHamForward(g_hDefuseSpawn)

	if(g_iWarmupMode == ONLY_KNIFE)
		SendScenarioIcon(0)

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
		WarmupEnd(.bSvRestart = true, .bNotify = false)
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

	return PLUGIN_HANDLED
}

public DefuserSpawned(iEnt)
{
	return HAM_SUPERCEDE
}

// CBasePlayer
public CSGameRules_GiveC4()
{
	SetHookChainReturn(ATYPE_INTEGER, 0)
	return HC_SUPERCEDE
}

public HandleMenu_ChooseAppearance(const index, const slot)
{
	if(1 <= slot <= 5/*only cstrike*/ && !is_user_alive(index) && !g_bFirstSpawn[index])
	{
		ExecuteHamB(Ham_CS_RoundRespawn, index)
	}
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
	g_bFirstSpawn[id] = false

	switch(g_iWarmupMode)
	{
		case FREE_BUY: rg_add_account(id, FREE_BUY_MODE_MONEY, AS_SET, true)
		case ONLY_KNIFE:{
			StripWeapons(id)
			SendScenarioIcon(id)
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
	SendStatusIcon(id, .status = 2)
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

	SendStatusIcon(id)
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

back_cvar_values()
{
	set_cvar_num("mp_round_infinite", mp_round_infinite)
	set_cvar_num("mp_roundrespawn_time", mp_roundrespawn_time)
	set_cvar_num("mp_freezetime", mp_freezetime)
	set_cvar_num("mp_refill_bpammo_weapons", mp_refill_bpammo_weapons)
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
	rg_give_item(id, g_szWeaponName[iId], GT_REPLACE)
	rg_set_user_bpammo(id, WeaponIdType:iId, g_eWeapons[iIndex][iAmmo])
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

stock SendScenarioIcon(id)
{
	const ICON_OFF = 0
	const ICON_ON = 1

	if(id){
		// to show icon I use per player msgs to make sure every player will get msg
		message_begin(MSG_ONE, g_iMsgIdScenarioIcon, .player = id)
		write_byte(ICON_ON)
		write_string("d_knife") // sprite name in hud.txt
		write_byte(0)	// no alpha value
		message_end()
	}else{
		// it is 'global' msg that I use to hide icon only
		message_begin(MSG_BROADCAST, g_iMsgIdScenarioIcon)
		write_byte(ICON_OFF)
		message_end()
	}
}

stock SendStatusIcon(id, status=0, r=0, g=160, b=0)
{
	if(id){
		message_begin(MSG_ONE_UNRELIABLE, g_iMsgIdStatusIcon, .player = id)
		write_byte(status) // status: 0 - off, 1 - on, 2 - flash
		write_string("suithelmet_full") // sprite name in hud.txt
		write_byte(r) // Color Red
		write_byte(g) // Color Green
		write_byte(b) // Color Blue
		message_end()
	}else{
		message_begin(MSG_BROADCAST, g_iMsgIdStatusIcon)
		write_byte(0) // status: 0 - off, 1 - on, 2 - flash
		message_end()
	}
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

