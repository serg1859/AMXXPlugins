// Copyright © 2016 Vaqtincha

#include <amxmodx>
#include <fakemeta>
#include <csdm>
#include <xs>


#define REMOVE_ENTITY(%1) 			engfunc(EngFunc_RemoveEntity, %1)
#define SET_ORIGIN(%1,%2) 			engfunc(EngFunc_SetOrigin, %1, %2)
#define SET_MODEL(%1,%2)			engfunc(EngFunc_SetModel, %1, %2)
#define IsVectorZero(%1) 			(%1[X] == 0.0 && %1[Y] == 0.0 && %1[Z] == 0.0)

const MAX_SPAWNS = 64
const Float:ADD_Z_POSITION = 15.0

const SEQUENCE_ACT_IDLE = 1
const SEQUENCE_ACT_RUN = 4

const MENU_KEY_BITS = (MENU_KEY_1|MENU_KEY_2|MENU_KEY_3|MENU_KEY_4|MENU_KEY_5|MENU_KEY_8)

enum coord_e { Float:X, Float:Y, Float:Z }

enum 
{
	FAILED_CREATE,
	FILE_SAVED,
	FILE_DELETED
}

new const g_szModel[] = "models/player/vip/vip.mdl"
new const g_szClassName[] = "view_spawn"
new const g_szMenuTitle[] = "SpawnEditor"

new HookChain:g_hGetPlayerSpawnSpot

new Float:g_flSpotOrigin[MAX_SPAWNS][coord_e]
new Float:g_flSpotVAngles[MAX_SPAWNS][coord_e]
new Float:g_flSpotAngles[MAX_SPAWNS][coord_e]

new g_pAimedEntity[MAX_CLIENTS + 1], g_iLastSpawnIndex[MAX_CLIENTS + 1], bool:g_bFirstSpawn[MAX_CLIENTS + 1]
new g_szSpawnFile[MAX_CONFIG_PATH_LEN + 32], g_szMapName[32], g_szAuthorName[32]
new g_iTotalPoints, bool:g_bEditSpawns, bool:g_bNotSaved


public plugin_init()
{
	register_plugin("CSDM Spawn Manager", CSDM_VERSION_STRING, "Vaqtincha")
	register_concmd("csdm_edit_spawns", "ConCmd_EditSpawns", ADMIN_MAP, "Edits spawn configuration")
	register_clcmd("nightvision", "ClCmd_Nightvision") 
	register_menucmd(register_menuid(g_szMenuTitle), MENU_KEY_BITS, "MenuHandler")

	DisableHookChain(g_hGetPlayerSpawnSpot = RegisterHookChain(RG_CSGameRules_GetPlayerSpawnSpot, "CSGameRules_GetPlayerSpawnSpot", .post = false))
}

public plugin_cfg()
{
	new iLen = get_localinfo("amxx_configsdir", g_szSpawnFile, charsmax(g_szSpawnFile))
	get_mapname(g_szMapName, charsmax(g_szMapName))
	formatex(g_szSpawnFile[iLen], charsmax(g_szSpawnFile) - iLen, "%s/%s/%s/%s.spawns.cfg", g_szSpawnFile[iLen], g_szMainDir, g_szSpawnDir, g_szMapName)

	LoadPoints()
}

public plugin_end()
{
	if(g_bEditSpawns && g_bNotSaved) // autosave
		SavePoints()
}

public CSDM_Initialized(const szVersion[])
{
	if(!szVersion[0])
		pause("ad")
}

public CSDM_ExecuteCVarValues()
{
	set_member_game(m_iSpawnPointCount_Terrorist, get_member_game(m_iSpawnPointCount_Terrorist) + g_iTotalPoints)
	set_member_game(m_iSpawnPointCount_CT, get_member_game(m_iSpawnPointCount_CT) + g_iTotalPoints)
}

public CSDM_RestartRound(const bool:bNewGame)
{
	if(bNewGame)
	{
		ArraySet(g_iLastSpawnIndex, INVALID_INDEX)
	}
}

public client_connect(pPlayer)
{
	g_bFirstSpawn[pPlayer] = true
}

public client_putinserver(pPlayer)
{
	g_pAimedEntity[pPlayer] = NULLENT
	g_iLastSpawnIndex[pPlayer] = INVALID_INDEX
	g_bFirstSpawn[pPlayer] = false
}

public ClCmd_Nightvision(const pPlayer, const level)
{
	if(!g_bEditSpawns || !is_user_alive(pPlayer) || ~get_user_flags(pPlayer) & level)
		return PLUGIN_CONTINUE

	return ShowMenu(pPlayer)
}

