//	Copyright © 2016 Vaqtincha

//■■■■■■■■■■■■■■■■■■■■■■■ CONFIG START ■■■■■■■■■■■■■■■■■■■■■■■//

#define BONUS_HEALTH			15
#define BONUS_HS_HEALTH			35
#define MAX_HEALTH				140

#define DEFAULT_ACCESS			ACCESS_OTHER
#define IGNORE_TEAM_KILL  		// 
#define ONLY_ALLOWED_MAPS 		// included in section [maps]

//■■■■■■■■■■■■■■■■■■■■■■■■ CONFIG END ■■■■■■■■■■■■■■■■■■■■■■■■//


#include <amxmodx>
#include <fun>
#include <vip_environment>


public plugin_init()
{
	register_plugin("Killer Healer", "0.0.2", "Vaqtincha")
#if defined ONLY_ALLOWED_MAPS
	if(!vip_environment_loaded() || !IsAllowedMap())
#else
	if(!vip_environment_loaded())
#endif
	{
		pause("ad")
	}
}

public UserPreKilled(iVictim, iKiller, iHitplace, iTeamKill)
{
	if(!iKiller || iVictim == iKiller)
	{
		return
	}
	if(/* !is_user_alive(iKiller) || */ ~GetUserAccess(iKiller) & DEFAULT_ACCESS)
	{
		return
	}
#if defined IGNORE_TEAM_KILL
	if(iTeamKill)
	{
		return
	}
#endif
	new iCurHealth = get_user_health(iKiller)
	if(iCurHealth < MAX_HEALTH)
	{
		new iBonusHealth = iHitplace == HIT_HEAD ? BONUS_HS_HEALTH : BONUS_HEALTH
		new iNewHealth = min(iCurHealth + iBonusHealth, MAX_HEALTH)

		set_user_health(iKiller, iNewHealth)
		set_hudmessage(0, 255, 100, -1.0, 0.15, 0, 1.0, 1.0, 0.1, 0.1, -1)
		show_hudmessage(iKiller, "Healed +%d hp", (iNewHealth - iCurHealth))
	}
}

