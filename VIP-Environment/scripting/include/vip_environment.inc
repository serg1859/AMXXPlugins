/** Copyright © 2016 Vaqtincha
 *
 * V.I.P Environment include file.
 *
 * Support forum:
 *		http://goldsrc.ru
 *
*/

#if defined _vip_environment_included
  #endinput
#endif
#define _vip_environment_included

#if AMXX_VERSION_NUM >= 175
	#pragma reqlib vip_environment
	#if !defined AMXMODX_NOAUTOLOAD
		#pragma loadlib vip_environment
	#endif
#else
	#pragma library vip_environment
#endif

#define PLUGIN_NAME "V.I.P Environment"


enum /* Teams */
{
	TEAM_TT = 1,	/* Terrorists */
	TEAM_CT,		/* Counter-terrorists */
	TEAM_ALL		/* All teams (Counter-terrorists & Terrorists) */
}

enum /* Counter Types */{
	COUNTER_ROUND = 1,
	COUNTER_SPAWN,
	COUNTER_FRAG
}

enum /* Reset Types */{
	RESET_RESTART = 1,
	RESET_ROUND,
	RESET_DEATH,
	RESET_SPAWN,
	RESET_TIME
}

#define BUY_SUCCESS		3
#define FREE_ITEM		0

#define ACCESS_SPAWN_ITEMS 	(1<<0)
#define ACCESS_WEAPON_MENU	(1<<1)
#define ACCESS_BUY_MENU		(1<<2)
#define ACCESS_OTHER		(1<<3)
#define ACCESS_ALL			(ACCESS_SPAWN_ITEMS|ACCESS_WEAPON_MENU|ACCESS_BUY_MENU|ACCESS_OTHER)


/**
 * Add item to menu.
 *
 * @param szName		Item text to display.
 * @param szCmd			Buy alias command. (optional)
 * @param szHandler		Name of the handler function.
 * @param iCost			Item cost.
 * @param iTeam			Team required by the player viewing the item.
 *
 * @return				Index of this item. 
 *
 * @note				Max item name length is 32.
 * @note				Max alias command length is 16.
 * @note				Max handler function name length is 64.
 */
native RegisterCustomItem(const szName[], const szCmd[]="", const szHandler[], iCost=FREE_ITEM, iTeam=TEAM_ALL)


/** Return true is allowed map (included in section [maps])*/
native bool:IsAllowedMap()

/** Returns current round count */
native GetCurrentRound()

/** Returns "Counter Types" */
native GetCounterType()

/** 
 * Returns user flags
 *
 * @param id			Player id 
 */
native GetUserAccess(id)

/** 
 * Returns user spawns count
 *
 * @param id			Player id 
 */
native GetUserSpawns(id)

/** 
 * Player spawned
 *
 * @param id			Player id
 */
forward UserPostSpawn(id)

/** 
 * Player killed pre
 *
 * @param iVictim		Victim id
 * @param iKiller		Killer id
 * @param iHitplace		Last hitgroup
 *
 * @note				iKiller == 0 (or  !iKiller) if player was killed by world
 */
forward UserPreKilled(iVictim, iKiller, iHitplace, iTeamKill)


/** 
 * Reloaded config file
 *
 */
forward ConfigReloaded()

/** 
 * Set Weapon World Model
 * 
 * @param iEnt				iEntity
 * @param wEnt				Weapon Entity id
 * @param iImpulse			Weapon Impulse
 * @param iOwner			Player id
 * @param szModel			Weapon World Model
 * 
 * @return					FMRES_SUPERCEDE set new model
 */
forward SetWeaponWorldModel(iEnt, wEnt, iImpulse, iOwner, const szModel[])



// ========================== Helper ===========================

#if !defined MAX_PLAYERS
	const MAX_PLAYERS = 32
#endif
const MAPZONE_BUYZONE = 1<<0
const CSW_SHIELD = 2
const PDATA_SAFE = 2
const MAX_ITEM_TYPES = 6	// hud item selection slots

const START_IMPULSE = 333
const FINITE_IMPULSE = 99999

// offsets
const m_iId = 43
const m_iClip = 51
const m_pNext = 42
const m_pPlayer = 41
const m_pActiveItem = 373
const m_flDefuseCountDown = 99
const m_flNextPrimaryAttack = 46
const m_fHasSurvivedLastRound = 113
const m_flNextSecondaryAttack = 47
const m_flNextAttack = 83
const m_iTeam = 114
const m_iMenu = 205
const m_fClientMapZone = 235
const m_iAccount = 115
const g_ulModelIndexPlayer = 491
const m_LastHitGroup = 75
const XO_WEAPON = 4
stock const m_rgpPlayerItems_CBasePlayer[MAX_ITEM_TYPES] = {367, 368, ...}
stock const m_rgpPlayerItems_CWeaponBox[MAX_ITEM_TYPES] = {34, 35, ...}

