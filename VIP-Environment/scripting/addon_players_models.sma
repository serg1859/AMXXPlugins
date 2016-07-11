/**
* 	Original code by ConnorMcLeod https://forums.alliedmods.net/showthread.php?p=958925
*
*/

//■■■■■■■■■■■■■■■■■■■■■■■ CONFIG START ■■■■■■■■■■■■■■■■■■■■■■■//
new const MODEL_TT[] = "vip"
new const MODEL_CT[] = "bot"
#define DEFAULT_ACCESS		ACCESS_OTHER

#define MAX_MODEL_LEN		16
// #define SET_MODELINDEX
//■■■■■■■■■■■■■■■■■■■■■■■■ CONFIG END ■■■■■■■■■■■■■■■■■■■■■■■■//


#include <amxmodx>
#include <fakemeta>
#include <vip_environment>

#define VERSION "0.0.1"

#define SetUserModeled(%1)			g_bModeled |= 1<<(%1 & 31)
#define SetUserNotModeled(%1)		g_bModeled &= ~( 1<<(%1 & 31))
#define IsUserModeled(%1)			(g_bModeled &  1<<(%1 & 31))

#define SetUserConnected(%1)		g_bConnected |= 1<<(%1 & 31)
#define SetUserNotConnected(%1)		g_bConnected &= ~( 1<<(%1 & 31))
#define IsUserConnected(%1)			(g_bConnected &  1<<(%1 & 31))

const ClCorpse_ModelName = 1
const ClCorpse_PlayerID = 12

new g_bConnected, g_bModeled
new const MODEL[] = "model"

new Trie:g_tModelIndexes
new g_szCurrentModel[MAX_PLAYERS+1][MAX_MODEL_LEN]

public plugin_precache()
{
	g_tModelIndexes = TrieCreate()
	PrecachePlayerModel(MODEL_TT)
	PrecachePlayerModel(MODEL_CT)
}

public plugin_init()
{
	register_plugin("Players Models", VERSION, "ConnorMcLeod | Vaqtincha")
	if(!vip_environment_loaded())
	{
		pause("ad")
	}
	register_forward(FM_SetClientKeyValue, "SetClientKeyValue", 0)
	register_message(get_user_msgid("ClCorpse"), "Message_ClCorpse")
}

public client_putinserver(id)
{
	if(!is_user_hltv(id) && GetUserAccess(id) & DEFAULT_ACCESS)
	{
		SetUserConnected(id)
	}else{
		SetUserNotConnected(id)
	}
	SetUserNotModeled(id)
}

public client_disconnect(id)
{
	SetUserNotModeled(id)
	SetUserNotConnected(id)
}

public SetClientKeyValue(id, const szInfoBuffer[], const szKey[], const szValue[])
{
	if(!equal(szKey, MODEL) || !IsUserConnected(id))
	{
		return FMRES_IGNORED
	}

	new szSupposedModel[MAX_MODEL_LEN]
	switch(cs_get_user_team(id))
	{
		case TEAM_TT: szSupposedModel = MODEL_TT
		case TEAM_CT: szSupposedModel = MODEL_CT
		default: return FMRES_IGNORED
	}

	if(szSupposedModel[0])
	{
		if(!IsUserModeled(id) || !equal(g_szCurrentModel[id], szSupposedModel) || !equal(szValue, szSupposedModel))
		{
			copy(g_szCurrentModel[id], MAX_MODEL_LEN-1, szSupposedModel)
			SetUserModeled(id)
			set_user_info(id, MODEL, szSupposedModel)
		#if defined SET_MODELINDEX
			new iModelIndex
			TrieGetCell(g_tModelIndexes, szSupposedModel, iModelIndex)
		//	set_pev(id, pev_modelindex, iModelIndex) // is this needed ?
			set_pdata_int(id, g_ulModelIndexPlayer, iModelIndex)
		#endif
			return FMRES_SUPERCEDE
		}
	}

	if(IsUserModeled(id))
	{
		SetUserNotModeled(id)
		g_szCurrentModel[id][0] = 0
	}

	return FMRES_IGNORED
}

public Message_ClCorpse()
{
	new id = get_msg_arg_int(ClCorpse_PlayerID)
	if(IsUserModeled(id))
	{
		set_msg_arg_string(ClCorpse_ModelName, g_szCurrentModel[id])
	}
}

public plugin_end()
{
	TrieDestroy(g_tModelIndexes)
}

PrecachePlayerModel(const szModel[])
{
	if(TrieKeyExists(g_tModelIndexes, szModel))
	{
		return 1
	}

	new szFileToPrecache[MAX_MODEL_LEN + MAX_MODEL_LEN + 32], szMsg[MAX_MODEL_LEN + 64]
	formatex(szFileToPrecache, charsmax(szFileToPrecache), "models/player/%s/%s.mdl", szModel, szModel)
	if(!file_exists(szFileToPrecache))
	{
		formatex(szMsg, charsmax(szMsg), "[V.I.P] ERROR: Model ^"%s^" not found!", szFileToPrecache)
		set_fail_state(szMsg)
		return 0
	}

	TrieSetCell(g_tModelIndexes, szModel, precache_model(szFileToPrecache))

	formatex(szFileToPrecache, charsmax(szFileToPrecache), "models/player/%s/%st.mdl", szModel, szModel)
	if(file_exists(szFileToPrecache))
	{
		precache_model(szFileToPrecache)
		return 1
	}

	formatex(szFileToPrecache, charsmax(szFileToPrecache), "models/player/%s/%sT.mdl", szModel, szModel)
	if(file_exists(szFileToPrecache))
	{
		precache_model(szFileToPrecache)
		return 1
	}
	return 1
}

