// Copyright © 2016 Vaqtincha

#include <amxmodx>
#include <csdm>


#define IsPlayer(%1)				(1 <= (%1) <= g_iMaxPlayers)
#define PlayerTask(%1)				(%1 + PROTECTION_TASK_ID)
#define GetPlayerByTaskID(%1)		(%1 - PROTECTION_TASK_ID)

const Float:MAX_ALPHA_VALUE = 30.0
const Float:MAX_PROTECTION_TIME = 25.0

const PROTECTION_TASK_ID = 216897

enum color_e { Float:R, Float:G, Float:B }

enum 
{ 
	STATUSICON_HIDE, 
	STATUSICON_SHOW, 
	STATUSICON_FLASH 
}

new bool:g_bProtected[MAX_CLIENTS + 1]
new g_iMaxPlayers

new g_szSpriteName[18] = "suithelmet_full"	// "suithelmet_empty" max lenght = 16
new Float:g_flRenderAlpha = 10.0, Float:g_flProtectionTime = 2.0
new Float:g_flTeamColors[TeamName][color_e] = 
{
	{0.0, 0.0, 0.0},
	{235.0, 0.0, 0.0}, // TEAM_TERRORIST
	{0.0, 0.0, 235.0}, // TEAM_CT
	{0.0, 0.0, 0.0}
}


public plugin_init()
{
	register_plugin("CSDM Protection", CSDM_VERSION_STRING, "Vaqtincha")

	if(g_flProtectionTime > 0.0)
	{
		RegisterHookChain(RG_CBasePlayer_TakeDamage, "CBasePlayer_TakeDamage", .post = true)
	}

	g_iMaxPlayers = get_maxplayers()
}

public CSDM_Initialized(const szVersion[])
{
	if(!szVersion[0])
		pause("ad")
}

public CSDM_ConfigurationLoad(const ReadTypes:iReadAction)
{
	CSDM_RegisterConfig("protection", "ReadCfg")
}

public client_putinserver(pPlayer)
{
	g_bProtected[pPlayer] = false
	remove_task(PlayerTask(pPlayer))
}

public CSDM_PlayerSpawned(const pPlayer, const bool:bIsBot, const iNumSpawns)
{
	if(g_flProtectionTime > 0.0)
	{
		SetProtection(pPlayer)
	}
}

public CSDM_PlayerKilled(const pVictim, const pKiller, const HitBoxGroup:iLastHitGroup)
{
	if(g_bProtected[pVictim])
	{
		RemoveProtection(pVictim)
	}
}

public CBasePlayer_TakeDamage(const pPlayer, const pevInflictor, const pevAttacker, Float:flDamage, bitsDamageType)
{
	if(!IsPlayer(pevAttacker) || pPlayer == pevAttacker)
		return HC_CONTINUE

	if(g_bProtected[pevAttacker])
	{
		RemoveProtection(pevAttacker)
	}

	return HC_CONTINUE
}

public TaskProtectionEnd(const iTaskID)
{
	RemoveProtection(GetPlayerByTaskID(iTaskID))
}

public ReadCfg(const szLineData[], const iSectionID)
{
	new szKey[MAX_KEY_LEN], szValue[MAX_VALUE_LEN], szSign[2]
	if(!ParseConfigKey(szLineData, szKey, szSign, szValue))
		return

	if(equali(szKey, "protection_time"))
	{
		g_flProtectionTime = floatclamp(str_to_float(szValue), 0.0, MAX_PROTECTION_TIME)
	}
	else if(equali(szKey, "sprite_name"))
	{
		copy(g_szSpriteName, charsmax(g_szSpriteName), szValue)
		strtolower(g_szSpriteName)
	}
	else if(equali(szKey, "render_color_", 13))
	{
		new szRed[4], szGreen[4], szBlue[4]
		new TeamName:iTeam = szKey[13] == 'c' ? TEAM_CT : TEAM_TERRORIST

		if(parse(szValue, szRed, charsmax(szRed), szGreen, charsmax(szGreen), szBlue, charsmax(szBlue)) == 3)
		{
			g_flTeamColors[iTeam][R] = floatclamp(str_to_float(szRed), 0.0, 255.0)
			g_flTeamColors[iTeam][G] = floatclamp(str_to_float(szGreen), 0.0, 255.0)
			g_flTeamColors[iTeam][B] = floatclamp(str_to_float(szBlue), 0.0, 255.0)	
		}
	}
	else if(equali(szKey, "render_alpha"))
	{
		g_flRenderAlpha = floatclamp(str_to_float(szValue), 0.0, MAX_ALPHA_VALUE)
	}
}

SetProtection(const pPlayer)
{
	new iTaskID = PlayerTask(pPlayer)
	remove_task(iTaskID)
	set_task(g_flProtectionTime, "TaskProtectionEnd", iTaskID)

	set_entvar(pPlayer, var_takedamage, DAMAGE_NO)
	rg_set_rendering(pPlayer, kRenderFxGlowShell, g_flTeamColors[get_member(pPlayer, m_iTeam)], g_flRenderAlpha)
	g_bProtected[pPlayer] = true

	if(g_szSpriteName[0] && g_flProtectionTime > 1.4)
	{
		SendStatusIcon(pPlayer, STATUSICON_FLASH)
	}
}

RemoveProtection(const pPlayer)
{
	remove_task(PlayerTask(pPlayer))
	g_bProtected[pPlayer] = false

	if(is_user_connected(pPlayer))
	{
		set_entvar(pPlayer, var_takedamage, DAMAGE_AIM)
		rg_set_rendering(pPlayer)

		if(g_szSpriteName[0] && g_flProtectionTime >= 2.0)
		{
			SendStatusIcon(pPlayer)
		}
	}
}

stock SendStatusIcon(const pPlayer, iStatus = STATUSICON_HIDE, red = 0, green = 160, blue = 0)
{
	static iMsgIdStatusIcon
	if(iMsgIdStatusIcon || (iMsgIdStatusIcon = get_user_msgid("StatusIcon")))
	{
		message_begin(MSG_ONE_UNRELIABLE, iMsgIdStatusIcon, .player = pPlayer)
		write_byte(iStatus)			// status: 0 - off, 1 - on, 2 - flash
		write_string(g_szSpriteName) 	
		write_byte(red)
		write_byte(green)
		write_byte(blue)
		message_end()
	}
}

