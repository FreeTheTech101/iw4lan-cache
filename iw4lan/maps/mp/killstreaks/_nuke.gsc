/*************************/
/*      By momo5502      */
/*************************/

#include common_scripts\utility;
#include maps\mp\_utility;

init()
{
	
	precacheItem( "nuke_mp" );
	precacheLocationSelector( "map_nuke_selector" );
	precacheString( &"MP_TACTICAL_NUKE_CALLED" );
	precacheString( &"MP_FRIENDLY_TACTICAL_NUKE" );
	precacheString( &"MP_TACTICAL_NUKE" );

	level._effect[ "nuke_player" ] = loadfx( "explosions/player_death_nuke" );
	level._effect[ "nuke_flash" ] = loadfx( "explosions/player_death_nuke_flash" );
	level._effect[ "nuke_aftermath" ] = loadfx( "dust/nuke_aftermath_mp" );

	game["strings"]["nuclear_strike"] = &"MP_TACTICAL_NUKE";
	
	level.killstreakFuncs["nuke"] = ::tryUseNuke;
	
	level.MoabXP["allies"] = false;
    level.MoabXP["axis"] = false;
	
	setDvarIfUninitialized( "scr_nukeTimer", 10 );
	setDvarIfUninitialized( "scr_nukeCancelMode", 0 );
	setDvarIfUninitialized( "moab", 0 );
	setDvarIfUninitialized( "nuke_location", 0 );
	
	level.nukeTimer = getDvarInt( "scr_nukeTimer" );
	level.cancelMode = getDvarInt( "scr_nukeCancelMode" );
	
	level.moab = getDvarInt( "moab" );
	/#
	setDevDvarIfUninitialized( "scr_nukeDistance", 5000 );
	setDevDvarIfUninitialized( "scr_nukeEndsGame", true );
	setDevDvarIfUninitialized( "scr_nukeDebugPosition", false );
	#/
        level thread onPlayerConnect();
       
}
 
 
 
onPlayerConnect()
{
        for(;;)
        {
                level waittill("connected", player);
                player thread onPlayerSpawned();
        }
}
 
 
onPlayerSpawned()
{
        self endon("disconnect");
 
        for(;;)
        {
                self waittill( "spawned_player" );
               
                if ( level.moab!=0 && ( ( level.teambased && level.MoabXP[self.team] == true ) || ( level.owner == self && level.gameType == "dm" ) ) )
                        self.xpScaler = 2;  
        }
}

tryUseNuke( lifeId, allowCancel )
{
		level.moab    = getDvarInt( "moab" );
		level.locator = getDvarInt( "nuke_location" ); //Choose whether or not to use the location selector!
		if( isDefined( level.nukeIncoming ) && level.moab == 0 || isDefined( level.Plane ) )
		{
			self iPrintLnBold( &"MP_NUKE_ALREADY_INBOUND" );
			return false;	
		}
	else
	{
		if( isDefined( level.Plane ) )
		{
			self iPrintLnBold( &"MP_NUKE_ALREADY_INBOUND" );
			return false;	
		}
	}

	if ( self isUsingRemote() && ( !isDefined( level.gtnw ) || !level.gtnw ) )
		return false;
	
	if ( !isDefined( allowCancel ) )
		allowCancel = true;
		
	myTeam = self.pers["team"];
    otherTeam = level.otherTeam[myTeam];
	level.teamName = otherTeam;
	
	if(level.moab!=0)	
		level.nuke_vision = "aftermath";
	else	
		level.nuke_vision = "mpnuke_aftermath";	
		
	if(level.locator == 1)
		self selectLocation();	
	self thread doNuke( allowCancel );
	self notify( "used_nuke" );
	
	return true;
}

delaythread_nuke( delay, func )
{
	level endon ( "nuke_cancelled" );
	
	wait ( delay );
	
	thread [[ func ]]();
}