public ConCmd_EditSpawns(const pPlayer, const level)
{
	if(!is_user_alive(pPlayer) || ~get_user_flags(pPlayer) & level)
		return PLUGIN_HANDLED

	if(g_bEditSpawns)
	{
		if(g_bNotSaved && SavePoints() == FAILED_CREATE)
		{
			console_print(pPlayer, "[CSDM] Autosave is failed. Try again manually")
			return ShowMenu(pPlayer)
		}

		console_print(pPlayer, "[CSDM] Spawn editor disabled")
		RemoveAllSpotEntitys()
		g_bEditSpawns = false

		return PLUGIN_HANDLED
	}

	get_user_name(pPlayer, g_szAuthorName, charsmax(g_szAuthorName))
	console_print(pPlayer, "[CSDM] Spawn editor enabled")
	MakeAllSpotEntitys()
	g_bEditSpawns = true

	return ShowMenu(pPlayer)
}

public CSGameRules_GetPlayerSpawnSpot(const pPlayer)
{
	if(!g_bFirstSpawn[pPlayer] && RandomSpawn(pPlayer))
	{
		SetHookChainReturn(ATYPE_INTEGER, NULLENT) // invalid spot entity
		return HC_SUPERCEDE
	}

	return HC_CONTINUE
}

bool:RandomSpawn(const pPlayer)
{
	if(!g_iTotalPoints)
		return false

	new iRand = random(g_iTotalPoints), iAttempts
	do
	{	
		iAttempts++
		// server_print("iRand %d iAttempts %d", iRand, iAttempts)
		if(iRand != g_iLastSpawnIndex[pPlayer] && !IsVectorZero(g_flSpotOrigin[iRand])
			&& IsHullVacant(g_flSpotOrigin[iRand], HULL_HUMAN, DONT_IGNORE_MONSTERS))
		{
			SetPlayerPosition(pPlayer, g_flSpotOrigin[iRand], g_flSpotVAngles[iRand])
			g_iLastSpawnIndex[pPlayer] = iRand
			return true	// break
		}

		if(iRand++ > g_iTotalPoints)
			iRand = random(g_iTotalPoints)

	}while(iAttempts < g_iTotalPoints)

	return false
}

public ShowMenu(const pPlayer)
{
	new szMenu[512], Float:flOrigin[coord_e], iKeys, iLen
	get_entvar(pPlayer, var_origin, flOrigin)
	iLen = formatex(szMenu, charsmax(szMenu), "\ySpawn Editor^n^n")
	iKeys |= g_bNotSaved ? (MENU_KEY_2|MENU_KEY_5|MENU_KEY_8) : (MENU_KEY_2|MENU_KEY_5)

	if(g_pAimedEntity[pPlayer] == NULLENT)
	{
		iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, 
			"%s^n^n\
			\y2. \wMark aimed spawn^n\
			\d3. Teleport me^n\
			\d4. Delete spawn^n^n",
			(g_iTotalPoints >= MAX_SPAWNS) ? "\d1. Add new spawn\w(\rMax limit reached!\w)" : "\y1. \wAdd new spawn"
		)
		iKeys |= (g_iTotalPoints >= MAX_SPAWNS) ? 0 : MENU_KEY_1
	}
	else
	{
		iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, 
			"\y1. \wUpdate position^n^n\
			\y2. \wUnmark marked spawn^n\
			\y3. \wTeleport me^n\
			\y4. \wDelete spawn^n^n"
		)
		iKeys |= (MENU_KEY_1|MENU_KEY_3|MENU_KEY_4)
	}

	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, 
		"\y5. \wReflesh info^n\
		%s^n",
		g_bNotSaved ? "\y8. \wSave manual" : "\d8. Save manual"
	)

	formatex(szMenu[iLen], charsmax(szMenu) - iLen, 
		"^n^n\wTotal spawns: \y%d^n\wCurrent position: \rX \y%0.f \rY \y%0.f \rZ \y%0.f",
		g_iTotalPoints, flOrigin[X], flOrigin[Y], flOrigin[Z]
	)

	show_menu(pPlayer, iKeys, szMenu, .title = g_szMenuTitle)
	return PLUGIN_HANDLED
}

