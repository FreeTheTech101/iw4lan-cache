#include common_scripts\utility;
#include maps\mp\_utility;
#include maps\mp\gametypes\_hud_util;

/*
	Title:		Modern Warfare 3 related code
	Notes: 		-
	Version: 	1.0
	Author: 	NoFaTe
*/

initMW3HUD()
{
	self thread initUnderScorePopup();
	//self thread initKillstreakHUD();
}

initUnderScorePopup()
{
	// Create the under score popup element
	self.mw3_scorePopup = newClientHudElem( self );
	self.mw3_scorePopup.horzAlign = "center";
	self.mw3_scorePopup.vertAlign = "middle";
	self.mw3_scorePopup.alignX = "center";
	self.mw3_scorePopup.alignY = "middle";
	self.mw3_scorePopup.x = 35;
	self.mw3_scorePopup.y = -48;
	self.mw3_scorePopup.font = "hudbig";
	self.mw3_scorePopup.fontscale = 0.65;
	self.mw3_scorePopup.archived = false;
	self.mw3_scorePopup.color = (0.5, 0.5, 0.5);
	self.mw3_scorePopup.sort = 10000;
}

initKillstreakHUD()
{
	// Get killstreak icons
	ksOne = tableLookup( "mp/killstreakTable.csv", 1, (self getPlayerData( "killstreaks", 0 )), 14 );
	ksTwo = tableLookup( "mp/killstreakTable.csv", 1, (self getPlayerData( "killstreaks", 1 )), 14 );
	ksThr = tableLookup( "mp/killstreakTable.csv", 1, (self getPlayerData( "killstreaks", 2 )), 14 );
	
	// Create the killstreak counter HUD
	self.ksOneIcon = createKSIcon(ksOne, -90);
	self.ksTwoIcon = createKSIcon(ksTwo, -115);
	self.ksThrIcon = createKSIcon(ksThr, -140);
	
	// Create killstreak shells
	highestCount = self thread getKillstreakHigherCount();
	self.ksShells = [];
	
	if (highestCount > 0)
	{
		h = -53;
		for(i = 0; i < highestCount; i++)
		{
			self.ksShells[i] = createKSShell(h);
			h -= 4;
		}
	}
}

getKillstreakCount(killstreak)
{
	count = int(tableLookup( "mp/killstreakTable.csv", 1, killstreak, 4 ));
	if ( count > 0 )
		return count;
		
	return 0;
}

getKillstreakHigherCount()
{
	ksCounts = [];
	ksCounts[0] = getKillstreakCount(self getPlayerData( "killstreaks", 0 ));
	ksCounts[1] = getKillstreakCount(self getPlayerData( "killstreaks", 1 ));
	ksCounts[2] = getKillstreakCount(self getPlayerData( "killstreaks", 2 ));
	
	highestCount = 0;
	foreach(count in ksCounts)
	{
		if(count > highestCount)
			highestCount = count;
	}
	
	return highestCount;
}

resetKillstreakHUD()
{
	self.ksOneIcon.alpha = 0.4;
	self.ksTwoIcon.alpha = 0.4;
	self.ksThrIcon.alpha = 0.4;

	foreach(shell in self.ksShells)
	{
		shell.alpha = 0.3;
	}
	
	self thread watchKSShells();
}

checkKSProgression(currentStreak)
{
	ksCounts = [];
	ksCounts[0] = getKillstreakCount(self getPlayerData( "killstreaks", 0 ));
	ksCounts[1] = getKillstreakCount(self getPlayerData( "killstreaks", 1 ));
	ksCounts[2] = getKillstreakCount(self getPlayerData( "killstreaks", 2 ));
	
	if (currentStreak >= ksCounts[0])
		self.ksOneIcon.alpha = 0.9;
		
	if (currentStreak >= ksCounts[1])
		self.ksTwoIcon.alpha = 0.9;
		
	if (currentStreak >= ksCounts[2])
		self.ksThrIcon.alpha = 0.9;
}

watchKSShells()
{
	self endon("death");
	self endon("disconnect");
	
	while(true)
	{
		currentStreak = self.pers["cur_kill_streak"];
		self thread checkKSProgression(currentStreak);

		if (self.ksShells.size >= currentStreak - 1)
		{
			for(i = 0; i < self.ksShells.size; i++)
			{
				if (currentStreak > i)
					self.ksShells[i].alpha = 0.85;
				else
					self.ksShells[i].alpha = 0.3;
			}
		}
		wait 0.1;
	}
}

