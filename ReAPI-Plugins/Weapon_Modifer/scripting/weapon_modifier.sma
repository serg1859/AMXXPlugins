//	Copyright © 2017 Vaqtincha

#define CASE_SENSITIVE_MEMBER_NAME


#include <amxmodx>
#include <hamsandwich>
#include <reapi>


new const CFG_FILE_NAME[] = "weapons.lsp"
#define PL_VERSION  		"0.0.3"


#define IsValidWeaponID(%1) 		(WEAPON_P228 <= %1 <= WEAPON_P90 && %1 != WEAPON_GLOCK)
#define IsNoClipWeaponID(%1) 		(NOCLIP_WPN_BS & (1 << any:%1))
#define IsSniperWeaponID(%1) 		(SNIPER_WPN_BS & (1 << any:%1))

#define IsShieldDrawn(%1) 			(get_member(%1, m_Weapon_iWeaponState) & WPNSTATE_SHIELD_DRAWN)
#define UsesZoom(%1) 				(get_member(pPlayer, m_iFOV) != DEFAULT_FOV)

#define IsValidMember(%1) 			(m_iMaxClip <= %1 < m_MemberEnd)
#define IsPlayer(%1)				(1 <= %1 <= g_iMaxPlayers)
new g_iMaxPlayers


const NOCLIP_WPN_BS = ((1 << _:WEAPON_HEGRENADE)|(1 << _:WEAPON_SMOKEGRENADE)|(1 << _:WEAPON_FLASHBANG)|(1 << _:WEAPON_KNIFE)|(1 << _:WEAPON_C4))
const SNIPER_WPN_BS = ((1 << _:WEAPON_SCOUT)|(1 << _:WEAPON_SG550)|(1 << _:WEAPON_AWP)|(1 << _:WEAPON_G3SG1))

// #define PRIMARY_POSITION_START		18 	// famas hudpos
// #define SECONDARY_POSITION_START		7 	// fiveseven hudpos

#define DEFAULT_FOV					90			// the default field of view

enum ( <<= 1 )
{
	WFLAG_CANT_DROP = 1,	// (1<<0) - 1 -  "a" = block drop
	WFLAG_DEATH_REMOVE,		// (1<<1) - 2 -  "b" = don't drop on death
	WFLAG_SPAWN_AUTORELOAD,	// (1<<2) - 4 -  "c" = fill clip on spawn
	WFLAG_KILL_AUTORELOAD,	// (1<<3) - 8 -  "d" = fill clip on kill
	WFLAG_SET_DEFAULT,		// (1<<4) - 16 - "e" = set default weapon
	WFLAG_FREE_FULLAMMO		// (1<<5) - 32 - "f" = give free ammo on buy
}

const WFLAG_ALL = 
(
	WFLAG_CANT_DROP|WFLAG_DEATH_REMOVE|WFLAG_SPAWN_AUTORELOAD|WFLAG_KILL_AUTORELOAD|WFLAG_SET_DEFAULT|WFLAG_FREE_FULLAMMO
)

enum weapon_data_e
{
	m_UnknownMember = 0,
	m_iMaxClip,
	m_iMaxAmmo,
	// m_iBuyAmmo,
	m_iPrice,
	m_iAmmoPrice,
	m_iReward,
	m_iSlot,
	m_iPosition,
	m_iWeight,
	m_bitFlags,
	Float:m_fReloadTime, 		// for custom models
	Float:m_fSwitchDelay,
	Float:m_fNextPrimAttack,
	Float:m_fNextSecAttack,
	Float:m_fPrimSpeed,
	Float:m_fSecSpeed,
	Float:m_fDamage,
	// m_szViewModel[64],
	// m_szWeaponModel[64],
	m_MemberEnd,

	// m_iszViewModel,
	// m_iszWeaponModel,
	HamHook:hGetItemInfo,
	bool:bWeaponModified
}

enum member_type_e
{
	MTYPE_UNKNOWN = 0,
	MTYPE_INTEGER,
	MTYPE_FLOAT,
	MTYPE_BITWISE,
	MTYPE_STRING
}

enum member_data_e
{
	member_type_e:m_iMemType,
	m_szMemName[20],
	m_iMinval,
	m_iMaxval,
	Float:m_fMinval,
	Float:m_fMaxval
}