doNuke( allowCancel )
{
	level endon ( "nuke_cancelled" );
	
	level.nukeInfo = spawnStruct();
	level.nukeInfo.player = self;
	level.nukeInfo.team = self.pers["team"];
	
	if(level.moab==0)
		level.nukeIncoming = true;
		
	level.nukeDetonated = false;
	level.owner = self;
	level.empPlayer = level.owner;
	
	//level.timeLeft = maps\mp\gametypes\_gamelogic::getTimeRemaining();
	
	maps\mp\gametypes\_gamelogic::pauseTimer();
	level.timeLimitOverride = true;
	setGameEndTime( int( gettime() + (level.nukeTimer * 1000) ) );
	setDvar( "ui_bomb_timer", 4 ); // Nuke sets '4' to avoid briefcase icon showing
	
	if ( level.teambased )
	{
		thread teamPlayerCardSplash( "used_nuke", self, self.team );
		/*
		players = level.players;
		
		foreach( player in level.players )
		{
			playerteam = player.pers["team"];
			if ( isdefined( playerteam ) )
			{
				if ( playerteam == self.pers["team"] )
					player iprintln( &"MP_TACTICAL_NUKE_CALLED", self );
			}
		}
		*/
	}
	else
	{
		if ( !level.hardcoreMode )
			self iprintlnbold(&"MP_FRIENDLY_TACTICAL_NUKE");
	}
	level thread delaythread_nuke( (level.nukeTimer - 9), ::spawnNKPlane); //Spawn Nuke Plane
	level thread delaythread_nuke( (level.nukeTimer - 3.3), ::nukeSoundIncoming );
	level thread delaythread_nuke( (level.nukeTimer - 1.2), ::spawnNKBomb); //Spawn Nuke Bomb
	level thread delaythread_nuke( level.nukeTimer, ::nukeSoundExplosion );
	level thread delaythread_nuke( level.nukeTimer, ::nukeSlowMo );
	level thread delaythread_nuke( level.nukeTimer, ::nukeEffects );
	level thread delaythread_nuke( (level.nukeTimer + 0.25), ::nukeVision );
	level thread delaythread_nuke( (level.nukeTimer + 1.5), ::nukeDeath );
	level thread delaythread_nuke( (level.nukeTimer + 1.5), ::nukeEarthquake );
	level thread nukeAftermathEffect();

	if ( level.cancelMode && allowCancel )
		level thread cancelNukeOnDeath( self ); 

	// leaks if lots of nukes are called due to endon above.
	clockObject = spawn( "script_origin", (0,0,0) );
	clockObject hide();

	while ( level.nukeDetonated == false )
	{
		clockObject playSound( "ui_mp_nukebomb_timer" );
		wait( 1.0 );
	}

}
spawnNKPlane()
{
	if( level.locator == 0 )
	{
		minimapOrigins = getEntArray( "minimap_corner", "targetname" );
		level.location = maps\mp\gametypes\_spawnlogic::findBoxCenter( miniMapOrigins[0].origin, miniMapOrigins[1].origin );
	}
	
	direction = ( 0, randomint(360), 0 );
	
	heightEnt = GetEnt( "airstrikeheight", "targetname" );
	level.planeFlyHeight = heightEnt.origin[2];
	
	planeHalfDistance = 70000;
	
	startPoint = level.location + vector_multiply( anglestoforward( direction ), -1 * planeHalfDistance );
	startPoint += ( 0, 0, level.planeFlyHeight );
	
	endPoint = level.location + vector_multiply( anglestoforward( direction ), planeHalfDistance );
	endPoint += ( 0, 0, level.planeFlyHeight );
	
	startPathRandomness = 100;
	endPathRandomness = 150;
	
	pathStart = startPoint + ( (randomfloat(2) - 1)*startPathRandomness, (randomfloat(2) - 1)*startPathRandomness, 0 );
	pathEnd   = endPoint   + ( (randomfloat(2) - 1)*endPathRandomness  , (randomfloat(2) - 1)*endPathRandomness  , 0 );
	
	level.Plane = spawnplane( level.owner, "script_model", pathStart, "hud_minimap_harrier_green", "hud_minimap_harrier_red" );

	if ( level.owner.team == "allies" )
		level.Plane setModel( "vehicle_av8b_harrier_jet_mp" );
	else
		level.Plane setModel( "vehicle_av8b_harrier_jet_opfor_mp" );
		
	level.Plane thread maps\mp\killstreaks\_airstrike::playPlaneFx();
	level.Plane.angles = direction;
	level.Plane playLoopSound( "veh_mig29_dist_loop" );
	level.Plane moveTo( pathEnd, 16 );
	
	wait ( 17.0 );
	
	level.Plane delete();
}

