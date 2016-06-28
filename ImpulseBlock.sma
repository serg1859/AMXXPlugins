/* 
Impulse Block
Автор: wopox
Версия: 0.1 от 17.02.2016 г.

Описание: Блокировка команд использования Фонарика, спрея.

Квары:
amx_impulse_block "1"       // [1 - включить блокировку, 0 - выключить]

История версий:
v0.1
	- Создание плагина.
*/

#include <amxmodx>
#include <engine>

new g_cvar
public plugin_init(){
	register_plugin("ImpulseCMD Block", "0.1", "wopox")
	register_impulse(100, "impulseBlock") 			// Блокировка фонарика
	register_impulse(201, "impulseBlock") 			// Блокировка спрея
	g_cvar = register_cvar("amx_impulse_block", "1")
}

public impulseBlock(id) return get_pcvar_num(g_cvar) ? PLUGIN_HANDLED : PLUGIN_CONTINUE