#if AMXX_VERSION_NUM < 183
	const m_bHasShield = 1<<24
	const m_bHasDefuser = 1<<16
	const m_iUserPrefs = 510
	const m_bools = 193
	#define UserPrefs(%1)				get_pdata_int(%1, m_iUserPrefs)
	#define has_user_shield(%1)			(UserPrefs(%1) & m_bHasShield)
	stock set_user_shield(id, bool:bActive)
		set_pdata_int(id, m_iUserPrefs, bActive ? UserPrefs(id) |m_bHasShield : UserPrefs(id) & ~m_bHasShield)
	#define has_user_defuser(%1)		(get_pdata_int(%1, m_bools) & m_bHasDefuser)
#else
	const m_bHasShield = 2043
	const m_bHasDefuser = 774
	#define has_user_shield(%1)			get_pdata_bool(%1, m_bHasShield)
	#define set_user_shield(%1,%2)		set_pdata_bool(%1, m_bHasShield, %2)
	#define has_user_defuser(%1)		get_pdata_bool(%1, m_bHasDefuser)
#endif

#define get_weapon_owner(%1)			get_pdata_cbase(%1, m_pPlayer, XO_WEAPON)
#define get_user_last_hitgroup(%1)		get_pdata_int(%1, m_LastHitGroup)
#define cs_get_user_money(%1)			get_pdata_int(%1, m_iAccount)
#define cs_get_user_buyzone(%1)			(get_pdata_int(%1, m_fClientMapZone) & MAPZONE_BUYZONE)
#define cs_get_user_team(%1)			get_pdata_int(%1, m_iTeam)
#define cs_get_weapon_id(%1)			get_pdata_int(%1, m_iId, XO_WEAPON)
#define cs_get_user_hasprim(%1) 		(get_pdata_cbase(%1, m_rgpPlayerItems_CBasePlayer[1]) > 0)
#define cs_get_user_menu(%1) 			get_pdata_int(%1, m_iMenu)
#define cs_set_user_menu(%1,%2)			set_pdata_int(%1, m_iMenu, %2)
#define cs_set_weapon_ammo(%1,%2)		set_pdata_int(%1, m_iClip, %2, XO_WEAPON)
#define AllocString(%1) 				engfunc(EngFunc_AllocString,%1)
#define SetModel(%1,%2) 				engfunc(EngFunc_SetModel,%1,%2)
#define GetCustomWeapon(%1) 			pev(%1, pev_impulse)


/**	by PRoSToTeM@ - method to hook Ham_CS_Player_ResetMaxSpeed on AMXX below 1.8.3-dev */

#if !defined Ham_CS_Player_ResetMaxSpeed
	#define Ham_CS_Player_ResetMaxSpeed Ham_Item_PreFrame
#endif

const PRIMARY_WEAPONS_BIT_SUM = 1<<CSW_SHIELD|1<<CSW_SCOUT|1<<CSW_XM1014|1<<CSW_MAC10|1<<CSW_AUG|1<<CSW_UMP45
	|1<<CSW_SG550|1<<CSW_GALIL|1<<CSW_FAMAS|1<<CSW_AWP|1<<CSW_MP5NAVY|1<<CSW_M249|1<<CSW_M3
	|1<<CSW_M4A1|1<<CSW_TMP|1<<CSW_G3SG1|1<<CSW_SG552|1<<CSW_AK47|1<<CSW_P90
const SECONDARY_WEAPONS_BIT_SUM = 1<<CSW_P228|1<<CSW_ELITE|1<<CSW_FIVESEVEN|1<<CSW_USP|1<<CSW_GLOCK18|1<<CSW_DEAGLE
const EXCP_WEAPONS_BIT_SUM = 1<<CSW_HEGRENADE|1<<CSW_SMOKEGRENADE|1<<CSW_FLASHBANG|1<<CSW_KNIFE|1<<CSW_C4

stock const g_iWeaponSlots[CSW_P90+1] = { 
	-1, 2, -1, 1, 4, 1, 5, 1, 1, 4, 2, 2, 1, 1, 1,
	1, 2, 2, 1, 1, 1, 1, 1, 1, 1, 4, 2, 1, 1, 3, 1 
}

stock const g_iMaxClip[CSW_P90+1] = { 
	-1, 13, -1, 10, 1, 7, 1, 30, 30, 1, 30, 20, 25, 30, 35, 25, 
	12, 20, 10, 30, 100, 8, 30, 30, 20, 2, 7, 30, 30, -1, 50
}

