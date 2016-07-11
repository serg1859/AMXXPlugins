//	Copyright © 2016 Vaqtincha

//■■■■■■■■■■■■■■■■■■■■■■■ CONFIG START ■■■■■■■■■■■■■■■■■■■■■■■//

#define PREFIX_CHAT 		"[V.I.P]"
#define PREFIX_RADIO 		"[V.I.P]"
#define DEFAULT_ACCESS		ACCESS_OTHER

//■■■■■■■■■■■■■■■■■■■■■■■■ CONFIG END ■■■■■■■■■■■■■■■■■■■■■■■■//

#include <amxmodx>
#include <vip_environment>

#define SetUserAccess(%1)			g_bHasAccess |= 1<<(%1 & 31)
#define ClearUserAccess(%1)			g_bHasAccess &= ~( 1<<(%1 & 31))
#define CheckAccess(%1)				(g_bHasAccess &  1<<(%1 & 31))

const SayText_SenderId = 1
const SayText_SubMsg = 2
const TextMsg_SenderId = 2
const TextMsg_SubMsg = 3

new g_bHasAccess
new Trie:g_tChannels


public plugin_init() 
{
	register_plugin("VIP Prefix", "0.0.1", "Vaqtincha")
	if(!vip_environment_loaded())
	{
		pause("ad")
	}
#if defined PREFIX_CHAT || defined PREFIX_RADIO
	new szTemp[192]
#endif
	g_tChannels = TrieCreate()

#if defined PREFIX_CHAT
	register_message(get_user_msgid("SayText"), "Message_SayText")

	formatex(szTemp, charsmax(szTemp), "(Counter-Terrorist) %s %%s1 :  %%s2", PREFIX_CHAT) 
	TrieSetString(g_tChannels, "#Cstrike_Chat_CT", szTemp)

	formatex(szTemp, charsmax(szTemp), "(Terrorist) %s %%s1 :  %%s2", PREFIX_CHAT) 
	TrieSetString(g_tChannels, "#Cstrike_Chat_T", szTemp)

	formatex(szTemp, charsmax(szTemp), "*DEAD*(Counter-Terrorist) %s %%s1 :  %%s2", PREFIX_CHAT) 
	TrieSetString(g_tChannels, "#Cstrike_Chat_CT_Dead", szTemp)

	formatex(szTemp, charsmax(szTemp), "*DEAD*(Terrorist) %s %%s1 :  %%s2", PREFIX_CHAT) 
	TrieSetString(g_tChannels, "#Cstrike_Chat_T_Dead", szTemp)

	formatex(szTemp, charsmax(szTemp), "(Spectator) %s %%s1 :  %%s2", PREFIX_CHAT) 
	TrieSetString(g_tChannels, "#Cstrike_Chat_Spec", szTemp)

	formatex(szTemp, charsmax(szTemp), "%s %%s1 :  %%s2", PREFIX_CHAT) 
	TrieSetString(g_tChannels, "#Cstrike_Chat_All", szTemp)

	formatex(szTemp, charsmax(szTemp), "*DEAD* %s %%s1 :  %%s2", PREFIX_CHAT) 
	TrieSetString(g_tChannels, "#Cstrike_Chat_AllDead", szTemp)

	formatex(szTemp, charsmax(szTemp), "*SPEC* %s %%s1 :  %%s2", PREFIX_CHAT) 
	TrieSetString(g_tChannels, "#Cstrike_Chat_AllSpec", szTemp)
#endif
#if defined PREFIX_RADIO
	register_message(get_user_msgid("TextMsg"), "Message_TextMsg")
	formatex(szTemp, charsmax(szTemp), "%s %%s1 (RADIO): %%s2", PREFIX_RADIO) 
	TrieSetString(g_tChannels, "#Game_radio", szTemp)
#endif
}

public ConfigReloaded()
{
	new iPlayers[32], iNum, iPlayerId
	get_players(iPlayers, iNum, "ch")
	for(new i = 0; i < iNum; i++)
	{
		iPlayerId = iPlayers[i] 
		if(GetUserAccess(iPlayerId) & DEFAULT_ACCESS)
		{
			SetUserAccess(iPlayerId)
		}else{
			ClearUserAccess(iPlayerId)
		}
	}
}

public client_putinserver(id)
{
	if(!is_user_hltv(id) && GetUserAccess(id) & DEFAULT_ACCESS)
	{
		SetUserAccess(id)
	}else{
		ClearUserAccess(id)
	}
}

public client_disconnect(id)
{
	ClearUserAccess(id)
}

public Message_SayText(iMesgId, iMsgType, iMsgEnt)
{
	if(get_msg_args() != 4)
	{
		return PLUGIN_CONTINUE
	}

	new szTemp[192]
	get_msg_arg_string(SayText_SubMsg, szTemp, charsmax(szTemp))
	
	if(TrieGetString(g_tChannels, szTemp, szTemp, charsmax(szTemp)))
	{
		if(CheckAccess(get_msg_arg_int(SayText_SenderId)))
		{
			set_msg_arg_string(SayText_SubMsg, szTemp)
		}
	}

	return PLUGIN_CONTINUE
}

public Message_TextMsg(iMesgId, iMsgType, iMsgEnt)
{
	if(get_msg_args() != 5)
	{
		return PLUGIN_CONTINUE
	}

	new szTemp[192]
	get_msg_arg_string(TextMsg_SubMsg, szTemp, charsmax(szTemp))

	if(TrieGetString(g_tChannels, szTemp, szTemp, charsmax(szTemp)))
	{
		new szSender[4]
		get_msg_arg_string(TextMsg_SenderId, szSender, charsmax(szSender))
		if(CheckAccess(str_to_num(szSender)))
		{
			set_msg_arg_string(TextMsg_SubMsg, szTemp)
		}
	}

	return PLUGIN_CONTINUE
}

public plugin_end()
{
	if(g_tChannels)
	{
		TrieDestroy(g_tChannels)
	}
}

