// Copyright © 2016 Vaqtincha

#include <amxmodx>
#include <fakemeta>
#include <csdm>


#define SET_ORIGIN(%1,%2) 		engfunc(EngFunc_SetOrigin, %1, %2)
#define SET_SIZE(%1,%2,%3) 		engfunc(EngFunc_SetSize, %1, %2, %3)
#define REMOVE_ENTITY(%1) 		engfunc(EngFunc_RemoveEntity, %1)
#define ENTITY_THINK(%1) 		dllfunc(DLLFunc_Think, %1)
#define IsPlayer(%1)			(1 <= %1 <= g_iMaxPlayers)

enum
{
	func_bomb_target	= 	(1<<0),
	info_bomb_target	=	(1<<1),
	func_hostage_rescue	= 	(1<<2),
	info_hostage_rescue	=	(1<<3),
	func_vip_safetyzone	=	(1<<4),
	info_vip_start		=	(1<<5),
	hostage_entity		=	(1<<6),
	monster_scientist	=	(1<<7),
	func_escapezone 	=	(1<<8),
	func_buyzone		=	(1<<9),
	armoury_entity		=	(1<<10),
	game_player_equip	=	(1<<11),
	player_weaponstrip	=	(1<<12)
}

new const g_szMapEntityList[][] = 
{
	"func_bomb_target",
	"info_bomb_target",
	"func_hostage_rescue",
	"info_hostage_rescue",
	"func_vip_safetyzone",
	"info_vip_start",
	"hostage_entity",
	"monster_scientist",
	"func_escapezone",
	"func_buyzone",
	"armoury_entity",
	"game_player_equip",
	"player_weaponstrip"
}

new Trie:g_tMapEntitys, g_iFwdEntitySpawn, g_iMaxPlayers, g_iFwdSetModel
new g_bitRemoveObjects, bool:g_bRemoveWeapons, bool:g_bExcludeBomb


public plugin_precache()
{
	g_tMapEntitys = TrieCreate()

	for(new i = 0; i < sizeof(g_szMapEntityList); i++)
	{
		TrieSetCell(g_tMapEntitys, g_szMapEntityList[i], i)
	}

	g_iFwdEntitySpawn = register_forward(FM_Spawn, "Entity_Spawn")

	if(g_bitRemoveObjects & func_buyzone)
	{
		CreateBuyZone()
	}
}

public CSDM_Initialized(const szVersion[])
{
	if(!szVersion[0])
		pause("ad")
}

public CSDM_ConfigurationLoad(const ReadTypes:iReadAction)
{
	CSDM_RegisterConfig("mapcleaner", "ReadCfg")
}

public plugin_init()
{
	register_plugin("CSDM Map Cleaner", CSDM_VERSION_STRING, "Vaqtincha")	

	if(g_iFwdEntitySpawn)
		unregister_forward(FM_Spawn, g_iFwdEntitySpawn)
	if(g_tMapEntitys)
		TrieDestroy(g_tMapEntitys)

	g_iMaxPlayers = get_maxplayers()
}

public plugin_cfg()
{
	CheckForwards()
}

public Entity_SetModel(const pEntity, const szModel[])
{
	if(/* is_nullent(pEntity) || */ IsPlayer(pEntity))
		return FMRES_IGNORED

	new iLen = strlen(szModel)
	if((iLen == 22 && szModel[17] == 'x') || !(iLen >= 9 && szModel[8] == '_')) // "models/w_weaponbox.mdl" && "models/w_"
		return FMRES_IGNORED

	new szClassName[10]
	get_entvar(pEntity, var_classname, szClassName, charsmax(szClassName))

	if(szClassName[0] == 'w' && szClassName[8] == 'x') // weaponbox
	{
		if(!g_bExcludeBomb && get_member(pEntity, m_WeaponBox_bIsBomb))
		{
			set_entvar(pEntity, var_flags, FL_KILLME)
			return FMRES_IGNORED
		}

		ENTITY_THINK(pEntity)
	}
	else if((szClassName[6] == '_' && szClassName[7] == 's' && szClassName[8] == 'h') && IsPlayer(get_entvar(pEntity, var_owner)))
	{
		set_entvar(pEntity, var_flags, FL_KILLME)
	}

	return FMRES_IGNORED
}

public Entity_Spawn(const pEntity)
{
	if(is_nullent(pEntity))
		return FMRES_IGNORED

	static szClassName[32], bits
	get_entvar(pEntity, var_classname, szClassName, charsmax(szClassName))

	if(!TrieGetCell(g_tMapEntitys, szClassName, bits))
		return FMRES_IGNORED

	if(g_bitRemoveObjects & (1<<bits))
	{
		REMOVE_ENTITY(pEntity)
		return FMRES_SUPERCEDE
	}

	return FMRES_IGNORED
}

public ReadCfg(const szLineData[], const iSectionID)
{	
	new szKey[MAX_KEY_LEN], szValue[MAX_VALUE_LEN], szSign[2]
	if(!ParseConfigKey(szLineData, szKey, szSign, szValue))
		return

	if(equali(szKey, "remove_objective_flags"))
	{
		if(ContainFlag(szValue, "a"))
			g_bitRemoveObjects |= (func_vip_safetyzone|info_vip_start|func_escapezone)
		if(ContainFlag(szValue, "b"))
			g_bitRemoveObjects |= func_buyzone
		if(ContainFlag(szValue, "c"))
			g_bitRemoveObjects |= (func_hostage_rescue|info_hostage_rescue|hostage_entity|monster_scientist)
		if(ContainFlag(szValue, "d"))
			g_bitRemoveObjects |= (func_bomb_target|info_bomb_target)
		if(ContainFlag(szValue, "e"))
			g_bitRemoveObjects |= (game_player_equip|player_weaponstrip)
		if(ContainFlag(szValue, "w"))
			g_bitRemoveObjects |= armoury_entity
	}
	else if(equali(szKey, "remove_dropped_weapons"))
	{
		g_bRemoveWeapons = bool:(str_to_num(szValue))
	}
	else if(equali(szKey, "exclude_bomb"))
	{
		g_bExcludeBomb = bool:(str_to_num(szValue))
	}
}

CheckForwards()
{
	if(g_bRemoveWeapons && !g_iFwdSetModel)
	{
		g_iFwdSetModel = register_forward(FM_SetModel, "Entity_SetModel", ._post = false)
	}
	else if(!g_bRemoveWeapons && g_iFwdSetModel)
	{
		unregister_forward(FM_SetModel, g_iFwdSetModel, .post = false)
		g_iFwdSetModel = 0
	}
}

CreateBuyZone()
{
	new pEntity = rg_create_entity("func_buyzone")
	if(!is_nullent(pEntity))
	{
		// SET_SIZE(pEntity, Vector(-1, -1, -1), Vector(1, 1, 1))
		// SET_ORIGIN(pEntity, VECTOR_ZERO)
		set_entvar(pEntity, var_solid, SOLID_NOT)
	}
}