new const g_aMemberData[m_MemberEnd][member_data_e] =
{
	{ MTYPE_UNKNOWN, "Unknown member", 		-1, -1, -1.0, -1.0 },

	{ MTYPE_INTEGER, "m_iMaxClip", 			1, 255, 0.0, 0.0 },
	{ MTYPE_INTEGER, "m_iMaxAmmo", 			0, 255, 0.0, 0.0 },
	{ MTYPE_INTEGER, "m_iPrice", 			0, 0, 0.0, 0.0 },
	{ MTYPE_INTEGER, "m_iAmmoPrice", 		0, 0, 0.0, 0.0 },
	{ MTYPE_INTEGER, "m_iReward", 			0, 0, 0.0, 0.0 },
	{ MTYPE_INTEGER, "m_iSlot", 			0, 0, 0.0, 0.0 },
	{ MTYPE_INTEGER, "m_iPosition", 		1, 0, 0.0, 0.0 },
	{ MTYPE_INTEGER, "m_iWeight", 			0, 0, 0.0, 0.0 },
	{ MTYPE_BITWISE, "m_bitFlags", 			0, WFLAG_ALL, 0.0, 0.0 },
	{ MTYPE_FLOAT, 	 "m_fReloadTime",		0, 0, 1.0, 20.0 },
	{ MTYPE_FLOAT, 	 "m_fSwitchDelay",		0, 0, 0.01, 5.0 },
	{ MTYPE_FLOAT, 	 "m_fNextPrimAttack",	0, 0, 0.01, 5.0 },
	{ MTYPE_FLOAT, 	 "m_fNextSecAttack",	0, 0, 0.01, 5.0 },
	{ MTYPE_FLOAT, 	 "m_fPrimSpeed",		0, 0, 100.0, 1000.0 },
	{ MTYPE_FLOAT, 	 "m_fSecSpeed",			0, 0, 100.0, 1000.0 },
	{ MTYPE_FLOAT, 	 "m_fDamage",			0, 0, 0.01, 5.0 }
}

new const g_szWeaponName[any:WEAPON_P90 + 1][] = 
{
	"", "weapon_p228", "", "weapon_scout", "weapon_hegrenade", "weapon_xm1014", "weapon_c4",
	"weapon_mac10", "weapon_aug", "weapon_smokegrenade", "weapon_elite", "weapon_fiveseven", "weapon_ump45",
	"weapon_sg550", "weapon_galil", "weapon_famas", "weapon_usp", "weapon_glock18", "weapon_awp",
	"weapon_mp5navy", "weapon_m249", "weapon_m3", "weapon_m4a1", "weapon_tmp", "weapon_g3sg1",
	"weapon_flashbang", "weapon_deagle", "weapon_sg552", "weapon_ak47", "weapon_knife", "weapon_p90"
}

new const g_iMaxBPAmmo[any:WEAPON_P90 + 1] = 
{
	-1, 52, -1, 90, 1, 32, 1, 100, 90, 1, 120, 100, 100, 90, 90, 90, 
	100, 120, 30, 120, 200, 32, 90, 120, 90, 2, 35, 90, 90, -1, 100
}

new const g_iReloadAnims[any:WEAPON_P90 + 1] = {
	-1, 5, -1, 3, -1, 6, -1, 1, 1, -1, 14, 4, 2, 3, 1, 1, 13, 7, 4, 1, 3, 6, 11, 1, 3, -1, 4, 1, 1, -1, 1
}

new g_aWeaponData[any:WEAPON_P90 + 1][weapon_data_e]
new WeaponIdType:g_iDefaultItems[any:WEAPON_P90 + 1], g_iTotalItems
new g_iRewardMoney[MAX_CLIENTS + 1], WeaponIdType:g_iActiveWeaponID[MAX_CLIENTS + 1]

new Trie:g_tWeaponName, Trie:g_tMemberName
new HookChain:g_hAddAccount
new bool:g_bPlayerSpawn, bool:g_bPlayerKilled, bool:g_bDeathWeapons, bool:g_bTakeDamage, bool:g_bBuyWeapon


public plugin_end()
{
	if(g_tWeaponName) {
		TrieDestroy(g_tWeaponName)
	}
	if(g_tMemberName) {
		TrieDestroy(g_tMemberName)
	}
}