spawnNKBomb()
{
	level.Plane playSound( "veh_mig29_sonic_boom" );
	
	level.bomb = maps\mp\killstreaks\_airstrike::spawnbomb(level.Plane.origin, level.Plane.angles );
	level.bomb moveGravity( vector_multiply( anglestoforward( ( level.Plane.angles + (20,0,0) )), ( level.planeFlyHeight - level.owner.origin[2] ) ), 2.2 );
	level.bomb RotateYaw( 80, 2.2);
	
	wait( 0.9 );
	
	level.bomb setModel( "tag_origin" );
	
	wait( 0.10 );
	
	playfxontag( level.airstrikefx, level.bomb, "tag_origin" );
	earthquake( 1.0, 2, level.bomb.origin, 2000 );
	wait( 5 );
	
	level.bomb delete();
}

cancelNukeOnDeath( player )
{
	player waittill_any( "death", "disconnect" );

	if ( isDefined( player ) && level.cancelMode == 2 )
		player thread maps\mp\killstreaks\_emp::EMP_Use( 0, 0 );


	maps\mp\gametypes\_gamelogic::resumeTimer();
	level.timeLimitOverride = false;

	setDvar( "ui_bomb_timer", 0 ); // Nuke sets '4' to avoid briefcase icon showing

	level notify ( "nuke_cancelled" );
}

nukeSoundIncoming()
{
	level endon ( "nuke_cancelled" );
	
	foreach( player in level.players )
		player playlocalsound( "nuke_incoming" );
}

nukeSoundExplosion()
{
	level endon ( "nuke_cancelled" );

	foreach( player in level.players )
	{
		player playlocalsound( "nuke_explosion" );
		
		if( level.moab != 0 )
			player playLocalSound( "emp_activate" );
			
		player playlocalsound( "nuke_wave" );
		if( level.moab == 0 )
		{
			wait( 2.0 );
			player playlocalsound( "mp_defeat" );
		}
	}
}

nukeEffects()
{
	level endon ( "nuke_cancelled" );

	setDvar( "ui_bomb_timer", 0 );
	setGameEndTime( 0 );

	level.nukeDetonated = true;
	level maps\mp\killstreaks\_emp::destroyActiveVehicles( level.nukeInfo.player );

	foreach( player in level.players )
	{
		playerForward = anglestoforward( player.angles );
		playerForward = ( playerForward[0], playerForward[1], 0 );
		playerForward = VectorNormalize( playerForward );
	
		nukeDistance = 5000;
		/# nukeDistance = getDvarInt( "scr_nukeDistance" );	#/

		//nukeEnt = Spawn( "script_model", player.origin + Vector_Multiply( playerForward, nukeDistance ) );
		nukeEnt = Spawn( "script_model", level.bomb.origin );
		nukeEnt setModel( "tag_origin" );
		nukeEnt.angles = ( 0, (player.angles[1] + 180), 90 );

		/#
		if ( getDvarInt( "scr_nukeDebugPosition" ) )
		{
			lineTop = ( nukeEnt.origin[0], nukeEnt.origin[1], (nukeEnt.origin[2] + 500) );
			thread draw_line_for_time( nukeEnt.origin, lineTop, 1, 0, 0, 10 );
		}
		#/

		nukeEnt thread nukeEffect( player );
		player.nuked = true;
	}
}

