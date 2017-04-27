#include <amxmodx>
#include <reapi>

public plugin_init()
{
	register_plugin("Killer info DHUD", "0.0.1", "wopox1337");

	RegisterHookChain(RG_CBasePlayer_Killed, "CBasePlayer_Killed_Post", .post = true);
}

public CBasePlayer_Killed_Post(const pVictimId, const pKillerId, iGib)
{
	if(!is_user_connected(pVictimId) || !is_user_connected(pKillerId))
	{
		return;
	}
	
	if(pKillerId == pVictimId)
	{
		return;
	}
	
	static szKillerName[32];
	get_user_name(pKillerId, szKillerName, charsmax(szKillerName));
	
	set_dhudmessage(.red = 255, .x = -1.0, .y = 0.7, .effects = 1, .fxtime = 2.0, .holdtime = 4.0, .fadeouttime = 2.0);
	show_dhudmessage(pVictimId, "Вас убил %s^nHP: %d		AP: %d",
		szKillerName,
		get_user_health(pKillerId),
		get_user_armor(pKillerId)
	);
}