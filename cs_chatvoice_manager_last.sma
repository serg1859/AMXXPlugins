/* Доработка от wopox1337 
	- Добавлена поддержка colorchat (183, 182)


*/
#define USE_ReAPI

#pragma semicolon					1

#include <amxmodx>
#include <fakemeta>

#if defined USE_ReAPI
	#include <reapi>
#else
#include <hamsandwich>
#endif

#if AMXX_VERSION_NUM < 183
	#include <colorchat>

	#define print_team_default	DontChange
	#define print_team_grey		Grey
	#define print_team_red		Red
	#define print_team_blue		Blue
	#define client_print_color	ColorChat 
	
	const MAX_PLAYERS 			= 32;
#endif

#define PLUGIN_NAME					"[CS] Chat & Voice Manager"
#define PLUGIN_VERS					"0.3ADDDDDDD"
#define PLUGIN_AUTH					"81x08"

#define SetBit(%0,%1) 				((%0) |= (1 << (%1)))
#define ClearBit(%0,%1) 			((%0) &= ~(1 << (%1)))
#define IsSetBit(%0,%1) 			((%0) & (1 << (%1)))
#define IsNotSetBit(%0,%1) 			(~(%0) & (1 << (%1)))

#define CVM_CHAT_PREFIX				"[CVM]"

#define CVM_MODE_AES				/* AES by serfreeman1337  			*/
#define CVM_MODE_CSSTATS_SQL		/* CSSTATS SQL by serfreeman1337	*/

#define CVM_HIDE_IMMUNITY			/* Скрывать ли игрока у которого иммунитет или админка из меню Gag и VoteGag */

#define CVM_GAG_ACCESS				"abc"	/* Флаги для открытия Gag меню */
#define CVM_IMMUNITY_FLAGS			"a"		/* Флаги иммунитета, от блокировки чата\голоса */
#define CVM_FLAGS_LISTEN_ALL		"b"		/* Флаги для прослушивания всех игроков (независимо от настроек) */

#define CVM_SHOW_TEXT_GAG			0		/* [0 - ALL | 1 - ADMIN & PLAYER] Кому показывать сообщение о гаге */

#define CVM_TIME_VOTE_GAG			15		/* Время в секундах, сколько длится голосование VoteGag */
#define CVM_NEXT_VOTE_GAG			30		/* Время в секундах, до возможного следующего VoteGag */

#if defined CVM_MODE_AES
	#define CVM_AES_RANK_USE_CHAT	2	/* Ранг, который должен иметь игрок, чтобы использовать чат */
	#define CVM_AES_RANK_USE_VOICE	5	/* Ранг, который должен иметь игрок, чтобы использовать микрофон */
	
	new g_szRankNameChat[40];
	
	new gp_iRank[MAX_PLAYERS + 1 char];
	
	native aes_get_player_stats(const pId, const iStats[4]);
	native aes_get_level_name(const iLevel, const szRankName[], const iLen, const iIdLang = LANG_SERVER);
#endif

#if defined CVM_MODE_CSSTATS_SQL
	#define CVM_CSSTATS_FRAG_USE_CHAT	20 /* Кол-во убийств, для использования чата */
	#define CVM_CSSTATS_FRAG_USE_VOICE	30 /* Кол-во убийств, для использования голосового чата */

	new gp_iFrags[MAX_PLAYERS + 1 char];

	native get_user_stats_sql(const pId, const iStats[8], const iBodyHits[8]);
#endif

#if !defined USE_ReAPI
enum TeamName
{
	TEAM_UNASSIGNED,
	TEAM_TERRORIST,
	TEAM_CT,
	TEAM_SPECTATOR
};
#endif


enum _: ENUM_DATA_PL_VOTE_GAG	{
	PL_VOTE_GAG_ID,
	PL_VOTE_GAG_TYPE,
	PL_VOTE_GAG_TIME
};

enum _: ENUM_DATA_GAG_TYPE	{
	GAG_TYPE_NONE,

	GAG_TYPE_CHAT,
	GAG_TYPE_VOICE,
	GAG_TYPE_COMMAND_CHAT,
	GAG_TYPE_ALL
};

enum _: ENUM_DATA_PLAYER_GAG	{
	PL_GAG_TYPE,
	PL_GAG_TIME
};

enum _: ENUM_DATA_BITS	{
	BIT_NULL,
	
	BIT_ALIVE,
	BIT_ACCESS,
	BIT_GAGGED,
	BIT_MUTTED[MAX_PLAYERS + 1 char],
	BIT_IMMUNITY,
	BIT_CONNECTED,
	BIT_LISTEN_ALL,
	
	BIT_MAX
};

new const g_iGagTimes[] = {5, 10, 30, 60, 120, 180};

new const g_szGagTypes[][] = {'^0', "Chat", "Voice", "Team chat", "ALL"};

new g_iMaxPlayers;

new	g_iVoteTotalNo,
	g_iVoteTotalYes,
	g_iVotePlayerGag[ENUM_DATA_PL_VOTE_GAG];

new gp_iMenuTarget[MAX_PLAYERS + 1 char],
	gp_iMenuPlayers[MAX_PLAYERS + 1 char][MAX_PLAYERS],
	gp_iMenuPosition[MAX_PLAYERS + 1 char];
	
new gp_iBit[ENUM_DATA_BITS],
	gp_iGag[MAX_PLAYERS + 1 char][ENUM_DATA_PLAYER_GAG],
	gp_iTeam[MAX_PLAYERS + 1 char];

new gp_szIP[MAX_PLAYERS + 1 char][16];

new Trie: g_tPlayerGag;

/* Cvar's Pointers */
new pCvar_HearEnemy,
	pCvar_HearDeath,
	pCvar_DeathHearAlive;

/* Bool's from cvars */
new g_bHearEnemy		= false,
	g_bHearDeath		= false,
	g_bDeathHearAlive	= false;