public plugin_precache()
{
	if(!LoadConfigFile())
		return

	for(new WeaponIdType:iId = WEAPON_P228; iId <= WEAPON_P90; iId++)
	{
		if(!g_aWeaponData[iId][bWeaponModified] || !g_szWeaponName[iId][0])
			continue

		g_aWeaponData[iId][hGetItemInfo] = any:RegisterHam(Ham_Item_GetItemInfo, g_szWeaponName[iId], "CBasePlayerItem_GetItemInfo", .Post = true)

		if(g_aWeaponData[iId][m_iMaxClip] > 0) {
			RegisterHam(Ham_Spawn, g_szWeaponName[iId], "CBasePlayerWeapon_Spawn", .Post = true)
		}
		if(g_aWeaponData[iId][m_bitFlags] & WFLAG_CANT_DROP) {
			RegisterHam(Ham_CS_Item_CanDrop, g_szWeaponName[iId], "CBasePlayerItem_CanDrop", .Post = false)
		}
		if(g_aWeaponData[iId][m_fPrimSpeed] > 0.0 || g_aWeaponData[iId][m_fSecSpeed] > 0.0) {
			RegisterHam(Ham_CS_Item_GetMaxSpeed, g_szWeaponName[iId], "CBasePlayerItem_GetMaxSpeed", .Post = false)
		}
		if(g_aWeaponData[iId][m_fSwitchDelay] > 0.0 || g_aWeaponData[iId][m_fDamage] > 0.0) {
			RegisterHam(Ham_Item_Deploy, g_szWeaponName[iId], "CBasePlayerItem_Deploy", .Post = true)
		}
		if(g_aWeaponData[iId][m_fNextPrimAttack] > 0.0) {
			RegisterHam(Ham_Weapon_PrimaryAttack, g_szWeaponName[iId], "CBasePlayerWeapon_PrimAttack", .Post = true)
		}
		if(g_aWeaponData[iId][m_fNextSecAttack] > 0.0) {
			RegisterHam(Ham_Weapon_SecondaryAttack, g_szWeaponName[iId], "CBasePlayerWeapon_SecAttack", .Post = true)
		}
		if(!IsNoClipWeaponID(iId) && g_aWeaponData[iId][m_fReloadTime] > 0.0) {
			RegisterHam(Ham_CS_Weapon_SendWeaponAnim, g_szWeaponName[iId], "CBasePlayerWeapon_SendWpnAnim", .Post = true)
		}
		if(g_aWeaponData[iId][m_fDamage] > 0.0) 
		{
			RegisterHam(Ham_Item_Holster, g_szWeaponName[iId], "CBasePlayerItem_Holster", .Post = true)
			g_bTakeDamage = true
		}
		if(g_aWeaponData[iId][m_bitFlags] & WFLAG_SET_DEFAULT)
		{
			g_iDefaultItems[g_iTotalItems] = iId
			min(g_iTotalItems++, any:WEAPON_P90)
		}

		if(!g_bDeathWeapons && (g_aWeaponData[iId][m_bitFlags] & WFLAG_DEATH_REMOVE)) {
			g_bDeathWeapons = true
		}
		if(!g_bPlayerKilled && (g_aWeaponData[iId][m_iReward] > 0 || (g_aWeaponData[iId][m_bitFlags] & WFLAG_KILL_AUTORELOAD))) {
			g_bPlayerKilled = true
		}
		if(!g_bPlayerSpawn && (g_aWeaponData[iId][m_bitFlags] & WFLAG_SPAWN_AUTORELOAD)) {
			g_bPlayerSpawn = true
		}
		if(!g_bBuyWeapon && (g_aWeaponData[iId][m_bitFlags] & WFLAG_FREE_FULLAMMO)) {
			g_bBuyWeapon = true
		}
	}
}

public plugin_init() 
{
	register_plugin("Weapon Modifier", PL_VERSION, "Vaqtincha")

	if(g_bTakeDamage) {
		RegisterHookChain(RG_CBasePlayer_TakeDamage, "CBasePlayer_TakeDamage", .post = false)
	}
	if(g_bPlayerKilled)
	{
		RegisterHookChain(RG_CSGameRules_DeathNotice, "CSGameRules_DeathNotice", .post = true)
		DisableHookChain(g_hAddAccount = RegisterHookChain(RG_CBasePlayer_AddAccount, "CBasePlayer_AddAccount", .post = false))
	}
	if(g_bDeathWeapons) {
		RegisterHookChain(RG_CSGameRules_DeadPlayerWeapons, "CSGameRules_DeadPlayerWeapons", .post = false)
	}
	if(g_bPlayerSpawn) {
		RegisterHookChain(RG_CBasePlayer_Spawn, "CBasePlayer_Spawn", .post = true)
	}
	if(g_iTotalItems > 0) {
		RegisterHookChain(RG_CBasePlayer_GiveDefaultItems, "CBasePlayer_GiveDefaultItems", .post = true)
		
	}
	if(g_bBuyWeapon) {
		RegisterHookChain(RG_BuyWeaponByWeaponID, "BuyWeaponByWeaponID", .post = true)
	}

	register_concmd("weapon_info", "ConCommand_WeaponInfo")

	g_iMaxPlayers = get_maxplayers()
	DisableGetItemInfoForward()
}