public MenuHandler(const pPlayer, iKey)
{
	iKey++
	switch(iKey)
	{
		case 1: g_bNotSaved = bool:(g_pAimedEntity[pPlayer] == NULLENT ? AddSpawn(pPlayer) : MoveSpawn(pPlayer, g_pAimedEntity[pPlayer]))
		case 2:
		{
			if(g_pAimedEntity[pPlayer] == NULLENT && !SetAimedEntity(pPlayer))
			{
				client_print(pPlayer, print_center, "Spawn entity not found!")
			}
			else
			{
				ClearAimedEntity(pPlayer)
				SetAimedEntity(pPlayer)
			}
		}
		case 3: TeleportToAimed(pPlayer, g_pAimedEntity[pPlayer])
		case 4: g_bNotSaved = bool:DeleteSpawn(pPlayer, g_pAimedEntity[pPlayer])
		case 5:
		{
			new Float:flOrigin[coord_e]
			get_entvar(pPlayer, var_origin, flOrigin)

			CSDM_PrintChat(pPlayer, GREY, 
				"Total spawns: ^4%d ^1Current position: ^3X ^4%0.f ^3Y ^4%0.f ^3Z ^4%0.f", 
					g_iTotalPoints, flOrigin[X], flOrigin[Y], flOrigin[Z])
		}
		case 8:
		{
			static const szResultPrint[][] = {"Failed to create file!", "Saved successfully", "File deleted"}
			client_print(pPlayer, print_center, "%s", szResultPrint[SavePoints()])
		}
	}

	return ShowMenu(pPlayer)
}

bool:AddSpawn(const pPlayer)
{
	new Float:flOrigin[coord_e], Float:flAngles[coord_e], Float:flVAngles[coord_e], pEntity = NULLENT
	GetPosition(pPlayer, flOrigin, flAngles, flVAngles)
	flOrigin[Z] += ADD_Z_POSITION

	if(!IsFreeSpace(pPlayer, flOrigin) || (pEntity = CreateEntity()) == NULLENT)
		return false

	SetPosition(pEntity, flOrigin, flAngles, flVAngles)
	g_iTotalPoints++

	return true
}

bool:MoveSpawn(const pPlayer, const pEntity = NULLENT)
{
	new Float:flOrigin[coord_e], Float:flAngles[coord_e], Float:flVAngles[coord_e]
	GetPosition(pPlayer, flOrigin, flAngles, flVAngles)
	flOrigin[Z] += ADD_Z_POSITION

	if(IsFreeSpace(pPlayer, flOrigin))
	{
		SetPosition(pEntity, flOrigin, flAngles, flVAngles)
		return true
	}
	return false
}

bool:DeleteSpawn(const pPlayer, const pEntity = NULLENT)
{
	if(is_nullent(pEntity))
		return false

	new Float:flOrigin[coord_e]
	get_entvar(pEntity, var_origin, flOrigin)

	g_pAimedEntity[pPlayer] = NULLENT
	REMOVE_ENTITY(pEntity)
	g_iTotalPoints--

	return true
}

bool:TeleportToAimed(const pPlayer, const pEntity = NULLENT)
{
	if(pEntity == NULLENT)
		return false

	new Float:flOrigin[coord_e], Float:flAngles[coord_e], Float:flVAngles[coord_e]
	GetPosition(pEntity, flOrigin, flAngles, flVAngles)

	if(IsFreeSpace(pPlayer, flOrigin))
	{
		SetPlayerPosition(pPlayer, flOrigin, flVAngles)
		return true
	}
	return false
}

LoadPoints()
{
	new pFile
	if(!(pFile = fopen(g_szSpawnFile, "rt")))
	{
		server_print("[CSDM] No spawn points file found %s", g_szMapName)
		return
	}

	new szDatas[64], szOrigin[coord_e][6], szTeam[3], szAngles[coord_e][6], szVAngles[coord_e][6]
	while(!feof(pFile))
	{
		fgets(pFile, szDatas, charsmax(szDatas))
		trim(szDatas)

		if(!szDatas[0] || (szDatas[0] == '/' && szDatas[1] == '/'))
			continue

		if(parse(szDatas, 
					szOrigin[X], 5, szOrigin[Y], 5, szOrigin[Z], 5, 
					szAngles[X], 5, szAngles[Y], 5, szAngles[Z], 5,
					szTeam, charsmax(szTeam), // ignore team param 7
					szVAngles[X], 5, szVAngles[Y], 5, szVAngles[Z], 5
				) != 10)
		{
			continue
		}

		if(g_iTotalPoints >= MAX_SPAWNS)
			break

		g_flSpotOrigin[g_iTotalPoints][X] = str_to_float(szOrigin[X])
		g_flSpotOrigin[g_iTotalPoints][Y] = str_to_float(szOrigin[Y])
		g_flSpotOrigin[g_iTotalPoints][Z] = str_to_float(szOrigin[Z])

		g_flSpotAngles[g_iTotalPoints][X] = str_to_float(szAngles[X])
		g_flSpotAngles[g_iTotalPoints][Y] = str_to_float(szAngles[Y])
		// g_flSpotAngles[g_iTotalPoints][Z] = str_to_float(szAngles[Z])

		g_flSpotVAngles[g_iTotalPoints][X] = str_to_float(szVAngles[X])
		g_flSpotVAngles[g_iTotalPoints][Y] = str_to_float(szVAngles[Y])
		// g_flSpotVAngles[g_iTotalPoints][Z] = str_to_float(szVAngles[Z])

		g_iTotalPoints++
	}
	if(g_iTotalPoints)
	{
		server_print("[CSDM] Loaded %d spawn points for map %s", g_iTotalPoints, g_szMapName)
		EnableHookChain(g_hGetPlayerSpawnSpot)
	}

	fclose(pFile)
}

