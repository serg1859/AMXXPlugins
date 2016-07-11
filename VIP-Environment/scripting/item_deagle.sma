//	Copyright © 2016 Vaqtincha

//■■■■■■■■■■■■■■■■■■■■■■■ CONFIG START ■■■■■■■■■■■■■■■■■■■■■■■//
/** menu item settings */
#define WEAPON_COST 			1000
new const ITEM_NAME[] = "Item Golden Deagle"
new const ALIAS_CMD[] = "dgl"							// alias buy command

/** other settings */
// #define WEAPON_STRIP								//

/** weapon settings */
// #define WEAPON_AMMO			50				// or default bpammo
#define WEAPON_SPEED			280				//
#define WEAPON_DAMAGE			1.5				// float

/********************* for advanced users! **********************/

new const V_MODEL[] = 	"models/custom/v_deagle.mdl"  // view weapon model
#define P_MODEL 		"models/custom/p_deagle.mdl"  // player weapon model
#define W_MODEL 		"models/custom/w_deagle.mdl"  // world weapon model

// #define V_SHIELD_MODEL	 "models/custom/shield/v_deagle.mdl"// view weapon shield model
// #define P_SHIELD_MODEL	 "models/custom/shield/p_deagle.mdl"// player weapon shield model

#define WEAPON_ID				CSW_DEAGLE

//■■■■■■■■■■■■■■■■■■■■■■■■ CONFIG END ■■■■■■■■■■■■■■■■■■■■■■■■//

#define VERSION "0.0.4"

#include <amxmodx>
#include <fakemeta>
#include <hamsandwich>
#include <vip_environment>

#define IsPlayer(%1)				(1 <= (%1) <= g_iMaxPlayers)

#define SetItemActive(%1)			(g_bActiveItem |=  (1<<(%1 & 31)))
#define ClearItemActive(%1)			(g_bActiveItem &= ~(1<<(%1 & 31)))
#define IsItemActive(%1)			(g_bActiveItem &    1<<(%1 & 31))

new g_iMaxPlayers, g_bActiveItem, g_iViewModel
new g_iCustomWeaponId

#if defined P_MODEL
new g_iWeaponModel
#endif
#if defined V_SHIELD_MODEL
new g_iViewModelShield
#endif
#if defined P_SHIELD_MODEL
new g_iWeaponModelShield
#endif
#if defined WEAPON_SPEED
new HamHook:g_hResetSpeed
#endif

public plugin_precache()
{
	PrecacheModel(V_MODEL)
	g_iViewModel = AllocString(V_MODEL)
#if defined P_MODEL
	PrecacheModel(P_MODEL)
	g_iWeaponModel = AllocString(P_MODEL)
#endif
#if defined V_SHIELD_MODEL
	PrecacheModel(V_SHIELD_MODEL)
	g_iViewModelShield = AllocString(V_SHIELD_MODEL)
#endif
#if defined P_SHIELD_MODEL
	PrecacheModel(P_SHIELD_MODEL)
	g_iWeaponModelShield = AllocString(P_SHIELD_MODEL)
#endif
#if defined W_MODEL
	PrecacheModel(W_MODEL)
#endif
}

public plugin_init()
{
	register_plugin(ITEM_NAME, VERSION, "Vaqtincha")
	if(!vip_environment_loaded() || !IsAllowedMap())
	{
		pause("ad")
		return
	}

	RegisterCustomItem(ITEM_NAME[5], ALIAS_CMD, "BuyCustomWeapon", WEAPON_COST, TEAM_ALL)
	g_iCustomWeaponId = random_num(START_IMPULSE, FINITE_IMPULSE)
	
#if defined WEAPON_DAMAGE
	RegisterHam(Ham_TakeDamage, "player", "TakeDamage_Pre", false)
#endif
#if defined WEAPON_SPEED
	DisableHamForward(g_hResetSpeed = RegisterHam(Ham_CS_Player_ResetMaxSpeed, "player", "ResetMaxSpeed_Pre", false))
#endif
	RegisterHam(Ham_Item_Deploy, g_szWeaponName[WEAPON_ID], "ItemDeploy_Post", true)
#if defined WEAPON_SPEED || defined WEAPON_DAMAGE
	RegisterHam(Ham_Item_Holster, g_szWeaponName[WEAPON_ID], "ItemHolster_Post", true)
#endif
#if defined P_SHIELD_MODEL
	RegisterHam(Ham_Weapon_SecondaryAttack, g_szWeaponName[WEAPON_ID], "WeaponSecondaryAttack_Post", true)
#endif
	g_iMaxPlayers = get_maxplayers()
}

