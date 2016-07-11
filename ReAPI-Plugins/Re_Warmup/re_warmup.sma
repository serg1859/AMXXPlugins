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
**/

// #pragma semicolon 1

#include <amxmodx>
#include <hamsandwich>
#include <reapi>

enum _:WEAPON_DATA { szMenuItemName[64], any:iWeaponID,	iAmmo }


/*---------------EDIT ME------------------*/

#define RESPAWN_TIME 		1				// через сколько секунд игрок возродится
#define PROTECTION_TIME 	2				// сколько секунд действует защита после возрождения

// #define KNIFE_MODE_SET_HEALTH 	32		// 

//#define RESPAWN_BAR						// закомментируйте, чтобы не показывать полосу после смерти
#define PROTECTION_BAR						// закомментируйте, чтобы не показывать полосу во время защиты

#define HUD_COLOR_RGB 		67, 218, 231	// цвет RGB худа
#define HUD_MSG_POS 		-1.0, 0.90		// Позиция HUD сообщения о разминке

#define RED_TEAM_COLOUR   	255, 0, 0    	// цвет RGB во время защиты для ТТ ( рендеринг )
#define BLUE_TEAM_COLOUR   	0, 0, 255		// цвет RGB во время защиты для CT ( рендеринг )
#define GLOW_THICK         	10				// "Плотность" цвета защиты

new g_eMenuData[][WEAPON_DATA] = { /* Эту НЕ ТРОГАЙ! :D */ {"", 0, 0}
	/** FORMAT: "Menu Name" "Weapon ID" "BackPack Ammo" */

	// ,{"IMI Galil", WEAPON_GALIL, 90}
	// ,{"GIAT FAMAS", WEAPON_FAMAS, 90}
	,{"AK-47", WEAPON_AK47, 90}
	,{"Colt M4A1", WEAPON_M4A1, 90}
	// ,{"Steyr Scout", WEAPON_SCOUT, 90}
	// ,{"AI Arctic Warfare Magnum", WEAPON_AWP, 30}
	// ,{"FN Minimi M249 Para", WEAPON_M249, 200}
	// ,{"MP5 Navy", WEAPON_MP5N, 120}
	,{"Desert Eagle", WEAPON_DEAGLE, 35}
}

// #define USE_API
/*----------------------------------------*/

new const PLUGIN[] = "Re WarmUp";
new const VERSION[] = "0.9a";
new const AUTHOR[] = "gyxoBka";

#if defined USE_API
	#include <re_warmup_api>
	new g_iFwdWarmupStart, g_iFwdWarmupEnd
#else
	enum WarmupModes { FREE_BUY = 0, ONLY_KNIFE, EQUIP_MENU, RANDOM_WEAPON }
#endif

#define SetBit(%1)			(g_bBotUser |=  (1<<(%1 & 31)))
#define ClearBit(%1)		(g_bBotUser &= ~(1<<(%1 & 31)))
#define IsUserBot(%1)		(g_bBotUser & (1<<(%1 & 31)))

#define TASK_RESPAWN_ID		13232
#define TASK_PROTECTION_ID	33464
#define TASK_STATE_ID		59737

new bool:g_bGameCommencing;
new g_iDefaultRoundInfinite, g_iDefaultRespawnTime, g_iDefaultFreezeTime;
new HookChain:RegHookSpawn, HookChain:RegHookKilled, HookChain:RegHookDeadPlayer, HookChain:RegHookGiveC4, HookChain:RegHookChooseAppearance

new g_iCountdown, g_HudSync, g_MsgBarTime, g_bBotUser
new g_pCvarWarmupTime, g_pCvarWarmupMode
new g_MsgIDScenarioIcon, g_MsgIDRoundTime, g_MsgHookRoundTime
new WarmupModes:g_iWarmupMode, g_iEquipMenuID

