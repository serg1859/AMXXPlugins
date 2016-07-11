//	Copyright © 2016 Vaqtincha

//■■■■■■■■■■■■■■■■■■■■■■■ CONFIG START ■■■■■■■■■■■■■■■■■■■■■■■//

#define DEFAULT_ACCESS			ACCESS_BUY_MENU

//■■■■■■■■■■■■■■■■■■■■■■■■ CONFIG END ■■■■■■■■■■■■■■■■■■■■■■■■//

#include <amxmodx>
#include <fakemeta>
#include <hamsandwich>
#include <vip_environment>

public plugin_init()
{
	register_plugin("Strip Weapons on Death", "0.0.1", "Vaqtincha")
	if(!vip_environment_loaded() || !IsAllowedMap())
	{
		pause("ad")
	}
}

public UserPreKilled(iVictim, iKiller, iHitplace, iTeamKill)
{
	if(~GetUserAccess(iVictim) & DEFAULT_ACCESS)
	{
		return
	}

	new iSlot
	for(iSlot = 1; iSlot<= 2; iSlot++) // only primary & secondary
	{
		new wEnt = get_pdata_cbase(iVictim, m_rgpPlayerItems_CBasePlayer[iSlot])
		while(wEnt > 0)
		{
			if(START_IMPULSE <= GetCustomWeapon(wEnt) <= FINITE_IMPULSE)
			{
				ham_strip_user_weapon(iVictim, cs_get_weapon_id(wEnt), iSlot, .bSwitchIfActive = false)
			}
			wEnt = get_pdata_cbase(wEnt, m_pNext, XO_WEAPON)
		}
	}
}





