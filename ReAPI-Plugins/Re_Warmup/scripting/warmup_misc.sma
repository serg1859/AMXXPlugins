// Copyright © 2016 Vaqtincha

/**■■■■■■■■■■■■■■■■■■■■■■■■■■■■ CONFIG START ■■■■■■■■■■■■■■■■■■■■■■■■■■■■*/

#define MONEY_FRAG_COUNTER					// Original idea by Safety1st
#define FAST_SWITCH_DELAY		0.75		// Original idea by Numb
#define SILENCED_REMEMBER

/**■■■■■■■■■■■■■■■■■■■■■■■■■■■■■ CONFIG END ■■■■■■■■■■■■■■■■■■■■■■■■■■■■■*/

#include <amxmodx>
#include <hamsandwich>
#include <reapi>
#include <re_warmup_api>

#if defined MONEY_FRAG_COUNTER
	new HookChain:g_hAddAccount
#endif
#if defined FAST_SWITCH_DELAY
	new HamHook:g_hDeploy[2]
#endif

#if defined SILENCED_REMEMBER
new HamHook:g_hSecondaryAttack[2], HamHook:g_hAddToPlayer[2]
new WeaponState:g_bWeaponState[MAX_CLIENTS + 1]
#endif

public plugin_pause()
	WarmupEnded()

public plugin_init()
{
	register_plugin("[ReApi] Warmup Misc", "0.0.1", "Vaqtincha")
#if defined FAST_SWITCH_DELAY	
	DisableHamForward(g_hDeploy[0] = RegisterHam(Ham_Item_Deploy, "weapon_awp", "ItemDeploy_Post", .Post = true))
	DisableHamForward(g_hDeploy[1] = RegisterHam(Ham_Item_Deploy, "weapon_scout", "ItemDeploy_Post", .Post = true))
#endif
#if defined SILENCED_REMEMBER
	DisableHamForward(g_hAddToPlayer[0] = RegisterHam(Ham_Item_AddToPlayer, "weapon_m4a1", "ItemAddToPlayer", .Post = true))
	DisableHamForward(g_hAddToPlayer[1] = RegisterHam(Ham_Item_AddToPlayer, "weapon_usp", "ItemAddToPlayer", .Post = true))
	DisableHamForward(g_hSecondaryAttack[0] = RegisterHam(Ham_Weapon_SecondaryAttack, "weapon_m4a1", "ItemSecondaryAttack_Post", .Post = true))
	DisableHamForward(g_hSecondaryAttack[1] = RegisterHam(Ham_Weapon_SecondaryAttack, "weapon_usp", "ItemSecondaryAttack_Post", .Post = true))
#endif
#if defined MONEY_FRAG_COUNTER
	DisableHookChain(g_hAddAccount = RegisterHookChain(RG_CBasePlayer_AddAccount, "CBasePlayer_AddAccount", .post = false))
#endif
}

public WarmupStarted(WarmupModes:iMode, iTime)
{
#if defined MONEY_FRAG_COUNTER	
	if(iMode != FREE_BUY)
	{
		EnableHookChain(g_hAddAccount)
	}
#endif

	if(iMode != ONLY_KNIFE)
	{	
#if defined FAST_SWITCH_DELAY
		EnableHamForward(g_hDeploy[0])
		EnableHamForward(g_hDeploy[1])
#endif
#if defined SILENCED_REMEMBER	
		EnableHamForward(g_hAddToPlayer[0])
		EnableHamForward(g_hAddToPlayer[1])
		EnableHamForward(g_hSecondaryAttack[0])
		EnableHamForward(g_hSecondaryAttack[1])
#endif
	}
}

public WarmupEnded()
{
#if defined MONEY_FRAG_COUNTER
	if(g_hAddAccount)
		DisableHookChain(g_hAddAccount)
#endif
#if defined FAST_SWITCH_DELAY
	if(g_hDeploy[0])
		DisableHamForward(g_hDeploy[0])
	if(g_hDeploy[1])
		DisableHamForward(g_hDeploy[1])
#endif
#if defined SILENCED_REMEMBER
	if(g_hAddToPlayer[0])
		DisableHamForward(g_hAddToPlayer[0])
	if(g_hAddToPlayer[1])
		DisableHamForward(g_hAddToPlayer[1])
	if(g_hSecondaryAttack[0])
		DisableHamForward(g_hSecondaryAttack[0])	
	if(g_hSecondaryAttack[1])
		DisableHamForward(g_hSecondaryAttack[1])
#endif
}

#if defined MONEY_FRAG_COUNTER
public CBasePlayer_AddAccount(const intex, amount, RewardType:type, bool:bTrackChange)
{
	// server_print("amount: %d | type %d", amount, type)

	if(type == RT_ENEMY_KILLED)
	{
		SetHookChainArg(2, ATYPE_INTEGER, 1) // +1
		return HC_OVERRIDE
	}else{
		SetHookChainArg(2, ATYPE_INTEGER, get_user_frags(intex))
		SetHookChainArg(4, ATYPE_INTEGER, false)
		return HC_OVERRIDE
	}

	return HC_CONTINUE
}
#endif
#if defined SILENCED_REMEMBER
public ItemAddToPlayer(wEnt, id)
{
	if(wEnt > 0 && is_user_alive(id))
	{
		set_member(wEnt, m_Weapon_iWeaponState, g_bWeaponState[id])
	}
}

public ItemSecondaryAttack_Post(wEnt)
{
	if(wEnt <= 0)
		return HAM_IGNORED

	new id = get_member(wEnt, m_pPlayer)
	if(id > 0 /* && is_user_alive(id) */)
	{
		new WeaponState:wState = get_member(wEnt, m_Weapon_iWeaponState)
		switch(get_member(wEnt, m_iId))
		{
			case WEAPON_M4A1: ~wState & WPNSTATE_M4A1_SILENCED ? (g_bWeaponState[id] &= ~WPNSTATE_M4A1_SILENCED) : (g_bWeaponState[id] |= WPNSTATE_M4A1_SILENCED)
			case WEAPON_USP: ~wState & WPNSTATE_USP_SILENCED ? (g_bWeaponState[id] &= ~WPNSTATE_USP_SILENCED) : (g_bWeaponState[id] |= WPNSTATE_USP_SILENCED)
			default: return HAM_IGNORED
		}
	}
	return HAM_IGNORED
}
#endif
#if defined FAST_SWITCH_DELAY
public ItemDeploy_Post(wEnt)
{
	if(wEnt <= 0)
		return HAM_IGNORED

	new id = get_member(wEnt, m_pPlayer)
	if(is_user_alive(id))
	{
		set_member(wEnt, m_Weapon_flNextPrimaryAttack, FAST_SWITCH_DELAY)
		set_member(wEnt, m_Weapon_flNextSecondaryAttack, FAST_SWITCH_DELAY)
		set_member(id, m_flNextAttack, FAST_SWITCH_DELAY)
	}

	return HAM_IGNORED
}
#endif


