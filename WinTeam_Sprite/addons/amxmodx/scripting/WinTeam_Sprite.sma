/* Раскомментируйте, если вы используете ZombieMod версию. */
//#define USE_ON_ZM

/* Затемнять ли экран? */
#define FADE_SCREEN

/*Скрывать ли прицел*/
#define HIDE_CROSSHAIR

/*Показывать ли ничью*/
#define ROUND_DRAW_SHOW

#if defined ROUND_DRAW_SHOW
	#define ROUND_DRAW_TYPE 0 //0 - random, >0 - static

	#if ROUND_DRAW_TYPE > 0
		#define ROUND_DRAW_SPR_NUMBER 1 // Sprite number, aviable 1 & 64 states
	//	#define ROUND_DRAW_SPR_NUMBER 64
	#endif

#endif

#include <amxmodx>
#if defined USE_ON_ZM
	#include <zombieplague>
#endif

#define CSW_KNIFE	29
#define CSW_SHIELD	2
#define DEFAULT_FOV	90

new bool:g_bSomeBool, g_iRoundState;

enum _:ROUNDWIN_States {
	ROUND_DRAW = 0,
	ROUND_WIN_T,
	ROUND_WIN_CT
}

enum _:MESSAGES {
	g_iMsg_WeaponList,
#if defined FADE_SCREEN
	g_iMsg_ScreenFade,
#endif
	g_iMsg_CurWeapon,
	g_iMsg_ForceCam,
#if defined HIDE_CROSSHAIR
	g_iMsg_SetFOV,
	g_iMsg_HideWeapon
#else
	g_iMsg_SetFOV
#endif
}
	
new g_Messages_Name[MESSAGES][] = {
	"WeaponList",
#if defined FADE_SCREEN
	"ScreenFade",
#endif
	"CurWeapon",
	"ForceCam",
#if defined HIDE_CROSSHAIR
	"SetFOV",
	"HideWeapon"
#else
	"SetFOV"
#endif
}

new g_Messages[MESSAGES];
new g_Sprites[][] = {
	#if defined ROUND_DRAW_SHOW
	"sprites/winteam_round_draw_t.txt",
	"sprites/winteam_round_draw.spr",
	#endif
	#if !defined USE_ON_ZM
	"sprites/z_aufff_fmaledevcsrus.txt",
	#else
	"sprites/zombie_win_sz.txt",
	#endif
	"sprites/640hud11.spr",
	"sprites/640hud10.spr",
	"sprites/640hud7.spr",
	#if !defined USE_ON_ZM
	"sprites/winteam_fmaledevcsrus.spr"
	#else
	"sprites/zombie_win_uniq.spr"
	#endif
}

#if defined USE_ON_ZM
new const CMD[] = "zombie_win_sz";
#else
new const CMD[] = "z_aufff_fmaledevcsrus";
#endif

#if defined ROUND_DRAW_SHOW
new const CMD_DRAW[] = "winteam_round_draw_t"
#endif

public plugin_precache(){
	for(new i; i < sizeof(g_Sprites); i++)
		precache_generic(g_Sprites[i]);
}

public plugin_init(){
	register_plugin("WinTeam Sprite", "0.0.8", "Some Scripter");
	
	register_clcmd(CMD,"FakeSwitch");
	#if defined ROUND_DRAW_SHOW
	register_clcmd(CMD_DRAW,"FakeSwitch");
	#endif
	register_event("HLTV", "Event_NewRound","a","1=0","2=0");
	
	#if !defined USE_ON_ZM	
	register_event("SendAudio", "Event_CTWin","a","2=%!MRAD_ctwin");
	register_event("SendAudio", "Event_TerroristWin","a","2=%!MRAD_terwin");
	register_event("SendAudio", "Event_Draw","a","2=%!MRAD_rounddraw");
	#endif
	
	for(new i; i < sizeof(g_Messages); i++){			
		g_Messages[i] = get_user_msgid(g_Messages_Name[i]);
		register_message(g_Messages[i], "block");
	}
}

#if defined USE_ON_ZM
public zp_round_ended(winteam){
	switch(winteam){
		case WIN_NO_ONE:{
			g_iRoundState = ROUND_DRAW;
		#if defined ROUND_DRAW_SHOW
			StartDraw();
		#endif
		}
		case WIN_ZOMBIES:{
			g_iRoundState = ROUND_WIN_T;
			StartDraw();
		}
		case WIN_HUMANS:{
			g_iRoundState = ROUND_WIN_CT;
			StartDraw();
		}
	}
}
#else

public Event_CTWin(){
	g_iRoundState = ROUND_WIN_CT;
	StartDraw();
}

public Event_TerroristWin(){
	g_iRoundState = ROUND_WIN_T;
	StartDraw();
}