public ConCommand_WeaponInfo(const pPlayer)
{
	if(!is_user_alive(pPlayer))
		return PLUGIN_HANDLED

	new pItem, WeaponIdType:iId, weapon_data_e:iMemId, iType, szFlags[6]
	pItem = get_member(pPlayer, m_pActiveItem)
	if(!is_nullent(pItem))
	{
		iId = get_member(pItem, m_iId)
		if(!g_aWeaponData[iId][bWeaponModified])
		{
			console_print(pPlayer, "^n%s is not modified!", g_szWeaponName[iId])
			return PLUGIN_HANDLED
		}
		
		console_print(pPlayer, "^nName: %s Id: %i^n", g_szWeaponName[iId], iId)
		for(iMemId = m_iMaxClip; iMemId < m_MemberEnd; iMemId++)
		{
			iType = g_aMemberData[iMemId][m_iMemType]
			switch(iType)
			{
				case MTYPE_INTEGER: {
					if(g_aWeaponData[iId][iMemId] >= g_aMemberData[iMemId][m_iMinval]) {
						console_print(pPlayer, "%s: %i", g_aMemberData[iMemId][m_szMemName], g_aWeaponData[iId][iMemId])
					}
				}
				case MTYPE_FLOAT: {
					if(g_aWeaponData[iId][iMemId] >= g_aMemberData[iMemId][m_fMinval]) {
						console_print(pPlayer, "%s: %0.2f", g_aMemberData[iMemId][m_szMemName], g_aWeaponData[iId][iMemId])
					}
				}
				case MTYPE_BITWISE: {
					if(g_aWeaponData[iId][iMemId] > g_aMemberData[iMemId][m_iMinval]) {
						get_flags(g_aWeaponData[iId][iMemId], szFlags, charsmax(szFlags))
						console_print(pPlayer, "%s: %s (%i)", g_aMemberData[iMemId][m_szMemName], szFlags, g_aWeaponData[iId][iMemId])
					}
				}
			}
		}
	}
	
	return PLUGIN_HANDLED
}

public client_putinserver(pPlayer)
{
	g_iRewardMoney[pPlayer] = 0
	g_iActiveWeaponID[pPlayer] = WEAPON_NONE
}


public CBasePlayerItem_GetItemInfo(const pItem, const iItemInfo) 
{
	new WeaponIdType:iId = any:GetHamItemInfo(iItemInfo, Ham_ItemInfo_iId)

	if(IsValidWeaponID(iId))
	{
		if(g_aWeaponData[iId][m_iMaxClip] > 0) {
			SetHamItemInfo(iItemInfo, Ham_ItemInfo_iMaxClip, g_aWeaponData[iId][m_iMaxClip])
		}
		if(g_aWeaponData[iId][m_iMaxAmmo] != -1) {
			SetHamItemInfo(iItemInfo, Ham_ItemInfo_iMaxAmmo1, g_aWeaponData[iId][m_iMaxAmmo])
		}
		if(g_aWeaponData[iId][m_iSlot] != -1) {
			SetHamItemInfo(iItemInfo, Ham_ItemInfo_iSlot, g_aWeaponData[iId][m_iSlot])
		}
		if(g_aWeaponData[iId][m_iPosition] > 0) {
			SetHamItemInfo(iItemInfo, Ham_ItemInfo_iPosition, g_aWeaponData[iId][m_iPosition])
		}
		if(g_aWeaponData[iId][m_iWeight] != -1) {
			SetHamItemInfo(iItemInfo, Ham_ItemInfo_iWeight, g_aWeaponData[iId][m_iWeight])
		}

		if(g_aWeaponData[iId][m_iPrice] != -1) {
			rg_set_weapon_info(iId, WI_COST, g_aWeaponData[iId][m_iPrice])
		}
		if(g_aWeaponData[iId][m_iAmmoPrice] != -1) {
			rg_set_weapon_info(iId, WI_CLIP_COST, g_aWeaponData[iId][m_iAmmoPrice])
		}
	}

	return HAM_IGNORED
}