SavePoints()
{
	if(!g_iTotalPoints)
	{
		delete_file(g_szSpawnFile)
		DisableHookChain(g_hGetPlayerSpawnSpot)
		return FILE_DELETED
	}

	new pFile, pEntity = NULLENT
	if(!(pFile = fopen(g_szSpawnFile, "wt")))
		return FAILED_CREATE

	fprintf(pFile, "// Spawn file created by ^"%s^"^n// Total spawns: %d^n^n", g_szAuthorName, g_iTotalPoints)
	ClearAllArrays()

	while((pEntity = rg_find_ent_by_class(pEntity, g_szClassName)))
	{
		GetPosition(pEntity, g_flSpotOrigin[g_iTotalPoints], g_flSpotAngles[g_iTotalPoints], g_flSpotVAngles[g_iTotalPoints])
		if(IsVectorZero(g_flSpotOrigin[g_iTotalPoints]))
			continue

		if(g_iTotalPoints >= MAX_SPAWNS)
			break

		fprintf(pFile,
			"%-6.f %-5.f %-5.f %-4.f %-5.f %-2.f %-2.1d %-4.f %-5.f %-1.f^n", 
			g_flSpotOrigin[g_iTotalPoints][X], g_flSpotOrigin[g_iTotalPoints][Y], g_flSpotOrigin[g_iTotalPoints][Z],
			g_flSpotAngles[g_iTotalPoints][X],  g_flSpotAngles[g_iTotalPoints][Y],  g_flSpotAngles[g_iTotalPoints][Z], 
			0, // ignore team param 7
			g_flSpotVAngles[g_iTotalPoints][X],  g_flSpotVAngles[g_iTotalPoints][Y], g_flSpotVAngles[g_iTotalPoints][Z]
		)

		g_iTotalPoints++
	}

	g_iTotalPoints ? EnableHookChain(g_hGetPlayerSpawnSpot) : DisableHookChain(g_hGetPlayerSpawnSpot)
	g_bNotSaved = false
	fclose(pFile)

	return FILE_SAVED
}

MakeAllSpotEntitys()
{
	if(!g_iTotalPoints)
		return

	for(new i = 0; i < MAX_SPAWNS; i++)
	{
		if(IsVectorZero(g_flSpotOrigin[i]))
			continue

		SetPosition(CreateEntity(), g_flSpotOrigin[i], g_flSpotAngles[i], g_flSpotVAngles[i])
	}
}

RemoveAllSpotEntitys()
{
	new pEntity = NULLENT
	while((pEntity = rg_find_ent_by_class(pEntity, g_szClassName)))
	{
		REMOVE_ENTITY(pEntity)
	}
	ArraySet(g_pAimedEntity, NULLENT)	
	show_menu(0, 0, "^n", 1)
}

CreateEntity()
{
	new pEntity = rg_create_entity("info_target")
	if(is_nullent(pEntity))
	{
		server_print("Failed to create entity")
		return NULLENT
	}
	set_entvar(pEntity, var_classname, g_szClassName)
	SET_MODEL(pEntity, g_szModel)
	set_entvar(pEntity, var_solid, SOLID_NOT)
	set_entvar(pEntity, var_sequence, SEQUENCE_ACT_IDLE)
	return pEntity
}

SetPlayerPosition(const pPlayer, const Float:flOrigin[coord_e], const Float:flAngles[coord_e])
{
	SET_ORIGIN(pPlayer, flOrigin)
	set_entvar(pPlayer, var_velocity, VECTOR_ZERO)
	set_entvar(pPlayer, var_v_angle, VECTOR_ZERO)
	set_entvar(pPlayer, var_angles, flAngles)
	set_entvar(pPlayer, var_punchangle, VECTOR_ZERO)	
	set_entvar(pPlayer, var_fixangle, FORCE_VIEW_ANGLES)
}

