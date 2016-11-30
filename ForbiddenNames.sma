// Copyright © 2016 Vaqtincha
/******************************
*	Support forum:
*		http://goldsrc.ru
*
******************************/

/**■■■■■■■■■■■■■■■■■■■■■■■■■■■■ CONFIG START ■■■■■■■■■■■■■■■■■■■■■■■■■■■■*/

#define PLAYER_SET_NAME 	"CMEHI HIK"		// если закоментить то не пускает на сервер

// #define NAME_SPAM_CHECK_URL				// проверка url в нике
// #define NAME_SPAM_CHECK_IP				// проверка ip в нике

#define NAME_CUTTER				20			// обрезать длинные ники (макс 31)

// #define IMMUNITY_FLAG 	ADMIN_IMMUNITY 	//

#define	CONSOLE_INFO

new const g_szRejectReason[128] = 	"Запрещенный ник!" 

new const g_szBadnameList[][] = {

	"player",
	"noname",
	"admin",
	"madonna",

/**■■■■■■■■■■■■■■■■■■■■■■■■■■■■■ CONFIG END ■■■■■■■■■■■■■■■■■■■■■■■■■■■■■*/

	""
}

#include <amxmodx>
#include <fakemeta>


#if defined	NAME_SPAM_CHECK_URL || defined NAME_SPAM_CHECK_IP
	#include <regex>
	new g_iRet
	// %1 pattern, %2 flags
	#define PatternCompile(%1,%2)	regex_compile(%1, g_iRet, "", 0, %2)
#endif

#if defined NAME_SPAM_CHECK_IP
	new const g_pszIPsPattern[] = 
		"((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)"
	new Regex:g_rIPsCompiled
#endif

#if defined	NAME_SPAM_CHECK_URL
	new const g_pszDomainsPattern[] = 
		"(https?\:\/\/)?([a-z0-9]{1})((\.[a-z0-9-])|([a-z0-9-]))*\.([a-z]{2,4})(\/?)$"
	new Regex:g_rDomainsCompiled
#endif	


// %1 client, %2 new name
#define SetUserName(%1,%2) 		set_user_info(%1, NAME_KEY, %2)

new Trie:g_tData
new const NAME_KEY[] = "name"
new g_szHostAddress[32], g_szHostName[32]

public plugin_end()
{
	TrieDestroy(g_tData)
}


public plugin_init()
{
	register_plugin("Forbidden Names", "0.0.3", "Vaqtincha") 

	register_forward(FM_SetClientKeyValue, "SetClientKeyValue")

	get_user_ip(0, g_szHostAddress, charsmax(g_szHostAddress), .without_port = 1)
	get_user_name(0, g_szHostName, charsmax(g_szHostName))
	format(g_szHostAddress, charsmax(g_szHostAddress), "I Love <%s>", g_szHostAddress)
	format(g_szHostName, charsmax(g_szHostName), "I Love <%s>", g_szHostName)

	g_tData = TrieCreate()

	for(new i = 0; i < sizeof(g_szBadnameList)-1; i++)
	{
		TrieSetCell(g_tData, g_szBadnameList[i], 0)
	}

#if defined	NAME_SPAM_CHECK_URL
	g_rDomainsCompiled = PatternCompile(g_pszDomainsPattern, "i")
#endif
#if defined	NAME_SPAM_CHECK_IP
	g_rIPsCompiled = PatternCompile(g_pszIPsPattern, "")
#endif
}

public SetClientKeyValue(const pPlayer, const szInfoBuffer[], const szKey[], szValue[])
{
	if(!equal(szKey, NAME_KEY))
		return FMRES_IGNORED

#if defined IMMUNITY_FLAG
	if(get_user_flags(pPlayer) & IMMUNITY_FLAG)
		return FMRES_IGNORED
#endif

	new iResult = CheckBadName(szValue)
	
	if(iResult > 0)
	{
		client_print(pPlayer, print_chat, "[SERVER] %s", g_szRejectReason)

	#if defined PLAYER_SET_NAME
		SetUserName(pPlayer, iResult == 2 ? g_szHostName : iResult == 3 ? g_szHostAddress : PLAYER_SET_NAME)
	#else
		server_cmd("kick #%d ^"%s^"", get_user_userid(pPlayer), g_szRejectReason)
	#endif

		return FMRES_SUPERCEDE
	}
#if defined NAME_CUTTER
	else if(iResult == 0)
	{
		CheckNameLenght(pPlayer, szValue)
		return FMRES_SUPERCEDE
	}
#endif

	return FMRES_IGNORED
}

public client_authorized(pPlayer)
{
	if(is_user_bot(pPlayer) || is_user_hltv(pPlayer))
		return

#if defined IMMUNITY_FLAG
	if(get_user_flags(pPlayer) & IMMUNITY_FLAG)
		return
#endif

	new szName[32]
	get_user_info(pPlayer, NAME_KEY, szName, charsmax(szName))

	new iResult = CheckBadName(szName)

	if(iResult > 0)
	{
	#if defined	CONSOLE_INFO
		new szAddress[32]
		get_user_ip(pPlayer, szAddress, charsmax(szAddress), .without_port = 1)

		server_print("[Block Connect] ClientName: %s | Address: %s", szName, szAddress)
	#endif

	#if defined PLAYER_SET_NAME
		SetUserName(pPlayer, iResult == 2 ? g_szHostName : iResult == 3 ? g_szHostAddress : PLAYER_SET_NAME)
	#else
		server_cmd("kick #%d ^"%s^"", get_user_userid(pPlayer), g_szRejectReason)
	#endif
	}
#if defined NAME_CUTTER
	else
		CheckNameLenght(pPlayer, szName)
#endif
}

CheckBadName(szString[])
{
	if(CheckNameInArray(szString))
		return 1
#if defined	NAME_SPAM_CHECK_URL
	if(CheckSpamName(szString, g_rDomainsCompiled))
		return 2
#endif
#if defined	NAME_SPAM_CHECK_IP
	if(CheckSpamName(szString, g_rIPsCompiled, .bTrimSpaces = true))
		return 3
#endif
	return 0
}

bool:CheckNameInArray(szString[])
{
	strtolower(szString)
	return bool:(TrieKeyExists(g_tData, szString))
}

#if defined	NAME_SPAM_CHECK_URL || defined NAME_SPAM_CHECK_IP
bool:CheckSpamName(szString[], const Regex:rHandle, bool:bTrimSpaces = false)
{
	if(bTrimSpaces)
		while(replace(szString, strlen(szString)-1, " ", "")){}

	return bool:(regex_match_c(szString, rHandle, g_iRet) > 1)
}
#endif

#if defined NAME_CUTTER
CheckNameLenght(const pPlayer, szString[])
{
	if(strlen(szString) > NAME_CUTTER)
	{
		// server_print("[Block Connect] ClientName: %s | NameLen: %d", szString, strlen(szString))
		szString[NAME_CUTTER] = EOS
		SetUserName(pPlayer, szString)
	}
}
#endif