stock const g_iMaxBPAmmo[CSW_P90+1] = { 
	-1, 52, -1, 90, 1, 32, 1, 100, 90, 1, 120, 100, 100, 90, 90, 90,
	100, 120, 30, 120, 200, 32, 90, 120, 90, 2, 35, 90, 90, -1, 100
}

stock const g_szAmmoType[CSW_P90+1][] = {
	"","357sig","","762nato","HEGrenade","buckshot","C4","45acp","556nato","SmokeGrenade","9mm", 
	"57mm","45acp","556nato","556nato","556nato","45acp","9mm","338magnum","9mm","556natobox",
	"buckshot","556nato","9mm","762nato","Flashbang","50ae","556nato","762nato","","57mm"
}

stock const g_szWeaponName[CSW_P90+1][] = {
	"","weapon_p228","weapon_shield","weapon_scout","weapon_hegrenade","weapon_xm1014","weapon_c4",
	"weapon_mac10","weapon_aug","weapon_smokegrenade","weapon_elite","weapon_fiveseven","weapon_ump45",
	"weapon_sg550","weapon_galil","weapon_famas","weapon_usp","weapon_glock18","weapon_awp",
	"weapon_mp5navy","weapon_m249","weapon_m3","weapon_m4a1","weapon_tmp","weapon_g3sg1",
	"weapon_flashbang","weapon_deagle","weapon_sg552","weapon_ak47","weapon_knife","weapon_p90"
}

stock const g_szWorldModel[CSW_P90+1][] = {
	"","w_p228.mdl","","w_scout.mdl","w_hegrenade.mdl","w_xm1014.mdl","","w_mac10.mdl","w_aug.mdl",
	"w_smokegrenade.mdl","w_elite.mdl","w_fiveseven.mdl","w_ump45.mdl","w_sg550.mdl","w_galil.mdl",
	"w_famas.mdl","w_usp.mdl","w_glock18.mdl","w_awp.mdl","w_mp5.mdl","w_m249.mdl","w_m3.mdl","w_m4a1.mdl",
	"w_tmp.mdl","w_g3sg1.mdl","w_flashbang.mdl","w_deagle.mdl","w_sg552.mdl","w_ak47.mdl","","w_p90.mdl"
}

stock bool:vip_environment_loaded()
{
	return bool:(is_plugin_loaded(PLUGIN_NAME) > 0)
}

stock PrecacheModel(const szModel[])
{
	new szMsg[128]
	if(!file_exists(szModel))
	{
		formatex(szMsg, charsmax(szMsg), "[V.I.P] ERROR: Model ^"%s^" not found!", szModel)
		set_fail_state(szMsg)
		return 0
	}

	return precache_model(szModel)
}

stock client_print_center(id, const szMsg[], const szSubMsg[]="") 
{
	static iMsgIdTextMsg
	if(!iMsgIdTextMsg)
	{
		iMsgIdTextMsg = get_user_msgid("TextMsg")
	}
	message_begin(MSG_ONE_UNRELIABLE, iMsgIdTextMsg, .player = id)
	write_byte(print_center)
	write_string(szMsg)
	write_string(szSubMsg)
	message_end()
}

stock cs_set_user_money(id, iMoney, iFlash = 1)
{
	set_pdata_int(id, m_iAccount, iMoney)
	static iMsgIdMoney
	if(!iMsgIdMoney)
	{
		iMsgIdMoney = get_user_msgid("Money")
	}
	message_begin(MSG_ONE, iMsgIdMoney, .player = id)
	write_long(iMoney)
	write_byte(iFlash ? 1 : 0)
	message_end()
}

stock bool:IsBombDefuseMap()
{
	return bool:(engfunc(EngFunc_FindEntityByString, FM_NULLENT, "classname", "func_bomb_target")
	|| engfunc(EngFunc_FindEntityByString, FM_NULLENT, "classname", "info_bomb_target"))
}

stock bool:UserHasCustomWeapon(id, iId, iImpulse)
{
	new wEnt = get_pdata_cbase(id, m_rgpPlayerItems_CBasePlayer[g_iWeaponSlots[iId]])
	return bool:(wEnt > 0 && GetCustomWeapon(wEnt) == iImpulse)
}

