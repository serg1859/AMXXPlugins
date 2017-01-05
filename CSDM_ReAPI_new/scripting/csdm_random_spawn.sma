// Copyright © 2016 Vaqtincha

#include <amxmodx>
#include <csdm>
#include <fakemeta>


#define SET_ORIGIN(%1,%2) 		engfunc(EngFunc_SetOrigin, %1, %2)

const MIN_SPAWNS			=	10
const MAX_SPAWNS			=	64

enum coord_e { X, Y, Z }

new Float:g_flSpotOrigin[MAX_SPAWNS][coord_e]
new Float:g_flSpotVAngles[MAX_SPAWNS][coord_e]
new Float:g_flSpotAngles[MAX_SPAWNS][coord_e]

new g_iLastSpawnIndex[MAX_CLIENTS + 1]
new g_iTotalPoints

new g_szDirectory[] = "csdm"


public plugin_init()
{
	register_plugin("CSDM Random Spawn", CSDM_VERSION_STRING, "Vaqtincha")
}

public plugin_cfg()
{
	// if(!CSDM_LOADED())
		// return

	LoadPoints()
}

LoadPoints()
{
	new szSpawnFile[MAX_CONFIG_PATH_LEN + 32], szMapName[32]

	get_localinfo("amxx_configsdir", szSpawnFile, charsmax(szSpawnFile))
	get_mapname(szMapName, charsmax(szMapName))

	format(szSpawnFile, charsmax(szSpawnFile), "%s/%s/spawns/%s.spawns.cfg", szSpawnFile, g_szDirectory, szMapName)

	new pFile = fopen(szSpawnFile, "rt")
	if(!pFile)
	{
		return server_print("[CSDM] No spawn points file found %s", szMapName)	
	}

	new szDatas[64], szOrigin[coord_e][6], szTeam[3], szAngles[coord_e][6], szVAngles[coord_e][6]

	while(!feof(pFile))
	{
		fgets(pFile, szDatas, charsmax(szDatas))
		trim(szDatas)
		
		if(!szDatas[0])
			continue

		if(parse(szDatas, 
					szOrigin[X], 5, szOrigin[Y], 5, szOrigin[Z], 5, 
					szAngles[X], 5, szAngles[Y], 5, szAngles[Z], 5,
					szTeam, charsmax(szTeam), // ignore team param = 7
					szVAngles[X], 5, szVAngles[Y], 5, szVAngles[Z], 5
				) != 10)
		{
			continue
		}

		g_flSpotOrigin[g_iTotalPoints][X] = str_to_float(szOrigin[X])
		g_flSpotOrigin[g_iTotalPoints][Y] = str_to_float(szOrigin[Y])
		g_flSpotOrigin[g_iTotalPoints][Z] = str_to_float(szOrigin[Z])

		g_flSpotAngles[g_iTotalPoints][X] = str_to_float(szAngles[X])
		g_flSpotAngles[g_iTotalPoints][Y] = str_to_float(szAngles[Y])
		g_flSpotAngles[g_iTotalPoints][Z] = str_to_float(szAngles[Z])

		g_flSpotVAngles[g_iTotalPoints][X] = str_to_float(szVAngles[X])
		g_flSpotVAngles[g_iTotalPoints][Y] = str_to_float(szVAngles[Y])
		g_flSpotVAngles[g_iTotalPoints][Z] = str_to_float(szVAngles[Z])

		g_iTotalPoints++

		if(g_iTotalPoints >= MAX_SPAWNS)
			break
	}

	if(g_iTotalPoints < MIN_SPAWNS)
	{
		server_print("[CSDM] WARNING: SpawnCount %d is low!", g_iTotalPoints)
	}
	else
	{
		server_print("[CSDM] Loaded %d spawn points for map %s", g_iTotalPoints, szMapName)

		RegisterHookChain(RG_CSGameRules_GetPlayerSpawnSpot, "CSGameRules_GetPlayerSpawnSpot", .post = true)
	}
	
	return fclose(pFile)
}

public client_putinserver(pPlayer)
{
	g_iLastSpawnIndex[pPlayer] = -1
}

public CSGameRules_GetPlayerSpawnSpot(const pPlayer)
{
	SetPlayerSpawnSpot(pPlayer)
}

SetPlayerSpawnSpot(const pPlayer)
{
	new iRand, iAttempts
	do
	{
		iRand = random(g_iTotalPoints)
		if(iRand != g_iLastSpawnIndex[pPlayer] && is_hull_vacant(g_flSpotOrigin[iRand], HULL_HUMAN))
		{
			SET_ORIGIN(pPlayer, g_flSpotOrigin[iRand])
			set_pev(pPlayer, pev_v_angle, g_flSpotVAngles[iRand])
			// set_pev(pPlayer, pev_fixangle, 1)
			set_pev(pPlayer, pev_angles, g_flSpotAngles[iRand])
			set_pev(pPlayer, pev_fixangle, 1)

			g_iLastSpawnIndex[pPlayer] = iRand
			break
		}

	}while(iAttempts++ <= g_iTotalPoints)
}

// checks if a space is vacant, by VEN
stock bool:is_hull_vacant(const Float:flOrigin[3], const hull) 
{
	new tr
	engfunc(EngFunc_TraceHull, flOrigin, flOrigin, DONT_IGNORE_MONSTERS, hull, 0, tr)

	return bool:(!get_tr2(tr, TR_StartSolid) && !get_tr2(tr, TR_AllSolid) && get_tr2(tr, TR_InOpen))
}



