//	Copyright © 2016 Vaqtincha

//■■■■■■■■■■■■■■■■■■■■■■■ CONFIG START ■■■■■■■■■■■■■■■■■■■■■■■//
/** menu item settings */
#define WEAPON_COST_TT 			1400
#define WEAPON_COST_CT 			1000
new const ALIAS_CMD_TT[] = "brev"
new const ALIAS_CMD_CT[] = "srev"

/** other settings */
// #define WEAPON_STRIP							//

/** weapon settings */
#define WEAPON_SPEED_TT			265		// weapon tt
#define WEAPON_SPEED_CT			290		// weapon ct
#define WEAPON_DAMAGE_TT		1.4		// weapon tt
#define WEAPON_DAMAGE_CT		1.2		// weapon ct

/********************* for advanced users! **********************/

new const V_MODEL_TT[] = "models/custom/v_revolver_tt.mdl"  // view weapon model
new const P_MODEL_TT[] = "models/custom/p_revolver_tt.mdl"  // player weapon model
new const W_MODEL_TT[] = "models/custom/w_revolver_tt.mdl"  // world weapon model

new const V_MODEL_CT[] = "models/custom/v_revolver_ct.mdl"  // view weapon model
new const P_MODEL_CT[] = "models/custom/p_revolver_ct.mdl"  // player weapon model
new const W_MODEL_CT[] = "models/custom/w_revolver_ct.mdl"  // world weapon model

#define WEAPON_ID				CSW_DEAGLE

//■■■■■■■■■■■■■■■■■■■■■■■■ CONFIG END ■■■■■■■■■■■■■■■■■■■■■■■■//

#define VERSION "0.0.4"

#include <amxmodx>
#include <fakemeta>
#include <hamsandwich>
#include <vip_environment>

#define IsPlayer(%1)				(1 <= (%1) <= g_iMaxPlayers)

new g_iMaxPlayers, g_iCustomWeaponIdtt, g_iCustomWeaponIdct
new g_iItemActive[MAX_PLAYERS+1]
new g_iWeaponModeltt, g_iViewModeltt, g_iWeaponModelct, g_iViewModelct
new HamHook:g_hResetSpeed


public plugin_precache()
{
	PrecacheModel(V_MODEL_TT)
	PrecacheModel(V_MODEL_CT)
	PrecacheModel(P_MODEL_TT)
	PrecacheModel(P_MODEL_CT)
	PrecacheModel(W_MODEL_TT)
	PrecacheModel(W_MODEL_CT)
	precache_sound("weapons/custom/draw.wav")
	precache_sound("weapons/custom/reload.wav")

	g_iViewModeltt = AllocString(V_MODEL_TT)
	g_iViewModelct = AllocString(V_MODEL_CT)
	g_iWeaponModeltt = AllocString(P_MODEL_TT)
	g_iWeaponModelct = AllocString(P_MODEL_CT)
}

public plugin_init()
{
	register_plugin("Item Team Revolver", VERSION, "Vaqtincha")
	if(!vip_environment_loaded() || !IsAllowedMap())
	{
		pause("ad")
		return
	}

	RegisterCustomItem("Black Revolver", ALIAS_CMD_TT, "BuyCustomWeaponTT", WEAPON_COST_TT, TEAM_TT)
	RegisterCustomItem("Silver Revolver", ALIAS_CMD_CT, "BuyCustomWeaponCT", WEAPON_COST_CT, TEAM_CT)

	new iRand = random_num(START_IMPULSE, FINITE_IMPULSE)
	g_iCustomWeaponIdtt = iRand
	g_iCustomWeaponIdct = iRand + 1

	RegisterHam(Ham_TakeDamage, "player", "TakeDamage_Pre", false)
	DisableHamForward(g_hResetSpeed = RegisterHam(Ham_CS_Player_ResetMaxSpeed, "player", "ResetMaxSpeed_Pre", false))
	RegisterHam(Ham_Item_Deploy, g_szWeaponName[WEAPON_ID], "ItemDeploy_Post", true)
	RegisterHam(Ham_Item_Holster, g_szWeaponName[WEAPON_ID], "ItemHolster_Post", true)

	g_iMaxPlayers = get_maxplayers()
}

