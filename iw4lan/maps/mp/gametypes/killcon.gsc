#include maps\mp\_utility;
#include maps\mp\gametypes\_hud_util;
/*
	Kill Confirmed
	Objective: 	Score points for your team by eliminating players on the opposing team and collecting their dogtags
	Map ends:	When one team reaches the score limit, or time limit is reached
	Respawning:	No wait / Near teammates

	Level requirementss
	------------------
		Spawnpoints:
			classname		mp_tdm_spawn
			All players spawn from these. The spawnpoint chosen is dependent on the current locations of teammates and enemies
			at the time of spawn. Players generally spawn behind their teammates relative to the direction of enemies.

		Spectator Spawnpoints:
			classname		mp_global_intermission
			Spectators spawn from these and intermission is viewed from these positions.
			Atleast one is required, any more and they are randomly chosen between.
*/

/*QUAKED mp_tdm_spawn (0.0 0.0 1.0) (-16 -16 0) (16 16 72)
Players spawn away from enemies and near their team at one of these positions.*/

/*QUAKED mp_tdm_spawn_axis_start (0.5 0.0 1.0) (-16 -16 0) (16 16 72)
Axis players spawn away from enemies and near their team at one of these positions at the start of a round.*/

/*QUAKED mp_tdm_spawn_allies_start (0.0 0.5 1.0) (-16 -16 0) (16 16 72)
Allied players spawn away from enemies and near their team at one of these positions at the start of a round.*/

/*
	Title:		'Kill Confirmed' Game Mode
	Notes: 		-
	Version: 	1.2
	Author: 	NoFaTe
*/

main()
{
	if(getdvar("mapname") == "mp_background")
		return;
	
	maps\mp\gametypes\_globallogic::init();
	maps\mp\gametypes\_callbacksetup::SetupCallbacks();
	maps\mp\gametypes\_globallogic::SetupCallbacks();

	SetDvarIfUninitialized("scr_" + level.gameType + "_timelimit", 10);
	SetDvarIfUninitialized("scr_" + level.gameType + "_scorelimit", 40);
	SetDvarIfUninitialized("scr_" + level.gameType + "_roundlimit", 1);
	SetDvarIfUninitialized("scr_" + level.gameType + "_winlimit", 1);
	SetDvarIfUninitialized("scr_" + level.gameType + "_roundswitch", 1);
	SetDvarIfUninitialized("scr_" + level.gameType + "_numlives", 0);
	SetDvarIfUninitialized("scr_" + level.gameType + "_halftime", 0);
	
	registerTimeLimitDvar( level.gameType, 10, 0, 1440 );
	registerScoreLimitDvar( level.gameType, 40, 0, 20000 );
	registerRoundLimitDvar( level.gameType, 1, 0, 30 );
	registerWinLimitDvar( level.gameType, 1, 0, 10 );
	registerRoundSwitchDvar( level.gameType, 1, 0, 30 );
	registerNumLivesDvar( level.gameType, 0, 0, 10 );
	registerHalfTimeDvar( level.gameType, 0, 0, 1 );

	level.teamBased = true;
	level.onStartGameType = ::onStartGameType;
	level.getSpawnPoint = ::getSpawnPoint;
	level.onNormalDeath2 = ::onNormalDeath2;

	game["dialog"]["gametype"] = "killcon";
	
	if ( getDvarInt( "g_hardcore" ) )
		game["dialog"]["gametype"] = "hc_" + game["dialog"]["gametype"];
	else if ( getDvarInt( "camera_thirdPerson" ) )
		game["dialog"]["gametype"] = "thirdp_" + game["dialog"]["gametype"];
	else if ( getDvarInt( "scr_diehard" ) )
		game["dialog"]["gametype"] = "dh_" + game["dialog"]["gametype"];
	else if (getDvarInt( "scr_" + level.gameType + "_promode" ) )
		game["dialog"]["gametype"] = game["dialog"]["gametype"] + "_pro";
	
	game["strings"]["overtime_hint"] = &"MP_FIRST_BLOOD";
	
	level thread onPlayerConnect();
}

onPlayerConnect()
{
	for ( ;; )
	{
		level waittill( "connected", player );
		player thread maps\mp\gametypes\_mw3::initMW3HUD();
		player thread onJoinedTeam();
	}
}

onJoinedTeam()
{
	self endon("disconnect");

	for(;;)
	{
		self waittill( "joined_team" );
		self thread onPlayerSpawned();
	}
}

onPlayerSpawned()
{
	self endon("disconnect");

	for(;;)
	{
		self waittill("spawned_player");
		self thread maps\mp\gametypes\_mw3::resetKillstreakHUD();
	}
}

