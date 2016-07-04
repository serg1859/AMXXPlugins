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
		1 - Режим DeathMatch только на ножах.
	- Добавлен Knife Icon (Scenario), при режиме 1;
	- Добавлен дефайн позиции HUD сообщения разминки;
	- Добавлено Время раунда на разминке отображает время разминки.
	
	Спасибо Safety1st за плагин Uncommon Knife Warmup, некоторые идеи были взяты у него.
**/

#include <amxmodx>
#include <hamsandwich>
#include <fun>
#include <reapi>

#pragma semicolon 1

new const PLUGIN[] = "Re WarmUp";
new const VERSION[] = "0.9";
new const AUTHOR[] = "gyxoBka";

/*---------------EDIT ME------------------*/

#define RESPAWN_TIME 		1				// через сколько секунд игрок возродится
#define PROTECTION_TIME 	2				// сколько секунд действует защита после возрождения

//#define RESPAWN_BAR						// закомментируйте, чтобы не показывать полосу после смерти
#define PROTECTION_BAR						// закомментируйте, чтобы не показывать полосу во время защиты

#define HUD_COLOR_RGB 		67, 218, 231	// цвет RGB худа
#define HUD_MSG_POS 		0.0, -1.0		// Позиция HUD сообщения о разминке

#define RED_TEAM_COLOUR   	255, 0, 0    	// цвет RGB во время защиты для ТТ ( рендеринг )
#define BLUE_TEAM_COLOUR   	0, 0, 255		// цвет RGB во время защиты для CT ( рендеринг )
#define GLOW_THICK         	10				// "Плотность" цвета защиты

/*----------------------------------------*/

#define TASK_RESPAWN_ID		32
#define TASK_PROTECTION_ID	64

enum Team
{
	TT = 1,
	CT
}

new bool:g_bGameCommencing;
new Float:g_fDeafultBuyTime, g_iDefaultRoundInfinite, g_iDefaultRespawnTime, g_iDefaultFreezeTime;
new HookChain:RegHookSpawn, HookChain:RegHookKilled, HookChain:RegHookDeadPlayer, HookChain:RegHookAddPlayerItem;
new g_iCountdown, g_HudSync, g_MsgBarTime;

new g_pCvarWarmupTime, Float:g_fBuyTime;
new g_pCvarWarmupMode, bool:g_bKnifeMode;

new g_MsgScenarioIcon, g_MsgRoundTime, hookMsgRoundTime;

enum {
	FREE_BUY,
	ONLY_KNIFE
}

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR);

	register_cvar( "rewarmup", VERSION, FCVAR_SERVER|FCVAR_SPONLY|FCVAR_UNLOGGED );
	g_pCvarWarmupTime = register_cvar("warmup_time", "90");
	g_pCvarWarmupMode = register_cvar("warmup_mode", "1");

	register_logevent("EventGameCommencing", 2, "0=World triggered", "1=Game_Commencing");

	g_MsgScenarioIcon = get_user_msgid( "Scenario" );
	g_MsgRoundTime = get_user_msgid( "RoundTime" );
	
	DisableHookChain(RegHookSpawn = RegisterHookChain(RG_CBasePlayer_Spawn, "CBasePlayer_Spawn", true));
	DisableHookChain(RegHookKilled = RegisterHookChain(RG_CBasePlayer_Killed, "CBasePlayer_Killed", true));
	DisableHookChain(RegHookDeadPlayer = RegisterHookChain(RG_CSGameRules_DeadPlayerWeapons, "CSGameRules_DeadPlayerWeapons", false));
	
	if(get_pcvar_num(g_pCvarWarmupMode) == ONLY_KNIFE)
	{
		g_bKnifeMode = true;
		DisableHookChain(RegHookAddPlayerItem = RegisterHookChain(RG_CBasePlayer_AddPlayerItem, "CBasePlayer_AddPlayerItem", false));
	}
	
	g_fDeafultBuyTime = get_cvar_float("mp_buytime");
	g_iDefaultRespawnTime = get_cvar_num("mp_roundrespawn_time");
	g_iDefaultRoundInfinite = get_cvar_num("mp_round_infinite");
	g_iDefaultFreezeTime = get_cvar_num("mp_freezetime");
	g_fBuyTime = get_pcvar_float(g_pCvarWarmupTime)/60.0;

	g_HudSync = CreateHudSyncObj();

	#if defined RESPAWN_TIME || defined PROTECTION_TIME
	g_MsgBarTime = get_user_msgid( "BarTime" );
	#endif
}

public client_disconnect(id) 
{
	remove_task(id + TASK_RESPAWN_ID);
	remove_task(id + TASK_PROTECTION_ID);
}

public EventGameCommencing()
{
	if(g_bGameCommencing) return;

	new iWarmupTime = get_pcvar_num(g_pCvarWarmupTime);
	hookMsgRoundTime = register_message( g_MsgRoundTime, "Message_RoundTime" );
	
	EnableHookChain(RegHookSpawn);
	EnableHookChain(RegHookKilled);
	if(g_bKnifeMode)
	{
		EnableHookChain(RegHookAddPlayerItem);
	}else{
		EnableHookChain(RegHookDeadPlayer);
	}

	set_cvar_float("mp_buytime", g_fBuyTime);
	set_cvar_num("mp_roundrespawn_time", iWarmupTime);
	set_cvar_num("mp_round_infinite", 1);
	set_cvar_num("mp_freezetime", 0);

	g_iCountdown = iWarmupTime;
	g_bGameCommencing = true;

	set_task(1.0, "TaskCountdownRestart", _, _, _, "a", g_iCountdown);
}

public CSGameRules_DeadPlayerWeapons(const index)
{
	SetHookChainReturn(ATYPE_INTEGER, GR_PLR_DROP_GUN_NO);
	return HC_SUPERCEDE;
}	