nukeEffect( player )
{
	level endon ( "nuke_cancelled" );

	player endon( "disconnect" );

	waitframe();
	PlayFXOnTagForClients( level._effect[ "emp_flash" ], self, "tag_origin", player );
	PlayFXOnTagForClients( level._effect[ "nuke_flash" ], self, "tag_origin", player );
}

nukeAftermathEffect()
{
	level endon ( "nuke_cancelled" );

	level waittill ( "spawning_intermission" );
	
	afermathEnt = getEntArray( "mp_global_intermission", "classname" );
	afermathEnt = afermathEnt[0];
	up = anglestoup( afermathEnt.angles );
	right = anglestoright( afermathEnt.angles );

	PlayFX( level._effect[ "nuke_aftermath" ], afermathEnt.origin, up, right );
}

nukeSlowMo()
{
	level endon ( "nuke_cancelled" );

	//SetSlowMotion( <startTimescale>, <endTimescale>, <deltaTime> )
	setSlowMotion( 1.0, 0.25, 0.5 );
	level waittill( "nuke_death" );
	setSlowMotion( 0.25, 1, 2.0 );
}

nukeVision()
{
	level endon ( "nuke_cancelled" );

	level.nukeVisionInProgress = true;
	visionSetNaked( "mpnuke", 3 );

	level waittill( "nuke_death" );

	visionSetNaked( "mpnuke_aftermath", 5 );
	wait 8;
	level.nukeVisionInProgress = undefined;
	level.MoabXP[ level.owner.team ] = true;
	//visionSetNaked( "aftermath", 7 );
	//wait 7;
	visionSetNaked( "tulsa", 17 );
	wait 27;
	if(level.moab!=0)
	visionSetNaked( getDvar("mapname"), 60 );
}

nukeDeath()
{
	level endon ( "nuke_cancelled" );
	
	level notify( "nuke_death" );
	
	maps\mp\gametypes\_hostmigration::waitTillHostMigrationDone();	
	
	if(level.moab!=0)
	{
	/*
		level.timeLimitOverride = true;
		setGameEndTime( int( level.timeLeft ) );
	*/
	maps\mp\gametypes\_gamelogic::resumeTimer();
	level.timeLimitOverride = false;

	setDvar( "ui_bomb_timer", 0 );
	
	level thread maps\mp\killstreaks\_emp::destroyActiveVehicles( level.owner );
	}
		
	if( isDefined("level.hunted_weather") && level.hunted_weather == 1)
	{}
	
	else
		AmbientStop(1);
	
	setDvar( "g_knockback", "99999"); 
	foreach( player in level.players )
	{
		if ( isAlive( player ) )
		{
			if(level.moab==0)
				player thread maps\mp\gametypes\_damage::finishPlayerDamageWrapper( level.nukeInfo.player, level.nukeInfo.player, 999999, 0, "MOD_EXPLOSIVE", "nuke_mp", player.origin, player.origin, "none", 0, 0 );
			
			else
			{
				if( level.teamBased )
				{
					if( player.team != level.owner.team )
					{
						player thread maps\mp\gametypes\_damage::finishPlayerDamageWrapper( level.nukeInfo.player, level.nukeInfo.player, 999999, 0, "MOD_EXPLOSIVE", "nuke_mp", player.origin, player.origin, "none", 0, 0 );
						level thread launchEMP();
					}
					
					if ( player.team == level.owner.team )
					{
						if(player.health >= 10)
							player thread maps\mp\gametypes\_damage::finishPlayerDamageWrapper( level.nukeInfo.player, level.nukeInfo.player, 10, 0, "MOD_EXPLOSIVE", "nuke_mp", player.origin, player.origin, "none", 0, 0 );
					}
				}
				
				else
				{
					if ( player == level.owner )
					{
						if(player.health >= 10)
							player thread maps\mp\gametypes\_damage::finishPlayerDamageWrapper( level.nukeInfo.player, level.nukeInfo.player, 10, 0, "MOD_EXPLOSIVE", "nuke_mp", player.origin, player.origin, "none", 0, 0 );
					}
					
					else
					{
						player thread maps\mp\gametypes\_damage::finishPlayerDamageWrapper( level.nukeInfo.player, level.nukeInfo.player, 999999, 0, "MOD_EXPLOSIVE", "nuke_mp", player.origin, player.origin, "none", 0, 0 );
					}
				}
			}
		}
	}
	
	level.postRoundTime = 10;
	
	setDvar( "g_knockback", "1000"); 
	
	if(level.moab==0)
	{
		nukeEndsGame = true;

		if ( level.teamBased )
			thread maps\mp\gametypes\_gamelogic::endGame( level.nukeInfo.team, game["strings"]["nuclear_strike"], true );
		else
		{
			if ( isDefined( level.nukeInfo.player ) )
				thread maps\mp\gametypes\_gamelogic::endGame( level.nukeInfo.player, game["strings"]["nuclear_strike"], true );
			else
				thread maps\mp\gametypes\_gamelogic::endGame( level.nukeInfo, game["strings"]["nuclear_strike"], true );
		}
	}
}

