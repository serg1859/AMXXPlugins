/* Client Menu by wopox
	Описание: Простой плагин для создания клиентского меню по команде.
	Вся настройка пунктов меню и их исполнения настраивается в LANG файле.
	В LANG файле так же присутствует подробное описание по оформлению меню.
	
	История:
	-0.1 
		- Начало.
*/
#include <amxmodx>
#include <amxmisc>

#define PLUGIN "Client Menu"
#define VERSION "0.1"
#define AUTHOR "wopox"

#define IMPULSEHOOK
#if defined IMPULSEHOOK
	#include <engine>
#endif

//#define CUSTOMIP "cs.ololo.ru:27015" 		// Для указания сайта, или домена. Значение строго в кавычках ""

new keys = MENU_KEY_1|MENU_KEY_2|MENU_KEY_3|MENU_KEY_4|MENU_KEY_5|MENU_KEY_6|MENU_KEY_7|MENU_KEY_8|MENU_KEY_9|MENU_KEY_0

#if !defined CUSTOMIP
new ipaddress[256]
#endif
public plugin_init() 
{
	register_plugin(PLUGIN, VERSION, AUTHOR)

	register_dictionary("clientmenu.txt")
	register_menu("Menu_2", keys, "func_menu2")
	register_clcmd("say /menu",			"ShowClientMenu")
	register_clcmd("say_team /menu",	"ShowClientMenu")
	register_clcmd("nightvision",		"ShowClientMenu")			// Меню на N
	#if defined IMPULSEHOOK
	register_impulse(100, "ShowClientMenu")							// Меню на F
	#endif
	#if !defined CUSTOMIP
	get_cvar_string("net_address", ipaddress, charsmax(ipaddress))
	#endif
}

public ShowClientMenu(id)
{
	static menu[512], iLen
	iLen = 0
	#if defined CUSTOMIP
	iLen = 	formatex(menu[iLen], charsmax(menu) - iLen, "\w%L^n", id, "CLIENTM_0", CUSTOMIP)
	#else
	iLen = 	formatex(menu[iLen], charsmax(menu) - iLen, "\w%L^n", id, "CLIENTM_0", ipaddress)
	#endif
	iLen += formatex(menu[iLen], charsmax(menu) - iLen, "\w%L^n", id, "CLIENTM_1")
	keys |= MENU_KEY_1

	iLen += formatex(menu[iLen], charsmax(menu) - iLen, "\w%L^n", id, "CLIENTM_2")
	keys |= MENU_KEY_2

	iLen += formatex(menu[iLen], charsmax(menu) - iLen, "\w%L^n", id, "CLIENTM_3")
	keys |= MENU_KEY_3

	iLen += formatex(menu[iLen], charsmax(menu) - iLen, "\w%L^n", id, "CLIENTM_4")
	keys |= MENU_KEY_4

	iLen += formatex(menu[iLen], charsmax(menu) - iLen, "\w%L^n", id, "CLIENTM_5")
	keys |= MENU_KEY_5

	iLen += formatex(menu[iLen], charsmax(menu) - iLen, "\w%L^n", id, "CLIENTM_6")
	keys |= MENU_KEY_6
	
	iLen += formatex(menu[iLen], charsmax(menu) - iLen, "\w%L^n", id, "CLIENTM_7")
	keys |= MENU_KEY_7

	iLen += formatex(menu[iLen], charsmax(menu) - iLen, "\w%L^n", id, "CLIENTM_8")
	keys |= MENU_KEY_8

	iLen += formatex(menu[iLen], charsmax(menu) - iLen, "\w%L^n", id, "CLIENTM_9")
	keys |= MENU_KEY_9

	iLen += formatex(menu[iLen], charsmax(menu) - iLen, "\w%L", id, "CLIENTM_10")
	keys |= MENU_KEY_0

	show_menu(id, keys, menu, -1, "Menu_2");
	return PLUGIN_HANDLED
}

public func_menu2(id, key)
{
	switch(key)
	{
		case 0: client_cmd(id, "%L", id, "CMD_M1")				//1 пункт
		case 1:	client_cmd(id, "%L", id, "CMD_M2")
		case 2: client_cmd(id, "%L", id, "CMD_M3")
		case 3: client_cmd(id, "%L", id, "CMD_M4")
		case 4: client_cmd(id, "%L", id, "CMD_M5")
		case 5: client_cmd(id, "%L", id, "CMD_M6")
		case 6: client_cmd(id, "%L", id, "CMD_M7")
		case 7: client_cmd(id, "%L", id, "CMD_M8")
		case 8: client_cmd(id, "%L", id, "CMD_M9")				//9 пункт
	}
}