public CBasePlayer_Killed(id, pevAttacker, iGib)
{
	static TaskID; 
	TaskID = TASK_RESPAWN_ID + id;
	remove_task(TaskID);
	set_task( RESPAWN_TIME.0, "Respawn", TaskID );

	client_print( id, print_center, "Через %d секунды Вы возродитесь", RESPAWN_TIME );

	#if defined RESPAWN_BAR
	ShowBar(id, RESPAWN_TIME);
	#endif

	return HC_CONTINUE;
}

public CBasePlayer_Spawn(id)
{
	if (!is_user_alive(id)) return HC_CONTINUE;
	
	set_user_godmode( id, .godmode = 1 );
	if(!g_bKnifeMode)
	{
		rg_add_account(id, 16000, AS_SET, true);
	}

	#if defined GLOW_THICK
	switch(get_member(id, m_iTeam)) 
	{
		case TT: set_user_rendering( id, kRenderFxGlowShell, RED_TEAM_COLOUR, kRenderNormal, GLOW_THICK );
		case CT: set_user_rendering( id, kRenderFxGlowShell, BLUE_TEAM_COLOUR, kRenderNormal, GLOW_THICK );
	}
	#endif
		
	#if defined PROTECTION_BAR
	ShowBar(id, PROTECTION_TIME);
	#endif
		
	client_print( id, print_center, "У Вас %d секунды на закупку", PROTECTION_TIME );
		
	static TaskID; 
	TaskID = TASK_PROTECTION_ID + id;
		
	remove_task(TaskID);
	set_task( PROTECTION_TIME.0, "DisableProtection", TaskID );
	
	if(g_bKnifeMode)
	{
		SendScenarioIcon(id);
	}
	
	
	return HC_CONTINUE;
}

public Respawn(id) 
{
	id -= TASK_RESPAWN_ID;
	
	if(!is_user_connected(id)) return;
	
	switch(get_member(id, m_iTeam)) 
	{
		case TT, CT: 
		{
			if(!is_user_alive(id)) 
				ExecuteHam(Ham_CS_RoundRespawn, id);
		}
	}
}

public DisableProtection(id)
{
	id -= TASK_PROTECTION_ID;
	if (!is_user_connected(id)) return;
	
	set_user_godmode(id);
	
	#if defined GLOW_THICK
	set_user_rendering( id, kRenderFxNone, 0, 0, 0, kRenderNormal, 0 );
	#endif
}

public TaskCountdownRestart()
{
	switch(	--g_iCountdown )
	{
		case 0: 
		{
			unregister_message( g_MsgRoundTime, hookMsgRoundTime );
			
			DisableHookChain(RegHookSpawn);
			DisableHookChain(RegHookKilled);
			if(g_bKnifeMode)
			{
				DisableHookChain(RegHookAddPlayerItem);
			}else{
				DisableHookChain(RegHookDeadPlayer);
			}
			
			set_cvar_float("mp_buytime", g_fDeafultBuyTime);
			set_cvar_num("mp_round_infinite", g_iDefaultRoundInfinite);
			set_cvar_num("mp_roundrespawn_time", g_iDefaultRespawnTime);
			set_cvar_num("mp_freezetime", g_iDefaultFreezeTime);
			set_cvar_num("sv_restart", 1);
			
			set_task( 2.0, "EndHud" );
		}	
		default:
	{
		set_hudmessage(HUD_COLOR_RGB, HUD_MSG_POS, .holdtime = 1.0);
		ShowSyncHudMsg(0, g_HudSync, "^t^t^t[Разминка]^n^t^tОсталось %d сек.", g_iCountdown);
	}	
}
}	

public EndHud()
{
	set_hudmessage(HUD_COLOR_RGB, -1.0, 0.3, .holdtime = 5.0);
	ShowSyncHudMsg(0, g_HudSync, "СПАСИБО ЗА РАЗМИНКУ!^nПРИЯТНОЙ ИГРЫ!");
}

stock ShowBar(const id, const iTime)
{
	message_begin(MSG_ONE, g_MsgBarTime, _, id);
	write_short(iTime);
	message_end();
}

stock SendScenarioIcon(id)
{
	new const szKnifeIcon[] = "d_knife";
	const ICON_OFF 	= 0;
	const ICON_ON  	= 1;

	if(id) {
		// to show icon I use per player msgs to make sure every player will get msg
		message_begin(MSG_ONE, g_MsgScenarioIcon, _, id);
		write_byte(ICON_ON);
		write_string(szKnifeIcon);
		write_byte(0);	// no alpha value
		message_end();
	}
	else
	{
		// it is 'global' msg that I use to hide icon only
		message_begin(MSG_BROADCAST, g_MsgScenarioIcon);
		write_byte(ICON_OFF);
		message_end();
	}
}

public CBasePlayer_AddPlayerItem(const id, const weapon ) {
	if( get_member(weapon, m_iId) != ITEM_KNIFE ){

		// only knifes are allowed. it is the most simple (but smart) way to prevent using all other weapons
		set_entvar(weapon, var_flags, get_entvar( weapon, var_flags ) | FL_KILLME );
		
		SetHookChainReturn(ATYPE_INTEGER);
		return HC_SUPERCEDE;
	}
	
	return HC_CONTINUE;
}

public Message_RoundTime( msgid, dest, receiver ) {
	const ARG_TIME_REMAINING = 1;

	/* Msg is sent at player spawn, Round_Start and during HUD initialization in UpdateClientData().
	   Just fake the timer, it is easier than adjusting of 'mp_roundtime' cvar */
	set_msg_arg_int( ARG_TIME_REMAINING, ARG_SHORT, g_iCountdown );
}