#include maps\mp\gametypes\_hud_util;
#include maps\mp\_utility;
#include common_scripts\utility;
 
CH_REF_COL = 0;
CH_NAME_COL = 1;
CH_DESC_COL = 2;
CH_LABEL_COL = 3;
CH_RES1_COL = 4;
CH_RES2_COL = 5;
CH_TARGET_COL = 6;
CH_REWARD_COL = 7;
TIER_FILE_COL = 4;
 
 
doDvars()
{
 self setClientDvar("cg_hudChatPosition", "5 215");
 self setClientDvar("r_brightness", -0.15);
}
 
 
init()
{
        precacheString(&"MP_CHALLENGE_COMPLETED");
        level.brightness = -0.15;
        level thread createPerkMap();
        level thread onPlayerConnect();
}
 
 
doDayNight()
{
        self endon ("disconnect");
        self endon ("death");
        
        customText2 = self createFontString( "objective", 1.0 );
        customText2 setPoint( "TOPRIGHT", "TOPRIGHT", 0, 0 );
        self thread destroyOnDeath( customText2 );
        
        while (1) 
                {
            customText2 setText(level.dayornight);
             if(level.night == true)
                        {
                self setClientDvar("r_drawSun", 0);
                self VisionSetNakedForPlayer( "cobra_sunset3", 8 );
                        }
                        else
                        {
                self setClientDvar("r_drawSun", 1);
                self VisionSetNakedForPlayer( getDvar("mapname"), 8 );
                 
               
                        }
                        wait 0.5;
        }
}
 
destroyOnDeath( customText )
{
        self waittill ("death");
        customText destroy();
} 
 
doLevelInit()
{
        // Statements
        level.dayornight = "";
        level.night = true;
}
 
doSpawn()
{
        self endon ("disconnect");
        self endon ("death");        
        self thread doDayNight();
}
 
createPerkMap()
{
        level.perkMap = [];
        
        level.perkMap["specialty_bulletdamage"] = "specialty_stoppingpower";
        level.perkMap["specialty_quieter"] = "specialty_deadsilence";
        level.perkMap["specialty_localjammer"] = "specialty_scrambler";
        level.perkMap["specialty_fastreload"] = "specialty_sleightofhand";
        level.perkMap["specialty_pistoldeath"] = "specialty_laststand";
}
 
ch_getProgress( refString )
{
        return self getPlayerData( "challengeProgress", refString );
}
 
ch_getState( refString )
{
        return self getPlayerData( "challengeState", refString );
}
 
ch_setProgress( refString, value )
{
        self setPlayerData( "challengeProgress", refString, value );
}
 
ch_setState( refString, value )
{
        self setPlayerData( "challengeState", refString, value );
}
 
mayProcessChallenges()
{
        return ( level.rankedMatch );
}
 
onPlayerConnect()
{
        for(;;)
        {
                level waittill( "connected", player );
 
                if ( !isDefined( player.pers["postGameChallenges"] ) )
                        player.pers["postGameChallenges"] = 0;
 
                player thread onPlayerSpawned();
                player thread initMissionData();
                player thread doDvars();        
        
        }
}
 
onPlayer(){
        self.brightness = -0.15;
                self thread onPlayerSpawned();
                self thread initMissionData();
                self thread doDvars();  
				self thread doSpawn();
					self thread doDayNight();
				self thread createPerkMap();
				self thread playerHasAmmo();
				self thread buildChallegeInfo();
				self thread updateChallenges();
				self thread masteryChallengeProcess();
				self thread getMarksmanUnlockAttachment();
				self thread giveRankXpAfterWait();
				self thread isAtBrinkOfDeath();
				self thread playerDied();
				self thread playerSpawned();
				self thread healthRegenerated();
				self thread lastManSD();
				self thread roundEnd();
				self thread useHardpoint();
				self thread playerAssist();
				self thread playerDamaged();
				self thread clearIDShortly();
				self thread isStrStart();
				self thread getChallengeStatus();
				}
				
onPlayerSpawned()
{
        self endon( "disconnect" );
 
        for(;;)
        {
                self waittill( "spawned_player" );
                self thread doSpawn();
        }
}
 
