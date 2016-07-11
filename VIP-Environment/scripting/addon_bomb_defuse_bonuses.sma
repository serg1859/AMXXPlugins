// Copyright © 2016 Vaqtincha

//■■■■■■■■■■■■■■■■■■■■■■■ CONFIG START ■■■■■■■■■■■■■■■■■■■■■■■//

#define DEFAULT_ACCESS		ACCESS_OTHER
// money bonus
#define DEFUSER_BONUS		800 	// without defuse kit.
#define DEFUSER_BONUS_KIT	500 	// with defuse kit.
#define PLANTER_BONUS		500
#define BOMBER_BONUS		800
#define MAX_MONEY			16000
//
#define DEFUSE_TIME			5.0 	// without defuse kit.
#define DEFUSE_TIME_KIT 	2.0		// with defuse kit.
#define PLANTING_SPEED 		250

//■■■■■■■■■■■■■■■■■■■■■■■■ CONFIG END ■■■■■■■■■■■■■■■■■■■■■■■■//

#include <amxmodx>
#include <csx>
#include <fakemeta>
#include <hamsandwich>
#include <vip_environment>


new g_iMsgIdBarTime
new const g_szBombModel[] = "models/w_c4.mdl"


public plugin_init()
{
	register_plugin("Bomb Defuse Bonuses", "0.0.1", "Vaqtincha")
	if(!vip_environment_loaded() || !IsBombDefuseMap())
	{
		pause("ad")
		return
	}

	RegisterHam(Ham_Weapon_PrimaryAttack, "weapon_c4", "PrimaryAttack_Pre",	false)
	g_iMsgIdBarTime = get_user_msgid("BarTime")
}

public PrimaryAttack_Pre(wEnt) 
{
	new id = get_pdata_cbase(wEnt, m_pPlayer, XO_WEAPON)
	if(id > 0)
	{
		set_pev(id, pev_flags, pev(id, pev_flags) | FL_ONGROUND)
	}	
}

public bomb_defusing(DefuserId)
{
	if(~GetUserAccess(DefuserId) & DEFAULT_ACCESS)
	{
		return
	}

	new iEntBomb = engfunc(EngFunc_FindEntityByString, FM_NULLENT, "model", g_szBombModel)
	if(pev_valid(iEntBomb) == PDATA_SAFE)
	{
		new Float:flNewTime = (has_user_defuser(DefuserId) ? DEFUSE_TIME_KIT : DEFUSE_TIME)
		set_pdata_float(iEntBomb, m_flDefuseCountDown, get_gametime() + flNewTime)

		message_begin(MSG_ONE, g_iMsgIdBarTime, .player = DefuserId)
		write_short(floatround(flNewTime))
		message_end()
	}
}

public bomb_planting(PlanterId)
{
	if(GetUserAccess(PlanterId) & DEFAULT_ACCESS)
	{
		set_pev(PlanterId, pev_maxspeed, PLANTING_SPEED.0)
	}
}

public bomb_planted(PlanterId)
{
	if(GetUserAccess(PlanterId) & DEFAULT_ACCESS)
	{
		new iPlantBonus = min(cs_get_user_money(PlanterId) + PLANTER_BONUS, MAX_MONEY)
		cs_set_user_money(PlanterId, iPlantBonus)
	}
}

public bomb_explode(PlanterId, DefuserId)
{
	if(GetUserAccess(PlanterId) & DEFAULT_ACCESS)
	{
		new iPlantBonus = min(cs_get_user_money(PlanterId) + BOMBER_BONUS, MAX_MONEY)
		cs_set_user_money(PlanterId, iPlantBonus)
	}
}

public bomb_defused(DefuserId)
{
	if(GetUserAccess(DefuserId) & DEFAULT_ACCESS)
	{
		new iDefuseBonus = min(cs_get_user_money(DefuserId) + (has_user_defuser(DefuserId) ? DEFUSER_BONUS_KIT : DEFUSER_BONUS), MAX_MONEY)
		cs_set_user_money(DefuserId, iDefuseBonus)
	}
}


