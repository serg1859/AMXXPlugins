
// Вы можете заменить этот текст
new const PRINT_TEXT[] = "Во время разминки покупка запрещено!"


#include <amxmodx>
#include <re_warmup_api>

new g_iMsgIdTextMsg, g_iMsgHookTextMsg

public plugin_init()
{
	register_plugin("Warmup Replace Text", "0.0.1", "Vaqtincha")
	g_iMsgIdTextMsg	= get_user_msgid("TextMsg")
}

public WarmupStarted(WarmupModes:iMode, iTime)
{
	// server_print("TEST FORWARD: MODE %d | TIME %d", iMode, iTime)

	if(iMode != FREE_BUY && !g_iMsgHookTextMsg)
	{
		g_iMsgHookTextMsg = register_message(g_iMsgIdTextMsg, "Message_TextMsg")
	}
}

public WarmupEnded()
{
	unregister_message(g_iMsgIdTextMsg, g_iMsgHookTextMsg)
	g_iMsgHookTextMsg = 0
}

public Message_TextMsg(iMesgId, iMsgType, iMsgEnt)
{
	const PRINT_TYPE = 1
	const MESSAGE_STRING = 2

	// server_print("TEST HOOK: CALLING")
	if(get_msg_args() != 2 || get_msg_arg_int(PRINT_TYPE) != print_center)
		return PLUGIN_CONTINUE

	static szMessage[20]
	get_msg_arg_string(MESSAGE_STRING, szMessage, charsmax(szMessage))

	if(equal(szMessage, "#CT_cant_buy") || equal(szMessage, "#Terrorist_cant_buy"))
	{
		client_print(iMsgEnt, print_center, PRINT_TEXT)
		return PLUGIN_HANDLED 
	}
	return PLUGIN_CONTINUE
}



