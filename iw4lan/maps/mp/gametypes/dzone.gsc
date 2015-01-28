#include common_scripts\utility;
#include maps\mp\_utility;
#include maps\mp\gametypes\_hud_util;

/*
	Drop Zone
	Objective: 	Score points for your team over time by holding the drop zone.
				Periodic carepackage awarded to player who's been in drop zone the longest.
	Map ends:	When one team reaches the score limit, or time limit is reached
	Respawning:	No wait / Near teammates / Near drop zone

	Level requirementss
	------------------
		Start Spawnpoints:
			classname		mp_sab_spawn_allies_start, mp_sab_spawn_axis_start
			
		Spawnpoints:
			classname		mp_tdm_spawn	
			All players spawn from these. The spawnpoint chosen is dependent on the current locations of drop zone, teammates, and enemies
			at the time of spawn. Players generally spawn behind their teammates relative to the direction of enemies.

		Spectator Spawnpoints:
			classname		mp_global_intermission
			Spectators spawn from these and intermission is viewed from these positions.
			Atleast one is required, any more and they are randomly chosen between.
*/

/*
	Title:		'Drop Zone' Game Mode
	Notes: 		Thanks to xetal for helping out with the drop zones
	Version: 	1.0
	Author: 	Infinity Ward / NoFaTe
*/

GRND_ZONE_TOUCH_RADIUS = 300;
GRND_ZONE_DROP_RADIUS = 72;

main()
{
	if(getdvar("mapname") == "mp_background")
		return;

	maps\mp\gametypes\_globallogic::init();
	maps\mp\gametypes\_callbacksetup::SetupCallbacks();
	maps\mp\gametypes\_globallogic::SetupCallbacks();

	SetDvarIfUninitialized("scr_" + level.gameType + "_timelimit", 10);
	SetDvarIfUninitialized("scr_" + level.gameType + "_scorelimit", 12000);
	SetDvarIfUninitialized("scr_" + level.gameType + "_roundlimit", 1);
	SetDvarIfUninitialized("scr_" + level.gameType + "_winlimit", 1);
	SetDvarIfUninitialized("scr_" + level.gameType + "_roundswitch", 1);
	SetDvarIfUninitialized("scr_" + level.gameType + "_numlives", 0);
	SetDvarIfUninitialized("scr_" + level.gameType + "_halftime", 0);
	
	registerTimeLimitDvar( level.gameType, 10, 0, 1440 );
	registerScoreLimitDvar( level.gameType, 12000, 0, 50000 );
	registerRoundLimitDvar( level.gameType, 1, 0, 30 );
	registerWinLimitDvar( level.gameType, 1, 0, 10 );
	registerRoundSwitchDvar( level.gameType, 1, 0, 30 );
	registerNumLivesDvar( level.gameType, 0, 0, 10 );
	registerHalfTimeDvar( level.gameType, 0, 0, 1 );
	
	level.matchRules_dropTime = 45;
	level.matchRules_zoneSwitchTime = 90;
	level.zoneConflict = false;
	
	level.teamBased = true;
	level.onPrecacheGameType = ::onPrecacheGameType;
	level.onStartGameType = ::onStartGameType;
	level.getSpawnPoint = ::getSpawnPoint;
	level.onSpawnPlayer = ::onSpawnPlayer;	

	// TODO: Create new FX (?)
	level.grnd_fx["smoke"] = loadFx( "misc/flare_ambient" );
	
	level thread onPlayerConnect();
	createZones();
}

onPlayerConnect()
{
	for ( ;; )
	{
		level waittill( "connected", player );
		player thread maps\mp\gametypes\_mw3::initMW3HUD();
	}
}

onPrecacheGameType()
{
	precacheShader( "waypoint_captureneutral" );
	precacheShader( "waypoint_capture" );
	precacheShader( "waypoint_defend" );	
	
	precacheModel( "prop_flag_neutral" );
	
	precacheString( &"OBJECTIVES_GRND" );	
	precacheString( &"OBJECTIVES_GRND_SCORE" );	
	precacheString( &"OBJECTIVES_GRND_HINT" );	
	precacheString( &"OBJECTIVES_GRND_CONFIRM" );	
	precacheString( &"MP_CALLING_AIRDROP" );
	precacheString( &"MP_NEXT_DROP_ZONE_IN" );

	precacheModel( "mil_emergency_flare_mp" );
	precacheMenu( "iw5" );
}

onStartGameType()
{
	setClientNameMode("auto_change");

	if ( !isdefined( game["switchedsides"] ) )
		game["switchedsides"] = false;

	setObjectiveText( "allies", &"OBJECTIVES_GRND" );
	setObjectiveText( "axis", &"OBJECTIVES_GRND" );
	
	if ( level.splitscreen )
	{
		setObjectiveScoreText( "allies", &"OBJECTIVES_GRND" );
		setObjectiveScoreText( "axis", &"OBJECTIVES_GRND" );
	}
	else
	{
		setObjectiveScoreText( "allies", &"OBJECTIVES_GRND_SCORE" );
		setObjectiveScoreText( "axis", &"OBJECTIVES_GRND_SCORE" );
	}
	setObjectiveHintText( "allies", &"OBJECTIVES_GRND_HINT" );
	setObjectiveHintText( "axis", &"OBJECTIVES_GRND_HINT" );

	level.spawnMins = ( 0, 0, 0 );
	level.spawnMaxs = ( 0, 0, 0 );		
	maps\mp\gametypes\_spawnlogic::placeSpawnPoints( "mp_sab_spawn_allies_start" );
	maps\mp\gametypes\_spawnlogic::placeSpawnPoints( "mp_sab_spawn_axis_start" );		
	maps\mp\gametypes\_spawnlogic::addSpawnPoints( "allies", "mp_tdm_spawn" );
	maps\mp\gametypes\_spawnlogic::addSpawnPoints( "axis", "mp_tdm_spawn" );	
	level.mapCenter = maps\mp\gametypes\_spawnlogic::findBoxCenter( level.spawnMins, level.spawnMaxs );
	setMapCenter( level.mapCenter );	
	
	//	get the central loction for first DZ using the SAB bomb, before it is removed
	centerLocObj = getEnt( "sab_bomb", "targetname" );	
	level.grnd_centerLoc = centerLocObj.origin;	
	
	maps\mp\gametypes\_rank::registerScoreInfo( "zone_kill", 100 );	
	maps\mp\gametypes\_rank::registerScoreInfo( "zone_tick",  20 );
	
	allowed[0] = level.gameType;
	allowed[1] = "tdm";	
	
	maps\mp\gametypes\_gameobjects::main(allowed);	
	
	level.grnd_timerDisplay = createServerTimer( "objective", 1.4 );
	level.grnd_timerDisplay setPoint( "TOPLEFT", "TOPLEFT", 115, 5 );
	level.grnd_timerDisplay.label = &"MP_NEXT_DROP_ZONE_IN";
	level.grnd_timerDisplay.alpha = 0;
	level.grnd_timerDisplay.archived = false;
	level.grnd_timerDisplay.hideWhenInMenu = true;	
	thread hideHudElementOnGameEnd( level.grnd_timerDisplay );
	
	level thread maps\mp\gametypes\_mw3::initMW3Killstreaks();
	
	initFirstZone();
}

