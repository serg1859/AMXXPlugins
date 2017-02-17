#define USE_ON_ZM

#include <amxmodx>
#if defined USE_ON_ZM
	#include <zombieplague>
#endif
#define CSW_KNIFE 29
#define CSW_SHIELD 2
#define ORIGIN_FOV 90
new bool:g_bSomeBool, g_iRoundState;

enum _:ROUNDWIN_States {
	ROUND_DRAW = 0,
	ROUND_WIN_CT = 2,
	ROUND_WIN_T = 1
}

enum _:MESSAGES {
	g_iMsg_WeaponList,
	g_iMsg_ScreenFade,
	g_iMsg_CurWeapon,
	g_iMsg_ForceCam,
	g_iMsg_SetFOV,
	g_iMsg_HideWeapon
}
	
new g_Messages_Name[MESSAGES][] = {
	"WeaponList",
	"ScreenFade",
	"CurWeapon",
	"ForceCam",
	"SetFOV",
	"HideWeapon"
}

new g_Messages[MESSAGES];

new g_Sprites[][] = 
{
	#if !defined USE_ON_ZM
	"sprites/z_aufff.txt",
	#else
	"sprites/zombie_win_sz.txt",
	#endif
	"sprites/640hud11.spr",
	"sprites/640hud10.spr",
	"sprites/640hud7.spr",
	#if !defined USE_ON_ZM
	"sprites/winteam_asdasz.spr"
	#else
	"sprites/zombie_win_uniq.spr"
	#endif
}

#if defined USE_ON_ZM
new const CMD[] = "zombie_win_sz";
#else
new const CMD[] = "z_aufff";
#endif


public plugin_precache(){
	for(new i; i < sizeof(g_Sprites); i++){
		precache_generic(g_Sprites[i]);
	}
}

public plugin_init(){
	register_plugin("WinTeam Sprite", "0.0.1", "Some Scripter");
	
	register_clcmd(CMD,"FakeSwitch");
	
	#if !defined USE_ON_ZM	
	register_event("HLTV", "Event_NewRound","a","1=0","2=0");
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
}
#endif

public Event_NewRound(){
	if(!g_iRoundState)
	{
		return;
	}

	g_iRoundState = ROUND_DRAW;
	g_bSomeBool = false;
	
	Msg_ScreenFade();
	Msg_HideWeapon();
	Msg_WeaponList();
	Msg_CurWeapon();
}

public block(){
	if(g_bSomeBool)
	{
		return PLUGIN_HANDLED;
	}
	return PLUGIN_CONTINUE;
}
	
public FakeSwitch(const client){
	engclient_cmd(client,"weapon_shield");
}

public sendweapon(){
	Msg_WeaponList_Sprite();
	Msg_HideWeapon_2();
	Msg_SetFOV();
	
	g_bSomeBool = false;
	
	switch(g_iRoundState){
		case ROUND_WIN_CT:{
			Msg_CurWeapon_st1();
		}
		case ROUND_WIN_T:{
			Msg_CurWeapon_st2();
		}
	}
	
	g_bSomeBool = true;
	
	Msg_SetFOV_2();
}

public StartDraw(){
	Msg_ScreenFade_2();
	
	g_bSomeBool = true;
	set_task(0.6,"sendweapon");
}


stock Msg_WeaponList(){
	message_begin(MSG_ALL,g_Messages[g_iMsg_WeaponList],_,0);
	{
		write_string("weapon_knife");
		write_byte(-1);
		write_byte(-1);
		write_byte(-1);
		write_byte(-1);
		write_byte(2);
		write_byte(1);
		write_byte(CSW_KNIFE);
		write_byte(0);
	}
	message_end();
}

stock Msg_WeaponList_Sprite()
{
	message_begin(MSG_ALL,g_Messages[g_iMsg_WeaponList],_,0);
	{
		write_string(CMD);
		write_byte(-1);
		write_byte(-1);
		write_byte(-1);
		write_byte(-1);
		write_byte(0);
		write_byte(11);
		write_byte(CSW_SHIELD);
		write_byte(0);
	}
	message_end();
}

stock Msg_ScreenFade(){
	message_begin(MSG_ALL,g_Messages[g_iMsg_ScreenFade],_,0);
	{
		write_short(1500);
		write_short(700);
		write_short(1);
		write_byte(0);
		write_byte(0);
		write_byte(0);
		write_byte(230);
	}
	message_end();
}

stock Msg_ScreenFade_2(){
	message_begin(MSG_ALL,g_Messages[g_iMsg_ScreenFade],_,0);
	{
		write_short(9048);
		write_short(11480);
		write_short(1);
		write_byte(0);
		write_byte(0);
		write_byte(0);
		write_byte(230);
	}
	message_end();
}

stock Msg_CurWeapon(){
	message_begin(MSG_ALL,g_Messages[g_iMsg_CurWeapon],_,0);
	{
		write_byte(0);
		write_byte(0);
		write_byte(0);
	}
	message_end();
}

stock Msg_CurWeapon_st1(){		
	message_begin(MSG_ALL,g_Messages[g_iMsg_CurWeapon],_,0);
	{
		write_byte(1);
		write_byte(2);
		write_byte(-1);
	}
	message_end();
}

stock Msg_CurWeapon_st2()
{		
	message_begin(MSG_ALL,g_Messages[g_iMsg_CurWeapon],_,0);
	{
		write_byte(64);
		write_byte(2);
		write_byte(-1);
	}
	message_end();
}

stock Msg_SetFOV(){
	message_begin(MSG_ALL,g_Messages[g_iMsg_SetFOV],_,0);
	{
		write_byte(ORIGIN_FOV-1);
	}
	message_end();
}

stock Msg_SetFOV_2()
{
	message_begin(MSG_ALL,g_Messages[g_iMsg_SetFOV],_,0);
	{
		write_byte(ORIGIN_FOV);
	}
	message_end();
}

stock Msg_HideWeapon(){
	message_begin(MSG_ALL,g_Messages[g_iMsg_HideWeapon],_,0);
	{
		write_byte(0);
	}
	message_end();
}

stock Msg_HideWeapon_2(){
	message_begin(MSG_ALL,g_Messages[g_iMsg_HideWeapon],_,0);
	{
		write_byte(64);
	}
	message_end();
}