// Original idea came from Safety1st

#include <amxmodx>
#include <reapi>
#include <re_warmup_api>

new HookChain:g_hAddAccount
 
public plugin_init()
{
	register_plugin("[ReApi] Money as Frag Counter", "0.0.1", "Vaqtincha")
	DisableHookChain(g_hAddAccount = RegisterHookChain(RG_CBasePlayer_AddAccount, "CBasePlayer_AddAccount", .post = false))
}

public plugin_pause()
	WarmupEnded()

public WarmupStarted(WarmupModes:iMode, iTime)
{
	if(iMode != FREE_BUY)
	{
		EnableHookChain(g_hAddAccount)
	}
}

public WarmupEnded()
{
	if(g_hAddAccount)
		DisableHookChain(g_hAddAccount)
}

public CBasePlayer_AddAccount(const intex, amount, RewardType:type, bool:bTrackChange)
{
	// server_print("amount: %d | type %d", amount, type)

	if(type == RT_ENEMY_KILLED)
	{
		SetHookChainArg(2, ATYPE_INTEGER, 1) // +1
	}else{
		SetHookChainArg(2, ATYPE_INTEGER, get_user_frags(intex))
		SetHookChainArg(4, ATYPE_INTEGER, false)
	}

	return HC_CONTINUE
}


	