stock DoDropWeapon(id, iId)
{
	new bool:bShield = bool:has_user_shield(id)
	if(1<<iId & SECONDARY_WEAPONS_BIT_SUM)
	{
		if(bShield)
		{
			set_user_shield(id, false)
			DropWeapon(id, SECONDARY_WEAPONS_BIT_SUM)
			set_user_shield(id, true)

			new iActiveItem = get_pdata_cbase(id, m_pActiveItem)
			if(iActiveItem > 0)
			{
				ExecuteHamB(Ham_Item_Deploy, iActiveItem)
			}
		}else{
			DropWeapon(id, SECONDARY_WEAPONS_BIT_SUM)
		}
		return 1
	}
	else if(1<<iId & PRIMARY_WEAPONS_BIT_SUM)
	{
		DropWeapon(id, PRIMARY_WEAPONS_BIT_SUM, bool:bShield)
		return 1
	}
	return 0
}

stock DropWeapon(id, WeaponsBitsum, bool:bDropShield = false)
{
	new iWeapons[32], iNum, iId, i
	get_user_weapons(id, iWeapons, iNum)

	for(i = 0; i < iNum; i++)
	{
		iId = bDropShield ? CSW_SHIELD : iWeapons[i]

		if(!(EXCP_WEAPONS_BIT_SUM & 1<<iId) && 1<<iId & WeaponsBitsum)
		{
		#if defined WEAPON_STRIP
			ham_strip_user_weapon(id, iId)
		#else
			engclient_cmd(id, "drop", g_szWeaponName[iId])
		#endif
		}
	}
}

stock GiveCustomWeapon(id, iId, iImpulse, iBpAmmo = 0, bool:bSound = true)
{
	new wEnt = engfunc(EngFunc_CreateNamedEntity, engfunc(EngFunc_AllocString, g_szWeaponName[iId]))
	if(wEnt > 0 && pev_valid(wEnt))
	{
		set_pev(wEnt, pev_spawnflags, pev(wEnt, pev_spawnflags) | SF_NORESPAWN)
		set_pev(wEnt, pev_impulse, iImpulse)
		dllfunc(DLLFunc_Spawn, wEnt)

		if(ExecuteHamB(Ham_AddPlayerItem, id, wEnt))
		{
			ExecuteHamB(Ham_Item_AttachToPlayer, wEnt, id)
			if(iBpAmmo)
			{
				ExecuteHamB(Ham_GiveAmmo, id, iBpAmmo, g_szAmmoType[iId], iBpAmmo)
			}
			if(bSound)
			{
				emit_sound(id, CHAN_ITEM, "items/gunpickup2.wav", VOL_NORM, ATTN_NORM, 0, PITCH_NORM)
			}
			return wEnt
		}
		set_pev(wEnt, pev_flags, pev(wEnt, pev_flags) | FL_KILLME)
	}
	return -1
}


/* code extracted from stripweapons.inc file */
/**
 * ConnorMcLeod
 * http://forums.alliedmods.net/showpost.php?p=1109747&postcount=42
 *
 * Strips a player's weapon based on weapon index.
 *
 * @param id:				Player id
 * @param iCswId:			Weapon CSW_* index
 * @param iSlot:			Inventory slot (Leave 0 if not sure)
 * @param bSwitchIfActive:	Switch weapon if currently deployed
 *
 * @return					1 on success, otherwise 0
 *
 * Ex: 	ham_strip_user_weapon(id, CSW_M4A1); 	// Strips m4a1 if user has one.
 * 		ham_strip_user_weapon(id, CSW_HEGRENADE, _, false);		// Strips HE grenade if user has one 
 *																// without switching weapons.
*/
stock ham_strip_user_weapon(id, iCswId, iSlot = 0, bool:bSwitchIfActive = true)
{
	if(iCswId == CSW_SHIELD)
	{
		set_user_shield(id, false)
		return 1
	}
	if(!iSlot)
	{
		iSlot = g_iWeaponSlots[iCswId]
	}
	new iWeapon = get_pdata_cbase(id, m_rgpPlayerItems_CBasePlayer[iSlot])

	while(iWeapon > 0)
	{
		if(get_pdata_int(iWeapon, m_iId, XO_WEAPON) == iCswId)
		{
			break
		}
		iWeapon = get_pdata_cbase(iWeapon, m_pNext, XO_WEAPON)
	}
	if(iWeapon > 0)
	{
		if(bSwitchIfActive && get_pdata_cbase(id, m_pActiveItem) == iWeapon)
		{
			ExecuteHamB(Ham_Weapon_RetireWeapon, iWeapon)
		}
		if(ExecuteHamB(Ham_RemovePlayerItem, id, iWeapon))
		{
			user_has_weapon(id, iCswId, 0)
			ExecuteHamB(Ham_Item_Kill, iWeapon)
			return 1
		}
	}
	return 0
} 


