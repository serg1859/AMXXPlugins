/**
Credits:
	Big Thanks to tuty for his plugin "CS:GO Zeus/Taser Gun"
		his plugin was a basis.
	https://forums.alliedmods.net/showpost.php?p=2368670&postcount=7
	
	Thanks to: Next21 Team & ChakkiSkrip for p_, v_, w_ Models fixes & creating.
				gyxoBka for some tips.
				Tranquillity for testing & reports.
	
	TO-DO:
		- Indication of the state of charge on the p_ model;
		- Reload think for every WeaponEntity;
		- API (natives, forwards);
		- Support ReAPI.
*/

#include <amxmodx>

#include <fakemeta_util>
#include <hamsandwich>
#include <fun>
#include <engine>

new bool: g_bModeEnabled;

#define ZEUS_DISTANCE	230

new const szZeusWeaponName[] = "weapon_p228";

// new const gBeamSprite[] = "sprites/bolt1.spr";
new const gBeamSprite[] = "sprites/laserbeam.spr";

enum { ViewModel, PlayerModel, WorldModel }
new const Models[][] = {
	"models/GameMode/v_zeus.mdl",
	"models/GameMode/p_zeus.mdl",
	"models/GameMode/w_zeus.mdl"
}

stock const OLDWORLD_MODEL[] = "models/w_p228.mdl";

enum { Deploy, Hit, Shoot }
new const Sounds[][] = {
	"GameMode/Zeus_Deploy.wav",
	"GameMode/Zeus_Hit.wav",
	"GameMode/Zeus_HitWall.wav"
}

new g_pBoltSprite;

const XO_PLAYER	= 5;
const XO_WEAPON	= 4;

const m_pPlayer			= 41;
const m_flNextPrimaryAttack		= 46;
const m_flNextSecondaryAttack	= 47;
const m_flTimeWeaponIdle = 48;
const m_fKnown			= 44;
const m_iClip			= 51;
const m_iClientClip		= 52;

enum any: H_TYPES_s {
	_AttachToPlayer,
	_ZeusDeploy,
	_PrimaryAttack_Pre,
	_PrimaryAttack,
	_CBasePlayer_Spawn
}

new any: Hooks[H_TYPES_s];
new any: _SetModel;

const TASKID_RELOAD = 1337;
const Float: ZEUS_RELOADTIME = 30.0;

public plugin_init() {
	register_plugin( "Mode: Stab Stab Zap", "0.0.1", "wopox1337 @ Dev-CS.ru");

	Hooks[_AttachToPlayer] = RegisterHam(Ham_Item_AttachToPlayer, szZeusWeaponName, "Zeus_AttachToPlayer", .Post = true, .specialbot = true);
	Hooks[_ZeusDeploy] = RegisterHam(Ham_Item_Deploy, szZeusWeaponName, "Zeus_Deploy", .Post = true, .specialbot = true);
	Hooks[_PrimaryAttack_Pre] = RegisterHam(Ham_Weapon_PrimaryAttack, szZeusWeaponName, "Zeus_Weapon_PrimaryAttack_Pre", .Post = false, .specialbot = true);
	Hooks[_PrimaryAttack] = RegisterHam(Ham_Weapon_PrimaryAttack, szZeusWeaponName, "Zeus_Weapon_PrimaryAttack", .Post = true, .specialbot = true);
	Hooks[_CBasePlayer_Spawn] = RegisterHam(Ham_Spawn, "player", "CBasePlayer_Spawn", .Post = true, .specialbot = true);
	
	_SetModel = register_forward(FM_SetModel, "fw_SetModel", ._post = false);

	new pcvar = create_cvar(
		.name = "mp_gamemode_Stab_Stab_Zap",
		.string = "0",
		.flags = FCVAR_PROTECTED,
		.description = "Toggle 'Stab Stab Zap' mode.",
		.has_min = true,
		.min_val = 0.0,
		.has_max = true,
		.max_val = 1.0
	);
	
	hook_cvar_change(pcvar, "hookCvar_ModeChange");
	bind_pcvar_num(pcvar, g_bModeEnabled);

	Toggle_Mode(g_bModeEnabled);
}

public plugin_precache() {
	g_pBoltSprite = precache_model(gBeamSprite);

	new i, bWasFail;
	for(i = 0; i < sizeof Models; i++) {
		if(file_exists(Models[i])) {
			precache_model(Models[i]);
		} else {
			log_amx("[Precache fail] File '%s' not exist. Skipped!", Models[i]);
			
			bWasFail = true;
		}
	}
	
	new szFile[64];
	for(i = 0; i < sizeof Sounds; i++) {
		formatex(szFile, charsmax(szFile), "sound\%s", Sounds[i]);
		if(file_exists(szFile)) {
			precache_sound(Sounds[i]);
		} else {
			log_amx("[Precache fail] File '%s' not exist. Skipped!", Sounds[i]);
			
			bWasFail = true;
		}
	}
	
	if(bWasFail) {
		set_fail_state("Check all Models & Sounds! Some files not precached!");
	}
}

