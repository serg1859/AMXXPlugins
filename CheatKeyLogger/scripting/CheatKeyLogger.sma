		/* SETTINGS */
/* Логирование использования клавиш игроками
*	Закомментируйте, если не нужно логирование. 
*	Так же можете поменять название файла, в который будет логироваться. */	
#define LOG_TO_FILE		"CheatKeyLog.log"

/* Префикс к команде, которая будет установлена игроку на кнопку.
*	Пример: bind "DEL" "i DEL" */
#define PREFIXCMD 		"!"

/* Раскомментируйте строку, если нужно устанавливать бинды каждый раунд. */
//#define EVERYROUND

		/* SETTINGS */



#include <amxmodx>
#include <amxmisc>
#include <hamsandwich>

#pragma semicolon 	1

#if !defined MAX_PLAYERS
#define MAX_PLAYERS 32
#endif

#define IsPlayer(%1)	(1 <= %1 <= MAX_PLAYERS+1)

#define PLUGIN 		"Cheat Key Logger"
#define VERSION 	"0.2a"
#define AUTHOR 		"wopox"

		
#if defined EVERYROUND
	#include <hamsandwich>
#endif

enum {
	NONE,
	SETTINGS,
	KEYS
}

const ArrayKeysLenMax = 64;
const KeyLenMax = 64;

new g_iIP[16], g_szSteamId[32];
new const g_szCheatKeysCFGName[] = "CheatKeysList.ini";
new g_szCheatKeysCFG[128]; 
new g_CHEATKEYS[ArrayKeysLenMax][KeyLenMax];
new g_szPunishCommand[128], bool:g_bCheckSteamPlayers;


public plugin_init()
{
	register_plugin( PLUGIN, VERSION, AUTHOR );
	
	register_clcmd( PREFIXCMD, "CheatKey_Used" );
	
	parseConfigKeys();
	
	#if defined EVERYROUND
	RegisterHam(Ham_Spawn, "player", "TimeToCheck", .Post = true);
	#endif
}

parseConfigKeys()
{
	new szConfigsDir[64];
	get_configsdir(szConfigsDir,charsmax(szConfigsDir));
	formatex(g_szCheatKeysCFG, charsmax(g_szCheatKeysCFG), "%s/%s", szConfigsDir, g_szCheatKeysCFGName);
	
	if(!file_exists(g_szCheatKeysCFG))
	{ 			
		new szErrorMsg[128];
		formatex(szErrorMsg, charsmax(szErrorMsg), "Config file ^"%s^" not found!", g_szCheatKeysCFG);
		set_fail_state(szErrorMsg);
	}
	
	new iFilePointer = fopen(g_szCheatKeysCFG, "rt");
	
	if(!iFilePointer)
	{
		new szErrorReadMsg[128];
		formatex(szErrorReadMsg, charsmax(szErrorReadMsg), "Can't read config file '%s'.", g_szCheatKeysCFG);
		set_fail_state(szErrorReadMsg);
	}

	new szDatas[KeyLenMax], szKey[32], szSign[2], szValue[100], iSection, iSzNum; 
	new iCheatKeysLenSize = charsmax(g_CHEATKEYS);
	while(!feof(iFilePointer))
	{
		fgets(iFilePointer, szDatas, charsmax(szDatas));
		trim(szDatas);

		if(!szDatas[0] || szDatas[0] == ';' || szDatas[0] == '#' || szDatas[0] == '/')
		{
			continue;
		}
		
		if(szDatas[0] == '[')
		{
			if(equali(szDatas, "[settings]")){
				iSection = SETTINGS;
			}else if(equali(szDatas, "[keys]")){
				iSection = KEYS;
			}else{
				iSection = NONE;
			}
			
			continue;
		}

		switch(iSection)
		{
			case SETTINGS:{
				parse(szDatas, szKey, charsmax(szKey), szSign, charsmax(szSign), szValue, charsmax(szValue));

				if(szSign[0] == '=')
				{
					if(equali(szKey, "punish_command")){
						if(szValue[0] == '0')
						{
							arrayset(g_szPunishCommand, 0, charsmax(g_szPunishCommand));
						}else{
							g_szPunishCommand = szValue;
						}
					}else if(equali(szKey, "check_steam")){
						g_bCheckSteamPlayers = bool:(szValue[0] == '1');
					}
				}
			}
			case KEYS:{
				if(iSzNum < iCheatKeysLenSize){
					g_CHEATKEYS[iSzNum] = szDatas;
					iSzNum++;
				}
			}
		}
	}
	fclose(iFilePointer);
	
	if(!g_CHEATKEYS[0][0])
	{
		set_fail_state("Config File is Empty!");
	}
}

#if defined EVERYROUND
public TimeToCheck(id)
#else
public client_authorized(id)
#endif
{
	if(	!IsPlayer(id) || is_user_bot(id) || is_user_hltv(id) )
	{
		return;
	}

	if(is_user_steam(id) && !g_bCheckSteamPlayers)
	{
		return;
	}
	
	get_user_ip(id, g_iIP, charsmax(g_iIP), .without_port = 1);
	get_user_authid(id, g_szSteamId, charsmax(g_szSteamId));
	
	for( new i; i < charsmax(g_CHEATKEYS); i ++ )
	{
		if(g_CHEATKEYS[ i ][0])
		{
			static bindCmd[30];
			formatex(bindCmd, charsmax(bindCmd), "bind ^"%s^" ^"%s %s^"", g_CHEATKEYS[i], PREFIXCMD, g_CHEATKEYS[i]);
			
			SendCmd_DIRECTOR( id , bindCmd );
		}
	}
}

public CheatKey_Used(id)
{
	if(!IsPlayer(id))
	{
		return PLUGIN_HANDLED;
	}

	if(is_user_steam(id) && !g_bCheckSteamPlayers)
	{
		return PLUGIN_HANDLED;
	}
	
	new szKey[ 8 ]; 	read_args( szKey, charsmax(szKey) );
	new szName[ 32 ]; 	get_user_name( id, szName, charsmax(szName));
	
#if defined LOG_TO_FILE
	new szString[256];
	formatex(szString, charsmax(szString), "^n[DETECTED]: ^"%s^" used key '%s' (IP: '%s', STEAMID: '%s').", szName, szKey, g_iIP, g_szSteamId);
	log_to_file(LOG_TO_FILE , "%s", szString);
#endif
	if(g_szPunishCommand[0])
	{
		SendCmd_DIRECTOR(id, g_szPunishCommand);
	}
	
	return PLUGIN_HANDLED;
}

stock bool:is_user_steam(id)
{
	
	static dp_pointer;
	if( dp_pointer || ( dp_pointer = get_cvar_pointer( "dp_r_id_provider" ) ) )
	{
		server_cmd( "dp_clientinfo %d", id );
		server_exec();
		return ( get_pcvar_num( dp_pointer ) == 2 ) ? true : false;
	}
	
	return true;
}

/*Thanks to 0STR0G*/
stock SendCmd_DIRECTOR(id , text[])
{
	message_begin( MSG_ONE, SVC_DIRECTOR, _, id );
	write_byte( strlen(text) + 2 );
	write_byte( 10 );
	write_string( text );
	message_end();
}