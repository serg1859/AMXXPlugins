// Copyright © 2016 Vaqtincha

#include <amxmodx>
#include <csdm>
#include <fakemeta>
#include <xs>


#define IsVectorZero(%1) 			(%1[X] == 0.0 && %1[Y] == 0.0 && %1[Z] == 0.0)

const MAX_SPAWNS = 64

const Float:ADD_Z_POSITION = 15.0

const MENU_KEY_BITS = (MENU_KEY_1|MENU_KEY_2|MENU_KEY_3|MENU_KEY_4|MENU_KEY_5|MENU_KEY_6|MENU_KEY_8)
const MENU_KEY_BITS_2 = (MENU_KEY_0|MENU_KEY_1|MENU_KEY_2|MENU_KEY_3)

enum coord_e { Float:X, Float:Y, Float:Z }

enum 
{
	FAILED_CREATE,
	FILE_SAVED,
	FILE_DELETED
}

new const Float:g_flGravity[] = {1.0, 0.5, 0.25}
new const Float:g_flSpeed[] = {250.0, 350.0, 450.0}
new const Float:g_flDistance[] = {500.0, 1000.0, 2000.0}

new const g_szModel[] = "models/player/vip/vip.mdl"
new const g_szClassName[] = "view_spawn"
new const g_szEditorMenuTitle[] = "SpawnEditor"
new const g_szSettingsMenuTitle[] = "SettingsMenu"

new HookChain:g_hGetPlayerSpawnSpot, HookChain:g_hResetMaxSpeed

new Float:g_flSpotOrigin[MAX_SPAWNS][coord_e]
new Float:g_flSpotVAngles[MAX_SPAWNS][coord_e]
new Float:g_flSpotAngles[MAX_SPAWNS][coord_e]

new g_pAimedEntity[MAX_CLIENTS + 1], g_iLastSpawnIndex[MAX_CLIENTS + 1], bool:g_bFirstSpawn[MAX_CLIENTS + 1]
new g_szSpawnDirectory[MAX_CONFIG_PATH_LEN], g_szSpawnFile[MAX_CONFIG_PATH_LEN + 32], g_szMapName[32], g_szAuthorName[32]
new g_iTotalPoints, g_iEditorMenuID, g_iSettingsMenuID, bool:g_bEditSpawns, bool:g_bNotSaved
new g_iGravity, g_iSpeed, g_iDistance = 1


public plugin_init()
{
	register_plugin("CSDM Spawn Manager", CSDM_VERSION_STRING, "Vaqtincha")
	register_concmd("csdm_edit_spawns", "ConCmd_EditSpawns", ADMIN_MAP, "Edits spawn configuration")
	register_clcmd("nightvision", "ClCmd_Nightvision") 
	register_menucmd((g_iEditorMenuID = register_menuid(g_szEditorMenuTitle)), MENU_KEY_BITS, "EditorMenuHandler")
	register_menucmd((g_iSettingsMenuID = register_menuid(g_szSettingsMenuTitle)), MENU_KEY_BITS_2, "SettingsMenuHandler")

	DisableHookChain(g_hGetPlayerSpawnSpot = RegisterHookChain(RG_CSGameRules_GetPlayerSpawnSpot, "CSGameRules_GetPlayerSpawnSpot", .post = true))
	DisableHookChain(g_hResetMaxSpeed = RegisterHookChain(RG_CBasePlayer_ResetMaxSpeed, "CBasePlayer_ResetMaxSpeed", .post = false))
}

public plugin_cfg()
{
	new iLen = get_localinfo("amxx_configsdir", g_szSpawnDirectory, charsmax(g_szSpawnDirectory))
	iLen = formatex(g_szSpawnDirectory[iLen], charsmax(g_szSpawnDirectory) - iLen, "%s/%s/%s", g_szSpawnDirectory[iLen], g_szMainDir, g_szSpawnDir)
	MakeDir(g_szSpawnDirectory)

	get_mapname(g_szMapName, charsmax(g_szMapName))
	formatex(g_szSpawnFile, charsmax(g_szSpawnFile), "%s/%s.spawns.cfg", g_szSpawnDirectory, g_szMapName)
	LoadPoints()
}

public plugin_end()
{
	if(g_bEditSpawns && g_bNotSaved) // autosave
	{
		MakeDir(g_szSpawnDirectory)
		SavePoints()
	}
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

	return ShowEditorMenu(pPlayer)
}