/*================================================================================
 [PLUGIN]
=================================================================================*/
public plugin_init()	{
	/* [PLUGIN] */
	register_plugin(PLUGIN_NAME, PLUGIN_VERS, PLUGIN_AUTH);
	
	/* [CVAR'S] */
	register_cvar("cvm_HearEnemy", "1");         /* Слышит ли игрок противника */
	register_cvar("cvm_HearDeath", "1");         /* Слышит ли живой игрок мёртвого игрока */
	register_cvar("cvm_DeathHearAlive", "1");    /* Слышит ли мёртвый игрок живого игрока */
	
	if(get_cvar_num("cvm_HearEnemy"))
	{
		g_bHearEnemy = true;
	}
	
	if(get_cvar_num("cvm_HearDeath"))
	{
		g_bHearDeath = true;
	}
	
	if(get_cvar_num("cvm_DeathHearAlive"))
	{
		g_bDeathHearAlive = true;
	}
	
	/* [CLCMD] */
	register_clcmd("say", "ClCmd_HookSay");
	register_clcmd("say_team", "ClCmd_HookSayTeam");

	register_clcmd("cvm_gag", "ClCmd_Gag");
	register_clcmd("say /gag", "ClCmd_Gag");
	
	register_clcmd("say /mute", "ClCmd_Mute");

	register_clcmd("say /vg", "ClCmd_VoteGag");
	register_clcmd("say /votegag", "ClCmd_VoteGag");

	/* [MENUCMD] */
	register_menucmd(register_menuid("Show_GagMenu"), 1023, "Handler_GagMenu");
	register_menucmd(register_menuid("Show_MuteMenu"), 1023, "Handler_MuteMenu");
	register_menucmd(register_menuid("Show_ChooseGagType"), 1023, "Handler_ChooseGagType");
	register_menucmd(register_menuid("Show_ChooseGagTime"), 1023, "Handler_ChooseGagTime");

	register_menucmd(register_menuid("Show_VoteGagMenu"), 1023, "Handler_VoteGagMenu");
	register_menucmd(register_menuid("Show_ChooseVoteGagType"), 1023, "Handler_ChooseVoteGagType");
	register_menucmd(register_menuid("Show_ChooseVoteGagTime"), 1023, "Handler_ChooseVoteGagTime");
	register_menucmd(register_menuid("Show_ChooseVoteGagAnswer"), 1023, "Handler_ChooseVoteGagAnswer");

	/* [EVENT] */
	register_event("TeamInfo", "EventHook_TeamInfo", "a");
	
	#if defined CVM_MODE_AES || defined CVM_MODE_CSSTATS_SQL
		/* [LOGEVENT] */
		register_logevent("LogEventHook_RoundStart", 2,	"1=Round_Start");
	#endif
	
	/* [FAKEMETA] */
	register_forward(FM_Voice_SetClientListening, "FMHook_VoiceClientListening_Pre", false);

	/* [ReAPI] */
	#if defined USE_ReAPI
	RegisterHookChain(RG_CBasePlayer_Spawn, "CBasePlayer_Spawn_Post", .post = true);
	RegisterHookChain(RG_CBasePlayer_Killed, "CBasePlayer_Killed_Post", .post = true);
	#else
	/* [HAMSANDWICH] */
	RegisterHam(Ham_Spawn, "player", "CBasePlayer_Spawn_Post", .Post = true);
	RegisterHam(Ham_Killed, "player", "CBasePlayer_Killed_Post", .Post = true);
	#endif
	/* [OTHER] */
	g_iMaxPlayers = get_maxplayers();
	
	g_tPlayerGag = TrieCreate();
}

public plugin_end()
	TrieDestroy(g_tPlayerGag);

public plugin_natives()
	set_native_filter("native_filter");

public native_filter(const szName[], const iIndex, const iTrap)
	return iTrap ? PLUGIN_CONTINUE : PLUGIN_HANDLED;

/*================================================================================
 [CLIENT]
=================================================================================*/
public client_putinserver(pId)	{
	if(is_user_bot(pId) || is_user_hltv(pId))
		return PLUGIN_HANDLED;
	
	SetBit(gp_iBit[BIT_CONNECTED], pId);
	
	new iFlags = get_user_flags(pId);
	
	if(iFlags & read_flags(CVM_GAG_ACCESS)) SetBit(gp_iBit[BIT_ACCESS], pId);
	if(iFlags & read_flags(CVM_IMMUNITY_FLAGS)) SetBit(gp_iBit[BIT_IMMUNITY], pId);
	if(iFlags & read_flags(CVM_FLAGS_LISTEN_ALL)) SetBit(gp_iBit[BIT_LISTEN_ALL], pId);
	
	get_user_ip(pId, gp_szIP[pId], charsmax(gp_szIP[]), true);

	new tData[ENUM_DATA_PLAYER_GAG];
	if(TrieGetArray(g_tPlayerGag, gp_szIP[pId], tData, sizeof(tData)))	{
		if(tData[PL_GAG_TIME] > get_systime())
		{
			gp_iGag[pId][PL_GAG_TYPE] = tData[PL_GAG_TYPE];
			gp_iGag[pId][PL_GAG_TIME] = tData[PL_GAG_TIME];
			
			SetBit(gp_iBit[BIT_GAGGED], pId);
		}
		else
		{
			UnGag(pId);
		}
	}
	
	#if defined CVM_MODE_AES || defined CVM_MODE_CSSTATS_SQL
		GetPlayerStats(pId);
	#endif

	return PLUGIN_CONTINUE;
}

public client_disconnect(pId)	{
	if(IsNotSetBit(gp_iBit[BIT_CONNECTED], pId))
		return PLUGIN_HANDLED;
	
	for(new iCount = BIT_NULL; iCount < BIT_MAX; iCount++)
		ClearBit(gp_iBit[iCount], pId);

	gp_iTeam[pId] = TEAM_UNASSIGNED;

	gp_iGag[pId][PL_GAG_TYPE] = 0;
	gp_iGag[pId][PL_GAG_TIME] = 0;

	gp_szIP[pId] = "";

	return PLUGIN_CONTINUE;
}