nukeEarthquake()
{
	level endon ( "nuke_cancelled" );

	level waittill( "nuke_death" );

	// TODO: need to get a different position to call this on - I found it :P
	earthquake( 0.6, 10, level.bomb.origin, 100000 );

	foreach( player in level.players )
		player PlayRumbleOnEntity( "damage_heavy" );
}


waitForNukeCancel()
{
	self waittill( "cancel_location" );
	self setblurforplayer( 0, 0.3 );
}

endSelectionOn( waitfor )
{
	self endon( "stop_location_selection" );
	self waittill( waitfor );
	self thread stopNukeLocationSelection( (waitfor == "disconnect") );
}

endSelectionOnGameEnd()
{
	self endon( "stop_location_selection" );
	level waittill( "game_ended" );
	self thread stopNukeLocationSelection( false );
}

stopNukeLocationSelection( disconnected )
{
	if ( !disconnected )
	{
		self setblurforplayer( 0, 0.3 );
		self endLocationSelection();
		self.selectingLocation = undefined;
	}
	self notify( "stop_location_selection" );
}

launchEMP()
{
	level endon( "used_nuke" );
	
	level.teamEMPed[level.teamName] = true;
	level notify ( "emp_update" );
	wait( 60 );
	level.empPlayer = undefined;
	level.teamEMPed[level.teamName] = false;
	level notify ( "emp_update" );
    level notify ( "emp_ended" );

}

selectLocation()
{
		targetSize = level.mapSize / 5.625; // 138 in 720
        if ( level.splitscreen )
                targetSize *= 1.5;

		self beginLocationSelection( "map_nuke_selector", false, targetSize );
        self.selectingLocation = true;
 
        self setblurforplayer( 4.0, 0.3 );
 
        self thread endSelectionOn( "cancel_location" );
        self thread endSelectionOn( "death" );
        self thread endSelectionOn( "disconnect" );
        self thread endSelectionOn( "used_nuke" ); // so that this thread doesn't kill itself when we use an airstrike
        self thread endSelectionOnGameEnd();
        //self thread endSelectionOnEMP();
 
        self endon( "stop_location_selection" );
 
        // wait for the selection. randomize the yaw if we're not doing a precision airstrike.
        self waittill( "confirm_location", location );
		level.location = location;
		self endLocationSelection();
		self.selectingLocation = undefined;
        self setblurforplayer( 0, 0.3 );
}