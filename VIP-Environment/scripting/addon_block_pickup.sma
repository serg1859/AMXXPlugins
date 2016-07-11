
//■■■■■■■■■■■■■■■■■■■■■■■ CONFIG START ■■■■■■■■■■■■■■■■■■■■■■■//

#define DEFAULT_ACCESS		ACCESS_OTHER

#define MAX_MODEL_LEN		64

new const BLOCK_MODELS[][MAX_MODEL_LEN] = { 
	"models/custom/w_awp.mdl",
	"models/custom/w_deagle.mdl"
}

//■■■■■■■■■■■■■■■■■■■■■■■■ CONFIG END ■■■■■■■■■■■■■■■■■■■■■■■■//

#include <amxmodx>
#include <engine>
#include <vip_environment>

#define IsEntOnGround(%1) 			(entity_get_int(%1, EV_INT_flags) & FL_ONGROUND)

#define SetUserAccess(%1)			g_bHasAccess |= 1<<(%1 & 31)
#define ClearUserAccess(%1)			g_bHasAccess &= ~( 1<<(%1 & 31))
#define CheckAccess(%1)				(g_bHasAccess &  1<<(%1 & 31))

new g_bHasAccess
new Trie:g_tWorldModels

public plugin_init() 
{
	register_plugin("Block Pickup Custom Weapon", "0.0.1", "Vaqtincha")
	register_touch("weaponbox", "player", "OnWeaponboxTouch")
	g_tWorldModels = TrieCreate()

	for(new i = 0; i <sizeof(BLOCK_MODELS); i++)
	{
		TrieSetCell(g_tWorldModels, BLOCK_MODELS[i], i)
	}
}

public ConfigReloaded()
{
	new iPlayers[32], iNum, iPlayerId
	get_players(iPlayers, iNum, "ch")
	for(new i = 0; i < iNum; i++)
	{
		iPlayerId = iPlayers[i] 
		if(GetUserAccess(iPlayerId) & DEFAULT_ACCESS)
		{
			SetUserAccess(iPlayerId)
		}else{
			ClearUserAccess(iPlayerId)
		}
	}
}

public client_putinserver(id)
{
	if(!is_user_hltv(id) && GetUserAccess(id) & DEFAULT_ACCESS)
	{
		SetUserAccess(id)
	}else{
		ClearUserAccess(id)
	}
}

public client_disconnect(id)
{
	ClearUserAccess(id)
}

public OnWeaponboxTouch(wEnt, id)
{
	if(/* !is_user_alive(id) || */ CheckAccess(id) || !IsEntOnGround(wEnt))
	{
		return PLUGIN_CONTINUE
	}

	static szModel[MAX_MODEL_LEN]
	entity_get_string(wEnt, EV_SZ_model, szModel, charsmax(szModel))

	if(TrieKeyExists(g_tWorldModels, szModel))
	{
		// client_print(id, print_center, "Only VIPs!") // print_center flood 100/sec :D
		return PLUGIN_HANDLED
	}
	return PLUGIN_CONTINUE
}

public plugin_end()
{
	if(g_tWorldModels)
	{
		TrieDestroy(g_tWorldModels)
	}
}