initFirstZone()
{
	level.zonesCycling = false;	

	//	find the closest zone to center	
	shortestDistance = 999999;
	shortestDistanceIndex = 0;
	for ( i=0; i < level.dropZones[level.script].size; i++ )
	{
		dropZone = level.dropZones[level.script][i];
		distToCenter = distance2d( level.grnd_centerLoc, dropZone );
		if ( distToCenter < shortestDistance )
		{
			shortestDistance = distToCenter;
			shortestDistanceIndex = i;
		}
	}		
	level.grnd_initialIndex = shortestDistanceIndex;
	initilPos = level.dropZones[level.script][shortestDistanceIndex];	
	
	//	create marker
	level.grnd_zone = spawn( "script_model", initilPos );
	level.grnd_zone.origin = initilPos;
	level.grnd_zone.angles = ( 90, 0, 0 );
	level.grnd_zone setModel( "mil_emergency_flare_mp" );
	
	//	spawning
	level.favorCloseSpawnEnt = level.grnd_zone;
	level.favorCloseSpawnScalar = 5;	
	
	//	make the rest
	level thread initZones();	
}

initZones()
{
	level.grnd_zones = [];
	for ( i=0; i < level.dropZones[level.script].size; i++ )
	{
		dropZone = level.dropZones[level.script][i];
		level.grnd_zones[i] = spawn( "script_origin", dropZone );
		level.grnd_zones[i].origin = dropZone;
		wait( 0.05 );
	}
	
	level.grnd_zones[level.grnd_initialIndex] delete();
	level.grnd_zones[level.grnd_initialIndex] = undefined;
	level.grnd_zones = array_removeUndefined( level.grnd_zones );	
}

getSpawnPoint()
{
	if ( level.inGracePeriod )
	{
		spawnPoints = maps\mp\gametypes\_spawnlogic::getSpawnpointArray( "mp_sab_spawn_" + self.pers["team"] + "_start" );
		spawnPoint = maps\mp\gametypes\_spawnlogic::getSpawnpoint_Random( spawnPoints );
	}
	else
	{
		spawnPoints = maps\mp\gametypes\_spawnlogic::getTeamSpawnPoints( self.pers["team"] );
		spawnPoint = maps\mp\gametypes\_spawnlogic::getSpawnpoint_NearTeam( spawnPoints );
	}
	
	return spawnPoint;
}

onSpawnPlayer()
{
	self openMenu( "iw5" );

	//self thread maps\mp\gametypes\_mw3::resetKillstreakHUD();
	
	//	in/out zone indicator
	if ( !isDefined( self.inGrindZone ) )
	{
		level thread setPlayerMessages( self );	
		
		//	let the first player in activate this
		if ( !level.zonesCycling )
		{
			level thread cycleZones();	
			level thread locationScoring();	
		}
	}		

	level notify ( "spawned_player" );	
}

setPlayerMessages( player )
{
	level endon( "game_ended" );	
	
	gameFlagWait( "prematch_done" );	
	
	//	points
	player.inGrindZonePoints = 0;
	
	//	hud indicator		
	player.grndHUDText = player createFontString( "small", 1.6 );	
	player.grndHUDText setPoint( "TOP LEFT", "TOP LEFT", 115, 22 );
	player.grndHUDText.alpha = 1;
	player.grndHUDText.hideWhenInMenu = true;	
	level thread hideHudElementOnGameEnd( player.grndHUDText );	
	
	//	hud icon
	//player.grndHeadIcon = level.grnd_zone maps\mp\_entityheadIcons::setHeadIcon( player, "waypoint_captureneutral", (0,0,0), 14, 14 );

	//	minimap waypoint
	player.grndObjId = maps\mp\gametypes\_gameobjects::getNextObjID();	
	objective_add( player.grndObjId, "invisible", (0,0,0) );
	Objective_OnEntity( player.grndObjId, level.grnd_zone );
	objective_icon( player.grndObjId, "waypoint_captureneutral" );
	objective_state( player.grndObjId, "active" );
	
	// TODO: level.zoneConflict check
	if ( distance2D( level.grnd_zone.origin, player.origin ) < GRND_ZONE_TOUCH_RADIUS )	
	{
		player.inGrindZone = true;
		player.grndHUDText setText( &"OBJECTIVES_GRND_CONFIRM" );	
		player.grndHUDText.color = (0.6,1,0.6);
		//player.grndHeadIcon.alpha = 0;
	}
	else
	{
		player.inGrindZone = false;
		player.grndHUDText setText( &"OBJECTIVES_GRND_HINT" );	
		player.grndHUDText.color = (1,0.6,0.6);	
		//player.grndHeadIcon.alpha = 0.85;
	}
	
	player.grnd_wasSpectator = false;
	if ( player.team == "spectator" )
	{
		player.inGrindZone = false;
		player.inGrindZonePoints = 0;
		//player.grndHeadIcon.alpha = 0;
		player.grndHUDText.alpha = 0;	
		player.grnd_wasSpectator = true;		
	}	
	
	player thread grndTracking();		
}

getNextZone()
{
	pos = undefined;
	index = undefined;
	
	if ( level.grnd_zones.size > 2 )
	{
		//	get the distance to the current zone from all the remaining zones
		//	set index and save furthest and closest along the way
		closestDistance = 999999;
		furthestDistance = 0;
		for ( i=0; i < level.grnd_zones.size; i++ )
		{
			level.grnd_zones[i].index = i;
			level.grnd_zones[i].distToZone = distance( level.grnd_zones[i].origin, level.grnd_zone.origin );
			if ( level.grnd_zones[i].distToZone > furthestDistance )
				furthestDistance = level.grnd_zones[i].distToZone;
			else if ( level.grnd_zones[i].distToZone < closestDistance )
				closestDistance = level.grnd_zones[i].distToZone;
		}
		
		//	try to get a grouping of far zones to randomly choose from
		farZones = [];
		closeZones = [];
		halfDistance = int( ( closestDistance + furthestDistance ) / 2 );
		for ( i=0; i < level.grnd_zones.size; i++ )
		{
			if ( level.grnd_zones[i].distToZone >= halfDistance )
				farZones[farZones.size] = level.grnd_zones[i];
			else
				closeZones[closeZones.size] = level.grnd_zones[i];
		}	
		zone = undefined;
		if ( farZones.size > 1 )
			zone = farZones[ randomIntRange( 0, farZones.size ) ];
		else
			zone = farZones[0];		
		index = zone.index;		
	}
	else if ( level.grnd_zones.size == 2 )
	{
		distanceA = distance( level.grnd_zones[0].origin, level.grnd_zone.origin );
		distanceB = distance( level.grnd_zones[1].origin, level.grnd_zone.origin );		
		if ( distanceA > distanceB )
			index = 0;
		else	
			index = 1;		
	}
	else if ( level.grnd_zones.size == 1 )
	{
		index = 0;
	}
	
	if ( isDefined( index ) )
	{
		pos = level.grnd_zones[index].origin;
		level.grnd_zones[index] delete();
		level.grnd_zones[index] = undefined;		
		level.grnd_zones = array_removeUndefined( level.grnd_zones );		
	}
	else
	{
		//	start all over
		pos = level.dropZones[level.script][level.grnd_initialIndex];
		level thread initZones();		
	}
	
	return pos;	
}