/*================================================================================
 [CLCMD]
=================================================================================*/
public ClCmd_HookSay(const pId) return HookSay(pId);
public ClCmd_HookSayTeam(const pId) return HookSay(pId, true);

HookSay(const pId, const bool: bTeam = false)	{
	if(IsSetBit(gp_iBit[BIT_IMMUNITY], pId))
		return PLUGIN_CONTINUE;
	
	if(IsSetBit(gp_iBit[BIT_GAGGED], pId) && (gp_iGag[pId][PL_GAG_TYPE] == (bTeam ? GAG_TYPE_COMMAND_CHAT : GAG_TYPE_CHAT) || gp_iGag[pId][PL_GAG_TYPE] == GAG_TYPE_ALL))	{
		new iGagTimeLeft = gp_iGag[pId][PL_GAG_TIME] - get_systime();
		if(iGagTimeLeft > 0)	{
			client_print_color(pId, print_team_default, "^3%s ^1Извините, но у Вас ^4^"Gag^" ^1на ^3%s ^1чат. Времени осталось: ^4%s", CVM_CHAT_PREFIX, bTeam ? "командный" : "общий", UTIL_FixTime(iGagTimeLeft));
			return PLUGIN_HANDLED;
		} else UnGag(pId);
	}
	
	#if defined CVM_MODE_CSSTATS_SQL
		if(gp_iFrags[pId] < CVM_CSSTATS_FRAG_USE_CHAT)	{
			client_print_color(pId, print_team_default, "^3%s ^1Для допуска к чату, Вам нужно набрать ^3%d ^1убийств.", CVM_CHAT_PREFIX, CVM_CSSTATS_FRAG_USE_CHAT);
			return PLUGIN_HANDLED;
		}
	#endif
	
	#if defined CVM_MODE_AES
		if(gp_iRank[pId] < CVM_AES_RANK_USE_CHAT)	{
			if(g_szRankNameChat[0] == '^0')
				aes_get_level_name(CVM_AES_RANK_USE_CHAT, g_szRankNameChat, charsmax(g_szRankNameChat));

			client_print_color(pId, print_team_default, "^3%s ^1Для допуска к чату, получите звание ^3^"%s^"", CVM_CHAT_PREFIX, g_szRankNameChat);
			return PLUGIN_HANDLED;
		}
	#endif

	return PLUGIN_CONTINUE;
}

public ClCmd_Gag(const pId)
	return IsSetBit(gp_iBit[BIT_ACCESS], pId) ? Show_GagMenu(pId, gp_iMenuPosition[pId] = 0) : PLUGIN_HANDLED;

public ClCmd_Mute(const pId)
	return Show_MuteMenu(pId, gp_iMenuPosition[pId] = 0);

public ClCmd_VoteGag(const pId)	{
	new iSysTime = get_systime(); static iNextTime;
	
	if(iNextTime > iSysTime)	{
		client_print_color(pId, print_team_default, "^3%s ^1Запуск нового голосования возможно через ^4%d ^1секунд", CVM_CHAT_PREFIX, iNextTime - iSysTime);
		return PLUGIN_HANDLED;
	}
	
	iNextTime = iSysTime + CVM_NEXT_VOTE_GAG;
	return Show_VoteGagMenu(pId, gp_iMenuPosition[pId] = 0);
}

/*================================================================================
 [MENUCMD]
=================================================================================*/

/* [GAG] */
Show_GagMenu(const pId, const iPos)	{
	if(iPos < 0)
		return PLUGIN_HANDLED;

	new iPlayersNum;
	for(new iIndex = 1; iIndex <= g_iMaxPlayers; iIndex++)	{
		if(IsNotSetBit(gp_iBit[BIT_CONNECTED], iIndex) || pId == iIndex)
			continue;
		
		#if defined CVM_HIDE_IMMUNITY
			if(IsSetBit(gp_iBit[BIT_ACCESS], iIndex) || IsSetBit(gp_iBit[BIT_IMMUNITY], iIndex))
				continue;
		#endif
		
		#if defined CVM_MODE_AES
			if(gp_iRank[iIndex] < CVM_AES_RANK_USE_CHAT && gp_iRank[iIndex] < CVM_AES_RANK_USE_VOICE)
				continue;
		#endif
		
		#if defined CVM_MODE_CSSTATS_SQL
			if(gp_iFrags[iIndex] < CVM_CSSTATS_FRAG_USE_CHAT && gp_iFrags[iIndex] < CVM_CSSTATS_FRAG_USE_VOICE)
				continue;
		#endif
		
		gp_iMenuPlayers[pId][iPlayersNum++] = iIndex;
	}
	
	new iStart = iPos * 8;
	if(iStart > iPlayersNum) iStart = iPlayersNum;
	iStart = iStart - (iStart % 8);
	gp_iMenuPosition[pId] = iStart / 8;

	new iEnd = iStart + 8;
	if(iEnd > iPlayersNum) iEnd = iPlayersNum;

	new szMenu[512], iLen, iPagesNum = (iPlayersNum / 8 + ((iPlayersNum % 8) ? 1 : 0));
	switch(iPagesNum)	{
		case 0:	{
			client_print_color(pId, print_team_default, "^3%s ^1Нету подходящих Игроков.", CVM_CHAT_PREFIX);
			return PLUGIN_HANDLED;
		}
		default: iLen = formatex(szMenu, charsmax(szMenu), "\y[CVM Gag] \rВ\wыберите игрока \d[%d|%d]^n^n", iPos + 1, iPagesNum);
	}
	
	new iItem, iIndex, iBitKeys = MENU_KEY_0, szName[32];
	for(new i = iStart; i < iEnd; i++)	{
		iIndex = gp_iMenuPlayers[pId][i];
		get_user_name(iIndex, szName, charsmax(szName));

		#if !(defined CVM_HIDE_IMMUNITY)
			if(IsSetBit(gp_iBit[BIT_ACCESS], iIndex) || IsSetBit(gp_iBit[BIT_IMMUNITY], iIndex))	{
				iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r[%d] \d%s \r[ \dIMMUNITY \r]^n", ++iItem, szName);
				continue;
			}
		#endif
		
		iBitKeys |= (1 << iItem);
		
		if(IsSetBit(gp_iBit[BIT_GAGGED], iIndex)) iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r[%d] \w%s \r[ \yGAGGED \r]^n", ++iItem, szName);
		else iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r[%d] \w%s^n", ++iItem, szName);
	}
	
	for(new i = iItem; i < 8; i++) iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "^n");
	
	if(iEnd < iPlayersNum)	{
		iBitKeys |= MENU_KEY_9;
		formatex(szMenu[iLen], charsmax(szMenu) - iLen, "^n\r[9] \wДалее^n\r[0] \w%s", iPos ? "Назад" : "Выход");
	} else formatex(szMenu[iLen], charsmax(szMenu) - iLen, "^n^n\r[0] \w%s", iPos ? "Назад" : "Выход");

	return show_menu(pId, iBitKeys, szMenu, -1, "Show_GagMenu");
}

