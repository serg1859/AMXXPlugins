/**
* CREDITS:
* 	Safety1st for his 'Spawn Protection' plugin, I took idea with bar
*  Adidasmen for help with ReApi
*  a2 for tests
**/

#include <amxmodx>
#include <hamsandwich>
#include <fun>
#include <reapi>

#pragma semicolon 1

new const PLUGIN[] = "Re WarmUp";
new const VERSION[] = "0.8";
new const AUTHOR[] = "gyxoBka";

/*---------------EDIT ME------------------*/

#define RESPAWN_TIME 		3				// через сколько секунд игрок возродится
#define PROTECTION_TIME 	3				// сколько секунд действует защита после возрождения

#define RESPAWN_BAR							// закомментируйте, чтобы не показывать полосу после смерти
#define PROTECTION_BAR						// закомментируйте, чтобы не показывать полосу во время защиты

#define BUY_TIME 			1.5				// квар mp_buytime во время разминки ( Дефолт: 1 минута 30 секунд )
#define WARMUP_TIME 		90				// время разминки в секундах ( Дефолт: 1 минута 30 секунд )

#define HUD_COLOR_RGB 		67, 218, 231	// цвет RGB худа

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
new HookChain:RegHookSpawn, HookChain:RegHookKilled, HookChain:RegHookDeadPlayer;
new g_iCountdown, g_HudSync, g_MsgBarTime;

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR);

	register_cvar( "rewarmup", VERSION, FCVAR_SERVER|FCVAR_SPONLY|FCVAR_UNLOGGED );

	register_logevent("EventGameCommencing", 2, "0=World triggered", "1=Game_Commencing") ;

	RegHookSpawn = RegisterHookChain(RG_CBasePlayer_Spawn, "CBasePlayer_Spawn", true);
	RegHookKilled = RegisterHookChain(RG_CBasePlayer_Killed, "CBasePlayer_Killed", true);
	RegHookDeadPlayer = RegisterHookChain(RG_CSGameRules_DeadPlayerWeapons, "CSGameRules_DeadPlayerWeapons", false);

	DisableHookChain(RegHookSpawn);
	DisableHookChain(RegHookKilled);
	DisableHookChain(RegHookDeadPlayer);

	g_fDeafultBuyTime = get_cvar_float("mp_buytime");
	g_iDefaultRespawnTime = get_cvar_num("mp_roundrespawn_time");
	g_iDefaultRoundInfinite = get_cvar_num("mp_round_infinite");
	g_iDefaultFreezeTime = get_cvar_num("mp_freezetime");

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

	EnableHookChain(RegHookSpawn);
	EnableHookChain(RegHookKilled);
	EnableHookChain(RegHookDeadPlayer);

	set_cvar_float("mp_buytime", BUY_TIME);
	set_cvar_num("mp_roundrespawn_time", WARMUP_TIME);
	set_cvar_num("mp_round_infinite", 1);
	set_cvar_num("mp_freezetime", 0);

	g_iCountdown = WARMUP_TIME;
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
	rg_add_account(id, 16000, AS_SET, true);

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
			DisableHookChain(RegHookSpawn);
			DisableHookChain(RegHookKilled);
			DisableHookChain(RegHookDeadPlayer);
			
			set_cvar_float("mp_buytime", g_fDeafultBuyTime);
			set_cvar_num("mp_round_infinite", g_iDefaultRoundInfinite);
			set_cvar_num("mp_roundrespawn_time", g_iDefaultRespawnTime);
			set_cvar_num("mp_freezetime", g_iDefaultFreezeTime);
			set_cvar_num("sv_restart", 1);
			
			set_task( 2.0, "EndHud" );
		}	
		default:
	{
		set_hudmessage(HUD_COLOR_RGB, 0.0, -1.0, 0, 0.0, 1.0, 0.0, 0.0);
		ShowSyncHudMsg(0, g_HudSync, "^t^t^t[Разминка]^n^t^tОсталось %d сек.", g_iCountdown);
	}	
}
}	

public EndHud()
{
	set_hudmessage(HUD_COLOR_RGB, -1.0, 0.3, 0, 0.0, 5.0, 0.0, 0.0);
	ShowSyncHudMsg(0, g_HudSync, "СПАСИБО ЗА РАЗМИНКУ!^nПРИЯТНОЙ ИГРЫ!");
}

stock ShowBar(const id, const iTime)
{
	message_begin(MSG_ONE, g_MsgBarTime, _, id);
	write_short(iTime);
	message_end();
}