onStartGameType()
{
	setClientNameMode("auto_change");

	if ( !isdefined( game["switchedsides"] ) )
		game["switchedsides"] = false;

	if ( game["switchedsides"] )
	{
		oldAttackers = game["attackers"];
		oldDefenders = game["defenders"];
		game["attackers"] = oldDefenders;
		game["defenders"] = oldAttackers;
	}

	// TODO: Change objective text
	setObjectiveText( "allies", &"OBJECTIVES_WAR" );
	setObjectiveText( "axis", &"OBJECTIVES_WAR" );
	
	if ( level.splitscreen )
	{
		setObjectiveScoreText( "allies", &"OBJECTIVES_WAR" );
		setObjectiveScoreText( "axis", &"OBJECTIVES_WAR" );
	}
	else
	{
		setObjectiveScoreText( "allies", &"OBJECTIVES_WAR_SCORE" );
		setObjectiveScoreText( "axis", &"OBJECTIVES_WAR_SCORE" );
	}
	setObjectiveHintText( "allies", &"OBJECTIVES_WAR_HINT" );
	setObjectiveHintText( "axis", &"OBJECTIVES_WAR_HINT" );

	level.spawnMins = ( 0, 0, 0 );
	level.spawnMaxs = ( 0, 0, 0 );	
	maps\mp\gametypes\_spawnlogic::placeSpawnPoints( "mp_tdm_spawn_allies_start" );
	maps\mp\gametypes\_spawnlogic::placeSpawnPoints( "mp_tdm_spawn_axis_start" );
	maps\mp\gametypes\_spawnlogic::addSpawnPoints( "allies", "mp_tdm_spawn" );
	maps\mp\gametypes\_spawnlogic::addSpawnPoints( "axis", "mp_tdm_spawn" );
	
	level.mapCenter = maps\mp\gametypes\_spawnlogic::findBoxCenter( level.spawnMins, level.spawnMaxs );
	setMapCenter( level.mapCenter );
	
	allowed[0] = level.gameType;
	allowed[1] = "airdrop_pallet";
	
	maps\mp\gametypes\_gameobjects::main(allowed);	
	level thread maps\mp\gametypes\_mw3::initMW3Killstreaks();
}


getSpawnPoint()
{
	spawnteam = self.pers["team"];
	if ( game["switchedsides"] )
		spawnteam = getOtherTeam( spawnteam );

	if ( level.inGracePeriod )
	{
		spawnPoints = maps\mp\gametypes\_spawnlogic::getSpawnpointArray( "mp_tdm_spawn_" + spawnteam + "_start" );
		spawnPoint = maps\mp\gametypes\_spawnlogic::getSpawnpoint_Random( spawnPoints );
	}
	else
	{
		spawnPoints = maps\mp\gametypes\_spawnlogic::getTeamSpawnPoints( spawnteam );
		spawnPoint = maps\mp\gametypes\_spawnlogic::getSpawnpoint_NearTeam( spawnPoints );
	}
	
	return spawnPoint;
}

onNormalDeath2( victim, attacker, sMeansOfDeath )
{
	if (sMeansOfDeath == "MOD_MELEE")
	{
		// Melee kill is insta-confirm
		attacker thread maps\mp\gametypes\_rank::giveRankXP( "kconfrm", 50 );
		attacker thread maps\mp\gametypes\_mw3::underScorePopup("Kill Confirmed!", (1, 1, 0.5), 0);
		attacker maps\mp\gametypes\_gamescore::giveTeamScoreForObjective( attacker.pers["team"], 1 );
		attacker thread maps\mp\gametypes\_mw3::saySound(level.bcSounds["kill"]);
		attacker.pers["cur_kill_streak"]++;
		level notify ( "player_got_killstreak_" + attacker.pers["cur_kill_streak"], attacker );
		if ( isAlive( attacker ) )
			attacker thread maps\mp\killstreaks\_killstreaks::checkKillstreakReward( attacker.pers["cur_kill_streak"] );
	}
	else
	{
		// Create a dogtag
		victim initDogTag(attacker);
	}
}

onTimeLimit()
{
	if ( game["status"] == "overtime" )
	{
		winner = "forfeit";
	}
	else if ( game["teamScores"]["allies"] == game["teamScores"]["axis"] )
	{
		winner = "overtime";
	}
	else if ( game["teamScores"]["axis"] > game["teamScores"]["allies"] )
	{
		winner = "axis";
	}
	else
	{
		winner = "allies";
	}
	
	thread maps\mp\gametypes\_gamelogic::endGame( winner, game["strings"]["time_limit_reached"] );
}

killDogTag(dogTag)
{
	// Delete the dogTag model
	dogTag.isSpawned = false;
	dogTag.m01 delete();
	dogTag.m02 delete();
}

timeoutDogTag(dogTag)
{
	wait 30.0;
	dogTag killDogTag(dogTag);
}

