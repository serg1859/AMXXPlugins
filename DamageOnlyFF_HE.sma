// Блокировать урон гранаты тиммейтов? (или всего кроме гранаты)
//#define INVERSE

// Не шатать прицелы тиммейтов, при попадании?
#define NO_SHAKEPLAYERS

// Idea author: Katastrofa

#include <amxmodx>
#include <reapi>

public plugin_init() 
{
	register_plugin("Damage only from FF HE", "0.0.2", "wopox1337");
	RegisterHookChain(RG_CBasePlayer_TakeDamage, "CBasePlayer_TakeDamage_Pre", .post = false);
	#if !defined NO_SHAKEPLAYERS
	register_message(get_user_msgid("TextMsg"), "Message_TextMsg");
	#endif
}

public CBasePlayer_TakeDamage_Pre(const victim, inflictor, attacker, Float:damage, damagebits )
{
	#if !defined INVERSE
	if(!is_user_connected(attacker) || (damagebits & (DMG_GRENADE|DMG_BLAST)))
	#else
	if(victim == inflictor || !is_user_connected(attacker) || !(damagebits & (DMG_GRENADE|DMG_BLAST)))
	#endif
	{
		return HC_CONTINUE;
	}

	if(get_member(victim, m_iTeam) == get_member(attacker, m_iTeam))
	{
		#if defined NO_SHAKEPLAYERS
		SetHookChainReturn(ATYPE_INTEGER, 0);
		return HC_SUPERCEDE;
		#else
		SetHookChainArg(4, ATYPE_FLOAT, 0.0);
		#endif
	}

	return HC_CONTINUE;
}

#if !defined NO_SHAKEPLAYERS
	// Thanks to ConnorMcLeod for this
public Message_TextMsg(iMsgId, iMsgDest, id)
{
    if(id)
    {
        static szMsg[23];
        get_msg_arg_string(2, szMsg, charsmax(szMsg));
        	// must be optimise
        //return equal(szMsg, "#Game_teammate_attack");
        return (szMsg[3] == 'm' && szMsg[6] == 't' && szMsg[15] == 'a');
    }
    return PLUGIN_CONTINUE;
}
#endif