public Handler_GagMenu(const pId, const iKey)	{
	switch(iKey)	{
		case 8: return Show_GagMenu(pId, ++gp_iMenuPosition[pId]);
		case 9: return Show_GagMenu(pId, --gp_iMenuPosition[pId]);
		default:	{
			new iPlayer = gp_iMenuTarget[pId] = gp_iMenuPlayers[pId][gp_iMenuPosition[pId] * 8 + iKey];
			
			if(IsNotSetBit(gp_iBit[BIT_CONNECTED], iPlayer))	{
				client_print_color(pId, print_team_default, "^3%s ^1Этот Игрок не подходит.", CVM_CHAT_PREFIX);
				return PLUGIN_HANDLED;
			}
			
			if(IsSetBit(gp_iBit[BIT_GAGGED], iPlayer))	{
				UnGag(iPlayer);
				
				new szName[32];
				get_user_name(iPlayer, szName, charsmax(szName));

				switch(CVM_SHOW_TEXT_GAG)	{
					case 0: client_print_color(0, print_team_default, "^3%s ^1Игроку ^4%s ^1сняли затычку.", CVM_CHAT_PREFIX, szName);
					case 1:	{
						client_print_color(pId, print_team_default, "^3%s ^1Вы игроку ^4%s ^1сняли затычку.", CVM_CHAT_PREFIX, szName);

						get_user_name(pId, szName, charsmax(szName));
						client_print_color(iPlayer, print_team_default, "^3%s ^1Админ ^4%s ^1снял Вам затычку.", CVM_CHAT_PREFIX, szName);
					}
				}
			} else return Show_ChooseGagType(pId);
		}
	}
	
	return Show_GagMenu(pId, gp_iMenuPosition[pId]);
}

Show_ChooseGagType(const pId)	{
	static szMenu[160], iBitKeys = MENU_KEY_1|MENU_KEY_2|MENU_KEY_3|MENU_KEY_4|MENU_KEY_9|MENU_KEY_0;
	new iLen = formatex(szMenu, charsmax(szMenu), "\y[CVM Gag] \rВ\wыберите блокировку^n^n");

	new iItem; static iSize = sizeof(g_szGagTypes);
	for(iItem = 1; iItem < iSize; iItem++)
		iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r[%d] \w%s^n", iItem, g_szGagTypes[iItem]);

	for(new iCount = iItem - 1; iCount <= 8; iCount++) iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "^n");

	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r[9] \wНазад^n");
	formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r[0] \wВыход");

	return show_menu(pId, iBitKeys, szMenu, -1, "Show_ChooseGagType");
}

public Handler_ChooseGagType(const pId, const iKey)	{
	switch(iKey)	{
		case 0..3:	{
			gp_iGag[gp_iMenuTarget[pId]][PL_GAG_TYPE] = iKey + 1;
			return Show_ChooseGagTime(pId);
		}
		case 8:	{
			gp_iMenuTarget[pId] = 0;
			return Show_GagMenu(pId, gp_iMenuPosition[pId]);
		}
	}
	
	return PLUGIN_HANDLED;
}

Show_ChooseGagTime(const pId)	{
	static szMenu[154], iBitKeys = MENU_KEY_1|MENU_KEY_2|MENU_KEY_3|MENU_KEY_4|MENU_KEY_5|MENU_KEY_6|MENU_KEY_9|MENU_KEY_0;
	new iLen = formatex(szMenu, charsmax(szMenu), "\y[CVM Gag] \rВ\wыберите время^n^n");

	new iItem; static iSize = sizeof(g_iGagTimes);
	for(iItem = 1; iItem <= iSize; iItem++)
		iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r[%d] \w%d^n", iItem, g_iGagTimes[iItem - 1]);

	for(new iCount = iItem - 1; iCount <= 8; iCount++) iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "^n");

	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r[9] \wНазад^n");
	formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r[0] \wВыход");

	return show_menu(pId, iBitKeys, szMenu, -1, "Show_ChooseGagTime");
}