public CBasePlayerItem_Deploy(const pItem)
{
	if(pItem <= 0)
		return HAM_IGNORED

	new WeaponIdType:iId = get_member(pItem, m_iId)
	if(IsValidWeaponID(iId))
	{
		new pPlayer = get_member(pItem, m_pPlayer)
		if(IsPlayer(pPlayer))
		{
			if(g_aWeaponData[iId][m_fSwitchDelay] > 0.0)
			{
				set_member(pItem, m_Weapon_flNextPrimaryAttack, g_aWeaponData[iId][m_fSwitchDelay])
				set_member(pItem, m_Weapon_flNextSecondaryAttack, g_aWeaponData[iId][m_fSwitchDelay])
				set_member(pPlayer, m_flNextAttack, g_aWeaponData[iId][m_fSwitchDelay])
			}

			g_iActiveWeaponID[pPlayer] = iId
		}
	}

	return HAM_IGNORED
}

public CBasePlayerItem_Holster(const pItem)
{
	if(pItem <= 0)
		return HAM_IGNORED
	
	new pPlayer = get_member(pItem, m_pPlayer)
	if(IsPlayer(pPlayer)) {
		g_iActiveWeaponID[pPlayer] = WEAPON_NONE
	}

	return HAM_IGNORED
}

public CBasePlayerItem_GetMaxSpeed(const pItem)
{
	if(pItem <= 0)
		return HAM_IGNORED
	
	new Float:fMaxSpeed, pPlayer, WeaponIdType:iId = get_member(pItem, m_iId)

	if(IsValidWeaponID(iId))
	{
		if(IsSniperWeaponID(iId))
		{
			if(IsPlayer((pPlayer = get_member(pItem, m_pPlayer)))) {
				fMaxSpeed = (UsesZoom(pPlayer) ? g_aWeaponData[iId][m_fSecSpeed] : g_aWeaponData[iId][m_fPrimSpeed])
			}
		}
		else
		{
			fMaxSpeed = (IsShieldDrawn(pItem) ? g_aWeaponData[iId][m_fSecSpeed] : g_aWeaponData[iId][m_fPrimSpeed])
		}
	}

	if(fMaxSpeed > 0.0) 
	{
		SetHamReturnFloat(fMaxSpeed)
		return HAM_SUPERCEDE
	}

	return HAM_IGNORED
}

public CBasePlayerItem_CanDrop(const pItem)
{
	SetHamReturnInteger(false)
	return HAM_SUPERCEDE
}


public CBasePlayerWeapon_PrimAttack(const pWeapon)
{
	if(pWeapon > 0)
	{
		new WeaponIdType:iId = get_member(pWeapon, m_iId)
		if(IsValidWeaponID(iId) && g_aWeaponData[iId][m_fNextPrimAttack] > 0.0) {
			set_member(pWeapon, m_Weapon_flNextPrimaryAttack, g_aWeaponData[iId][m_fNextPrimAttack])
		}
	}
}

public CBasePlayerWeapon_SecAttack(const pWeapon)
{
	if(pWeapon > 0)
	{
		new WeaponIdType:iId = get_member(pWeapon, m_iId)
		if(IsValidWeaponID(iId) && g_aWeaponData[iId][m_fNextSecAttack] > 0.0) {
			set_member(pWeapon, m_Weapon_flNextSecondaryAttack, g_aWeaponData[iId][m_fNextSecAttack])
		}
	}
}

public CBasePlayerWeapon_Spawn(const pWeapon)
{
	if(pWeapon > 0)
	{
		new WeaponIdType:iId = get_member(pWeapon, m_iId)
		if(IsValidWeaponID(iId) && g_aWeaponData[iId][m_iMaxClip] != -1) {
			set_member(pWeapon, m_Weapon_iDefaultAmmo, g_aWeaponData[iId][m_iMaxClip])
		}
	}
}

public CBasePlayerWeapon_SendWpnAnim(const pWeapon, const iAnim, const skiplocal)
{
	if(pWeapon <= 0)
		return HAM_IGNORED

	new WeaponIdType:iId = get_member(pWeapon, m_iId)
	if(IsValidWeaponID(iId) && !IsNoClipWeaponID(iId) && iAnim == g_iReloadAnims[iId] && g_aWeaponData[iId][m_fReloadTime] > 0.0)
	{
		new pPlayer = get_member(pWeapon, m_pPlayer)
		if(IsPlayer(pPlayer)) 
		{
			set_member(pPlayer, m_flNextAttack, g_aWeaponData[iId][m_fReloadTime])
			// set_member(pWeapon, m_Weapon_flTimeWeaponIdle, g_aWeaponData[iId][m_fReloadTime] + 0.5)
		}
	}

	return HAM_IGNORED
}


