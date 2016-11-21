/*
		Плохие иемна не могут писать чат и говорить в микро.
*/
new const BADNAME_CONFIG[] = "/BadNames.ini";

#include <amxmodx>

new const VERSION[] = "0.0.1";

#if AMXX_VERSION_NUM < 183
const MAX_PLAYERS = 32;
#endif

new Array:g_aBadNames, g_iBadNamesSize;
//new g_pCvar_SetsBits;

new g_bPunishedPlayers;

#define get_bit(%1,%2)		(%1 & (1 << (%2 & 31)))
#define set_bit(%1,%2)		(%1 |= (1 << (%2 & 31)))
#define reset_bit(%1,%2)	(%1 &= ~(1 << (%2 & 31)))

public plugin_init()
{
	register_plugin("Bad Name Detector", VERSION, "wopox1337");
	register_cvar("badname_detector", VERSION, FCVAR_SERVER | FCVAR_SPONLY);
	
	//g_pCvar_SetsBits = register_cvar("badname_punishtype", "abc");
	
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


public client_authorized(pPlayerId)
{
	if(is_user_bot(pPlayerId) || is_user_hltv(pPlayerId))
	{
		return;
	}
	
	new szPlayerName[32];
	get_user_name(pPlayerId, szPlayerName, charsmax(szPlayerName));
	
	new szSuspectedName[charsmax(szPlayerName)];

	for(new i; i < g_iBadNamesSize; i++)
	{
		ArrayGetString(g_aBadNames, i, szSuspectedName, charsmax(szSuspectedName));
		
		if(equali(szPlayerName,szSuspectedName))
		{
			Get_PunishPlayer(pPlayerId, szPlayerName);
			break;
		}
	}
}

public client_disconnect(pPlayerId)
{
	reset_bit(g_bPunishedPlayers, pPlayerId);
}

public Handler_say(pPlayerId)
{
	if(get_bit(g_bPunishedPlayers, pPlayerId))
	{
		client_print(pPlayerId, print_chat, "Ваш чат заблокирован! Смените ник со стандартного для разблокировки чата!");
		return PLUGIN_HANDLED;
	}

	return PLUGIN_CONTINUE;
}

public Get_PunishPlayer(pPlayerId, const szPlayerName[])
{
	set_bit(g_bPunishedPlayers, pPlayerId);

	client_print(0, print_chat, "Зашёл игрок '%s' с недопустимым ником!", szPlayerName);
	set_hudmessage(.red = 255, .x = 0.4, .y = -1.0, .effects = 1, .fxtime = 3.0, .holdtime = 5.0);
	show_hudmessage(pPlayerId, "Вам заблокирован доступ к чату^nсмените ник для разблокировки!");
	
	log_to_file("BadNames_Detected.log", "Player: '%s'", szPlayerName);
}

public plugin_end()
{
	ArrayDestroy(g_aBadNames);
}
