/*
		Плохие имена не могут писать чат и говорить в микро.
*/
new const BADNAME_CONFIG[] = "/BadNames.ini";

#include <amxmodx>

new const VERSION[] = "0.0.1_beta";

#if AMXX_VERSION_NUM < 183
const MAX_PLAYERS = 32;
#endif

new Array:g_aBadNames, g_iBadNamesSize;
//new g_pCvar_SetsBits;

public plugin_init()
{
	register_plugin("Bad Name Detector", VERSION, "wopox1337");
	register_cvar("badname_detector", VERSION, FCVAR_SERVER | FCVAR_SPONLY);
	
	//g_pCvar_SetsBits = register_cvar("badname_punishtype", "abc");
	
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

public Get_PunishPlayer(pPlayerId, const szPlayerName[])
{
	client_print(0, print_chat, "Зашёл игрок '%s' с недопустимым ником!", szPlayerName);
	
	log_to_file("BadNames_Detected.log", "Player: '%s'", szPlayerName);
}

public plugin_end()
{
	ArrayDestroy(g_aBadNames);
}