cycleZones()
{	
	level endon( "game_ended" );	
	
	gameFlagWait( "prematch_done" );	

	//fxEnt = undefined;
	
	while( true )
	{	
		initialScores["axis"] = game["teamScores"]["axis"];
		initialScores["allies"] = game["teamScores"]["allies"];
		
		//	move zone
		pos = undefined;
		if ( !level.zonesCycling )
		{
			level.zonesCycling = true;
			pos = level.grnd_zone.origin;
		}
		else
		{
			pos = getNextZone();
			//if ( isdefined( fxEnt ) )
				//fxEnt delete();
			wait( 0.05 );			
		}		
		traceStart = pos;
		traceEnd = pos + (0,0,-1000);
		trace = bulletTrace( traceStart, traceEnd, false, undefined );		
		level.grnd_zone.origin = trace["position"] + (0,0,1);
		
		//	smoke
		wait( 0.05 );
	
		angles = level.grnd_zone getTagAngles( "tag_fire_fx" );
		fxEnt = SpawnFx( level.grnd_fx["smoke"], level.grnd_zone getTagOrigin( "tag_fire_fx" ), anglesToForward( angles ), anglesToUp( angles ) );
		TriggerFx( fxEnt );
		
		//	reset drops
		if ( level.matchRules_dropTime )
			level thread randomDrops();
		
		//	wait
		level.grnd_timerDisplay.label = &"MP_NEXT_DROP_ZONE_IN";
		level.grnd_timerDisplay setTimer( level.matchRules_zoneSwitchTime );
		level.grnd_timerDisplay.alpha = 1;	
		maps\mp\gametypes\_hostmigration::waitLongDurationWithHostMigrationPause( level.matchRules_zoneSwitchTime );				
		level.grnd_timerDisplay.alpha = 0;	
		
		fxEnt delete();
		
		//	audio cue for progress
		if ( game["teamScores"]["axis"] - initialScores["axis"] > game["teamScores"]["allies"] - initialScores["allies"] )
		{
			playSoundOnPlayers( "mp_obj_captured", "axis" );
			playSoundOnPlayers( "mp_enemy_obj_captured", "allies" );
		}		
		else if ( game["teamScores"]["allies"] - initialScores["allies"] > game["teamScores"]["axis"] - initialScores["axis"] )
		{
			playSoundOnPlayers( "mp_obj_captured", "allies" );
			playSoundOnPlayers( "mp_enemy_obj_captured", "axis" );
		}		
	}			
}

grndTracking()
{
	self endon( "disconnect" );
	level endon( "game_ended" );
	
	while( true )
	{
		if ( !self.grnd_wasSpectator && self.team == "spectator" )
		{
			self.inGrindZone = false;
			self.inGrindZonePoints = 0;
			//self.grndHeadIcon.alpha = 0;
			self.grndHUDText.alpha = 0;	
			self.grnd_wasSpectator = true;		
		}
		else if ( self.team != "spectator" )
		{
			// TODO: level.zoneConflict check
			if ( ( self.grnd_wasSpectator || !self.inGrindZone ) && distance2D( level.grnd_zone.origin, self.origin ) < GRND_ZONE_TOUCH_RADIUS )	
			{
				self.inGrindZone = true;
				self.inGrindZonePoints = 0;
				self.grndHUDText setText( &"OBJECTIVES_GRND_CONFIRM" );	
				self.grndHUDText.color = (0.6,1,0.6);
				self.grndHUDText.alpha = 1;
				//self.grndHeadIcon.alpha = 0;
			}
			else if ( ( self.grnd_wasSpectator || self.inGrindZone ) && distance2D( level.grnd_zone.origin, self.origin ) >= GRND_ZONE_TOUCH_RADIUS )
			{
				self.inGrindZone = false;
				self.inGrindZonePoints = 0;
				self.grndHUDText setText( &"OBJECTIVES_GRND_HINT" );	
				self.grndHUDText.color = (1,0.6,0.6);
				self.grndHUDText.alpha = 1;
				//self.grndHeadIcon.alpha = 0.85;
			}
			self.grnd_wasSpectator = false;
		}
		
		wait( 0.05 );
	}	
}

locationScoring()
{
	level endon( "game_ended" );
	
	gameFlagWait( "prematch_done" );
	
	score = maps\mp\gametypes\_rank::getScoreInfoValue( "zone_tick" );
	assert( isDefined( score ) );	
	
	while( true )
	{
		numPlayers["axis"] = 0;
		numPlayers["allies"] = 0;
		
		//	score
		foreach( player in level.players )
		{
			if ( isDefined( player.inGrindZone ) && isAlive( player ) && distance2D( level.grnd_zone.origin, player.origin ) < GRND_ZONE_TOUCH_RADIUS )
			{
				numPlayers[player.pers["team"]]++;
				player.inGrindZonePoints += score;				
			}
		}
		
		level.zoneConflict = false;
		
		if ( numPlayers["axis"] && numPlayers["allies"] != numPlayers["axis"] )
			maps\mp\gametypes\_gamescore::giveTeamScoreForObjective( "axis", score * numPlayers["axis"] );
		if ( numPlayers["allies"] && numPlayers["axis"] != numPlayers["allies"] )
			maps\mp\gametypes\_gamescore::giveTeamScoreForObjective( "allies", score * numPlayers["allies"] );
		
		//	waypoints and compasspings
		if ( numPlayers["axis"] == numPlayers["allies"] )
		{
			foreach( player in level.players )
			{
				if ( isDefined( player.inGrindZone ) )
				{
					//player.grndHeadIcon setShader( "waypoint_captureneutral", 14, 14 );
					//player.grndHeadIcon setWaypoint( false, false );
					objective_icon( player.grndObjId, "waypoint_captureneutral" );
				}
			}			
		}
		else
		{
			foreach( player in level.players )
			{
				if ( isDefined( player.inGrindZone ) )
				{
					if ( numPlayers[player.pers["team"]] > numPlayers[level.otherTeam[player.pers["team"]]] )
					{
						//player.grndHeadIcon setShader( "waypoint_defend", 14, 14 );
						//player.grndHeadIcon setWaypoint( false, false );
						objective_icon( player.grndObjId, "waypoint_defend" );					
					}
					else
					{
						//player.grndHeadIcon setShader( "waypoint_capture", 14, 14 );
						//player.grndHeadIcon setWaypoint( false, false );
						objective_icon( player.grndObjId, "waypoint_capture" );					
					}
				}
			}			
		}		
		
		wait 1.25;
	}
}