public Event_Draw(){
	g_iRoundState = ROUND_DRAW;
#if defined ROUND_DRAW_SHOW
	StartDraw();
#endif
}
#endif

public Event_NewRound(){
#if !defined ROUND_DRAW_SHOW
	if(!g_iRoundState)return;

	g_iRoundState = ROUND_DRAW;
#endif
	g_bSomeBool = false;
#if defined FADE_SCREEN
	Msg_ScreenFade(1500,700,1,0,0,0,230);
#endif

#if defined HIDE_CROSSHAIR
	Msg_HideWeapon(0);
#endif
	Msg_WeaponList("weapon_knife",-1,-1,-1,-1,2,1,CSW_KNIFE,0);
	Msg_CurWeapon(0,0,0);
}

public block(){
	if(g_bSomeBool)return PLUGIN_HANDLED;
	
	return PLUGIN_CONTINUE;
}

public FakeSwitch(const client)engclient_cmd(client,"weapon_shield");

public sendweapon(){
	switch(g_iRoundState){
		#if defined ROUND_DRAW_SHOW
		case ROUND_DRAW:	Msg_WeaponList(CMD_DRAW,-1,-1,-1,-1,0,11,CSW_SHIELD,0);
		#endif
		case ROUND_WIN_CT:	Msg_WeaponList(CMD,-1,-1,-1,-1,0,11,CSW_SHIELD,0);
		case ROUND_WIN_T:	Msg_WeaponList(CMD,-1,-1,-1,-1,0,11,CSW_SHIELD,0);
	}
	

#if defined HIDE_CROSSHAIR
	Msg_HideWeapon(64);
#endif

	Msg_SetFOV(DEFAULT_FOV-1);
	
	g_bSomeBool = false;
	

	switch(g_iRoundState){
	#if defined ROUND_DRAW_SHOW
		#if ROUND_DRAW_TYPE > 0
			case ROUND_DRAW:	Msg_CurWeapon(ROUND_DRAW_SPR_NUMBER,2,-1);
		#else
			case ROUND_DRAW:	Msg_CurWeapon(random_num(0,1)*63+1,2,-1);
		#endif
	#endif
		case ROUND_WIN_CT:	Msg_CurWeapon(1,2,-1);
		case ROUND_WIN_T:	Msg_CurWeapon(64,2,-1);
	}
	
	g_bSomeBool = true;
	
	Msg_SetFOV(DEFAULT_FOV);
}

public StartDraw(){
#if defined FADE_SCREEN
	Msg_ScreenFade(9048,11480,1,0,0,0,230);
#endif
	
	g_bSomeBool = true;
	set_task(0.6,"sendweapon");
}

stock Msg_WeaponList(const WeaponName[],PrimaryAmmoID,PrimaryAmmoMaxAmount,SecondaryAmmoID,SecondaryAmmoMaxAmount,
						SlotID,NumberInSlot,WeaponID,Flags){
	message_begin(MSG_ALL,g_Messages[g_iMsg_WeaponList], .player = 0);
	{
		write_string(WeaponName);
		write_byte(PrimaryAmmoID);
		write_byte(PrimaryAmmoMaxAmount);
		write_byte(SecondaryAmmoID);
		write_byte(SecondaryAmmoMaxAmount);
		write_byte(SlotID);
		write_byte(NumberInSlot);
		write_byte(WeaponID);
		write_byte(Flags);
	}
	message_end();
}

#if defined FADE_SCREEN
stock Msg_ScreenFade(Duration,HoldTime,Flags,ColorR,ColorG,ColorB,Alpha){
	message_begin(MSG_ALL,g_Messages[g_iMsg_ScreenFade], .player = 0);
	{
		write_short(Duration);
		write_short(HoldTime);
		write_short(Flags);
		write_byte(ColorR);
		write_byte(ColorG);
		write_byte(ColorB);
		write_byte(Alpha);
	}
	message_end();
}
#endif

stock Msg_CurWeapon(IsActive,WeaponID,ClipAmmo)
{		
	message_begin(MSG_ALL,g_Messages[g_iMsg_CurWeapon], .player = 0);
	{
		write_byte(IsActive);
		write_byte(WeaponID);
		write_byte(ClipAmmo);
	}
	message_end();
}

stock Msg_SetFOV(Degrees){
	message_begin(MSG_ALL,g_Messages[g_iMsg_SetFOV], .player = 0);
	{
		write_byte(Degrees);
	}
	message_end();
}

#if defined HIDE_CROSSHAIR
stock Msg_HideWeapon(Flags){
	message_begin(MSG_ALL,g_Messages[g_iMsg_HideWeapon], .player = 0);
	{
		write_byte(Flags);
	}
	message_end();
}
#endif