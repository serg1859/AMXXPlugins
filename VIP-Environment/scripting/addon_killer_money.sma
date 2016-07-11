//	Copyright © 2016 Vaqtincha

//■■■■■■■■■■■■■■■■■■■■■■■ CONFIG START ■■■■■■■■■■■■■■■■■■■■■■■//

#define KILL_MONEY				350
#define KILL_HS_MONEY			400
#define KILL_TEAM_PENALTY		-100

#define MAX_MONEY				16000

#define DEFAULT_ACCESS			ACCESS_OTHER
// #define ONLY_ALLOWED_MAPS 	// included in section [maps]

//■■■■■■■■■■■■■■■■■■■■■■■■ CONFIG END ■■■■■■■■■■■■■■■■■■■■■■■■//

#include <amxmodx>
#include <fakemeta>
#include <vip_environment>

const Money_Amount = 1
const Money_Flash = 2

new g_iNewMoney[MAX_PLAYERS+1]

public plugin_init()
{
	register_plugin("Killer Money", "0.0.3", "Vaqtincha")
#if defined ONLY_ALLOWED_MAPS
	if(!vip_environment_loaded() || !IsAllowedMap())
#else
	if(!vip_environment_loaded())
#endif
	{
		pause("ad")
	}
	register_message(get_user_msgid("Money"), "Message_Money")
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
#if defined KILL_TEAM_PENALTY
	g_iNewMoney[iKiller] = clamp(cs_get_user_money(iKiller) + (iTeamKill ? KILL_TEAM_PENALTY : iHitplace == HIT_HEAD ? KILL_HS_MONEY : KILL_MONEY), 0, MAX_MONEY)
#else
	g_iNewMoney[iKiller] = clamp(cs_get_user_money(iKiller) + (iHitplace == HIT_HEAD ? KILL_HS_MONEY : KILL_MONEY), 0, MAX_MONEY)
#endif
}

public Message_Money(iMsgId, iMsgDest, id)
{
	if(is_user_connected(id) && g_iNewMoney[id])
	{
		set_msg_arg_int(Money_Amount, ARG_LONG, g_iNewMoney[id])
		// set_msg_arg_int(Money_Flash, ARG_BYTE, 1) // is already = 1
		set_pdata_int(id, m_iAccount, g_iNewMoney[id])
		g_iNewMoney[id] = 0
	}
}



