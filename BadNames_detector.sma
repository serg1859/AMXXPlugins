/*
		Плагин: Bad Name Detector
		Автор: wopox1337
		Описание: Игрокам с не допустимыми именами блокируется чат и микрофон.
			Имена берутся из файла '/amxmodx/configs/BadNames.ini"
		
		Квары: badname_punishtype [a|b|ab]
				a - блокировать микрофон;
				b - блокировать чат;
*/

new const BADNAME_CONFIG[] = "/BadNames.ini";

#include <amxmodx>
#include <engine>

new const VERSION[] = "0.0.3a";

#if AMXX_VERSION_NUM < 183
const MAX_NAME_LENGTH	= 32;
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
#define ContainWord(%1,%2) 			(containi(%1,%2) != -1)

new g_iMsgId_SendAudio;

public plugin_init()
{
	register_plugin("Bad Name Detector", VERSION, "wopox1337");
	register_cvar("badname_detector", VERSION, FCVAR_SERVER | FCVAR_SPONLY);
	
	register_cvar("badname_punishtype", "ab");
	
	new szCvarString[3];
	get_cvar_string("badname_punishtype", szCvarString, charsmax(szCvarString))
	
	if(ContainWord(szCvarString, "a"))
	{
		g_bitBlockFlags |= BLOCK_VOICE
	}
	if(ContainWord(szCvarString, "b"))
	{
		g_bitBlockFlags |= BLOCK_CHAT
		
		register_clcmd("say",		"hCommand_Say");
		register_clcmd("say_team",	"hCommand_Say");
		
		g_iMsgId_SendAudio = get_user_msgid("SendAudio");
	}
	
	if(!g_bitBlockFlags)
	{
		new szMsg[64];
		formatex(szMsg, charsmax(szMsg), "CVar badname_punishtype = '' (empty), plugin stopped!");
		set_fail_state(szMsg);
	}

	g_aBadNames = ArrayCreate(MAX_NAME_LENGTH);
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

public client_infochanged(pPlayerId)
{
	if(!is_user_connected(pPlayerId) || is_user_bot(pPlayerId) || is_user_hltv(pPlayerId))
	{
		return PLUGIN_CONTINUE;
	}

	CheckNickname(pPlayerId);

	return PLUGIN_CONTINUE;
}

public CheckNickname(pPlayerId)
{
	new szNewName[MAX_NAME_LENGTH], szOldName[MAX_NAME_LENGTH];
	get_user_name(pPlayerId, szOldName, charsmax(szOldName));
	get_user_info(pPlayerId, "name", szNewName, charsmax(szNewName));

	if(equal(szNewName, szOldName))
	{
		return PLUGIN_CONTINUE;
	}

	for(new i, szSuspectedName[charsmax(szNewName)]; i < g_iBadNamesSize; i++)
	{
		ArrayGetString(g_aBadNames, i, szSuspectedName, charsmax(szSuspectedName));
		
		//if(equali(szNewName,szSuspectedName))
		if(ContainWord(szNewName,szSuspectedName))
		{
			Get_PunishPlayer(pPlayerId, szNewName);

			return PLUGIN_CONTINUE;
		}
	}

	Reset_PunishBits(pPlayerId);

	return PLUGIN_CONTINUE;
}

public client_disconnect(pPlayerId)
{
	reset_bit(g_bPunishedChatPlayers, pPlayerId);
}

public hCommand_Say(pPlayerId)
{
	if(get_bit(g_bPunishedChatPlayers, pPlayerId))
	{
		client_print(pPlayerId, print_chat, "[BLOCKED] Ваш чат заблокирован! Смените ник со стандартного для разблокировки чата!");
		SendAudio(pPlayerId, "sound/buttons/blip1.wav");
		
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
	
	// Логирование (temp)
	log_to_file("BadNames_Detected.log", "Player: '%s'", szPlayerName);
}

public task_ShowMessage(pPlayerId)
{
	if(!is_user_connected(pPlayerId))
	{
		return PLUGIN_HANDLED;
	}
	
	set_hudmessage(.red = 255, .x = 0.4, .y = -1.0, .effects = 1, .fxtime = 3.0, .holdtime = 5.0);
	show_hudmessage(pPlayerId, "Вам заблокирован доступ к чату^nсмените ник для разблокировки!");
	
	return PLUGIN_CONTINUE;
}

public plugin_end()
{
	ArrayDestroy(g_aBadNames);
}

Reset_PunishBits(pPlayerId)
{
	reset_bit(g_bPunishedChatPlayers, pPlayerId);
	set_speak(pPlayerId, SPEAK_ALL);
}

stock SendAudio(pPlayerId, const szDirSound[])
{
   message_begin(MSG_ONE_UNRELIABLE, g_iMsgId_SendAudio, .player = pPlayerId);
   write_byte(pPlayerId);
   write_string(szDirSound);
   write_short(PITCH_NORM);
   message_end();
}