public CBasePlayer_GiveDefaultItems(const pPlayer)
{
	for(new i = 0, WeaponIdType:iId; i < g_iTotalItems; i++)
	{
		iId = g_iDefaultItems[i]
		rg_give_item(pPlayer, g_szWeaponName[iId], GT_REPLACE)
	}
}

public CBasePlayer_Spawn(const pPlayer)
{
	if(!is_user_alive(pPlayer))
		return HC_CONTINUE
	
	for(new InventorySlotType:iSlot = PRIMARY_WEAPON_SLOT, WeaponIdType:iId, pItem; iSlot <= PISTOL_SLOT; iSlot++)
	{
		pItem = get_member(pPlayer, m_rgpPlayerItems, iSlot)
		while(!is_nullent(pItem))
		{
			iId = get_member(pItem, m_iId)
			if(IsValidWeaponID(iId) && g_aWeaponData[iId][m_bitFlags] & WFLAG_SPAWN_AUTORELOAD) {
				rg_instant_reload_weapons(pPlayer, pItem)
			}

			pItem = get_member(pItem, m_pNext)
		}
	}
	
	return HC_CONTINUE
}

public CBasePlayer_TakeDamage(const pPlayer, const pevInflictor, const pevAttacker, const Float:flDamage, const bitsDamageType)
{
	if(!IsPlayer(pevAttacker))
		return HC_CONTINUE

	new WeaponIdType:iId
	if(pevAttacker == pevInflictor && (bitsDamageType & DMG_BULLET))
	{
		iId = g_iActiveWeaponID[pevAttacker]
	}
	else if(pevAttacker != pevInflictor && (bitsDamageType & DMG_GRENADE) && FClassnameIs(pevInflictor, "grenade"))
	{
		iId = WEAPON_HEGRENADE
	}

	if(IsValidWeaponID(iId) && g_aWeaponData[iId][m_fDamage] > 0.0 && g_aWeaponData[iId][m_fDamage] != 1.0) {
		SetHookChainArg(4, ATYPE_FLOAT, flDamage * g_aWeaponData[iId][m_fDamage])
	}
	
	return HC_CONTINUE
}

public CBasePlayer_AddAccount(const pPlayer, const iAmount, const RewardType:iRwType, const bool:bTrackChange)
{
	if(iRwType == RT_ENEMY_KILLED && g_iRewardMoney[pPlayer]) {
		SetHookChainArg(2, ATYPE_INTEGER, g_iRewardMoney[pPlayer])
	}

	g_iRewardMoney[pPlayer] = 0	
	DisableHookChain(g_hAddAccount)
}


public CSGameRules_DeadPlayerWeapons(const pPlayer)
{
	RemovePlayerWeapons(pPlayer)
}

public CSGameRules_DeathNotice(const pPlayer, const pKiller, pevInflictor)
{
	if(!IsPlayer(pKiller) || pPlayer == pKiller)
		return HC_CONTINUE
	
	if(pKiller == pevInflictor) {
		pevInflictor = get_member(pKiller, m_pActiveItem)
	}

	if(!is_nullent(pevInflictor))
	{
		new WeaponIdType:iId, szWeaponName[20]
		get_entvar(pevInflictor, var_classname, szWeaponName, charsmax(szWeaponName))	

		if(szWeaponName[0] == 'g' && szWeaponName[6] == 'e' /* && get_member(pPlayer, m_bKilledByGrenade) */) // "grenade"
		{
			iId = WEAPON_HEGRENADE
		}
		else if(szWeaponName[0] == 'w' && szWeaponName[6] == '_') // "weapon_"
		{
			iId = get_member(pevInflictor, m_iId)
		}

		if(IsValidWeaponID(iId)) 
		{
			if(!IsNoClipWeaponID(iId) && (g_aWeaponData[iId][m_bitFlags] & WFLAG_KILL_AUTORELOAD)) {
				rg_instant_reload_weapons(pKiller, pevInflictor)
			}
			if(g_aWeaponData[iId][m_iReward] > 0)
			{
				g_iRewardMoney[pKiller] = g_aWeaponData[iId][m_iReward]
				EnableHookChain(g_hAddAccount)
			}
		}
	}
	
	return HC_CONTINUE
}