public BuyCustomWeapon(id)
{
	if(UserHasCustomWeapon(id, WEAPON_ID, g_iCustomWeaponId))
	{
		client_print(id, print_center, "#Cstrike_Already_Own_Weapon")
		return PLUGIN_HANDLED
	}

	DoDropWeapon(id, WEAPON_ID)
#if defined WEAPON_AMMO
	GiveCustomWeapon(id, WEAPON_ID, g_iCustomWeaponId, WEAPON_AMMO)
#else
	GiveCustomWeapon(id, WEAPON_ID, g_iCustomWeaponId, g_iMaxBPAmmo[WEAPON_ID])
#endif

	return BUY_SUCCESS
}

public ItemDeploy_Post(wEnt)
{
	if(wEnt <=0 || GetCustomWeapon(wEnt) != g_iCustomWeaponId)
	{
		return HAM_IGNORED
	}

	new id = get_weapon_owner(wEnt)
	if(IsPlayer(id))
	{
		if(has_user_shield(id))
		{
		#if defined V_SHIELD_MODEL
			set_pev(id, pev_viewmodel, g_iViewModelShield)
		#endif
		#if defined P_SHIELD_MODEL
			set_pev(id, pev_weaponmodel, g_iWeaponModelShield)
		#endif
		}else{
			set_pev(id, pev_viewmodel, g_iViewModel)
		#if defined P_MODEL
			set_pev(id, pev_weaponmodel, g_iWeaponModel)
		#endif
		}
	#if defined WEAPON_SPEED
		EnableHamForward(g_hResetSpeed)
	#endif
		SetItemActive(id)
	}
	return HAM_IGNORED
}

public ItemHolster_Post(wEnt)
{
	if(wEnt <=0 || GetCustomWeapon(wEnt) != g_iCustomWeaponId)
	{
		return HAM_IGNORED
	}

	ClearItemActive(get_weapon_owner(wEnt))
#if defined WEAPON_SPEED 
	DisableHamForward(g_hResetSpeed)
#endif
	return HAM_IGNORED
}
#if defined WEAPON_SPEED
public ResetMaxSpeed_Pre(id)
{
	if(IsItemActive(id))
	{
		set_pev(id, pev_maxspeed, WEAPON_SPEED.0)
		return HAM_SUPERCEDE
	}
	return HAM_IGNORED
}
#endif
#if defined P_SHIELD_MODEL
public WeaponSecondaryAttack_Post(wEnt)
{
	if(wEnt <=0 || g_iWeaponSlots[WEAPON_ID] != 2 || GetCustomWeapon(wEnt) != g_iCustomWeaponId)
	{
		return HAM_IGNORED
	}

	new id = get_weapon_owner(wEnt)
	if(IsPlayer(id) && has_user_shield(id))
	{
		set_pev(id, pev_weaponmodel, g_iWeaponModelShield)
	}
	return HAM_IGNORED
}
#endif
#if defined W_MODEL
public SetWeaponWorldModel(iEnt, wEnt, iImpulse, iOwner, const szModel[])
{
	if(equal(szModel[7], g_szWorldModel[WEAPON_ID]) && iImpulse == g_iCustomWeaponId)
	{
		SetModel(iEnt, W_MODEL)
		return FMRES_SUPERCEDE
	}
	return FMRES_IGNORED
}
#endif
#if defined WEAPON_DAMAGE
public TakeDamage_Pre(Victim, Inflictor, Attacker, Float:flDamage, DamageBits)
{
	if(!IsPlayer(Attacker) || ~DamageBits & DMG_BULLET)
	{
		return HAM_IGNORED
	}
	if(Attacker == Inflictor && IsItemActive(Attacker))
	{
		SetHamParamFloat(4, flDamage * WEAPON_DAMAGE)
		return HAM_HANDLED
	}
	return HAM_IGNORED
}
#endif