public hookCvar_ModeChange(pCvar) {
	Toggle_Mode(g_bModeEnabled);
	
	log_amx("== [Mode %s]", g_bModeEnabled ? "enabled" : "disabled");
}

Toggle_Mode(iStatus) {
	switch(iStatus)	{
		case true: {
			for(new i; i < H_TYPES_s; i++) {
				if(Hooks[i]) {
					EnableHamForward(Hooks[i]);
				}
			}

			_SetModel = register_forward(FM_SetModel, "fw_SetModel");
			
			server_cmd("mp_buytime 0; sv_restart 1");
		}
		case false: {
			for(new i; i < H_TYPES_s; i++) {
				if(Hooks[i]) {
					DisableHamForward(Hooks[i]);
				}
			}

			unregister_forward(FM_SetModel, _SetModel);
			
			server_cmd("mp_buytime 0.25; sv_restart 1");
		}
	}
}

public Zeus_Deploy(iWeaponEntity) {
	new pPlayerId = get_pdata_cbase(iWeaponEntity, m_pPlayer, XO_WEAPON);
	
	if(!pev_valid(pPlayerId)) {
		log_amx("[Deploy] Invalid entity player: %i", pPlayerId);
		return;
	}

	set_pev(pPlayerId, pev_viewmodel2, Models[ViewModel]);
	set_pev(pPlayerId, pev_weaponmodel2, Models[PlayerModel]);

	// set_pdata_float(iWeaponEntity, m_flNextSecondaryAttack, 999999.9, XO_WEAPON);

	UTIL_PlayWeaponAnimation(pPlayerId, 3);
	emit_sound(iWeaponEntity, CHAN_WEAPON, Sounds[Deploy], VOL_NORM, ATTN_NORM, 0, PITCH_NORM);
	
	static Float: fPercents;
	fPercents = ((ZEUS_RELOADTIME - floatclamp(get_pdata_float(iWeaponEntity, m_flNextPrimaryAttack, XO_WEAPON), 0.0, ZEUS_RELOADTIME)) * 100 ) / ZEUS_RELOADTIME;

	client_print(pPlayerId, print_center, "Reloading: %.0f%%", fPercents);
}

public Zeus_Weapon_PrimaryAttack_Pre(iWeaponEntity) {
	new pPlayerId = get_pdata_cbase(iWeaponEntity, m_pPlayer, XO_WEAPON);
	
	if(!pev_valid(pPlayerId)) {
		
		log_amx("[Weapon_PrimaryAttack] Invalid entity player: %i", pPlayerId);
		return HAM_IGNORED;
	}
	
	static iTarget, iBody, Float: fDistance;
	fDistance = get_user_aiming(pPlayerId, iTarget, iBody);
	
	static iOrigin[3];
	// get_user_origin(pPlayerId, iOrigin);
	
	static any: iTargetOrigin[3];
	// get_user_origin(pPlayerId, iTargetOrigin, 3);
	
	static Float: fOrigin[3], Float: fVelocity[3];
	entity_get_vector(pPlayerId, EV_VEC_origin, fOrigin);
	VelocityByAim(pPlayerId, ZEUS_DISTANCE, fVelocity);
	
	static Float: fTemp[3];
	xs_vec_add(fOrigin, fVelocity, fTemp);
	FVecIVec(fOrigin, iOrigin);
	FVecIVec(fTemp, iTargetOrigin);
	
	if(is_user_connected(iTarget) && fDistance <= ZEUS_DISTANCE) {
		get_user_origin(iTarget, iTargetOrigin, 0);
		
		if(get_user_team(pPlayerId) != get_user_team(iTarget)) {
			ExecuteHam(Ham_TakeDamage, iTarget, 0, pPlayerId, 4000.0, DMG_SHOCK );
		}
		
		emit_sound(pPlayerId, CHAN_WEAPON, Sounds[Hit], VOL_NORM, ATTN_NORM, 0, PITCH_NORM);
	} else {
		emit_sound(pPlayerId, CHAN_WEAPON, Sounds[Shoot], VOL_NORM, ATTN_NORM, 0, PITCH_NORM );
	}

	UTIL_CreateThunder2(pPlayerId, iTargetOrigin);
	UTIL_CreateLight(iOrigin);
	UTIL_PlayWeaponAnimation(pPlayerId, 2);

	return HAM_SUPERCEDE;
}