public BuyWeaponByWeaponID(const pPlayer, const WeaponIdType:iId)
{
	if(!IsValidWeaponID(iId) || g_aWeaponData[iId][m_iMaxAmmo] == 0)
		return HC_CONTINUE

	if((g_aWeaponData[iId][m_bitFlags] & WFLAG_FREE_FULLAMMO) && GetHookChainReturn(ATYPE_INTEGER) > 0) {
		rg_set_user_bpammo(pPlayer, iId, (g_aWeaponData[iId][m_iMaxAmmo] > 0) ? g_aWeaponData[iId][m_iMaxAmmo] : g_iMaxBPAmmo[iId])
	}

	return HC_CONTINUE
}


bool:LoadConfigFile()
{
	new szBuffer[128], szKey[32], szValue[10], pFile, bool:bStart, WeaponIdType:iId, weapon_data_e:iMemId, iLines

	if(!(pFile = OpenFile()))
		return false

	g_tMemberName = TrieCreate()
	g_tWeaponName = TrieCreate()
	
	for(iMemId = m_iMaxClip; iMemId < m_MemberEnd; iMemId++)
	{
#if !defined CASE_SENSITIVE_MEMBER_NAME
		strtolower(g_aMemberData[iMemId][m_szMemName])
#endif
		TrieSetCell(g_tMemberName, g_aMemberData[iMemId][m_szMemName], iMemId)
	}

	for(iId = WEAPON_P228; iId <= WEAPON_P90; iId++)
	{
		TrieSetCell(g_tWeaponName, g_szWeaponName[iId], g_szWeaponName[iId][0] ? iId : WEAPON_NONE)
		set_default_values(iId)
	}

	while(!feof(pFile))
	{
		fgets(pFile, szBuffer, charsmax(szBuffer))
		trim(szBuffer)
		iLines++
		
		if(!szBuffer[0] || szBuffer[0] == ';' || szBuffer[0] == '#' || (szBuffer[0] == '/' && szBuffer[1] == '/'))
			continue
	
		if((bStart && szBuffer[0] == '{') || (!bStart && szBuffer[0] == '}'))
		{
			server_print("[WEAPON MODIFIER] Invalid line! at #%i", iLines)
			continue
		}

		if(!bStart && szBuffer[0] == '{')
		{
			bStart = true
			continue
		}
		else if(bStart && szBuffer[0] == '}')
		{
			bStart = false
			continue
		}

		if(containi(szBuffer, "[weapon_") != -1)
		{
			szBuffer[strlen(szBuffer) - 1] = 0
			strtolower(szBuffer)

			if((iId = GetWeaponIndex(szBuffer[1])) == WEAPON_NONE)
			{
				server_print("[WEAPON MODIFIER] Invalid weapon name %s", szBuffer[1])
				bStart = false
				continue
			}
			
			if(g_aWeaponData[iId][bWeaponModified])
			{
				server_print("[WEAPON MODIFIER] Duplicate weapon %s! at #%i", szBuffer[1], iLines)
				bStart = false
				continue
			}

			g_aWeaponData[iId][bWeaponModified] = true
		}

		if(bStart && parse(szBuffer, szKey, charsmax(szKey), szValue, charsmax(szValue)) == 2)
		{
			if(!szKey[0] || !szValue[0])
			{
				server_print("[WEAPON MODIFIER] Invalid %s! at #%i", !szValue[0] ? "value" : "key", iLines)
				continue
			}
#if !defined CASE_SENSITIVE_MEMBER_NAME
			strtolower(szKey)
#endif
			if(set_weapon_keyvalue(iId, szKey, szValue) == m_UnknownMember)
			{
				server_print("[WEAPON MODIFIER] Unknown member %s! at #%i", szKey, iLines)
				continue
			}
		}
	}

	fclose(pFile)
	return true
}

OpenFile()
{
	new szFilePath[128], szMapName[32], szMapPrefix[6], pFile, iLen
	iLen = get_localinfo("amxx_configsdir", szFilePath, charsmax(szFilePath))
	get_mapname(szMapName, charsmax(szMapName))

	if(szMapName[0] == '$')				 // for support: $1000$, $2000$, $3000$ ...
		szMapPrefix[0] = szMapName[0]
	else
		copyc(szMapPrefix, charsmax(szMapPrefix), szMapName, '_')

	formatex(szFilePath[iLen], charsmax(szFilePath) - iLen, "%s/maps/%s.lsp", szFilePath[iLen], szMapName)
	if((pFile = fopen(szFilePath, "rt"))) // map config
		return pFile

	formatex(szFilePath[iLen], charsmax(szFilePath) - iLen, "%s/maps/prefix_%s.lsp", szFilePath[iLen + iLen], szMapPrefix)
	if((pFile = fopen(szFilePath, "rt"))) // prefix config
		return pFile
	
	formatex(szFilePath[iLen], charsmax(szFilePath) - iLen, "%s/%s", szFilePath[iLen + iLen], CFG_FILE_NAME)
	if((pFile = fopen(szFilePath, "rt"))) // main config
		return pFile

	return 0
}

