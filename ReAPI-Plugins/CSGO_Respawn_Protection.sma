#include <amxmodx>
#include <reapi>

// How many seconds will protection take effect?
const Float: PROTECTION_TIME = 15.0;

enum { any: TASK_PROTECTION_OFF = 337 }

const KEYS =
(
	IN_ATTACK | IN_ATTACK2 |
	IN_JUMP | IN_DUCK |
	IN_FORWARD | IN_BACK | IN_MOVELEFT | IN_MOVERIGHT
)

new bool: g_bProtected[MAX_CLIENTS + 1];

public plugin_init()
{
	register_plugin("CS:GO Respawn Protection", "0.0.1", "wopox1337");

	RegisterHookChain(RG_CSGameRules_PlayerSpawn, "CSGameRules_PlayerSpawn", .post = true);
	RegisterHookChain(RG_CBasePlayer_PreThink, "CBasePlayer_PostThink", .post = true);
}

public CSGameRules_PlayerSpawn(pPlayer)
	SetProtection(pPlayer);
	
public CBasePlayer_PostThink(pPlayer)
{
	if(g_bProtected[pPlayer])
		if(is_UserPressKeys(pPlayer, KEYS))
			Protection_Toggle(pPlayer, false);
}

public SetProtection(pPlayer)
{	
	Protection_Toggle(pPlayer, true);
	
	remove_task(TASK_PROTECTION_OFF + pPlayer);
	set_task(PROTECTION_TIME, "EndProtection", TASK_PROTECTION_OFF + pPlayer);
}

public EndProtection(TaskID)
{
	new pPlayer = TaskID - TASK_PROTECTION_OFF;

	g_bProtected[pPlayer] = false;
	
	if(is_user_connected(pPlayer))
		Protection_Toggle(pPlayer, false);
}



Protection_Toggle(pPlayer, bool: bEnabled)
{
	if(!bEnabled)
	{
		set_entvar(pPlayer, var_solid, SOLID_BBOX);
		set_entvar(pPlayer, var_takedamage, DAMAGE_AIM);
		rg_set_rendering(pPlayer);
	}
	else
	{
		set_entvar(pPlayer, var_solid, SOLID_NOT);
		set_entvar(pPlayer, var_takedamage, DAMAGE_NO);
		rg_set_rendering(pPlayer, .render = kRenderTransAdd, .amount = 150);
	}
	
	g_bProtected[pPlayer] = bEnabled;
}

stock bool: is_UserPressKeys(pPlayer, keys)
{
	return (get_member(pPlayer, m_afButtonPressed) & keys) ? true : false;
}

// Thanks to Vaqtincha for useful stock
stock rg_set_rendering(index, fx = kRenderFxNone, r = 255, g = 255, b = 255, render = kRenderNormal, amount = 16)
{
    new Float:RenderColor[3];
    RenderColor[0] = float(r);
    RenderColor[1] = float(g);
    RenderColor[2] = float(b);
    
    set_entvar(index, var_renderfx, fx);
    set_entvar(index, var_rendercolor, RenderColor);
    set_entvar(index, var_rendermode, render);
    set_entvar(index, var_renderamt, float(amount));
}