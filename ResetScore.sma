#include <amxmodx>
#include <fun>
#include <cstrike>

public plugin_init()
{
	register_plugin("Reset Score", "0.0.2f", "wopox1337");

	// Тут впишите желаемые команды для выполнения сброса у игрока.
	new szCmds[][] =
	{
		"say /rs",
		"say_team /rs",
		"say /resetscore",
		"say_team /resetscore"
	}

	for(new i; i < sizeof szCmds; i++)
	{
		register_clcmd(szCmds[i], "Do_ResetScore");
	}
}

public Do_ResetScore(iPlayerId)
{
	if(is_user_connected(iPlayerId))
	{
		set_user_frags(iPlayerId, .frags = 0);
		cs_set_user_deaths(iPlayerId, .newdeaths = 0);

		client_print(iPlayerId, print_center, "Вы сбросили свой счёт!");
	}

	return PLUGIN_HANDLED;
}