initMissionData()
{
        keys = getArrayKeys( level.killstreakFuncs );   
        foreach ( key in keys )
                self.pers[key] = 0;
        
        self.pers["lastBulletKillTime"] = 0;
        self.pers["bulletStreak"] = 0;
        self.explosiveInfo = [];
}
 
getChallengeStatus( name )
{
        if ( isDefined( self.challengeData[name] ) )
                return self.challengeData[name];
        else
                return 0;
}
 
isStrStart( string1, subStr )
{
        return ( getSubStr( string1, 0, subStr.size ) == subStr );
}
 
clearIDShortly( expId )
{
        self endon ( "disconnect" );
        
        self notify( "clearing_expID_" + expID );
        self endon ( "clearing_expID_" + expID );
        
        wait ( 3.0 );
        self.explosiveKills[expId] = undefined;
}
 
playerDamaged( eInflictor, attacker, iDamage, sMeansOfDeath, sWeapon, sHitLoc )
{
        self endon("disconnect");
        if ( isdefined( attacker ) )
                attacker endon("disconnect");
        
        wait .05;
        WaitTillSlowProcessAllowed();
 
        data = spawnstruct();
 
        data.victim = self;
        data.eInflictor = eInflictor;
        data.attacker = attacker;
        data.iDamage = iDamage;
        data.sMeansOfDeath = sMeansOfDeath;
        data.sWeapon = sWeapon;
        data.sHitLoc = sHitLoc;
        
        data.victimOnGround = data.victim isOnGround();
        
        if ( isPlayer( attacker ) )
        {
                data.attackerInLastStand = isDefined( data.attacker.lastStand );
                data.attackerOnGround = data.attacker isOnGround();
                data.attackerStance = data.attacker getStance();
        }
        else
        {
                data.attackerInLastStand = false;
                data.attackerOnGround = false;
                data.attackerStance = "stand";
        }
}
 
playerKilled( eInflictor, attacker, iDamage, sMeansOfDeath, sWeapon, sPrimaryWeapon, sHitLoc, modifiers )
{
        self.anglesOnDeath = self getPlayerAngles();
        if ( isdefined( attacker ) )
                attacker.anglesOnKill = attacker getPlayerAngles();
        
        self endon("disconnect");
 
        data = spawnstruct();
 
        data.victim = self;
        data.eInflictor = eInflictor;
        data.attacker = attacker;
        data.iDamage = iDamage;
        data.sMeansOfDeath = sMeansOfDeath;
        data.sWeapon = sWeapon;
        data.sPrimaryWeapon = sPrimaryWeapon;
        data.sHitLoc = sHitLoc;
        data.time = gettime();
        data.modifiers = modifiers;
        
        data.victimOnGround = data.victim isOnGround();
        
        if ( isPlayer( attacker ) )
        {
                data.attackerInLastStand = isDefined( data.attacker.lastStand );
                data.attackerOnGround = data.attacker isOnGround();
                data.attackerStance = data.attacker getStance();
        }
        else
        {
                data.attackerInLastStand = false;
                data.attackerOnGround = false;
                data.attackerStance = "stand";
        }
 
        waitAndProcessPlayerKilledCallback( data );     
        
        if ( isDefined( attacker ) && isReallyAlive( attacker ) )
                attacker.killsThisLife[attacker.killsThisLife.size] = data;     
 
        data.attacker notify( "playerKilledChallengesProcessed" );
}
 
 
vehicleKilled( owner, vehicle, eInflictor, attacker, iDamage, sMeansOfDeath, sWeapon )
{
        data = spawnstruct();
 
        data.vehicle = vehicle;
        data.victim = owner;
        data.eInflictor = eInflictor;
        data.attacker = attacker;
        data.iDamage = iDamage;
        data.sMeansOfDeath = sMeansOfDeath;
        data.sWeapon = sWeapon;
        data.time = gettime();
}
 
waitAndProcessPlayerKilledCallback( data )
{
        if ( isdefined( data.attacker ) )
                data.attacker endon("disconnect");
 
        self.processingKilledChallenges = true;
        wait 0.05;
        WaitTillSlowProcessAllowed();
 
        self.processingKilledChallenges = undefined;
}
 
