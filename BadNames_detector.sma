/*
		Плагин: Bad Name Detector
		Автор: wopox1337
		Описание: Описание: Игрокам с не допустимыми именами блокируется чат и микрофон.
		
		Квары: badname_punishtype [a|b|ab]
				a - блокировать микрофон;
				b - блокировать чат;
*/

new const BADNAME_CONFIG[] = "/BadNames.ini";

#include <amxmodx>
#include <engine>

new const VERSION[] = "0.0.1";

#if AMXX_VERSION_NUM < 183
const MAX_PLAYERS = 32;
#endif

new Array:g_aBadNames, g_iBadNamesSize;
new g_bitBlockFlags;

enum
{
	BLOCK_VOICE		=	(1<<0),
	BLOCK_CHAT		=	(1<<1)
}


new g_bPunishedChatPlayers;

#define get_bit(%1,%2)		(%1 & (1 << (%2 & 31)))
#define set_bit(%1,%2)		(%1 |= (1 << (%2 & 31)))
#define reset_bit(%1,%2)	(%1 &= ~(1 << (%2 & 31)))

	//Thanks to Vaqtincha for this macros
#define ContainFlag(%1,%2) 			(containi(%1,%2) != -1)

public plugin_init()
{
	register_plugin("Bad Name Detector", VERSION, "wopox1337");
	register_cvar("badname_detector", VERSION, FCVAR_SERVER | FCVAR_SPONLY);
	
	register_cvar("badname_punishtype", "ab");
	
	new szCvarString[4];
	get_cvar_string("badname_punishtype", szCvarString, charsmax(szCvarString))
	
	if(ContainFlag(szCvarString, "a"))
	{
		g_bitBlockFlags |= BLOCK_VOICE
	}
	if(ContainFlag(szCvarString, "b"))
	{
		g_bitBlockFlags |= BLOCK_CHAT
	}
	
	if(!g_bitBlockFlags)
	{
		new szMsg[64];
		formatex(szMsg, charsmax(szMsg), "CVar badname_punishtype = '' (empty), plugin stopped!");
		set_fail_state(szMsg);
	}

	register_clcmd("say",		"Handler_say");
	register_clcmd("say_team",	"Handler_say");
	
	g_aBadNames = ArrayCreate(32);
}

public plugin_cfg()
{
	new szFileName[128], iFilePointer; 
	get_localinfo("amxx_configsdir", szFileName, charsmax(szFileName));
	add(szFileName, charsmax(szFileName), BADNAME_CONFIG);
	
	iFilePointer = fopen(szFileName, "rt");
	if(!iFilePointer)
	{
		new szMsg[64];
		formatex(szMsg, charsmax(szMsg), "Config file '%s' not loaded!", szFileName);
		set_fail_state(szMsg);
	}

	new szLine[32];
	while(!feof(iFilePointer))
	{
		fgets(iFilePointer, szLine, charsmax(szLine));
		trim(szLine);

		if(!szLine[0] || szLine[0] == ';')
		{
			continue;
		}
		
		ArrayPushString(g_aBadNames, szLine);
	}
	fclose(iFilePointer);

	g_iBadNamesSize = ArraySize(g_aBadNames);
	if(!g_iBadNamesSize)
	{
		new szMsg[64];
		formatex(szMsg, charsmax(szMsg), "Names are not found in the file '%s'!", szFileName);
		set_fail_state(szMsg);
	}
}


public client_putinserver(pPlayerId)
{
	if(is_user_bot(pPlayerId) || is_user_hltv(pPlayerId))
	{
		return;
	}

	CheckNickname(pPlayerId);
}

public client_infochanged(pPlayerId)

{
	if(!is_user_connected(pPlayerId))
	{
		return PLUGIN_CONTINUE;
	}

	CheckNickname(pPlayerId);

	return PLUGIN_CONTINUE;
}

public CheckNickname(pPlayerId)
{
	new szPlayerName[32];
	get_user_name(pPlayerId, szPlayerName, charsmax(szPlayerName));
	
	new szSuspectedName[charsmax(szPlayerName)];

	for(new i; i < g_iBadNamesSize; i++)
	{
		ArrayGetString(g_aBadNames, i, szSuspectedName, charsmax(szSuspectedName));
		
		//if(equali(szPlayerName,szSuspectedName))
		if(ContainFlag(szPlayerName,szSuspectedName))
		{
			Get_PunishPlayer(pPlayerId, szPlayerName);
			break;
		}
	}
}

public client_disconnect(pPlayerId)
{
	reset_bit(g_bPunishedChatPlayers, pPlayerId);

	set_speak(pPlayerId, SPEAK_ALL);
}

public Handler_say(pPlayerId)
{
	if(get_bit(g_bPunishedChatPlayers, pPlayerId))
	{
		client_print(pPlayerId, print_chat, "[BLOCKED] Ваш чат заблокирован! Смените ник со стандартного для разблокировки чата!");
		client_cmd(pPlayerId, "spk buttons/blip1.wav");
		
		return PLUGIN_HANDLED;
	}

	return PLUGIN_CONTINUE;
}

public Get_PunishPlayer(pPlayerId, const szPlayerName[])
{
	if(g_bitBlockFlags & BLOCK_VOICE)
	{
		set_speak(pPlayerId, SPEAK_MUTED);
	}
	if(g_bitBlockFlags & BLOCK_CHAT)
	{
		set_bit(g_bPunishedChatPlayers, pPlayerId);
	}

	set_task(5.0, "task_ShowMessage", pPlayerId);
	log_to_file("BadNames_Detected.log", "Player: '%s'", szPlayerName);
}

public task_ShowMessage(pPlayerId)
{
	set_hudmessage(.red = 255, .x = 0.4, .y = -1.0, .effects = 1, .fxtime = 3.0, .holdtime = 5.0);
	show_hudmessage(pPlayerId, "Вам заблокирован доступ к чату^nсмените ник для разблокировки!");
}

public plugin_end()
{
	ArrayDestroy(g_aBadNames);
}