watchDogTag(dogTag) 
{
	wait 0.25;

	// Watch for players getting near the dog tag
	while(dogTag.isSpawned)
	{
		foreach(player in level.players)
		{
			if (!isAlive(player))
				continue;

			isOverDogTag = (distanceSquared(player getOrigin(), dogTag.org + (0,0,10)) < 1000);

			if(!isOverDogTag)
				continue;
			
			// Notify-reward the player
			if (player == dogTag.owner)
			{
				player thread maps\mp\gametypes\_rank::giveRankXP( "gottags", 100 );
				player thread maps\mp\gametypes\_mw3::underScorePopup("Got Your Tags!", (1, 1, 0.5), 0);
				player thread maps\mp\gametypes\_mw3::saySound(level.bcSounds["casualty"]);
			}
			else if (player.team == dogTag.team)
			{
				player thread maps\mp\gametypes\_rank::giveRankXP( "kdenied", 50 );
				player thread maps\mp\gametypes\_mw3::underScorePopup("Kill Denied!", (1,0.5,0.5), 0);
				player thread maps\mp\gametypes\_mw3::saySound(level.bcSounds["casualty"]);
				
				dogTag.owner thread maps\mp\gametypes\_rank::giveRankXP( "kdenied", 50 );
				dogTag.owner thread maps\mp\gametypes\_mw3::underScorePopup("Kill Denied!", (1,0.5,0.5), 0);
			}
			else
			{
				player thread maps\mp\gametypes\_rank::giveRankXP( "kconfrm", 50 );
				player thread maps\mp\gametypes\_mw3::underScorePopup("Kill Confirmed!", (1, 1, 0.5), 0);
				player maps\mp\gametypes\_gamescore::giveTeamScoreForObjective( player.pers["team"], 1 );
				player thread maps\mp\gametypes\_mw3::saySound(level.bcSounds["kill"]);
				
				if (player != dogTag.player)
				{
					dogTag.player thread maps\mp\gametypes\_rank::giveRankXP( "kconfrm", 50 );
					dogTag.player thread maps\mp\gametypes\_mw3::underScorePopup("Kill Confirmed!", (1, 1, 0.5), 0);
				}
			}
			
			if (dogTag.player == player)
			{
				// Increment the player's killstreak
				player.pers["cur_kill_streak"]++;
				level notify ( "player_got_killstreak_" + player.pers["cur_kill_streak"], player );
				if ( isAlive( player ) )
					player thread maps\mp\killstreaks\_killstreaks::checkKillstreakReward( player.pers["cur_kill_streak"] );
			}
			
			// Destroy the dog tag
			dogTag killDogTag(dogTag);
		}
		
		wait 0.05;
	}
}

animateDogTagsMovement(dogTag) 
{
	// Move the dog tag up and down
	while(dogTag.isSpawned)
	{
		if (dogTag.state == 0)
		{
			dogTag.m01 MoveZ(15, 0.75);
			dogTag.m02 MoveZ(15, 0.75);
			dogTag.state = 1;
		}
		else
		{
			dogTag.m01 MoveZ(-15, 0.75);
			dogTag.m02 MoveZ(-15, 0.75);
			dogTag.state = 0;
		}
		wait 0.75;
	}
}

animateDogTagsRotation(dogTag) 
{
	// Rotate the dog tag
	while(dogTag.isSpawned)
	{
		dogTag.m01 RotateYaw(180, 0.5);
		dogTag.m02 RotateYaw(180, 0.5);
		wait 0.5;
	}
}

initDogTag(attacker)
{
	// Init the dog tag struct
	dogTag = spawnStruct();
	
	// Set the required vars
	dogTag.owner = self;
	dogTag.team = self.team;
	dogTag.player = attacker;
	dogTag.weapon = "";
	dogTag.org = self getOrigin();
	dogTag.state = 0;
	dogTag.isSpawned = true;
	
	// Set a weapon model based on the player's team
	if (dogTag.team == "axis")
		dogTag.weapon = "ak47_mp";
	else
		dogTag.weapon = "m16_mp";
		
	// Spawn the script_model and set its model
	dogTag.m01 = spawn("script_model", dogTag.org + (0,0,30));
	dogTag.m02 = spawn("script_model", dogTag.org + (0,0,30));
	dogTag.m01 setModel(GetWeaponModel(dogTag.weapon));
	dogTag.m02 setModel(GetWeaponModel(dogTag.weapon));

	// Hide all attachments
	tags = GetWeaponHideTags(dogTag.weapon);
	attachments = GetArrayKeys(tags);
	foreach(attachment in attachments) 
	{
		dogTag.m01 HidePart(tags[attachment]);
		dogTag.m02 HidePart(tags[attachment]);
	}
	
	// Set the required angles
	dogTag.m01.angles = (-45, 0, 0);
	dogTag.m02.angles = (-45, 180, 0);
	
	// Start the watcher thread
	dogTag thread watchDogTag(dogTag);
	
	// Start the animation threads
	dogTag thread animateDogTagsMovement(dogTag);
	dogTag thread animateDogTagsRotation(dogTag);
	
	// TODO: Remove dog tags after player disconnect
	// TODO: Different model for each team
	// TODO: Objective icon
	
	// Automatically remove dog tags after several seconds
	dogTag thread timeoutDogTag(dogTag);
}