public Handler_ChooseGagTime(const pId, const iKey)	{
	switch(iKey)	{
		case 0..5:	{
			new iPlayer = gp_iMenuTarget[pId];
		
			if(IsNotSetBit(gp_iBit[BIT_CONNECTED], iPlayer))	{
				client_print_color(pId, print_team_default, "^3%s ^1Этот Игрок не подходит.", CVM_CHAT_PREFIX);
				return Show_GagMenu(pId, gp_iMenuPosition[pId]);
			}

			new tData[ENUM_DATA_PLAYER_GAG];

			tData[PL_GAG_TYPE] = gp_iGag[iPlayer][PL_GAG_TYPE];
			tData[PL_GAG_TIME] = gp_iGag[iPlayer][PL_GAG_TIME] = (get_systime() + (g_iGagTimes[iKey] * 60));

			TrieSetArray(g_tPlayerGag, gp_szIP[iPlayer], tData, sizeof(tData));

			SetBit(gp_iBit[BIT_GAGGED], iPlayer);
			
			new szName[32];
			get_user_name(iPlayer, szName, charsmax(szName));

			switch(CVM_SHOW_TEXT_GAG)	{
				case 0: client_print_color(0, print_team_default, "^3%s ^1Игрока ^4%s ^1заткнули на ^4%d ^1минут. (%s)", CVM_CHAT_PREFIX, szName, g_iGagTimes[iKey], g_szGagTypes[gp_iGag[iPlayer][PL_GAG_TYPE]]);
				case 1:	{
					client_print_color(pId, print_team_default, "^3%s ^1Вы игроку ^4%s ^1дали затычку на ^4%d ^1минут. (%s)", CVM_CHAT_PREFIX, szName, g_iGagTimes[iKey], g_szGagTypes[gp_iGag[iPlayer][PL_GAG_TYPE]]);

					get_user_name(pId, szName, charsmax(szName));
					client_print_color(iPlayer, print_team_default, "^3%s ^1Админ ^4%s выдал Вам затычку на ^4%d ^1минут. (%s)", CVM_CHAT_PREFIX, szName, g_iGagTimes[iKey], g_szGagTypes[gp_iGag[iPlayer][PL_GAG_TYPE]]);
				}
			}
		}
		case 8:	{
			gp_iGag[gp_iMenuTarget[pId]][PL_GAG_TYPE] = 0;
			return Show_ChooseGagType(pId);
		}
	}
	
	return PLUGIN_HANDLED;
}

/* [MUTE] */
Show_MuteMenu(const pId, const iPos)	{
	if(iPos < 0)
		return PLUGIN_HANDLED;

	new iPlayersNum;
	for(new iIndex = 1; iIndex <= g_iMaxPlayers; iIndex++)	{
		if(IsNotSetBit(gp_iBit[BIT_CONNECTED], iIndex) || pId == iIndex)
			continue;

		gp_iMenuPlayers[pId][iPlayersNum++] = iIndex;
	}
	
	new iStart = iPos * 8;
	if(iStart > iPlayersNum) iStart = iPlayersNum;
	iStart = iStart - (iStart % 8);
	gp_iMenuPosition[pId] = iStart / 8;

	new iEnd = iStart + 8;
	if(iEnd > iPlayersNum) iEnd = iPlayersNum;

	new szMenu[512], iLen, iPagesNum = (iPlayersNum / 8 + ((iPlayersNum % 8) ? 1 : 0));
	switch(iPagesNum)	{
		case 0:	{
			client_print_color(pId, print_team_default, "^3%s ^1Нету подходящих Игроков.", CVM_CHAT_PREFIX);
			return PLUGIN_HANDLED;
		}
		default: iLen = formatex(szMenu, charsmax(szMenu), "\y[CVM Mute] \rВ\wыберите игрока \d[%d|%d]^n^n", iPos + 1, iPagesNum);
	}
	
	new iItem, iIndex, iBitKeys = MENU_KEY_0, szName[32];
	for(new i = iStart; i < iEnd; i++)	{
		iIndex = gp_iMenuPlayers[pId][i];
		get_user_name(iIndex, szName, charsmax(szName));
		
		iBitKeys |= (1 << iItem);
		
		if(IsSetBit(gp_iBit[BIT_MUTTED][pId], iIndex)) iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r[%d] \w%s \r[ \yMUTED \r]^n", ++iItem, szName);
		else iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r[%d] \w%s^n", ++iItem, szName);
	}
	
	for(new i = iItem; i < 8; i++) iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "^n");
	
	if(iEnd < iPlayersNum)	{
		iBitKeys |= MENU_KEY_9;
		formatex(szMenu[iLen], charsmax(szMenu) - iLen, "^n\r[9] \wДалее^n\r[0] \w%s", iPos ? "Назад" : "Выход");
	} else formatex(szMenu[iLen], charsmax(szMenu) - iLen, "^n^n\r[0] \w%s", iPos ? "Назад" : "Выход");

	return show_menu(pId, iBitKeys, szMenu, -1, "Show_MuteMenu");
}

public Handler_MuteMenu(const pId, const iKey)	{
	switch(iKey)	{
		case 8: return Show_MuteMenu(pId, ++gp_iMenuPosition[pId]);
		case 9: return Show_MuteMenu(pId, --gp_iMenuPosition[pId]);
		default:	{
			new iPlayer = gp_iMenuPlayers[pId][gp_iMenuPosition[pId] * 8 + iKey];
			
			if(IsNotSetBit(gp_iBit[BIT_CONNECTED], iPlayer))	{
				client_print_color(pId, print_team_default, "^3%s ^1Этот Игрок не подходит.", CVM_CHAT_PREFIX);
				return PLUGIN_HANDLED;
			}
			
			new szName[32];
			get_user_name(iPlayer, szName, charsmax(szName));
			
			if(IsSetBit(gp_iBit[BIT_MUTTED][pId], iPlayer)) ClearBit(gp_iBit[BIT_MUTTED][pId], iPlayer);
			else SetBit(gp_iBit[BIT_MUTTED][pId], iPlayer);

			client_print_color(pId, print_team_default, "^3%s ^1Вы %s слышите ^4%s", CVM_CHAT_PREFIX, IsSetBit(gp_iBit[BIT_MUTTED][pId], iPlayer) ? "больше не" : "теперь", szName);
		}
	}
	
	return PLUGIN_HANDLED;
}

