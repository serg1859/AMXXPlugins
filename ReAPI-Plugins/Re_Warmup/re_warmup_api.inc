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

enum WarmupModes { FREE_BUY = 0, ONLY_KNIFE, EQUIP_MENU, RANDOM_WEAPON }

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


forward WarmupStarted()

forward WarmupEnded()

