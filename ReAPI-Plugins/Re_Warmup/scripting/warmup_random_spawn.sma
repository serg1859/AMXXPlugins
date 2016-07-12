
#include <amxmodx>
#include <fakemeta>
#include <reapi>
#include <re_warmup_api>

#define MAX_SPAWNS		64
#define MAX_PATH_LEN	186
#define CUSTOM_BUYZONE	-919

new Float:g_flSpawns[MAX_SPAWNS][9], HookChain:g_hPlayerSpawn, g_iSpawnCount
new g_pCvarWarmupRandom
new const BUYZONE[] = "func_buyzone"
new g_iLastSpawnIndex[MAX_CLIENTS+1]

public plugin_init()
{
	register_plugin("Warmup Spawn Random", "0.0.4", "Vaqtincha")
	g_pCvarWarmupRandom = register_cvar("warmup_random_spawn", "1")
	DisableHookChain(g_hPlayerSpawn = RegisterHookChain(RG_CBasePlayer_Spawn, "CBasePlayer_Spawn", .post = true))
	readspawns()
}

public WarmupStarted(WarmupModes:iMode, iTime)
{
	if(get_pcvar_num(g_pCvarWarmupRandom))
	{
		EnableHookChain(g_hPlayerSpawn)
		if(iMode == FREE_BUY || iMode == EQUIP_MENU)
			CreateBuyZone()
	}
}

public WarmupEnded()
{
	if(g_hPlayerSpawn)
		DisableHookChain(g_hPlayerSpawn)

	RemoveBuyZone()
}

public plugin_pause()
{
	RemoveBuyZone()
}

public client_putinserver(id) 
	g_iLastSpawnIndex[id] = -1

public CBasePlayer_Spawn(id)
{
	if(is_user_alive(id))
	{
		do_random_spawn(id)
	}
}

// Original code by Avalanche
readspawns()
{
	new SpawnFile[MAX_PATH_LEN + 32], MapName[32], fp
	get_localinfo("amxx_configsdir", SpawnFile, charsmax(SpawnFile))
	get_mapname(MapName, charsmax(MapName))

	formatex(SpawnFile, charsmax(SpawnFile), "%s/warmup_spawns/%s.spawns.cfg", SpawnFile, MapName)
	// collect CSDM spawns
	if(file_exists(SpawnFile))
	{
		fp = fopen(SpawnFile,"rt")
		while(fp && !feof(fp))
		{
			new csdmData[10][6], lineData[64]
			fgets(fp, lineData, charsmax(lineData))
			// invalid spawn
			if(!lineData[0] || str_count(lineData,' ') < 2)
				continue

			// BREAK IT UP!
			parse(
					lineData,csdmData[0],5,csdmData[1],5,
					csdmData[2],5,csdmData[3],5,csdmData[4],5,
					csdmData[5],5,csdmData[6],5,csdmData[7],5,
					csdmData[8],5,csdmData[9],5
				)
			// origin
			g_flSpawns[g_iSpawnCount][0] = floatstr(csdmData[0])
			g_flSpawns[g_iSpawnCount][1] = floatstr(csdmData[1])
			g_flSpawns[g_iSpawnCount][2] = floatstr(csdmData[2])
			// angles
			g_flSpawns[g_iSpawnCount][3] = floatstr(csdmData[3])
			g_flSpawns[g_iSpawnCount][4] = floatstr(csdmData[4])
			g_flSpawns[g_iSpawnCount][5] = floatstr(csdmData[5])
			// team, csdmData[6], unused
			// vangles
			g_flSpawns[g_iSpawnCount][6] = floatstr(csdmData[7])
			g_flSpawns[g_iSpawnCount][7] = floatstr(csdmData[8])
			g_flSpawns[g_iSpawnCount][8] = floatstr(csdmData[9])

			g_iSpawnCount++

			if(g_iSpawnCount >= MAX_SPAWNS) break
		}
		server_print("[WARMUP] Loaded %d spawn points for map %s", g_iSpawnCount, MapName)
		if(fp) fclose(fp)
	}// collect regular, boring spawns
	else{
		server_print("[WARMUP] No spawn points file found %s", MapName)
	}
}