/* [VOTE GAG] */
Show_VoteGagMenu(const pId, const iPos)	{
	if(iPos < 0)
		return PLUGIN_HANDLED;

	new iPlayersNum;
	for(new iIndex = 1; iIndex <= g_iMaxPlayers; iIndex++)	{
		if(IsNotSetBit(gp_iBit[BIT_CONNECTED], iIndex) || pId == iIndex)
			continue;

		#if defined CVM_HIDE_IMMUNITY
			if(IsSetBit(gp_iBit[BIT_ACCESS], iIndex) || IsSetBit(gp_iBit[BIT_IMMUNITY], iIndex))
				continue;
		#endif
		
		#if defined CVM_MODE_AES
			if(gp_iRank[iIndex] < CVM_AES_RANK_USE_CHAT && gp_iRank[iIndex] < CVM_AES_RANK_USE_VOICE)
				continue;
		#endif
		
		#if defined CVM_MODE_CSSTATS_SQL
			if(gp_iFrags[iIndex] < CVM_CSSTATS_FRAG_USE_CHAT && gp_iFrags[iIndex] < CVM_CSSTATS_FRAG_USE_VOICE)
				continue;
		#endif
		
		gp_iMenuPlayers[pId][iPlayersNum++] = iIndex;
	}
	
	new iStart = iPos * 8;
	if(iStart > iPlayersNum) iStart = iPlayersNum;
	iStart = iStart - (iStart % 8);
	gp_iMenuPosition[pId] = iStart / 8;

	new iEnd = iStart + 8;
	if(iEnd > iPlayersNum) iEnd = iPlayersNum;

	new szMenu[512], iLen, iPagesNum = (iPlayersNum / 8 + ((iPlayersNum % 8) ? 1 : 0));
	switch(iPagesNum)	{
		case 0:	{
			client_print_color(pId, print_team_default, "^3%s ^1Нету подходящих Игроков.", CVM_CHAT_PREFIX);
			return PLUGIN_HANDLED;
		}
		default: iLen = formatex(szMenu, charsmax(szMenu), "\y[CVM VoteGag] \rВ\wыберите игрока \d[%d|%d]^n^n", iPos + 1, iPagesNum);
	}
	
	new iItem, iIndex, iBitKeys = MENU_KEY_0, szName[32];
	for(new i = iStart; i < iEnd; i++)	{
		iIndex = gp_iMenuPlayers[pId][i];
		get_user_name(iIndex, szName, charsmax(szName));

		#if !(defined CVM_HIDE_IMMUNITY)
			if(IsSetBit(gp_iBit[BIT_ACCESS], iIndex) || IsSetBit(gp_iBit[BIT_IMMUNITY], iIndex))	{
				iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r[%d] \d%s \r[ \dIMMUNITY \r]^n", ++iItem, szName);
				continue;
			}
		#endif
		
		if(IsSetBit(gp_iBit[BIT_GAGGED], iIndex)) iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r[%d] \d%s \r[ \yGAGGED \r]^n", ++iItem, szName);
		else {
			iBitKeys |= (1 << iItem);
			iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r[%d] \w%s^n", ++iItem, szName);
		}
	}
	
	for(new i = iItem; i < 8; i++) iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "^n");
	
	if(iEnd < iPlayersNum)	{
		iBitKeys |= MENU_KEY_9;
		formatex(szMenu[iLen], charsmax(szMenu) - iLen, "^n\r[9] \wДалее^n\r[0] \w%s", iPos ? "Назад" : "Выход");
	} else formatex(szMenu[iLen], charsmax(szMenu) - iLen, "^n^n\r[0] \w%s", iPos ? "Назад" : "Выход");

	return show_menu(pId, iBitKeys, szMenu, -1, "Show_VoteGagMenu");
}

public Handler_VoteGagMenu(const pId, const iKey)	{
	switch(iKey)	{
		case 8: return Show_VoteGagMenu(pId, ++gp_iMenuPosition[pId]);
		case 9: return Show_VoteGagMenu(pId, --gp_iMenuPosition[pId]);
		default:	{
			g_iVotePlayerGag[PL_VOTE_GAG_ID] = gp_iMenuPlayers[pId][gp_iMenuPosition[pId] * 8 + iKey];
			
			if(IsNotSetBit(gp_iBit[BIT_CONNECTED], g_iVotePlayerGag[PL_VOTE_GAG_ID]))	{
				client_print_color(pId, print_team_default, "^3%s ^1Этот Игрок не подходит.", CVM_CHAT_PREFIX);
				return PLUGIN_HANDLED;
			}
			
			return Show_ChooseVoteGagType(pId);
		}
	}
	
	return Show_VoteGagMenu(pId, gp_iMenuPosition[pId]);
}

Show_ChooseVoteGagType(const pId)	{
	static szMenu[165], iBitKeys = MENU_KEY_1|MENU_KEY_2|MENU_KEY_3|MENU_KEY_4|MENU_KEY_9|MENU_KEY_0;
	new iLen = formatex(szMenu, charsmax(szMenu), "\y[CVM VoteGag] \rВ\wыберите блокировку^n^n");

	new iItem; static iSize = sizeof(g_szGagTypes);
	for(iItem = 1; iItem < iSize; iItem++)
		iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r[%d] \w%s^n", iItem, g_szGagTypes[iItem]);

	for(new iCount = iItem - 1; iCount <= 8; iCount++) iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "^n");

	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r[9] \wНазад^n");
	formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r[0] \wВыход");

	return show_menu(pId, iBitKeys, szMenu, -1, "Show_ChooseVoteGagType");
}

public Handler_ChooseVoteGagType(const pId, const iKey)	{
	switch(iKey)	{
		case 0..3:	{
			g_iVotePlayerGag[PL_VOTE_GAG_TYPE] = iKey + 1;
			return Show_ChooseVoteGagTime(pId);
		}
		case 8:	{
			g_iVotePlayerGag[PL_VOTE_GAG_ID] = 0;
			return Show_VoteGagMenu(pId, gp_iMenuPosition[pId]);
		}
	}
	
	return PLUGIN_HANDLED;
}

