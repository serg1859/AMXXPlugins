/* The flag to give the discount */
new const FLAGS_FOR_DISCOUNT[] = "b";
/* Size of discount in percent */
const PERCENT_TO_DISCOUNT = 25;



#include <amxmodx>
#include <amxmisc>
#include <reapi>

const bitsKeys = MENU_KEY_1|MENU_KEY_2|MENU_KEY_3|MENU_KEY_4|MENU_KEY_5|MENU_KEY_6|MENU_KEY_7|MENU_KEY_8|MENU_KEY_9|MENU_KEY_0;
#define PercentSub(%1,%2)	(%1 - (%1 * %2) / 100)

new bool: g_bMenu_Used[MAX_CLIENTS];
new g_ibitsFlagsToDiscount;

public plugin_init()
{
	register_plugin("Sniper Shop", "0.0.4f", "Dev-CS.ru Team");
	
	RegisterHookChain(
		RG_CSGameRules_RestartRound,
		"CSGameRules_RestartRound",
		.post = true
	);
	
	RegisterHookChain(
		RH_SV_DropClient,
		"SV_DropClient",
		.post = true
	);
	
	RegisterHookChain(
		RG_CBasePlayer_Killed,
		"CBasePlayer_Killed",
		.post = true
	);

	/* Commands to open Snipers menu */
	new const CMDS[][] =
	{
		"say /sniper",
		"say_team /sniper",
		"/sniper"
	}

	for(new i; i < sizeof CMDS; i++)
	{
		register_clcmd(CMDS[i], "ShowMenu_ChooseSnipers");
	}

	register_menu("Menu_ChooseSnipers", bitsKeys , "MenuHandler_ChooseSnipers");

	g_ibitsFlagsToDiscount = read_flags(FLAGS_FOR_DISCOUNT);
}

enum _:WEAPON_DATA_s { szMenuItemName[32], iCost, szClassname[32] }

/**
	Allowed weapons in menu
	Format:
	[ Name - Cost - Classname item ]
*/
new const WeaponsArray[][WEAPON_DATA_s] =
{
	{ "AWP",	220,	"weapon_awp"	}
	,{ "Scout",	130,	"weapon_scout"	}
	,{ "SG550",	260,	"weapon_sg550"	}
	,{ "G3SG1",	300,	"weapon_g3sg1"	}
}

public ShowMenu_ChooseSnipers(pPlayerId)
{
	new iAccount = get_member(pPlayerId, m_iAccount);

	if(!iAccount)
	{
		client_print(pPlayerId, print_chat, "You have no money!");
		return PLUGIN_HANDLED;
	}
	
	if(g_bMenu_Used[pPlayerId])
	{
		client_print(pPlayerId, print_chat, "Allowed to buy only 1 time!");
		return PLUGIN_HANDLED;
	}

	new bIsVIPPlayer = get_user_flags(pPlayerId) & g_ibitsFlagsToDiscount;
	
	new szMenu[512], iLen, iKeys, iItem, iKeyBit;
	iLen = formatex(szMenu[iLen], charsmax(szMenu), "\ySelect your sniper weapon:^n%s", bIsVIPPlayer ? "^tYou have discount!^n" : "");
	
	for(new i; i < sizeof WeaponsArray; i++)
	{
		new iWeaponConst = bIsVIPPlayer ? PercentSub(WeaponsArray[i][iCost], PERCENT_TO_DISCOUNT) : WeaponsArray[i][iCost];
	
		if(iAccount >= iWeaponConst)
		{
			iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r%i.\w %s [\r%i$\w]^n", ++iItem, WeaponsArray[i][szMenuItemName], iWeaponConst);
			iKeys |= (1 << iKeyBit);
		}
		else
		{
			iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r%i.\d %s [\r%i$\w]^n", ++iItem, WeaponsArray[i][szMenuItemName], iWeaponConst);
		}
	
		++iKeyBit;
	}
	
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "^n\r0. \yExit");
	iKeys |= MENU_KEY_0;
	
	show_menu(pPlayerId, iKeys, szMenu, 10, "Menu_ChooseSnipers");
	
	return PLUGIN_HANDLED;
}

public MenuHandler_ChooseSnipers(pPlayerId, key)
{
	if(key >= 9)
	{
		return;
	}

	rg_give_item(pPlayerId, WeaponsArray[key][szClassname], .type = GT_DROP_AND_REPLACE);

	new iWeaponConst = get_user_flags(pPlayerId) & g_ibitsFlagsToDiscount ? PercentSub(WeaponsArray[key][iCost], PERCENT_TO_DISCOUNT) : WeaponsArray[key][iCost];

	rg_add_account(
		pPlayerId,
		-iWeaponConst,
		.typeSet = AS_ADD,
		.bTrackChange = true
	);

	g_bMenu_Used[pPlayerId] = true;
}

public CSGameRules_RestartRound()
{
	arrayset(g_bMenu_Used, false, sizeof(g_bMenu_Used));
}

public SV_DropClient(pPlayerId)
{
	g_bMenu_Used[pPlayerId] = false;
}

public CBasePlayer_Killed(const pPlayerId, pKillerId, iGib)
{
	g_bMenu_Used[pPlayerId] = false;
}
