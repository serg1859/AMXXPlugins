
// Раз во сколько секунд обновлять статистику
const Float: EVERYSECONDS = 10.0;

#include <amxmodx>
#include <reapi>

const TASK_SHOWMESSAGE	= 1234;
new g_iMsgId_HudSync;

public plugin_init()
{
	register_plugin("Kill\Deaths stats", "0.0.1", "wopox1337");
	
	set_task(EVERYSECONDS, "Show_Scores", .id = TASK_SHOWMESSAGE, .flags = "b");

	RegisterHookChain(RG_CBasePlayer_Spawn, "RG_CBasePlayer_Spawn_Post", .post = true);

	g_iMsgId_HudSync = CreateHudSyncObj();
	
	set_hudmessage
	(
		.red = 250,
		.green = 0,
		.blue = 0,
		.x = 0.15,
		.y = 0.2,
		.effects = 0,
		.holdtime = EVERYSECONDS,
		.fadeouttime = 0.1	
	);
}

public RG_CBasePlayer_Spawn_Post(const pPlayerId)
{
	Show_Scores();
}

public Show_Scores()
{
	for(new iPlayerId ; iPlayerId < MaxClients ; iPlayerId++)
	{
		if(!is_user_connected(iPlayerId) || is_user_bot(iPlayerId) || is_user_hltv(iPlayerId))
		{
			continue;
		}
		
		static Float: fKillDeaths_Ratio;
		fKillDeaths_Ratio = get_entvar(iPlayerId, var_frags) / get_member(iPlayerId, m_iDeaths);

		if(!fKillDeaths_Ratio)
		{
			continue;
		}

		ShowSyncHudMsg(iPlayerId, g_iMsgId_HudSync, "K/D = %0.1f",
			fKillDeaths_Ratio
		);
	}
}