new const g_szWeaponName[any:WEAPON_P90+1][] = {
	"","weapon_p228","","weapon_scout","weapon_hegrenade","weapon_xm1014","weapon_c4",
	"weapon_mac10","weapon_aug","weapon_smokegrenade","weapon_elite","weapon_fiveseven","weapon_ump45",
	"weapon_sg550","weapon_galil","weapon_famas","weapon_usp","weapon_glock18","weapon_awp",
	"weapon_mp5navy","weapon_m249","weapon_m3","weapon_m4a1","weapon_tmp","weapon_g3sg1",
	"weapon_flashbang","weapon_deagle","weapon_sg552","weapon_ak47","weapon_knife","weapon_p90"
}

public plugin_end()
{
	set_cvar_num("mp_round_infinite", g_iDefaultRoundInfinite)
	set_cvar_num("mp_roundrespawn_time", g_iDefaultRespawnTime)
	set_cvar_num("mp_freezetime", g_iDefaultFreezeTime)
#if defined USE_API
	DestroyForward(g_iFwdWarmupStart)
	DestroyForward(g_iFwdWarmupEnd)
}

public plugin_natives()
{
	register_library("re_warmup_api")
	register_native("GetWarmupMode", "NativeGetWarmupMode")
	register_native("SetWarmupMode", "NativeSetWarmupMode")
}

public NativeGetWarmupMode(iPlugin, iParams)
{
	return any:g_iWarmupMode
}

public NativeSetWarmupMode(iPlugin, iParams)
{
	g_iWarmupMode = WarmupModes:get_param(1)
	new iNum = get_param(2)
	(iNum <= 0) ? WarmupEnd() : WarmupStart(iNum)

	server_cmd("sv_restart 1")
#endif
}

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR);
	register_logevent("EventGameCommencing", 2, "0=World triggered", "1=Game_Commencing");
	register_cvar( "rewarmup", VERSION, FCVAR_SERVER|FCVAR_SPONLY|FCVAR_UNLOGGED );
	register_concmd("warmup_start", "ConCmd_WarmupStart", ADMIN_CFG, "< time | 0 = off >")

	DisableHookChain(RegHookSpawn = RegisterHookChain(RG_CBasePlayer_Spawn, "CBasePlayer_Spawn", .post = true));
	DisableHookChain(RegHookKilled = RegisterHookChain(RG_CBasePlayer_Killed, "CBasePlayer_Killed", .post = true));
	DisableHookChain(RegHookDeadPlayer = RegisterHookChain(RG_CSGameRules_DeadPlayerWeapons, "CSGameRules_DeadPlayerWeapons", .post = false));
	DisableHookChain(RegHookGiveC4 = RegisterHookChain(RG_CSGameRules_GiveC4, "CSGameRules_GiveC4", .post = false));
	DisableHookChain(RegHookChooseAppearance = RegisterHookChain(RG_HandleMenu_ChooseAppearance, "HandleMenu_ChooseAppearance", .post = true));

	g_pCvarWarmupTime = register_cvar("warmup_time", "60");
	g_pCvarWarmupMode = register_cvar("warmup_mode", "1");
#if defined USE_API
	g_iFwdWarmupStart = CreateMultiForward("WarmupStarted", ET_IGNORE)
	g_iFwdWarmupEnd = CreateMultiForward("WarmupEnded", ET_IGNORE)
#endif
	g_iDefaultRespawnTime = get_cvar_num("mp_roundrespawn_time");
	g_iDefaultRoundInfinite = get_cvar_num("mp_round_infinite");
	g_iDefaultFreezeTime = get_cvar_num("mp_freezetime");

	g_MsgIDScenarioIcon = get_user_msgid( "Scenario" );
	g_MsgIDRoundTime = get_user_msgid( "RoundTime" );
	g_MsgBarTime = get_user_msgid( "BarTime" );	

	g_HudSync = CreateHudSyncObj()
	buildmenu()
}