do_random_spawn(id)
{
	if(g_iSpawnCount < 2)
		return

	new Float:vecHolder[3], sp_index = 0
	sp_index = random_num(0, g_iSpawnCount-1)

	// get origin for comparisons
	vecHolder[0] = g_flSpawns[sp_index][0]
	vecHolder[1] = g_flSpawns[sp_index][1]
	vecHolder[2] = g_flSpawns[sp_index][2]

	if(!is_hull_vacant(vecHolder, HULL_HUMAN) || sp_index == g_iLastSpawnIndex[id])
	{
		new newe2, i
		for(i = 0; i < sizeof(g_flSpawns); i++)
		{
			if(i == g_iLastSpawnIndex[id])
				continue

			i = random_num(0, g_iSpawnCount-1)
			if(i == g_iLastSpawnIndex[id])
				continue

			newe2 = random_num(i, g_iSpawnCount-1)
			// get origin for comparisons
			vecHolder[0] = g_flSpawns[newe2][0]
			vecHolder[1] = g_flSpawns[newe2][1]
			vecHolder[2] = g_flSpawns[newe2][2]
			if(is_hull_vacant(vecHolder, HULL_HUMAN)) 
			{
				sp_index = newe2
				break
			}else{
				return
			}
		}
	}

	// origin
	vecHolder[0] = g_flSpawns[sp_index][0]
	vecHolder[1] = g_flSpawns[sp_index][1]
	vecHolder[2] = g_flSpawns[sp_index][2]
	engfunc(EngFunc_SetOrigin,id,vecHolder)

	// angles
	vecHolder[0] = g_flSpawns[sp_index][3]
	vecHolder[1] = g_flSpawns[sp_index][4]
	vecHolder[2] = g_flSpawns[sp_index][5]
	set_pev(id,pev_angles,vecHolder)

	// vangles
	vecHolder[0] = g_flSpawns[sp_index][6]
	vecHolder[1] = g_flSpawns[sp_index][7]
	vecHolder[2] = g_flSpawns[sp_index][8]
	set_pev(id,pev_v_angle,vecHolder)
	set_pev(id,pev_fixangle,1)

	g_iLastSpawnIndex[id] = sp_index
}

RemoveBuyZone()
{
	new iEnt = FM_NULLENT
	while((iEnt = engfunc(EngFunc_FindEntityByString, iEnt, "classname", BUYZONE)) > 0)
	{
		if(pev(iEnt, pev_iuser1) == CUSTOM_BUYZONE)
			engfunc(EngFunc_RemoveEntity, iEnt)
	}
}

CreateBuyZone()
{
	new iEnt = engfunc(EngFunc_CreateNamedEntity, engfunc(EngFunc_AllocString, BUYZONE))
	dllfunc(DLLFunc_Spawn, iEnt)
	engfunc(EngFunc_SetSize, iEnt, {-8191.0, -8191.0, -8191.0}, {8191.0, 8191.0, 8191.0})
	engfunc(EngFunc_SetOrigin, iEnt, Float:{0.0, 0.0, 0.0})
	set_pev(iEnt, pev_iuser1, CUSTOM_BUYZONE)
}

stock str_count(str[], searchchar)
{
	new i = 0
	new maxlen = strlen(str)
	new count = 0
	for(i=0; i<=maxlen; i++)
	{
		if(str[i] == searchchar)
			count++
	}
	return count
}

// checks if a space is vacant, by VEN

stock bool:is_hull_vacant(const Float:origin[3], hull) 
{
	new tr = 0
	engfunc(EngFunc_TraceHull, origin, origin, 0, hull, 0, tr)

	return bool:(!get_tr2(tr, TR_StartSolid) && !get_tr2(tr, TR_AllSolid) && get_tr2(tr, TR_InOpen))
}

