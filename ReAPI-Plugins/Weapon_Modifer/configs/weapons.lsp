
; ================================================================================
;
; "member name"		 "description" 								"min/max"
;
; m_iMaxClip 		 weapon maxclip 							[1/255]
; m_iMaxAmmo 		 weapon maxbackpack ammo					[0/255]
; m_iPrice 			 weapon cost 								[0/N]
; m_iAmmoPrice 		 ammo cost 									[0/N]
; m_iReward 		 kill reward 								[1/N]
; m_iSlot	 		 hud slot index 							[0/N]
; m_iPosition	 	 hud position number in slot 				[1/N]
; m_iWeight 		 weapon weight 								[0/N]
; m_bitFlags 		 see "Weapon Flags"							[0/N]
; m_fSwitchDelay 	 delay after deploy 						[0.01/5.0]
; m_fNextPrimAttack  next primary attack delay					[0.01/5.0]
; m_fNextSecAttack   next secondary attack delay 				[0.01/5.0]
; m_fReloadTime 	 for custom models 							[1.0/20.0]
; m_fPrimSpeed 		 player speed								[100.0/1000.0]
; m_fSecSpeed 		 player speed (zoomed/uses shield)			[100.0/1000.0]
; m_fDamage 		 damage multiplier							[0.01/5.0]
;
; ================================================================================

; Weapon Flags: 
; "a" = can't drop
; "b" = don't drop on death
; "c" = refill clip on spawn
; "d" = refill clip on kill
; "e" = set default weapon
; "f" = give free ammo on buy


; Format:
; [weapon_name]
; {
;	 "member" 	"value"
; }


[weapon_awp]
{	
	"m_iMaxClip" 		"5"
	"m_iMaxAmmo"		"50"
	"m_iPrice" 			"2150"
	"m_iAmmoPrice" 		"350"
	"m_iReward" 		"350"
	; "m_fReloadTime" 	"1.5"
	; "m_iSlot" 		"1"
	; "m_iPosition" 	"17"
	; "m_iWeight" 		"1"
	; "m_bitFlags" 		"ba"
	"m_fSwitchDelay" 	"0.8"
	"m_fPrimSpeed" 		"311.3"
	"m_fSecSpeed" 		"350.9"
	"m_fDamage" 		"1.4"
}

[weapon_ak47]
{
	"m_iMaxClip" 		"25"
	"m_iMaxAmmo"		"120"
	"m_iAmmoPrice" 		"5"
	"m_iReward" 		"50"
	"m_bitFlags" 		"f"
	; "m_iSlot" 		"1"
	; "m_iPosition" 	"8"
	; "m_fReloadTime" 	"1.1"
	; "m_fSwitchDelay" 	"0.1"
	"m_fPrimSpeed" 		"270.0"
	; "m_fSecSpeed" 	"150"
	"m_iPrice" 			"150"
	"m_fDamage" 		"1.1"
}

; [weapon_knife]
; {
	; "m_fNextPrimAttack" 	"0.1"
	; "m_fNextSecAttack" 	"0.2"
; }

; [weapon_hegrenade]
; {
	; "m_fDamage" 		"2.8"
; }