buildmenu()
{
	g_iEquipMenuID = menu_create("Weapons Menu", "WeaponMenuHandler")
	menu_setprop(g_iEquipMenuID, MPROP_EXIT, MEXIT_NEVER)
	menu_setprop(g_iEquipMenuID, MPROP_PERPAGE, 0)
	menu_setprop(g_iEquipMenuID, MPROP_NUMBER_COLOR, "\y")

	new szNum[3], i
	for(i = 1; i < sizeof(g_eMenuData); i++)
	{
		num_to_str(i, szNum, charsmax(szNum))
		menu_additem(g_iEquipMenuID, g_eMenuData[i][szMenuItemName], szNum)
		if(i >= 9) break
	}
}

public ConCmd_WarmupStart(id, level)
{
	if(~get_user_flags(id) & level)
	{
		return PLUGIN_HANDLED
	}

	if(read_argc() < 2)
	{
		WarmupStart(get_pcvar_num(g_pCvarWarmupTime))
	}else{
		new szArg[5], iNum = 0
		read_argv(1, szArg, charsmax(szArg))

		iNum = str_to_num(szArg)
		(iNum <= 0) ? WarmupEnd() : WarmupStart(iNum)
	}
	server_cmd("sv_restart 1")

	return PLUGIN_HANDLED
}

public client_putinserver(id) 
{
	is_user_bot(id) ? SetBit(id) : ClearBit(id)
}

public client_disconnect(id) 
{
	remove_task(id + TASK_RESPAWN_ID);
	remove_task(id + TASK_PROTECTION_ID);
	ClearBit(id)
}

// Main
public EventGameCommencing()
{
	if(!g_bGameCommencing)
	{
		WarmupStart(get_pcvar_num(g_pCvarWarmupTime))
		g_bGameCommencing = true
	}
}

public WarmupStart(iWarmupTime)
{
	switch(clamp(get_pcvar_num(g_pCvarWarmupMode), 0, 3))
	{
		case 0: g_iWarmupMode = FREE_BUY
		case 1: g_iWarmupMode = ONLY_KNIFE
		case 2: g_iWarmupMode = EQUIP_MENU
		case 3: g_iWarmupMode = RANDOM_WEAPON
		/* 
		default:{
			server_print("[AMXX] WARNING: Wrong value ^"warmup_mode^" ^"%d^"", g_iWarmupMode) // 
			g_iWarmupMode = FREE_BUY
		} 
		*/
	}
	// server_print("%d", g_iWarmupMode)
	if(!g_MsgHookRoundTime)
	{
		g_MsgHookRoundTime = register_message( g_MsgIDRoundTime, "Message_RoundTime" );
	}
	EnableHookChain(RegHookSpawn);
	EnableHookChain(RegHookKilled);
	EnableHookChain(RegHookGiveC4);
	EnableHookChain(RegHookChooseAppearance);

	if(g_iWarmupMode != ONLY_KNIFE)
	{
		EnableHookChain(RegHookDeadPlayer)
	}
	if(g_iWarmupMode != FREE_BUY)
	{
		set_member_game(m_bCTCantBuy, true)
		set_member_game(m_bTCantBuy, true)
	}

	set_cvar_num("mp_roundrespawn_time", iWarmupTime);
	set_cvar_num("mp_round_infinite", 1);
	set_cvar_num("mp_freezetime", 0);
	
	g_iCountdown = iWarmupTime	
	remove_task(TASK_STATE_ID)
	set_task(1.0, "TaskCountdownRestart", TASK_STATE_ID, _, _, "a", g_iCountdown)
#if defined USE_API
	new iRet
	ExecuteForward(g_iFwdWarmupStart, iRet)
#endif
}

