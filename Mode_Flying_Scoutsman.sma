#include <amxmodx>
#include <cstrike>
#include <fun>
#include <fakemeta>
#include <fakemeta_util>
#include <hamsandwich>




enum {
	XO_WEAPON		= 4,
	m_pPlayer		= 41,
	m_iFOV			= 363,
	m_flAccuracy	= 62,
	m_flLastFire	= 63,
	m_iId			= 43,
#if !defined MAX_CLIENTS
	MAX_CLIENTS		= 32,
#endif

	random_seed		= 96
}

new bool: g_bModeEnabled;
new Float:g_vecVelocity[MAX_CLIENTS + 1][3];

enum any: H_TYPES_s {
	_PrimaryAttack_Pre,
	_PrimaryAttack_Post,
	_CBasePlayer_Spawn,
	_CBaseEntity_Touch
}

new any: Hooks[H_TYPES_s];

new const CLASS_WEAPON[] = "weapon_scout";
new const CLASS_ArouryEntity[] = "armoury_entity";

public plugin_init() {
	register_plugin("Mode: Flying Scoutsman", "0.0.1", "wopox1337@Dev-CS.ru");
	
	Hooks[_PrimaryAttack_Pre] = RegisterHam(Ham_Weapon_PrimaryAttack, CLASS_WEAPON, "CBasePlayerWeapon_PrimAttack", .Post = false);
	Hooks[_PrimaryAttack_Post] = RegisterHam(Ham_Weapon_PrimaryAttack, CLASS_WEAPON, "CBasePlayerWeapon_PrimAttackP", .Post = true);
	Hooks[_CBasePlayer_Spawn] = RegisterHam(Ham_Spawn, "player", "CBasePlayer_Spawn", .Post = true, .specialbot = true);
	Hooks[_CBaseEntity_Touch] = RegisterHam(Ham_Touch, CLASS_ArouryEntity, "CBaseEntity_Touch", .Post = false, .specialbot = true);
	
#if defined HIDE_ARMORYENTS
	register_event("HLTV", "event_NewRound", "a", "1=0", "2=0");
#endif

	new pCvar = create_cvar(
		.name = "mp_gamemode_Flying_Scoutsman",
		.string = "0",
		.flags = FCVAR_PROTECTED,
		.description = "Toggle Flying Scoutsman mode.",
		.has_min = true,
		.min_val = 0.0,
		.has_max = true,
		.max_val = 1.0
	);

	hook_cvar_change(pCvar, "hookCvar_ModeChange");
	bind_pcvar_num(pCvar, g_bModeEnabled);
	
	Toggle_Mode(g_bModeEnabled);
}

public hookCvar_ModeChange(pCvar) {
	Toggle_Mode(g_bModeEnabled);

	// log_amx("== [Mode %s]", g_bModeEnabled ? "enabled" : "disabled");
}

new g_szCvars_Enabled[][] = {
	"sv_gravity 200",
	"mp_startmoney 0",
	"mp_buytime 0",
	"sv_restart 1"
}

new g_szCvars_Disabled[][] = {
	"sv_gravity 800",
	"mp_startmoney 800",
	"mp_buytime 0.25",
	"sv_restart 1"
}

Toggle_Mode(iStatus) {
	switch(iStatus){
		case true: {
			for(new i; i < H_TYPES_s; i++) {
				if(Hooks[i])
					EnableHamForward(Hooks[i]);
			}
			
			ExecCMDS(g_szCvars_Enabled, sizeof g_szCvars_Enabled);
		}
		case false: {
			for(new i; i < H_TYPES_s; i++) {
				if(Hooks[i])
					DisableHamForward(Hooks[i]);
			}
			
			ExecCMDS(g_szCvars_Disabled, sizeof g_szCvars_Disabled);
		}
	}
}

enum any: tasks ( +=12 ) { TASK_SetWeapons = 1337 }

public CBasePlayer_Spawn(pPlayerId) {
	if(is_user_connected(pPlayerId))
		set_task(0.2, "set_user_weapons", .id = TASK_SetWeapons + pPlayerId);
}

public set_user_weapons(pPlayerId) {
	pPlayerId -= TASK_SetWeapons;
	
	if(!is_user_connected(pPlayerId))
		return;
	
	strip_user_weapons(pPlayerId);

	give_item(pPlayerId, "weapon_scout");
	cs_set_user_bpammo(pPlayerId, CSW_SCOUT, 90);

	give_item(pPlayerId, "weapon_knife");
}

stock ExecCMDS(szBuffer[][], const iLen) {
	for(new i; i < iLen; i++)
		server_cmd(szBuffer[i]);
}


public CBasePlayerWeapon_PrimAttackP(pWeapon)
{
	if(pWeapon <= 0)
		return;

	new pPlayer = get_pdata_cbase(pWeapon, m_pPlayer, XO_WEAPON);
	if(pPlayer > 0)
	{
		if(g_vecVelocity[pPlayer][0] && g_vecVelocity[pPlayer][0] && g_vecVelocity[pPlayer][0])
		{
			set_pev(pPlayer, pev_velocity, g_vecVelocity[pPlayer]);
			set_pev(pPlayer, pev_fov, float(get_pdata_int(pPlayer, m_iFOV)));
			set_pev(pPlayer, pev_flags, pev(pPlayer, pev_flags) & ~FL_ONGROUND);

			g_vecVelocity[pPlayer][0] = g_vecVelocity[pPlayer][0] = g_vecVelocity[pPlayer][0] = 0.0;
		}
	}
}

public CBasePlayerWeapon_PrimAttack(const pWeapon)
{
	if(pWeapon <= 0)
		return;

	new pPlayer = get_pdata_cbase(pWeapon, m_pPlayer, XO_WEAPON);
	if(pPlayer > 0)
	{
		set_pdata_int(pPlayer, random_seed, 0);
		
		set_pdata_float(pWeapon, m_flLastFire, 0.0, XO_WEAPON);
		set_pdata_float(pWeapon, m_flAccuracy, 1.0, XO_WEAPON);

		pev(pPlayer, pev_velocity, g_vecVelocity[pPlayer]);

		set_pev(pPlayer, pev_velocity, Float:{0.0, 0.0, 0.0});
		set_pev(pPlayer, pev_fov, 40.0);
		set_pev(pPlayer, pev_flags, pev(pPlayer, pev_flags) | FL_ONGROUND);
	}
}

public CBaseEntity_Touch(pWeaponEnt, pPlayerId)
	return HAM_SUPERCEDE;
	
#if defined HIDE_ARMORYENTS
enum ArmouryEnts_States ( +=1 ) { HIDE, SHOW }

public event_NewRound() {
	if(g_bModeEnabled){
		Hide_Armoury_Entity();
	}
}

stock Hide_Armoury_Entity()
{
	new pEnt = -1;
	while((pEnt = fm_find_ent_by_class(pEnt, CLASS_ArouryEntity)))
		Hide_ArmouryEntities(pEnt);
}

stock Hide_ArmouryEntities(pEnt)
{
	if(!pev_valid(pEnt))
		return;

	static fOrigin[3];
	pev(pEnt, pev_origin, fOrigin);
	fOrigin[1] -= 2000.0;
	set_pev(pEnt, pev_origin, fOrigin);
}
#endif