randomDrops()
{
	level endon( "game_ended" );
	level notify( "reset_grnd_drops" );
	level endon( "reset_grnd_drops" );
	
	level.grnd_previousCrateTypes = [];
	
	while( true )
	{
		owner = getBestPlayer();			
		numIncomingVehicles = 1;
		if( isDefined( owner ) && level.numDropCrates < 8 )
		{
			owner thread maps\mp\gametypes\_rank::giveRankXP( "capture", 100 );
			owner thread maps\mp\gametypes\_mw3::underScorePopup("Приближается груз!!", (1, 1, 0.5), 0);
			// TODO
			//thread teamPlayerCardSplash( "callout_earned_carepackage", owner );			
			//owner thread leaderDialog( level.otherTeam[ owner.team ] + "_enemy_airdrop_assault_inbound", level.otherTeam[ owner.team ] );
			//owner thread leaderDialog( owner.team + "_friendly_airdrop_assault_inbound", owner.team );
			playSoundOnPlayers( "mp_war_objective_taken", owner.team );
			playSoundOnPlayers( "mp_war_objective_lost", level.otherTeam[owner.team] );			
			
			position = level.grnd_zone.origin + ( randomIntRange( (-1*GRND_ZONE_DROP_RADIUS), GRND_ZONE_DROP_RADIUS ), randomIntRange( (-1*GRND_ZONE_DROP_RADIUS), GRND_ZONE_DROP_RADIUS ), 0 );
		
			crateType = getDropZoneCrateType();
			if ( crateType == "mega" )
			{
				level thread maps\mp\killstreaks\_airdrop::doC130FlyBy( owner, position, randomFloat( 360 ), "airdrop" );
			}
			else
			{
				level thread maps\mp\killstreaks\_airdrop::doFlyBy( owner, position, randomFloat( 360 ), "airdrop", 0, crateType );
			}

			waitTime = level.matchRules_dropTime;
		}		
		else
		{
			waitTime = 0.5;
		}

		wait waitTime;
	}
}

getBestPlayer()
{		
	bestPlayer = undefined;
	bestPlayerPoints = 0;

	// find the player with the currently highest accumulated points in the zone
	foreach ( player in level.players )
	{
		if ( isAlive( player ) )
		{
			if ( distance2D( level.grnd_zone.origin, player.origin ) < GRND_ZONE_TOUCH_RADIUS && player.inGrindZonePoints > bestPlayerPoints )
			{
				bestPlayer = player;
				bestPlayerPoints = player.inGrindZonePoints;
			}
		}
	}	
	
	// may return undefined
	return bestPlayer;
}

getDropZoneCrateType()
{
	crateType = undefined;
	if ( !isDefined( level.grnd_previousCrateTypes["mega"] ) && level.numDropCrates == 0 && randomIntRange( 0, 100 ) < 5 )
	{
		crateType = "mega";
	}
	else
	{
		if ( level.grnd_previousCrateTypes.size )
		{
			maxTries = 200;
			while( maxTries )
			{
				crateType = maps\mp\killstreaks\_airdrop::getRandomCrateType( "airdrop" );				
				if ( isDefined( level.grnd_previousCrateTypes[crateType] ) )
					crateType = undefined;
				else
					break;
				
				maxTries--;
			}
		}
		
		if ( !isDefined( crateType ) )
			crateType = maps\mp\killstreaks\_airdrop::getRandomCrateType( "airdrop" );
	}
	
	// track it
	level.grnd_previousCrateTypes[crateType] = 1;	
	if ( level.grnd_previousCrateTypes.size == 15 )
		level.grnd_previousCrateTypes = [];
		
	return crateType;	
}

hideHudElementOnGameEnd( hudElement )
{
	level waittill("game_ended");
	hudElement.alpha = 0;
}