createKSShell(y)
{
	ksShell = NewClientHudElem( self );
	ksShell.x = 40;
	ksShell.y = y;
	ksShell.alignX = "right";
	ksShell.alignY = "bottom";
	ksShell.horzAlign = "right";
	ksShell.vertAlign = "bottom";
	ksShell setshader("white", 10, 2);
	ksShell.alpha = 0.3;
	ksShell.hideWhenInMenu = true;
	ksShell.foreground = false;
	
	return ksShell;
}

createKSIcon(ksShader, y)
{
	ksIcon = createIcon( ksShader, 20, 20 );
	ksIcon setPoint( "BOTTOM RIGHT", "BOTTOM RIGHT", -32, y );
	ksIcon.alpha = 0.4;
	ksIcon.hideWhenInMenu = true;
	ksIcon.foreground = true;
	
	return ksIcon;
}

underScorePopup(string, hudColor, glowAlpha)
{
	// Display text under the score popup
	self endon( "disconnect" );
	self endon( "joined_team" );
	self endon( "joined_spectators" );

	if ( string == "" )
		return;

	self notify( "underScorePopup" );
	self endon( "underScorePopup" );

	self.mw3_scorePopup.color = hudColor;
	self.mw3_scorePopup.glowColor = hudColor;
	self.mw3_scorePopup.glowAlpha = glowAlpha;

	self.mw3_scorePopup setText(string);
	self.mw3_scorePopup.alpha = 0.85;

	wait 1.0;

	self.mw3_scorePopup fadeOverTime( 0.75 );
	self.mw3_scorePopup.alpha = 0;
}

saySound( soundAlias )
{
	// Alert the player using a specific sound and a hitmarker sound
	self playLocalSound("MP_hit_alert");

	prefix = maps\mp\gametypes\_teams::getTeamVoicePrefix( self.team );
	
	soundAlias = prefix + soundAlias;
	
	team = self.pers["team"];
	
	level.speakers[team][level.speakers[team].size] = self;

	self playSoundToTeam( soundAlias, team );

	wait 2.0;
	
	newSpeakers = [];
	for ( index = 0; index < level.speakers[team].size; index++ )
	{
		if ( level.speakers[team][index] == self )
			continue;
			
		newSpeakers[newSpeakers.size] = level.speakers[team][index]; 
	}
	
	level.speakers[team] = newSpeakers;
}

// MW3 Killstreaks
initMW3Killstreaks()
{
	precacheShader("cardicon_skull_black");
	
	// Explosive decoy
	level.crateTypes["airdrop"]["expl_decoy"] = 19;
	level.crateFuncs["airdrop"]["expl_decoy"] = ::decoyCrateThink;
}

// dropType is unused but required
decoyCrateThink( dropType )
{
	self endon ( "death" );
	
	// TODO: Randomize
	crateHint = game["strings"]["uav_hint"];
	maps\mp\killstreaks\_airdrop::crateSetupForUse( crateHint, "all", "cardicon_skull_black" );

	self thread maps\mp\killstreaks\_airdrop::crateOtherCaptureThink();
	self thread maps\mp\killstreaks\_airdrop::crateOwnerCaptureThink();

	for ( ;; )
	{
		self waittill ( "captured", player );
		
		if ( isDefined( self.owner ) && player != self.owner )
		{
			if ( !level.teamBased || player.team != self.team )
			{
				self.owner thread maps\mp\gametypes\_rank::giveRankXP( "killstreak_giveaway", 200 );
			}
		}

		// KABOOM time
		explEnt = spawn("script_origin", self.origin);
		explEnt playSound( "car_explode" );
		playFX( level.chopper_fx["explode"]["medium"], explEnt.origin );
		radiusDamage(explEnt.origin + (0, 0, 30), 350, 250, 20, self.owner, "MOD_EXPLOSIVE", "barrel_mp" );
		physicsExplosionSphere( explEnt.origin + (0, 0, 30), 350, 250, 2 );
		
		PlayRumbleOnPosition( "grenade_rumble", explEnt.origin );
		earthquake( 0.4, 0.76, explEnt.origin, 512 );
		
		wait 0.1;
		
		explEnt delete();
		self maps\mp\killstreaks\_airdrop::deleteCrate();
	}
}