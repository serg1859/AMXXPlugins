#include <amxmodx> 

#define PLUGIN_NAME "SmokeLOG.log"

#define CVARNAME "cl_pmanstats"


public plugin_init(){
	register_plugin( PLUGIN_NAME, "0.03f", "wopox")
}

public client_putinserver(id){
	if(!is_user_bot(id) || !is_user_hltv(id))
	{
		set_task(5.0,"checkCvar",id)
	}
}

public checkCvar(id)
{
	if(is_user_connected(id))
	{
		query_client_cvar(id, CVARNAME ,"cvar_result_func")
	}
	
}

public cvar_result_func(id,const Cvar[],const Value[]){
	new name[33]
	get_user_name(id,name,charsmax(name))

	if( Value[0] != '0' )
	{
		log_to_file(PLUGIN_NAME, "[!!!] %s: CVAR ' %s =%s '",name, Cvar, Value)
	}
}
