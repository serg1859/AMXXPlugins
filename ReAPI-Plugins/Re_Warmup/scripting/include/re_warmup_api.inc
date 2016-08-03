#if defined _re_warmup_api_included
  #endinput
#endif
#define _re_warmup_api_included

#if AMXX_VERSION_NUM >= 175
	#pragma reqlib re_warmup_api
	#if !defined AMXMODX_NOAUTOLOAD
		#pragma loadlib re_warmup_api
	#endif
#else
	#pragma library re_warmup_api
#endif

enum WarmupModes { FREE_BUY = 0, ONLY_KNIFE, EQUIP_MENU, AUTO_EQUIP, RANDOM_WEAPON }
#define IsValidTeam(%1) 	(TEAM_TERRORIST <= get_member(%1, m_iTeam) <= TEAM_CT)

//******** Natives ********

/** Return true is Warmup Started
 */
native bool:GetWarmupState()

/**
 * Gets Warmup Mode
 *
 * @return			WarmupModes
 */
native WarmupModes:GetWarmupMode()

/**
 * Sets Warmup Mode
 * 
 * @param iMode 	Warmup Mode
 * @param iTime 	Warmup Time
 *
 * @note 			set Time == 0 to disable warmup mode
 * @noreturn
 */
native SetWarmupMode(WarmupModes:iMode, iTime)


//******** Forwards ******** 

/** stop on PLUGIN_HANDLED */
forward WarmupStarted(WarmupModes:iMode, iTime)

forward WarmupEnded()

forward WarmupCountdown(iCurrent, iCountdown)