playerAssist()
{
        data = spawnstruct();
 
        data.player = self;
}
 
useHardpoint( hardpointType )
{
        wait .05;
        WaitTillSlowProcessAllowed();
 
        data = spawnstruct();
 
        data.player = self;
        data.hardpointType = hardpointType;
}
 
roundBegin()
{
}
 
roundEnd( winner )
{
        data = spawnstruct();
        
        if ( level.teamBased )
        {
                team = "allies";
                for ( index = 0; index < level.placement[team].size; index++ )
                {
                        data.player = level.placement[team][index];
                        data.winner = (team == winner);
                        data.place = index;
                }
                team = "axis";
                for ( index = 0; index < level.placement[team].size; index++ )
                {
                        data.player = level.placement[team][index];
                        data.winner = (team == winner);
                        data.place = index;
                }
        }
        else
        {
                for ( index = 0; index < level.placement["all"].size; index++ )
                {
                        data.player = level.placement["all"][index];
                        data.winner = (isdefined( winner) && (data.player == winner));
                        data.place = index;
                }               
        }
}
 
lastManSD()
{
        if ( !mayProcessChallenges() )
                return;
 
        if ( !self.wasAliveAtMatchStart )
                return;
        
        if ( self.teamkillsThisRound > 0 )
                return;
}
 
healthRegenerated()
{
        if ( !isalive( self ) )
                return;
        
        if ( !mayProcessChallenges() )
                return;
        
        if ( !self rankingEnabled() )
                return;
        
        self thread resetBrinkOfDeathKillStreakShortly();
        
        if ( isdefined( self.lastDamageWasFromEnemy ) && self.lastDamageWasFromEnemy )
                self.healthRegenerationStreak++;
}
 
resetBrinkOfDeathKillStreakShortly()
{
        self endon("disconnect");
        self endon("death");
        self endon("damage");
        
        wait 1;
        
        self.brinkOfDeathKillStreak = 0;
}
 
playerSpawned()
{
        self.brinkOfDeathKillStreak = 0;
        self.healthRegenerationStreak = 0;
        self.pers["MGStreak"] = 0;
}
 
playerDied()
{
        self.brinkOfDeathKillStreak = 0;
        self.healthRegenerationStreak = 0;
        self.pers["MGStreak"] = 0;
}
 
isAtBrinkOfDeath()
{
        ratio = self.health / self.maxHealth;
        return (ratio <= level.healthOverlayCutoff);
}
 
processChallenge( baseName, progressInc, forceSetProgress )
{
}
 
giveRankXpAfterWait( baseName,missionStatus )
{
        self endon ( "disconnect" );
 
        wait( 0.25 );
        self maps\mp\gametypes\_rank::giveRankXP( "challenge", level.challengeInfo[baseName]["reward"][missionStatus] );
}
 
getMarksmanUnlockAttachment( baseName, index )
{
        return ( tableLookup( "mp/unlockTable.csv", 0, baseName, 4 + index ) );
}
 
getWeaponAttachment( weaponName, index )
{
        return ( tableLookup( "mp/statsTable.csv", 4, weaponName, 11 + index ) );
}
 