public ConCmd_EditSpawns(const pPlayer, const level)
{
	if(!is_user_alive(pPlayer) || ~get_user_flags(pPlayer) & level)
		return PLUGIN_HANDLED

	if(g_bEditSpawns)
	{
		if(g_bNotSaved && SavePoints() == FAILED_CREATE)
		{
			console_print(pPlayer, "[CSDM] Autosave is failed. Please try again")
			return ShowEditorMenu(pPlayer)
		}

		console_print(pPlayer, "[CSDM] Spawn editor disabled")
		CloseOpenedMenu(pPlayer)
		RemoveAllSpotEntitys()
		g_bEditSpawns = false

		set_entvar(pPlayer, var_gravity, 1.0)
		DisableHookChain(g_hResetMaxSpeed)
		rg_reset_maxspeed(pPlayer)

		return PLUGIN_HANDLED
	}

	console_print(pPlayer, "[CSDM] Spawn editor enabled")
	get_user_name(pPlayer, g_szAuthorName, charsmax(g_szAuthorName))
	MakeAllSpotEntitys()
	g_bEditSpawns = true

	set_entvar(pPlayer, var_gravity, g_flGravity[g_iGravity])
	EnableHookChain(g_hResetMaxSpeed)
	rg_reset_maxspeed(pPlayer)

	return ShowEditorMenu(pPlayer)
}

public CBasePlayer_ResetMaxSpeed(const pPlayer)
{
	set_entvar(pPlayer, var_maxspeed, g_flSpeed[g_iSpeed])
	return HC_SUPERCEDE
}

public CSGameRules_GetPlayerSpawnSpot(const pPlayer)
{
	RandomSpawn(pPlayer)
}

RandomSpawn(const pPlayer)
{
	if(!g_iTotalPoints || g_bFirstSpawn[pPlayer])
		return

	new iRand = random(g_iTotalPoints), iAttempts, iLast = g_iLastSpawnIndex[pPlayer]
	while(iAttempts <= g_iTotalPoints)
	{
		iAttempts++
		// server_print("iRand %d iAttempts %d", iRand, iAttempts)
		if(iRand != iLast && !IsVectorZero(g_flSpotOrigin[iRand])
			&& IsHullVacant(g_flSpotOrigin[iRand], HULL_HUMAN, DONT_IGNORE_MONSTERS))
		{
			SetPlayerPosition(pPlayer, g_flSpotOrigin[iRand], g_flSpotVAngles[iRand])
			g_iLastSpawnIndex[pPlayer] = iRand
			break
		}

		if(iRand++ > g_iTotalPoints)
			iRand = random(g_iTotalPoints)
	}
}

public ShowEditorMenu(const pPlayer)
{
	new szMenu[512], Float:flOrigin[coord_e], iKeys, iLen
	get_entvar(pPlayer, var_origin, flOrigin)
	iLen = formatex(szMenu, charsmax(szMenu), "\ySpawn Editor^n^n")
	iKeys |= g_bNotSaved ? (MENU_KEY_2|MENU_KEY_5|MENU_KEY_6|MENU_KEY_8) : (MENU_KEY_2|MENU_KEY_5|MENU_KEY_6)

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
		\y6. \wSettings^n^n\
		%s^n",
		g_bNotSaved ? "\y8. \wSave manual" : "\d8. Save manual"
	)

	formatex(szMenu[iLen], charsmax(szMenu) - iLen, 
		"^n\wTotal spawns: \y%d^n\wCurrent position: \rX \y%0.f \rY \y%0.f \rZ \y%0.f",
		g_iTotalPoints, flOrigin[X], flOrigin[Y], flOrigin[Z]
	)

	show_menu(pPlayer, iKeys, szMenu, .title = g_szEditorMenuTitle)
	return PLUGIN_HANDLED
}

public ShowSettingsMenu(const pPlayer)
{
	new szMenu[512], iLen = formatex(szMenu, charsmax(szMenu), "\ySettings^n^n")
	formatex(szMenu[iLen], charsmax(szMenu) - iLen,
		"\y1. \wSpeed: \y%0.f^n\
		\y2. \wGravity: \y%0.2f^n\
		\y3. \wDistance: \y%0.f^n\
		^n^n\y0. \wBack^n",
		g_flSpeed[g_iSpeed], g_flGravity[g_iGravity], g_flDistance[g_iDistance]
	)

	show_menu(pPlayer, MENU_KEY_BITS_2, szMenu, .title = g_szSettingsMenuTitle)
	return PLUGIN_HANDLED
}