SetPosition(const pEntity, const Float:flOrigin[coord_e], const Float:flAngles[coord_e], const Float:flVAngles[coord_e])
{
	if(pEntity != NULLENT)
	{
		SET_ORIGIN(pEntity, flOrigin)
		set_entvar(pEntity, var_angles, flAngles)
		set_entvar(pEntity, var_v_angle, flVAngles) // temporary save
	}
}

GetPosition(const pEntity, Float:flOrigin[coord_e], Float:flAngles[coord_e], Float:flVAngles[coord_e])
{
	get_entvar(pEntity, var_origin, flOrigin)
	get_entvar(pEntity, var_angles, flAngles)
	get_entvar(pEntity, var_v_angle, flVAngles)
}

bool:SetAimedEntity(const pPlayer)
{
	new pEntity = FindEntityByAim(pPlayer, g_szClassName)
	if(pEntity == NULLENT)
		return false

	rg_animate_entity(pEntity, SEQUENCE_ACT_RUN, 1.0)
	rg_set_rendering(pEntity, kRenderFxGlowShell, Vector(0, 250, 0), 20.0)

	g_pAimedEntity[pPlayer] = pEntity
	client_print(pPlayer, print_center, "Aimed entity index %d", g_pAimedEntity[pPlayer])
	return true
}

ClearAimedEntity(const pPlayer)
{
	rg_animate_entity(g_pAimedEntity[pPlayer], SEQUENCE_ACT_IDLE)
	rg_set_rendering(g_pAimedEntity[pPlayer])
	g_pAimedEntity[pPlayer] = NULLENT
}

ClearAllArrays()
{
	g_iTotalPoints = 0
	for(new i = 0; i < MAX_SPAWNS; i++)
	{
		g_flSpotOrigin[i][X] = g_flSpotOrigin[i][Y] = g_flSpotOrigin[i][Z] = 0.0
		g_flSpotVAngles[i][X] = g_flSpotVAngles[i][Y] = g_flSpotVAngles[i][Z] = 0.0
		g_flSpotAngles[i][X] = g_flSpotAngles[i][Y] = g_flSpotAngles[i][Z] = 0.0
	}
}

stock rg_animate_entity(const pEntity, const iSequence, const Float:flFramerate = 0.0)
{
	set_entvar(pEntity, var_sequence, iSequence)
	set_entvar(pEntity, var_framerate, flFramerate)
}

stock rg_set_rendering(const pEntity, const fx = kRenderFxNone, const Float:flColor[] = {0.0, 0.0, 0.0}, const Float:iAmount = 0.0)
{
	set_entvar(pEntity, var_renderfx, fx)
	set_entvar(pEntity, var_rendercolor, flColor)
	set_entvar(pEntity, var_renderamt, iAmount)
}

stock FindEntityByAim(const pPlayer, const szClassName[], const Float:iMaxDistance = 8191.0)
{
	new Float:vecSrc[3], Float:vecEnd[3], ptr, pEntity = FM_NULLENT
	get_entvar(pPlayer, var_origin, vecSrc)
	get_entvar(pPlayer, var_view_ofs, vecEnd)
	xs_vec_add(vecSrc, vecEnd, vecSrc)

	get_entvar(pPlayer, var_v_angle, vecEnd)
	engfunc(EngFunc_MakeVectors, vecEnd)
	global_get(glb_v_forward, vecEnd)
	xs_vec_mul_scalar(vecEnd, iMaxDistance, vecEnd)
	xs_vec_add(vecSrc, vecEnd, vecEnd)	

	ptr = create_tr2()
	while((pEntity = rg_find_ent_by_class(pEntity, szClassName)))
	{
		engfunc(EngFunc_TraceModel, vecSrc, vecEnd, HULL_POINT, pEntity, ptr)
		if(get_tr2(ptr, TR_pHit) == pEntity)
		{
			return pEntity
		}
	}
	free_tr2(ptr)
	return NULLENT
}

bool:IsFreeSpace(const pPlayer, const Float:flOrigin[coord_e])
{
	if(!IsHullVacant(flOrigin, HULL_HUMAN, IGNORE_MONSTERS))
	{
		client_print(pPlayer, print_center, "No free space!")
		return false
	}
	return true
}

// checks if a space is vacant, by VEN
stock bool:IsHullVacant(const Float:flOrigin[coord_e], const iHullNumber, const fNoMonsters) 
{
	new ptr
	engfunc(EngFunc_TraceHull, flOrigin, flOrigin, fNoMonsters, iHullNumber, 0, ptr)

	return bool:(!get_tr2(ptr, TR_StartSolid) && !get_tr2(ptr, TR_AllSolid) && get_tr2(ptr, TR_InOpen))
}