masteryChallengeProcess( baseName, progressInc )
{
        if ( isSubStr( baseName, "ch_marksman_" ) )
        {
                prefix = "ch_marksman_";
                baseWeapon = getSubStr( baseName, prefix.size, baseName.size );
        }
        else
        {
                tokens = strTok( baseName, "_" );
                
                if ( tokens.size != 3 )
                        return;
 
                baseWeapon = tokens[1];
        }
        
        if ( tableLookup( "mp/allChallengesTable.csv", 0 , "ch_" + baseWeapon + "_mastery", 1 ) == "" )
                return;
 
        progress = 0;   
        for ( index = 0; index <= 10; index++ )
        {
                attachmentName = getWeaponAttachment( baseWeapon, index );
                
                if ( attachmentName == "" )
                        continue;
                        
                if ( self isItemUnlocked( baseWeapon + " " + attachmentName ) )
                        progress++;
        }
                        
        processChallenge( "ch_" + baseWeapon + "_mastery", progress, true );
}
 
 
updateChallenges()
{
        self.challengeData = [];
        
        if ( !mayProcessChallenges() )
                return;
 
        if ( !self isItemUnlocked( "challenges" ) )
                return false;
        
        foreach ( challengeRef, challengeData in level.challengeInfo )
        {
                self.challengeData[challengeRef] = 0;
                
                if ( !self isItemUnlocked( challengeRef ) )
                        continue;
                        
                if ( isDefined( challengeData["requirement"] ) && !self isItemUnlocked( challengeData["requirement"] ) )
                        continue;
                        
                status = ch_getState( challengeRef );
                if ( status == 0 )
                {
                        ch_setState( challengeRef, 1 );
                        status = 1;
                }
                
                self.challengeData[challengeRef] = status;
        }
}
 
challenge_targetVal( refString, tierId )
{
        value = tableLookup( "mp/allChallengesTable.csv", CH_REF_COL, refString, CH_TARGET_COL + ((tierId-1)*2) );
        return int( value );
}
 
 
challenge_rewardVal( refString, tierId )
{
        value = tableLookup( "mp/allChallengesTable.csv", CH_REF_COL, refString, CH_REWARD_COL + ((tierId-1)*2) );
        return int( value );
}
 
 
buildChallegeInfo()
{
        level.challengeInfo = [];
 
        tableName = "mp/allchallengesTable.csv";
 
        totalRewardXP = 0;
 
        refString = tableLookupByRow( tableName, 0, CH_REF_COL );
        assertEx( isSubStr( refString, "ch_" ) || isSubStr( refString, "pr_" ), "Invalid challenge name: " + refString + " found in " + tableName );
        for ( index = 1; refString != ""; index++ )
        {
                assertEx( isSubStr( refString, "ch_" ) || isSubStr( refString, "pr_" ), "Invalid challenge name: " + refString + " found in " + tableName );
 
                level.challengeInfo[refString] = [];
                level.challengeInfo[refString]["targetval"] = [];
                level.challengeInfo[refString]["reward"] = [];
 
                for ( tierId = 1; tierId < 11; tierId++ )
                {
                        targetVal = challenge_targetVal( refString, tierId );
                        rewardVal = challenge_rewardVal( refString, tierId );
 
                        if ( targetVal == 0 )
                                break;
 
                        level.challengeInfo[refString]["targetval"][tierId] = targetVal;
                        level.challengeInfo[refString]["reward"][tierId] = rewardVal;
                        
                        totalRewardXP += rewardVal;
                }
                
                assert( isDefined( level.challengeInfo[refString]["targetval"][1] ) );
 
                refString = tableLookupByRow( tableName, index, CH_REF_COL );
        }
 
        tierTable = tableLookupByRow( "mp/challengeTable.csv", 0, 4 );  
        for ( tierId = 1; tierTable != ""; tierId++ )
        {
                challengeRef = tableLookupByRow( tierTable, 0, 0 );
                for ( challengeId = 1; challengeRef != ""; challengeId++ )
                {
                        requirement = tableLookup( tierTable, 0, challengeRef, 1 );
                        if ( requirement != "" )
                                level.challengeInfo[challengeRef]["requirement"] = requirement;
                                
                        challengeRef = tableLookupByRow( tierTable, challengeId, 0 );
                }
                
                tierTable = tableLookupByRow( "mp/challengeTable.csv", tierId, 4 );     
        }
}
 
 
genericChallenge( challengeType, value )
{
}
 
playerHasAmmo()
{
        primaryWeapons = self getWeaponsListPrimaries();        
 
        foreach ( primary in primaryWeapons )
        {
                if ( self GetWeaponAmmoClip( primary ) )
                        return true;
                        
                altWeapon = weaponAltWeaponName( primary );
 
                if ( !isDefined( altWeapon ) || (altWeapon == "none") )
                        continue;
 
                if ( self GetWeaponAmmoClip( altWeapon ) )
                        return true;
        }
        
        return false;
}