public BuyCustomWeaponTT(id)
{
	if(UserHasCustomWeapon(id, WEAPON_ID, g_iCustomWeaponIdtt))
	{
		client_print(id, print_center, "#Cstrike_Already_Own_Weapon")
		return PLUGIN_HANDLED
	}

	DoDropWeapon(id, WEAPON_ID)
	GiveCustomWeapon(id, WEAPON_ID, g_iCustomWeaponIdtt, g_iMaxBPAmmo[WEAPON_ID])

	return BUY_SUCCESS
}

public BuyCustomWeaponCT(id)
{
	if(UserHasCustomWeapon(id, WEAPON_ID, g_iCustomWeaponIdct))
	{
		client_print(id, print_center, "#Cstrike_Already_Own_Weapon")
		return PLUGIN_HANDLED
	}

	DoDropWeapon(id, WEAPON_ID)
	GiveCustomWeapon(id, WEAPON_ID, g_iCustomWeaponIdct, g_iMaxBPAmmo[WEAPON_ID])

	return BUY_SUCCESS
}

public ItemDeploy_Post(wEnt)
{
	if(wEnt <=0)
	{
		return HAM_IGNORED
	}
	new id = get_weapon_owner(wEnt)
	if(IsPlayer(id))
	{
		new iImpulse = GetCustomWeapon(wEnt)
		if(iImpulse == g_iCustomWeaponIdtt)
		{
			set_pev(id, pev_viewmodel, g_iViewModeltt)
			set_pev(id, pev_weaponmodel, g_iWeaponModeltt)
			EnableHamForward(g_hResetSpeed)
			g_iItemActive[id] = g_iCustomWeaponIdtt
		}
		else if(iImpulse == g_iCustomWeaponIdct)
		{
			set_pev(id, pev_viewmodel, g_iViewModelct)
			set_pev(id, pev_weaponmodel, g_iWeaponModelct)
			EnableHamForward(g_hResetSpeed)
			g_iItemActive[id] = g_iCustomWeaponIdct
		}
		return HAM_IGNORED
	}
	return HAM_IGNORED
}

public ItemHolster_Post(wEnt)
{
	if(wEnt > 0 && g_iCustomWeaponIdtt <= GetCustomWeapon(wEnt) <= g_iCustomWeaponIdct)
	{
		g_iItemActive[get_weapon_owner(wEnt)] = 0
		DisableHamForward(g_hResetSpeed)
	}
	return HAM_IGNORED
}

public ResetMaxSpeed_Pre(id)
{
	if(g_iItemActive[id] == g_iCustomWeaponIdtt)
	{
		set_pev(id, pev_maxspeed, WEAPON_SPEED_TT.0)
		return HAM_SUPERCEDE
	}
	else if(g_iItemActive[id] == g_iCustomWeaponIdct)
	{
		set_pev(id, pev_maxspeed, WEAPON_SPEED_CT.0)
		return HAM_SUPERCEDE
	}
	return HAM_IGNORED
}

public SetWeaponWorldModel(iEnt, wEnt, iImpulse, iOwner, const szModel[])
{
	if(equal(szModel[7], g_szWorldModel[WEAPON_ID]))
	{
		if(iImpulse == g_iCustomWeaponIdtt)
		{
			SetModel(iEnt, W_MODEL_TT)
			return FMRES_SUPERCEDE
		}
		else if(iImpulse == g_iCustomWeaponIdct)
		{
			SetModel(iEnt, W_MODEL_CT)
			return FMRES_SUPERCEDE
		}
	}
	return FMRES_IGNORED
}

public TakeDamage_Pre(Victim, Inflictor, Attacker, Float:flDamage, DamageBits)
{
	if(!IsPlayer(Attacker) || ~DamageBits & DMG_BULLET || Attacker != Inflictor)
	{
		return HAM_IGNORED
	}

	if(g_iItemActive[Attacker] == g_iCustomWeaponIdtt)
	{
		SetHamParamFloat(4, flDamage * WEAPON_DAMAGE_TT)
		return HAM_HANDLED
	}
	else if(g_iItemActive[Attacker] == g_iCustomWeaponIdct)
	{
		SetHamParamFloat(4, flDamage * WEAPON_DAMAGE_CT)
		return HAM_HANDLED
	}

	return HAM_IGNORED
}