Show_ChooseVoteGagTime(const pId)	{
	static szMenu[160], iBitKeys = MENU_KEY_1|MENU_KEY_2|MENU_KEY_3|MENU_KEY_4|MENU_KEY_5|MENU_KEY_6|MENU_KEY_9|MENU_KEY_0;
	new iLen = formatex(szMenu, charsmax(szMenu), "\y[CVM VoteGag] \rВ\wыберите время^n^n");

	new iItem; static iSize = sizeof(g_iGagTimes);
	for(iItem = 1; iItem <= iSize; iItem++)
		iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r[%d] \w%d^n", iItem, g_iGagTimes[iItem - 1]);

	for(new iCount = iItem - 1; iCount <= 8; iCount++) iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "^n");

	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r[9] \wНазад^n");
	formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r[0] \wВыход");

	return show_menu(pId, iBitKeys, szMenu, -1, "Show_ChooseVoteGagTime");
}

public Handler_ChooseVoteGagTime(const pId, const iKey)	{
	switch(iKey)	{
		case 0..5:	{
			new iPlayer = g_iVotePlayerGag[PL_VOTE_GAG_ID];
		
			if(IsNotSetBit(gp_iBit[BIT_CONNECTED], iPlayer))	{
				client_print_color(pId, print_team_default, "^3%s ^1Этот Игрок не подходит.", CVM_CHAT_PREFIX);
				return Show_VoteGagMenu(pId, gp_iMenuPosition[pId]);
			}

			g_iVotePlayerGag[PL_VOTE_GAG_TIME] = (get_systime() + (g_iGagTimes[iKey] * 60));

			for(new iIndex = 1; iIndex <= g_iMaxPlayers; iIndex++)	{
				if(IsNotSetBit(gp_iBit[BIT_CONNECTED], iIndex) || iIndex == iPlayer)
					continue;
				
				Show_ChooseVoteGagAnswer(iIndex);
			}
			
			g_iVoteTotalNo = 1;
			set_task(CVM_TIME_VOTE_GAG.0, "task_EndVoteGag");
		}
		case 8:	{
			g_iVotePlayerGag[PL_VOTE_GAG_TYPE] = 0;
			return Show_ChooseVoteGagType(pId);
		}
	}
	
	return PLUGIN_HANDLED;
}

public Show_ChooseVoteGagAnswer(const pId)	{
	new szMenu[512], iBitKeys = MENU_KEY_5|MENU_KEY_6;
	
	new szName[32];
	get_user_name(g_iVotePlayerGag[PL_VOTE_GAG_ID], szName, charsmax(szName));

	new iLen = formatex(szMenu, charsmax(szMenu), "\r\y[CVM VoteGag] \wЗаблокировать^n^n\dИгрока \r[ \y%s \r]^n\dНа время \r[ \y%d минут \r]^n\dТип блокировки \r[ \y%s \r]^n^n", szName, (get_systime() - g_iVotePlayerGag[PL_VOTE_GAG_TIME]) / 60, g_szGagTypes[g_iVotePlayerGag[PL_VOTE_GAG_TYPE]]);
	
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r[5] \wДа^n");
	formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r[6] \wНет^n");
	
	return show_menu(pId, iBitKeys, szMenu, -1, "Show_ChooseVoteGagAnswer");
}	

public Handler_ChooseVoteGagAnswer(const pId, const iKey)	{
	(iKey == 4) ? g_iVoteTotalYes++ : g_iVoteTotalNo++;
	client_print_color(pId, print_team_default, "^3%s ^1Вы проголосовали ^4^"%s^"", CVM_CHAT_PREFIX, (iKey == 4) ? "Да" : "Нет");
	
	return PLUGIN_HANDLED;
}

public task_EndVoteGag()	{
	client_print_color(0, print_team_default, "^3%s ^1Голосование завершено. За - ^4%d ^1| Против - ^3%d", CVM_CHAT_PREFIX, g_iVoteTotalYes, g_iVoteTotalNo);

	if(g_iVoteTotalYes >= g_iVoteTotalNo)	{		
		new iPlayer = g_iVotePlayerGag[PL_VOTE_GAG_ID];

		new tData[ENUM_DATA_PLAYER_GAG];

		tData[PL_GAG_TYPE] = g_iVotePlayerGag[PL_VOTE_GAG_TYPE];
		tData[PL_GAG_TIME] = g_iVotePlayerGag[PL_VOTE_GAG_TIME];

		TrieSetArray(g_tPlayerGag, gp_szIP[iPlayer], tData, sizeof(tData));

		SetBit(gp_iBit[BIT_GAGGED], iPlayer);
	}
	
	g_iVoteTotalNo = 0;
	g_iVoteTotalYes = 0;
}

/*================================================================================
 [EVENT]
=================================================================================*/
public EventHook_TeamInfo()	{
	static pId; pId = read_data(1);
	static szTeam[2]; read_data(2, szTeam, 1);
	
	static const szCurTeam[] = {'U', 'T', 'C', 'S'};

	if(szCurTeam[gp_iTeam[pId]] != szTeam[0])	{
		switch(szTeam[0])	{
			case 'U': gp_iTeam[pId] = TEAM_UNASSIGNED;
			case 'T': gp_iTeam[pId] = TEAM_TERRORIST;
			case 'C': gp_iTeam[pId] = TEAM_CT;
			case 'S': gp_iTeam[pId] = TEAM_SPECTATOR;
		}
	}
}

/*================================================================================
 [LOGEVENT]
=================================================================================*/
public LogEventHook_RoundStart()	{
	for(new iIndex = 1; iIndex <= g_iMaxPlayers; iIndex++)	{
		if(IsSetBit(gp_iBit[BIT_CONNECTED], iIndex))
			GetPlayerStats(iIndex);
	}
}