public EditorMenuHandler(const pPlayer, iKey)
{
	if(!g_bEditSpawns)
		return PLUGIN_HANDLED

	iKey++
	switch(iKey)
	{
		case 1: g_bNotSaved = bool:(g_pAimedEntity[pPlayer] == NULLENT ? AddSpawn(pPlayer) : MoveSpawn(pPlayer, g_pAimedEntity[pPlayer]))
		case 2:
		{
			if(g_pAimedEntity[pPlayer] == NULLENT)
			{
				if(!SetAimedEntity(pPlayer))
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
		case 6: return ShowSettingsMenu(pPlayer)
		case 8:
		{
			static const szResultPrint[][] = {"Failed to create file!^rPlease try again", "Saved successfully", "File deleted"}
			client_print(pPlayer, print_center, "%s", szResultPrint[SavePoints()])
		}
	}

	return ShowEditorMenu(pPlayer)
}

public SettingsMenuHandler(const pPlayer, iKey)
{
	if(!g_bEditSpawns)
		return PLUGIN_HANDLED

	iKey++
	switch(iKey)
	{
		case 1: 
		{
			if(g_iSpeed++ >= sizeof(g_flSpeed)-1)
				g_iSpeed = 0

			rg_reset_maxspeed(pPlayer)
		}
		case 2:
		{
			if(g_iGravity++ >= sizeof(g_flGravity)-1)
				g_iGravity = 0

			set_entvar(pPlayer, var_gravity, g_flGravity[g_iGravity])
		}
		case 3:
		{
			if(g_iDistance++ >= sizeof(g_flDistance)-1)
				g_iDistance = 0
		}
		case 10: return ShowEditorMenu(pPlayer)
	}

	return ShowSettingsMenu(pPlayer)
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
		server_print("[CSDM] No spawn points file found ^"%s^"", g_szMapName)
		return
	}

	new szDatas[MAX_LINE_LEN], szOrigin[coord_e][6], szTeam[3], szAngles[coord_e][6], szVAngles[coord_e][6]
	while(!feof(pFile))
	{
		fgets(pFile, szDatas, charsmax(szDatas))
		trim(szDatas)

		if(!szDatas[0] || IsCommentLine(szDatas))
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
		{
			server_print("[CSDM] Max limit %d reached!", MAX_SPAWNS)
			break
		}

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
		server_print("[CSDM] Loaded %d spawn points for map ^"%s^"", g_iTotalPoints, g_szMapName)
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
	{
		MakeDir(g_szSpawnDirectory, false)
		return FAILED_CREATE
	}

	fprintf(pFile, "// Spawn file created by ^"%s^"^n// Total spawns: %d^n^n", g_szAuthorName, g_iTotalPoints)
	ClearAllArrays()

	while((pEntity = rg_find_ent_by_class(pEntity, g_szClassName)))
	{
		GetPosition(pEntity, g_flSpotOrigin[g_iTotalPoints], g_flSpotAngles[g_iTotalPoints], g_flSpotVAngles[g_iTotalPoints])
		if(IsVectorZero(g_flSpotOrigin[g_iTotalPoints]))
			continue

		if(g_iTotalPoints >= MAX_SPAWNS)
		{
			server_print("[CSDM] Max limit %d reached!", MAX_SPAWNS)
			break
		}

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
	ArraySet(g_pAimedEntity, NULLENT)
	while((pEntity = rg_find_ent_by_class(pEntity, g_szClassName)))
	{
		REMOVE_ENTITY(pEntity)
	}
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
	rg_animate_entity(pEntity, ACT_IDLE)

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
	new pEntity = FindEntityByAim(pPlayer, g_szClassName, g_flDistance[g_iDistance])
	if(pEntity == NULLENT)
		return false

	rg_animate_entity(pEntity, ACT_RUN, 1.0)
	rg_set_rendering(pEntity, kRenderFxGlowShell, Vector(0, 250, 0), 20.0)

	g_pAimedEntity[pPlayer] = pEntity
	client_print(pPlayer, print_center, "Aimed entity index %d", g_pAimedEntity[pPlayer])
	return true
}

ClearAimedEntity(const pPlayer)
{
	rg_animate_entity(g_pAimedEntity[pPlayer], ACT_IDLE)
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

CloseOpenedMenu(const pPlayer) 
{
	new iMenuID, iKeys
	get_user_menu(pPlayer, iMenuID, iKeys)
	if(iMenuID == g_iEditorMenuID || iMenuID == g_iSettingsMenuID)
	{
		menu_cancel(pPlayer)
		show_menu(pPlayer, 0, "^n", 1)
	}
}

stock rg_animate_entity(const pEntity, const Activity:iSequence, const Float:flFramerate = 0.0)
{
	set_entvar(pEntity, var_sequence, iSequence)
	set_entvar(pEntity, var_framerate, flFramerate)
}

stock FindEntityByAim(const pPlayer, const szClassName[], const Float:iMaxDistance = 8191.0)
{
	new Float:vecSrc[3], Float:vecEnd[3], ptr, pEntity = NULLENT
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