createZones()
{
	level.dropZones = [];
	
	// MW2 Drop Zones
	level.dropZones["mp_afghan"][0] = (117.338, -460.24, -40.867);
	level.dropZones["mp_afghan"][1] = (1288.73, 56.8669, -19.6298);
	level.dropZones["mp_afghan"][2] = (3083.92, 8.59047, 131.866);
	level.dropZones["mp_afghan"][3] = (3610.07, 1157.24, 92.5098);
	level.dropZones["mp_afghan"][4] = (1985.48, 495.555, -4.64144);
	level.dropZones["mp_afghan"][5] = (1272.57, 193.061, -11.6069);
	level.dropZones["mp_afghan"][6] = (1468.03, 1072.53, 47.999);
	level.dropZones["mp_afghan"][7] = (2465.28, 2068.83, 3.65806);
	level.dropZones["mp_afghan"][8] = (3721.11, 2451.97, -23.1472);
	level.dropZones["mp_afghan"][9] = (3460.5, 1625.55, 48.9016);
	level.dropZones["mp_afghan"][10] = (2851.8, 3547.1, 124.207);
	level.dropZones["mp_afghan"][11] = (1878.49, 2813.17, 334.455);
	level.dropZones["mp_afghan"][12] = (1340.12, 3731.96, 243.451);
	level.dropZones["mp_afghan"][13] = (440.343, 2436.96, 227.683);
	level.dropZones["mp_afghan"][14] = (-520.129, 1481.55, 187.967);
	level.dropZones["mp_afghan"][15] = (-360.224, 136.006, 33.4738);

	level.dropZones["mp_complex"][0] = (-2296.43, -2405.58, 672.125);
	level.dropZones["mp_complex"][1] = (-1742.09, -2042.05, 658.326);
	level.dropZones["mp_complex"][2] = (-907.796, -1700.49, 672.125);
	level.dropZones["mp_complex"][3] = (502.407, -2523.96, 672.125);
	level.dropZones["mp_complex"][4] = (903.411, -2261.24, 672.125);
	level.dropZones["mp_complex"][5] = (1641.51, -1647.79, 384.095);
	level.dropZones["mp_complex"][6] = (1487.02, -2650.25, 459.306);
	level.dropZones["mp_complex"][7] = (2026.04, -2802.17, 600.125);
	level.dropZones["mp_complex"][8] = (2208.44, -3083.36, 568.326);
	level.dropZones["mp_complex"][9] = (893.816, -2873.07, 548.236);
	level.dropZones["mp_complex"][10] = (-736.637, -3049.68, 648.125);
	level.dropZones["mp_complex"][11] = (-245.059, -3376.2, 648.125);

	level.dropZones["mp_abandon"][0] = (524.014, -1776.53, -63.1825);
	level.dropZones["mp_abandon"][1] = (1082.34, -2036.01, -64.9983);
	level.dropZones["mp_abandon"][2] = (1698.76, -2457.36, -12.9466);
	level.dropZones["mp_abandon"][3] = (2187.69, -1847.68, -47.931);
	level.dropZones["mp_abandon"][4] = (3060.84, -1916.83, -71.329);
	level.dropZones["mp_abandon"][5] = (3250.98, 673.104, -55.944);
	level.dropZones["mp_abandon"][6] = (2633.18, 1095.97, -61.7689);
	level.dropZones["mp_abandon"][7] = (2115.99, 2342.87, -63.875);
	level.dropZones["mp_abandon"][8] = (1734.72, 1261.4, -63.875);
	level.dropZones["mp_abandon"][9] = (500.22, 1283.58, -63.875);
	level.dropZones["mp_abandon"][10] = (94.384, 637.207, -67.875);
	level.dropZones["mp_abandon"][11] = (273.092, 28.3205, -67.875);
	level.dropZones["mp_abandon"][12] = (1356.94, -716.822, -67.875);
	level.dropZones["mp_abandon"][13] = (624.213, -1685.11, -63.9118);

	level.dropZones["mp_crash"][0] = (-358.047, 1612.61, 234.082);
	level.dropZones["mp_crash"][1] = (277.334, 950.261, 125.206);
	level.dropZones["mp_crash"][2] = (1048.92, 1230.78, 129.24);
	level.dropZones["mp_crash"][3] = (1214.15, 801.127, 141.592);
	level.dropZones["mp_crash"][4] = (1545.74, 90.9134, 123.821);
	level.dropZones["mp_crash"][5] = (951.181, -501.296, 94.3481);
	level.dropZones["mp_crash"][6] = (1574.11, -1196.24, 65.125);
	level.dropZones["mp_crash"][7] = (689.892, -1441.81, 63.4583);
	level.dropZones["mp_crash"][8] = (370.083, -1922.18, 120.079);
	level.dropZones["mp_crash"][9] = (-236.563, -1169.2, 75.9487);
	level.dropZones["mp_crash"][10] = (291.373, 81.0358, 130.5);

	level.dropZones["mp_derail"][0] = (1576.63, 4106.34, 212.101);
	level.dropZones["mp_derail"][1] = (687.306, 4159.84, 121.047);
	level.dropZones["mp_derail"][2] = (1297.93, 3096.53, 116.271);
	level.dropZones["mp_derail"][3] = (-98.2683, 3434.05, 124.857);
	level.dropZones["mp_derail"][4] = (-88.0703, 2689.5, 121.065);
	level.dropZones["mp_derail"][5] = (-538.135, 3027.77, 138.125);
	level.dropZones["mp_derail"][6] = (-1631.72, 3775.98, 183.012);
	level.dropZones["mp_derail"][7] = (-1209.66, 2790.94, 120.031);
	level.dropZones["mp_derail"][8] = (-1916.89, 1458.25, -18.2086);
	level.dropZones["mp_derail"][9] = (-864.765, 1051.18, -15.9631);
	level.dropZones["mp_derail"][10] = (-1610.28, -27.9166, -39.3281);
	level.dropZones["mp_derail"][11] = (-1682.8, -1199.08, 11.8185);
	level.dropZones["mp_derail"][12] = (-1581.02, -2488.13, 106.425);
	level.dropZones["mp_derail"][13] = (-1029.39, -3065.11, 99.4903);
	level.dropZones["mp_derail"][14] = (-216.71, -2935.28, 88.6071);
	level.dropZones["mp_derail"][15] = (888.318, -2854.25, 126.632);
	level.dropZones["mp_derail"][16] = (1875, -2684.32, 39.7591);
	level.dropZones["mp_derail"][17] = (1828.29, -1517.89, 75.6948);
	level.dropZones["mp_derail"][18] = (1334.19, -1398.01, 76.2062);
	level.dropZones["mp_derail"][19] = (2212.35, 42.9167, -15.875);
	level.dropZones["mp_derail"][20] = (3214.94, 1089.46, 125.06);
	level.dropZones["mp_derail"][21] = (3003.02, 3505.66, 39.5764);
	level.dropZones["mp_derail"][22] = (1850.69, 3606.8, 173.049);
	level.dropZones["mp_derail"][23] = (833.755, 1367.12, 111.649);
	level.dropZones["mp_derail"][24] = (900.291, 744.522, 61.1975);
	level.dropZones["mp_derail"][25] = (539.479, -243.707, -15.875);
	level.dropZones["mp_derail"][26] = (1312.24, -324.12, 128.341);

	level.dropZones["mp_estate"][0] = (1679.97, 121.091, 59.5909);
	level.dropZones["mp_estate"][1] = (1268.29, 650.235, 48.7306);
	level.dropZones["mp_estate"][2] = (1000.35, -198.793, 57.5225);
	level.dropZones["mp_estate"][3] = (325.273, -242.239, 98.9586);
	level.dropZones["mp_estate"][4] = (-417.978, 161.768, 77.9252);
	level.dropZones["mp_estate"][5] = (-1156.54, 20.2593, -71.7926);
	level.dropZones["mp_estate"][6] = (-1833.86, 874.161, -326.884);
	level.dropZones["mp_estate"][7] = (-1598.26, 1643.91, -250.852);
	level.dropZones["mp_estate"][8] = (-2466.59, 1608.17, -305.454);
	level.dropZones["mp_estate"][9] = (-3328.65, 94.3842, -305.615);
	level.dropZones["mp_estate"][10] = (-4495.26, 2985.2, -307.719);
	level.dropZones["mp_estate"][11] = (-3425.38, 3746.47, -297.228);
	level.dropZones["mp_estate"][12] = (-626.87, 2262.16, -110.424);
	level.dropZones["mp_estate"][13] = (144.167, 4031.83, 154.289);
	level.dropZones["mp_estate"][14] = (623.379, 3471.5, 148.976);
	level.dropZones["mp_estate"][15] = (1712.24, 3315.9, 102.421);
	level.dropZones["mp_estate"][16] = (748.751, 1695.27, 133.598);

	level.dropZones["mp_favela"][0] = (471.785, 2741.19, 287.708);
	level.dropZones["mp_favela"][1] = (-433.961, 2221.86, 281.316);
	level.dropZones["mp_favela"][2] = (-1058.17, 2168.93, 280.001);
	level.dropZones["mp_favela"][3] = (-926.963, 1349.36, 87.6624);
	level.dropZones["mp_favela"][4] = (-1273.45, 685.824, 8.125);
	level.dropZones["mp_favela"][5] = (-1472.75, -3.17477, 8.125);
	level.dropZones["mp_favela"][6] = (-466.179, -73.6516, -3.10529);
	level.dropZones["mp_favela"][7] = (-603.599, -762.528, 17.5112);
	level.dropZones["mp_favela"][8] = (276.405, -1038.96, 2.125);
	level.dropZones["mp_favela"][9] = (1109.3, -728.669, 186.125);
	level.dropZones["mp_favela"][10] = (1164.39, 9.83376, 186.125);
	level.dropZones["mp_favela"][11] = (1171.25, 693.774, 196.125);
	level.dropZones["mp_favela"][12] = (1269.25, 1344.33, 184.127);
	level.dropZones["mp_favela"][13] = (855.802, 1672.1, 167.967);
	level.dropZones["mp_favela"][14] = (198.233, 2006.39, 240.125);
	level.dropZones["mp_favela"][15] = (109.289, -55.9644, -5.875);

	level.dropZones["mp_highrise"][0] = (-238.862, 7244.42, 2776.13);
	level.dropZones["mp_highrise"][1] = (-383.763, 6500.03, 2776.13);
	level.dropZones["mp_highrise"][2] = (-581.02, 5671.64, 2776.13);
	level.dropZones["mp_highrise"][3] = (-876.583, 6429.86, 2776.13);
	level.dropZones["mp_highrise"][4] = (-1827.51, 5676.01, 2776.13);
	level.dropZones["mp_highrise"][5] = (-2346.89, 5617.27, 2776.13);
	level.dropZones["mp_highrise"][6] = (-2419.92, 6393.53, 2776.13);
	level.dropZones["mp_highrise"][7] = (-1953.67, 6412.83, 2776.13);
	level.dropZones["mp_highrise"][8] = (-2485.09, 6996, 2776.13);
	level.dropZones["mp_highrise"][9] = (-985.413, 7278.28, 2776.13);
	level.dropZones["mp_highrise"][10] = (-2030.12, 6135.71, 2776.13);

	level.dropZones["mp_invasion"][0] = (-578.893, 485.462, 248.125);
	level.dropZones["mp_invasion"][1] = (-725.125, -724.466, 260.728);
	level.dropZones["mp_invasion"][2] = (-1678.29, -1042.69, 250.266);
	level.dropZones["mp_invasion"][3] = (-2767.43, -856.393, 264.125);
	level.dropZones["mp_invasion"][4] = (-2877.88, -1639.64, 264.125);
	level.dropZones["mp_invasion"][5] = (-2310.46, -2622.74, 264.125);
	level.dropZones["mp_invasion"][6] = (-3425.57, -2556.11, 256.125);
	level.dropZones["mp_invasion"][7] = (-2795.36, -3345.05, 266.687);
	level.dropZones["mp_invasion"][8] = (-1686.31, -2379.19, 256.125);
	level.dropZones["mp_invasion"][9] = (-632.171, -3190.3, 248.539);
	level.dropZones["mp_invasion"][10] = (391.25, -3333.44, 239.552);
	level.dropZones["mp_invasion"][11] = (467.697, -2821.57, 246.395);
	level.dropZones["mp_invasion"][12] = (1302.03, -2279.54, 288.125);
	level.dropZones["mp_invasion"][13] = (1691.34, -1900.87, 288.125);
	level.dropZones["mp_invasion"][14] = (678.551, -1428.68, 288.106);
	level.dropZones["mp_invasion"][15] = (-318.012, -1769.72, 264.125);
	level.dropZones["mp_invasion"][16] = (116.846, -588.041, 266.908);

	level.dropZones["mp_fuel2"][0] = (-1047.14, 2834.49, -148.042);
	level.dropZones["mp_fuel2"][1] = (-1895.29, 1680.91, -143.875);
	level.dropZones["mp_fuel2"][2] = (-875.419, 1436.13, -175.343);
	level.dropZones["mp_fuel2"][3] = (-867.087, 889.723, -72.246);
	level.dropZones["mp_fuel2"][4] = (9.74682, 783.054, 0.124997);
	level.dropZones["mp_fuel2"][5] = (3.73035, 38.0266, 0.124998);
	level.dropZones["mp_fuel2"][6] = (19.6001, -704.985, 0.124997);
	level.dropZones["mp_fuel2"][7] = (-563.963, -718.458, -11.9662);
	level.dropZones["mp_fuel2"][8] = (-793.297, -1440.26, -127.875);
	level.dropZones["mp_fuel2"][9] = (-1085.26, -2277.69, -250.489);
	level.dropZones["mp_fuel2"][10] = (-69.7957, -2395.99, -255.875);
	level.dropZones["mp_fuel2"][11] = (1205.44, -2143.18, -255.875);
	level.dropZones["mp_fuel2"][12] = (1624.4, -2060.76, -203.791);
	level.dropZones["mp_fuel2"][13] = (2430.07, -1297.23, -193.636);
	level.dropZones["mp_fuel2"][14] = (2551.54, -109.02, -176.61);
	level.dropZones["mp_fuel2"][15] = (2219.88, 1137.78, -160.875);
	level.dropZones["mp_fuel2"][16] = (1260.5, 2840.58, -188.861);
	level.dropZones["mp_fuel2"][17] = (2749.95, 2313.59, -180.318);
	level.dropZones["mp_fuel2"][18] = (594.622, 1710.49, -191.875);
	level.dropZones["mp_fuel2"][19] = (-1920.56, 1679.52, -143.894);

	level.dropZones["mp_checkpoint"][0] = (-748.012, 2136.32, 0.500999);
	level.dropZones["mp_checkpoint"][1] = (-294.191, 1443.72, 48.1252);
	level.dropZones["mp_checkpoint"][2] = (473.807, 2164.89, -4.04511);
	level.dropZones["mp_checkpoint"][3] = (-362.915, 2119.99, -1.72446);
	level.dropZones["mp_checkpoint"][4] = (1201.46, 756.61, 0.124998);
	level.dropZones["mp_checkpoint"][5] = (1915.41, 517.161, 0.124999);
	level.dropZones["mp_checkpoint"][6] = (1560.5, -582.721, 4.3744);
	level.dropZones["mp_checkpoint"][7] = (1398.74, -953.55, 1.8437);
	level.dropZones["mp_checkpoint"][8] = (252.058, -1060.66, 0.124998);
	level.dropZones["mp_checkpoint"][9] = (319.447, -3111.42, 6.62059);
	level.dropZones["mp_checkpoint"][10] = (-58.4231, -2684.51, 0.126436);
	level.dropZones["mp_checkpoint"][11] = (342.826, -2254.34, 19.8267);
	level.dropZones["mp_checkpoint"][12] = (-591.131, -2166.58, 0.147712);
	level.dropZones["mp_checkpoint"][13] = (-622.95, -1708.91, 0.336198);
	level.dropZones["mp_checkpoint"][14] = (-175.042, -1081.16, 0.124997);
	level.dropZones["mp_checkpoint"][15] = (-1572.03, -1059.71, 0.125001);
	level.dropZones["mp_checkpoint"][16] = (-2113.48, 114.397, 0.125);
	level.dropZones["mp_checkpoint"][17] = (-1084.13, 114.754, 0.124997);
	level.dropZones["mp_checkpoint"][18] = (155.857, 110.422, 35.3885);

	level.dropZones["mp_overgrown"][0] = (-1332.22, -4918.14, -147.42);
	level.dropZones["mp_overgrown"][1] = (-792.349, -4784.37, -163.332);
	level.dropZones["mp_overgrown"][2] = (-105.576, -5119.57, -274.167);
	level.dropZones["mp_overgrown"][3] = (123.867, -4363.94, -280.986);
	level.dropZones["mp_overgrown"][4] = (781.919, -4405.25, -188.808);
	level.dropZones["mp_overgrown"][5] = (1307.98, -3731.01, -129.258);
	level.dropZones["mp_overgrown"][6] = (2238.84, -3634.67, -175.875);
	level.dropZones["mp_overgrown"][7] = (2203.85, -2911.38, -177.54);
	level.dropZones["mp_overgrown"][8] = (1525.39, -2009.28, -187.324);
	level.dropZones["mp_overgrown"][9] = (2326.71, -2219.01, -175.685);
	level.dropZones["mp_overgrown"][10] = (2212.51, -1671.49, -201.129);
	level.dropZones["mp_overgrown"][11] = (2197.16, -517.854, -143.335);
	level.dropZones["mp_overgrown"][12] = (1268.51, -79.2441, -309.947);
	level.dropZones["mp_overgrown"][13] = (1044.53, -1629.37, -351.736);
	level.dropZones["mp_overgrown"][14] = (364.851, -2375.38, -323.256);
	level.dropZones["mp_overgrown"][15] = (119.551, -3473.92, -296.631);
	level.dropZones["mp_overgrown"][16] = (-1379.36, -4398.07, -127.303);
	level.dropZones["mp_overgrown"][17] = (-1315.31, -3510.99, -128.042);
	level.dropZones["mp_overgrown"][18] = (-827.809, -2794.69, -193.822);
	level.dropZones["mp_overgrown"][19] = (-1109.41, -2341, -189.798);
	level.dropZones["mp_overgrown"][20] = (-641.145, -1472.71, -189.447);
	level.dropZones["mp_overgrown"][21] = (-6.08065, -1620.12, -183.875);
	level.dropZones["mp_overgrown"][22] = (-66.6476, -825.381, -183.875);
	level.dropZones["mp_overgrown"][23] = (-222.551, -172.611, -179.707);
	level.dropZones["mp_overgrown"][24] = (450.562, 455.598, -176.899);
	level.dropZones["mp_overgrown"][25] = (507.75, -362.501, -177.991);
	  
	level.dropZones["mp_quarry"][0] = (-5276.54, -1600.86, -193.601);
	level.dropZones["mp_quarry"][1] = (-5354.61, -810.865, -192.703);
	level.dropZones["mp_quarry"][2] = (-5379.31, -118.606, -206.733);
	level.dropZones["mp_quarry"][3] = (-5246.6, 459.418, -197.35);
	level.dropZones["mp_quarry"][4] = (-5049.6, 2146.92, 80.125);
	level.dropZones["mp_quarry"][5] = (-4048.65, 2121.26, 5.61493);
	level.dropZones["mp_quarry"][6] = (-3221.63, 2162.75, 22.1948);
	level.dropZones["mp_quarry"][7] = (-3219.86, 2889.65, 15.7006);
	level.dropZones["mp_quarry"][8] = (-2205.87, 2743.07, 66.7044);
	level.dropZones["mp_quarry"][9] = (-2275.27, 1514.65, 17.3541);
	level.dropZones["mp_quarry"][10] = (-1918.73, 411.724, -7.95859);
	level.dropZones["mp_quarry"][11] = (-2283.04, -241.974, -47.9706);
	level.dropZones["mp_quarry"][12] = (-2843.64, -1040.13, -102.1);
	level.dropZones["mp_quarry"][13] = (-3481.18, -1329.64, -122.508);
	level.dropZones["mp_quarry"][14] = (-3805.19, -511.11, -175.225);
	level.dropZones["mp_quarry"][15] = (-4721.77, -761.886, -157.808);
	level.dropZones["mp_quarry"][16] = (-3917.89, 598.619, -322.23);
	level.dropZones["mp_quarry"][17] = (-3090.08, 206.594, -279.805);

	level.dropZones["mp_rundown"][0] = (2440.11, -3059.03, 203.345);
	level.dropZones["mp_rundown"][1] = (2591.58, -2067.64, 192.539);
	level.dropZones["mp_rundown"][2] = (1698.09, -1857.54, 189.237);
	level.dropZones["mp_rundown"][3] = (1421.9, -2792.37, 192.125);
	level.dropZones["mp_rundown"][4] = (22.0316, -2609.6, 98.2543);
	level.dropZones["mp_rundown"][5] = (445.049, -2169.06, 109.739);
	level.dropZones["mp_rundown"][6] = (-257.588, -2085.71, 30.5926);
	level.dropZones["mp_rundown"][7] = (-265.713, -1119.36, 16.0508);
	level.dropZones["mp_rundown"][8] = (-1150.66, -418.834, 8.13965);
	level.dropZones["mp_rundown"][9] = (-1983.03, -308.157, 25.0869);
	level.dropZones["mp_rundown"][10] = (-1060.88, 881.446, 13.6751);
	level.dropZones["mp_rundown"][11] = (-520.138, 346.676, 24.4814);
	level.dropZones["mp_rundown"][12] = (217.137, 658.458, 18.6903);
	level.dropZones["mp_rundown"][13] = (961.279, 981.803, 15.1271);
	level.dropZones["mp_rundown"][14] = (1771.69, 1808.09, -91.8275);
	level.dropZones["mp_rundown"][15] = (1612.56, 751.608, -1.86562);
	level.dropZones["mp_rundown"][16] = (1014.11, 3227.24, 64.125);
	level.dropZones["mp_rundown"][17] = (655.52, 2360.54, 70.4625);
	level.dropZones["mp_rundown"][18] = (490.404, -529.977, 10.2182);

	level.dropZones["mp_rust"][0] = (-294.093, -135.073, -238.467);
	level.dropZones["mp_rust"][1] = (46.0205, 183.173, -247.875);
	level.dropZones["mp_rust"][2] = (675.216, 218.007, -243.529);
	level.dropZones["mp_rust"][3] = (1049.65, 355.724, -240.893);
	level.dropZones["mp_rust"][4] = (1281.95, 899.31, -232.575);
	level.dropZones["mp_rust"][5] = (413.69, 1298.84, -238.727);
	level.dropZones["mp_rust"][6] = (-80.0613, 959.324, -241.993);
	level.dropZones["mp_rust"][7] = (1509.93, 282.273, -239.782);

	level.dropZones["mp_compact"][0] = (1313.95, -1118.28, -3.88086);
	level.dropZones["mp_compact"][1] = (1358.13, -130.759, -3.57603);
	level.dropZones["mp_compact"][2] = (1734.59, 71.7187, 9.18784);
	level.dropZones["mp_compact"][3] = (1813.86, 1352.91, -15.1049);
	level.dropZones["mp_compact"][4] = (2551.39, 1725.27, 3.16682);
	level.dropZones["mp_compact"][5] = (2937.87, 2033.3, -6.87949);
	level.dropZones["mp_compact"][6] = (2300.16, 3066.61, 40.2807);
	level.dropZones["mp_compact"][7] = (1847.7, 2974.9, 41.1664);
	level.dropZones["mp_compact"][8] = (1019.2, 2202.23, 48.1731);
	level.dropZones["mp_compact"][9] = (487.279, 2255.42, 48.981);
	level.dropZones["mp_compact"][10] = (403.037, 1547.82, 34.3888);
	level.dropZones["mp_compact"][11] = (528.592, 937.109, 5.05536);
	level.dropZones["mp_compact"][12] = (315.904, 166.21, 9.07175);
	level.dropZones["mp_compact"][13] = (2734.85, 977.24, -5.61341);

	level.dropZones["mp_boneyard"][0] = (-1477.81, 1286.14, -135.585);
	level.dropZones["mp_boneyard"][1] = (-984.346, 934.055, -136.99);
	level.dropZones["mp_boneyard"][2] = (-616.675, 1390.44, -112.529);
	level.dropZones["mp_boneyard"][3] = (699.153, 820.408, -135.777);
	level.dropZones["mp_boneyard"][4] = (713.377, 449.576, -119.874);
	level.dropZones["mp_boneyard"][5] = (717.622, -36.5019, -138.165);
	level.dropZones["mp_boneyard"][6] = (22.8997, -358.35, -139.875);
	level.dropZones["mp_boneyard"][7] = (-688.486, -111.806, -139.875);
	level.dropZones["mp_boneyard"][8] = (-699.956, -445.906, -139.875);
	level.dropZones["mp_boneyard"][9] = (-761.527, -517.726, -139.875);
	level.dropZones["mp_boneyard"][10] = (-1321.69, -551.025, -127.434);
	level.dropZones["mp_boneyard"][11] = (-553.684, 374.262, -122.378);
	level.dropZones["mp_boneyard"][12] = (1123.28, 331.367, -163.151);
	level.dropZones["mp_boneyard"][13] = (1563.71, -362.076, -152.937);
	level.dropZones["mp_boneyard"][14] = (1803.13, -207.962, -185.98);
	level.dropZones["mp_boneyard"][15] = (1858.14, 1323.58, -85.9334);
	level.dropZones["mp_boneyard"][16] = (-311.783, 935.103, -135.877);

	level.dropZones["mp_nightshift"][0] = (-1750.96, -2010.52, -11.875);
	level.dropZones["mp_nightshift"][1] = (-1796.48, -1248.27, -11.875);
	level.dropZones["mp_nightshift"][2] = (-1246.91, -1069.35, -11.9759);
	level.dropZones["mp_nightshift"][3] = (-1685.2, -664.435, -10.8346);
	level.dropZones["mp_nightshift"][4] = (-1216.23, -294.944, -11.875);
	level.dropZones["mp_nightshift"][5] = (357.547, -1406.76, -7.875);
	level.dropZones["mp_nightshift"][6] = (1257.95, -1163.67, -7.875);
	level.dropZones["mp_nightshift"][7] = (1230.52, -572.303, 0.125);
	level.dropZones["mp_nightshift"][8] = (1624.34, -212.613, 0.125);
	level.dropZones["mp_nightshift"][9] = (1253.63, 64.4525, -7.875);
	level.dropZones["mp_nightshift"][10] = (314.801, 87.7069, 0.124998);
	level.dropZones["mp_nightshift"][11] = (-797.663, 844.989, 80.125);
	level.dropZones["mp_nightshift"][12] = (-934.477, -1896.24, 0.125002);

	level.dropZones["mp_storm"][0] = (-1052.33, 1762.11, 151.301);
	level.dropZones["mp_storm"][1] = (-1015.64, 1120.69, -7.875);
	level.dropZones["mp_storm"][2] = (-787.261, 648.313, -7.35107);
	level.dropZones["mp_storm"][3] = (-1319.34, 293.744, -7.93533);
	level.dropZones["mp_storm"][4] = (-1947.66, -244.55, -14.6772);
	level.dropZones["mp_storm"][5] = (-1285.47, -559.303, -7.875);
	level.dropZones["mp_storm"][6] = (-1736.11, -1317.99, -8.36085);
	level.dropZones["mp_storm"][7] = (205.231, -1867.69, -7.875);
	level.dropZones["mp_storm"][8] = (255.93, -1228.34, -7.875);
	level.dropZones["mp_storm"][9] = (-206.76, -923.863, -6.875);
	level.dropZones["mp_storm"][10] = (817.755, -1888.15, -7.875);
	level.dropZones["mp_storm"][11] = (920.291, -1264.48, -7.875);
	level.dropZones["mp_storm"][12] = (1545.93, -1182.04, -67.3653);
	level.dropZones["mp_storm"][13] = (1489.62, -67.4184, -63.875);
	level.dropZones["mp_storm"][14] = (1347.59, 852.586, -7.875);
	level.dropZones["mp_storm"][15] = (386.845, 691.089, -7.875);

	level.dropZones["mp_strike"][0] = (-867.602, -2882.35, 213.797);
	level.dropZones["mp_strike"][1] = (-1351.86, -2238.81, 208.125);
	level.dropZones["mp_strike"][2] = (-876.113, -2058.06, 210.735);
	level.dropZones["mp_strike"][3] = (-966.124, -1291.76, 84.7795);
	level.dropZones["mp_strike"][4] = (-1117.68, -416.019, 12.125);
	level.dropZones["mp_strike"][5] = (-607.46, -135.706, 8.125);
	level.dropZones["mp_strike"][6] = (297.674, -100.332, -6.20005);
	level.dropZones["mp_strike"][7] = (816.82, -876.829, 8.125);
	level.dropZones["mp_strike"][8] = (1987.54, -867.026, 12.125);
	level.dropZones["mp_strike"][9] = (1554.96, 432.915, 16.125);
	level.dropZones["mp_strike"][10] = (1509.93, 1230.27, 11.0519);
	level.dropZones["mp_strike"][11] = (1663.9, 1717.98, 16.125);
	level.dropZones["mp_strike"][12] = (2119.95, 2412.18, 16.125);
	level.dropZones["mp_strike"][13] = (2867.56, 2573.83, 19.0824);
	level.dropZones["mp_strike"][15] = (-212.839, 1029.07, 16.125);
	level.dropZones["mp_strike"][16] = (-644.174, -35.8806, 8.08052);
	level.dropZones["mp_strike"][17] = (-895.581, -1290.88, 86.5456);
	level.dropZones["mp_strike"][18] = (-1131.31, 1508.3, 24.125);
}