/*================================================================================
 [FAKEMETA]
=================================================================================*/
public FMHook_VoiceClientListening_Pre(const iReceiver, const iSender)	{
	if(IsNotSetBit(gp_iBit[BIT_CONNECTED], iReceiver) || IsNotSetBit(gp_iBit[BIT_CONNECTED], iSender) || iReceiver == iSender)
		return FMRES_IGNORED;

	if(IsSetBit(gp_iBit[BIT_MUTTED][iReceiver], iSender))	{
		engfunc(EngFunc_SetClientListening, iReceiver, iSender, false);
		return FMRES_SUPERCEDE;
	}
	
	if(IsSetBit(gp_iBit[BIT_GAGGED], iSender) && (gp_iGag[iSender][PL_GAG_TYPE] == GAG_TYPE_VOICE || gp_iGag[iSender][PL_GAG_TYPE] == GAG_TYPE_ALL))	{
		static iGagTimeLeft; iGagTimeLeft = gp_iGag[iSender][PL_GAG_TIME] - get_systime();
		
		if(!(iGagTimeLeft))
			UnGag(iSender);
		
		engfunc(EngFunc_SetClientListening, iReceiver, iSender, false);
		return FMRES_SUPERCEDE;
	}
	
	#if defined CVM_MODE_CSSTATS_SQL
		if(gp_iFrags[iSender] < CVM_CSSTATS_FRAG_USE_VOICE)	{
			engfunc(EngFunc_SetClientListening, iReceiver, iSender, false);
			return FMRES_SUPERCEDE;
		}
	#endif
	
	#if defined CVM_MODE_AES
		if(gp_iRank[iSender] < CVM_AES_RANK_USE_VOICE)	{
			engfunc(EngFunc_SetClientListening, iReceiver, iSender, false);
			return FMRES_SUPERCEDE;
		}
	#endif

	if(IsSetBit(gp_iBit[BIT_LISTEN_ALL], iReceiver))
		return FMRES_IGNORED;
	
	if(g_bHearDeath)
	{
		
		if(IsSetBit(gp_iBit[BIT_ALIVE], iReceiver) && (IsSetBit(gp_iBit[BIT_ALIVE], iSender) || IsNotSetBit(gp_iBit[BIT_ALIVE], iSender))){
			if(g_bHearEnemy)
				if(gp_iTeam[iReceiver] == gp_iTeam[iSender] || gp_iTeam[iReceiver] != gp_iTeam[iSender])
		else
		{
				if(gp_iTeam[iReceiver] == gp_iTeam[iSender])
		}
			
			return FMRES_IGNORED;
	}else{
		if(IsSetBit(gp_iBit[BIT_ALIVE], iReceiver) && IsSetBit(gp_iBit[BIT_ALIVE], iSender))	{
			if(g_bHearEnemy)
				if(gp_iTeam[iReceiver] == gp_iTeam[iSender] || gp_iTeam[iReceiver] != gp_iTeam[iSender])
			else
				if(gp_iTeam[iReceiver] == gp_iTeam[iSender])

			return FMRES_IGNORED;
		}
	}
	if(g_bDeathHearAlive)
	{
		if(IsNotSetBit(gp_iBit[BIT_ALIVE], iReceiver) && (IsNotSetBit(gp_iBit[BIT_ALIVE], iSender) || IsSetBit(gp_iBit[BIT_ALIVE], iSender)))	{
			if(g_bHearEnemy)
				if(gp_iTeam[iReceiver] == gp_iTeam[iSender] || gp_iTeam[iReceiver] != gp_iTeam[iSender])
			else
				if(gp_iTeam[iReceiver] == gp_iTeam[iSender])

			return FMRES_IGNORED;
		}
	}else{
		if(IsNotSetBit(gp_iBit[BIT_ALIVE], iReceiver) && IsNotSetBit(gp_iBit[BIT_ALIVE], iSender))	{
			if(g_bHearEnemy)
				if(gp_iTeam[iReceiver] == gp_iTeam[iSender] || gp_iTeam[iReceiver] != gp_iTeam[iSender])
			else
				if(gp_iTeam[iReceiver] == gp_iTeam[iSender])

			return FMRES_IGNORED;
		}
	}
		
	engfunc(EngFunc_SetClientListening, iReceiver, iSender, false);
	return FMRES_SUPERCEDE;
}

public CBasePlayer_Spawn_Post(const pId)	{
	if(is_user_alive(pId))	{
		if(IsNotSetBit(gp_iBit[BIT_ALIVE], pId))
			SetBit(gp_iBit[BIT_ALIVE], pId);
	}
}

public CBasePlayer_Killed_Post(const vId)	{
	if(IsNotSetBit(gp_iBit[BIT_ALIVE], vId))
		#if defined USE_ReAPI
		return HC_CONTINUE;
		#else
		return HAM_IGNORED;
		#endif
	
	ClearBit(gp_iBit[BIT_ALIVE], vId);

	#if defined USE_ReAPI
	return HC_CONTINUE;
	#else
	return HAM_IGNORED;
	#endif
}

/*================================================================================
 [STOCK]
=================================================================================*/
UnGag(const pId)	{
	ClearBit(gp_iBit[BIT_GAGGED], pId);
	
	gp_iGag[pId][PL_GAG_TYPE] = 0;
	gp_iGag[pId][PL_GAG_TIME] = 0;

	TrieDeleteKey(g_tPlayerGag, gp_szIP[pId]);
}

GetPlayerStats(const pId)	{
	#if defined CVM_MODE_AES
		new iStatsAES[4];
		aes_get_player_stats(pId, iStatsAES);
		
		gp_iRank[pId] = iStatsAES[1];
	#endif
	
	#if defined CVM_MODE_CSSTATS_SQL
		new iStatsSQL[8], iBodyHits[8];
		get_user_stats_sql(pId, iStatsSQL, iBodyHits);
		
		gp_iFrags[pId] = iStatsSQL[0];
	#endif
}

/*================================================================================
 [UTIL]
=================================================================================*/
UTIL_FixTime(iTimer)	{
	if(iTimer > 3600)
		iTimer = 3600;

	new szTime[7];
	if(iTimer < 1) add(szTime, charsmax(szTime), "00:00");
	else {
		new iMin = floatround(iTimer / 60.0, floatround_floor);
		new iSec = iTimer - (iMin * 60);
		
		formatex(szTime, charsmax(szTime), "%s%d:%s%d", iMin > 9 ? "" : "0", iMin, iSec > 9 ? "" : "0", iSec);
	}
	
	return szTime;
}