weapon_data_e:set_weapon_keyvalue(const WeaponIdType:iId, const szKey[], const szValue[])
{
	new weapon_data_e:iMemId
	
	if(!TrieGetCell(g_tMemberName, szKey, iMemId))
		return m_UnknownMember
	
	if(!IsValidMember(iMemId))
		return m_UnknownMember

	new iType = g_aMemberData[iMemId][m_iMemType]
	switch(iType)
	{
		case MTYPE_INTEGER: {
			if(g_aMemberData[iMemId][m_iMaxval] > g_aMemberData[iMemId][m_iMinval]) {
				g_aWeaponData[iId][iMemId] = clamp(str_to_num(szValue), g_aMemberData[iMemId][m_iMinval], g_aMemberData[iMemId][m_iMaxval])
			}
			else {
				g_aWeaponData[iId][iMemId] = str_to_num(szValue)
			}
		}
		case MTYPE_FLOAT: {
			// BUGBUG: str_to_float/floatstr  + 0.000001
			if(g_aMemberData[iMemId][m_fMaxval] > g_aMemberData[iMemId][m_fMinval]) {
				g_aWeaponData[iId][iMemId] = any:(floatclamp(str_to_float(szValue), g_aMemberData[iMemId][m_fMinval], g_aMemberData[iMemId][m_fMaxval]) + 0.000001)
			}
			else {
				g_aWeaponData[iId][iMemId] = any:(str_to_float(szValue) + 0.000001)
			}
		}
		case MTYPE_BITWISE: {
			if(g_aMemberData[iMemId][m_iMaxval] > g_aMemberData[iMemId][m_iMinval]) {
				g_aWeaponData[iId][iMemId] = clamp(read_flags(szValue), g_aMemberData[iMemId][m_iMinval], g_aMemberData[iMemId][m_iMaxval])
			}
			else {
				g_aWeaponData[iId][iMemId] = read_flags(szValue)
			}
		}
		// case MTYPE_STRING: {}
		default: return m_UnknownMember
	}

	return iMemId
}

set_default_values(const WeaponIdType:iId)
{
	g_aWeaponData[iId][m_iPrice] = -1		// 0 = free weapon
	g_aWeaponData[iId][m_iAmmoPrice] = -1	// 0 = free ammo
	g_aWeaponData[iId][m_iMaxAmmo] = -1		// 0 = no bp ammo
	g_aWeaponData[iId][m_iSlot] = -1		// 0 = first slot
	g_aWeaponData[iId][m_iWeight] = -1		// 0 = no weight (like weapon_knife)
}

DisableGetItemInfoForward()
{
	for(new WeaponIdType:iId = WEAPON_P228; iId <= WEAPON_P90; iId++)
	{
		if(g_szWeaponName[iId][0] && g_aWeaponData[iId][bWeaponModified] && g_aWeaponData[iId][hGetItemInfo]) {
			DisableHamForward(any:g_aWeaponData[iId][hGetItemInfo])
		}
	}
}

// alternate rg_get_weapon_info(WI_ID), get_weaponid(str[])
WeaponIdType:GetWeaponIndex(const szClassName[])
{
	new WeaponIdType:iId
	if(!szClassName[0] || !TrieGetCell(g_tWeaponName, szClassName, iId)) {
		return WEAPON_NONE
	}

	return iId
}

RemovePlayerWeapons(const pPlayer)
{
	new iWeapons[MAX_WEAPONS], iNum, WeaponIdType:iId, i
	get_user_weapons(pPlayer, iWeapons, iNum)

	for(i = 0; i < iNum; i++)
	{
		iId = any:iWeapons[i]
		if(iId != WEAPON_KNIFE && (g_aWeaponData[iId][m_bitFlags] & WFLAG_DEATH_REMOVE)) {
			rg_remove_item(pPlayer, g_szWeaponName[iId])
		}
	}
}







