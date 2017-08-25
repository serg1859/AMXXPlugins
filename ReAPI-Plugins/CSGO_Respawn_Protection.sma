
// How many seconds will protection take effect?
const Float: PROTECTION_TIME = 15.0;

// Change solid prop of players
#define ENABLE_SOLID

#include <amxmodx>
#include <reapi>


#if AMXX_VERSION_NUM < 183
	#define client_disconnected 		client_disconnect
#endif

const TASK_PROTECTION_OFF = 1337;

const KEYS =
(
	IN_ATTACK | IN_ATTACK2 |
	IN_JUMP | IN_DUCK |
	IN_FORWARD | IN_BACK | IN_MOVELEFT | IN_MOVERIGHT
)

new bool:g_bProtected[MAX_CLIENTS + 1];

public plugin_init()
{
	register_plugin("CS:GO Respawn Protection", "0.0.2", "wopox1337");

	RegisterHookChain(RG_CSGameRules_PlayerSpawn, "CSGameRules_PlayerSpawn", .post = true);
	RegisterHookChain(RG_CBasePlayer_PostThink, "CBasePlayer_PostThink", .post = true);
}

public client_disconnected(pPlayer) 
{
	if(g_bProtected[pPlayer]) {
		remove_task(TASK_PROTECTION_OFF + pPlayer);
	}
}

public CSGameRules_PlayerSpawn(pPlayer) {
	SetProtection(pPlayer);
}	

public CBasePlayer_PostThink(pPlayer)
{
	if(g_bProtected[pPlayer] && is_UserPressKeys(pPlayer, KEYS)) {
		Protection_Toggle(pPlayer, false);
	}
}

public Task_EndProtection(TaskID)
{
	new pPlayer = TaskID - TASK_PROTECTION_OFF;

	g_bProtected[pPlayer] = false;
	
	if(is_user_connected(pPlayer)) {
		Protection_Toggle(pPlayer, false);
	}
}

SetProtection(pPlayer)
{	
	Protection_Toggle(pPlayer, true);
	
	remove_task(TASK_PROTECTION_OFF + pPlayer);
	set_task(PROTECTION_TIME, "Task_EndProtection", TASK_PROTECTION_OFF + pPlayer);
}

Protection_Toggle(pPlayer, bool:bEnabled)
{
	if(!bEnabled)
	{
#if defined ENABLE_SOLID
		set_entvar(pPlayer, var_solid, SOLID_BBOX);
#endif
		set_entvar(pPlayer, var_takedamage, DAMAGE_AIM);
		rg_set_rendering(pPlayer);
	}
	else
	{
#if defined ENABLE_SOLID
		set_entvar(pPlayer, var_solid, SOLID_NOT);
#endif
		set_entvar(pPlayer, var_takedamage, DAMAGE_NO);
		rg_set_rendering(pPlayer, .render = kRenderTransAdd, .amount = 150.0);
	}
	
	g_bProtected[pPlayer] = bEnabled;
}

stock bool:is_UserPressKeys(pPlayer, keys) {
	return bool:(get_member(pPlayer, m_afButtonPressed) & keys);
}

// Thanks to BAILOPAN for useful stock
stock rg_set_rendering(index, /* fx = kRenderFxNone, */ const Float:flColor[3] = {255.0, 255.0, 255.0}, render = kRenderNormal, const Float:amount = 16.0)
{
	// set_entvar(index, var_renderfx, fx);
	set_entvar(index, var_rendercolor, flColor);
	set_entvar(index, var_rendermode, render);
	set_entvar(index, var_renderamt, amount);
}