public WarmupEnd()
{
	unregister_message( g_MsgIDRoundTime, g_MsgHookRoundTime );
	g_MsgHookRoundTime = 0
	g_iCountdown = 0

	DisableHookChain(RegHookSpawn);
	DisableHookChain(RegHookKilled);
	DisableHookChain(RegHookGiveC4);
	DisableHookChain(RegHookChooseAppearance);

	if(g_iWarmupMode == ONLY_KNIFE)
	{
		SendScenarioIcon(0)
	}else{
		DisableHookChain(RegHookDeadPlayer)
	}
	if(g_iWarmupMode != FREE_BUY)
	{
		set_member_game(m_bCTCantBuy, false)
		set_member_game(m_bTCantBuy, false)
	}

	set_cvar_num("mp_round_infinite", g_iDefaultRoundInfinite);
	set_cvar_num("mp_roundrespawn_time", g_iDefaultRespawnTime);
	set_cvar_num("mp_freezetime", g_iDefaultFreezeTime);

#if defined USE_API
	new iRet
	ExecuteForward(g_iFwdWarmupEnd, iRet)
#endif
	remove_task(TASK_STATE_ID)
}

public TaskCountdownRestart()
{
	switch(	--g_iCountdown )
	{
		case 0:{
			WarmupEnd()
			server_cmd("sv_restart 1")
			set_task( 2.0, "EndHud" )
		}
		default:{
			set_hudmessage(HUD_COLOR_RGB, HUD_MSG_POS, .effects = 1, .holdtime = 1.0);
			ShowSyncHudMsg(0, g_HudSync, "[Режим Разминки]");
			// set_member_game(m_fRoundCount, get_gametime())
		}
	}
}

public EndHud()
{
	set_hudmessage(HUD_COLOR_RGB, -1.0, 0.3, .holdtime = 5.0);
	ShowSyncHudMsg(0, g_HudSync, "СПАСИБО ЗА РАЗМИНКУ!^nПРИЯТНОЙ ИГРЫ!");
}

public Message_RoundTime( msgid, dest, receiver ) {
	const ARG_TIME_REMAINING = 1;

	/* Msg is sent at player spawn, Round_Start and during HUD initialization in UpdateClientData().
	   Just fake the timer, it is easier than adjusting of 'mp_roundtime' cvar */
	set_msg_arg_int( ARG_TIME_REMAINING, ARG_SHORT, g_iCountdown );
}

public WeaponMenuHandler(id, iMenu, iItem)
{
	if(iItem == MENU_EXIT || iItem < 0)
	{
		return PLUGIN_HANDLED
	}

	new szNum[3], iAccess, hCallback
	menu_item_getinfo(iMenu, iItem, iAccess, szNum, charsmax(szNum), _, _, hCallback)

	GiveWeapon(id, (str_to_num(szNum)))

	return PLUGIN_HANDLED
}

// CBasePlayer
public CSGameRules_GiveC4() 
{
	SetHookChainReturn(ATYPE_INTEGER, 0)
	return HC_SUPERCEDE; 
}

public HandleMenu_ChooseAppearance(const index, const slot)
{
	if(1 <= slot <= 4/*only cstrike*/ && !is_user_alive(index))
	{
		ExecuteHamB(Ham_CS_RoundRespawn, index)
	}
}

public CSGameRules_DeadPlayerWeapons(const index)
{
	SetHookChainReturn(ATYPE_INTEGER, GR_PLR_DROP_GUN_NO);
	return HC_SUPERCEDE;
}

public CBasePlayer_Killed(id, pevAttacker, iGib)
{
	set_task( RESPAWN_TIME.0, "Respawn", TASK_RESPAWN_ID + id );
	set_entvar(id, var_effects, EF_NODRAW)

	client_print( id, print_center, "Через %d секунды Вы возродитесь", RESPAWN_TIME );

#if defined RESPAWN_BAR
	ShowBar(id, RESPAWN_TIME);
#endif

	return HC_CONTINUE;
}