public Zeus_Weapon_PrimaryAttack(iWeaponEntity)
{	
	set_pdata_int(iWeaponEntity, m_iClip, 0, XO_WEAPON);
	set_pdata_float(iWeaponEntity, m_flNextPrimaryAttack, ZEUS_RELOADTIME, XO_WEAPON);
	
	set_task(ZEUS_RELOADTIME, "Reload_Zeus", TASKID_RELOAD + iWeaponEntity);
	
	// client_print(0, print_chat, "ZEUS SHOOT!");
}

public Reload_Zeus(iWeaponEntity)
{
	iWeaponEntity -= TASKID_RELOAD;
	
	if(pev_valid(iWeaponEntity)) {
		set_pdata_int(iWeaponEntity, m_iClip, 1, XO_WEAPON);
	}
	
	// client_print(0, print_chat, "ZEUS RELOADED!");
}

public CBasePlayer_Spawn(pPlayerId) {
	set_user_weapons(pPlayerId);
}

stock set_user_weapons(const pPlayerId) {
	if(is_user_alive(pPlayerId))
	{
		strip_user_weapons(pPlayerId);
	
		give_item(pPlayerId, "weapon_knife");
		give_item(pPlayerId, szZeusWeaponName);
	}
}

public Zeus_AttachToPlayer(iWeaponEntity, pPlayerId) {
	if(get_pdata_float(iWeaponEntity, m_fKnown, XO_WEAPON)) {
		return;
	}

	set_pdata_int(iWeaponEntity, m_iClip, 1, XO_WEAPON);
	set_pdata_int(pPlayerId, m_iClientClip, 0, XO_PLAYER);
}

public fw_SetModel(iWeaponEntity, szModel[])
{
	if(!pev_valid(iWeaponEntity)) {
		return FMRES_IGNORED;
	}

	if(equali(szModel, OLDWORLD_MODEL)) {
		static szClassName[8];
		pev(iWeaponEntity, pev_classname, szClassName, charsmax(szClassName));
		
		// if(equal(szClassName, "weaponbox")) {
		if(szClassName[0] == 'w' && szClassName[6] == 'b') {
			engfunc(EngFunc_SetModel, iWeaponEntity, Models[WorldModel]);
			
			return FMRES_SUPERCEDE;
		}
	}
	
	return FMRES_IGNORED
}


stock UTIL_PlayWeaponAnimation(const pPlayerId, const Sequence) {
	set_pev(pPlayerId, pev_weaponanim, Sequence);
	
	message_begin(MSG_ONE_UNRELIABLE, SVC_WEAPONANIM, .player = pPlayerId);
	write_byte(Sequence);
	write_byte(pev(pPlayerId, pev_body));
	message_end();
}

stock UTIL_CreateThunder(iStart[3], iEnd[3]) {
	message_begin(MSG_BROADCAST, SVC_TEMPENTITY); 
	write_byte(TE_BEAMPOINTS); 
	write_coord(iStart[0]); 
	write_coord(iStart[1]); 
	write_coord(iStart[2]); 
	write_coord(iEnd[0]); 
	write_coord(iEnd[1]); 
	write_coord(iEnd[2]); 
	write_short(g_pBoltSprite); 
	write_byte(1);
	write_byte(5);
	write_byte(7);
	write_byte(20);
	write_byte(30);
	write_byte(135); 
	write_byte(206);
	write_byte(250);
	write_byte(255);
	write_byte(145);
	message_end();
}

stock UTIL_CreateThunder2(iStartId, iEnd[3]) {
	message_begin(MSG_BROADCAST ,SVC_TEMPENTITY);
	write_byte(TE_BEAMENTPOINT);
	write_short(iStartId | 0x1000);	// Начальное энтити
	write_coord(iEnd[0]);	// Конец луча
	write_coord(iEnd[1]);	// Y
	write_coord(iEnd[2]);	// Z
	write_short(g_pBoltSprite);	// Индекс спрайта
	write_byte(1);		// FrameStart
	write_byte(30);		// FrameRate
	write_byte(5);		// Life
	write_byte(2);		// Width
	write_byte(20);		// Noise
	write_byte(135); 	// Color R
	write_byte(206);	// G
	write_byte(250);	// B
	write_byte(200);	// Brightness
	write_byte(200);	// Scroll
	message_end()
}

stock UTIL_CreateLight(origin[3])
{
	message_begin(MSG_BROADCAST, SVC_TEMPENTITY);
	write_byte(TE_DLIGHT);
	write_coord(origin[0]); // x
	write_coord(origin[1]); // y
	write_coord(origin[2]); // z
	write_byte(50); // radius
	write_byte(135);	// r
	write_byte(206);	// g
	write_byte(250);	// b
	write_byte(3); // life
	write_byte(120); // decay rate
	message_end();
}