public CBasePlayer_Spawn(id)
{
	set_member_game(m_fRoundCount, get_gametime())

	if (!is_user_alive(id)) return HC_CONTINUE;

	SetProtection(id);

	switch(g_iWarmupMode)
	{
		case FREE_BUY: rg_add_account(id, 16000, AS_SET, true);
		case ONLY_KNIFE:{
			SendScenarioIcon(id)
		#if defined KNIFE_MODE_SET_HEALTH
			set_entvar(id, var_health, KNIFE_MODE_SET_HEALTH.0)
		#endif
		}
		case EQUIP_MENU: IsUserBot(id) ? GiveRandomWeapon(id) : menu_display(id, g_iEquipMenuID, 0)
		case RANDOM_WEAPON: GiveRandomWeapon(id)
		// default: return HC_CONTINUE;
	}
	return HC_CONTINUE;
}

public Respawn(TaskID) 
{
	new id = TaskID - TASK_RESPAWN_ID

	if(!is_user_connected(id)) return;

	if(TEAM_TERRORIST <= get_member(id, m_iTeam) <= TEAM_CT && !is_user_alive(id))
	{
		ExecuteHam(Ham_CS_RoundRespawn, id);
	}
}

public SetProtection(id)
{
	set_entvar(id, var_takedamage, DAMAGE_NO);
#if defined PROTECTION_BAR
	ShowBar(id, PROTECTION_TIME);
#endif
#if defined GLOW_THICK
	switch(get_member(id, m_iTeam))
	{
		case TEAM_TERRORIST:{
			rm_set_rendering( id, kRenderFxGlowShell, RED_TEAM_COLOUR, GLOW_THICK );
			rg_remove_item(id, "weapon_glock18")
		}
		case TEAM_CT:{
			rm_set_rendering( id, kRenderFxGlowShell, BLUE_TEAM_COLOUR, GLOW_THICK );
			rg_remove_item(id, "weapon_usp")
		}
	}
#endif

	// client_print( id, print_center, "У Вас %d секунды на закупку", PROTECTION_TIME );

	remove_task(TASK_PROTECTION_ID + id);
	set_task( PROTECTION_TIME.0, "DisableProtection", TASK_PROTECTION_ID + id );
}

public DisableProtection(TaskID)
{
	new id = TaskID - TASK_PROTECTION_ID;
	if (!is_user_connected(id)) return;

	set_entvar(id, var_takedamage, DAMAGE_AIM);
	
#if defined GLOW_THICK
	rm_set_rendering( id );
#endif
}

stock GiveWeapon(id, iIndex)
{
	new iId = g_eMenuData[iIndex][iWeaponID]
	rg_give_item(id, g_szWeaponName[iId])
	rg_set_user_bpammo(id, WeaponIdType:iId, g_eMenuData[iIndex][iAmmo])
}

stock GiveRandomWeapon(id)
{
	new iIndex = random_num(1, charsmax(g_eMenuData))
	GiveWeapon(id, iIndex)
}

stock ShowBar(const id, const iTime)
{
	message_begin(MSG_ONE, g_MsgBarTime, _, id);
	write_short(iTime);
	message_end();
}

stock SendScenarioIcon(id)
{
	const ICON_OFF 	= 0;
	const ICON_ON  	= 1;
	static const szKnifeIcon[] = "d_knife";

	if(id){
		// to show icon I use per player msgs to make sure every player will get msg
		message_begin(MSG_ONE, g_MsgIDScenarioIcon, _, id);
		write_byte(ICON_ON);
		write_string(szKnifeIcon);
		write_byte(0);	// no alpha value
		message_end();
	}else{
		// it is 'global' msg that I use to hide icon only
		message_begin(MSG_BROADCAST, g_MsgIDScenarioIcon);
		write_byte(ICON_OFF);
		message_end();
	}
}

stock rm_set_rendering(index, fx = kRenderFxNone, r = 255, g = 255, b = 255, amount = 16) 
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

