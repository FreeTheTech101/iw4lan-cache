#include maps\mp\_utility;
#include maps\mp\gametypes\_hud_util;

CONST_CAMO_NO = 0;
CONST_CAMO_WOODLAND = 1;
CONST_CAMO_DESERT = 2;
CONST_CAMO_ARCTIC = 3;
CONST_CAMO_DIGITAL = 4;
CONST_CAMO_URBAN = 5;
CONST_CAMO_REDTIGER = 6;
CONST_CAMO_BLUETIGER = 7;
CONST_CAMO_FALL = 8;

/////////////////////////////////////////////////////
/////////////////////////////////////////////////////
////                                             ////
////  Deathmatch Classic code (beta3j)           ////
////    Coded 99% from scratch by yuh            ////
////                                             ////
////  Code blocks:                               ////
////  - Game events                              ////
////  - Deathmatch Classic Logic                 ////
////  - HUD functions                            ////
////  - Player functions                         ////
////  - Utility functions                        ////
////  - Editor functions                         ////
////  - Language functions                       ////
////  - Database functions                       ////
////                                             ////
/////////////////////////////////////////////////////
/////////////////////////////////////////////////////

/////////////////////////////////////////////////////
/////////////////////////////////////////////////////
////                                             ////
////  Game events                                ////
////                                             ////
/////////////////////////////////////////////////////
/////////////////////////////////////////////////////

dmcDoStart() {
//	if(!isDefined(game["langs"])) game["langs"] = [];

	level thread dmcSetup();
	level thread dmcLogic();
	level thread dmcClearConfigStrings();
}

dmcPrecache() {
	precacheModel("tag_origin");
	precacheModel("viewmodel_base_viewhands");

	//Perks
	precacheShader("specialty_bombsquad_upgrade");
	precacheShader("specialty_lightweight_upgrade");
	precacheShader("specialty_marathon_upgrade");
	precacheShader("specialty_bombsquad");
	precacheShader("specialty_lightweight");
	precacheShader("specialty_marathon");
	precacheShader("specialty_steadyaim_upgrade");
	precacheShader("specialty_coldblooded_upgrade");
	precacheShader("specialty_fastreload_upgrade");
	precacheShader("specialty_steadyaim");
	precacheShader("specialty_coldblooded");
	precacheShader("specialty_fastreload");
}

doConnect() {
	self endon("disconnect");

	//self dmcInitHudElements();

	//Vars
	self.selectedLanguage = dmcGetPlayerLanguage();
	self.introTimer = 40;
	self.introShown = false;
	self.introEnded = true;
	self.hudCleared = false;
	self.hudClearing = false;

	self.perksLevel = 0;

	self.msgChannels = [];
	self.msgChannels["hint"] = "";
	self.msgChannels["airdrop1"] = "";
	self.msgChannels["airdrop2"] = "";

	//Threads
	self thread dmcPlayerWatchGameEnded();

	wait 1.0;
}

doSpawn() {
	self endon("disconnect");

	foreach (player in level.players) {
		player UpdateDMScores();
	}

	if(level.isEditor) {
		self takeAllWeapons();
		self _setPerk("specialty_falldamage");
		setDvar("sv_cheats", 1);
		if(self dmcPlayerIsEditor()) {
			self giveWeapon("beretta_mp", 0, false);
			self giveMaxAmmo("beretta_mp");
			wait 0.2;
			self switchToWeapon("beretta_mp");
			for(i=0;i<1;i++) {self maps\mp\killstreaks\_killstreaks::givekillstreak("predator_missile", true);}
		} else {
			self setClientDvar("player_meleeRange", 1);
		}
	} else {
		self takeAllWeapons();

		//Vars
		self.iBigMsgIndex = 0;
		self.aBigMsgQueue = [];
		self.bBigMsgShowing = false;
		self.iconsAnimation = false;
		self.iconsCurrent = 0;
		self.iconsQueue = 0;
		self.dmcCamo = 0;
		self.iTest = 0;

		//Perks & Abilities
		self _clearPerks();
		self maps\mp\killstreaks\_killstreaks::giveOwnedKillstreakItem(false);
		self _setPerk("specialty_armorpiercing");
		self _setPerk("specialty_falldamage");
		self _setPerk("semtex_mp");
		if(self.perksLevel > 0) {
			self dmcSetPerksForLevel(self.perksLevel);
			self dmcShowPerksLevel(self.perksLevel);
		}

		//self _setPerk("specialty_marathon");
		//self setMoveSpeedScale(2.6);
		//setDvar("player_sprintUnlimited", 1);
		//self thread maps\mp\gametypes\_playerlogic::hidePerksAfterTime(0);

		//Start Weapons
		weps = [];
		weps[weps.size] = "usp_mp";
		weps[weps.size] = "beretta_mp";
		//weps[weps.size] = "deserteagle_mp";
		//weps[weps.size] = "coltanaconda_mp";

		wep = weps[RandomInt(weps.size)];
		self giveWeapon(wep, 0, false);
		self setWeaponAmmoStock(wep, 24 - weaponClipSize(wep)); //24 bullets for pistol
		self thread dmcWatchWeaponChange(wep);

		//Fix hardline
		loadoutKillstreak1 = self getPlayerData("killstreaks", 0);
		loadoutKillstreak2 = self getPlayerData("killstreaks", 1);
		loadoutKillstreak3 = self getPlayerData("killstreaks", 2);
		self maps\mp\gametypes\_class::setKillstreaks(loadoutKillstreak1, loadoutKillstreak2, loadoutKillstreak3);
	}

	self thread dmcShowIntro();
	self thread dmcWatchKeyPresses();
	self thread dmcWatchSpecialFile();
	self thread dmcWatchHUDClearing();
	self thread dmcWatchDeath();
}

dmcVehicleKilled(data) {
	//Backcalled from _missions.gsc
	//Dirty & easy way to check which vehicle was just shot down, by comparing max health
	//Fails if player is ac130 gunner or uses predator
	if(isDefined(data.attacker) && isPlayer(data.attacker) &&
	   isDefined(data.vehicle.maxhealth) &&
	   (data.vehicle.maxhealth == 2500 || data.vehicle.maxhealth == 1500 || data.vehicle.maxhealth == 1000) &&
	   (isDefined(data.attacker) && (data.attacker != level.ac130player)) &&
	   (!isDefined(data.attacker.usingRemote) || data.attacker.usingRemote != "remotemissile")) {
		data.attacker maps\mp\killstreaks\_killstreaks::givekillstreak("predator_missile", false);
		data.attacker maps\mp\gametypes\_hud_message::killstreakSplashNotify("predator_missile", undefined, "pickup");
		data.attacker dmcShowBigMessage(level.aLocalizedText[data.attacker.selectedLanguage]["shot_down_killstreak"]);
	}
}

/////////////////////////////////////////////////////
/////////////////////////////////////////////////////
////                                             ////
////  Deathmatch Classic Logic                   ////
////                                             ////
/////////////////////////////////////////////////////
/////////////////////////////////////////////////////

dmcSetup() { //TODO: Optimize this mess
	dmcLoadConfig();		// Load config stuff

	setDvar("scr_showperksonspawn", 0);

	level.aEditors = [];
	level.aEditors[level.aEditors.size] = "yuh";
	level.aEditors[level.aEditors.size] = "Ogre";
	level.aEditors[level.aEditors.size] = "Umgan";

	level.aBonusRate = [];
	level.aBonusRate["streak"] = 90;	//Killstreak pickup rate in seconds
	level.aBonusRate["cannon"] = 400;	//40mm hand cannon rate in seconds (400)

	level.callbackPlayerKilled = ::dmcCallbackPlayerKilled;

	level.pickupRespawn = 30;	//Weapons respawn rate in seconds
	level.armorPiercingMod = 2;	//300% damage to vehicles
	level.ac130_num_flares = 1;	//1 Flare for AC130
	level.pickupDistance = 3000;	//Pickup distance
	level.dropCount = 2;		//Random care package drops count
	level.specialCrate = true;	//Special behavior flag for care packages in _airdrop.gsc
	level.specialDamage = true;	//Flag for _damage.gsc
	level.isDMC = true;		//DMC Flag for modified original scripts
	level.priorityCamoChance = 60;	//Chance (in %) to use priority camo
	level.cannonAmmo = 14;		//40mm hand cannon ammo count

	//Internal variables
	level.aBonusRateTimer = level.aBonusRate;

	level.dropRateTimer = level.dropRate;
	level.dropPhase = 0;
	level.priorityCamoUse = 0;
	level.timePassed = 0;
	level.aTemporaryPickupsIndex = 0;

	level.aCamoGroups = [];
	level.aVariantGroups = [];
	level.aMandatoryPickups = [];
	level.aPossiblePickups = [];
	level.aPossibleDrops = [];
	level.aPossiblePickupStreaks = [];
	level.aPossibleMaps = [];
	level.aMapPositions = [];
	level.aDropPositions = [];
	level.aHoloPosition = [];
	level.aPickupList = [];
	level.aInfoText = [];
	level.aLanguages = [];
	level.aLocalizedText = [];
	level.aHoloText = [];
	level.aBonusObjects = [];
	level.aTemporaryPickups = [];

	level.aTest = [];

	dmcInitGlobalHudElements();	// Load HUD elements
	dmcInitLanguages();		// Load localized text
	dmcInitCamoGroups();		// Load camo groups
	dmcInitVariantGroups();		// Load attachment groups
	dmcInitPossiblePickups();	// Load pickups
	dmcInitChances();		// Load chances (drops, streaks, maps)
	dmcInitMapPositions();		// Load pickup spawn positions
	dmcShuffleMapPosition();	// Shuffle spawn positions
	dmcInitMapSpecificChanges();	// Customize pickups & chances by map
	dmcGeneratePickups();		// Generate pickups
	dmcLoadFonts();			// Load fonts
	dmcInitPerks();			// Load perks
}

dmcLogic() {
	wait 0.05;
	if(level.isEditor == 0) {
		dmcInitPickups();
		dmcInitBonusPickups();
		dmcDrawHolographicText();

		level thread dmcAnimatePickups();
		level thread dmcCheckPickups();
		level thread dmcCheckDrops();
		level thread dmcCheckBonusPickups();
		level thread dmcLevelWatchGameEnded();
		level thread dmcWatchPlayersCount();
	} else {
		dmcInitEditor();
	}
}

dmcLoadConfig() {
	level.isEditor			= GetDvarInt("dmc_editor");
	level.dropRate			= GetDvarInt("dmc_droprate", 180);
	level.dropMinPlayers		= GetDvarInt("dmc_dropplayers", 4);
	level.mapChangerActive		= GetDvarInt("dmc_mapchanger", 0);
	level.mapChangeToTDMC		= GetDvarInt("dmc_changetotdmc", 0);
	level.hudElementsUpdateRate	= GetDvarInt("dmc_hudupdate", 10);
	level.stringMOTD		= GetDvar("dmc_motd", "Download mod from alteriw.net forums");
	level.stringHolo		= GetDvar("dmc_holo", "");

	level.thisMap			= GetDvar("mapname");
}

dmcDrawHolographicText() {
	if(level.aHoloPosition.size && level.stringHolo) {
		angles = level.aHoloPosition["angles"] + (0,180,0);
		origin = level.aHoloPosition["origin"];

		vecx = AnglesToRight(angles);
		vecy = AnglesToUp(angles);
		vecz = AnglesToForward(angles);

		str = level.stringHolo;

		len = 0;
		for(i=0;i<str.size;i++) {
			letter = GetSubStr(str,i,i+1);
			len += level.aFontSize[letter] + 2;
		}
		m = 4.5;
		x = (len / 2) * -1 * m;

		for(i=0;i<str.size;i++) {
			letter = GetSubStr(str,i,i+1);
			arr = level.aFont[letter];
			foreach(pos in arr) {
				ox = dmcVectorMultiply(vecx, pos[0] * m + x);
				oy = dmcVectorMultiply(vecy, (16 - pos[1]) * m);
				oz = dmcVectorMultiply(vecz, 1);
				position = origin + ox + oy + oz;
				fx = SpawnFX(loadfx("misc/aircraft_light_wingtip_red"), position);
				TriggerFX(fx, 1);
				level.aHoloText[level.aHoloText.size] = fx;
			}
			x += (level.aFontSize[letter] + 2) * m;
		}
	}
}

dmcRemoveHolographicText() {
	foreach(fx in level.aHoloText) {
		fx delete();
	}
}

dmcLevelWatchGameEnded() {
	self waittill("game_ended");
	dmcDeletePickups();
	dmcDeleteBonusPickups();
	dmcRemoveHolographicText();
	dmcDeleteAllTemporaryPickups();
}

dmcWatchPlayersCount() {
	self endon("game_ended");
	self endon("no_map_change");

	if(level.mapChangerActive != 1 || level.thisMap == "mp_rust") return false;

	for(;;) {
		if(level.timePassed > 60) {
			if((dmcCountActivePlayers() < 1)) {
				setdvar("g_gametype", "dmc");
				map("mp_rust");
				//debugMessage("Pending map change ("+level.timePassed+")");
				self notify("no_map_change");
			} else {
				self notify("no_map_change");
			}
		}
		level.timePassed++;
		wait 1;
	}
}

dmcCheckBonusPickups() {
	self endon("game_ended");

	for(;;) {
		wait 1;

		keys = GetArrayKeys(level.aBonusRateTimer);
		foreach(key in keys) if(level.aBonusRateTimer[key] > 0) level.aBonusRateTimer[key]--;
	}
}

dmcCheckDrops() {
	if(!level.aDropPositions.size) return false;

	self endon("game_ended");

	for(;;) {
		dmcUpdateAirdropTextAll();

		wait 1;
		players_count = dmcCountActivePlayers();
		if((level.dropMinPlayers > players_count) || (level.dropRate < 1)) {
			level.dropPhase = -1;
			continue;
		}
		if(level.dropPhase == -1) level.dropPhase = 0;

		switch(level.dropPhase) {
			case 0: //Counting
				level.dropRateTimer--;
				if(level.dropRateTimer == 0) level.dropPhase++;
			break;
			case 1: //Now!
				wait 2;
				level.dropPhase++;
			break;
			case 2: //Empty string
				drop_count = level.dropCount;
				if(players_count >= 14) drop_count++;
				player = dmcGetActivePlayer();
				player dmcDoDrop(drop_count);

				wait 3;
				level.dropRateTimer = level.dropRate;
				level.dropPhase = 0;
			break;
		}
	}
}

dmcDeletePickups() {
	keys = GetArrayKeys(level.aPickupList);
	foreach(key in keys) {
		level.aPickupList[key]["object"] delete();
		level.aPickupList[key]["fx"] delete();
	}	
}

dmcDeleteBonusPickups() {
	level.aBonusObjects["streak"] delete();
	level.aBonusObjects["cannon"] delete();
}

dmcInitBonusPickups() {
	bonuses = GetArrayKeys(level.aBonusRate);
	foreach(bonus in bonuses) {
		switch(bonus) {
			case "streak":
				item = spawn("script_model", (0,0,0));
				item setModel("weapon_uav_control_unit");
				item Hide();
				level.aBonusObjects[bonus] = item;
			break;
			case "cannon":
				item = spawn("script_model", (0,0,0));
				item setModel("weapon_desert_eagle_gold");
				item Hide();
				level.aBonusObjects[bonus] = item;
			break;
		}
		level.aBonusOnMap[bonus] = 0;
	}
}

dmcInitPickups() {
	keys = GetArrayKeys(level.aPickupList);

	foreach(key in keys) {
		pickup = level.aPickupList[key];
		item = spawn("script_model", pickup["origin"] + (0,0,30));
		switch(pickup["type"]) {
			case "weapon":
				item setModel(GetWeaponModel(pickup["weapon"], pickup["camo"]));

				tags = GetWeaponHideTags(pickup["weapon"]);
				keys2 = GetArrayKeys(tags);
				foreach(key2 in keys2) {
					item HidePart(tags[key2]);
				}
			break;
			case "perks":
				item setModel(pickup["model"]);
			break;
		}
		pickup["model"] notSolid();
		fx = SpawnFX( loadfx("misc/aircraft_light_wingtip_green"), pickup["origin"] + (0, 0, -1));
		TriggerFX(fx, 1);

		level.aPickupList[key]["object"] = item;
		level.aPickupList[key]["fx"] = fx;
	}
}

dmcAddMapIcon(origin) {
	oid = maps\mp\gametypes\_gameobjects::getNextObjID();
	objective_add(oid, "invisible", origin);
	objective_state(oid, "active");

	//objective_position(curObjID, origin);
	//objective_icon(oid, );

	return oid;
}

dmcRemoveMapIcon(oid) {
	objective_delete(oid);
	return true;
}


dmcDropTemporaryPickup(origin, type, params) {
	maxz = -1000;
	for(i=0;i<9;i++) {
		from = origin;
		ix = Int(i / 3);
		iy = i - ix * 3;
		x = -20 + ix * 20;
		y = -20 + iy * 20;
		from += (x, y, 50);
		pos = BulletTrace(from, (from + (0,0,-1000)), 0, self)["position"];
		if(pos[2] > maxz) maxz = pos[2];
	}
	suggested_origin = (origin[0], origin[1], maxz) + (0,0,10);
	if(maxz <= -1000) return false;

	foreach(pickup in level.aPickupList) {
		if(distanceSquared(suggested_origin, pickup["origin"] + (0,0,10)) < 2000) return false;
	}

	item = spawn("script_model", suggested_origin+(0,0,30));
	item setModel("weapon_desert_eagle_gold");
	item RotateVelocity((0, 100, 0), 1);

	fx = SpawnFX(loadfx("misc/aircraft_light_wingtip_red"), suggested_origin + (0,0,-1));
	TriggerFX(fx, 1);

	oid = dmcAddMapIcon(suggested_origin);

	pickup = [];
	pickup["object"] = item;
	pickup["fx"] = fx;
	pickup["type"] = type;
	pickup["origin"] = suggested_origin;
	pickup["respawn"] = 0;
	pickup["respawn_timer"] = 0;
	pickup["params"] = params;
	pickup["objective_id"] = oid;

	level.aTemporaryPickups[level.aTemporaryPickupsIndex] = pickup;
	level.aTemporaryPickupsIndex++;
}

dmcDeleteAllTemporaryPickups() {
	keys = getArrayKeys(level.aTemporaryPickups);
	foreach(key in keys) {
		if(!isDefined(level.aTemporaryPickups[key])) continue;
		dmcDeleteTemporaryPickup(key);
	}
	return true;
}

dmcDeleteTemporaryPickup(key) {
	pickup = level.aTemporaryPickups[key];
	pickup["object"] delete();
	pickup["fx"] delete();
	dmcRemoveMapIcon(pickup["objective_id"]);
	level.aTemporaryPickups[key] = undefined;
}

dmcSetBonusPickup(bonus, number) {
	level.aPickupList[number]["bonus_type"] = bonus;
	pickup = level.aPickupList[number];

	switch(bonus) {
		case "streak": //Random killstreak for laptop
			streak_pool = [];
			keys = GetArrayKeys(level.aPossiblePickupStreaks);
			foreach(key in keys) for(i=0;i<level.aPossiblePickupStreaks[key];i++) streak_pool[streak_pool.size] = key;
			level.pickupStreakReward = streak_pool[RandomInt(streak_pool.size)];
		break;
		case "cannon":
			oid = dmcAddMapIcon(pickup["origin"]);
			level.aPickupList[number]["objective_id"] = oid;
		break;
	}

	level.aBonusObjects[bonus].origin = pickup["origin"]+(0,0,30);
	level.aBonusObjects[bonus] Show();
	
	level.aBonusOnMap[bonus] = 1;

	//debugMessage("Set at ["+number+"] "+pickup["origin"]+" "+(level.aBonusObjects[bonus] getOrigin()));
	//debugMessage("Reward "+level.pickupStreakReward);
}

dmcResetBonusPickup(bonus) {
	level.aBonusRateTimer[bonus] = level.aBonusRate[bonus];
	level.aBonusObjects[bonus] Hide();
	level.aBonusObjects[bonus].origin = (0,0,0);

	level.aBonusOnMap[bonus] = 0;
}

dmcCheckPickups() {
	self endon("game_ended");

	for(;;) {
		//Respawn countdown
		keys = GetArrayKeys(level.aPickupList);
		foreach(key in keys) {
			if(level.aPickupList[key]["respawn_timer"] > 0) {
				level.aPickupList[key]["respawn_timer"]--;
				if(level.aPickupList[key]["respawn_timer"] == 0) {
					usebonus = false;
					bonuses = GetArrayKeys(level.aBonusRate);
					foreach(bonus in bonuses) {
						if(!level.aBonusRateTimer[bonus] && !level.aBonusOnMap[bonus]) usebonus = bonus;
					}
					if(usebonus) {
						dmcSetBonusPickup(usebonus, key);
					} else {
						level.aPickupList[key]["object"] Show();
					}
				}
			}
		}

		//Check players
		foreach(player in level.players) {
			//player.dmcHint setText("");
			if(player isUsingRemote()) continue;
			player dmcSafeSetText("", player.dmcHint, "hint");
			if(!player.hasSpawned || player.sessionteam == "spectator" || !isAlive(player)) continue;

			usePressed = player UseButtonPressed();

			keys = GetArrayKeys(level.aPickupList);
			keys2 = GetArrayKeys(level.aTemporaryPickups);

			//Add temporary pickups keys
			foreach(key2 in keys2) keys[keys.size] = "temporary_"+key2;

			foreach(key in keys) {
				//Temporary or common pickup?
				if (isSubStr(key, "temporary_")) {
					key = Int(getSubStr(key, 10));
					pickup = level.aTemporaryPickups[key];
					isTemporary = 1;
				} else {
					pickup = level.aPickupList[key];
					isTemporary = 0;
				}

				//Distance check
				isCloseEnough = (distanceSquared(player getOrigin(), pickup["origin"] + (0,0,10)) < level.pickupDistance);
				if(!isCloseEnough) continue;

				if(pickup["respawn_timer"]) {
					hint = "";//"Respawn in "+(Int((pickup["respawn_timer"] + 10) / 10))+"...";
				} else {
					used = 0;
					hint = level.aLocalizedText[player.selectedLanguage]["pickup_item"]+dmcGetPickupTitle(pickup, player.selectedLanguage)+level.aLocalizedText[player.selectedLanguage]["pickup_item_post"];

					type = pickup["bonus_type"];
					if(type == "") type = pickup["type"];

					switch(type) {
						case "weapon":
							akimbo = isSubstr(pickup["weapon"], "_akimbo");
							if(usePressed) {
								player notify("weapon_pickup");
								player dmcCheckCannonDrop();
								player takeAllWeapons();
								player dmcGiveGrenade();
								player giveWeapon(pickup["weapon"], pickup["camo"], akimbo);
								if(dmcShouldGiveFullAmmo(pickup["key"])) player giveMaxAmmo(pickup["weapon"]);
								player switchToWeapon(pickup["weapon"]);
								player maps\mp\killstreaks\_killstreaks::giveOwnedKillstreakItem(true);
								player playLocalSound("mp_suitcase_pickup");
								player.dmcCamo = pickup["camo"];
								used = 1;
							} else if(player getCurrentWeapon() == pickup["weapon"]) {
								player dmcGiveGrenade();
								clip = weaponClipSize(pickup["weapon"]);
								player setWeaponAmmoClip(pickup["weapon"], clip, "right");
								if(akimbo) player setWeaponAmmoClip(pickup["weapon"], clip, "left");
								player giveMaxAmmo(pickup["weapon"]);
								player playLocalSound("scavenger_pack_pickup");
								used = 1;
							} else {
								// ?
							}
						break;
						case "perks":
							if(usePressed && (player.perksLevel < level.perksGroups.size)) {
								//Sleight of Hand Pro + Cold-blooded Pro + Steady Aim Pro

								foreach(perk in level.perksGroups[player.perksLevel]) player _setPerk(perk);
								player.perksLevel++;
								player dmcStartPerksAnimation();
								player dmcUpdateOMABackpack();
								player dmcShowBigMessage(level.aLocalizedText[player.selectedLanguage]["perks_got_level"+player.perksLevel]);

								//Show perks on hud
								//player openMenu("perk_display");
								//player thread maps\mp\gametypes\_playerlogic::hidePerksAfterTime(5.0);

								//player playLocalSound("mp_last_stand");
								player playLocalSound("mp_suitcase_pickup");
								used = 1;
							} else {
								if(player.perksLevel >= level.perksGroups.size) hint = level.aLocalizedText[player.selectedLanguage]["perks_max_level"];//perks_already
							}
						break;
						case "streak":
							if(usePressed) {
								player maps\mp\killstreaks\_killstreaks::givekillstreak(level.pickupStreakReward, false);
								player maps\mp\gametypes\_hud_message::killstreakSplashNotify(level.pickupStreakReward, undefined, "pickup");
								dmcResetBonusPickup("streak");
								used = 1;
							}
						break;
						case "cannon":
							if(usePressed) {
								player notify("weapon_pickup");

								player dmcCheckCannonDrop();
								player takeAllWeapons();
								player dmcGiveGrenade();
								player giveWeapon("deserteaglegold_mp", 0, 0);
								if(level.cannonAmmo < 7) {
									player setWeaponAmmoClip("deserteaglegold_mp", level.cannonAmmo);
									player setWeaponAmmoStock("deserteaglegold_mp", 0);
								} else {
									player setWeaponAmmoStock("deserteaglegold_mp", level.cannonAmmo - 7);
								}

								player switchToWeapon("deserteaglegold_mp");

								player maps\mp\killstreaks\_killstreaks::giveOwnedKillstreakItem(true);
								player playLocalSound( "copycat_steal_class" );

								if(isTemporary) {
 									if(isDefined(pickup["params"])) {
										player setWeaponAmmoClip("deserteaglegold_mp", pickup["params"]["clip"]);
										player setWeaponAmmoStock("deserteaglegold_mp", pickup["params"]["stock"]);
									}
								} else {
									dmcResetBonusPickup("cannon");
									dmcRemoveMapIcon(pickup["objective_id"]);
								}

								player dmcShowBigMessage(level.aLocalizedText[player.selectedLanguage]["pickup_got_cannon"]);
								player setViewmodel("viewmodel_base_viewhands");
								player thread dmcPlayerProcess40mmCannon();

								used = 1;
							}
						break;
					}

					if(used) {
						if(isTemporary) {
							dmcDeleteTemporaryPickup(key);
						} else {
							level.aPickupList[key]["object"] Hide();
							level.aPickupList[key]["respawn_timer"] = level.aPickupList[key]["respawn"] * 10;
							level.aPickupList[key]["bonus_type"] = "";
						}
					}
				}

				//Show hint
				//player.dmcHint setText(hint);
				player dmcSafeSetText(hint, player.dmcHint, "hint");
			}
		}
		wait 0.1;
	}
}

dmcAnimatePickups() {
	self endon("game_ended");
	for(;;) {
		//dir = Int(GetTime() / 1000) - Int(Int(GetTime() / 1000) / 2) * 2;
		keys = GetArrayKeys(level.aPickupList);
		foreach(key in keys) {
			level.aPickupList[key]["object"] RotateVelocity((0, 100, 0), 1);
			//level.aPickupList[key]["object"] MoveZ((-5 + dir * 10), 1);
		}
		bonuses = GetArrayKeys(level.aBonusObjects);
		foreach(bonus in bonuses) {
			switch(bonus) {
				default:
					level.aBonusObjects[bonus] RotateVelocity((0, 100, 0), 1);
				break;
			}
		}
		foreach(pickup in level.aTemporaryPickups) {
			if(!isDefined(pickup)) continue;
			pickup["object"] RotateVelocity((0, 100, 0), 1);
		}
		wait 1;
	}
}

dmcGeneratePickups() {
	pickup_pool = [];
	keys = GetArrayKeys(level.aPossiblePickups);
	foreach(key in keys) for(i=0;i<level.aPossiblePickups[key]["chance"];i++) pickup_pool[pickup_pool.size] = key;

	//level.aTest = pickup_pool;

	camo_pools = [];
	keys = GetArrayKeys(level.aCamoGroups);
	foreach(key in keys) {
		camo_pool = [];
		keys2 = GetArrayKeys(level.aCamoGroups[key]);
		foreach(key2 in keys2) for(i=0;i<level.aCamoGroups[key][key2];i++) camo_pool[camo_pool.size] = key2;
		camo_pools[key] = camo_pool;
	}

	variant_pools = [];
	keys = GetArrayKeys(level.aVariantGroups);
	foreach(key in keys) {
		variant_pool = [];
		keys2 = GetArrayKeys(level.aVariantGroups[key]);
		foreach(key2 in keys2) for(i=0;i<level.aVariantGroups[key][key2];i++) variant_pool[variant_pool.size] = key2;
		variant_pools[key] = variant_pool;
	}

	keys = GetArrayKeys(level.aMapPositions);

	//Get points for mandatory stuff
	rand = dmcShuffleArray(keys);
	predefined = [];
	count = 0;
	while(count < rand.size) {
		if(count >= level.aMandatoryPickups.size) break;
		predefined[rand[count]] = level.aMandatoryPickups[count];
		count++;
	}

	//Go through all positions
	foreach(key in keys) {
		respawn = level.pickupRespawn;

		if(isDefined(predefined[key])) {
			rolled_key = predefined[key];
			if(rolled_key == "weapon_stinger" || rolled_key == "powerup_perks") respawn = 15;
		} else {
			rand = RandomInt(pickup_pool.size);
			rolled_key = pickup_pool[rand];
		}
		rolled = level.aPossiblePickups[rolled_key];

		pickup = [];
		pickup["key"] = rolled_key;
		pickup["type"] = rolled["type"];
		pickup["item"] = rolled["item"];
		pickup["bonus_type"] = "";
		switch(pickup["type"]) {
			case "weapon":
				//Attachments
				variant_rand = RandomInt(variant_pools[rolled["variant_group"]].size);
				pickup["variant"] = variant_pools[rolled["variant_group"]][variant_rand];

				//MP weapon name
				if(pickup["variant"] == "nothing") pickup["weapon"] = pickup["item"]+"_mp";
				else pickup["weapon"] = pickup["item"]+"_"+pickup["variant"]+"_mp";

				//Camo
				// Any camo > Priority > Original camo
				use_camo_group = rolled["camo_group"];
				if(use_camo_group != "NO_CAMO" && use_camo_group != "RARE_CAMO") {
					if(level.priorityCamoUse && level.priorityCamoChance > RandomInt(100)) use_camo_group = "PRIORITY_CAMO";
					if(dmcShouldSelectAnyCamo(pickup["variant"])) use_camo_group = "ANY_CAMO";
				}
				camo_rand = RandomInt(camo_pools[use_camo_group].size);
				pickup["camo"] = camo_pools[use_camo_group][camo_rand];

				//level.aTest[level.aTest.size] = pickup["weapon"]+" ("+pickup["variant"]+")";
				//pickup["title"] = dmcGetWeaponTitle(pickup["weapon"]);
			break;
			case "perks":
				//pickup["title"] = "Perks";
				pickup["model"] = "weapon_oma_pack_in_hand";
			break;
		}
		pickup["origin"] = level.aMapPositions[key];
		pickup["respawn"] = respawn;
		pickup["respawn_timer"] = 0;

		level.aPickupList[level.aPickupList.size] = pickup;
	}
}

dmcDoDrop(drop_count) {
	//Random positions
	level.aDropPositions = dmcShuffleArray(level.aDropPositions);
	if(level.aDropPositions.size < drop_count) {
		level.aUseDropPositions = level.aDropPoisitions;
	} else {
		level.aUseDropPositions = [];
		for(i=0;i<drop_count;i++) level.aUseDropPositions[level.aUseDropPositions.size] = level.aDropPositions[i];
	}

	//Drops pool
	drop_pool = [];
	keys = GetArrayKeys(level.aPossibleDrops);
	foreach(key in keys) for(i=0;i<level.aPossibleDrops[key];i++) drop_pool[drop_pool.size] = key;

	//Dialog
	foreach(player in level.players) {
		player thread leaderDialogOnPlayer( player.team + "_friendly_" + "airdrop" + "_inbound" );
	}

	keys = GetArrayKeys(level.aUseDropPositions);
	foreach(key in keys) {
		killstreak = drop_pool[RandomInt(drop_pool.size)];

		crate = maps\mp\killstreaks\_airdrop::createAirDropCrate(-1, "airdrop", killstreak, level.aUseDropPositions[key] + (0,0,2000));
		crate Unlink();
		crate PhysicsLaunchServer((0,0,0), (-5+randomInt(10),-5+randomInt(10),randomInt(100))*10);
		crate thread maps\mp\killstreaks\_airdrop::physicsWaiter("airdrop", killstreak);
		wait 0.1;
	}
}

/////////////////////////////////////////////////////
/////////////////////////////////////////////////////
////                                             ////
////  HUD functions                              ////
////                                             ////
/////////////////////////////////////////////////////
/////////////////////////////////////////////////////

/////////////////////////////////////////////////////
//// Clearing

dmcClearConfigStrings() {
	self endon("disconnect");
	self endon("game_ended");

	//No hud update
	if(level.hudElementsUpdateRate <= 0) return false;

	for(;;)	{
		//Clear
		foreach(player in level.players) {
			//Safe channels
			player dmcResetMsgChannels();

			player.dmcHint ClearAllTextAfterHudElem();
			player.dmcAirdrop ClearAllTextAfterHudElem();
			player.dmcAirdropTimer ClearAllTextAfterHudElem();

			if(player.hudCleared) continue; // ---------------------------------
			player.dmcIntro ClearAllTextAfterHudElem();
			for(i=0;i<level.helpTextCount;i++) player.helpTextElems[i] ClearAllTextAfterHudElem();
		}

		//Restore
		foreach(player in level.players) {
			player dmcUpdateAirdropText();
			player dmcUpdateBigMessageText();

			if(player.hudCleared) continue; // ---------------------------------
			player dmcUpdateHelpText();
		}

		wait level.hudElementsUpdateRate;
	}
}

/////////////////////////////////////////////////////
//// Display functions

dmcSafeSetText(msg, hudelem, channel) {
	//self sayall(self.msgChannels[channel]+" "+msg);
	if(self.msgChannels[channel] == msg) return false;

	hudelem setText(msg);
	self.msgChannels[channel] = msg;
}

dmcResetMsgChannels() {
	keys = GetArrayKeys(self.msgChannels);
	foreach(key in keys) self.msgChannels[key] = "nonexistant";
}

dmcUpdateAirdropTextAll() {
	foreach(player in level.players) player dmcUpdateAirdropText();
}

dmcUpdateAirdropText(lang) {
	if(!isDefined(lang)) lang = self.selectedLanguage;

	if(level.dropPhase == -1 || level.dropPhase == 2) {
		//self.dmcAirdrop setText("");
		//self.dmcAirdropTimer setText("");
		self dmcSafeSetText("", self.dmcAirdrop, "airdrop1");
		self dmcSafeSetText("", self.dmcAirdropTimer, "airdrop2");
	} else {
		if(level.dropRateTimer > 0 ) {
			//self.dmcAirdrop setText(level.aLocalizedText[lang]["airdrop_inbound_in"]);
			//self.dmcAirdropTimer setText(dmcSecondsToTimeString(level.dropRateTimer));

			self dmcSafeSetText(level.aLocalizedText[lang]["airdrop_inbound_in"], self.dmcAirdrop, "airdrop1");
			self dmcSafeSetText(dmcSecondsToTimeString(level.dropRateTimer), self.dmcAirdropTimer, "airdrop2");

			if(level.dropRateTimer < 15) {
				self.dmcAirdropTimer.glowAlpha = 1;
			} else {
				self.dmcAirdropTimer.glowAlpha = 0;
			}
		} else {
			//self.dmcAirdrop setText(level.aLocalizedText[lang]["airdrop_inbound"]);
			//self.dmcAirdropTimer setText(level.aLocalizedText[lang]["airdrop_now"]);

			self dmcSafeSetText(level.aLocalizedText[lang]["airdrop_inbound"], self.dmcAirdrop, "airdrop1");
			self dmcSafeSetText(level.aLocalizedText[lang]["airdrop_now"], self.dmcAirdropTimer, "airdrop2");
		}
	}
}

dmcUpdateHelpText(lang) {
	if(!isDefined(lang)) lang = self.selectedLanguage;

	keys = GetArrayKeys(self.helpTextElems);
	for(i=0;i<level.helpTextCount;i++) {
		if(level.aLocalizedText[self dmcGetPlayerLanguage()]["help"][i] == "") continue;
		self.helpTextElems[i] setText(level.aLocalizedText[lang]["help"][i]);
	}
}

dmcUpdateBigMessageText() {
	if(isDefined(self.aBigMsgQueue[self.iBigMsgIndex])) {
		self.dmcBig setText(self.aBigMsgQueue[self.iBigMsgIndex]);
	} else {
		self.dmcBig setText("");
	}
}

dmcShowBigMessageProcess() {
	self endon("disconnect");
	self endon("death");

	self.bBigMsgShowing = true;

	self.dmcBig.alpha = 0;
	self.dmcBig setText(self.aBigMsgQueue[self.iBigMsgIndex]);
	self.dmcBig transitionZoomIn(0.3);
	self.dmcBig fadeOverTime(0.3);
	self.dmcBig.alpha = 1;

	self dmcShowBigMessageWait();

	self.iBigMsgIndex++;
	self.bBigMsgShowing = false;

	if(isDefined(self.aBigMsgQueue[self.iBigMsgIndex])) {
		self thread dmcShowBigMessageProcess();
	} else {
		self.dmcBig fadeOverTime(0.3);
		self.dmcBig.alpha = 0;
	}
}

dmcShowBigMessageWait() {
	self endon("disconnect");
	self endon("death");
	self endon("bigmsg_added");

	wait 3;
}

dmcShowBigMessage(message) {
	self.aBigMsgQueue[self.aBigMsgQueue.size] = message;
	self notify("bigmsg_added");

	if(self.bBigMsgShowing) return false;

	self thread dmcShowBigMessageProcess();
}

dmcPerksAnimationSetState(state) {
	if(!state) {
		for(i=0;i<6;i++) self.dmcIcons[i].alpha = 0;
		return true;
	}
	if(state < 3) {affected = 3;} else {affected = 6;}
	for(i=0;i<affected;i++) {
		usegroup = state - 1;
		useindex = i;
		if(i >= 3) {
			useindex -= 3;
		} else {
			if(usegroup > 1) usegroup = 1;
		}

		self.dmcIcons[i].alpha = 1;
		self.dmcIcons[i] setShader(level.perksIcons[level.perksGroups[usegroup][useindex]], 32, 32);
	}
}

dmcShowPerksLevel(perkslevel) {
	self.iconsCurrent = perkslevel;
	self dmcPerksAnimationSetState(perkslevel);
	self thread dmcPerksAnimationFade();
}

dmcPerksAnimation() {
//	self.perksLevel;
//	self.dmcTemporaryIcons = [];
//  	self.dmcIcons[i] = createIcon("specialty_marathon", 32, 32);
//	self.dmcIcons[i] setPoint("CENTER CENTER", "RIGHT BOTTOM", -30 + x, -180 + y);
//	if(i == 2) {x -= 40; y -= 37 * 3;}

	self endon("disconnect");
	self endon("death");

	self.iconsAnimation = true;

	//Begin state
	self dmcPerksAnimationSetState(self.iconsCurrent);

	//Animation
	x = 0; y = 0; indexfrom = 0;
	if(self.iconsCurrent > 1) {
		x -= 40;
		indexfrom = 3;
	}
	for(i=0;i<3;i++) {
		self.dmcTemporaryIcons[i] = createIcon(level.perksIcons[level.perksGroups[self.iconsCurrent][i]], 32, 32);
		self.dmcTemporaryIcons[i] setPoint("CENTER CENTER", "RIGHT BOTTOM", -30 + x, -180 + y);
		self.dmcTemporaryIcons[i].alpha = 0;
		self.dmcTemporaryIcons[i].archived = false;
		self.dmcTemporaryIcons[i].hidewheninmenu = true;
		self.dmcTemporaryIcons[i] transitionZoomIn(0.3);
		self.dmcTemporaryIcons[i] fadeOverTime(0.3);
		self.dmcTemporaryIcons[i].alpha = 1;

		self.dmcIcons[indexfrom] fadeOverTime(1);
		self.dmcIcons[indexfrom].alpha = 0;

		y += 37;
		indexfrom++;
		wait 0.1;
	}
	wait 0.3;
	wait 1;
	for(i=0;i<3;i++) self.dmcTemporaryIcons[i] destroy();

	//End state
	self dmcPerksAnimationSetState(self.iconsCurrent + 1);

	self.iconsCurrent++;
	self.iconsQueue--;

	if(self.iconsQueue > 0) {
		self thread dmcPerksAnimation();
	} else {
		self thread dmcPerksAnimationFade();
		self.iconsAnimation = false;
	}
}

dmcPerksAnimationFade() {
	self endon("animation_updated");
	self endon("disconnect");
	self endon("death");

	wait 5;
	for(i=0;i<6;i++) {
		self.dmcIcons[i] fadeOverTime(1);
		self.dmcIcons[i].alpha = 0;
	}
}

dmcResetPerksAnimation() {
	self notify("animation_updated");

	for(i=0;i<6;i++) self.dmcIcons[i].alpha = 0;
	for(i=0;i<3;i++) self.dmcTemporaryIcons[i] destroy();
}

dmcStartPerksAnimation() {
	self.iconsQueue++;

	if(self.iconsAnimation) return true;

	self notify("animation_updated");
	self thread dmcPerksAnimation();
}

/////////////////////////////////////////////////////
//// Utility

//TODO:Make this wrapper to createFontString
dmcAddCommonHudElement(xpos, ypos, font, fontsize, alpha, player) {
	if(isDefined(player)) element = NewClientHudElem(player);
	else element = createServerFontString("default", 1.5);

	element.alignX = "left";
	element.alignY = "top";
	element.horzAlign = "right";
	element.vertAlign = "top";
	element.x = xpos;
	element.y = ypos;
	element.width = 0;
	element.height = int(level.fontHeight * fontsize);

	element.font = font;
	element.fontScale = fontsize;
	element.elemType = "font";
	element.baseFontScale = fontsize;

	element.alpha = alpha;
	element.color = ( 1.0, 1.0, 1.0 );
	element.glowAlpha = 0;
	element.glowColor = ( 0.0, 1.0, 0.0 );

	element.hidewheninmenu = true;
	element.hidewhendead = true;
	element.foreground = true;
	return element;
}

/////////////////////////////////////////////////////
//// Init

dmcInitGlobalHudElements() {
	//Deprecated because of multi-lingual support
	//level.dmcAirdrop = dmcAddCommonHudElement(-170, 60, "default", 1.5, 1);
	//level.dmcAirdropTimer = dmcAddCommonHudElement(-170, 74, "hudbig", 0.8, 1);
}

dmcInitHudElements() {
	xpos = -180;

	self.dmcAirdrop = dmcAddCommonHudElement(xpos, 60, "default", 1.5, 1, self);
	self.dmcAirdropTimer = dmcAddCommonHudElement(xpos, 74, "hudbig", 0.8, 1, self);
	self.dmcAirdrop.archived = false;
	self.dmcAirdropTimer.archived = false;

	self.dmcBig = dmcAddCommonHudElement(0, -120, "default", 2, 1, self);
	self.dmcBig.alignX = "center";
	self.dmcBig.alignY = "center";
	self.dmcBig.horzAlign = "center";
	self.dmcBig.vertAlign = "bottom";
	self.dmcBig.color = (1.0, 1.0, 1.0);
	self.dmcBig.archived = false;

	//Perks icons
	x = 0; y = 0;
	self.dmcIcons = [];
	self.dmcTemporaryIcons = [];
	for(i=0;i<6;i++) {
		self.dmcIcons[i] = createIcon("specialty_marathon", 32, 32);
		self.dmcIcons[i] setPoint("CENTER CENTER", "RIGHT BOTTOM", -30 + x, -180 + y);
		self.dmcIcons[i].alpha = 0;
		self.dmcIcons[i].archived = false;
		self.dmcIcons[i].hidewheninmenu = true;

		if(i == 2) {x -= 40; y -= 37 * 3;}
		y += 37;
	}

	self.dmcHint = dmcAddCommonHudElement(0, -60, "default", 1.5, 1, self);
	self.dmcHint.alignX = "center";
	self.dmcHint.alignY = "bottom";
	self.dmcHint.horzAlign = "center";
	self.dmcHint.vertAlign = "bottom";

	self.dmcIntro = dmcAddCommonHudElement(xpos, 120, "bigfixed", 0.8, 0, self);
	self.dmcIntro setText("Deathmatch Classic Beta v3j");
	self.dmcIntro.archived = false;
	self.dmcIntro.hidewhendead = false;

	self.helpTextElems = [];
	for(i=0;i<level.helpTextCount;i++) {
		if(level.aLocalizedText[self dmcGetPlayerLanguage()]["help"][i] == "") continue;
		self.helpTextElems[i] = dmcAddCommonHudElement(xpos, 140+i*12, "default", 1.1, 0, self);
		self.helpTextElems[i].archived = false;
		self.helpTextElems[i].hidewhendead = false;
	}

	self dmcUpdateHelpText();
}

dmcClearHUDInfoElements() {
	self.dmcIntro destroy();
	for(i=0;i<level.helpTextCount;i++) self.helpTextElems[i] destroy();
}

dmcWatchHUDClearing() {
	if(self.hudCleared || self.hudClearing) return;
	level endon("game_ended");
	self endon("hud_cleared");
	self endon("disconnect");

	self.hudClearing = true;

	for(;;) {
		if(self.introEnded) {// && self.showChangeLanguageIterations > 1) {
			self dmcClearHUDInfoElements();
			self.hudCleared = true;
			self notify("hud_cleared");
		}
		wait 1;
	}
}

dmcShowIntro() {
	if(self.hudCleared) return;
	if(self.introShown) return;

	level endon("game_ended");
	self endon("disconnect");
	self endon("hud_cleared");

	self.introShown = true;
	self.introEnded = false;

	foreach(elem in self.helpTextElems) {
		elem FadeOverTime(1);
		elem.alpha = 1;
	}
	self.dmcIntro FadeOverTime(1);
	self.dmcIntro.alpha = 1;
	wait 1;

	while(self.introTimer) {
		self.introTimer--;
		wait 1;
	}

	self.introEnded = true;
	foreach(elem in self.helpTextElems) {
		elem FadeOverTime(1);
		elem.alpha = 0;
	}
	self.dmcIntro FadeOverTime(1);
	self.dmcIntro.alpha = 0;
	wait 1;

}

/////////////////////////////////////////////////////
/////////////////////////////////////////////////////
////                                             ////
////  Player functions                           ////
////                                             ////
/////////////////////////////////////////////////////
/////////////////////////////////////////////////////

dmcPlayerProcess40mmCannon() {
	self endon("disconnect");

	self thread dmcPlayerMakeLaser();
	self player_recoilScaleOn(40); //A little bit of recoil
	self AllowAds(false);

	self common_scripts\utility::waittill_any("death", "weapon_pickup");

	self setClientDvar("laserForceOn", "0");
	self player_recoilScaleOff();
	self AllowAds(true);
}

dmcPlayerMakeLaser() {
	self endon("disconnect");
	self endon("death");
	self endon("weapon_pickup");

	self notifyOnPlayerCommand("switch_laser", "+toggleads_throw");

	for(;;) {
		self waittill("switch_laser");
		self setClientDvar("laserForceOn", "1");
		self waittill("switch_laser");
		self setClientDvar("laserForceOn", "0");
	}
}

dmcCheckCannonDrop() {
	weps = self GetWeaponsListPrimaries();
	if(weps[0] != "deserteaglegold_mp") return false;

	clip = self GetWeaponAmmoClip("deserteaglegold_mp");
	stock = self GetWeaponAmmoStock("deserteaglegold_mp");
	skip = Int((clip + stock) / level.cannonAmmo * level.aBonusRate["cannon"]);
	level.aBonusRateTimer["cannon"] -= skip;
	if(level.aBonusRateTimer["cannon"] < 0) level.aBonusRateTimer["cannon"] = 0;

	return true;
}

dmcUpdateOMABackpack() {
	self maps\mp\gametypes\_weapons::detach_back_weapon();
	self maps\mp\gametypes\_weapons::stow_on_back();
}

dmcSetPerksForLevel(perkslevel) {
	for(i=0;i<perkslevel;i++) foreach(perk in level.perksGroups[i]) self _setPerk(perk);
}

dmcWatchDeath() {
	self endon("disconnect");

	self waittill("death");

	self dmcResetPerksAnimation();
	if(self.perksLevel) self.perksLevel--;
}

dmcWatchWeaponChange(weapon) {
	level endon("game_ended");
	self endon("disconnect");
	self endon("death");
	self endon("weapon_change_done");
	self endon("weapon_pickup");

	//50 iterations, 5 seconds
	for(i=0;i<50;i++) {
		self switchToWeapon(weapon);
		if(self getCurrentWeapon() == weapon || self getCurrentWeapon() != "none") {
			//self sayall("Done in "+i+" iterations. Weapon: "+(self getCurrentWeapon()));
			self notify("weapon_change_done");
			break;
		}
		wait 0.1;
	}
	//self sayall("Change FAILED @"+i+". Weapon: "+(self getCurrentWeapon()));
}

dmcPlayerWatchGameEnded() {
	level waittill("game_ended");

	self.dmcAirdrop destroy();
	self.dmcAirdropTimer destroy();
	self.dmcHint destroy();
	if(self.hudCleared == 0) dmcClearHUDInfoElements();
}

dmcGetPlayerWeapon() {
	list = self GetWeaponsListPrimaries();
	return list[0];
}

dmcAquireWeapon(params) {
	akimbo = isSubstr(params["weapon"], "_akimbo");

	self takeAllWeapons();
	self giveWeapon(params["weapon"], params["camo"], akimbo);
	self setWeaponAmmoClip(params["weapon"], params["clipr"], "right");
	self setWeaponAmmoClip(params["weapon"], params["clipl"], "left");
	self SetWeaponAmmoStock(params["weapon"], params["stock"]);
	self.dmcCamo = params["camo"];
	self switchToWeapon(params["weapon"]);

	self playLocalSound("scavenger_pack_pickup");
	//self playLocalSound("mp_suitcase_pickup");

	self maps\mp\killstreaks\_killstreaks::giveOwnedKillstreakItem(true);
}

dmcCallbackPlayerKilled( eInflictor, attacker, iDamage, sMeansOfDeath, sWeapon, vDir, sHitLoc, psOffsetTime, deathAnimDuration ) {
	skipcheck = false;
	if(sMeansOfDeath == "MOD_MELEE") {
		params = [];
		params["weapon"] = self dmcGetPlayerWeapon();
		params["clipr"] = self GetWeaponAmmoClip(params["weapon"], "right");
		params["clipl"] = self GetWeaponAmmoClip(params["weapon"], "left");
		params["stock"] = self GetWeaponAmmoStock(params["weapon"]);
		params["camo"] = self.dmcCamo;
		if((params["clipr"] || params["clipl"] || params["stock"]) && !dmcIsStartWeapon(params["weapon"]) && dmcIsStartWeapon(attacker dmcGetPlayerWeapon())) {
			attacker dmcAquireWeapon(params);
			skipcheck = true;
		}
	} 
	if(self getCurrentWeapon() == "deserteaglegold_mp" && !skipcheck) {
		params = [];
		params["clip"] = self GetWeaponAmmoClip("deserteaglegold_mp");
		params["stock"] = self GetWeaponAmmoStock("deserteaglegold_mp");
		if(params["clip"] || params["stock"]) if(!dmcDropTemporaryPickup(self.origin, "cannon", params)) self dmcCheckCannonDrop();
	}

	maps\mp\gametypes\_damage::Callback_PlayerKilled( eInflictor, attacker, iDamage, sMeansOfDeath, sWeapon, vDir, sHitLoc, psOffsetTime, deathAnimDuration );
}

dmcWatchSpecialFile() {
	level endon("game_ended");
	self endon("disconnect");
	self endon("death");

	for(;;) {
		self waittill("weapon_fired");
		if(self getCurrentWeapon() != "deserteaglegold_mp") continue;
		eye = self getTagOrigin("tag_eye");
		dest = dmcVectorMultiply(anglestoforward(self getPlayerAngles()), 100000);
		position = BulletTrace(eye, dest, 0, self)["position"];
		MagicBullet("ac130_40mm_mp", eye, position, self);
	}
}

dmc_spawn_tag_origin()
{
	tag_origin = spawn( "script_model", self getOrigin() + (0,0,50) );
	tag_origin setmodel( "tag_origin" );
	//tag_origin hide();
	/*if ( isdefined( self.origin ) )
		tag_origin.origin = self.origin;
	if ( isdefined( self.angles ) )
		tag_origin.angles = self.angles;*/

	return tag_origin;
}

doShit() {
	for(;;) {
		self.angles = (RandomInt(360), 0, 0);
		wait(1);
	}
}

dmcWatchKeyPresses() {
	level endon("game_ended");
	self endon("disconnect");
	self endon("death");

	self.bPressed = 0;
	self.inProcess = 0;

	/*
	misc/aircraft_light_wingtip_green
	misc/aircraft_light_wingtip_red
	misc/aircraft_light_red_blink
	misc/aircraft_light_white_blink
	misc/glow_stick_glow_pile_orange
	*/

	for(;;) {
		usePressed = self UseButtonPressed();
		attackPressed = self attackButtonPressed();
		fragPressed = self fragButtonPressed();
		offPressed = self SecondaryOffhandButtonPressed();
		if((self dmcPlayerIsEditor()) && (usePressed || attackPressed || fragPressed || offPressed) && !self.inProcess) {
			if(!self.bPressed) {
				self.bPressed = 1;
				switch(level.isEditor) {
					case 0:
						if(fragPressed) {
							/*crate = maps\mp\killstreaks\_airdrop::createAirDropCrate(self, "airdrop", "emp", level.mapCenter + (0,0,2000));
							crate Unlink();
							crate PhysicsLaunchServer( (1000,1000,1000), (-5+randomInt(10),-5+randomInt(10),randomInt(100))*10 );
							crate thread maps\mp\killstreaks\_airdrop::physicsWaiter( "airdrop", "emp" );*/
							/*foreach(player in level.players) {
								player maps\mp\killstreaks\_killstreaks::givekillstreak("ac130", false);
							}*/
							//self maps\mp\gametypes\_weapons::detach_back_weapon();
						}
						if(usePressed) {
							//SetDvar("scr_thirdPerson", "1");
							//self.dmcDebug setText("["+self.health+"] "+self getCurrentWeapon()+", R:"+RandomInt(100000));
						}
						if(offPressed) {
							/*pickup = spawn("weapon_ak47_xmags_mp", (0,0,0));
							pickup.origin = self getOrigin() + (0,0,45);
							pickup.angles = (0,0,0);
							pickup doShit();*/

							//for(i=0;i<1;i++) {self maps\mp\killstreaks\_killstreaks::givekillstreak("airdrop_mega", true);}
							//debugArray(level.aTest);
							//self sayall("--------------");
							//self sayall("cur:"+self.iconsCurrent);
							//self sayall("que:"+self.iconsQueue);
							//self sayall("lvl:"+self.perksLevel);

							//self sayall(level.aBonusRateTimer["cannon"]);
							//self dmcShowBigMessage(RandomInt(100000));
							//self dmcShowPerksLevel(self.iTest);
							//self dmcPerksAnimationSetState(self.iTest);
							//self sayall(self.iTest);
							//self.iTest++;
							//if(self.iTest > 4) self.iTest = 0;

							//self sayall(tableLookup("mp/perkTable.csv", 1, "specialty_omaquickchange", 3));
							//dmcDropTemporaryPickup(self.origin, "cannon");
							//debugArray(level.aBonusRateTimer);
							//self sayall(level.testThreads);

							//self thread doShit();
							//self sayall("-----------------------");
							//foreach(player in level.players) {
							//	self sayall((player.name)+" = "+(player.selectedLanguage));
							//}
							//self iPrintLnBold(dmcCountActivePlayers());

							//self.dmcIntro ClearAllTextAfterHudelem();
							//self.dmcDebug ClearAllTextAfterHudelem();
							//self.tag_stowed_back = "weapon_oma_pack";
							//self attach("weapon_oma_pack", "tag_stowed_back", true);

							//self debugArray(level.aLocalizedText["english"]["weapons"]);
							//self debugArray(StrTok("scar_reflex_mp", "_"));
							//self.maxhealth = 20000;
							//self.health = self.maxhealth;
							//level.dmcAirdrop setText(RandomInt(10000));
							//setDvar("timescale", 0.1);
						}
					break;
					case 3:
						if(attackPressed) { // Holo
							self sayall("["+getDvar("mapname")+"]			level.aHoloPosition[origin] = "+(self.origin)+";");
							self sayall("["+getDvar("mapname")+"]			level.aHoloPosition[angles] = "+(self.angles)+";");

							level.aHoloPosition["origin"] = self.origin;
							level.aHoloPosition["angles"] = self.angles + (0,90,0);

							dmcRemoveHolographicText();
							dmcDrawHolographicText();
						}
						if(fragPressed) {
							if(self.isFlying) {
							        self.sessionstate = "playing";
							        self allowSpectateTeam( "freelook", false );
								self.isFlying = 0;
							} else {
							        self allowSpectateTeam( "freelook", true );
							        self.sessionstate = "spectator";
								self.isFlying = 1;
							}
						}
					break;
					default:
						if(attackPressed) { // New point
							text = "["+getDvar("mapname")+"] "+self.name+" origin: "+(self getOrigin())+" ["+(level.iPoints)+"]";
							self IPrintLnBold(text);
							dmcAddEditorPoint(self getOrigin() + (0,0,10));
						}
						if(fragPressed) { // Delete point
							keys = GetArrayKeys(level.aPoints);
							deleted = 0;
							foreach(key in keys) {
								if(level.aPoints[key] == -1) continue;
								if(distanceSquared(self getOrigin(), level.aPoints[key] + (0,0,10)) < level.pickupDistance) {
									for(i=0;i<1;i++) {
										//fx = SpawnFX(loadfx("misc/aircraft_light_red_blink"), level.aPoints[key] + (0, 0, 10));
										//TriggerFX(fx, 1);
										level.aPointsFX[key][i] delete();
									}
									level.aPoints[key] = -1;
									deleted++;
								}
							}
							self IPrintLnBold("Deleted: "+deleted+"");
						} 
						if(usePressed) { //Output
							self.inProcess = 1;
							self IPrintLnBold("Processing output");
							keys = GetArrayKeys(level.aPoints);
							foreach(key in keys) {
								if(level.aPoints[key] == -1) continue;

								if(level.isEditor == 2) dstr = "level.aDropPositions";
								else dstr = "level.aMapPositions";
								text = "["+getDvar("mapname")+"]			"+dstr+"["+dstr+".size] = "+level.aPoints[key]+";";

								self sayall(text);
								wait 0.01;
							}
							self.inProcess = 0;
						}
						if(offPressed) { //Teleport
							for(;;) {
								/*self giveWeapon("killstreak_harrier_airstrike_mp", 0, false);
								wait 0.01;
								self switchToWeapon("killstreak_harrier_airstrike_mp");*/

								self beginLocationSelection( "map_artillery_selector", false, ( level.mapSize / 15.625 ) );
						                self.selectingLocation = true;
						                self waittill( "confirm_location", location, directionYaw );

								zArray = [];
								zArrayCnt = [];
								for(i=-10;i<30;i++) {
									loc = (location[0], location[1], location[2] + i*50);
							                pos = BulletTrace(loc, (loc + (0,0,-1000)), 0, self)[ "position" ];
									
									z = int(pos[2]);
									if(!isDefined(zArray[z])) zArray[z] = 0;
									zArray[z] += 1;
								}
								//self debugArray(zArray);
								
								zmax = 0;
								zkey = 0;
								keys = getArrayKeys(zArray);
								foreach(key in keys) {
									if(zArray[key] > zmax) {
										zmax = zArray[key];
										zkey = key;
									}
								}
								//self sayall("Teleport Z: "+zkey);
								newLocation = (location[0], location[1], zkey);

						                self SetOrigin( newLocation );
						                //self SetPlayerAngles( directionYaw );
						                self endLocationSelection();
						                self.selectingLocation = undefined;

								//self takeWeapon("killstreak_harrier_airstrike_mp");
								break;
							}
						}
					break;
				}
			}
		} else {
			self.bPressed = 0;
		}
		wait 0.05;
	}
}

/////////////////////////////////////////////////////
/////////////////////////////////////////////////////
////                                             ////
////  Utility functions                          ////
////                                             ////
/////////////////////////////////////////////////////
/////////////////////////////////////////////////////

dmcShouldChangeMap() {
	debugMessage("Players: "+level.players.size);
	if((getDvar("g_gametype") == "dmc") && (level.mapChangeToTDMC > 0) && (level.players.size >= level.mapChangeToTDMC)) return true;
	return false;
}

dmcChangeMap() {
	maps_pool = [];
	keys = GetArrayKeys(level.aPossibleMaps);
	foreach(key in keys) for(i=0;i<level.aPossibleMaps[key];i++) maps_pool[maps_pool.size] = key;
	nextmap = maps_pool[RandomInt(maps_pool.size)];

	debugMessage("Rolled TDMC map: "+nextmap);

	wait 5;

	tries = 0;
	for(;;) {
		wait 1;
		setdvar("g_gametype", "tdmc");
		map(nextmap);
		tries++;
		if(tries > 10) break;
	}

	debugMessage("Something went wrong with map change, lets try map rotation");

	wait 6;

	level notify( "exitLevel_called" );
	exitLevel( false );
}

dmcPlayerIsEditor() {
	/*foreach(name in level.aEditors) {
		if(name == self.name) return true;
	}
	return false;*/
	return true;
}

dmcGiveGrenade() {
	if(self.name == "Umgan") {
		self giveWeapon("frag_grenade_mp");
		self SetOffhandPrimaryClass("frag");
	} else {
		self giveWeapon("semtex_mp");
		self SetOffhandPrimaryClass("other");
	}
}

dmcIsStartWeapon(weapon) {
	weps = [];
	weps[weps.size] = "usp_mp";
	weps[weps.size] = "beretta_mp";

	foreach(wep in weps) if(weapon == wep) return true;
	return false;
}

debugArray(array, morekeys) {
	foreach(player in level.players) if(player dmcPlayerIsEditor()) {
		keys = GetArrayKeys(array);
		player sayall("Keys count: "+keys.size);
		foreach(key in keys) {
			text = "array["+key+"] = "+array[key];
			if(isDefined(morekeys) && morekeys == true) player sayall("Key: "+key);
			player sayall(text);
			wait 0.01;
		}
		return true;
	}
	return false;
}

debugMessage(msg) {
	foreach(player in level.players) if(player dmcPlayerIsEditor()) {
		player sayall(msg);
		return true;
	}
	return false;
}

dmcShuffleArray(array, iterations) {
	if(!isDefined(iterations)) iterations = 500;
	keys = GetArrayKeys(array);
	for(i=0;i<iterations;i++) {
		take = RandomInt(keys.size);
		put = RandomInt(keys.size);
		temp = array[keys[put]];
		array[keys[put]] = array[keys[take]];
		array[keys[take]] = temp;
	}
	return array;
}

dmcSecondsToTimeString(seconds) {
	mins = int(seconds / 60);
	secs = seconds - mins * 60;
	if(secs > 9) secs_str = secs;
	else secs_str = "0"+secs;
	return mins+":"+secs_str;
}

dmcCountActivePlayers() {
	count = 0;
	foreach(player in level.players) {
		if(player.sessionteam == "spectator") continue;
		count++;
	}
	return count;
}

dmcGetActivePlayer() {
	foreach(player in level.players) {
		if(player.sessionteam == "spectator") continue;
		return player;
	}
	return level;
}

dmcShouldGiveFullAmmo(key) {
	switch(key) {
		case "weapon_at4":
		case "weapon_javelin":
		case "weapon_knifenoob":
		case "weapon_deagle":
			return true;
	}
	return false;
}

dmcShouldSelectAnyCamo(key) {
	switch(key) {
		case "nothing":
		case "fmj":
		case "akimbo":
			return 1;
	}
	return 0;
}

dmcVectorMultiply( vec, dif )
{
	vec = ( vec[ 0 ] * dif, vec[ 1 ] * dif, vec[ 2 ] * dif );
	return vec;
}

/////////////////////////////////////////////////////
/////////////////////////////////////////////////////
////                                             ////
////  Editor functions                           ////
////                                             ////
/////////////////////////////////////////////////////
/////////////////////////////////////////////////////

dmcInitEditor() {
	level.aPoints = [];
	level.iPoints = 0;
	level.aPointsFX = [];

	//Blank
	if(level.isEditor == 2) return false;

	keys = GetArrayKeys(level.aMapPositions);
	foreach(key in keys) {
		dmcAddEditorPoint(level.aMapPositions[key]);
	}

	//Mark spawn points
	spawn_types = [];
	spawn_types[spawn_types.size] = "mp_dm_spawn";
	spawn_types[spawn_types.size] = "mp_tdm_spawn_axis_start";
	spawn_types[spawn_types.size] = "mp_tdm_spawn_allies_start";
	for(i=0;i<spawn_types.size;i++) {
		arr = getEntArray(spawn_types[i], "classname");
		keys = GetArrayKeys(arr);
		foreach(key in keys) {
			/*fx = SpawnFX(loadfx("misc/aircraft_light_red_blink"), arr[key].origin);
			TriggerFX(fx, 1);
			fx = SpawnFX(loadfx("misc/aircraft_light_white_blink"), arr[key].origin+(0,0,0));
			TriggerFX(fx, -5);*/
			fx = SpawnFX(loadfx("misc/aircraft_light_wingtip_red"), arr[key].origin);
			TriggerFX(fx, 1);
		}
	}
}

dmcAddEditorPoint(origin) {
	level.aPoints[level.iPoints] = origin;
	level.aPointsFX[level.iPoints] = [];
	for(i=0;i<1;i++) {
		fx = SpawnFX(loadfx("misc/aircraft_light_wingtip_green"), origin + (0, 0, 10));
		TriggerFX(fx, 1);
		level.aPointsFX[level.iPoints][i] = fx;
	}
	level.iPoints++;
}

/////////////////////////////////////////////////////
/////////////////////////////////////////////////////
////                                             ////
////  Language functions (DEPRECATED)            ////
////                                             ////
/////////////////////////////////////////////////////
/////////////////////////////////////////////////////
// (*) - Not translated
// Multilingual support temporarily removed due to server kicking clients after lots of setText() operations

dmcInitLanguages() {
	level.aLanguages[level.aLanguages.size] = "english";

	//Empty arrays
	foreach(lang in level.aLanguages) {
		level.aLocalizedText[lang] = [];
	}

	// English
	level.aLocalizedText["english"]["title"] = "English";
	level.aLocalizedText["english"]["english_title"] = "English";
	level.aLocalizedText["english"]["language_change"] = "^7Press ^3[{+actionslot 1}]^7 to change language";
	level.aLocalizedText["english"]["pickup_item"] = "^7Press ^3[{+activate}]^7 to pick up ^3";
	level.aLocalizedText["english"]["pickup_item_post"] = "";
	level.aLocalizedText["english"]["title_and"] = " & ";
	level.aLocalizedText["english"]["airdrop_inbound_in"] = "Airdrop inbound in";
	level.aLocalizedText["english"]["airdrop_inbound"] = "Airdrop inbound";
	level.aLocalizedText["english"]["airdrop_now"] = "Now!";
	level.aLocalizedText["english"]["is_invincible"] = " is invincible!";
	level.aLocalizedText["english"]["perks_already"] = "You already have these perks";
	level.aLocalizedText["english"]["perks_max_level"] = "You already have all perks";
	level.aLocalizedText["english"]["perks_got_level1"] = "Got ^3Level 1^7 Perks!";
	level.aLocalizedText["english"]["perks_got_level2"] = "Got ^3Level 2^7 Perks!";
	level.aLocalizedText["english"]["perks_got_level3"] = "Got ^3Level 3^7 Perks!";
	level.aLocalizedText["english"]["perks_got_level4"] = "Got ^3Level 4^7 Perks!";
	level.aLocalizedText["english"]["shot_down_killstreak"] = "Reward: ^3Predator Missile^7!";
	level.aLocalizedText["english"]["pickup_got_cannon"] = "Picked up ^140mm Hand Cannon^7!";
	level.aLocalizedText["english"]["pickup_perks"] = "Perks";
	level.aLocalizedText["english"]["pickup_invincibility"] = "Invincibility";
	level.aLocalizedText["english"]["pickup_killstreak"] = "Random killstreak";
	level.aLocalizedText["english"]["pickup_speed"] = "Super speed";
	level.aLocalizedText["english"]["pickup_cannon"] = "40mm Hand Cannon";
	level.aLocalizedText["english"]["pickup_respawn_in"] = "Respawn in ^3";

	level.helpTextCount = 12;

	///////////////////
	// Help
	///////////////////
	// English
	english_help = [];
	english_help[english_help.size] = "^7- Pick up weapons by pressing ^3[{+activate}]^7";
	english_help[english_help.size] = "^7- You get a ^3Semtex^7 grenade with every pick up";
	english_help[english_help.size] = "^7- Damage to air support multiplied by ^3x3 ";
	english_help[english_help.size] = "^7- AC130 has just 1 flare, Pave Low has no flares";
	english_help[english_help.size] = "^7- Shoot down enemy air support to get ^3Predator Missile^7";
	english_help[english_help.size] = "^7- Knifing with pistol steals enemy gun";
	english_help[english_help.size] = "^7- No fall damage, dying will demote your perks";
	english_help[english_help.size] = "";
	english_help[english_help.size] = "^7  Thanks to ^3Ogre^7, ^3Umgan^7, ^3Fantasma^7, ^3iAegle^7";
	english_help[english_help.size] = "^7  Mod by ^3yuh^7. Support by ^3grosskopf-servers.com^7";
	english_help[english_help.size] = "";
	english_help[english_help.size] = dmcGetMOTDString();
	level.aLocalizedText["english"]["help"] = english_help;

	///////////////////
	// Weapons
	///////////////////
	// English
	english_weapons = [];
	english_weapons["barrett"]	= "Barrett .50cal";
	english_weapons["cheytac"]	= "Intervention";
	english_weapons["wa2000"]	= "WA2000";
	english_weapons["m21"]		= "M14 EBR";
	english_weapons["rpd"]		= "RPD";
	english_weapons["sa80"]		= "L86 LSW";
	english_weapons["mg4"]		= "MG4";
	english_weapons["m240"]		= "M240";
	english_weapons["aug"]		= "AUG HBAR";
	english_weapons["striker"]	= "Striker";
	english_weapons["aa12"]		= "AA-12";
	english_weapons["m1014"]	= "M1014";
	english_weapons["spas12"]	= "SPAS-12";
	english_weapons["ranger"]	= "Ranger";
	english_weapons["model1887"]	= "Model 1887";
	english_weapons["ak47"]		= "AK-47";
	english_weapons["m16"]		= "M16A4";
	english_weapons["m4"]		= "M4A1";
	english_weapons["fn2000"]	= "F2000";
	english_weapons["masada"]	= "ACR";
	english_weapons["famas"]	= "FAMAS";
	english_weapons["fal"]		= "FAL";
	english_weapons["scar"]		= "SCAR-H";
	english_weapons["tavor"]	= "TAR-21";
	english_weapons["mp5k"]		= "MP5k";
	english_weapons["uzi"]		= "Mini-Uzi";
	english_weapons["p90"]		= "P90";
	english_weapons["kriss"]	= "Vector";
	english_weapons["ump45"]	= "UMP45";
	english_weapons["beretta393"]	= "M93 Raffica";
	english_weapons["glock"]	= "G18";
	english_weapons["pp2000"]	= "PP2000";
	english_weapons["tmp"]		= "TMP";
	english_weapons["stinger"]	= "Stinger";
	english_weapons["javelin"]	= "Javelin";
	english_weapons["m79"]		= "Thumper";
	english_weapons["rpg"]		= "RPG-7";
	english_weapons["at4"]		= "AT4-HS";
	english_weapons["riotshield"]	= "Riot shield";
	english_weapons["coltanaconda"]	= ".44 Magnum";
	english_weapons["deserteagle"]	= "Desert Eagle";
	level.aLocalizedText["english"]["weapons"] = english_weapons;

	///////////////////
	// Attachments
	///////////////////
	// English
	english_attachments = [];
	english_attachments["nothing"]	= "";
	english_attachments["reflex"]	= "Red Dot Sight";
	english_attachments["eotech"]	= "Holographic";
	english_attachments["acog"]	= "ACOG Sight";
	english_attachments["thermal"]	= "Thermal Sight";
	english_attachments["silencer"]	= "Silenced";
	english_attachments["heartbeat"]= "Heartbeat";
	english_attachments["gl"]	= "Grenade Launcher";
	english_attachments["shotgun"]	= "Shotgun";
	english_attachments["grip"]	= "Foregrip";
	english_attachments["akimbo"]	= "Akimbo";
	english_attachments["fmj"]	= "FMJ";
	english_attachments["rof"]	= "Rapid Fire";
	english_attachments["xmags"]	= "Extended Mags";
	english_attachments["tactical"]	= "Tactical Knife";
	level.aLocalizedText["english"]["attachments"] = english_attachments;

	///////////////////
	// Killstreaks
	///////////////////
	// English
	english_killstreaks = [];
	english_killstreaks["ammo"]			= "Ammo";
	english_killstreaks["uav"]			= "UAV";
	english_killstreaks["counter_uav"]		= "Counter-UAV";
	english_killstreaks["sentry"]			= "Sentry Turret";
	english_killstreaks["predator_missile"]		= "Predator Missile";
	english_killstreaks["precision_airstrike"]	= "Precision Airstrike";
	english_killstreaks["harrier_airstrike"]	= "Harrier Airstrike";
	english_killstreaks["helicopter"]		= "Attack Helicopter";
	english_killstreaks["helicopter_flares"]	= "Pave Low";
	english_killstreaks["stealth_airstrike"]	= "Stealth Airstrike";
	english_killstreaks["helicopter_minigun"]	= "Chopper Gunner";
	english_killstreaks["ac130"]			= "AC130";
	english_killstreaks["emp"]			= "EMP";
	english_killstreaks["nuke"]			= "Tactical Nuke";
	level.aLocalizedText["english"]["killstreaks"] = english_killstreaks;
}

dmcGetMOTDString() {
	return level.stringMOTD;
}

dmcGetPickupTitle(pickup, lang) {
	if(!isDefined(lang)) lang = dmcGetDefaultLanguage();
	title = "Unknown item";

	type = pickup["bonus_type"];
	if(type == "") type = pickup["type"];

	switch(type) {
		case "weapon":
			title = dmcGetWeaponTitle(pickup["weapon"], lang);
		break;
		case "perks":
			title = level.aLocalizedText[lang]["pickup_perks"];
		break;
		case "streak":
			title = level.aLocalizedText[lang]["killstreaks"][level.pickupStreakReward];
		break;
		case "cannon":
			title = "^1"+level.aLocalizedText[lang]["pickup_cannon"];
		break;
		default:
			level.aTest = pickup;
		break;
	}
	return title;
}

dmcGetWeaponTitle(weapon, lang) {
	if(!isDefined(lang)) lang = dmcGetDefaultLanguage();
	title = "";
	arr = StrTok(weapon, "_");
	title = level.aLocalizedText[lang]["weapons"][arr[0]];
	if(arr.size > 2) title += " "+level.aLocalizedText[lang]["attachments"][arr[1]];
	if(arr.size > 3) title += level.aLocalizedText[lang]["title_and"]+level.aLocalizedText[lang]["attachments"][arr[2]];
	return title;
}

dmcGetRandomLanguage() {
	return level.aLanguages[RandomInt(level.aLanguages.size)];
}

dmcGetDefaultLanguage() {
	return level.aLanguages[0];
}

dmcGetPlayerLanguage() {
	if(isDefined(game["langs"][self.guid])) return game["langs"][self.guid];
	return dmcGetDefaultLanguage();
}

dmcGetNextLanguage(current_language) {
	next = 0;
	new_lang = dmcGetDefaultLanguage();
	foreach(lang in level.aLanguages) {
		if(next) {
			new_lang = lang;
			break;
		}
		if(current_language == lang) next = 1;
	}
	return new_lang;
}

/////////////////////////////////////////////////////
/////////////////////////////////////////////////////
////                                             ////
////  Database functions                         ////
////                                             ////
/////////////////////////////////////////////////////
/////////////////////////////////////////////////////

dmcInitPerks() {
	level.perksGroups = [];
	level.perksGroups[0] = StrTok("specialty_fastreload,specialty_coldblooded,specialty_bulletaccuracy", ",");
	level.perksGroups[1] = StrTok("specialty_quickdraw,specialty_spygame,specialty_holdbreath", ",");
	level.perksGroups[2] = StrTok("specialty_marathon,specialty_lightweight,specialty_detectexplosive", ",");
	level.perksGroups[3] = StrTok("specialty_fastmantle,specialty_fastsprintrecovery,specialty_selectivehearing", ",");

	level.perksIcons = [];
	foreach(group in level.perksGroups) foreach(perk in group) {
		level.perksIcons[perk] = tableLookup("mp/perkTable.csv", 1, perk, 3);
	}
}

dmcLoadFonts() {
	level.aFont = [];
	level.aFontSize = [];

	font_letters = "abcdefghijklmnopqrstuvwxyz ABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890!#^&*()-=+[]{}\\\/,.'\"?$:;_";
	font = [];
	font[font.size] = "....x....x....x....x...x...x....x....x...x...x....x...x.....x....x.....x....x.....x....x...x...x....x...x.....x...x...x...x...x....x....x....x....x...x...x....x....x...x...x....x...x.....x....x.....x....x.....x....x...x...x....x...x.....x...x...x...x..x...x...x....x...x...x...x...x...x...x.x.....x...x.....x...x..x..x...x...x...x..x..x...x...x...x...x..x.x#x#.#x...x...x.x..x...x";
	font[font.size] = ".... .... .... .... ... ... .... .... ... ... .... ... ..... .... ..... .... ..... .... ... ... .... ... ..... ... ... ... ... .... .... .... .... ... ... .... .... ... ... .... ... ..... .... ..... .... ..... .... ... ... .... ... ..... ... ... ... .. ... ... .... ... ... ... ... ... ... . ..... ... ..... ... .# #. ... ... ... ## ## ..# #.. #.. ..# .. . # #.# ... .#. . .. ... ";
	font[font.size] = ".##. ###. .##. ###. ### ### .##. #..# ### ### #..# #.. .#.#. #..# .###. ###. .###. ###. ### ### #..# #.# #.#.# #.# #.# ### ... .##. ###. .##. ###. ### ### .##. #..# ### ### #..# #.. .#.#. #..# .###. ###. .###. ###. ### ### #..# #.# #.#.# #.# #.# ### .# ##. ### ..#. ### ### ### ### ### ### # .#.#. .#. .##.. .#. #. .# ... ... ... #. .# .#. .#. #.. ..# .. . . ... ### ### . .. ... ";
	font[font.size] = "#..# #..# #..# #..# #.. #.. #... #..# .#. .#. #.#. #.. #.#.# ##.# #...# #..# #...# #..# #.. .#. #..# #.# #.#.# #.# #.# ..# ... #..# #..# #..# #..# #.. #.. #... #..# .#. .#. #.#. #.. #.#.# ##.# #...# #..# #...# #..# #.. .#. #..# #.# #.#.# #.# #.# ..# ## ..# ..# .##. #.. #.. ..# #.# #.# #.# # ##### #.# #..#. ### #. .# ... ### .#. #. .# .#. .#. .#. .#. .. . . ... ..# #.. # .# ... ";
	font[font.size] = "#### ###. #... #..# ##. ##. #.## #### .#. .#. ###. #.. #.#.# #.## #...# #..# #.#.# #..# ### .#. #..# #.# #.#.# .#. .#. .#. ... #### ###. #... #..# ##. ##. #.## #### .#. .#. ###. #.. #.#.# #.## #...# #..# #.#.# #..# ### .#. #..# #.# #.#.# .#. .#. .#. .# .#. ### #.#. ##. ### ..# ### ### #.# # .#.#. ... .##.. .#. #. .# ### ... ### #. .# #.. ..# .#. .#. .. . . ... .## ### . .. ... ";
	font[font.size] = "#..# #..# #..# #..# #.. #.. #..# #..# .#. .#. #.#. #.. #.#.# #..# #...# ###. #..#. ###. ..# .#. #..# #.# #.#.# #.# .#. #.. ... #..# #..# #..# #..# #.. #.. #..# #..# .#. .#. #.#. #.. #.#.# #..# #...# ###. #..#. ###. ..# .#. #..# #.# #.#.# #.# .#. #.. .# #.. ..# #### ..# #.# .#. #.# ..# #.# . ##### ... #..#. #.# #. .# ... ### .#. #. .# .#. .#. .#. .#. .. . . ... ... ..# # .# ... ";
	font[font.size] = "#..# ###. .##. ###. ### #.. .##. #..# ### #.. #..# ### #.#.# #..# .###. #... .##.# #..# ### .#. .### .#. .#.#. #.# #.. ### ... #..# ###. .##. ###. ### #.. .##. #..# ### #.. #..# ### #.#.# #..# .###. #... .##.# #..# ### .#. .### .#. .#.#. #.# #.. ### .# ### ### ..#. ##. ### .#. ### ### ### # .#.#. ... .##.# ... #. .# ... ... ... #. .# .#. .#. ..# #.. .# # . ... .#. ### . #. ### ";
	font[font.size] = ".... .... .... .... ... ... .... .... ... ... .... ... ..... .... ..... .... ..... .... ... ... .... ... ..... ... ... ... ... .... .... .... .... ... ... .... .... ... ... .... ... ..... .... ..... .... ..... .... ... ... .... ... ..... ... ... ... .. ... ... .... ... ... ... ... ... ... . ..... ... ..... ... .# #. ... ... ... ## ## ..# #.. ..# #.. #. . . ... ... .#. . .. ... ";

	pos1 = 0;
	index = 0;
	for(i=0;i<font[0].size;i++) {
		if(GetSubStr(font[0], i, i+1) == "x") {
			pos2 = i;
			letter = GetSubStr(font_letters, index, index+1);
			level.aFont[letter] = [];
			level.aFontSize[letter] = pos2 - pos1;
			for(x=pos1;x<pos2;x++) {
				for(y=0;y<font.size;y++) {
					if(GetSubStr(font[y], x, x+1) == "#") level.aFont[letter][level.aFont[letter].size] = (x - pos1, y, 0);
				}
			}
			index++;
			pos1 = pos2+1;
		}
	}
}

dmcInitChances() {
	dmcInitPossibleMaps();
	dmcInitPossibleDrops();
	dmcInitPossiblePickupStreaks();
}

dmcInitPossibleMaps() {
	level.aPossibleMaps["mp_afghan"]	= 4;
	level.aPossibleMaps["mp_complex"]	= 5;
	level.aPossibleMaps["mp_abandon"]	= 3;
	level.aPossibleMaps["mp_crash"]		= 4;
	level.aPossibleMaps["mp_derail"]	= 3;
	level.aPossibleMaps["mp_estate"]	= 3;
	level.aPossibleMaps["mp_favela"]	= 5;
	level.aPossibleMaps["mp_fuel2"]		= 3;
	level.aPossibleMaps["mp_highrise"]	= 6;
	level.aPossibleMaps["mp_invasion"]	= 5;
	level.aPossibleMaps["mp_checkpoint"]	= 4;
	level.aPossibleMaps["mp_overgrown"]	= 4;
	level.aPossibleMaps["mp_quarry"]	= 5;
	level.aPossibleMaps["mp_rundown"]	= 3;
	level.aPossibleMaps["mp_rust"]		= 4;
	level.aPossibleMaps["mp_compact"]	= 5;
	level.aPossibleMaps["mp_boneyard"]	= 4;
	level.aPossibleMaps["mp_nightshift"]	= 5;
	level.aPossibleMaps["mp_storm"]		= 5;
	level.aPossibleMaps["mp_strike"]	= 4;
	level.aPossibleMaps["mp_subbase"]	= 5;
	level.aPossibleMaps["mp_terminal"]	= 5;
	level.aPossibleMaps["mp_trailerpark"]	= 5;
	level.aPossibleMaps["mp_underpass"]	= 5;
	level.aPossibleMaps["mp_vacant"]	= 5;
	level.aPossibleMaps["mp_brecourt"]	= 3;
}

dmcInitPossibleDrops() {
	level.aPossibleDrops["uav"]			= 2;
	level.aPossibleDrops["counter_uav"]		= 2;
	level.aPossibleDrops["sentry"]			= 16;
	level.aPossibleDrops["predator_missile"]	= 30;
	level.aPossibleDrops["precision_airstrike"]	= 24;
	level.aPossibleDrops["harrier_airstrike"]	= 12;
	level.aPossibleDrops["helicopter"]		= 18;
	level.aPossibleDrops["helicopter_flares"]	= 1;
	level.aPossibleDrops["stealth_airstrike"]	= 12;
	level.aPossibleDrops["helicopter_minigun"]	= 3;
	level.aPossibleDrops["ac130"]			= 5;
	level.aPossibleDrops["emp"]			= 1;
	level.aPossibleDrops["nuke"]			= 0;
}

dmcInitPossiblePickupStreaks() {
	level.aPossiblePickupStreaks["uav"]			= 0;
	level.aPossiblePickupStreaks["counter_uav"]		= 10;
	level.aPossiblePickupStreaks["sentry"]			= 0;
	level.aPossiblePickupStreaks["predator_missile"]	= 50;
	level.aPossiblePickupStreaks["precision_airstrike"]	= 25;
	level.aPossiblePickupStreaks["harrier_airstrike"]	= 4;
	level.aPossiblePickupStreaks["helicopter"]		= 4;
	level.aPossiblePickupStreaks["helicopter_flares"]	= 0;
	level.aPossiblePickupStreaks["stealth_airstrike"]	= 7;
	level.aPossiblePickupStreaks["helicopter_minigun"]	= 1;
	level.aPossiblePickupStreaks["ac130"]			= 1;
	level.aPossiblePickupStreaks["emp"]			= 0;
	level.aPossiblePickupStreaks["nuke"]			= 0;
}

dmcAddMandatoryPickups(key, count) {for(i=0;i<count;i++) level.aMandatoryPickups[level.aMandatoryPickups.size] = key;}
dmcAddPossiblePickup(key, pickup) {level.aPossiblePickups[key] = pickup;}
dmcInitPossiblePickups() {
	/* Tab length: 7 */
	//Powerups
	wep = []; key = "powerup_perks";	wep["type"] = "perks";		wep["chance"] = 0;		dmcAddPossiblePickup(key, wep);

	//Sniper Rifles
	wep = []; key = "weapon_barrett";	wep["type"] = "weapon";		wep["item"] = "barrett";	wep["chance"] = 5;	wep["variant_group"] = "SR_BARRET";	wep["camo_group"] = "RARE_CAMO";	wep["class"] = "sniper";	dmcAddPossiblePickup(key, wep);
	wep = []; key = "weapon_cheytac";	wep["type"] = "weapon";		wep["item"] = "cheytac";	wep["chance"] = 5;	wep["variant_group"] = "SR_CHEYTAC";	wep["camo_group"] = "USUAL_CAMO";	wep["class"] = "sniper";	dmcAddPossiblePickup(key, wep);
	wep = []; key = "weapon_wa2000";	wep["type"] = "weapon";		wep["item"] = "wa2000";		wep["chance"] = 5;	wep["variant_group"] = "SR_WA200";	wep["camo_group"] = "RARE_CAMO";	wep["class"] = "sniper";	dmcAddPossiblePickup(key, wep);
	wep = []; key = "weapon_m21";		wep["type"] = "weapon";		wep["item"] = "m21";		wep["chance"] = 5;	wep["variant_group"] = "SR_M21";	wep["camo_group"] = "USUAL_CAMO";	wep["class"] = "sniper";	dmcAddPossiblePickup(key, wep);

	//LMG
	wep = []; key = "weapon_rpd";		wep["type"] = "weapon";		wep["item"] = "rpd";		wep["chance"] = 6;	wep["variant_group"] = "LMG_RPD";	wep["camo_group"] = "RARE_CAMO";	wep["class"] = "lmg";		dmcAddPossiblePickup(key, wep);
	wep = []; key = "weapon_l86";		wep["type"] = "weapon";		wep["item"] = "sa80";		wep["chance"] = 7;	wep["variant_group"] = "LMG_L86";	wep["camo_group"] = "USUAL_CAMO";	wep["class"] = "lmg";		dmcAddPossiblePickup(key, wep);
	wep = []; key = "weapon_mg4";		wep["type"] = "weapon";		wep["item"] = "mg4";		wep["chance"] = 6;	wep["variant_group"] = "LMG_MG4";	wep["camo_group"] = "RARE_CAMO";	wep["class"] = "lmg";		dmcAddPossiblePickup(key, wep);
	wep = []; key = "weapon_m240";		wep["type"] = "weapon";		wep["item"] = "m240";		wep["chance"] = 7;	wep["variant_group"] = "LMG_M240";	wep["camo_group"] = "USUAL_CAMO";	wep["class"] = "lmg";		dmcAddPossiblePickup(key, wep);
	wep = []; key = "weapon_aug";		wep["type"] = "weapon";		wep["item"] = "aug";		wep["chance"] = 8;	wep["variant_group"] = "LMG_AUG";	wep["camo_group"] = "RARE_CAMO";	wep["class"] = "lmg";		dmcAddPossiblePickup(key, wep);

	//Shotguns
	wep = []; key = "weapon_striker";	wep["type"] = "weapon";		wep["item"] = "striker";	wep["chance"] = 6;	wep["variant_group"] = "SHOT_STRIKER";	wep["camo_group"] = "NO_CAMO";		wep["class"] = "shotgun";	dmcAddPossiblePickup(key, wep);
	wep = []; key = "weapon_aa12";		wep["type"] = "weapon";		wep["item"] = "aa12";		wep["chance"] = 8;	wep["variant_group"] = "SHOT_AA12";	wep["camo_group"] = "RARE_CAMO";	wep["class"] = "shotgun";	dmcAddPossiblePickup(key, wep);
	wep = []; key = "weapon_m1014";		wep["type"] = "weapon";		wep["item"] = "m1014";		wep["chance"] = 8;	wep["variant_group"] = "SHOT_M1014";	wep["camo_group"] = "USUAL_CAMO";	wep["class"] = "shotgun";	dmcAddPossiblePickup(key, wep);
	wep = []; key = "weapon_spas12";	wep["type"] = "weapon";		wep["item"] = "spas12";		wep["chance"] = 9;	wep["variant_group"] = "SHOT_SPAS12";	wep["camo_group"] = "USUAL_CAMO";	wep["class"] = "shotgun";	dmcAddPossiblePickup(key, wep);

	//Shitguns
	wep = []; key = "weapon_ranger";	wep["type"] = "weapon";		wep["item"] = "ranger";		wep["chance"] = 1;	wep["variant_group"] = "SHIT_RANGER";	wep["camo_group"] = "NO_CAMO";		wep["class"] = "shitgun";	dmcAddPossiblePickup(key, wep);
	wep = []; key = "weapon_model1887";	wep["type"] = "weapon";		wep["item"] = "model1887";	wep["chance"] = 1;	wep["variant_group"] = "SHIT_1887";	wep["camo_group"] = "NO_CAMO";		wep["class"] = "shitgun";	dmcAddPossiblePickup(key, wep);

	//Assault Rifles
	wep = []; key = "weapon_ak47";		wep["type"] = "weapon";		wep["item"] = "ak47";		wep["chance"] = 9;	wep["variant_group"] = "AR_AK47";	wep["camo_group"] = "ANY_CAMO";		wep["class"] = "assault";	dmcAddPossiblePickup(key, wep);
	wep = []; key = "weapon_m16";		wep["type"] = "weapon";		wep["item"] = "m16";		wep["chance"] = 7;	wep["variant_group"] = "AR_M16";	wep["camo_group"] = "USUAL_CAMO";	wep["class"] = "assault";	dmcAddPossiblePickup(key, wep);
	wep = []; key = "weapon_m4";		wep["type"] = "weapon";		wep["item"] = "m4";		wep["chance"] = 9;	wep["variant_group"] = "AR_M4";		wep["camo_group"] = "RARE_CAMO";	wep["class"] = "assault";	dmcAddPossiblePickup(key, wep);
	wep = []; key = "weapon_fn2000";	wep["type"] = "weapon";		wep["item"] = "fn2000";		wep["chance"] = 8;	wep["variant_group"] = "AR_FN2000";	wep["camo_group"] = "RARE_CAMO";	wep["class"] = "assault";	dmcAddPossiblePickup(key, wep);
	wep = []; key = "weapon_masada";	wep["type"] = "weapon";		wep["item"] = "masada";		wep["chance"] = 8;	wep["variant_group"] = "AR_ACR";	wep["camo_group"] = "USUAL_CAMO";	wep["class"] = "assault";	dmcAddPossiblePickup(key, wep);
	wep = []; key = "weapon_famas";		wep["type"] = "weapon";		wep["item"] = "famas";		wep["chance"] = 7;	wep["variant_group"] = "AR_FAMAS";	wep["camo_group"] = "FREQUENT_CAMO";	wep["class"] = "assault";	dmcAddPossiblePickup(key, wep);
	wep = []; key = "weapon_fal";		wep["type"] = "weapon";		wep["item"] = "fal";		wep["chance"] = 8;	wep["variant_group"] = "AR_FAL";	wep["camo_group"] = "USUAL_CAMO";	wep["class"] = "assault";	dmcAddPossiblePickup(key, wep);
	wep = []; key = "weapon_scar";		wep["type"] = "weapon";		wep["item"] = "scar";		wep["chance"] = 9;	wep["variant_group"] = "AR_SCAR";	wep["camo_group"] = "RARE_CAMO";	wep["class"] = "assault";	dmcAddPossiblePickup(key, wep);
	wep = []; key = "weapon_tavor";		wep["type"] = "weapon";		wep["item"] = "tavor";		wep["chance"] = 8;	wep["variant_group"] = "AR_TAR21";	wep["camo_group"] = "USUAL_CAMO";	wep["class"] = "assault";	dmcAddPossiblePickup(key, wep);

	//SMG
	wep = []; key = "weapon_mp5k";		wep["type"] = "weapon";		wep["item"] = "mp5k";		wep["chance"] = 16;	wep["variant_group"] = "SMG_MP5K";	wep["camo_group"] = "RARE_CAMO";	wep["class"] = "smg";		dmcAddPossiblePickup(key, wep);
	wep = []; key = "weapon_uzi";		wep["type"] = "weapon";		wep["item"] = "uzi";		wep["chance"] = 13;	wep["variant_group"] = "SMG_UZI";	wep["camo_group"] = "USUAL_CAMO";	wep["class"] = "smg";		dmcAddPossiblePickup(key, wep);
	wep = []; key = "weapon_p90";		wep["type"] = "weapon";		wep["item"] = "p90";		wep["chance"] = 15;	wep["variant_group"] = "SMG_P90";	wep["camo_group"] = "FREQUENT_CAMO";	wep["class"] = "smg";		dmcAddPossiblePickup(key, wep);
	wep = []; key = "weapon_kriss";		wep["type"] = "weapon";		wep["item"] = "kriss";		wep["chance"] = 16;	wep["variant_group"] = "SMG_KRISS";	wep["camo_group"] = "USUAL_CAMO";	wep["class"] = "smg";		dmcAddPossiblePickup(key, wep);
	wep = []; key = "weapon_ump45";		wep["type"] = "weapon";		wep["item"] = "ump45";		wep["chance"] = 16;	wep["variant_group"] = "SMG_UMP45";	wep["camo_group"] = "ANY_CAMO";		wep["class"] = "smg";		dmcAddPossiblePickup(key, wep);

	//Auto Pistols
	wep = []; key = "weapon_raffica";	wep["type"] = "weapon";		wep["item"] = "beretta393";	wep["chance"] = 5;	wep["variant_group"] = "AP_RAFFICA";	wep["camo_group"] = "NO_CAMO";		wep["class"] = "autopistol";	dmcAddPossiblePickup(key, wep);
	wep = []; key = "weapon_g18";		wep["type"] = "weapon";		wep["item"] = "glock";		wep["chance"] = 5;	wep["variant_group"] = "AP_G18";	wep["camo_group"] = "NO_CAMO";		wep["class"] = "autopistol";	dmcAddPossiblePickup(key, wep);
	wep = []; key = "weapon_pp2000";	wep["type"] = "weapon";		wep["item"] = "pp2000";		wep["chance"] = 5;	wep["variant_group"] = "AP_PP2000";	wep["camo_group"] = "FREQUENT_CAMO";	wep["class"] = "autopistol";	dmcAddPossiblePickup(key, wep);
	wep = []; key = "weapon_tmp";		wep["type"] = "weapon";		wep["item"] = "tmp";		wep["chance"] = 5;	wep["variant_group"] = "AP_TMP";	wep["camo_group"] = "FREQUENT_CAMO";	wep["class"] = "autopistol";	dmcAddPossiblePickup(key, wep);

	//Launchers
	wep = []; key = "weapon_m79";		wep["type"] = "weapon";		wep["item"] = "m79";		wep["chance"] = 3;	wep["variant_group"] = "NO_VARIANT";	wep["camo_group"] = "NO_CAMO";		wep["class"] = "launcher";	dmcAddPossiblePickup(key, wep);
	wep = []; key = "weapon_rpg";		wep["type"] = "weapon";		wep["item"] = "rpg";		wep["chance"] = 3;	wep["variant_group"] = "NO_VARIANT";	wep["camo_group"] = "NO_CAMO";		wep["class"] = "launcher";	dmcAddPossiblePickup(key, wep);
	wep = []; key = "weapon_at4";		wep["type"] = "weapon";		wep["item"] = "at4";		wep["chance"] = 2;	wep["variant_group"] = "NO_VARIANT";	wep["camo_group"] = "NO_CAMO";		wep["class"] = "launcher";	dmcAddPossiblePickup(key, wep);
	wep = []; key = "weapon_stinger";	wep["type"] = "weapon";		wep["item"] = "stinger";	wep["chance"] = 0;	wep["variant_group"] = "NO_VARIANT";	wep["camo_group"] = "NO_CAMO";		wep["class"] = "launcher";	dmcAddPossiblePickup(key, wep);
	wep = []; key = "weapon_javelin";	wep["type"] = "weapon";		wep["item"] = "javelin";	wep["chance"] = 0;	wep["variant_group"] = "NO_VARIANT";	wep["camo_group"] = "NO_CAMO";		wep["class"] = "launcher";	dmcAddPossiblePickup(key, wep);

	//Misc
	wep = []; key = "weapon_deagle";	wep["type"] = "weapon";		wep["item"] = "deserteagle";	wep["chance"] = 0;	wep["variant_group"] = "DEAGLE_AKIMBO";	wep["camo_group"] = "NO_CAMO";		wep["class"] = "misc";		dmcAddPossiblePickup(key, wep);
	wep = []; key = "weapon_knifenoob";	wep["type"] = "weapon";		wep["item"] = "coltanaconda";	wep["chance"] = 0;	wep["variant_group"] = "KNIFE_NOOB";	wep["camo_group"] = "NO_CAMO";		wep["class"] = "misc";		dmcAddPossiblePickup(key, wep);
	wep = []; key = "weapon_riot";		wep["type"] = "weapon";		wep["item"] = "riotshield";	wep["chance"] = 0;	wep["variant_group"] = "NO_VARIANT";	wep["camo_group"] = "NO_CAMO";		wep["class"] = "misc";		dmcAddPossiblePickup(key, wep);
}

dmcChangeChanceByWeaponClass(weapon_class, change, nonrelative) {
	keys = GetArrayKeys(level.aPossiblePickups);
	foreach(key in keys) {
		if(level.aPossiblePickups[key]["type"] != "weapon" || level.aPossiblePickups[key]["class"] != weapon_class || level.aPossiblePickups[key]["chance"] == 0) continue;
		if(isDefined(nonrelative) && nonrelative) level.aPossiblePickups[key]["chance"] = change;
		level.aPossiblePickups[key]["chance"] += change;
	}
}

dmcAddCamoGroup(key, array) {level.aCamoGroups[key] = array;}
dmcInitCamoGroups() {
	//					No camo		Woodland	Desert		Arctic		Digital		Urban		Red Tiger	Blue Tiger	Fall
	//  ----------------------------------+---------------+---------------+---------------+---------------+---------------+---------------+---------------+---------------+------------
	key = "NO_CAMO"; 	grp = [];	grp[0] = 10;	grp[1] = 0;	grp[2] = 0;	grp[3] = 0;	grp[4] = 0;	grp[5] = 0;	grp[6] = 0;	grp[7] = 0;	grp[8] = 0;	dmcAddCamoGroup(key, grp);
	key = "RARE_CAMO"; 	grp = [];	grp[0] = 60;	grp[1] = 1;	grp[2] = 1;	grp[3] = 1;	grp[4] = 1;	grp[5] = 1;	grp[6] = 1;	grp[7] = 1;	grp[8] = 1;	dmcAddCamoGroup(key, grp);
	key = "USUAL_CAMO"; 	grp = [];	grp[0] = 20;	grp[1] = 1;	grp[2] = 1;	grp[3] = 1;	grp[4] = 1;	grp[5] = 1;	grp[6] = 1;	grp[7] = 1;	grp[8] = 1;	dmcAddCamoGroup(key, grp);
	key = "FREQUENT_CAMO"; 	grp = [];	grp[0] = 80;	grp[1] = 10;	grp[2] = 10;	grp[3] = 10;	grp[4] = 10;	grp[5] = 10;	grp[6] = 10;	grp[7] = 10;	grp[8] = 10;	dmcAddCamoGroup(key, grp);
	key = "ANY_CAMO"; 	grp = [];	grp[0] = 1;	grp[1] = 1;	grp[2] = 1;	grp[3] = 1;	grp[4] = 1;	grp[5] = 1;	grp[6] = 1;	grp[7] = 1;	grp[8] = 1;	dmcAddCamoGroup(key, grp);
	key = "PRIORITY_CAMO"; 	grp = [];	grp[0] = 0;	grp[1] = 0;	grp[2] = 0;	grp[3] = 0;	grp[4] = 0;	grp[5] = 0;	grp[6] = 0;	grp[7] = 0;	grp[8] = 0;	dmcAddCamoGroup(key, grp);

	//Chance to get camo'ed weapon
	//NO		= 0,0%
	//RARE		= 11,8%
	//USUAL		= 28,6%
	//FREQUENT	= 50,0%
	//ANY		= 88,9%
}

dmcAddCamoPriority(camo_num, value) {
	if(!isDefined(value)) {
		value = 2;
		if(camo_num > 5) value = 3;
	}
	level.aCamoGroups["PRIORITY_CAMO"][camo_num] = value;
	level.priorityCamoUse = 1;
}

dmcAddVariantGroup(key, array) {level.aVariantGroups[key] = array;}
dmcInitVariantGroups() {
	////////////////////////////////
	// GENERIC
	////////////////////////////////
	key = "NO_VARIANT"; grp = [];
	grp["nothing"] = 1;
	dmcAddVariantGroup(key, grp);

	key = "KNIFE_NOOB"; grp = [];
	grp["tactical"] = 1;
	dmcAddVariantGroup(key, grp);

	key = "DEAGLE_AKIMBO"; grp = [];
	grp["akimbo"] = 1;
	dmcAddVariantGroup(key, grp);

	////////////////////////////////
	// SMG
	////////////////////////////////
	// MP5K                                 UZI (akimbo+)                           P90 (silenced+)                         KRISS                                   UMP45
	// -----------------------------------+---------------------------------------+---------------------------------------+---------------------------------------+-------------------------
	grp1 = [];				grp2 = [];				grp3 = [];				grp4 = [];				grp5 = [];				
	grp1["nothing"] = 10;			grp2["nothing"] = 5;			grp3["nothing"] = 10;			grp4["nothing"] = 10;			grp5["nothing"] = 10;			
	grp1["acog"] = 30;			grp2["acog"] = 5;			grp3["acog"] = 20;			grp4["acog"] = 30;			grp5["acog"] = 30;			
	grp1["akimbo"] = 15;			grp2["akimbo"] = 20;			grp3["akimbo"] = 15;			grp4["akimbo"] = 15;			grp5["akimbo"] = 15;			
	grp1["eotech"] = 30;			grp2["eotech"] = 3;			grp3["eotech"] = 20;			grp4["eotech"] = 30;			grp5["eotech"] = 30;			
	grp1["fmj"] = 1;			grp2["fmj"] = 1;			grp3["fmj"] = 1;			grp4["fmj"] = 1;			grp5["fmj"] = 5;				
	grp1["reflex"] = 50;			grp2["reflex"] = 5;			grp3["reflex"] = 40;			grp4["reflex"] = 50;			grp5["reflex"] = 50;			
	grp1["rof"] = 20;			grp2["rof"] = 20;			grp3["rof"] = 20;			grp4["rof"] = 20;			grp5["rof"] = 20;			
	grp1["silencer"] = 40;			grp2["silencer"] = 10;			grp3["silencer"] = 50;			grp4["silencer"] = 50;			grp5["silencer"] = 40;			
	grp1["thermal"] = 1;			grp2["thermal"] = 1;			grp3["thermal"] = 1;			grp4["thermal"] = 1;			grp5["thermal"] = 1;			
	grp1["xmags"] = 3;			grp2["xmags"] = 1;			grp3["xmags"] = 3;			grp4["xmags"] = 5;			grp5["xmags"] = 3;			
	grp1["acog_fmj"] = 1;			grp2["acog_fmj"] = 0;			grp3["acog_fmj"] = 1;			grp4["acog_fmj"] = 1;			grp5["acog_fmj"] = 1;			
	grp1["acog_rof"] = 1;			grp2["acog_rof"] = 0;			grp3["acog_rof"] = 1;			grp4["acog_rof"] = 1;			grp5["acog_rof"] = 1;			
	grp1["acog_silencer"] = 5;		grp2["acog_silencer"] = 1;		grp3["acog_silencer"] = 5;		grp4["acog_silencer"] = 5;		grp5["acog_silencer"] = 5;		
	grp1["acog_xmags"] = 1;			grp2["acog_xmags"] = 0;			grp3["acog_xmags"] = 1;			grp4["acog_xmags"] = 1;			grp5["acog_xmags"] = 1;			
	grp1["akimbo_fmj"] = 1;			grp2["akimbo_fmj"] = 1;			grp3["akimbo_fmj"] = 1;			grp4["akimbo_fmj"] = 1;			grp5["akimbo_fmj"] = 1;			
	grp1["akimbo_rof"] = 2;			grp2["akimbo_rof"] = 10;		grp3["akimbo_rof"] = 5;			grp4["akimbo_rof"] = 2;			grp5["akimbo_rof"] = 2;			
	grp1["akimbo_silencer"] = 3;		grp2["akimbo_silencer"] = 10;		grp3["akimbo_silencer"] = 3;		grp4["akimbo_silencer"] = 3;		grp5["akimbo_silencer"] = 3;		
	grp1["akimbo_xmags"] = 1;		grp2["akimbo_xmags"] = 5;		grp3["akimbo_xmags"] = 1;		grp4["akimbo_xmags"] = 1;		grp5["akimbo_xmags"] = 1;		
	grp1["eotech_fmj"] = 1;			grp2["eotech_fmj"] = 0;			grp3["eotech_fmj"] = 1;			grp4["eotech_fmj"] = 1;			grp5["eotech_fmj"] = 1;			
	grp1["eotech_rof"] = 1;			grp2["eotech_rof"] = 0;			grp3["eotech_rof"] = 5;			grp4["eotech_rof"] = 1;			grp5["eotech_rof"] = 1;			
	grp1["eotech_silencer"] = 5;		grp2["eotech_silencer"] = 1;		grp3["eotech_silencer"] = 15;		grp4["eotech_silencer"] = 5;		grp5["eotech_silencer"] = 5;		
	grp1["eotech_xmags"] = 1;		grp2["eotech_xmags"] = 0;		grp3["eotech_xmags"] = 1;		grp4["eotech_xmags"] = 1;		grp5["eotech_xmags"] = 1;		
	grp1["fmj_reflex"] = 1;			grp2["fmj_reflex"] = 0;			grp3["fmj_reflex"] = 1;			grp4["fmj_reflex"] = 1;			grp5["fmj_reflex"] = 1;			
	grp1["fmj_rof"] = 1;			grp2["fmj_rof"] = 0;			grp3["fmj_rof"] = 1;			grp4["fmj_rof"] = 1;			grp5["fmj_rof"] = 1;			
	grp1["fmj_silencer"] = 1;		grp2["fmj_silencer"] = 0;		grp3["fmj_silencer"] = 1;		grp4["fmj_silencer"] = 1;		grp5["fmj_silencer"] = 1;		
	grp1["fmj_thermal"] = 1;		grp2["fmj_thermal"] = 0;		grp3["fmj_thermal"] = 1;		grp4["fmj_thermal"] = 1;		grp5["fmj_thermal"] = 1;			
	grp1["fmj_xmags"] = 1;			grp2["fmj_xmags"] = 0;			grp3["fmj_xmags"] = 1;			grp4["fmj_xmags"] = 1;			grp5["fmj_xmags"] = 1;			
	grp1["reflex_rof"] = 4;			grp2["reflex_rof"] = 0;			grp3["reflex_rof"] = 10;		grp4["reflex_rof"] = 4;			grp5["reflex_rof"] = 4;			
	grp1["reflex_silencer"] = 4;		grp2["reflex_silencer"] = 1;		grp3["reflex_silencer"] = 30;		grp4["reflex_silencer"] = 4;		grp5["reflex_silencer"] = 4;		
	grp1["reflex_xmags"] = 1;		grp2["reflex_xmags"] = 0;		grp3["reflex_xmags"] = 1;		grp4["reflex_xmags"] = 1;		grp5["reflex_xmags"] = 1;		
	grp1["rof_silencer"] = 1;		grp2["rof_silencer"] = 1;		grp3["rof_silencer"] = 3;		grp4["rof_silencer"] = 2;		grp5["rof_silencer"] = 1;		
	grp1["rof_thermal"] = 1;		grp2["rof_thermal"] = 1;		grp3["rof_thermal"] = 1;		grp4["rof_thermal"] = 1;		grp5["rof_thermal"] = 1;			
	grp1["rof_xmags"] = 1;			grp2["rof_xmags"] = 1;			grp3["rof_xmags"] = 1;			grp4["rof_xmags"] = 1;			grp5["rof_xmags"] = 1;			
	grp1["silencer_thermal"] = 2;		grp2["silencer_thermal"] = 1;		grp3["silencer_thermal"] = 4;		grp4["silencer_thermal"] = 2;		grp5["silencer_thermal"] = 2;		
	grp1["silencer_xmags"] = 2;		grp2["silencer_xmags"] = 0;		grp3["silencer_xmags"] = 2;		grp4["silencer_xmags"] = 2;		grp5["silencer_xmags"] = 2;		
	grp1["thermal_xmags"] = 1;		grp2["thermal_xmags"] = 0;		grp3["thermal_xmags"] = 1;		grp4["thermal_xmags"] = 1;		grp5["thermal_xmags"] = 1;		
	dmcAddVariantGroup("SMG_MP5K", grp1);	dmcAddVariantGroup("SMG_UZI", grp2);	dmcAddVariantGroup("SMG_P90", grp3);	dmcAddVariantGroup("SMG_KRISS", grp4);	dmcAddVariantGroup("SMG_UMP45", grp5);

	////////////////////////////////
	// Auto Pistols
	////////////////////////////////
	// RAFFICA                              G18 (akimbo+)                           PP2000                                  TMP (attachments+)
	// -----------------------------------+---------------------------------------+---------------------------------------+-----------------------------
	grp1 = [];				grp2 = [];				grp3 = [];				grp4 = [];			
	grp1["nothing"] = 20;			grp2["nothing"] = 10;			grp3["nothing"] = 20;			grp4["nothing"] = 5;		
	grp1["akimbo"] = 10;			grp2["akimbo"] = 20;			grp3["akimbo"] = 5;			grp4["akimbo"] = 5;		
	grp1["eotech"] = 1;			grp2["eotech"] = 1;			grp3["eotech"] = 5;			grp4["eotech"] = 3;		
	grp1["fmj"] = 1;			grp2["fmj"] = 1;			grp3["fmj"] = 1;			grp4["fmj"] = 1;			
	grp1["reflex"] = 3;			grp2["reflex"] = 3;			grp3["reflex"] = 5;			grp4["reflex"] = 5;		
	grp1["silencer"] = 10;			grp2["silencer"] = 20;			grp3["silencer"] = 10;			grp4["silencer"] = 10;		
	grp1["xmags"] = 1;			grp2["xmags"] = 1;			grp3["xmags"] = 1;			grp4["xmags"] = 1;		
	grp1["akimbo_fmj"] = 1;			grp2["akimbo_fmj"] = 3;			grp3["akimbo_fmj"] = 1;			grp4["akimbo_fmj"] = 1;		
	grp1["akimbo_silencer"] = 5;		grp2["akimbo_silencer"] = 15;		grp3["akimbo_silencer"] = 5;		grp4["akimbo_silencer"] = 5;	
	grp1["akimbo_xmags"] = 3;		grp2["akimbo_xmags"] = 5;		grp3["akimbo_xmags"] = 3;		grp4["akimbo_xmags"] = 5;	
	grp1["eotech_fmj"] = 1;			grp2["eotech_fmj"] = 1;			grp3["eotech_fmj"] = 1;			grp4["eotech_fmj"] = 1;		
	grp1["eotech_silencer"] = 1;		grp2["eotech_silencer"] = 2;		grp3["eotech_silencer"] = 1;		grp4["eotech_silencer"] = 1;	
	grp1["eotech_xmags"] = 1;		grp2["eotech_xmags"] = 1;		grp3["eotech_xmags"] = 1;		grp4["eotech_xmags"] = 1;	
	grp1["fmj_reflex"] = 1;			grp2["fmj_reflex"] = 1;			grp3["fmj_reflex"] = 1;			grp4["fmj_reflex"] = 1;		
	grp1["fmj_silencer"] = 1;		grp2["fmj_silencer"] = 1;		grp3["fmj_silencer"] = 1;		grp4["fmj_silencer"] = 1;	
	grp1["fmj_xmags"] = 1;			grp2["fmj_xmags"] = 1;			grp3["fmj_xmags"] = 1;			grp4["fmj_xmags"] = 1;		
	grp1["reflex_silencer"] = 1;		grp2["reflex_silencer"] = 2;		grp3["reflex_silencer"] = 1;		grp4["reflex_silencer"] = 1;	
	grp1["reflex_xmags"] = 1;		grp2["reflex_xmags"] = 1;		grp3["reflex_xmags"] = 1;		grp4["reflex_xmags"] = 1;	
	grp1["silencer_xmags"] = 1;		grp2["silencer_xmags"] = 1;		grp3["silencer_xmags"] = 1;		grp4["silencer_xmags"] = 1;	
	dmcAddVariantGroup("AP_RAFFICA", grp1);	dmcAddVariantGroup("AP_G18", grp2);	dmcAddVariantGroup("AP_PP2000", grp3);	dmcAddVariantGroup("AP_TMP", grp4);

	////////////////////////////////
	// Assault Rifles
	////////////////////////////////
	// AK47                                 M16                                     M4                                      FN2000 (sights-)                        ACR                                     FAMAS                                   FAL                                     SCAR                                    TAR21
	//------------------------------------+---------------------------------------+---------------------------------------+---------------------------------------+---------------------------------------+---------------------------------------+---------------------------------------+---------------------------------------+---------------------------------------
	grp1 = [];				grp2 = [];				grp3 = [];				grp4 = [];				grp5 = [];				grp6 = [];				grp7 = [];				grp8 = [];				grp9 = [];				
	grp1["nothing"] = 20;			grp2["nothing"] = 20;			grp3["nothing"] = 20;			grp4["nothing"] = 20;			grp5["nothing"] = 20;			grp6["nothing"] = 20;			grp7["nothing"] = 20;			grp8["nothing"] = 20;			grp9["nothing"] = 50;			
	grp1["acog"] = 50;			grp2["acog"] = 50;			grp3["acog"] = 50;			grp4["acog"] = 10;			grp5["acog"] = 50;			grp6["acog"] = 50;			grp7["acog"] = 50;			grp8["acog"] = 50;			grp9["acog"] = 50;			
	grp1["eotech"] = 30;			grp2["eotech"] = 30;			grp3["eotech"] = 30;			grp4["eotech"] = 5;			grp5["eotech"] = 30;			grp6["eotech"] = 30;			grp7["eotech"] = 30;			grp8["eotech"] = 30;			grp9["eotech"] = 30;			
	grp1["fmj"] = 5;			grp2["fmj"] = 5;			grp3["fmj"] = 5;			grp4["fmj"] = 5;			grp5["fmj"] = 5;			grp6["fmj"] = 5;			grp7["fmj"] = 5;			grp8["fmj"] = 5;			grp9["fmj"] = 5;			
	grp1["gl"] = 10;			grp2["gl"] = 10;			grp3["gl"] = 10;			grp4["gl"] = 30;			grp5["gl"] = 10;			grp6["gl"] = 10;			grp7["gl"] = 10;			grp8["gl"] = 10;			grp9["gl"] = 10;			
	grp1["heartbeat"] = 5;			grp2["heartbeat"] = 5;			grp3["heartbeat"] = 5;			grp4["heartbeat"] = 5;			grp5["heartbeat"] = 5;			grp6["heartbeat"] = 5;			grp7["heartbeat"] = 5;			grp8["heartbeat"] = 5;			grp9["heartbeat"] = 5;			
	grp1["reflex"] = 50;			grp2["reflex"] = 50;			grp3["reflex"] = 50;			grp4["reflex"] = 10;			grp5["reflex"] = 50;			grp6["reflex"] = 50;			grp7["reflex"] = 50;			grp8["reflex"] = 50;			grp9["reflex"] = 50;			
	grp1["shotgun"] = 1;			grp2["shotgun"] = 1;			grp3["shotgun"] = 1;			grp4["shotgun"] = 1;			grp5["shotgun"] = 1;			grp6["shotgun"] = 2;			grp7["shotgun"] = 1;			grp8["shotgun"] = 2;			grp9["shotgun"] = 1;			
	grp1["silencer"] = 10;			grp2["silencer"] = 10;			grp3["silencer"] = 10;			grp4["silencer"] = 50;			grp5["silencer"] = 10;			grp6["silencer"] = 10;			grp7["silencer"] = 10;			grp8["silencer"] = 10;			grp9["silencer"] = 10;			
	grp1["thermal"] = 5;			grp2["thermal"] = 5;			grp3["thermal"] = 5;			grp4["thermal"] = 5;			grp5["thermal"] = 5;			grp6["thermal"] = 5;			grp7["thermal"] = 5;			grp8["thermal"] = 5;			grp9["thermal"] = 5;			
	grp1["xmags"] = 1;			grp2["xmags"] = 1;			grp3["xmags"] = 1;			grp4["xmags"] = 3;			grp5["xmags"] = 1;			grp6["xmags"] = 1;			grp7["xmags"] = 1;			grp8["xmags"] = 5;			grp9["xmags"] = 1;			
	grp1["acog_fmj"] = 1;			grp2["acog_fmj"] = 1;			grp3["acog_fmj"] = 1;			grp4["acog_fmj"] = 1;			grp5["acog_fmj"] = 1;			grp6["acog_fmj"] = 1;			grp7["acog_fmj"] = 1;			grp8["acog_fmj"] = 1;			grp9["acog_fmj"] = 1;			
	grp1["acog_gl"] = 4;			grp2["acog_gl"] = 4;			grp3["acog_gl"] = 4;			grp4["acog_gl"] = 4;			grp5["acog_gl"] = 4;			grp6["acog_gl"] = 4;			grp7["acog_gl"] = 4;			grp8["acog_gl"] = 4;			grp9["acog_gl"] = 4;			
	grp1["acog_heartbeat"] = 5;		grp2["acog_heartbeat"] = 5;		grp3["acog_heartbeat"] = 5;		grp4["acog_heartbeat"] = 5;		grp5["acog_heartbeat"] = 5;		grp6["acog_heartbeat"] = 5;		grp7["acog_heartbeat"] = 5;		grp8["acog_heartbeat"] = 5;		grp9["acog_heartbeat"] = 5;		
	grp1["acog_shotgun"] = 1;		grp2["acog_shotgun"] = 1;		grp3["acog_shotgun"] = 1;		grp4["acog_shotgun"] = 1;		grp5["acog_shotgun"] = 1;		grp6["acog_shotgun"] = 1;		grp7["acog_shotgun"] = 1;		grp8["acog_shotgun"] = 1;		grp9["acog_shotgun"] = 1;		
	grp1["acog_silencer"] = 5;		grp2["acog_silencer"] = 5;		grp3["acog_silencer"] = 5;		grp4["acog_silencer"] = 5;		grp5["acog_silencer"] = 5;		grp6["acog_silencer"] = 5;		grp7["acog_silencer"] = 5;		grp8["acog_silencer"] = 5;		grp9["acog_silencer"] = 5;		
	grp1["acog_xmags"] = 1;			grp2["acog_xmags"] = 1;			grp3["acog_xmags"] = 1;			grp4["acog_xmags"] = 1;			grp5["acog_xmags"] = 1;			grp6["acog_xmags"] = 1;			grp7["acog_xmags"] = 1;			grp8["acog_xmags"] = 1;			grp9["acog_xmags"] = 1;			
	grp1["eotech_fmj"] = 1;			grp2["eotech_fmj"] = 1;			grp3["eotech_fmj"] = 1;			grp4["eotech_fmj"] = 1;			grp5["eotech_fmj"] = 1;			grp6["eotech_fmj"] = 1;			grp7["eotech_fmj"] = 1;			grp8["eotech_fmj"] = 1;			grp9["eotech_fmj"] = 1;			
	grp1["eotech_gl"] = 2;			grp2["eotech_gl"] = 2;			grp3["eotech_gl"] = 2;			grp4["eotech_gl"] = 2;			grp5["eotech_gl"] = 2;			grp6["eotech_gl"] = 2;			grp7["eotech_gl"] = 2;			grp8["eotech_gl"] = 2;			grp9["eotech_gl"] = 2;			
	grp1["eotech_heartbeat"] = 3;		grp2["eotech_heartbeat"] = 3;		grp3["eotech_heartbeat"] = 3;		grp4["eotech_heartbeat"] = 3;		grp5["eotech_heartbeat"] = 3;		grp6["eotech_heartbeat"] = 3;		grp7["eotech_heartbeat"] = 3;		grp8["eotech_heartbeat"] = 3;		grp9["eotech_heartbeat"] = 3;		
	grp1["eotech_shotgun"] = 1;		grp2["eotech_shotgun"] = 1;		grp3["eotech_shotgun"] = 1;		grp4["eotech_shotgun"] = 1;		grp5["eotech_shotgun"] = 1;		grp6["eotech_shotgun"] = 1;		grp7["eotech_shotgun"] = 1;		grp8["eotech_shotgun"] = 1;		grp9["eotech_shotgun"] = 1;		
	grp1["eotech_silencer"] = 3;		grp2["eotech_silencer"] = 3;		grp3["eotech_silencer"] = 3;		grp4["eotech_silencer"] = 3;		grp5["eotech_silencer"] = 3;		grp6["eotech_silencer"] = 3;		grp7["eotech_silencer"] = 3;		grp8["eotech_silencer"] = 3;		grp9["eotech_silencer"] = 3;		
	grp1["eotech_xmags"] = 1;		grp2["eotech_xmags"] = 1;		grp3["eotech_xmags"] = 1;		grp4["eotech_xmags"] = 1;		grp5["eotech_xmags"] = 1;		grp6["eotech_xmags"] = 1;		grp7["eotech_xmags"] = 1;		grp8["eotech_xmags"] = 1;		grp9["eotech_xmags"] = 1;		
	grp1["fmj_gl"] = 1;			grp2["fmj_gl"] = 1;			grp3["fmj_gl"] = 1;			grp4["fmj_gl"] = 1;			grp5["fmj_gl"] = 1;			grp6["fmj_gl"] = 1;			grp7["fmj_gl"] = 1;			grp8["fmj_gl"] = 1;			grp9["fmj_gl"] = 1;			
	grp1["fmj_heartbeat"] = 1;		grp2["fmj_heartbeat"] = 1;		grp3["fmj_heartbeat"] = 1;		grp4["fmj_heartbeat"] = 1;		grp5["fmj_heartbeat"] = 1;		grp6["fmj_heartbeat"] = 1;		grp7["fmj_heartbeat"] = 1;		grp8["fmj_heartbeat"] = 1;		grp9["fmj_heartbeat"] = 1;		
	grp1["fmj_reflex"] = 1;			grp2["fmj_reflex"] = 1;			grp3["fmj_reflex"] = 1;			grp4["fmj_reflex"] = 1;			grp5["fmj_reflex"] = 1;			grp6["fmj_reflex"] = 1;			grp7["fmj_reflex"] = 1;			grp8["fmj_reflex"] = 1;			grp9["fmj_reflex"] = 1;			
	grp1["fmj_shotgun"] = 1;		grp2["fmj_shotgun"] = 1;		grp3["fmj_shotgun"] = 1;		grp4["fmj_shotgun"] = 1;		grp5["fmj_shotgun"] = 1;		grp6["fmj_shotgun"] = 1;		grp7["fmj_shotgun"] = 1;		grp8["fmj_shotgun"] = 1;		grp9["fmj_shotgun"] = 1;		
	grp1["fmj_silencer"] = 1;		grp2["fmj_silencer"] = 1;		grp3["fmj_silencer"] = 1;		grp4["fmj_silencer"] = 1;		grp5["fmj_silencer"] = 1;		grp6["fmj_silencer"] = 1;		grp7["fmj_silencer"] = 1;		grp8["fmj_silencer"] = 1;		grp9["fmj_silencer"] = 1;		
	grp1["fmj_thermal"] = 1;		grp2["fmj_thermal"] = 1;		grp3["fmj_thermal"] = 1;		grp4["fmj_thermal"] = 1;		grp5["fmj_thermal"] = 1;		grp6["fmj_thermal"] = 1;		grp7["fmj_thermal"] = 1;		grp8["fmj_thermal"] = 1;		grp9["fmj_thermal"] = 1;		
	grp1["fmj_xmags"] = 1;			grp2["fmj_xmags"] = 1;			grp3["fmj_xmags"] = 1;			grp4["fmj_xmags"] = 1;			grp5["fmj_xmags"] = 1;			grp6["fmj_xmags"] = 1;			grp7["fmj_xmags"] = 1;			grp8["fmj_xmags"] = 1;			grp9["fmj_xmags"] = 1;			
	grp1["gl_heartbeat"] = 2;		grp2["gl_heartbeat"] = 2;		grp3["gl_heartbeat"] = 2;		grp4["gl_heartbeat"] = 2;		grp5["gl_heartbeat"] = 2;		grp6["gl_heartbeat"] = 2;		grp7["gl_heartbeat"] = 2;		grp8["gl_heartbeat"] = 2;		grp9["gl_heartbeat"] = 2;		
	grp1["gl_reflex"] = 3;			grp2["gl_reflex"] = 3;			grp3["gl_reflex"] = 3;			grp4["gl_reflex"] = 3;			grp5["gl_reflex"] = 3;			grp6["gl_reflex"] = 3;			grp7["gl_reflex"] = 3;			grp8["gl_reflex"] = 3;			grp9["gl_reflex"] = 3;			
	grp1["gl_silencer"] = 2;		grp2["gl_silencer"] = 2;		grp3["gl_silencer"] = 2;		grp4["gl_silencer"] = 5;		grp5["gl_silencer"] = 2;		grp6["gl_silencer"] = 2;		grp7["gl_silencer"] = 2;		grp8["gl_silencer"] = 2;		grp9["gl_silencer"] = 2;		
	grp1["gl_thermal"] = 2;			grp2["gl_thermal"] = 2;			grp3["gl_thermal"] = 2;			grp4["gl_thermal"] = 2;			grp5["gl_thermal"] = 2;			grp6["gl_thermal"] = 2;			grp7["gl_thermal"] = 2;			grp8["gl_thermal"] = 2;			grp9["gl_thermal"] = 2;			
	grp1["gl_xmags"] = 1;			grp2["gl_xmags"] = 1;			grp3["gl_xmags"] = 1;			grp4["gl_xmags"] = 1;			grp5["gl_xmags"] = 1;			grp6["gl_xmags"] = 1;			grp7["gl_xmags"] = 1;			grp8["gl_xmags"] = 1;			grp9["gl_xmags"] = 1;			
	grp1["heartbeat_reflex"] = 3;		grp2["heartbeat_reflex"] = 3;		grp3["heartbeat_reflex"] = 3;		grp4["heartbeat_reflex"] = 3;		grp5["heartbeat_reflex"] = 3;		grp6["heartbeat_reflex"] = 3;		grp7["heartbeat_reflex"] = 3;		grp8["heartbeat_reflex"] = 3;		grp9["heartbeat_reflex"] = 3;		
	grp1["heartbeat_shotgun"] = 1;		grp2["heartbeat_shotgun"] = 1;		grp3["heartbeat_shotgun"] = 1;		grp4["heartbeat_shotgun"] = 1;		grp5["heartbeat_shotgun"] = 1;		grp6["heartbeat_shotgun"] = 1;		grp7["heartbeat_shotgun"] = 1;		grp8["heartbeat_shotgun"] = 1;		grp9["heartbeat_shotgun"] = 1;		
	grp1["heartbeat_silencer"] = 2;		grp2["heartbeat_silencer"] = 2;		grp3["heartbeat_silencer"] = 2;		grp4["heartbeat_silencer"] = 2;		grp5["heartbeat_silencer"] = 2;		grp6["heartbeat_silencer"] = 2;		grp7["heartbeat_silencer"] = 2;		grp8["heartbeat_silencer"] = 2;		grp9["heartbeat_silencer"] = 2;		
	grp1["heartbeat_thermal"] = 3;		grp2["heartbeat_thermal"] = 3;		grp3["heartbeat_thermal"] = 3;		grp4["heartbeat_thermal"] = 3;		grp5["heartbeat_thermal"] = 3;		grp6["heartbeat_thermal"] = 3;		grp7["heartbeat_thermal"] = 3;		grp8["heartbeat_thermal"] = 3;		grp9["heartbeat_thermal"] = 3;		
	grp1["heartbeat_xmags"] = 1;		grp2["heartbeat_xmags"] = 1;		grp3["heartbeat_xmags"] = 1;		grp4["heartbeat_xmags"] = 1;		grp5["heartbeat_xmags"] = 1;		grp6["heartbeat_xmags"] = 1;		grp7["heartbeat_xmags"] = 1;		grp8["heartbeat_xmags"] = 1;		grp9["heartbeat_xmags"] = 1;		
	grp1["reflex_shotgun"] = 1;		grp2["reflex_shotgun"] = 1;		grp3["reflex_shotgun"] = 1;		grp4["reflex_shotgun"] = 1;		grp5["reflex_shotgun"] = 1;		grp6["reflex_shotgun"] = 1;		grp7["reflex_shotgun"] = 1;		grp8["reflex_shotgun"] = 1;		grp9["reflex_shotgun"] = 1;		
	grp1["reflex_silencer"] = 5;		grp2["reflex_silencer"] = 5;		grp3["reflex_silencer"] = 5;		grp4["reflex_silencer"] = 5;		grp5["reflex_silencer"] = 5;		grp6["reflex_silencer"] = 5;		grp7["reflex_silencer"] = 5;		grp8["reflex_silencer"] = 5;		grp9["reflex_silencer"] = 5;		
	grp1["reflex_xmags"] = 1;		grp2["reflex_xmags"] = 1;		grp3["reflex_xmags"] = 1;		grp4["reflex_xmags"] = 1;		grp5["reflex_xmags"] = 1;		grp6["reflex_xmags"] = 1;		grp7["reflex_xmags"] = 1;		grp8["reflex_xmags"] = 1;		grp9["reflex_xmags"] = 1;		
	grp1["shotgun_silencer"] = 1;		grp2["shotgun_silencer"] = 1;		grp3["shotgun_silencer"] = 1;		grp4["shotgun_silencer"] = 3;		grp5["shotgun_silencer"] = 1;		grp6["shotgun_silencer"] = 1;		grp7["shotgun_silencer"] = 1;		grp8["shotgun_silencer"] = 1;		grp9["shotgun_silencer"] = 1;		
	grp1["shotgun_thermal"] = 1;		grp2["shotgun_thermal"] = 1;		grp3["shotgun_thermal"] = 1;		grp4["shotgun_thermal"] = 1;		grp5["shotgun_thermal"] = 1;		grp6["shotgun_thermal"] = 1;		grp7["shotgun_thermal"] = 1;		grp8["shotgun_thermal"] = 1;		grp9["shotgun_thermal"] = 1;		
	grp1["shotgun_xmags"] = 1;		grp2["shotgun_xmags"] = 1;		grp3["shotgun_xmags"] = 1;		grp4["shotgun_xmags"] = 1;		grp5["shotgun_xmags"] = 1;		grp6["shotgun_xmags"] = 1;		grp7["shotgun_xmags"] = 1;		grp8["shotgun_xmags"] = 1;		grp9["shotgun_xmags"] = 1;		
	grp1["silencer_thermal"] = 4;		grp2["silencer_thermal"] = 4;		grp3["silencer_thermal"] = 4;		grp4["silencer_thermal"] = 4;		grp5["silencer_thermal"] = 4;		grp6["silencer_thermal"] = 4;		grp7["silencer_thermal"] = 4;		grp8["silencer_thermal"] = 4;		grp9["silencer_thermal"] = 4;		
	grp1["silencer_xmags"] = 1;		grp2["silencer_xmags"] = 1;		grp3["silencer_xmags"] = 1;		grp4["silencer_xmags"] = 1;		grp5["silencer_xmags"] = 1;		grp6["silencer_xmags"] = 1;		grp7["silencer_xmags"] = 1;		grp8["silencer_xmags"] = 1;		grp9["silencer_xmags"] = 1;		
	grp1["thermal_xmags"] = 1;		grp2["thermal_xmags"] = 1;		grp3["thermal_xmags"] = 1;		grp4["thermal_xmags"] = 1;		grp5["thermal_xmags"] = 1;		grp6["thermal_xmags"] = 1;		grp7["thermal_xmags"] = 1;		grp8["thermal_xmags"] = 1;		grp9["thermal_xmags"] = 1;		
	dmcAddVariantGroup("AR_AK47", grp1);	dmcAddVariantGroup("AR_M16", grp2);	dmcAddVariantGroup("AR_M4", grp3);	dmcAddVariantGroup("AR_FN2000", grp4);	dmcAddVariantGroup("AR_ACR", grp5);	dmcAddVariantGroup("AR_FAMAS", grp6);	dmcAddVariantGroup("AR_FAL", grp7);	dmcAddVariantGroup("AR_SCAR", grp8);	dmcAddVariantGroup("AR_TAR21", grp9);

	////////////////////////////////
	// Shotguns
	////////////////////////////////
	// STRIKER (sights-)                            AA12                                            M1014                                           SPAS12
	// -------------------------------------------+-----------------------------------------------+-----------------------------------------------+---------------------------------------
	grp1 = [];					grp2 = [];					grp3 = [];					grp4 = [];					
	grp1["nothing"] = 20;				grp2["nothing"] = 30;				grp3["nothing"] = 30;				grp4["nothing"] = 30;				
	grp1["eotech"] = 3;				grp2["eotech"] = 10;				grp3["eotech"] = 10;				grp4["eotech"] = 10;				
	grp1["fmj"] = 1;				grp2["fmj"] = 1;				grp3["fmj"] = 1;				grp4["fmj"] = 1;				
	grp1["grip"] = 50;				grp2["grip"] = 30;				grp3["grip"] = 30;				grp4["grip"] = 30;				
	grp1["reflex"] = 5;				grp2["reflex"] = 20;				grp3["reflex"] = 20;				grp4["reflex"] = 20;				
	grp1["silencer"] = 2;				grp2["silencer"] = 10;				grp3["silencer"] = 10;				grp4["silencer"] = 10;				
	grp1["xmags"] = 3;				grp2["xmags"] = 3;				grp3["xmags"] = 3;				grp4["xmags"] = 3;				
	grp1["eotech_fmj"] = 1;				grp2["eotech_fmj"] = 1;				grp3["eotech_fmj"] = 1;				grp4["eotech_fmj"] = 1;				
	grp1["eotech_grip"] = 1;			grp2["eotech_grip"] = 2;			grp3["eotech_grip"] = 2;			grp4["eotech_grip"] = 2;			
	grp1["eotech_silencer"] = 1;			grp2["eotech_silencer"] = 1;			grp3["eotech_silencer"] = 1;			grp4["eotech_silencer"] = 1;			
	grp1["eotech_xmags"] = 1;			grp2["eotech_xmags"] = 1;			grp3["eotech_xmags"] = 1;			grp4["eotech_xmags"] = 1;			
	grp1["fmj_grip"] = 1;				grp2["fmj_grip"] = 1;				grp3["fmj_grip"] = 1;				grp4["fmj_grip"] = 1;				
	grp1["fmj_reflex"] = 1;				grp2["fmj_reflex"] = 1;				grp3["fmj_reflex"] = 1;				grp4["fmj_reflex"] = 1;				
	grp1["fmj_silencer"] = 1;			grp2["fmj_silencer"] = 1;			grp3["fmj_silencer"] = 1;			grp4["fmj_silencer"] = 1;			
	grp1["fmj_xmags"] = 1;				grp2["fmj_xmags"] = 1;				grp3["fmj_xmags"] = 1;				grp4["fmj_xmags"] = 1;				
	grp1["grip_reflex"] = 5;			grp2["grip_reflex"] = 2;			grp3["grip_reflex"] = 2;			grp4["grip_reflex"] = 2;			
	grp1["grip_silencer"] = 1;			grp2["grip_silencer"] = 1;			grp3["grip_silencer"] = 1;			grp4["grip_silencer"] = 1;			
	grp1["grip_xmags"] = 2;				grp2["grip_xmags"] = 2;				grp3["grip_xmags"] = 2;				grp4["grip_xmags"] = 2;				
	grp1["reflex_silencer"] = 1;			grp2["reflex_silencer"] = 3;			grp3["reflex_silencer"] = 3;			grp4["reflex_silencer"] = 3;			
	grp1["reflex_xmags"] = 1;			grp2["reflex_xmags"] = 1;			grp3["reflex_xmags"] = 1;			grp4["reflex_xmags"] = 1;			
	grp1["silencer_xmags"] = 1;			grp2["silencer_xmags"] = 1;			grp3["silencer_xmags"] = 1;			grp4["silencer_xmags"] = 1;			
	dmcAddVariantGroup("SHOT_STRIKER", grp1);	dmcAddVariantGroup("SHOT_AA12", grp2);		dmcAddVariantGroup("SHOT_M1014", grp3);		dmcAddVariantGroup("SHOT_SPAS12", grp4);

	// RANGER                                       1887
	// -------------------------------------------+----------------------------------------
	grp1 = [];					grp2 = [];					
	grp1["nothing"] = 15;				grp2["nothing"] = 15;				
	grp1["akimbo"] = 10;				grp2["akimbo"] = 10;				
	grp1["fmj"] = 5;				grp2["fmj"] = 5;				
	grp1["akimbo_fmj"] = 3;				grp2["akimbo_fmj"] = 3;				
	dmcAddVariantGroup("SHIT_RANGER", grp1);	dmcAddVariantGroup("SHIT_1887", grp2);


	////////////////////////////////
	// LMG
	////////////////////////////////
	// RPD                                  L86                                     MG4                                     M240                                    AUG
	// -----------------------------------+---------------------------------------+---------------------------------------+---------------------------------------+--------------------------------
	grp1 = [];				grp2 = [];				grp3 = [];				grp4 = [];				grp5 = [];				
	grp1["nothing"] = 20;			grp2["nothing"] = 40;			grp3["nothing"] = 20;			grp4["nothing"] = 20;			grp5["nothing"] = 20;			
	grp1["acog"] = 30;			grp2["acog"] = 30;			grp3["acog"] = 30;			grp4["acog"] = 30;			grp5["acog"] = 30;			
	grp1["eotech"] = 30;			grp2["eotech"] = 10;			grp3["eotech"] = 30;			grp4["eotech"] = 30;			grp5["eotech"] = 30;			
	grp1["fmj"] = 5;			grp2["fmj"] = 5;			grp3["fmj"] = 5;			grp4["fmj"] = 5;			grp5["fmj"] = 5;			
	grp1["grip"] = 30;			grp2["grip"] = 40;			grp3["grip"] = 30;			grp4["grip"] = 30;			grp5["grip"] = 30;			
	grp1["heartbeat"] = 10;			grp2["heartbeat"] = 10;			grp3["heartbeat"] = 10;			grp4["heartbeat"] = 10;			grp5["heartbeat"] = 10;			
	grp1["reflex"] = 50;			grp2["reflex"] = 50;			grp3["reflex"] = 50;			grp4["reflex"] = 50;			grp5["reflex"] = 50;			
	grp1["silencer"] = 20;			grp2["silencer"] = 20;			grp3["silencer"] = 20;			grp4["silencer"] = 20;			grp5["silencer"] = 20;			
	grp1["thermal"] = 10;			grp2["thermal"] = 10;			grp3["thermal"] = 10;			grp4["thermal"] = 10;			grp5["thermal"] = 10;			
	grp1["xmags"] = 1;			grp2["xmags"] = 1;			grp3["xmags"] = 1;			grp4["xmags"] = 1;			grp5["xmags"] = 1;			
	grp1["acog_fmj"] = 1;			grp2["acog_fmj"] = 1;			grp3["acog_fmj"] = 1;			grp4["acog_fmj"] = 1;			grp5["acog_fmj"] = 1;			
	grp1["acog_grip"] = 5;			grp2["acog_grip"] = 5;			grp3["acog_grip"] = 5;			grp4["acog_grip"] = 5;			grp5["acog_grip"] = 5;			
	grp1["acog_heartbeat"] = 5;		grp2["acog_heartbeat"] = 15;		grp3["acog_heartbeat"] = 5;		grp4["acog_heartbeat"] = 5;		grp5["acog_heartbeat"] = 5;		
	grp1["acog_silencer"] = 3;		grp2["acog_silencer"] = 3;		grp3["acog_silencer"] = 3;		grp4["acog_silencer"] = 3;		grp5["acog_silencer"] = 3;		
	grp1["acog_xmags"] = 1;			grp2["acog_xmags"] = 1;			grp3["acog_xmags"] = 1;			grp4["acog_xmags"] = 1;			grp5["acog_xmags"] = 1;			
	grp1["eotech_fmj"] = 1;			grp2["eotech_fmj"] = 1;			grp3["eotech_fmj"] = 1;			grp4["eotech_fmj"] = 1;			grp5["eotech_fmj"] = 1;			
	grp1["eotech_grip"] = 5;		grp2["eotech_grip"] = 5;		grp3["eotech_grip"] = 5;		grp4["eotech_grip"] = 5;		grp5["eotech_grip"] = 5;		
	grp1["eotech_heartbeat"] = 2;		grp2["eotech_heartbeat"] = 2;		grp3["eotech_heartbeat"] = 2;		grp4["eotech_heartbeat"] = 2;		grp5["eotech_heartbeat"] = 2;		
	grp1["eotech_silencer"] = 3;		grp2["eotech_silencer"] = 3;		grp3["eotech_silencer"] = 3;		grp4["eotech_silencer"] = 3;		grp5["eotech_silencer"] = 3;		
	grp1["eotech_xmags"] = 1;		grp2["eotech_xmags"] = 1;		grp3["eotech_xmags"] = 1;		grp4["eotech_xmags"] = 1;		grp5["eotech_xmags"] = 1;		
	grp1["fmj_grip"] = 1;			grp2["fmj_grip"] = 1;			grp3["fmj_grip"] = 1;			grp4["fmj_grip"] = 1;			grp5["fmj_grip"] = 1;			
	grp1["fmj_heartbeat"] = 5;		grp2["fmj_heartbeat"] = 5;		grp3["fmj_heartbeat"] = 5;		grp4["fmj_heartbeat"] = 5;		grp5["fmj_heartbeat"] = 5;		
	grp1["fmj_reflex"] = 1;			grp2["fmj_reflex"] = 1;			grp3["fmj_reflex"] = 1;			grp4["fmj_reflex"] = 1;			grp5["fmj_reflex"] = 1;			
	grp1["fmj_silencer"] = 1;		grp2["fmj_silencer"] = 1;		grp3["fmj_silencer"] = 1;		grp4["fmj_silencer"] = 1;		grp5["fmj_silencer"] = 1;		
	grp1["fmj_thermal"] = 1;		grp2["fmj_thermal"] = 1;		grp3["fmj_thermal"] = 1;		grp4["fmj_thermal"] = 1;		grp5["fmj_thermal"] = 1;		
	grp1["fmj_xmags"] = 1;			grp2["fmj_xmags"] = 1;			grp3["fmj_xmags"] = 1;			grp4["fmj_xmags"] = 1;			grp5["fmj_xmags"] = 1;			
	grp1["grip_heartbeat"] = 1;		grp2["grip_heartbeat"] = 1;		grp3["grip_heartbeat"] = 1;		grp4["grip_heartbeat"] = 1;		grp5["grip_heartbeat"] = 1;		
	grp1["grip_reflex"] = 3;		grp2["grip_reflex"] = 3;		grp3["grip_reflex"] = 3;		grp4["grip_reflex"] = 3;		grp5["grip_reflex"] = 3;		
	grp1["grip_silencer"] = 3;		grp2["grip_silencer"] = 3;		grp3["grip_silencer"] = 3;		grp4["grip_silencer"] = 3;		grp5["grip_silencer"] = 3;		
	grp1["grip_thermal"] = 3;		grp2["grip_thermal"] = 3;		grp3["grip_thermal"] = 3;		grp4["grip_thermal"] = 3;		grp5["grip_thermal"] = 3;		
	grp1["grip_xmags"] = 1;			grp2["grip_xmags"] = 1;			grp3["grip_xmags"] = 1;			grp4["grip_xmags"] = 1;			grp5["grip_xmags"] = 1;			
	grp1["heartbeat_reflex"] = 3;		grp2["heartbeat_reflex"] = 3;		grp3["heartbeat_reflex"] = 3;		grp4["heartbeat_reflex"] = 3;		grp5["heartbeat_reflex"] = 3;		
	grp1["heartbeat_silencer"] = 3;		grp2["heartbeat_silencer"] = 3;		grp3["heartbeat_silencer"] = 3;		grp4["heartbeat_silencer"] = 3;		grp5["heartbeat_silencer"] = 3;		
	grp1["heartbeat_thermal"] = 3;		grp2["heartbeat_thermal"] = 3;		grp3["heartbeat_thermal"] = 3;		grp4["heartbeat_thermal"] = 3;		grp5["heartbeat_thermal"] = 3;		
	grp1["heartbeat_xmags"] = 1;		grp2["heartbeat_xmags"] = 1;		grp3["heartbeat_xmags"] = 1;		grp4["heartbeat_xmags"] = 1;		grp5["heartbeat_xmags"] = 1;		
	grp1["reflex_silencer"] = 5;		grp2["reflex_silencer"] = 5;		grp3["reflex_silencer"] = 5;		grp4["reflex_silencer"] = 5;		grp5["reflex_silencer"] = 5;		
	grp1["reflex_xmags"] = 1;		grp2["reflex_xmags"] = 1;		grp3["reflex_xmags"] = 1;		grp4["reflex_xmags"] = 1;		grp5["reflex_xmags"] = 1;		
	grp1["silencer_thermal"] = 1;		grp2["silencer_thermal"] = 1;		grp3["silencer_thermal"] = 1;		grp4["silencer_thermal"] = 1;		grp5["silencer_thermal"] = 1;		
	grp1["silencer_xmags"] = 1;		grp2["silencer_xmags"] = 1;		grp3["silencer_xmags"] = 1;		grp4["silencer_xmags"] = 1;		grp5["silencer_xmags"] = 1;		
	grp1["thermal_xmags"] = 1;		grp2["thermal_xmags"] = 1;		grp3["thermal_xmags"] = 1;		grp4["thermal_xmags"] = 1;		grp5["thermal_xmags"] = 1;		
	dmcAddVariantGroup("LMG_RPD", grp1);	dmcAddVariantGroup("LMG_L86", grp2);	dmcAddVariantGroup("LMG_MG4", grp3);	dmcAddVariantGroup("LMG_M240", grp4);	dmcAddVariantGroup("LMG_AUG", grp5);

	////////////////////////////////
	// Sniper Rifles
	////////////////////////////////
	// BARRET                               CHEYTAC                                 WA2000 (xmags+)                         M21 (acog+)
	// ------------------------------------------------------------------------------------------------------------------------------------------------
	grp1 = [];				grp2 = [];				grp3 = [];				grp4 = [];				
	grp1["nothing"] = 20;			grp2["nothing"] = 20;			grp3["nothing"] = 30;			grp4["nothing"] = 20;			
	grp1["acog"] = 5;			grp2["acog"] = 5;			grp3["acog"] = 5;			grp4["acog"] = 15;			
	grp1["fmj"] = 10;			grp2["fmj"] = 10;			grp3["fmj"] = 10;			grp4["fmj"] = 10;			
	grp1["heartbeat"] = 5;			grp2["heartbeat"] = 5;			grp3["heartbeat"] = 5;			grp4["heartbeat"] = 5;			
	grp1["silencer"] = 2;			grp2["silencer"] = 1;			grp3["silencer"] = 4;			grp4["silencer"] = 4;			
	grp1["thermal"] = 5;			grp2["thermal"] = 5;			grp3["thermal"] = 5;			grp4["thermal"] = 5;			
	grp1["xmags"] = 1;			grp2["xmags"] = 1;			grp3["xmags"] = 5;			grp4["xmags"] = 1;			
	grp1["acog_fmj"] = 1;			grp2["acog_fmj"] = 1;			grp3["acog_fmj"] = 1;			grp4["acog_fmj"] = 5;			
	grp1["acog_heartbeat"] = 3;		grp2["acog_heartbeat"] = 3;		grp3["acog_heartbeat"] = 3;		grp4["acog_heartbeat"] = 5;		
	grp1["acog_silencer"] = 1;		grp2["acog_silencer"] = 1;		grp3["acog_silencer"] = 1;		grp4["acog_silencer"] = 3;		
	grp1["acog_xmags"] = 1;			grp2["acog_xmags"] = 1;			grp3["acog_xmags"] = 5;			grp4["acog_xmags"] = 5;			
	grp1["fmj_heartbeat"] = 1;		grp2["fmj_heartbeat"] = 1;		grp3["fmj_heartbeat"] = 1;		grp4["fmj_heartbeat"] = 1;		
	grp1["fmj_silencer"] = 1;		grp2["fmj_silencer"] = 1;		grp3["fmj_silencer"] = 1;		grp4["fmj_silencer"] = 1;		
	grp1["fmj_thermal"] = 1;		grp2["fmj_thermal"] = 1;		grp3["fmj_thermal"] = 1;		grp4["fmj_thermal"] = 1;		
	grp1["fmj_xmags"] = 1;			grp2["fmj_xmags"] = 1;			grp3["fmj_xmags"] = 5;			grp4["fmj_xmags"] = 1;			
	grp1["heartbeat_silencer"] = 1;		grp2["heartbeat_silencer"] = 1;		grp3["heartbeat_silencer"] = 1;		grp4["heartbeat_silencer"] = 1;		
	grp1["heartbeat_thermal"] = 2;		grp2["heartbeat_thermal"] = 2;		grp3["heartbeat_thermal"] = 2;		grp4["heartbeat_thermal"] = 2;		
	grp1["heartbeat_xmags"] = 1;		grp2["heartbeat_xmags"] = 1;		grp3["heartbeat_xmags"] = 5;		grp4["heartbeat_xmags"] = 1;		
	grp1["silencer_thermal"] = 1;		grp2["silencer_thermal"] = 1;		grp3["silencer_thermal"] = 1;		grp4["silencer_thermal"] = 1;		
	grp1["silencer_xmags"] = 1;		grp2["silencer_xmags"] = 1;		grp3["silencer_xmags"] = 1;		grp4["silencer_xmags"] = 1;		
	grp1["thermal_xmags"] = 1;		grp2["thermal_xmags"] = 1;		grp3["thermal_xmags"] = 5;		grp4["thermal_xmags"] = 1;		
	dmcAddVariantGroup("SR_BARRET", grp1);	dmcAddVariantGroup("SR_CHEYTAC", grp2);	dmcAddVariantGroup("SR_WA200", grp3);	dmcAddVariantGroup("SR_M21", grp4);
}

// Possible group prefixes: SMG, AP, AR, SHOT, SHIT, LMG, SR
// First char "*" in variant argument means that will be affected all variants not containing this attachment
dmcChangeVariantChance(variant, change, group) {
	if(GetSubStr(variant, 0, 1) == "*") is_not = 1;
	else is_not = 0;
	if(is_not) variant = GetSubStr(variant, 1);

	keys = GetArrayKeys(level.aVariantGroups);
	foreach(key in keys) {
		if((isDefined(group) && !isSubStr(key, group)) || key == "NO_VARIANT") continue;
		keys2 = GetArrayKeys(level.aVariantGroups[key]);
		foreach(key2 in keys2) {
			match = isSubStr(key2, variant);
			if((!is_not && !match) || (is_not && match)) continue;
			level.aVariantGroups[key][key2] += change;
			if(level.aVariantGroups[key][key2] < 0) level.aVariantGroups[key][key2] = 0;
		}
	}
}

dmcInitMapSpecificChanges() {
	dmcAddMandatoryPickups("weapon_deagle", 1);
	dmcAddMandatoryPickups("weapon_knifenoob", 1);

	switch(getDvar("mapname")) {
		case "mp_afghan":
			dmcAddMandatoryPickups("weapon_stinger", 2);
			dmcAddMandatoryPickups("powerup_perks", 3);
			dmcChangeChanceByWeaponClass("assault", 1);
			dmcChangeChanceByWeaponClass("lmg", 1);
			dmcAddCamoPriority(CONST_CAMO_DESERT);
		break;
		case "mp_rust":
			dmcAddMandatoryPickups("weapon_stinger", 1);
			dmcAddMandatoryPickups("powerup_perks", 2);
			dmcChangeChanceByWeaponClass("autopistol", 1);
			dmcChangeChanceByWeaponClass("launcher", 1);
			dmcChangeChanceByWeaponClass("smg", 1);
			dmcChangeChanceByWeaponClass("sniper", -4);
			dmcAddCamoPriority(CONST_CAMO_DESERT);
		break;
		case "mp_terminal":
			dmcAddMandatoryPickups("weapon_stinger", 2);
			dmcAddMandatoryPickups("powerup_perks", 3);
			dmcChangeChanceByWeaponClass("smg", 1);
			dmcChangeChanceByWeaponClass("shotgun", 1);
			dmcAddCamoPriority(CONST_CAMO_NO);
			dmcAddCamoPriority(CONST_CAMO_DIGITAL);
			dmcAddCamoPriority(CONST_CAMO_BLUETIGER);
		break;
		case "mp_boneyard":
			dmcAddMandatoryPickups("weapon_stinger", 1);
			dmcAddMandatoryPickups("powerup_perks", 2);
			dmcChangeChanceByWeaponClass("autopistol", 1);
			dmcChangeChanceByWeaponClass("launcher", 1);
			dmcChangeChanceByWeaponClass("shotgun", 1);
			dmcChangeChanceByWeaponClass("smg", 1);
			dmcAddCamoPriority(CONST_CAMO_NO);
			dmcAddCamoPriority(CONST_CAMO_URBAN);
		break;
		case "mp_favela":
			dmcAddMandatoryPickups("weapon_stinger", 2);
			dmcAddMandatoryPickups("powerup_perks", 3);
			dmcChangeChanceByWeaponClass("shotgun", 1);
			dmcChangeChanceByWeaponClass("smg", 2);
			dmcAddCamoPriority(CONST_CAMO_NO);
			dmcAddCamoPriority(CONST_CAMO_WOODLAND);
		break;
		case "mp_subbase":
			dmcAddMandatoryPickups("weapon_stinger", 2);
			dmcAddMandatoryPickups("powerup_perks", 3);
			dmcChangeChanceByWeaponClass("assault", 2);
			dmcChangeChanceByWeaponClass("lmg", 1);
			dmcAddCamoPriority(CONST_CAMO_ARCTIC);
		break;
		case "mp_highrise":
			dmcAddMandatoryPickups("weapon_stinger", 2);
			dmcAddMandatoryPickups("powerup_perks", 3);
			dmcChangeChanceByWeaponClass("assault", 1);
			dmcAddCamoPriority(CONST_CAMO_REDTIGER);
		break;
		case "mp_nightshift":
			dmcAddMandatoryPickups("weapon_stinger", 2);
			dmcAddMandatoryPickups("powerup_perks", 3);
			dmcChangeChanceByWeaponClass("assault", 1);
			dmcChangeChanceByWeaponClass("shotgun", 1);
			dmcAddCamoPriority(CONST_CAMO_NO);
			dmcAddCamoPriority(CONST_CAMO_DIGITAL);
		break;
		case "mp_underpass":
			dmcAddMandatoryPickups("weapon_stinger", 2);
			dmcAddMandatoryPickups("powerup_perks", 4);
			dmcChangeChanceByWeaponClass("lmg", 1);
			dmcAddCamoPriority(CONST_CAMO_WOODLAND);
			dmcChangeVariantChance("thermal", 5);
		break;
		case "mp_quarry":
			dmcAddMandatoryPickups("weapon_stinger", 2);
			dmcAddMandatoryPickups("powerup_perks", 4);
			dmcChangeChanceByWeaponClass("smg", 1);
			dmcAddCamoPriority(CONST_CAMO_DESERT);
			dmcAddCamoPriority(CONST_CAMO_DIGITAL);
		break;
		case "mp_complex":
			dmcAddMandatoryPickups("weapon_stinger", 2);
			dmcAddMandatoryPickups("powerup_perks", 3);
			dmcChangeChanceByWeaponClass("assault", 1);
			dmcChangeChanceByWeaponClass("lmg", 1);
			dmcAddCamoPriority(CONST_CAMO_DIGITAL);
			dmcAddCamoPriority(CONST_CAMO_WOODLAND);
		break;
		case "mp_estate":
			dmcAddMandatoryPickups("weapon_stinger", 2);
			dmcAddMandatoryPickups("powerup_perks", 3);
			dmcChangeChanceByWeaponClass("sniper", 2);
			dmcChangeChanceByWeaponClass("lmg", 1);
			dmcAddCamoPriority(CONST_CAMO_WOODLAND);
			dmcChangeVariantChance("thermal", 5);
		break;
		case "mp_trailerpark":
			dmcAddMandatoryPickups("weapon_stinger", 2);
			dmcAddMandatoryPickups("powerup_perks", 3);
			dmcChangeChanceByWeaponClass("shotgun", 1);
			dmcChangeChanceByWeaponClass("smg", 1);
			dmcAddCamoPriority(CONST_CAMO_NO);
			dmcAddCamoPriority(CONST_CAMO_WOODLAND);
		break;
		case "mp_vacant":
			dmcAddMandatoryPickups("weapon_stinger", 2);
			dmcAddMandatoryPickups("powerup_perks", 3);
			dmcChangeChanceByWeaponClass("shotgun", 1);
			dmcChangeChanceByWeaponClass("smg", 1);
			dmcAddCamoPriority(CONST_CAMO_DIGITAL);
		break;
		case "mp_invasion":
			dmcAddMandatoryPickups("weapon_stinger", 2);
			dmcAddMandatoryPickups("powerup_perks", 4);
			dmcChangeChanceByWeaponClass("assault", 1);
			dmcChangeChanceByWeaponClass("lmg", 1);
			dmcAddCamoPriority(CONST_CAMO_DESERT);
		break;
		case "mp_brecourt":
			dmcAddMandatoryPickups("weapon_stinger", 3);
			dmcAddMandatoryPickups("powerup_perks", 6);
			dmcChangeChanceByWeaponClass("sniper", 5);
			dmcChangeChanceByWeaponClass("lmg", 1);
			dmcAddCamoPriority(CONST_CAMO_WOODLAND);
			dmcChangeVariantChance("thermal", 5);
			dmcChangeVariantChance("heartbeat", 1);
		break;
		case "mp_compact":
			dmcAddMandatoryPickups("weapon_stinger", 2);
			dmcAddMandatoryPickups("powerup_perks", 3);
			dmcChangeChanceByWeaponClass("shotgun", 1);
			dmcAddCamoPriority(CONST_CAMO_ARCTIC);
		break;
		case "mp_checkpoint":
			dmcAddMandatoryPickups("weapon_stinger", 2);
			dmcAddMandatoryPickups("powerup_perks", 4);
			dmcChangeChanceByWeaponClass("assault", 1);
			dmcChangeChanceByWeaponClass("lmg", 1);
			dmcAddCamoPriority(CONST_CAMO_NO);
		break;
		case "mp_storm":
			dmcAddMandatoryPickups("weapon_stinger", 2);
			dmcAddMandatoryPickups("powerup_perks", 4);
			dmcChangeChanceByWeaponClass("assault", 1);
			dmcAddCamoPriority(CONST_CAMO_NO);
		break;
		case "mp_derail":
			dmcAddMandatoryPickups("weapon_stinger", 3);
			dmcAddMandatoryPickups("powerup_perks", 6);
			dmcChangeChanceByWeaponClass("assault", 1);
			dmcChangeChanceByWeaponClass("sniper", 4);
			dmcChangeChanceByWeaponClass("lmg", 1);
			dmcAddCamoPriority(CONST_CAMO_ARCTIC);
			dmcChangeVariantChance("thermal", 2);
			dmcChangeVariantChance("heartbeat", 4);
		break;
		case "mp_rundown":
			dmcAddMandatoryPickups("weapon_stinger", 2);
			dmcAddMandatoryPickups("powerup_perks", 4);
			dmcChangeChanceByWeaponClass("assault", 1);
			dmcChangeChanceByWeaponClass("lmg", 1);
			dmcAddCamoPriority(CONST_CAMO_NO);
			dmcAddCamoPriority(CONST_CAMO_WOODLAND);
		break;
		case "mp_fuel2":
			dmcAddMandatoryPickups("weapon_stinger", 3);
			dmcAddMandatoryPickups("powerup_perks", 6);
			dmcChangeChanceByWeaponClass("assault", 2);
			dmcChangeChanceByWeaponClass("sniper", 1);
			dmcChangeChanceByWeaponClass("lmg", 1);
			dmcAddCamoPriority(CONST_CAMO_DESERT);
			dmcChangeVariantChance("heartbeat", 4);
		break;
		case "mp_crash":
			dmcAddMandatoryPickups("weapon_stinger", 2);
			dmcAddMandatoryPickups("powerup_perks", 3);
			dmcChangeChanceByWeaponClass("assault", 1);
			dmcChangeChanceByWeaponClass("shotgun", 1);
			dmcChangeChanceByWeaponClass("smg", 1);
			dmcAddCamoPriority(CONST_CAMO_DIGITAL);
		break;
		case "mp_strike":
			dmcAddMandatoryPickups("weapon_stinger", 3);
			dmcAddMandatoryPickups("powerup_perks", 5);
			dmcChangeChanceByWeaponClass("assault", 1);
			dmcAddCamoPriority(CONST_CAMO_NO);
			dmcAddCamoPriority(CONST_CAMO_DESERT);
			dmcAddCamoPriority(CONST_CAMO_WOODLAND);
		break;
		case "mp_abandon":
			dmcAddMandatoryPickups("weapon_stinger", 3);
			dmcAddMandatoryPickups("powerup_perks", 5);
			dmcChangeChanceByWeaponClass("smg", 1);
			dmcAddCamoPriority(CONST_CAMO_WOODLAND);
			dmcAddCamoPriority(CONST_CAMO_REDTIGER);
			dmcChangeVariantChance("heartbeat", 1);
		break;
		case "mp_overgrown":
			dmcAddMandatoryPickups("weapon_stinger", 3);
			dmcAddMandatoryPickups("powerup_perks", 5);
			dmcChangeChanceByWeaponClass("assault", 1);
			dmcAddCamoPriority(CONST_CAMO_WOODLAND);
			dmcChangeVariantChance("thermal", 2);
			dmcChangeVariantChance("heartbeat", 1);
		break;
		default:
			dmcAddMandatoryPickups("weapon_stinger", 1);
			dmcAddMandatoryPickups("powerup_perks", 2);
		break;
	}
}

dmcShuffleMapPosition() {
	usepercent = 0;
	switch(getDvar("mapname")) { //%
		case "mp_afghan":	usepercent = 100; break;
		case "mp_rust":		usepercent = 100; break;
		case "mp_terminal":	usepercent = 90; break;
		case "mp_favela":	usepercent = 90; break;
		case "mp_subbase":	usepercent = 90; break;
		case "mp_boneyard":	usepercent = 90; break;
		case "mp_highrise":	usepercent = 95; break;
		case "mp_nightshift":	usepercent = 80; break;
		case "mp_underpass":	usepercent = 80; break;
		case "mp_quarry":	usepercent = 80; break;
		case "mp_complex":	usepercent = 100; break;
		case "mp_estate":	usepercent = 90; break;
		case "mp_trailerpark":	usepercent = 80; break;
		case "mp_vacant":	usepercent = 90; break;
		case "mp_invasion":	usepercent = 80; break;
		case "mp_brecourt":	usepercent = 90; break;
		case "mp_compact":	usepercent = 90; break;
		case "mp_checkpoint":	usepercent = 80; break;
		case "mp_storm":	usepercent = 70; break;
		case "mp_derail":	usepercent = 80; break;
		case "mp_rundown":	usepercent = 80; break;
		case "mp_fuel2":	usepercent = 80; break;
		case "mp_crash":	usepercent = 90; break;
		case "mp_strike":	usepercent = 70; break;
		case "mp_abandon":	usepercent = 80; break;
		case "mp_overgrown":	usepercent = 90; break;
	}

	level.aTest[level.aTest.size] = "Was: "+level.aMapPositions.size;
	level.aTest[level.aTest.size] = "Percent: "+usepercent;

	shuffled = dmcShuffleArray(level.aMapPositions);
	newsize = Int(level.aMapPositions.size * usepercent / 100);
	level.aMapPositions = [];

	for(i=0;i<newsize;i++) level.aMapPositions[level.aMapPositions.size] = shuffled[i];

	level.aTest[level.aTest.size] = "Now: "+level.aMapPositions.size;
}

dmcInitMapPositions() {
	//Supported: mp_afghan mp_rust mp_terminal mp_favela mp_subbase mp_boneyard mp_highrise mp_nightshift mp_underpass mp_quarry mp_complex mp_estate mp_trailerpark mp_vacant mp_invasion mp_brecourt mp_compact mp_checkpoint mp_storm mp_derail mp_rundown mp_fuel2 mp_crash mp_strike mp_abandon mp_overgrown
	//Unsupported: -
	//Drops: mp_afghan mp_rust mp_terminal mp_favela mp_subbase mp_boneyard mp_highrise mp_nightshift mp_underpass mp_quarry mp_complex mp_estate mp_trailerpark mp_vacant mp_invasion mp_brecourt mp_compact mp_checkpoint mp_storm mp_derail mp_rundown mp_fuel2 mp_crash mp_strike mp_abandon mp_overgrown
	//No drops: -
	//Holo: mp_afghan mp_rust mp_terminal mp_favela mp_subbase mp_boneyard mp_highrise^ mp_nightshift mp_underpass
	//No holo: mp_quarry mp_complex mp_estate mp_trailerpark mp_vacant mp_invasion mp_brecourt mp_compact mp_checkpoint mp_storm mp_derail mp_rundown mp_fuel2 mp_crash mp_strike mp_abandon mp_overgrown

	switch(getDvar("mapname")) {
		case "mp_afghan":
			level.aMapPositions[level.aMapPositions.size] = (2732.77, 945.195, 210.125);
			level.aMapPositions[level.aMapPositions.size] = (3195.39, 350.899, 102.329);
			level.aMapPositions[level.aMapPositions.size] = (2240.3, 53.0634, 146.125);
			level.aMapPositions[level.aMapPositions.size] = (1276.87, 84.0895, -9.83394);
			level.aMapPositions[level.aMapPositions.size] = (2516.31, 919.297, 86.4457);
			level.aMapPositions[level.aMapPositions.size] = (73.221, 2379.16, 170.398);
			level.aMapPositions[level.aMapPositions.size] = (308.183, 3071.69, 223.88);
			level.aMapPositions[level.aMapPositions.size] = (1884.57, 4381.85, 262.125);
			level.aMapPositions[level.aMapPositions.size] = (1583.32, 3342.13, 260.955);
			level.aMapPositions[level.aMapPositions.size] = (2079.74, 2992.58, 295.92);
			level.aMapPositions[level.aMapPositions.size] = (3629.43, 1451.76, 103.25);
			level.aMapPositions[level.aMapPositions.size] = (3739.21, 2319.28, 11.5558);
			level.aMapPositions[level.aMapPositions.size] = (3167.15, 2686.38, 9.96534);
			level.aMapPositions[level.aMapPositions.size] = (2276.07, 2026.59, 19.0977);
			level.aMapPositions[level.aMapPositions.size] = (1621.46, 2111.47, 13.57);
			level.aMapPositions[level.aMapPositions.size] = (925.653, 1541.11, 496.125);
			level.aMapPositions[level.aMapPositions.size] = (2110.89, 1203.5, 105.579);
			level.aMapPositions[level.aMapPositions.size] = (1781.3, 534.613, 80.9615);
			level.aMapPositions[level.aMapPositions.size] = (1343.14, 851.973, 50.2424);
			level.aMapPositions[level.aMapPositions.size] = (1293.04, 1582.75, 80.466);
			level.aMapPositions[level.aMapPositions.size] = (769.48, 1311.05, 151.433);
			level.aMapPositions[level.aMapPositions.size] = (-62.4888, 1741.31, 209.289);
			level.aMapPositions[level.aMapPositions.size] = (-192.154, 1584.46, 214.125);
			level.aMapPositions[level.aMapPositions.size] = (-1254.72, 1703.94, 63.8897);
			level.aMapPositions[level.aMapPositions.size] = (623.171, 90.4333, -7.63846);
			level.aMapPositions[level.aMapPositions.size] = (449.902, -328.655, -11.6494);
			level.aMapPositions[level.aMapPositions.size] = (1777.57, 111.969, 146.125);
			level.aMapPositions[level.aMapPositions.size] = (2118.22, -268.643, 146.125);
			level.aMapPositions[level.aMapPositions.size] = (3182.73, -161.702, 190.125);
			level.aMapPositions[level.aMapPositions.size] = (4485.46, 445.926, 92.455);
			level.aMapPositions[level.aMapPositions.size] = (4074.34, 647.495, 85.6051);
			level.aMapPositions[level.aMapPositions.size] = (3362.82, 828.453, 71.8932);
			level.aMapPositions[level.aMapPositions.size] = (3171.59, 1566.16, 51.2719);
			level.aMapPositions[level.aMapPositions.size] = (3800.07, 1335.83, 166.125);
			level.aMapPositions[level.aMapPositions.size] = (1015.47, 1863.54, 415.423);
			level.aMapPositions[level.aMapPositions.size] = (2330.75, 275.315, 154.639);
			level.aMapPositions[level.aMapPositions.size] = (2238.36, 1256.33, 177.067);
			level.aMapPositions[level.aMapPositions.size] = (2002.42, 1949.72, 5.70062);
			level.aMapPositions[level.aMapPositions.size] = (1652.4, 580.452, 118.723);
			level.aMapPositions[level.aMapPositions.size] = (1812.06, 1355.65, 117.157);
			level.aMapPositions[level.aMapPositions.size] = (960.636, 851.319, 169.221);
			level.aMapPositions[level.aMapPositions.size] = (1055.99, 1819.27, 159.703);
			level.aMapPositions[level.aMapPositions.size] = (17.2085, 1285.26, 190.997);
			level.aMapPositions[level.aMapPositions.size] = (-305.829, -243.346, 78.9452);
			level.aMapPositions[level.aMapPositions.size] = (-691.166, -918.101, -128.341);
			level.aMapPositions[level.aMapPositions.size] = (115.339, -754.125, 65.438);
			level.aMapPositions[level.aMapPositions.size] = (884.703, 103.788, 51.5024);
			level.aMapPositions[level.aMapPositions.size] = (1082.1, -476.306, 99.359);
			level.aMapPositions[level.aMapPositions.size] = (1857.96, -250.802, 146.125);
			level.aMapPositions[level.aMapPositions.size] = (2559.23, 142.308, 138.219);
			level.aMapPositions[level.aMapPositions.size] = (3273.97, 271.332, 154.125);
			level.aMapPositions[level.aMapPositions.size] = (3687.18, 20.7064, 193.486);
			level.aMapPositions[level.aMapPositions.size] = (3996.99, 154.062, 186.125);
			level.aMapPositions[level.aMapPositions.size] = (4032.23, 1056.34, 166.125);
			level.aMapPositions[level.aMapPositions.size] = (3775.5, 1774.75, 110.634);
			level.aMapPositions[level.aMapPositions.size] = (3249.49, 2141.54, 22.0778);
			level.aMapPositions[level.aMapPositions.size] = (2670.29, 2160.72, 22.8085);
			level.aMapPositions[level.aMapPositions.size] = (2503.44, 2764.05, 151.044);
			level.aMapPositions[level.aMapPositions.size] = (4099.79, 2888.33, 142.781);
			level.aMapPositions[level.aMapPositions.size] = (3356.92, 3189.25, 146.576);
			level.aMapPositions[level.aMapPositions.size] = (2971.96, 3366.21, 148.442);
			level.aMapPositions[level.aMapPositions.size] = (1594.82, 3880.77, 261.129);
			level.aMapPositions[level.aMapPositions.size] = (815.415, 3757.57, 286.785);
			level.aMapPositions[level.aMapPositions.size] = (675.819, 2571.87, 291.261);
			level.aMapPositions[level.aMapPositions.size] = (-6.10056, 3275.62, 130.125);
			level.aMapPositions[level.aMapPositions.size] = (-489.751, 2952.18, -9.875);
			level.aMapPositions[level.aMapPositions.size] = (-230.846, 2716.16, 240.786);
			level.aMapPositions[level.aMapPositions.size] = (331.376, 2050.93, 328.599);
			level.aMapPositions[level.aMapPositions.size] = (-1025.51, 1918.64, 287.882);
			level.aMapPositions[level.aMapPositions.size] = (-1114.5, 842.754, 238.565);
			level.aMapPositions[level.aMapPositions.size] = (-817.866, 1183.9, 237.437);
			level.aMapPositions[level.aMapPositions.size] = (-305.385, 1168.22, 321.846);

			//Drops
			level.aDropPositions[level.aDropPositions.size] = (1388.29, 200.102, 6.92983);
			level.aDropPositions[level.aDropPositions.size] = (107.611, -468.045, -31.1325);
			level.aDropPositions[level.aDropPositions.size] = (-547.735, 1108.91, 203.708);
			level.aDropPositions[level.aDropPositions.size] = (84.558, 2290.59, 183.597);
			level.aDropPositions[level.aDropPositions.size] = (1318.37, 3367.64, 270.558);
			level.aDropPositions[level.aDropPositions.size] = (3324.57, 2552.07, -16.4075);
			level.aDropPositions[level.aDropPositions.size] = (3283.38, 796.699, 69.2897);
			level.aDropPositions[level.aDropPositions.size] = (1953.03, 1329.51, 262.935);

			//Holo
			level.aHoloPosition["origin"] = (-219.201, 1557.74, 438.21);
			level.aHoloPosition["angles"] = (0, 180, 0);
		break;
		case "mp_rust":
			level.aMapPositions[level.aMapPositions.size] = (-187.772, 1726.38, -221.081);
			level.aMapPositions[level.aMapPositions.size] = (1107.27, 1354.79, -228.424);
			level.aMapPositions[level.aMapPositions.size] = (305.534, 1372.46, -226.684);
			level.aMapPositions[level.aMapPositions.size] = (-96.2996, 909.238, -229.32);
			level.aMapPositions[level.aMapPositions.size] = (449.302, 819.1, -187.875);
			level.aMapPositions[level.aMapPositions.size] = (909.75, 971.23, -216.473);
			level.aMapPositions[level.aMapPositions.size] = (1093.27, 70.2746, -226.709);
			level.aMapPositions[level.aMapPositions.size] = (1529.08, 56.1862, -223.188);
			level.aMapPositions[level.aMapPositions.size] = (1163.19, -208.394, -216.541);
			level.aMapPositions[level.aMapPositions.size] = (570.862, -177.808, -218.076);
			level.aMapPositions[level.aMapPositions.size] = (-2.05472, -0.186192, -237.875);
			level.aMapPositions[level.aMapPositions.size] = (-226.563, 1412.88, -225.71);
			level.aMapPositions[level.aMapPositions.size] = (788.926, 1193.18, -213.387);
			level.aMapPositions[level.aMapPositions.size] = (643.562, 1185.68, -214.303);
			level.aMapPositions[level.aMapPositions.size] = (630.242, 1793.1, -211.798);
			level.aMapPositions[level.aMapPositions.size] = (853.273, 476.41, -226.762);
			level.aMapPositions[level.aMapPositions.size] = (710.91, 1472.84, -224.006);
			level.aMapPositions[level.aMapPositions.size] = (1315.51, 170.489, -231.33);
			level.aMapPositions[level.aMapPositions.size] = (539.078, 1068.83, 276.422);
			level.aMapPositions[level.aMapPositions.size] = (507.62, 940.505, 185.125);
			level.aMapPositions[level.aMapPositions.size] = (1136.51, 756.498, 7.93072);
			level.aMapPositions[level.aMapPositions.size] = (542.865, 1088.29, 29.332);
			level.aMapPositions[level.aMapPositions.size] = (718.885, 1351.65, 20.8237);
			level.aMapPositions[level.aMapPositions.size] = (990.716, 1645.36, -86.5778);
			level.aMapPositions[level.aMapPositions.size] = (293.45, 963.124, -230.223);
			level.aMapPositions[level.aMapPositions.size] = (-341.24, 1225.55, -220.403);
			level.aMapPositions[level.aMapPositions.size] = (853.968, 687.973, -155.875);
			level.aMapPositions[level.aMapPositions.size] = (595.402, 584.38, -106.735);
			level.aMapPositions[level.aMapPositions.size] = (311.575, 584.72, -186.875);
			level.aMapPositions[level.aMapPositions.size] = (-244.891, 480.806, -202.279);
			level.aMapPositions[level.aMapPositions.size] = (-285.269, -16.0756, -191.975);
			level.aMapPositions[level.aMapPositions.size] = (355.345, -92.0607, -229.875);
			level.aMapPositions[level.aMapPositions.size] = (1599.71, 918.042, -123.111);
			level.aMapPositions[level.aMapPositions.size] = (1280.77, 1324.51, -95.875);
			level.aMapPositions[level.aMapPositions.size] = (290.775, 1629.81, -222.999);
			level.aMapPositions[level.aMapPositions.size] = (124.485, 814.595, -107.875);
			level.aMapPositions[level.aMapPositions.size] = (572.386, 222.329, -231.444);
			level.aMapPositions[level.aMapPositions.size] = (1315.29, -65.4255, -228.221);
			level.aMapPositions[level.aMapPositions.size] = (1458.74, 458.544, -227.978);
			level.aMapPositions[level.aMapPositions.size] = (1417.17, 914.254, -225.343);
			level.aMapPositions[level.aMapPositions.size] = (1665.17, 1654.03, -139.311);
			level.aMapPositions[level.aMapPositions.size] = (612.497, 802.737, -199.172);
			level.aMapPositions[level.aMapPositions.size] = (-440.983, 1798.24, -36.875);
			level.aMapPositions[level.aMapPositions.size] = (-139.426, 1488.32, -118.908);

			//Drops
			level.aDropPositions[level.aDropPositions.size] = (538.793, 1067.28, 276.412);
			level.aDropPositions[level.aDropPositions.size] = (729.645, 1534.14, -234.364);
			level.aDropPositions[level.aDropPositions.size] = (1326.57, 841.129, -220.14);
			level.aDropPositions[level.aDropPositions.size] = (933.69, 246.679, -236.713);
			level.aDropPositions[level.aDropPositions.size] = (70.2166, 223.733, -237.875);
			level.aDropPositions[level.aDropPositions.size] = (62.2479, 1106.26, -229.961);

			//Holo
			level.aHoloPosition["origin"] = (-489.397, 746.178, 168.086);
			level.aHoloPosition["angles"] = (0, 0, 0);
		break;
		case "mp_terminal":
			level.aMapPositions[level.aMapPositions.size] = (2153.25, 3265.42, 58.125);
			level.aMapPositions[level.aMapPositions.size] = (2869.92, 4538.89, 202.125);
			level.aMapPositions[level.aMapPositions.size] = (-78.8801, 5466.6, 203.125);
			level.aMapPositions[level.aMapPositions.size] = (1226.23, 6021.89, 202.125);
			level.aMapPositions[level.aMapPositions.size] = (477.729, 3615.99, 76.125);
			level.aMapPositions[level.aMapPositions.size] = (769.288, 2868.52, 50.125);
			level.aMapPositions[level.aMapPositions.size] = (1540.6, 2466.41, 50.125);
			level.aMapPositions[level.aMapPositions.size] = (397.35, 5204.26, 202.125);
			level.aMapPositions[level.aMapPositions.size] = (-7.32617, 5564.28, 202.125);
			level.aMapPositions[level.aMapPositions.size] = (-476.133, 5728.27, 202.125);
			level.aMapPositions[level.aMapPositions.size] = (1420.31, 7037.82, 202.125);
			level.aMapPositions[level.aMapPositions.size] = (723.888, 7042.18, 202.125);
			level.aMapPositions[level.aMapPositions.size] = (885.969, 5560.5, 202.125);
			level.aMapPositions[level.aMapPositions.size] = (1759.11, 6014.66, 202.125);
			level.aMapPositions[level.aMapPositions.size] = (2303.75, 6289.21, 202.125);
			level.aMapPositions[level.aMapPositions.size] = (1943.72, 4142.69, 58.125);
			level.aMapPositions[level.aMapPositions.size] = (1801.1, 3941.36, 50.125);
			level.aMapPositions[level.aMapPositions.size] = (784.959, 4345.37, 54.125);
			level.aMapPositions[level.aMapPositions.size] = (36.1413, 4248.64, 50.125);
			level.aMapPositions[level.aMapPositions.size] = (2108.74, 3096.8, 50.125);
			level.aMapPositions[level.aMapPositions.size] = (2496.7, 2585.02, 101.125);
			level.aMapPositions[level.aMapPositions.size] = (1492.43, 6683.98, 202.125);
			level.aMapPositions[level.aMapPositions.size] = (82.9341, 6023.34, 202.125);
			level.aMapPositions[level.aMapPositions.size] = (1403.6, 3469.63, 50.125);
			level.aMapPositions[level.aMapPositions.size] = (1843.94, 2471.83, 50.125);
			level.aMapPositions[level.aMapPositions.size] = (1139.9, 4808.37, 202.125);
			level.aMapPositions[level.aMapPositions.size] = (38.2964, 5404.62, 202.125);
			level.aMapPositions[level.aMapPositions.size] = (1712.03, 4107.85, 314.125);
			level.aMapPositions[level.aMapPositions.size] = (2777.18, 5439.13, 202.125);
			level.aMapPositions[level.aMapPositions.size] = (1460.44, 4471.38, 234.125);
			level.aMapPositions[level.aMapPositions.size] = (1785.27, 4035.15, 178.125);
			level.aMapPositions[level.aMapPositions.size] = (1349.93, 4774.75, 54.125);
			level.aMapPositions[level.aMapPositions.size] = (1369.08, 4121.66, 54.125);
			level.aMapPositions[level.aMapPositions.size] = (703.426, 4118.68, 50.125);
			level.aMapPositions[level.aMapPositions.size] = (1549.06, 2991.57, 122.125);
			level.aMapPositions[level.aMapPositions.size] = (2004.09, 3272.37, 130.125);
			level.aMapPositions[level.aMapPositions.size] = (2815.61, 2625.17, 50.125);
			level.aMapPositions[level.aMapPositions.size] = (2749.5, 3096.58, 78.125);
			level.aMapPositions[level.aMapPositions.size] = (2901.56, 3760.72, 90.125);
			level.aMapPositions[level.aMapPositions.size] = (2895.62, 4285.61, 58.125);
			level.aMapPositions[level.aMapPositions.size] = (1956.46, 5040.56, 202.125);
			level.aMapPositions[level.aMapPositions.size] = (2851.17, 5007.12, 202.125);
			level.aMapPositions[level.aMapPositions.size] = (2153.24, 5243.02, 202.125);
			level.aMapPositions[level.aMapPositions.size] = (1070.87, 6445.26, 202.125);
			level.aMapPositions[level.aMapPositions.size] = (1643.05, 5073.29, 202.125);
			level.aMapPositions[level.aMapPositions.size] = (996.785, 5354.55, 202.125);
			level.aMapPositions[level.aMapPositions.size] = (592.19, 5006.35, 202.125);
			level.aMapPositions[level.aMapPositions.size] = (665.108, 4012.32, 212.625);
			level.aMapPositions[level.aMapPositions.size] = (665.501, 3485.31, 212.625);
			level.aMapPositions[level.aMapPositions.size] = (611.601, 2798.34, 212.625);
			level.aMapPositions[level.aMapPositions.size] = (848.319, 3167.06, 50.125);
			level.aMapPositions[level.aMapPositions.size] = (1153.97, 2599.88, 178.125);
			level.aMapPositions[level.aMapPositions.size] = (212.603, 2786.57, 50.125);
			level.aMapPositions[level.aMapPositions.size] = (426.17, 4890.18, 54.125);
			level.aMapPositions[level.aMapPositions.size] = (48.1988, 4852.79, 202.125);
			level.aMapPositions[level.aMapPositions.size] = (-178.579, 6092.56, 202.125);
			level.aMapPositions[level.aMapPositions.size] = (177.809, 6800.04, 202.125);
			level.aMapPositions[level.aMapPositions.size] = (1410.75, 5554.18, 202.125);

			//Drops
			level.aDropPositions[level.aDropPositions.size] = (1028.8, 3599.85, 50.125);
			level.aDropPositions[level.aDropPositions.size] = (202.262, 5121.2, 202.125);
			level.aDropPositions[level.aDropPositions.size] = (863.894, 6152.81, 202.125);
			level.aDropPositions[level.aDropPositions.size] = (2428.97, 5540.29, 234.125);
			level.aDropPositions[level.aDropPositions.size] = (2438.08, 3648.34, 58.125);
			level.aDropPositions[level.aDropPositions.size] = (1586.41, 4593.56, 175.62);
			level.aDropPositions[level.aDropPositions.size] = (2450.14, 5550.31, 234.125);
			level.aDropPositions[level.aDropPositions.size] = (1896.31, 5899.23, 202.125);
			level.aDropPositions[level.aDropPositions.size] = (879.791, 6146.24, 202.125);
			level.aDropPositions[level.aDropPositions.size] = (215.957, 5116.3, 202.125);
			level.aDropPositions[level.aDropPositions.size] = (60.4544, 4319.48, 50.125);
			level.aDropPositions[level.aDropPositions.size] = (251.713, 2816.87, 50.125);
			level.aDropPositions[level.aDropPositions.size] = (1279.7, 3762.34, 50.125);
			level.aDropPositions[level.aDropPositions.size] = (2432.72, 2898.87, 50.125);
			level.aDropPositions[level.aDropPositions.size] = (2433.94, 4062.55, 58.125);

			//Holo
			level.aHoloPosition["origin"] = (1075.32, 4759.88, 284.291);
			level.aHoloPosition["angles"] = (0, -90, 0);
		break;
		case "mp_favela":
			level.aMapPositions[level.aMapPositions.size] = (-444.408, 243.59, 6.18972);
			level.aMapPositions[level.aMapPositions.size] = (-203.845, 180.843, 5.61985);
			level.aMapPositions[level.aMapPositions.size] = (-421.388, -412.896, 16.9794);
			level.aMapPositions[level.aMapPositions.size] = (53.4977, -945.401, 16.125);
			level.aMapPositions[level.aMapPositions.size] = (-898.526, -345.515, 26.125);
			level.aMapPositions[level.aMapPositions.size] = (-1086.64, 1349.94, 194.125);
			level.aMapPositions[level.aMapPositions.size] = (-644.641, 2111.81, 333.025);
			level.aMapPositions[level.aMapPositions.size] = (916.01, 2884.25, 304.067);
			level.aMapPositions[level.aMapPositions.size] = (1488.34, 1619.78, 192.166);
			level.aMapPositions[level.aMapPositions.size] = (227.086, 1032.55, 166.125);
			level.aMapPositions[level.aMapPositions.size] = (1369.78, 155.667, 217.087);
			level.aMapPositions[level.aMapPositions.size] = (-26.8951, -844.57, 314.125);
			level.aMapPositions[level.aMapPositions.size] = (687.473, -509.954, 322.125);
			level.aMapPositions[level.aMapPositions.size] = (740.573, -1167.46, 189.15);
			level.aMapPositions[level.aMapPositions.size] = (1208.85, -1199.91, 198.293);
			level.aMapPositions[level.aMapPositions.size] = (69.909, -437.181, 42.125);
			level.aMapPositions[level.aMapPositions.size] = (-313.618, -424.155, 42.125);
			level.aMapPositions[level.aMapPositions.size] = (1041.87, 389.675, 316.709);
			level.aMapPositions[level.aMapPositions.size] = (-247.993, -200.702, 4.65857);
			level.aMapPositions[level.aMapPositions.size] = (180.349, 245.839, 322.125);
			level.aMapPositions[level.aMapPositions.size] = (-719.275, 872.821, 22.635);
			level.aMapPositions[level.aMapPositions.size] = (361.764, 1008.95, 308.125);
			level.aMapPositions[level.aMapPositions.size] = (999.664, 1196.67, 202.125);
			level.aMapPositions[level.aMapPositions.size] = (1748.74, 986.677, 203.77);
			level.aMapPositions[level.aMapPositions.size] = (937.226, 2407.69, 291.494);
			level.aMapPositions[level.aMapPositions.size] = (214.346, 2891.15, 356.225);
			level.aMapPositions[level.aMapPositions.size] = (-431.484, 2536.81, 346.455);
			level.aMapPositions[level.aMapPositions.size] = (-977.394, 2978.59, 293.975);
			level.aMapPositions[level.aMapPositions.size] = (-1260.31, 2289.12, 294.892);
			level.aMapPositions[level.aMapPositions.size] = (-1471.14, 1665.89, 236.911);
			level.aMapPositions[level.aMapPositions.size] = (-1495.93, 1204.4, 194.125);
			level.aMapPositions[level.aMapPositions.size] = (-1498.19, 1102.49, 242.125);
			level.aMapPositions[level.aMapPositions.size] = (-1784.5, 855.254, 18.125);
			level.aMapPositions[level.aMapPositions.size] = (-1439.27, 492.878, 18.125);
			level.aMapPositions[level.aMapPositions.size] = (-1572.75, 141.625, 18.125);
			level.aMapPositions[level.aMapPositions.size] = (-463.519, 1311.56, 162.125);
			level.aMapPositions[level.aMapPositions.size] = (-439.323, 869.295, 159.48);
			level.aMapPositions[level.aMapPositions.size] = (11.9405, 489.975, 318.125);
			level.aMapPositions[level.aMapPositions.size] = (-645.821, 633.256, 342.867);
			level.aMapPositions[level.aMapPositions.size] = (-38.0471, 248.158, 186.125);
			level.aMapPositions[level.aMapPositions.size] = (198.871, 668.395, 186.125);
			level.aMapPositions[level.aMapPositions.size] = (487.499, 383.131, 17.125);
			level.aMapPositions[level.aMapPositions.size] = (-940.372, -506.165, 16.5384);
			level.aMapPositions[level.aMapPositions.size] = (-692.2, 151.936, 154.125);
			level.aMapPositions[level.aMapPositions.size] = (-590.291, 1058.74, 298.125);
			level.aMapPositions[level.aMapPositions.size] = (-224.644, 1188.06, 317.125);
			level.aMapPositions[level.aMapPositions.size] = (-36.7834, 1571.02, 356.125);
			level.aMapPositions[level.aMapPositions.size] = (-182.018, 1800.58, 341.125);
			level.aMapPositions[level.aMapPositions.size] = (683.956, 2121.47, 177.85);
			level.aMapPositions[level.aMapPositions.size] = (745.013, 1299.65, 354.125);
			level.aMapPositions[level.aMapPositions.size] = (738.665, 1020.89, 354.125);
			level.aMapPositions[level.aMapPositions.size] = (679.614, -249.792, 171.086);
			level.aMapPositions[level.aMapPositions.size] = (566.033, 374.755, 171.437);
			level.aMapPositions[level.aMapPositions.size] = (592.401, -340.723, 18.125);
			level.aMapPositions[level.aMapPositions.size] = (-340.877, -420.342, 178.125);
			level.aMapPositions[level.aMapPositions.size] = (569.79, -415.338, 178.125);
			level.aMapPositions[level.aMapPositions.size] = (64.4577, -828.974, 182.125);
			level.aMapPositions[level.aMapPositions.size] = (64.0761, -788.33, 42.125);
			level.aMapPositions[level.aMapPositions.size] = (-674.779, -393.04, 162.125);
			level.aMapPositions[level.aMapPositions.size] = (-1101.9, 963.886, 195.125);

			//Drops
			level.aDropPositions[level.aDropPositions.size] = (-17.6494, 557.196, 318.125);
			level.aDropPositions[level.aDropPositions.size] = (146.64, 839.868, 202.125);
			level.aDropPositions[level.aDropPositions.size] = (-5.98336, -84.6647, 4.12488);
			level.aDropPositions[level.aDropPositions.size] = (1275.5, 1595.14, 199.578);
			level.aDropPositions[level.aDropPositions.size] = (693.401, 2418.39, 291.28);
			level.aDropPositions[level.aDropPositions.size] = (-986.413, 2330.47, 293.555);
			level.aDropPositions[level.aDropPositions.size] = (-1217.87, 270.78, 12.074);
			level.aDropPositions[level.aDropPositions.size] = (-685.67, -843.166, 34.8249);
			level.aDropPositions[level.aDropPositions.size] = (60.1713, -551.729, 314.125);
			level.aDropPositions[level.aDropPositions.size] = (949.861, -779.907, 205.873);
			level.aDropPositions[level.aDropPositions.size] = (616.84, 239.747, 170.277);

			//Holo
			level.aHoloPosition["origin"] = (-1852.2, -415.991, 583.378);
			level.aHoloPosition["angles"] = (0, 30.5098, 0);
		break;
		case "mp_subbase":
			level.aMapPositions[level.aMapPositions.size] = (1001.45, 333.112, 186.125);
			level.aMapPositions[level.aMapPositions.size] = (818.805, 292.906, 326.691);
			level.aMapPositions[level.aMapPositions.size] = (-275.861, 414.633, 287.125);
			level.aMapPositions[level.aMapPositions.size] = (1272.62, -83.6306, 234.125);
			level.aMapPositions[level.aMapPositions.size] = (1153.26, -225.944, 90.125);
			level.aMapPositions[level.aMapPositions.size] = (1429.78, -730.254, 21.9875);
			level.aMapPositions[level.aMapPositions.size] = (1063.38, -874.014, 103.174);
			level.aMapPositions[level.aMapPositions.size] = (1063.67, -220.954, 118.499);
			level.aMapPositions[level.aMapPositions.size] = (-275.644, 529.666, 45.5146);
			level.aMapPositions[level.aMapPositions.size] = (2103.39, 828.343, 51.3503);
			level.aMapPositions[level.aMapPositions.size] = (1062.15, 1072.89, 49.6391);
			level.aMapPositions[level.aMapPositions.size] = (372.316, 1376.88, 48.1522);
			level.aMapPositions[level.aMapPositions.size] = (694.388, 1668.39, 42.125);
			level.aMapPositions[level.aMapPositions.size] = (991.096, 1311.21, 42.125);
			level.aMapPositions[level.aMapPositions.size] = (2570.94, 1818.81, 67.4715);
			level.aMapPositions[level.aMapPositions.size] = (-887.546, -1811.86, 79.625);
			level.aMapPositions[level.aMapPositions.size] = (1161.22, -1007.15, 282.125);
			level.aMapPositions[level.aMapPositions.size] = (369.67, -1243, 66.125);
			level.aMapPositions[level.aMapPositions.size] = (1046.57, -2054.02, 10.0251);
			level.aMapPositions[level.aMapPositions.size] = (343.253, -2126.91, 14.3265);
			level.aMapPositions[level.aMapPositions.size] = (-100.977, -2525.6, 18.7719);
			level.aMapPositions[level.aMapPositions.size] = (-1040.06, -2215.85, 10.125);
			level.aMapPositions[level.aMapPositions.size] = (-99.1807, -1383, 94.125);
			level.aMapPositions[level.aMapPositions.size] = (-264.452, -1271.2, 58.125);
			level.aMapPositions[level.aMapPositions.size] = (-1476.8, -470.515, 131.98);
			level.aMapPositions[level.aMapPositions.size] = (-718.768, -202.986, 195.125);
			level.aMapPositions[level.aMapPositions.size] = (84.1536, 866.122, 43.125);
			level.aMapPositions[level.aMapPositions.size] = (154.683, 1223, 55.1174);
			level.aMapPositions[level.aMapPositions.size] = (460.306, 721.659, 47.4484);
			level.aMapPositions[level.aMapPositions.size] = (1320.39, 609.154, 24.3662);
			level.aMapPositions[level.aMapPositions.size] = (-843.577, -2715.71, 10.125);
			level.aMapPositions[level.aMapPositions.size] = (-236.982, -3792.52, 10.125);
			level.aMapPositions[level.aMapPositions.size] = (-470.803, -3139.48, 22.1364);
			level.aMapPositions[level.aMapPositions.size] = (1748.68, -2292.25, 20.0197);
			level.aMapPositions[level.aMapPositions.size] = (-279.214, -232.203, 105.819);
			level.aMapPositions[level.aMapPositions.size] = (-170.181, -2036.16, 58.125);
			level.aMapPositions[level.aMapPositions.size] = (-1574.25, -2152.84, 51.1123);
			level.aMapPositions[level.aMapPositions.size] = (-1439.72, -2514.44, 49.6639);
			level.aMapPositions[level.aMapPositions.size] = (-1499.61, -1827.51, 10.125);
			level.aMapPositions[level.aMapPositions.size] = (-1508.27, -1026.03, 130.125);
			level.aMapPositions[level.aMapPositions.size] = (-1500.68, 778.081, 122.597);
			level.aMapPositions[level.aMapPositions.size] = (-750.82, 1182.02, 106.521);
			level.aMapPositions[level.aMapPositions.size] = (1409.01, 1814.07, 58.915);
			level.aMapPositions[level.aMapPositions.size] = (480.68, 206.811, 107.125);
			level.aMapPositions[level.aMapPositions.size] = (-672.911, 627.38, 99.125);
			level.aMapPositions[level.aMapPositions.size] = (1138.45, -1472.66, 27.5944);
			level.aMapPositions[level.aMapPositions.size] = (1824.16, -707.417, 10.4117);
			level.aMapPositions[level.aMapPositions.size] = (1497.19, -348.147, 58.125);
			level.aMapPositions[level.aMapPositions.size] = (-79.4192, 182.189, 322.125);
			level.aMapPositions[level.aMapPositions.size] = (13.2618, -345.742, 99.2581);
			level.aMapPositions[level.aMapPositions.size] = (-258.964, -879.486, 111.182);
			level.aMapPositions[level.aMapPositions.size] = (1056.36, -1413.31, 316.125);
			level.aMapPositions[level.aMapPositions.size] = (406.906, -1446.77, 282.125);
			level.aMapPositions[level.aMapPositions.size] = (-474.288, -1537.19, 273.092);
			level.aMapPositions[level.aMapPositions.size] = (-1516.27, -1027.55, 266.125);
			level.aMapPositions[level.aMapPositions.size] = (-941.894, -1382.46, 10.125);
			level.aMapPositions[level.aMapPositions.size] = (-1412.2, 1152.59, 107.719);
			level.aMapPositions[level.aMapPositions.size] = (-556.256, -212.896, 99.125);
			level.aMapPositions[level.aMapPositions.size] = (1238.95, 1406.73, 46.125);
			level.aMapPositions[level.aMapPositions.size] = (1840.52, 1821.09, 62.7914);

			//Drops
			level.aDropPositions[level.aDropPositions.size] = (1698.35, -738.01, 10.125);
			level.aDropPositions[level.aDropPositions.size] = (370.928, 608.074, 42.125);
			level.aDropPositions[level.aDropPositions.size] = (-1174.22, -318.996, 130.125);
			level.aDropPositions[level.aDropPositions.size] = (-290.658, -594.935, 112.125);
			level.aDropPositions[level.aDropPositions.size] = (862.591, -527.485, 98.125);
			level.aDropPositions[level.aDropPositions.size] = (935.055, -2199.77, 10.125);
			level.aDropPositions[level.aDropPositions.size] = (-850.581, -2284.38, 10.5811);

			//Holo
			level.aHoloPosition["origin"] = (263.047, -2168.13, 139.118);
			level.aHoloPosition["angles"] = (0, -90, 0);
		break;
		case "mp_boneyard":
			level.aMapPositions[level.aMapPositions.size] = (955.181, 245.964, -126.647);
			level.aMapPositions[level.aMapPositions.size] = (-1312.37, 456.683, -117.875);
			level.aMapPositions[level.aMapPositions.size] = (-1318.29, 818.117, -117.875);
			level.aMapPositions[level.aMapPositions.size] = (-294.551, 520.41, -115.245);
			level.aMapPositions[level.aMapPositions.size] = (-913.591, -385.638, -117.375);
			level.aMapPositions[level.aMapPositions.size] = (-184.501, -300.433, -129.875);
			level.aMapPositions[level.aMapPositions.size] = (530.54, -9.42481, -52.875);
			level.aMapPositions[level.aMapPositions.size] = (1732.91, 547.277, -166.279);
			level.aMapPositions[level.aMapPositions.size] = (14.7335, 706.922, -57.375);
			level.aMapPositions[level.aMapPositions.size] = (1731.76, -16.9887, -186.608);
			level.aMapPositions[level.aMapPositions.size] = (1266.03, 423.294, -165.686);
			level.aMapPositions[level.aMapPositions.size] = (564.421, 601.536, -96.572);
			level.aMapPositions[level.aMapPositions.size] = (1256.88, -28.2147, -133.481);
			level.aMapPositions[level.aMapPositions.size] = (321.013, -305.58, -125.875);
			level.aMapPositions[level.aMapPositions.size] = (-166.045, -691.292, -120.436);
			level.aMapPositions[level.aMapPositions.size] = (-570.459, -694.186, -119.406);
			level.aMapPositions[level.aMapPositions.size] = (-338.707, 45.1067, -59.3806);
			level.aMapPositions[level.aMapPositions.size] = (300.882, 528.613, -107.865);
			level.aMapPositions[level.aMapPositions.size] = (-718.9, 249.323, -115.479);
			level.aMapPositions[level.aMapPositions.size] = (-1214.02, 327.106, -125.297);
			level.aMapPositions[level.aMapPositions.size] = (-1400.1, -693.413, -117.875);
			level.aMapPositions[level.aMapPositions.size] = (-1666.11, -258.923, -117.875);
			level.aMapPositions[level.aMapPositions.size] = (-1308.2, -82.9111, -117.875);
			level.aMapPositions[level.aMapPositions.size] = (-1730.05, -101.924, 16.125);
			level.aMapPositions[level.aMapPositions.size] = (-1301.88, -95.6403, 152.125);
			level.aMapPositions[level.aMapPositions.size] = (-1726.3, 824.043, 152.125);
			level.aMapPositions[level.aMapPositions.size] = (-1732.17, 743.682, -117.875);
			level.aMapPositions[level.aMapPositions.size] = (428.666, 687.61, -111.494);
			level.aMapPositions[level.aMapPositions.size] = (20.2223, 919.26, 19.1512);
			level.aMapPositions[level.aMapPositions.size] = (-1660.2, 913.06, -120.138);
			level.aMapPositions[level.aMapPositions.size] = (-1730.88, 1638.87, -102.413);
			level.aMapPositions[level.aMapPositions.size] = (-745.3, 1630.03, -118.654);
			level.aMapPositions[level.aMapPositions.size] = (-40.5911, 1283.42, -61.875);
			level.aMapPositions[level.aMapPositions.size] = (287.167, 1590.59, -61.875);
			level.aMapPositions[level.aMapPositions.size] = (875.564, 1212.82, 25.125);
			level.aMapPositions[level.aMapPositions.size] = (774.372, 1143.43, -51.0944);
			level.aMapPositions[level.aMapPositions.size] = (1365.64, 1026.9, -69.5726);
			level.aMapPositions[level.aMapPositions.size] = (943.728, 1453.35, -76.9143);
			level.aMapPositions[level.aMapPositions.size] = (1957.48, 1655.56, -89.0118);
			level.aMapPositions[level.aMapPositions.size] = (1956.08, 1004.84, -126.201);
			level.aMapPositions[level.aMapPositions.size] = (1729.47, 688.127, -7.875);
			level.aMapPositions[level.aMapPositions.size] = (2284.91, 274.678, -7.875);
			level.aMapPositions[level.aMapPositions.size] = (1950.56, 557.255, -141.875);
			level.aMapPositions[level.aMapPositions.size] = (2300.05, -17.0005, -141.875);
			level.aMapPositions[level.aMapPositions.size] = (2106.4, 745.278, -141.875);
			level.aMapPositions[level.aMapPositions.size] = (2322.92, 257.51, -141.875);
			level.aMapPositions[level.aMapPositions.size] = (1947.01, -599.347, -166.197);
			level.aMapPositions[level.aMapPositions.size] = (2216.22, -237.053, -186.149);

			//Drops
			level.aDropPositions[level.aDropPositions.size] = (694.987, 231.429, -108.527);
			level.aDropPositions[level.aDropPositions.size] = (-635.103, -390.546, -129.875);
			level.aDropPositions[level.aDropPositions.size] = (-412.133, 375.513, -118.763);
			level.aDropPositions[level.aDropPositions.size] = (-1298.28, 1120.33, -121.509);
			level.aDropPositions[level.aDropPositions.size] = (-10.4627, 916.735, 18.9776);
			level.aDropPositions[level.aDropPositions.size] = (1063.42, 827.628, -129.389);
			level.aDropPositions[level.aDropPositions.size] = (1776.67, -187.668, -174.927);

			//Holo
			level.aHoloPosition["origin"] = (459.3, -239.868, 28.2875);
			level.aHoloPosition["angles"] = (0, 90, 0);
		break;
		case "mp_highrise":
			level.aMapPositions[level.aMapPositions.size] = (74.5502, 5815.08, 2786.13);
			level.aMapPositions[level.aMapPositions.size] = (-3039.77, 6401.99, 2834.13);
			level.aMapPositions[level.aMapPositions.size] = (-3592.48, 6531.82, 2834.13);
			level.aMapPositions[level.aMapPositions.size] = (-3535.41, 5759.43, 2834.13);
			level.aMapPositions[level.aMapPositions.size] = (-3375.56, 5372.57, 2834.13);
			level.aMapPositions[level.aMapPositions.size] = (-3180.8, 6083.98, 2834.13);
			level.aMapPositions[level.aMapPositions.size] = (-3082.25, 5142.09, 2834.13);
			level.aMapPositions[level.aMapPositions.size] = (-3226.36, 5601.5, 2834.13);
			level.aMapPositions[level.aMapPositions.size] = (-3870.31, 5152.91, 2834.13);
			level.aMapPositions[level.aMapPositions.size] = (-1636.99, 8479.79, 3290.13);
			level.aMapPositions[level.aMapPositions.size] = (679.537, 7607.37, 2834.13);
			level.aMapPositions[level.aMapPositions.size] = (1043.58, 7371.01, 2834.13);
			level.aMapPositions[level.aMapPositions.size] = (1167.69, 7572.37, 2834.13);
			level.aMapPositions[level.aMapPositions.size] = (1621.38, 7445.37, 2834.13);
			level.aMapPositions[level.aMapPositions.size] = (1226.12, 7061.16, 2834.13);
			level.aMapPositions[level.aMapPositions.size] = (28.1629, 6243.12, 2834.13);
			level.aMapPositions[level.aMapPositions.size] = (220.251, 6484.66, 2834.13);
			level.aMapPositions[level.aMapPositions.size] = (688.144, 6745.67, 2922.63);
			level.aMapPositions[level.aMapPositions.size] = (-1931.34, 6557.82, 2786.13);
			level.aMapPositions[level.aMapPositions.size] = (-1980.31, 5827.92, 2786.13);
			level.aMapPositions[level.aMapPositions.size] = (-1570.68, 5085.09, 2636.25);
			level.aMapPositions[level.aMapPositions.size] = (-309.796, 5685.97, 2922.13);
			level.aMapPositions[level.aMapPositions.size] = (659.311, 6307.51, 2818.13);
			level.aMapPositions[level.aMapPositions.size] = (567.743, 6805.34, 2834.13);
			level.aMapPositions[level.aMapPositions.size] = (13.1976, 5926.13, 3030.13);
			level.aMapPositions[level.aMapPositions.size] = (78.1806, 7460.64, 3061.13);
			level.aMapPositions[level.aMapPositions.size] = (-885.905, 6848.51, 2658.13);
			level.aMapPositions[level.aMapPositions.size] = (-1278.33, 7853.74, 2884.13);
			level.aMapPositions[level.aMapPositions.size] = (-1256.75, 6560.42, 3052.13);
			level.aMapPositions[level.aMapPositions.size] = (918.798, 6961.6, 2658.13);
			level.aMapPositions[level.aMapPositions.size] = (291.435, 6904.62, 2658.13);
			level.aMapPositions[level.aMapPositions.size] = (-502.299, 6658.31, 2658.13);
			level.aMapPositions[level.aMapPositions.size] = (-360.428, 7100, 2658.13);
			level.aMapPositions[level.aMapPositions.size] = (-1867.19, 7175.13, 2786.13);
			level.aMapPositions[level.aMapPositions.size] = (-1383.32, 5614.77, 2986.13);
			level.aMapPositions[level.aMapPositions.size] = (-1190.76, 7647.78, 2773.13);
			level.aMapPositions[level.aMapPositions.size] = (-1137.35, 7381.7, 2954.13);
			level.aMapPositions[level.aMapPositions.size] = (-695.395, 5798.36, 2786.13);
			level.aMapPositions[level.aMapPositions.size] = (-1367.04, 6667.23, 2788.28);
			level.aMapPositions[level.aMapPositions.size] = (-1274.92, 6299.97, 2786.13);
			level.aMapPositions[level.aMapPositions.size] = (-496.976, 6587.21, 2786.13);
			level.aMapPositions[level.aMapPositions.size] = (-108.67, 6114.76, 2786.13);
			level.aMapPositions[level.aMapPositions.size] = (-1183.47, 6152.97, 2786.13);
			level.aMapPositions[level.aMapPositions.size] = (-244.757, 5565.24, 2786.13);
			level.aMapPositions[level.aMapPositions.size] = (-108.355, 5386.55, 2786.13);
			level.aMapPositions[level.aMapPositions.size] = (-1171.82, 5191.16, 2786.13);
			level.aMapPositions[level.aMapPositions.size] = (-1274.29, 5508.14, 2786.13);
			level.aMapPositions[level.aMapPositions.size] = (-1003.54, 6988.95, 2801.32);
			level.aMapPositions[level.aMapPositions.size] = (-1273.93, 6160.58, 2658.13);
			level.aMapPositions[level.aMapPositions.size] = (-2205.61, 6544.48, 2658.13);
			level.aMapPositions[level.aMapPositions.size] = (-1448.4, 6848.86, 2706.12);
			level.aMapPositions[level.aMapPositions.size] = (-3831.19, 5880.65, 2834.13);
			level.aMapPositions[level.aMapPositions.size] = (-2992.75, 7167.77, 2658.13);
			level.aMapPositions[level.aMapPositions.size] = (-2416.54, 6883.78, 2658.13);
			level.aMapPositions[level.aMapPositions.size] = (-2605.67, 5362.8, 2802.13);
			level.aMapPositions[level.aMapPositions.size] = (-2429.12, 6063.56, 2786.13);
			level.aMapPositions[level.aMapPositions.size] = (-2186.7, 7208.88, 2658.13);
			level.aMapPositions[level.aMapPositions.size] = (-1551.35, 5550.39, 2786.13);
			level.aMapPositions[level.aMapPositions.size] = (-1868.8, 6019.06, 2786.13);
			level.aMapPositions[level.aMapPositions.size] = (-1802.95, 7462.42, 2786.13);
			level.aMapPositions[level.aMapPositions.size] = (-2198.81, 6125.24, 2786.13);
			level.aMapPositions[level.aMapPositions.size] = (-2325.67, 6654, 2786.13);
			level.aMapPositions[level.aMapPositions.size] = (-2776.66, 6918.47, 2786.13);
			level.aMapPositions[level.aMapPositions.size] = (-1071.12, 7438.53, 2786.13);
			level.aMapPositions[level.aMapPositions.size] = (-2911.84, 7210.07, 2834.13);
			level.aMapPositions[level.aMapPositions.size] = (-3793.59, 7195.3, 2834.13);
			level.aMapPositions[level.aMapPositions.size] = (-3628.52, 6874.59, 2834.13);
			level.aMapPositions[level.aMapPositions.size] = (-3653.11, 6073.97, 2834.13);
			level.aMapPositions[level.aMapPositions.size] = (-3176.26, 6205.98, 2834.13);
			level.aMapPositions[level.aMapPositions.size] = (-2680.5, 6781.43, 2834.13);
			level.aMapPositions[level.aMapPositions.size] = (-2681.06, 5914.83, 2834.13);
			level.aMapPositions[level.aMapPositions.size] = (-3138.26, 5588.93, 2834.13);
			level.aMapPositions[level.aMapPositions.size] = (766.161, 6823.7, 2834.13);
			level.aMapPositions[level.aMapPositions.size] = (-3220.62, 5781.83, 2834.13);
			level.aMapPositions[level.aMapPositions.size] = (25.764, 6804.28, 2834.13);
			level.aMapPositions[level.aMapPositions.size] = (628.147, 5967.35, 2834.13);
			level.aMapPositions[level.aMapPositions.size] = (-0.881554, 5923.94, 2834.13);
			level.aMapPositions[level.aMapPositions.size] = (187.859, 5215.99, 2834.13);
			level.aMapPositions[level.aMapPositions.size] = (748.829, 7219.72, 2834.13);

			//Drops
			level.aDropPositions[level.aDropPositions.size] = (-1341.21, 6179.68, 2986.13);
			level.aDropPositions[level.aDropPositions.size] = (-1385.74, 5583.73, 2986.13);
			level.aDropPositions[level.aDropPositions.size] = (-1788.64, 5875.65, 2786.13);
			level.aDropPositions[level.aDropPositions.size] = (-2549.75, 7039.26, 2786.13);
			level.aDropPositions[level.aDropPositions.size] = (-1162.39, 7275.65, 2786.13);
			level.aDropPositions[level.aDropPositions.size] = (-1865.18, 6801.98, 2706.12);
			level.aDropPositions[level.aDropPositions.size] = (-702.826, 6844.49, 2746.13);
			level.aDropPositions[level.aDropPositions.size] = (-179.434, 6954.69, 2786.13);
			level.aDropPositions[level.aDropPositions.size] = (-927.964, 6482.02, 2786.13);
			level.aDropPositions[level.aDropPositions.size] = (-665.864, 5666.8, 2786.13);
			level.aDropPositions[level.aDropPositions.size] = (-2360.3, 5682.55, 2786.13);
			level.aDropPositions[level.aDropPositions.size] = (-2243.67, 6461.47, 2786.13);

			//Holo
			//level.aHoloPosition["origin"] = (-69.0602, 6371.8, 3187.87);
			//level.aHoloPosition["angles"] = (0, -180, 0);
			//Not enough effects to display text
		break;
		case "mp_nightshift":
			level.aMapPositions[level.aMapPositions.size] = (-2109.85, 285.835, 46.125);
			level.aMapPositions[level.aMapPositions.size] = (-1090.54, 124.959, 2.125);
			level.aMapPositions[level.aMapPositions.size] = (-1610.37, -1473.37, 2.125);
			level.aMapPositions[level.aMapPositions.size] = (-1953.97, -29.6975, 2.125);
			level.aMapPositions[level.aMapPositions.size] = (-1932.31, -445.798, 4.59837);
			level.aMapPositions[level.aMapPositions.size] = (-1613.88, -2201.99, 18.8229);
			level.aMapPositions[level.aMapPositions.size] = (-1331.67, -1327.42, 2.125);
			level.aMapPositions[level.aMapPositions.size] = (-2057.36, -741.172, 4.95431);
			level.aMapPositions[level.aMapPositions.size] = (-923.609, -515.354, 6.125);
			level.aMapPositions[level.aMapPositions.size] = (210.809, -1448.78, 42.125);
			level.aMapPositions[level.aMapPositions.size] = (-920.174, -1174.86, 10.125);
			level.aMapPositions[level.aMapPositions.size] = (-314.194, -1996.16, 10.125);
			level.aMapPositions[level.aMapPositions.size] = (-525.154, -1630.6, 146.125);
			level.aMapPositions[level.aMapPositions.size] = (-720.292, 926.506, 90.125);
			level.aMapPositions[level.aMapPositions.size] = (33.842, 925.223, 90.125);
			level.aMapPositions[level.aMapPositions.size] = (-448.887, 382.124, 186.125);
			level.aMapPositions[level.aMapPositions.size] = (-1019.53, 237.253, 146.125);
			level.aMapPositions[level.aMapPositions.size] = (154.249, -415.971, 18.125);
			level.aMapPositions[level.aMapPositions.size] = (-877.159, -146.512, 146.125);
			level.aMapPositions[level.aMapPositions.size] = (651.728, 303.723, 18.125);
			level.aMapPositions[level.aMapPositions.size] = (-157.884, 93.1095, 10.125);
			level.aMapPositions[level.aMapPositions.size] = (182.753, -574.325, 10.125);
			level.aMapPositions[level.aMapPositions.size] = (14.6379, -882.715, 10.125);
			level.aMapPositions[level.aMapPositions.size] = (763.805, -1684.82, 61.625);
			level.aMapPositions[level.aMapPositions.size] = (-967.221, -758.883, 146.125);
			level.aMapPositions[level.aMapPositions.size] = (56.8449, -1045.5, 15.2814);
			level.aMapPositions[level.aMapPositions.size] = (573.863, -593.092, 10.0292);
			level.aMapPositions[level.aMapPositions.size] = (-441.638, -522.33, 167.151);
			level.aMapPositions[level.aMapPositions.size] = (1078.38, -138.417, 2.125);
			level.aMapPositions[level.aMapPositions.size] = (1456.05, 439.035, 18.125);
			level.aMapPositions[level.aMapPositions.size] = (-244.47, -839.709, 146.125);
			level.aMapPositions[level.aMapPositions.size] = (1921.06, 284.739, 118.125);
			level.aMapPositions[level.aMapPositions.size] = (-754.516, -1299.56, 146.125);
			level.aMapPositions[level.aMapPositions.size] = (1943.5, -506.834, 10.125);
			level.aMapPositions[level.aMapPositions.size] = (-685.462, -2253.33, 90.125);
			level.aMapPositions[level.aMapPositions.size] = (1158.84, -276.736, 10.125);
			level.aMapPositions[level.aMapPositions.size] = (1520.63, -872.996, 10.125);
			level.aMapPositions[level.aMapPositions.size] = (1485.34, -1665.96, 10.125);
			level.aMapPositions[level.aMapPositions.size] = (-765.944, -2041.58, 10.125);
			level.aMapPositions[level.aMapPositions.size] = (1109.35, -2131.38, 186.125);
			level.aMapPositions[level.aMapPositions.size] = (-1285.94, -1835.17, 10.125);
			level.aMapPositions[level.aMapPositions.size] = (1088.31, -2159.87, 42.125);
			level.aMapPositions[level.aMapPositions.size] = (661.768, -1849.86, 10.125);
			level.aMapPositions[level.aMapPositions.size] = (-2068.68, -1516.31, -45.875);
			level.aMapPositions[level.aMapPositions.size] = (-2367.53, -883.326, 138.125);
			level.aMapPositions[level.aMapPositions.size] = (-2462.07, -456.526, 138.125);
			level.aMapPositions[level.aMapPositions.size] = (-2028.88, -488.368, 138.125);
			level.aMapPositions[level.aMapPositions.size] = (-1195.4, 709.841, 2.125);

			//Drops
			level.aDropPositions[level.aDropPositions.size] = (-961.043, 817.905, 90.125);
			level.aDropPositions[level.aDropPositions.size] = (46.9969, -5.06412, 10.125);
			level.aDropPositions[level.aDropPositions.size] = (787.01, -1244.23, 2.125);
			level.aDropPositions[level.aDropPositions.size] = (-814.885, -1941.52, 10.125);
			level.aDropPositions[level.aDropPositions.size] = (-1611.31, -830.919, 2.20369);

			//Holo
			level.aHoloPosition["origin"] = (196.48, -1445.83, 290.906);
			level.aHoloPosition["angles"] = (0, 0, 0);
		break;
		case "mp_underpass":
			level.aMapPositions[level.aMapPositions.size] = (842.556, 744.532, 262.017);
			level.aMapPositions[level.aMapPositions.size] = (2542.42, -341.002, 384.179);
			level.aMapPositions[level.aMapPositions.size] = (2555.81, 68.7565, 302.125);
			level.aMapPositions[level.aMapPositions.size] = (2952.56, 998.134, 311.41);
			level.aMapPositions[level.aMapPositions.size] = (2285.41, 3263.15, 412.361);
			level.aMapPositions[level.aMapPositions.size] = (1916.46, 3131.73, 402.139);
			level.aMapPositions[level.aMapPositions.size] = (1242.72, 2756.76, 386.125);
			level.aMapPositions[level.aMapPositions.size] = (1369.24, 2750.89, 384.669);
			level.aMapPositions[level.aMapPositions.size] = (419.824, 2833.68, 315.435);
			level.aMapPositions[level.aMapPositions.size] = (3668.03, -69.0534, 350.125);
			level.aMapPositions[level.aMapPositions.size] = (969.632, -407.617, 477.343);
			level.aMapPositions[level.aMapPositions.size] = (275.786, 52.7803, 358.56);
			level.aMapPositions[level.aMapPositions.size] = (-479.143, 216.15, 194.125);
			level.aMapPositions[level.aMapPositions.size] = (1580.01, 1168.38, 394.125);
			level.aMapPositions[level.aMapPositions.size] = (1246.07, 2056.72, 394.125);
			level.aMapPositions[level.aMapPositions.size] = (1173.94, 2063.86, 202.013);
			level.aMapPositions[level.aMapPositions.size] = (1355.09, -766.1, 443.875);
			level.aMapPositions[level.aMapPositions.size] = (2193.99, 152.753, 458.125);
			level.aMapPositions[level.aMapPositions.size] = (1300.31, -78.7602, 454.851);
			level.aMapPositions[level.aMapPositions.size] = (223.059, 3671.97, 366.125);
			level.aMapPositions[level.aMapPositions.size] = (1140.88, 3178.79, 391.932);
			level.aMapPositions[level.aMapPositions.size] = (1233.46, 2887.69, 498.125);
			level.aMapPositions[level.aMapPositions.size] = (2768.68, 378.723, 462.125);
			level.aMapPositions[level.aMapPositions.size] = (855.652, 2498.56, 506.125);
			level.aMapPositions[level.aMapPositions.size] = (-174.27, 3585.23, 301.731);
			level.aMapPositions[level.aMapPositions.size] = (98.2623, 1332.62, 246.125);
			level.aMapPositions[level.aMapPositions.size] = (-510.951, 1545.51, 362.125);
			level.aMapPositions[level.aMapPositions.size] = (2591.39, 3428.36, 401.541);
			level.aMapPositions[level.aMapPositions.size] = (712.611, 1826.45, 514.125);
			level.aMapPositions[level.aMapPositions.size] = (876.937, 187.926, 362.125);
			level.aMapPositions[level.aMapPositions.size] = (-19.3926, 907.441, 188.862);
			level.aMapPositions[level.aMapPositions.size] = (429.722, 1080.25, 178.341);
			level.aMapPositions[level.aMapPositions.size] = (-482.92, 1157.19, 124.809);
			level.aMapPositions[level.aMapPositions.size] = (-344.448, 2315.55, 64.6576);
			level.aMapPositions[level.aMapPositions.size] = (-495.556, 467.414, 194.125);
			level.aMapPositions[level.aMapPositions.size] = (-64.2765, -1008.83, 357.125);
			level.aMapPositions[level.aMapPositions.size] = (878.907, 93.8611, 362.125);
			level.aMapPositions[level.aMapPositions.size] = (911.432, -1027.43, 471.853);
			level.aMapPositions[level.aMapPositions.size] = (1639.96, -1151.81, 402.125);
			level.aMapPositions[level.aMapPositions.size] = (3141.97, -1201.97, 374.681);
			level.aMapPositions[level.aMapPositions.size] = (3468.18, -365.55, 346.125);
			level.aMapPositions[level.aMapPositions.size] = (3667.88, 334.286, 298.125);
			level.aMapPositions[level.aMapPositions.size] = (2154.59, 249.558, 302.125);
			level.aMapPositions[level.aMapPositions.size] = (2471.81, 1420.85, 305.065);
			level.aMapPositions[level.aMapPositions.size] = (3334.93, 1670.99, 311.453);
			level.aMapPositions[level.aMapPositions.size] = (3334.08, 2125.62, 298.297);
			level.aMapPositions[level.aMapPositions.size] = (2096.85, 1892.84, 353.103);
			level.aMapPositions[level.aMapPositions.size] = (1810.4, 2378.36, 394.125);
			level.aMapPositions[level.aMapPositions.size] = (1560.09, 1582.28, 506.303);
			level.aMapPositions[level.aMapPositions.size] = (887.348, 1969.67, 352.231);
			level.aMapPositions[level.aMapPositions.size] = (1071.87, 950.073, 642.125);
			level.aMapPositions[level.aMapPositions.size] = (249.853, 2467.34, 317.336);
			level.aMapPositions[level.aMapPositions.size] = (2085.27, 485.567, 458.125);
			level.aMapPositions[level.aMapPositions.size] = (2463.04, 1183.83, 292.81);
			level.aMapPositions[level.aMapPositions.size] = (1651.52, -328.597, 418.354);
			level.aMapPositions[level.aMapPositions.size] = (-51.6875, 1814.68, 530.125);
			level.aMapPositions[level.aMapPositions.size] = (1843.16, 1197.08, 458.125);
			level.aMapPositions[level.aMapPositions.size] = (2413.19, -1124, 384.092);
			level.aMapPositions[level.aMapPositions.size] = (1564.25, -522.671, 522.125);
			level.aMapPositions[level.aMapPositions.size] = (1178.49, -679.453, 522.125);
			level.aMapPositions[level.aMapPositions.size] = (1086.05, -287.608, 522.125);
			level.aMapPositions[level.aMapPositions.size] = (419.882, -270.941, 330.125);
			level.aMapPositions[level.aMapPositions.size] = (-437.502, -355.311, 322.125);
			level.aMapPositions[level.aMapPositions.size] = (119.556, 375.995, 328.125);
			level.aMapPositions[level.aMapPositions.size] = (65.2383, 345.849, 194.125);
			level.aMapPositions[level.aMapPositions.size] = (118.473, 482.239, 194.125);
			level.aMapPositions[level.aMapPositions.size] = (761.947, 1358.83, 346.125);
			level.aMapPositions[level.aMapPositions.size] = (79.1656, 1635.42, 394.125);
			level.aMapPositions[level.aMapPositions.size] = (-511.594, 2314.38, 362.125);
			level.aMapPositions[level.aMapPositions.size] = (-421.79, 3213.5, 402.125);
			level.aMapPositions[level.aMapPositions.size] = (-544.134, 2978.78, 300.125);
			level.aMapPositions[level.aMapPositions.size] = (173.557, 2766.58, 265.573);
			level.aMapPositions[level.aMapPositions.size] = (-339.174, 2491.51, 301.125);


			//Drops
			level.aDropPositions[level.aDropPositions.size] = (1548.53, 690.471, 433.603);
			level.aDropPositions[level.aDropPositions.size] = (1154.36, 2524.03, 385.914);
			level.aDropPositions[level.aDropPositions.size] = (2594.42, 1966.46, 298.934);
			level.aDropPositions[level.aDropPositions.size] = (2765.43, 720.164, 294.599);
			level.aDropPositions[level.aDropPositions.size] = (426.174, 838.837, 114.718);
			level.aDropPositions[level.aDropPositions.size] = (230.774, -357.373, 331.943);
			level.aDropPositions[level.aDropPositions.size] = (1673.83, -928.173, 391.652);
			level.aDropPositions[level.aDropPositions.size] = (1151.89, 1574.86, 395.741);

			//Holo
			level.aHoloPosition["origin"] = (1705.06, 377.937, 837.003);
			level.aHoloPosition["angles"] = (0, 117.966, 0);
		break;
		case "mp_quarry":
			level.aMapPositions[level.aMapPositions.size] = (-1936.46, 1628.3, 30.4601);
			level.aMapPositions[level.aMapPositions.size] = (-1779.41, 1600.46, 35.7696);
			level.aMapPositions[level.aMapPositions.size] = (-2971.28, 660.425, -330.477);
			level.aMapPositions[level.aMapPositions.size] = (-3629.28, 1234.4, -330.171);
			level.aMapPositions[level.aMapPositions.size] = (-4985.95, -634.121, -139.587);
			level.aMapPositions[level.aMapPositions.size] = (-5593.26, -1644.12, -138.916);
			level.aMapPositions[level.aMapPositions.size] = (-4820.44, -66.31, -181.954);
			level.aMapPositions[level.aMapPositions.size] = (-4268.89, -1031.87, -117.875);
			level.aMapPositions[level.aMapPositions.size] = (-4285.48, -812.211, 42.0593);
			level.aMapPositions[level.aMapPositions.size] = (-3525.72, 2312.91, 46.8472);
			level.aMapPositions[level.aMapPositions.size] = (-2808.63, 2315.47, 52.6996);
			level.aMapPositions[level.aMapPositions.size] = (-2714.55, 1683.48, 28.6031);
			level.aMapPositions[level.aMapPositions.size] = (-4785.42, 1263.61, 38.125);
			level.aMapPositions[level.aMapPositions.size] = (-4734.55, 2030.2, 206.61);
			level.aMapPositions[level.aMapPositions.size] = (-3173.97, -351.838, -21.875);
			level.aMapPositions[level.aMapPositions.size] = (-4596.17, 1451.3, -167.831);
			level.aMapPositions[level.aMapPositions.size] = (-3136.04, -622.108, -181.037);
			level.aMapPositions[level.aMapPositions.size] = (-2839.58, 249.809, -69.0005);
			level.aMapPositions[level.aMapPositions.size] = (-2640.71, 1257.46, 30.125);
			level.aMapPositions[level.aMapPositions.size] = (-2454.46, -271.345, -34.7209);
			level.aMapPositions[level.aMapPositions.size] = (-2304.53, -926.165, -27.4242);
			level.aMapPositions[level.aMapPositions.size] = (-3060.62, -829.345, -56.7145);
			level.aMapPositions[level.aMapPositions.size] = (-3089.04, -1501.78, 170.125);
			level.aMapPositions[level.aMapPositions.size] = (-2881.8, -1351.28, 79.1044);
			level.aMapPositions[level.aMapPositions.size] = (-4628.88, 588.199, -181.875);
			level.aMapPositions[level.aMapPositions.size] = (-4648.99, 1047.42, -47.875);
			level.aMapPositions[level.aMapPositions.size] = (-4099.1, 115.191, -45.875);
			level.aMapPositions[level.aMapPositions.size] = (-5021.69, 37.7683, 16.125);
			level.aMapPositions[level.aMapPositions.size] = (-5874.03, -1121.88, -101.634);
			level.aMapPositions[level.aMapPositions.size] = (-4982.35, -382.699, 298.125);
			level.aMapPositions[level.aMapPositions.size] = (-4576.47, -168.04, 362.125);
			level.aMapPositions[level.aMapPositions.size] = (-5168.74, -2077.92, -113.239);
			level.aMapPositions[level.aMapPositions.size] = (-5366.27, -2040.24, -102.798);
			level.aMapPositions[level.aMapPositions.size] = (-3995.46, -421.396, -42.1287);
			level.aMapPositions[level.aMapPositions.size] = (-5106.72, -279.622, -95.875);
			level.aMapPositions[level.aMapPositions.size] = (-5698.51, -450.429, -173.394);
			level.aMapPositions[level.aMapPositions.size] = (-4863.78, -1329.7, -181.875);
			level.aMapPositions[level.aMapPositions.size] = (-4983.1, 1892.37, 90.125);
			level.aMapPositions[level.aMapPositions.size] = (-3697.42, 3038.19, 96.4829);
			level.aMapPositions[level.aMapPositions.size] = (-3807.38, 2310.28, 34.125);
			level.aMapPositions[level.aMapPositions.size] = (-3938.75, 1296.31, -20.952);
			level.aMapPositions[level.aMapPositions.size] = (-4989.29, 213.405, -68.875);
			level.aMapPositions[level.aMapPositions.size] = (-3433.24, 505.994, 6.12495);
			level.aMapPositions[level.aMapPositions.size] = (-4450.3, 503.82, -155.757);
			level.aMapPositions[level.aMapPositions.size] = (-3499.02, 1421.6, 62.8804);
			level.aMapPositions[level.aMapPositions.size] = (-5057.13, 1151.47, -250.657);
			level.aMapPositions[level.aMapPositions.size] = (-3310.57, 1294.28, -239.875);
			level.aMapPositions[level.aMapPositions.size] = (-3313.23, 182.26, -284.16);
			level.aMapPositions[level.aMapPositions.size] = (-3296.1, 572.029, -269.875);
			level.aMapPositions[level.aMapPositions.size] = (-4491.33, 767.763, -181.875);
			level.aMapPositions[level.aMapPositions.size] = (-3422.31, 596.563, -101.875);
			level.aMapPositions[level.aMapPositions.size] = (-4095.45, 78.2671, -181.875);
			level.aMapPositions[level.aMapPositions.size] = (-3730.37, 1941.09, 280.125);
			level.aMapPositions[level.aMapPositions.size] = (-4769.13, -1087.65, -117.875);
			level.aMapPositions[level.aMapPositions.size] = (-2808.44, 1941.86, 144.125);
			level.aMapPositions[level.aMapPositions.size] = (-2824.46, 1930.59, 10.125);
			level.aMapPositions[level.aMapPositions.size] = (-4758.63, -1441.69, 18.125);
			level.aMapPositions[level.aMapPositions.size] = (-2726.09, 1432.88, 122.125);
			level.aMapPositions[level.aMapPositions.size] = (-4105.01, -423.179, 90.125);
			level.aMapPositions[level.aMapPositions.size] = (-2458.13, 643.63, 30.125);
			level.aMapPositions[level.aMapPositions.size] = (-4370.53, 645.758, -47.875);
			level.aMapPositions[level.aMapPositions.size] = (-1645.72, 24.2094, 66.125);
			level.aMapPositions[level.aMapPositions.size] = (-1446.03, 511.861, 74.125);
			level.aMapPositions[level.aMapPositions.size] = (-4627.36, 1330.4, -181.875);
			level.aMapPositions[level.aMapPositions.size] = (-5780.16, 303.29, -95.3936);
			level.aMapPositions[level.aMapPositions.size] = (-1681.04, 2132.69, 170.125);
			level.aMapPositions[level.aMapPositions.size] = (-5576.15, 1524.64, 95.4443);
			level.aMapPositions[level.aMapPositions.size] = (-5435.43, 2312.67, 90.125);
			level.aMapPositions[level.aMapPositions.size] = (-4610.93, 3044.07, 85.286);
			level.aMapPositions[level.aMapPositions.size] = (-2680.38, 2784.38, 82.4302);
			level.aMapPositions[level.aMapPositions.size] = (-4051.21, 1569.98, 10.125);
			level.aMapPositions[level.aMapPositions.size] = (-1898.35, 2028.09, 33.5561);
			level.aMapPositions[level.aMapPositions.size] = (-3726.98, 1948.4, 10.125);
			level.aMapPositions[level.aMapPositions.size] = (-2309.77, 1730.02, 34.125);
			level.aMapPositions[level.aMapPositions.size] = (-3133.13, 3201.72, 30.1003);
			level.aMapPositions[level.aMapPositions.size] = (-1663.54, 755.167, 34.125);
			level.aMapPositions[level.aMapPositions.size] = (-1835.74, 3051.85, 98.5984);
			level.aMapPositions[level.aMapPositions.size] = (-2314.61, 1715.25, 168.125);
			level.aMapPositions[level.aMapPositions.size] = (-1787.16, 1472.65, 168.125);
			level.aMapPositions[level.aMapPositions.size] = (-1448.99, 1939, 34.125);
			level.aMapPositions[level.aMapPositions.size] = (-2636.46, 733.741, 30.125);

			//Drops
			level.aDropPositions[level.aDropPositions.size] = (-5199.8, 452.119, -183.709);
			level.aDropPositions[level.aDropPositions.size] = (-5329.38, -705.566, -183.651);
			level.aDropPositions[level.aDropPositions.size] = (-3774.07, -694.228, -176.551);
			level.aDropPositions[level.aDropPositions.size] = (-3049.51, 105.636, -250.299);
			level.aDropPositions[level.aDropPositions.size] = (-3230.68, 1176.29, -35.3534);
			level.aDropPositions[level.aDropPositions.size] = (-4355.39, 1070.01, -271.671);
			level.aDropPositions[level.aDropPositions.size] = (-4189.86, 2116.32, -1.66415);
			level.aDropPositions[level.aDropPositions.size] = (-3197.86, 2202.49, 36.2347);
			level.aDropPositions[level.aDropPositions.size] = (-2092.76, 1049.83, 34.286);
		break;
		case "mp_complex":
			level.aMapPositions[level.aMapPositions.size] = (350.518, -3101.88, 654.125);
			level.aMapPositions[level.aMapPositions.size] = (-286.904, -3040.52, 804.125);
			level.aMapPositions[level.aMapPositions.size] = (861.145, -2668.77, 563.391);
			level.aMapPositions[level.aMapPositions.size] = (1882.7, -3570.08, 610.125);
			level.aMapPositions[level.aMapPositions.size] = (2846.43, -2786.43, 610.125);
			level.aMapPositions[level.aMapPositions.size] = (2238.03, -1948.15, 602.125);
			level.aMapPositions[level.aMapPositions.size] = (1789.54, -1934.76, 568.125);
			level.aMapPositions[level.aMapPositions.size] = (1365.53, -1918.72, 568.125);
			level.aMapPositions[level.aMapPositions.size] = (6.22393, -2321.78, 858.125);
			level.aMapPositions[level.aMapPositions.size] = (18.836, -2422.79, 682.125);
			level.aMapPositions[level.aMapPositions.size] = (-338.122, -1646.91, 682.125);
			level.aMapPositions[level.aMapPositions.size] = (-1047.29, -1563.97, 682.125);
			level.aMapPositions[level.aMapPositions.size] = (-1494.4, -3296.95, 682.125);
			level.aMapPositions[level.aMapPositions.size] = (945.902, -3982.89, 610.125);
			level.aMapPositions[level.aMapPositions.size] = (1316.49, -3944.71, 610.125);
			level.aMapPositions[level.aMapPositions.size] = (1618.72, -4157.5, 610.125);
			level.aMapPositions[level.aMapPositions.size] = (373.446, -2094.84, 682.125);
			level.aMapPositions[level.aMapPositions.size] = (2553.5, -3917.51, 610.125);
			level.aMapPositions[level.aMapPositions.size] = (2013.36, -2066.94, 602.125);
			level.aMapPositions[level.aMapPositions.size] = (217.196, -3102.67, 658.125);
			level.aMapPositions[level.aMapPositions.size] = (2399.74, -2558.29, 758.125);
			level.aMapPositions[level.aMapPositions.size] = (2622.23, -2433.67, 610.125);
			level.aMapPositions[level.aMapPositions.size] = (-1212.73, -1910.28, 682.125);
			level.aMapPositions[level.aMapPositions.size] = (2071.6, -2607.02, 610.125);
			level.aMapPositions[level.aMapPositions.size] = (2184.1, -2979.13, 578.182);
			level.aMapPositions[level.aMapPositions.size] = (-323.889, -2083.76, 682.125);
			level.aMapPositions[level.aMapPositions.size] = (-100.85, -1790.29, 826.125);
			level.aMapPositions[level.aMapPositions.size] = (1584.73, -2802.05, 506.075);
			level.aMapPositions[level.aMapPositions.size] = (235.638, -2419.93, 826.125);
			level.aMapPositions[level.aMapPositions.size] = (1343.64, -2484.22, 457.856);
			level.aMapPositions[level.aMapPositions.size] = (1960.89, -1614.76, 410.125);
			level.aMapPositions[level.aMapPositions.size] = (99.0391, -1896.27, 700.125);
			level.aMapPositions[level.aMapPositions.size] = (998.826, -2060.66, 682.125);
			level.aMapPositions[level.aMapPositions.size] = (1057.01, -2440.51, 682.125);
			level.aMapPositions[level.aMapPositions.size] = (661.701, -2376.88, 682.125);
			level.aMapPositions[level.aMapPositions.size] = (-322.766, -2488.53, 682.125);
			level.aMapPositions[level.aMapPositions.size] = (1106.66, -3312.26, 610.125);
			level.aMapPositions[level.aMapPositions.size] = (623.347, -3996.11, 610.125);
			level.aMapPositions[level.aMapPositions.size] = (1935.12, -2360.51, 422.125);
			level.aMapPositions[level.aMapPositions.size] = (-365.856, -3739.83, 858.125);
			level.aMapPositions[level.aMapPositions.size] = (1533.39, -1294.13, 394.125);
			level.aMapPositions[level.aMapPositions.size] = (102.127, -3927, 858.125);
			level.aMapPositions[level.aMapPositions.size] = (-465.605, -3933.39, 858.125);
			level.aMapPositions[level.aMapPositions.size] = (-625.506, -3643.84, 666.125);
			level.aMapPositions[level.aMapPositions.size] = (2136.56, -4040.97, 610.125);
			level.aMapPositions[level.aMapPositions.size] = (326.503, -3646.88, 705.458);
			level.aMapPositions[level.aMapPositions.size] = (630.256, -3571.76, 858.125);
			level.aMapPositions[level.aMapPositions.size] = (-1265.58, -3332.05, 682.125);
			level.aMapPositions[level.aMapPositions.size] = (-1328.7, -2466.98, 717.125);
			level.aMapPositions[level.aMapPositions.size] = (-1535.1, -1699.72, 682.125);
			level.aMapPositions[level.aMapPositions.size] = (-1162.28, -1745.76, 684.125);
			level.aMapPositions[level.aMapPositions.size] = (-948.118, -3993.31, 858.125);
			level.aMapPositions[level.aMapPositions.size] = (-2053.84, -1648.98, 690.125);
			level.aMapPositions[level.aMapPositions.size] = (-2637.23, -2329.3, 682.125);
			level.aMapPositions[level.aMapPositions.size] = (-1810.68, -3215.98, 858.125);

			level.aDropPositions[level.aDropPositions.size] = (-193.264, -3803.85, 858.125);
			level.aDropPositions[level.aDropPositions.size] = (1729.05, -2069.57, 602.125);
			level.aDropPositions[level.aDropPositions.size] = (2374.13, -3114.13, 616.1);
			level.aDropPositions[level.aDropPositions.size] = (1424.51, -2825.32, 503.359);
			level.aDropPositions[level.aDropPositions.size] = (-79.393, -2913.71, 658.125);
			level.aDropPositions[level.aDropPositions.size] = (-598.985, -1752.44, 682.125);
			level.aDropPositions[level.aDropPositions.size] = (-1745.15, -2034.43, 669.516);
		break;
		case "mp_estate":
			level.aMapPositions[level.aMapPositions.size] = (-1736.68, 2565.88, -123.465);
			level.aMapPositions[level.aMapPositions.size] = (-2282.92, 282.434, -161.875);
			level.aMapPositions[level.aMapPositions.size] = (-2599.65, 600.381, -158.875);
			level.aMapPositions[level.aMapPositions.size] = (-2767.15, 1134.94, -296.875);
			level.aMapPositions[level.aMapPositions.size] = (-3099.28, 915.354, -296.875);
			level.aMapPositions[level.aMapPositions.size] = (-2259.15, 248.828, -296.875);
			level.aMapPositions[level.aMapPositions.size] = (730.101, 1001.1, 48.125);
			level.aMapPositions[level.aMapPositions.size] = (661.73, 474.844, 48.125);
			level.aMapPositions[level.aMapPositions.size] = (1.8747, 619.391, 161.805);
			level.aMapPositions[level.aMapPositions.size] = (-925.8, 2878.07, -107.102);
			level.aMapPositions[level.aMapPositions.size] = (-1816.82, 3485.13, -278.155);
			level.aMapPositions[level.aMapPositions.size] = (-2790.7, 1238.97, -296.699);
			level.aMapPositions[level.aMapPositions.size] = (-1963, 2122.66, -145.242);
			level.aMapPositions[level.aMapPositions.size] = (-2072.89, 1237.38, -255.613);
			level.aMapPositions[level.aMapPositions.size] = (-2003.42, 185.563, -284.566);
			level.aMapPositions[level.aMapPositions.size] = (-826.415, 3230.09, -86.1376);
			level.aMapPositions[level.aMapPositions.size] = (-1169.95, 2782.43, 16.125);
			level.aMapPositions[level.aMapPositions.size] = (-925.458, 2517.51, 16.125);
			level.aMapPositions[level.aMapPositions.size] = (-1024.51, 2847.06, -113.875);
			level.aMapPositions[level.aMapPositions.size] = (-1595.91, 2549.97, -113.875);
			level.aMapPositions[level.aMapPositions.size] = (-1109.52, 2471.47, -111.884);
			level.aMapPositions[level.aMapPositions.size] = (122.925, 2199.28, -31.4917);
			level.aMapPositions[level.aMapPositions.size] = (506.411, 770.022, 200.125);
			level.aMapPositions[level.aMapPositions.size] = (325.467, 742.945, 200.125);
			level.aMapPositions[level.aMapPositions.size] = (-349.837, 1048.28, 200.125);
			level.aMapPositions[level.aMapPositions.size] = (181.787, 789.763, 328.125);
			level.aMapPositions[level.aMapPositions.size] = (512.185, 1084.8, 329.125);
			level.aMapPositions[level.aMapPositions.size] = (515.389, 890.984, 328.125);
			level.aMapPositions[level.aMapPositions.size] = (796.987, 652.954, 346.125);
			level.aMapPositions[level.aMapPositions.size] = (128.232, 646.582, 328.125);
			level.aMapPositions[level.aMapPositions.size] = (221.874, 340.971, 180.125);
			level.aMapPositions[level.aMapPositions.size] = (527.652, 249.496, 326.125);
			level.aMapPositions[level.aMapPositions.size] = (-1238.37, 1315.42, -456.309);
			level.aMapPositions[level.aMapPositions.size] = (-391.116, 2130.81, -33.8867);
			level.aMapPositions[level.aMapPositions.size] = (186.894, 1214.89, 150.589);
			level.aMapPositions[level.aMapPositions.size] = (543.099, 1155.43, 200.125);
			level.aMapPositions[level.aMapPositions.size] = (869.742, 795.717, 200.125);
			level.aMapPositions[level.aMapPositions.size] = (-432.374, -218.332, 95.884);
			level.aMapPositions[level.aMapPositions.size] = (474.457, 153.477, 167.919);
			level.aMapPositions[level.aMapPositions.size] = (83.7108, 277.55, 145.27);
			level.aMapPositions[level.aMapPositions.size] = (-337.722, 729.044, 95.0528);
			level.aMapPositions[level.aMapPositions.size] = (-810.477, 827.567, 74.9645);
			level.aMapPositions[level.aMapPositions.size] = (-741.445, -474.501, -66.875);
			level.aMapPositions[level.aMapPositions.size] = (-840.666, 65.3314, -45.1488);
			level.aMapPositions[level.aMapPositions.size] = (-1265.89, -369.038, -59.6737);
			level.aMapPositions[level.aMapPositions.size] = (-779.838, -103.79, 53.625);
			level.aMapPositions[level.aMapPositions.size] = (3.40036, -583.16, 85.625);
			level.aMapPositions[level.aMapPositions.size] = (1118.28, -464.65, 81.2893);
			level.aMapPositions[level.aMapPositions.size] = (678.627, 346.498, 80.5104);
			level.aMapPositions[level.aMapPositions.size] = (711.884, -473.709, 75.6817);
			level.aMapPositions[level.aMapPositions.size] = (1198.52, -1159.15, 149.454);
			level.aMapPositions[level.aMapPositions.size] = (1538.03, -356.502, 82.6639);
			level.aMapPositions[level.aMapPositions.size] = (1946.82, 424.378, 100.872);
			level.aMapPositions[level.aMapPositions.size] = (920.697, 1096.2, 82.1937);
			level.aMapPositions[level.aMapPositions.size] = (1324.13, 1331.19, 139.111);
			level.aMapPositions[level.aMapPositions.size] = (643.878, 1896.72, 155.902);
			level.aMapPositions[level.aMapPositions.size] = (1519.93, 2312.88, 154.947);
			level.aMapPositions[level.aMapPositions.size] = (1087.14, 2895.49, 172.261);
			level.aMapPositions[level.aMapPositions.size] = (1698.92, 3091.55, 172.598);
			level.aMapPositions[level.aMapPositions.size] = (1403.55, 4320.13, 4.125);
			level.aMapPositions[level.aMapPositions.size] = (1236.13, 3613.92, 156.125);
			level.aMapPositions[level.aMapPositions.size] = (586.535, 3918.99, 186.892);
			level.aMapPositions[level.aMapPositions.size] = (-262.386, 4322.62, 150.727);
			level.aMapPositions[level.aMapPositions.size] = (-570.533, 3564.05, 160.125);
			level.aMapPositions[level.aMapPositions.size] = (-343.653, 2849.02, -2.45301);
			level.aMapPositions[level.aMapPositions.size] = (-783, 2618.85, -114.379);
			level.aMapPositions[level.aMapPositions.size] = (-1493.63, 3080.75, -103.559);
			level.aMapPositions[level.aMapPositions.size] = (-1405.29, 3677.6, -167.572);
			level.aMapPositions[level.aMapPositions.size] = (-1551.12, 2695.82, -111.165);
			level.aMapPositions[level.aMapPositions.size] = (-1847.52, 3021.09, -223.042);
			level.aMapPositions[level.aMapPositions.size] = (-1704.08, 4320.45, -164.178);
			level.aMapPositions[level.aMapPositions.size] = (-2723.52, 3423.49, -129.075);
			level.aMapPositions[level.aMapPositions.size] = (-3152.2, 3499.56, -297.075);
			level.aMapPositions[level.aMapPositions.size] = (-3670.63, 3219.94, -265.075);
			level.aMapPositions[level.aMapPositions.size] = (-3162.96, 2524.09, -297.075);
			level.aMapPositions[level.aMapPositions.size] = (-3251.32, 4091.96, -278.258);
			level.aMapPositions[level.aMapPositions.size] = (-4729.97, 3654.12, -279.398);
			level.aMapPositions[level.aMapPositions.size] = (-4028.77, 2830.33, -302.393);
			level.aMapPositions[level.aMapPositions.size] = (-3981.92, 1916.52, -316.245);
			level.aMapPositions[level.aMapPositions.size] = (-2988.56, 1815.05, -299.022);
			level.aMapPositions[level.aMapPositions.size] = (-3705.75, 1513.25, -284.099);
			level.aMapPositions[level.aMapPositions.size] = (-3841.35, 1017.8, -212.319);
			level.aMapPositions[level.aMapPositions.size] = (-3806.69, 492.94, -139.038);
			level.aMapPositions[level.aMapPositions.size] = (-3448.01, -234.193, -306.03);

			//Drops
			level.aDropPositions[level.aDropPositions.size] = (1163.82, 3075.88, 149.08);
			level.aDropPositions[level.aDropPositions.size] = (-1210.13, 3380.98, -125.271);
			level.aDropPositions[level.aDropPositions.size] = (-3251.79, 1766.94, -290.886);
			level.aDropPositions[level.aDropPositions.size] = (-1445.19, 1785.17, -234.738);
			level.aDropPositions[level.aDropPositions.size] = (457.911, 1724.61, 118.525);
			level.aDropPositions[level.aDropPositions.size] = (138.384, -134.837, 127.764);
			level.aDropPositions[level.aDropPositions.size] = (-1238.43, -174.002, -56.7145);
		break;
		case "mp_trailerpark":
			level.aMapPositions[level.aMapPositions.size] = (734.176, 991.857, 7.19034);
			level.aMapPositions[level.aMapPositions.size] = (1088.39, -1676.06, 16.8212);
			level.aMapPositions[level.aMapPositions.size] = (-1179.18, 626.133, 3.84398);
			level.aMapPositions[level.aMapPositions.size] = (-2411.79, -25.9036, 20.959);
			level.aMapPositions[level.aMapPositions.size] = (-2418.93, -618.459, 1.47027);
			level.aMapPositions[level.aMapPositions.size] = (1118.65, -675.742, 15.1001);
			level.aMapPositions[level.aMapPositions.size] = (-742.386, 1344.88, 15.9167);
			level.aMapPositions[level.aMapPositions.size] = (-1392.19, 1107.78, 20.9744);
			level.aMapPositions[level.aMapPositions.size] = (976.967, 156.842, 9.65738);
			level.aMapPositions[level.aMapPositions.size] = (1338.57, -894.155, 9.88799);
			level.aMapPositions[level.aMapPositions.size] = (-34.9657, -1119.66, 0.265737);
			level.aMapPositions[level.aMapPositions.size] = (160.548, -537.008, 4.34821);
			level.aMapPositions[level.aMapPositions.size] = (-294.018, -154.915, 43.125);
			level.aMapPositions[level.aMapPositions.size] = (-665.598, -9.91432, 43.125);
			level.aMapPositions[level.aMapPositions.size] = (-61.5901, -194.486, 43.125);
			level.aMapPositions[level.aMapPositions.size] = (170.091, 1288.48, 70.5764);
			level.aMapPositions[level.aMapPositions.size] = (232.981, 1119.4, 16.4959);
			level.aMapPositions[level.aMapPositions.size] = (635.473, 650.018, 3.55123);
			level.aMapPositions[level.aMapPositions.size] = (1324.49, 654.928, 14.6204);
			level.aMapPositions[level.aMapPositions.size] = (971.846, 560.496, 7.8583);
			level.aMapPositions[level.aMapPositions.size] = (666.853, -110.837, 42.625);
			level.aMapPositions[level.aMapPositions.size] = (793.185, 248.98, 17.6338);
			level.aMapPositions[level.aMapPositions.size] = (1314.96, 1173.71, 15.5189);
			level.aMapPositions[level.aMapPositions.size] = (1298.89, 315.882, 9.19726);
			level.aMapPositions[level.aMapPositions.size] = (1315.21, -501.078, 41.125);
			level.aMapPositions[level.aMapPositions.size] = (1302.62, -300.74, 41.125);
			level.aMapPositions[level.aMapPositions.size] = (1367.77, -189.056, 10.4506);
			level.aMapPositions[level.aMapPositions.size] = (1874.36, 98.5858, 6.50442);
			level.aMapPositions[level.aMapPositions.size] = (1500.13, -734.57, 10.1434);
			level.aMapPositions[level.aMapPositions.size] = (1982.3, -938.284, 18.0288);
			level.aMapPositions[level.aMapPositions.size] = (1874.93, -1053.99, 33.125);
			level.aMapPositions[level.aMapPositions.size] = (1650.21, -1485.04, 33.125);
			level.aMapPositions[level.aMapPositions.size] = (1865.62, -1213.14, 33.125);
			level.aMapPositions[level.aMapPositions.size] = (1330.42, -1315.15, 6.71916);
			level.aMapPositions[level.aMapPositions.size] = (1499.71, -1634.74, 15.2027);
			level.aMapPositions[level.aMapPositions.size] = (810.293, -655.278, -5.43377);
			level.aMapPositions[level.aMapPositions.size] = (-322.757, -1361.61, 7.04447);
			level.aMapPositions[level.aMapPositions.size] = (-255.041, -878.132, 36.125);
			level.aMapPositions[level.aMapPositions.size] = (-38.9138, -646.202, 1.06757);
			level.aMapPositions[level.aMapPositions.size] = (-545.913, -274.536, 13.6223);
			level.aMapPositions[level.aMapPositions.size] = (-556.215, 44.5557, 14.8228);
			level.aMapPositions[level.aMapPositions.size] = (-848.756, 139.924, 14.1054);
			level.aMapPositions[level.aMapPositions.size] = (-838.217, 375.04, 11.3238);
			level.aMapPositions[level.aMapPositions.size] = (-576.034, 322.148, 15.6227);
			level.aMapPositions[level.aMapPositions.size] = (149.172, 21.6588, 10.6177);
			level.aMapPositions[level.aMapPositions.size] = (-108.195, 385.352, 26.025);
			level.aMapPositions[level.aMapPositions.size] = (-259.386, 952.333, 12.9931);
			level.aMapPositions[level.aMapPositions.size] = (-515.907, 906.922, 46.125);
			level.aMapPositions[level.aMapPositions.size] = (-562.578, 709.423, 46.125);
			level.aMapPositions[level.aMapPositions.size] = (-839.367, 482.591, 10.2438);
			level.aMapPositions[level.aMapPositions.size] = (-670.77, 750.467, 13.6641);
			level.aMapPositions[level.aMapPositions.size] = (-1604.49, 1319.7, 12.125);
			level.aMapPositions[level.aMapPositions.size] = (-1864.33, 1575, 12.125);
			level.aMapPositions[level.aMapPositions.size] = (-2008.18, 1330.27, 12.125);
			level.aMapPositions[level.aMapPositions.size] = (-1520.74, 1473.04, 10.2291);
			level.aMapPositions[level.aMapPositions.size] = (-1795.31, 1191.42, 11.3432);
			level.aMapPositions[level.aMapPositions.size] = (-1830.9, 924.632, 10.4726);
			level.aMapPositions[level.aMapPositions.size] = (-2035, 123.827, 30.625);
			level.aMapPositions[level.aMapPositions.size] = (-1991.32, 497.561, 32.9173);
			level.aMapPositions[level.aMapPositions.size] = (-1813.8, 333.604, 35.2772);
			level.aMapPositions[level.aMapPositions.size] = (-1765.7, 175.498, 33.5974);
			level.aMapPositions[level.aMapPositions.size] = (-2029.99, -8.648, 31.5669);
			level.aMapPositions[level.aMapPositions.size] = (-1705.91, -223.544, 31.5095);
			level.aMapPositions[level.aMapPositions.size] = (-1124.97, -365.907, 16.125);
			level.aMapPositions[level.aMapPositions.size] = (-677.547, -360.234, 13.625);
			level.aMapPositions[level.aMapPositions.size] = (-1155.89, 304.054, 41.125);
			level.aMapPositions[level.aMapPositions.size] = (-1620.24, -445.049, 8.87825);
			level.aMapPositions[level.aMapPositions.size] = (-1521.63, -830.198, 2.03113);
			level.aMapPositions[level.aMapPositions.size] = (-1612.1, -541.845, 10.0789);
			level.aMapPositions[level.aMapPositions.size] = (-2133.59, -674.188, -3.95842);
			level.aMapPositions[level.aMapPositions.size] = (-1993.65, -803.349, 37.725);
			level.aMapPositions[level.aMapPositions.size] = (-2399.46, 273.792, -78.9956);
			level.aMapPositions[level.aMapPositions.size] = (-2064.82, 1022.69, -64.5375);
			level.aMapPositions[level.aMapPositions.size] = (-2503.42, 1024.74, -73.2804);
			level.aMapPositions[level.aMapPositions.size] = (-2260.85, 1200.93, 41.8395);

			//Drops
			level.aDropPositions[level.aDropPositions.size] = (-2493.95, -195.262, -51.0184);
			level.aDropPositions[level.aDropPositions.size] = (-198.392, 1210.92, 20.9303);
			level.aDropPositions[level.aDropPositions.size] = (-1296.1, 1069.1, 22.6542);
			level.aDropPositions[level.aDropPositions.size] = (-353.475, -610.178, -0.766003);
			level.aDropPositions[level.aDropPositions.size] = (-1414.19, -229.218, 16.9508);
			level.aDropPositions[level.aDropPositions.size] = (-115.386, 367.895, 26.025);
			level.aDropPositions[level.aDropPositions.size] = (1661.13, -253.581, 3.53503);
			level.aDropPositions[level.aDropPositions.size] = (1066.23, 804.143, 14.3998);
			level.aDropPositions[level.aDropPositions.size] = (1092.54, -1293.51, 13.8801);
		break;
		case "mp_vacant":
			level.aMapPositions[level.aMapPositions.size] = (343.63, 635.613, -37.875);
			level.aMapPositions[level.aMapPositions.size] = (-527.808, 637.885, -37.875);
			level.aMapPositions[level.aMapPositions.size] = (-22.7309, -495.403, -37.875);
			level.aMapPositions[level.aMapPositions.size] = (96.9889, -499.199, -37.875);
			level.aMapPositions[level.aMapPositions.size] = (-126.121, 1102.97, -37.875);
			level.aMapPositions[level.aMapPositions.size] = (-1778.65, 543.449, -92.875);
			level.aMapPositions[level.aMapPositions.size] = (-1410.45, 394.525, -92.875);
			level.aMapPositions[level.aMapPositions.size] = (1135.45, 815.399, -37.875);
			level.aMapPositions[level.aMapPositions.size] = (-1169.52, -1365.1, -93.875);
			level.aMapPositions[level.aMapPositions.size] = (-889.667, -356.322, -101.875);
			level.aMapPositions[level.aMapPositions.size] = (-1168.85, -564.34, -93.875);
			level.aMapPositions[level.aMapPositions.size] = (-788.509, -1363.46, -93.1773);
			level.aMapPositions[level.aMapPositions.size] = (-403.753, -993.512, -93.875);
			level.aMapPositions[level.aMapPositions.size] = (-79.1234, -899.258, -93.875);
			level.aMapPositions[level.aMapPositions.size] = (500.632, -1337.75, -92.5347);
			level.aMapPositions[level.aMapPositions.size] = (1232.74, -523.778, 5.225);
			level.aMapPositions[level.aMapPositions.size] = (792.111, -890.508, 6.125);
			level.aMapPositions[level.aMapPositions.size] = (793.346, -250.063, -37.875);
			level.aMapPositions[level.aMapPositions.size] = (491.011, -342.287, -37.875);
			level.aMapPositions[level.aMapPositions.size] = (395.915, -1056.84, -37.875);
			level.aMapPositions[level.aMapPositions.size] = (547.763, -805.621, -37.875);
			level.aMapPositions[level.aMapPositions.size] = (-335.763, -806.898, -37.875);
			level.aMapPositions[level.aMapPositions.size] = (132.051, -788.732, -37.875);
			level.aMapPositions[level.aMapPositions.size] = (-430.839, -607.592, -37.875);
			level.aMapPositions[level.aMapPositions.size] = (-768.681, -757.23, -30.875);
			level.aMapPositions[level.aMapPositions.size] = (-788.75, -383.139, -37.875);
			level.aMapPositions[level.aMapPositions.size] = (-320.305, -270.036, -37.875);
			level.aMapPositions[level.aMapPositions.size] = (120.631, -108.941, -37.875);
			level.aMapPositions[level.aMapPositions.size] = (258.535, 232.949, -37.875);
			level.aMapPositions[level.aMapPositions.size] = (411.789, 10.6642, -37.875);
			level.aMapPositions[level.aMapPositions.size] = (793.959, 64.4022, -37.875);
			level.aMapPositions[level.aMapPositions.size] = (635.849, 311.078, -37.875);
			level.aMapPositions[level.aMapPositions.size] = (399.718, 399.181, -37.875);
			level.aMapPositions[level.aMapPositions.size] = (259.135, 394.666, -37.875);
			level.aMapPositions[level.aMapPositions.size] = (192.188, 633.095, -37.875);
			level.aMapPositions[level.aMapPositions.size] = (-216.177, 533.807, -37.875);
			level.aMapPositions[level.aMapPositions.size] = (-682.891, 630.676, -37.875);
			level.aMapPositions[level.aMapPositions.size] = (-583.219, -280.96, -37.875);
			level.aMapPositions[level.aMapPositions.size] = (-699.484, 79.7588, -101.875);
			level.aMapPositions[level.aMapPositions.size] = (-895.461, 323.082, -100.745);
			level.aMapPositions[level.aMapPositions.size] = (-1240.31, 843.409, -95.4967);
			level.aMapPositions[level.aMapPositions.size] = (-1438.73, -302.246, -99.3132);
			level.aMapPositions[level.aMapPositions.size] = (-2057.62, -289.258, -98.0341);
			level.aMapPositions[level.aMapPositions.size] = (-1686.07, 208.058, -92.875);
			level.aMapPositions[level.aMapPositions.size] = (-1618.88, 962.25, -84.0417);
			level.aMapPositions[level.aMapPositions.size] = (-2062.96, 1380.64, -98.2785);
			level.aMapPositions[level.aMapPositions.size] = (-1558.11, 1466.31, -97.6792);
			level.aMapPositions[level.aMapPositions.size] = (-905.655, 674.089, -99.1619);
			level.aMapPositions[level.aMapPositions.size] = (-1050.18, 1516.79, -100.279);
			level.aMapPositions[level.aMapPositions.size] = (-161.442, 1518.96, -102.199);
			level.aMapPositions[level.aMapPositions.size] = (738.932, 1535.32, -101.796);
			level.aMapPositions[level.aMapPositions.size] = (283.609, 1305.86, -96.8696);
			level.aMapPositions[level.aMapPositions.size] = (-285.328, 1597.49, -27.174);
			level.aMapPositions[level.aMapPositions.size] = (-439.885, 979.889, -94.0058);
			level.aMapPositions[level.aMapPositions.size] = (-413.941, 722.017, -37.875);
			level.aMapPositions[level.aMapPositions.size] = (441.467, 1136.69, -37.875);
			level.aMapPositions[level.aMapPositions.size] = (728.014, 823.918, -37.875);
			level.aMapPositions[level.aMapPositions.size] = (128.406, 741.669, -37.875);
			level.aMapPositions[level.aMapPositions.size] = (994.208, 1211.74, -37.875);
			level.aMapPositions[level.aMapPositions.size] = (1007.09, 731.284, -37.875);
			level.aMapPositions[level.aMapPositions.size] = (1135.58, 1195.7, -37.875);
			level.aMapPositions[level.aMapPositions.size] = (1264.12, 624.135, -37.875);
			level.aMapPositions[level.aMapPositions.size] = (944.244, 81.6833, -37.875);
			level.aMapPositions[level.aMapPositions.size] = (914.246, 235.169, -37.875);
			level.aMapPositions[level.aMapPositions.size] = (1637.14, 149.233, -17.875);
			level.aMapPositions[level.aMapPositions.size] = (1430.99, -73.3988, -37.875);
			level.aMapPositions[level.aMapPositions.size] = (897.073, -178.068, -37.875);
			level.aMapPositions[level.aMapPositions.size] = (1052.91, -914.99, -37.875);
			level.aMapPositions[level.aMapPositions.size] = (1514.13, -917.333, -37.875);

			//Drops
			level.aDropPositions[level.aDropPositions.size] = (578.845, 885.635, -37.875);
			level.aDropPositions[level.aDropPositions.size] = (-542.894, 1573.87, -101.875);
			level.aDropPositions[level.aDropPositions.size] = (-197.801, 926.901, -37.875);
			level.aDropPositions[level.aDropPositions.size] = (-1265.36, 1072.39, -96.1199);
			level.aDropPositions[level.aDropPositions.size] = (-1072.56, -4.54831, -47.875);
			level.aDropPositions[level.aDropPositions.size] = (-384.406, -1178.54, -35.875);
			level.aDropPositions[level.aDropPositions.size] = (-54.1793, -199.084, -37.875);
		break;
		case "mp_brecourt":
			level.aMapPositions[level.aMapPositions.size] = (182.365, -3784.97, 100.945);
			level.aMapPositions[level.aMapPositions.size] = (-2810.94, -265.839, 69.2636);
			level.aMapPositions[level.aMapPositions.size] = (2150.24, -3797.85, 109.76);
			level.aMapPositions[level.aMapPositions.size] = (2574.17, -3214, 45.4548);
			level.aMapPositions[level.aMapPositions.size] = (2914.74, -2862.32, -5.0139);
			level.aMapPositions[level.aMapPositions.size] = (4165.71, -1145.54, 30.9659);
			level.aMapPositions[level.aMapPositions.size] = (310.472, -3773.94, 102.942);
			level.aMapPositions[level.aMapPositions.size] = (3411.16, -1272.5, 33.3139);
			level.aMapPositions[level.aMapPositions.size] = (805.472, -3020.67, -3.52433);
			level.aMapPositions[level.aMapPositions.size] = (2243.31, 1137.56, -19.2177);
			level.aMapPositions[level.aMapPositions.size] = (1831.35, 1799.19, -47.4974);
			level.aMapPositions[level.aMapPositions.size] = (-458.16, 2186.34, 8.68471);
			level.aMapPositions[level.aMapPositions.size] = (2951.21, -791.469, -8.41243);
			level.aMapPositions[level.aMapPositions.size] = (-67.195, 1911.59, -45.3517);
			level.aMapPositions[level.aMapPositions.size] = (674.98, 2037.13, -23.0649);
			level.aMapPositions[level.aMapPositions.size] = (87.1136, -1074.32, 47.2608);
			level.aMapPositions[level.aMapPositions.size] = (-998.265, -868.352, 62.9659);
			level.aMapPositions[level.aMapPositions.size] = (-1649.69, -2688.38, 53.9113);
			level.aMapPositions[level.aMapPositions.size] = (-1474.87, -1292.29, 57.1237);
			level.aMapPositions[level.aMapPositions.size] = (1082.21, -2575.41, 124.733);
			level.aMapPositions[level.aMapPositions.size] = (1219.29, -2298.92, 44.8022);
			level.aMapPositions[level.aMapPositions.size] = (2185.92, -810.936, 40.3789);
			level.aMapPositions[level.aMapPositions.size] = (-1324.87, 241.414, 24.9311);
			level.aMapPositions[level.aMapPositions.size] = (-1897.56, 479.5, -14.4884);
			level.aMapPositions[level.aMapPositions.size] = (-2491.14, -1107.03, 29.9064);
			level.aMapPositions[level.aMapPositions.size] = (-1884.4, -1243.77, 56.2774);
			level.aMapPositions[level.aMapPositions.size] = (-3446.69, -130.483, 59.5913);
			level.aMapPositions[level.aMapPositions.size] = (-3193.89, 587.671, 45.8899);
			level.aMapPositions[level.aMapPositions.size] = (-3785.89, 1090.73, 58.125);
			level.aMapPositions[level.aMapPositions.size] = (-3763.86, 1576.2, 44.0517);
			level.aMapPositions[level.aMapPositions.size] = (-3101.8, 2013.59, 44.125);
			level.aMapPositions[level.aMapPositions.size] = (-2818.8, 2289.49, 111.676);
			level.aMapPositions[level.aMapPositions.size] = (-2271.4, 1749.96, 139.463);
			level.aMapPositions[level.aMapPositions.size] = (-121.435, 2210.69, 18.125);
			level.aMapPositions[level.aMapPositions.size] = (-1247.57, 1376.86, 61.7801);
			level.aMapPositions[level.aMapPositions.size] = (-831.459, 611.971, -48.1291);
			level.aMapPositions[level.aMapPositions.size] = (164.624, 382.925, 17.8913);
			level.aMapPositions[level.aMapPositions.size] = (1025.87, 231.432, 66.4883);
			level.aMapPositions[level.aMapPositions.size] = (1112.86, -648.419, -45.7082);
			level.aMapPositions[level.aMapPositions.size] = (709.095, -465.921, -26.2075);
			level.aMapPositions[level.aMapPositions.size] = (1027.64, -496.327, -34.059);
			level.aMapPositions[level.aMapPositions.size] = (1016.31, -1058.26, -47.5772);
			level.aMapPositions[level.aMapPositions.size] = (880.615, 1283.37, -16.9132);
			level.aMapPositions[level.aMapPositions.size] = (166.3, 1345.58, -94.0227);
			level.aMapPositions[level.aMapPositions.size] = (1946.13, 1421.42, -62.6604);
			level.aMapPositions[level.aMapPositions.size] = (1754.85, 338.964, 0.634582);
			level.aMapPositions[level.aMapPositions.size] = (2582.6, 314.108, -88.143);
			level.aMapPositions[level.aMapPositions.size] = (3232.78, 32.0139, -9.1887);
			level.aMapPositions[level.aMapPositions.size] = (3973.13, -126.36, -56.5583);
			level.aMapPositions[level.aMapPositions.size] = (3503.16, -858.705, 25.2223);
			level.aMapPositions[level.aMapPositions.size] = (1396.31, -337.191, 106.616);
			level.aMapPositions[level.aMapPositions.size] = (1831.46, -1487.69, -1.16924);
			level.aMapPositions[level.aMapPositions.size] = (2350.09, -1832.05, -3.70736);
			level.aMapPositions[level.aMapPositions.size] = (2959.47, -2101.75, 74.3295);
			level.aMapPositions[level.aMapPositions.size] = (-1587.22, -1588.41, 59.2554);
			level.aMapPositions[level.aMapPositions.size] = (4067.26, -1892.45, 20.6404);
			level.aMapPositions[level.aMapPositions.size] = (3925.16, -2666.44, 55.2094);
			level.aMapPositions[level.aMapPositions.size] = (-2549.18, -134.895, 26.9425);
			level.aMapPositions[level.aMapPositions.size] = (3683.64, -2911.78, 48.2396);
			level.aMapPositions[level.aMapPositions.size] = (-3442.13, 1282.67, 60.9381);
			level.aMapPositions[level.aMapPositions.size] = (1337.76, -3524.59, 53.4525);
			level.aMapPositions[level.aMapPositions.size] = (1020.11, -2787.35, 40.9678);
			level.aMapPositions[level.aMapPositions.size] = (1382.08, -3023.68, 43.6926);
			level.aMapPositions[level.aMapPositions.size] = (45.7029, -1575.31, 60.4594);
			level.aMapPositions[level.aMapPositions.size] = (-1083.39, 2399.55, 52.925);
			level.aMapPositions[level.aMapPositions.size] = (-1692.82, 1927.13, 52.925);
			level.aMapPositions[level.aMapPositions.size] = (345.649, -2397.03, -7.72564);
			level.aMapPositions[level.aMapPositions.size] = (-464.734, -2478.77, 51.0803);
			level.aMapPositions[level.aMapPositions.size] = (-116.069, 2014.3, 21.4153);
			level.aMapPositions[level.aMapPositions.size] = (71.938, -2909.79, 46.1264);
			level.aMapPositions[level.aMapPositions.size] = (376.386, 2222.22, 18.125);
			level.aMapPositions[level.aMapPositions.size] = (-297.062, -3276.88, 45.5181);
			level.aMapPositions[level.aMapPositions.size] = (-1202.61, -2576.33, -12.2641);
			level.aMapPositions[level.aMapPositions.size] = (1570.32, 1045.25, -83.875);
			level.aMapPositions[level.aMapPositions.size] = (2702.38, 1639.61, -69.2618);
			level.aMapPositions[level.aMapPositions.size] = (-1107.48, -3041.41, 79.7691);
			level.aMapPositions[level.aMapPositions.size] = (-2188.26, -1793.5, -16.7879);
			level.aMapPositions[level.aMapPositions.size] = (3565.05, 651.044, -94.2981);
			level.aMapPositions[level.aMapPositions.size] = (-2276.34, -1436.69, 42.2425);
			level.aMapPositions[level.aMapPositions.size] = (1804.86, -598.102, -8.53125);
			level.aMapPositions[level.aMapPositions.size] = (-1396.7, -2101.5, 30.2689);
			level.aMapPositions[level.aMapPositions.size] = (1213.41, -1915.9, 26.8989);
			level.aMapPositions[level.aMapPositions.size] = (-373.04, -396.114, 81.3469);
			level.aMapPositions[level.aMapPositions.size] = (-1511.87, -639.02, 2.61472);
			level.aMapPositions[level.aMapPositions.size] = (940.237, -2456.35, 50.3771);
			level.aMapPositions[level.aMapPositions.size] = (115.605, -569.591, -11.0679);
			level.aMapPositions[level.aMapPositions.size] = (652.663, -374.484, 124.182);

			//Drops
			level.aDropPositions[level.aDropPositions.size] = (3720.33, 279.558, -97.2377);
			level.aDropPositions[level.aDropPositions.size] = (2990.16, -1433.35, -2.41279);
			level.aDropPositions[level.aDropPositions.size] = (-320.468, -1624.78, 12.747);
			level.aDropPositions[level.aDropPositions.size] = (-1958.13, -934.453, 21.0294);
			level.aDropPositions[level.aDropPositions.size] = (-1702.03, 745.134, -23.3193);
			level.aDropPositions[level.aDropPositions.size] = (821.935, 695.163, -20.0217);
			level.aDropPositions[level.aDropPositions.size] = (2660.17, 457.48, -109.882);
			level.aDropPositions[level.aDropPositions.size] = (1706.78, -1275.6, 12.3322);
			level.aDropPositions[level.aDropPositions.size] = (512, -1152, 42);
		break;
		case "mp_invasion":
			level.aMapPositions[level.aMapPositions.size] = (-627.626, -1617.16, 274.125);
			level.aMapPositions[level.aMapPositions.size] = (481.885, -1574.73, 304.121);
			level.aMapPositions[level.aMapPositions.size] = (651.65, -1963.91, 300.791);
			level.aMapPositions[level.aMapPositions.size] = (1705.4, -2454.27, 298.125);
			level.aMapPositions[level.aMapPositions.size] = (2097.33, -2498.67, 300.775);
			level.aMapPositions[level.aMapPositions.size] = (1438.06, -2054.19, 298.125);
			level.aMapPositions[level.aMapPositions.size] = (824.294, -1359.38, 341.125);
			level.aMapPositions[level.aMapPositions.size] = (2176.79, -1432.29, 306.125);
			level.aMapPositions[level.aMapPositions.size] = (2326, -1037.96, 442.125);
			level.aMapPositions[level.aMapPositions.size] = (1414.81, -1414.97, 442.125);
			level.aMapPositions[level.aMapPositions.size] = (1020.89, -1581.13, 442.125);
			level.aMapPositions[level.aMapPositions.size] = (169.934, -867.747, 333.421);
			level.aMapPositions[level.aMapPositions.size] = (-311.985, 525.291, 266.125);
			level.aMapPositions[level.aMapPositions.size] = (-2333.69, -1048.09, 318.71);
			level.aMapPositions[level.aMapPositions.size] = (-417.311, -188.782, 310.125);
			level.aMapPositions[level.aMapPositions.size] = (604.79, -593.41, 249.367);
			level.aMapPositions[level.aMapPositions.size] = (-2855.09, -1144.68, 368.772);
			level.aMapPositions[level.aMapPositions.size] = (-2378.68, -2802.85, 274.125);
			level.aMapPositions[level.aMapPositions.size] = (-2670.64, -2220.79, 353.537);
			level.aMapPositions[level.aMapPositions.size] = (-1301.43, -2538.4, 276.125);
			level.aMapPositions[level.aMapPositions.size] = (-1035.15, -2142.76, 274.125);
			level.aMapPositions[level.aMapPositions.size] = (-2824.75, -1972.09, 274.125);
			level.aMapPositions[level.aMapPositions.size] = (-2858.79, -2559.29, 274.125);
			level.aMapPositions[level.aMapPositions.size] = (400.786, -2644.18, 260.747);
			level.aMapPositions[level.aMapPositions.size] = (242.022, -3127.28, 262.379);
			level.aMapPositions[level.aMapPositions.size] = (-558.016, -3790.38, 281.022);
			level.aMapPositions[level.aMapPositions.size] = (-1198.51, -3518.06, 282.287);
			level.aMapPositions[level.aMapPositions.size] = (-886.591, -2964.58, 261.291);
			level.aMapPositions[level.aMapPositions.size] = (30.2455, -274.895, 250.746);
			level.aMapPositions[level.aMapPositions.size] = (-261.972, 299.178, 266.125);
			level.aMapPositions[level.aMapPositions.size] = (-1132.93, -2728.65, 276.125);
			level.aMapPositions[level.aMapPositions.size] = (-1663.77, -3693.11, 274.125);
			level.aMapPositions[level.aMapPositions.size] = (-2217.64, -3805.55, 277.415);
			level.aMapPositions[level.aMapPositions.size] = (1064.94, -639.609, 442.125);
			level.aMapPositions[level.aMapPositions.size] = (-2891.8, -3515.93, 271.523);
			level.aMapPositions[level.aMapPositions.size] = (-2968.59, -2945.06, 275.215);
			level.aMapPositions[level.aMapPositions.size] = (-3425.99, -2937.74, 266.125);
			level.aMapPositions[level.aMapPositions.size] = (-3527.31, -2204.64, 266.125);
			level.aMapPositions[level.aMapPositions.size] = (-2927.38, -2527.72, 426.125);
			level.aMapPositions[level.aMapPositions.size] = (2205.64, -1327.66, 442.125);
			level.aMapPositions[level.aMapPositions.size] = (-2305.22, -3034.09, 418.125);
			level.aMapPositions[level.aMapPositions.size] = (-2209.08, -2830.96, 420.598);
			level.aMapPositions[level.aMapPositions.size] = (-2410.78, -2914.45, 282.125);
			level.aMapPositions[level.aMapPositions.size] = (-2200.71, -3092.21, 282.125);
			level.aMapPositions[level.aMapPositions.size] = (-2005.04, -2841.84, 282.125);
			level.aMapPositions[level.aMapPositions.size] = (-2203.87, -2581.49, 274.013);
			level.aMapPositions[level.aMapPositions.size] = (2271.22, -1703.33, 306.125);
			level.aMapPositions[level.aMapPositions.size] = (-2502.94, -1598.38, 274.125);
			level.aMapPositions[level.aMapPositions.size] = (-3302.7, -1735.03, 282.125);
			level.aMapPositions[level.aMapPositions.size] = (-3559.84, -1469.88, 282.125);
			level.aMapPositions[level.aMapPositions.size] = (-2980.1, -1489.12, 274.125);
			level.aMapPositions[level.aMapPositions.size] = (1455.59, -2737.38, 300.791);
			level.aMapPositions[level.aMapPositions.size] = (1264.49, -2971.31, 316.125);
			level.aMapPositions[level.aMapPositions.size] = (779.228, -2860.65, 316.125);
			level.aMapPositions[level.aMapPositions.size] = (392.941, -1905.05, 309.236);
			level.aMapPositions[level.aMapPositions.size] = (202.405, -1822.68, 274.125);
			level.aMapPositions[level.aMapPositions.size] = (1002.36, -3598.8, 260.591);
			level.aMapPositions[level.aMapPositions.size] = (-642.005, -2174.46, 274.125);
			level.aMapPositions[level.aMapPositions.size] = (-48.7431, -2330.88, 266.125);
			level.aMapPositions[level.aMapPositions.size] = (-718.214, -3659.62, 394.125);
			level.aMapPositions[level.aMapPositions.size] = (-668.545, -2552.69, 268.216);
			level.aMapPositions[level.aMapPositions.size] = (-742.599, -3573.98, 298.48);
			level.aMapPositions[level.aMapPositions.size] = (-1330.6, -747.819, 274.125);
			level.aMapPositions[level.aMapPositions.size] = (-1934.64, -771.758, 282.125);
			level.aMapPositions[level.aMapPositions.size] = (-923.939, -3833.08, 297.889);
			level.aMapPositions[level.aMapPositions.size] = (-2510.33, -608.586, 282.125);
			level.aMapPositions[level.aMapPositions.size] = (-1920.87, -1180.01, 303.847);
			level.aMapPositions[level.aMapPositions.size] = (-1587.07, -3733.86, 477.125);
			level.aMapPositions[level.aMapPositions.size] = (-2192.24, -1656.47, 278.125);
			level.aMapPositions[level.aMapPositions.size] = (-2358.06, -1368.58, 314.125);
			level.aMapPositions[level.aMapPositions.size] = (-988.444, -2682.5, 276.125);
			level.aMapPositions[level.aMapPositions.size] = (-2401.47, -1812.61, 278.125);
			level.aMapPositions[level.aMapPositions.size] = (-1315.12, -3044.85, 276.125);
			level.aMapPositions[level.aMapPositions.size] = (-2197.05, -2320.48, 278.125);
			level.aMapPositions[level.aMapPositions.size] = (-1367.96, -2121.65, 280.125);
			level.aMapPositions[level.aMapPositions.size] = (-2043.64, -1746.69, 278.125);
			level.aMapPositions[level.aMapPositions.size] = (-1645.4, -1736.23, 266.134);
			level.aMapPositions[level.aMapPositions.size] = (-799.243, -1420.5, 279.125);
			level.aMapPositions[level.aMapPositions.size] = (-1481.5, -1230.5, 280.125);
			level.aMapPositions[level.aMapPositions.size] = (-832.675, -1116.91, 303.125);
			level.aMapPositions[level.aMapPositions.size] = (-1353.72, -1669.23, 280.125);
			level.aMapPositions[level.aMapPositions.size] = (-3382.29, -730.655, 274.125);

			//Drops
			level.aDropPositions[level.aDropPositions.size] = (-2651.55, -2045.4, 266.125);
			level.aDropPositions[level.aDropPositions.size] = (-3462.41, -2010.36, 266.125);
			level.aDropPositions[level.aDropPositions.size] = (-3298.93, -2782.83, 266.125);
			level.aDropPositions[level.aDropPositions.size] = (-304.745, -2400.51, 266.125);
			level.aDropPositions[level.aDropPositions.size] = (-608.486, -3240.75, 266.138);
			level.aDropPositions[level.aDropPositions.size] = (1016.18, -2199.13, 298.125);
			level.aDropPositions[level.aDropPositions.size] = (-332.541, -588.899, 343.785);
			level.aDropPositions[level.aDropPositions.size] = (-1051.39, -853.222, 265.865);
			level.aDropPositions[level.aDropPositions.size] = (-2260.59, -1041.86, 319.502);
			level.aDropPositions[level.aDropPositions.size] = (-1772.94, -2036.85, 258.125);
			level.aDropPositions[level.aDropPositions.size] = (-1662.3, -3245.22, 263.377);
			level.aDropPositions[level.aDropPositions.size] = (352.031, -2944.92, 260.412);
			level.aDropPositions[level.aDropPositions.size] = (740.084, -1353.26, 332.125);
			level.aDropPositions[level.aDropPositions.size] = (-348.424, -1822.4, 275);
		break;
		case "mp_compact":
			level.aMapPositions[level.aMapPositions.size] = (1411.96, 153.392, -2.56986);
			level.aMapPositions[level.aMapPositions.size] = (2016.89, 2912.36, 61.6317);
			level.aMapPositions[level.aMapPositions.size] = (1977.07, -5.21598, 22.5162);
			level.aMapPositions[level.aMapPositions.size] = (1867.85, 227.707, 30.4527);
			level.aMapPositions[level.aMapPositions.size] = (1629.12, 1763.02, 11.2041);
			level.aMapPositions[level.aMapPositions.size] = (329.727, 1797.77, 79.077);
			level.aMapPositions[level.aMapPositions.size] = (380.378, 1089.69, 17.3815);
			level.aMapPositions[level.aMapPositions.size] = (1077.74, 1007.49, 5.25728);
			level.aMapPositions[level.aMapPositions.size] = (1624.26, 1473.57, 31.0062);
			level.aMapPositions[level.aMapPositions.size] = (865.014, -94.1478, 39.8553);
			level.aMapPositions[level.aMapPositions.size] = (135.316, 229.37, 23.0829);
			level.aMapPositions[level.aMapPositions.size] = (1581.65, -266.603, 19.5618);
			level.aMapPositions[level.aMapPositions.size] = (1597.86, -387.041, 31.0539);
			level.aMapPositions[level.aMapPositions.size] = (1741.33, 379.544, 7.89813);
			level.aMapPositions[level.aMapPositions.size] = (1647.86, 738.129, 7.14557);
			level.aMapPositions[level.aMapPositions.size] = (2090.25, -78.443, 23.3307);
			level.aMapPositions[level.aMapPositions.size] = (1489.66, 1121.7, 14.2288);
			level.aMapPositions[level.aMapPositions.size] = (2314.67, -1019.87, 82.125);
			level.aMapPositions[level.aMapPositions.size] = (2079.07, -1242.66, 100.325);
			level.aMapPositions[level.aMapPositions.size] = (2074.75, 254.267, 130.125);
			level.aMapPositions[level.aMapPositions.size] = (2517.23, 236.645, 12.7372);
			level.aMapPositions[level.aMapPositions.size] = (2913.76, 1411.78, 19.5486);
			level.aMapPositions[level.aMapPositions.size] = (2897.7, 1079.62, 29.2135);
			level.aMapPositions[level.aMapPositions.size] = (2007.41, -269.659, 45.9625);
			level.aMapPositions[level.aMapPositions.size] = (2559.56, 1303.62, 86.1519);
			level.aMapPositions[level.aMapPositions.size] = (2577.82, 1413.49, 146.125);
			level.aMapPositions[level.aMapPositions.size] = (2063.95, 1005.58, 26.1716);
			level.aMapPositions[level.aMapPositions.size] = (2333.17, 2.59745, 26.7233);
			level.aMapPositions[level.aMapPositions.size] = (2382.93, 903.388, 23.4774);
			level.aMapPositions[level.aMapPositions.size] = (2722.1, 671.476, 17.3601);
			level.aMapPositions[level.aMapPositions.size] = (2382.66, 589.938, 24.3561);
			level.aMapPositions[level.aMapPositions.size] = (2211.41, -363.123, 156.554);
			level.aMapPositions[level.aMapPositions.size] = (2890.19, 581.573, 22.4395);
			level.aMapPositions[level.aMapPositions.size] = (2390.8, 1516.97, 13.0065);
			level.aMapPositions[level.aMapPositions.size] = (1971.82, -389.63, 38.0953);
			level.aMapPositions[level.aMapPositions.size] = (2001.73, 2183.96, 210.125);
			level.aMapPositions[level.aMapPositions.size] = (1877.7, 2039.55, 146.125);
			level.aMapPositions[level.aMapPositions.size] = (1597.78, -1277.56, 10.125);
			level.aMapPositions[level.aMapPositions.size] = (2438.6, 3304.75, 86.6594);
			level.aMapPositions[level.aMapPositions.size] = (3200.4, 2715.26, 31.1577);
			level.aMapPositions[level.aMapPositions.size] = (1189.42, -1509.39, 19.6821);
			level.aMapPositions[level.aMapPositions.size] = (3540.29, 2763.9, 26.2155);
			level.aMapPositions[level.aMapPositions.size] = (1103.82, -817.106, 18.7482);
			level.aMapPositions[level.aMapPositions.size] = (4238.9, 2024.5, 36.4788);
			level.aMapPositions[level.aMapPositions.size] = (3808.62, 1909.9, 18.2037);
			level.aMapPositions[level.aMapPositions.size] = (874.295, -559.74, 18.1249);
			level.aMapPositions[level.aMapPositions.size] = (1163.02, -497, 18.1249);
			level.aMapPositions[level.aMapPositions.size] = (2566.65, 2120.42, 50.863);
			level.aMapPositions[level.aMapPositions.size] = (1182.38, -311.543, 18.1249);
			level.aMapPositions[level.aMapPositions.size] = (304.695, -231.418, 22.0965);
			level.aMapPositions[level.aMapPositions.size] = (232.671, -93.2495, 29.3142);
			level.aMapPositions[level.aMapPositions.size] = (3379.97, 2136.15, 10.0086);
			level.aMapPositions[level.aMapPositions.size] = (3026.91, 1894.64, 27.5299);
			level.aMapPositions[level.aMapPositions.size] = (857.73, 745.016, 16.3074);
			level.aMapPositions[level.aMapPositions.size] = (382.959, 1636.9, 55.8236);
			level.aMapPositions[level.aMapPositions.size] = (2226.42, 1757.83, 16.5262);
			level.aMapPositions[level.aMapPositions.size] = (535.55, 2034.49, 80.0782);
			level.aMapPositions[level.aMapPositions.size] = (2063.59, 2232.56, 10.125);
			level.aMapPositions[level.aMapPositions.size] = (1539, 2156.98, 64.2436);
			level.aMapPositions[level.aMapPositions.size] = (1674.21, 2310.59, 10.125);
			level.aMapPositions[level.aMapPositions.size] = (1055.79, 1921.08, 130.102);
			level.aMapPositions[level.aMapPositions.size] = (2444.5, 2429.12, 19.7189);
			level.aMapPositions[level.aMapPositions.size] = (2155.38, 2025.04, 10.125);
			level.aMapPositions[level.aMapPositions.size] = (2553.6, 2862.78, 38.62);
			level.aMapPositions[level.aMapPositions.size] = (1075.62, 2705.3, 90.125);
			level.aMapPositions[level.aMapPositions.size] = (1654.44, 3304.3, 76.8885);
			level.aMapPositions[level.aMapPositions.size] = (1639.79, 2426.7, 10.125);
			level.aMapPositions[level.aMapPositions.size] = (365.403, 1274.79, 46.3734);
			level.aMapPositions[level.aMapPositions.size] = (115.214, 2484.35, 90.125);

			//Drops
			level.aDropPositions[level.aDropPositions.size] = (992.442, 507.102, 58.125);
			level.aDropPositions[level.aDropPositions.size] = (1331.65, -1072.46, 3.67845);
			level.aDropPositions[level.aDropPositions.size] = (1903.21, 2648.06, 36.668);
			level.aDropPositions[level.aDropPositions.size] = (1282.48, 2130.65, 48.125);
			level.aDropPositions[level.aDropPositions.size] = (1858.22, 1385.53, -6.49965);
			level.aDropPositions[level.aDropPositions.size] = (2516.79, 1772.61, 18.4408);
			level.aDropPositions[level.aDropPositions.size] = (2701.33, 1041.74, 7.4974);
			level.aDropPositions[level.aDropPositions.size] = (2391.8, -156.57, 6.48201);
			level.aDropPositions[level.aDropPositions.size] = (1485.92, -53.2689, 10.1167);
			level.aDropPositions[level.aDropPositions.size] = (396.627, 38.7408, 10.4697);
			level.aDropPositions[level.aDropPositions.size] = (351.456, 809.849, 6.56049);
			level.aDropPositions[level.aDropPositions.size] = (481.004, 1811.19, 58.125);
		break;
		case "mp_checkpoint":
			level.aMapPositions[level.aMapPositions.size] = (81.1011, -360.914, 108.346);
			level.aMapPositions[level.aMapPositions.size] = (-804.204, -333.347, 206.728);
			level.aMapPositions[level.aMapPositions.size] = (-1021.41, -83.4523, 147.125);
			level.aMapPositions[level.aMapPositions.size] = (-800.297, -660.217, -6.54458);
			level.aMapPositions[level.aMapPositions.size] = (-1054.27, -687.48, -5.875);
			level.aMapPositions[level.aMapPositions.size] = (424.872, 765.671, 54.125);
			level.aMapPositions[level.aMapPositions.size] = (-776.659, 1763.59, 41.1986);
			level.aMapPositions[level.aMapPositions.size] = (232.296, 1915.66, 16.1215);
			level.aMapPositions[level.aMapPositions.size] = (1327.39, 1609, 18.125);
			level.aMapPositions[level.aMapPositions.size] = (-234.097, -610.39, 242.125);
			level.aMapPositions[level.aMapPositions.size] = (-529.279, 711.919, 229.125);
			level.aMapPositions[level.aMapPositions.size] = (-417.242, 87.0407, 250.125);
			level.aMapPositions[level.aMapPositions.size] = (-55.5061, -166.054, 44.7748);
			level.aMapPositions[level.aMapPositions.size] = (204.622, 143.631, 49.2168);
			level.aMapPositions[level.aMapPositions.size] = (-329.217, -441.275, 72.6087);
			level.aMapPositions[level.aMapPositions.size] = (-641.711, -97.8203, 18.125);
			level.aMapPositions[level.aMapPositions.size] = (-1374.35, -81.8896, 18.125);
			level.aMapPositions[level.aMapPositions.size] = (799.303, 1000, 258.125);
			level.aMapPositions[level.aMapPositions.size] = (-1739.02, 124.587, 10.125);
			level.aMapPositions[level.aMapPositions.size] = (-1803.8, 95.0674, 162.125);
			level.aMapPositions[level.aMapPositions.size] = (-128.261, 977.719, 210.125);
			level.aMapPositions[level.aMapPositions.size] = (-397.366, 1233.09, 234.125);
			level.aMapPositions[level.aMapPositions.size] = (-2053.93, 510.548, 162.125);
			level.aMapPositions[level.aMapPositions.size] = (-1184.88, -510.606, 146.125);
			level.aMapPositions[level.aMapPositions.size] = (-466.993, 447.987, 210.125);
			level.aMapPositions[level.aMapPositions.size] = (-1052.53, -971.873, 146.125);
			level.aMapPositions[level.aMapPositions.size] = (-19.0123, 522.572, 210.125);
			level.aMapPositions[level.aMapPositions.size] = (253.272, 773.163, 18.125);
			level.aMapPositions[level.aMapPositions.size] = (-637.425, -1032.74, -13.875);
			level.aMapPositions[level.aMapPositions.size] = (-135.491, 664.117, 18.125);
			level.aMapPositions[level.aMapPositions.size] = (-1333.12, -938.549, 15.8516);
			level.aMapPositions[level.aMapPositions.size] = (-443.346, 876.341, 18.125);
			level.aMapPositions[level.aMapPositions.size] = (-1799.81, -1177.6, 10.125);
			level.aMapPositions[level.aMapPositions.size] = (-1034.38, 639.669, 18.125);
			level.aMapPositions[level.aMapPositions.size] = (-1103.75, -491.755, 278.125);
			level.aMapPositions[level.aMapPositions.size] = (-586.652, -459.22, 374.018);
			level.aMapPositions[level.aMapPositions.size] = (-768.35, 2264.15, 10.4088);
			level.aMapPositions[level.aMapPositions.size] = (-702.108, -662.378, 242.125);
			level.aMapPositions[level.aMapPositions.size] = (-951.424, 2007.49, 16.125);
			level.aMapPositions[level.aMapPositions.size] = (-706.301, -921.105, 241.069);
			level.aMapPositions[level.aMapPositions.size] = (-1417.73, 1777.61, 50.125);
			level.aMapPositions[level.aMapPositions.size] = (-452.249, -1119.65, 244.759);
			level.aMapPositions[level.aMapPositions.size] = (-1040.31, 1292.01, 18.125);
			level.aMapPositions[level.aMapPositions.size] = (-494.712, 1191.57, 2.125);
			level.aMapPositions[level.aMapPositions.size] = (33.5036, -1503.47, 20.125);
			level.aMapPositions[level.aMapPositions.size] = (211.136, 1269.33, 70.125);
			level.aMapPositions[level.aMapPositions.size] = (489.822, -2662.91, 13.3577);
			level.aMapPositions[level.aMapPositions.size] = (-490.229, 1632.9, 65.512);
			level.aMapPositions[level.aMapPositions.size] = (552.023, -3403.96, 11.7477);
			level.aMapPositions[level.aMapPositions.size] = (159.234, -3031.06, 23.2312);
			level.aMapPositions[level.aMapPositions.size] = (723.389, 2162.72, 7.99255);
			level.aMapPositions[level.aMapPositions.size] = (-301.219, -2817.77, 15.1875);
			level.aMapPositions[level.aMapPositions.size] = (-289.453, 2254.59, 42.625);
			level.aMapPositions[level.aMapPositions.size] = (-597.009, 1710.28, 34.125);
			level.aMapPositions[level.aMapPositions.size] = (-38.3091, 1340.71, 58.212);
			level.aMapPositions[level.aMapPositions.size] = (260.54, 1012.1, 61.3088);
			level.aMapPositions[level.aMapPositions.size] = (1304.95, -111.358, -5.875);
			level.aMapPositions[level.aMapPositions.size] = (1076.88, 1268.86, 22.125);
			level.aMapPositions[level.aMapPositions.size] = (915.228, -184.504, 18.125);
			level.aMapPositions[level.aMapPositions.size] = (1545.8, 533.219, 46.125);
			level.aMapPositions[level.aMapPositions.size] = (1952.36, 1375.82, 50.125);
			level.aMapPositions[level.aMapPositions.size] = (1943.32, 1469.11, 18.125);
			level.aMapPositions[level.aMapPositions.size] = (1848.08, 1069.27, 50.125);
			level.aMapPositions[level.aMapPositions.size] = (1279.9, 6.84705, 18.125);
			level.aMapPositions[level.aMapPositions.size] = (2120.95, 369.921, 10.125);
			level.aMapPositions[level.aMapPositions.size] = (1924.74, 21.9884, 18.125);
			level.aMapPositions[level.aMapPositions.size] = (1045.37, -1398.53, 10.125);
			level.aMapPositions[level.aMapPositions.size] = (1396.92, -1326.95, 11.6614);
			level.aMapPositions[level.aMapPositions.size] = (1783.22, -1014.8, 20.2693);
			level.aMapPositions[level.aMapPositions.size] = (514.839, -1348.93, 22.125);
			level.aMapPositions[level.aMapPositions.size] = (523.824, -893.961, 40.125);
			level.aMapPositions[level.aMapPositions.size] = (804.503, -665.21, 17.3232);
			level.aMapPositions[level.aMapPositions.size] = (-73.0612, -1605.64, 20.125);
			level.aMapPositions[level.aMapPositions.size] = (1348.6, -504.482, 146.125);
			level.aMapPositions[level.aMapPositions.size] = (391.066, -1412.9, 20.125);
			level.aMapPositions[level.aMapPositions.size] = (729.991, -1568.43, 18.125);
			level.aMapPositions[level.aMapPositions.size] = (-16.8019, -1905.05, 10.125);
			level.aMapPositions[level.aMapPositions.size] = (837.622, 564.374, 154.125);
			level.aMapPositions[level.aMapPositions.size] = (106.729, -2015.44, 18.6378);
			level.aMapPositions[level.aMapPositions.size] = (-617.56, -2788.24, 10.4821);
			level.aMapPositions[level.aMapPositions.size] = (1541.47, 83.2142, 182.125);
			level.aMapPositions[level.aMapPositions.size] = (-438.845, -1530.02, 14.9837);
			level.aMapPositions[level.aMapPositions.size] = (1202.23, 100.521, 154.125);
			level.aMapPositions[level.aMapPositions.size] = (664.938, -174.824, 154.125);
			level.aMapPositions[level.aMapPositions.size] = (784.578, 135.247, 18.125);
			level.aMapPositions[level.aMapPositions.size] = (556.689, 568.138, 49.2312);

			//Drops
			level.aDropPositions[level.aDropPositions.size] = (-402.572, 47.0359, 250.125);
			level.aDropPositions[level.aDropPositions.size] = (-130.485, 655.14, 18.125);
			level.aDropPositions[level.aDropPositions.size] = (78.2744, -6.74512, 346);
			level.aDropPositions[level.aDropPositions.size] = (-1663.14, 212.336, 181.125);
			level.aDropPositions[level.aDropPositions.size] = (1165.34, 781.438, 10.125);
			level.aDropPositions[level.aDropPositions.size] = (1452.39, -740.038, 12.0625);
			level.aDropPositions[level.aDropPositions.size] = (-2.57674, -1088.22, 68.273);
			level.aDropPositions[level.aDropPositions.size] = (-918.422, -1110.12, -22.7843);
			level.aDropPositions[level.aDropPositions.size] = (-735.367, 132.245, 10.125);
			level.aDropPositions[level.aDropPositions.size] = (-207.103, 1432.45, 58.1276);
		break;
		case "mp_storm":
			level.aMapPositions[level.aMapPositions.size] = (839.831, 1056.85, 138.125);
			level.aMapPositions[level.aMapPositions.size] = (797.181, 471.865, 138.125);
			level.aMapPositions[level.aMapPositions.size] = (800.215, 179.291, 146.125);
			level.aMapPositions[level.aMapPositions.size] = (393.722, 308.252, 144.645);
			level.aMapPositions[level.aMapPositions.size] = (-299.165, -43.8449, 10.125);
			level.aMapPositions[level.aMapPositions.size] = (522.346, -546.071, 10.125);
			level.aMapPositions[level.aMapPositions.size] = (1017.62, -403.973, 10.125);
			level.aMapPositions[level.aMapPositions.size] = (1021.37, 319.664, 10.125);
			level.aMapPositions[level.aMapPositions.size] = (695.778, 228.62, 10.125);
			level.aMapPositions[level.aMapPositions.size] = (112.64, 326.613, 10.125);
			level.aMapPositions[level.aMapPositions.size] = (84.0642, 23.4335, 10.125);
			level.aMapPositions[level.aMapPositions.size] = (-85.4818, -118.173, 10.125);
			level.aMapPositions[level.aMapPositions.size] = (21.0371, -542.309, 10.125);
			level.aMapPositions[level.aMapPositions.size] = (-508.284, -523.766, 10.125);
			level.aMapPositions[level.aMapPositions.size] = (-647.853, 311.938, 11.125);
			level.aMapPositions[level.aMapPositions.size] = (-1005.31, 120.793, 10.125);
			level.aMapPositions[level.aMapPositions.size] = (-797.15, -333.206, 19.125);
			level.aMapPositions[level.aMapPositions.size] = (-516.288, -448.563, 138.125);
			level.aMapPositions[level.aMapPositions.size] = (129.16, -514.985, 138.125);
			level.aMapPositions[level.aMapPositions.size] = (304.092, -649.682, 10.125);
			level.aMapPositions[level.aMapPositions.size] = (572.505, -656.529, 10.125);
			level.aMapPositions[level.aMapPositions.size] = (1036.1, -904.905, 37.125);
			level.aMapPositions[level.aMapPositions.size] = (1130.4, -1137.44, -10.767);
			level.aMapPositions[level.aMapPositions.size] = (1612.47, -356.441, -53.875);
			level.aMapPositions[level.aMapPositions.size] = (1418.25, -859.841, -53.875);
			level.aMapPositions[level.aMapPositions.size] = (1144.66, -87.8838, -53.875);
			level.aMapPositions[level.aMapPositions.size] = (1698.24, 47.0317, -53.875);
			level.aMapPositions[level.aMapPositions.size] = (1789.12, 324.799, 10.125);
			level.aMapPositions[level.aMapPositions.size] = (1416.97, 312.389, 10.125);
			level.aMapPositions[level.aMapPositions.size] = (1602.5, 451.902, 2.125);
			level.aMapPositions[level.aMapPositions.size] = (1481.16, 440.219, 2.125);
			level.aMapPositions[level.aMapPositions.size] = (959.435, 436.919, 2.125);
			level.aMapPositions[level.aMapPositions.size] = (1245.14, 738.699, 2.125);
			level.aMapPositions[level.aMapPositions.size] = (1786.66, 637.905, 10.125);
			level.aMapPositions[level.aMapPositions.size] = (1216.65, 1356.1, 2.125);
			level.aMapPositions[level.aMapPositions.size] = (643.246, 1012.7, 10.125);
			level.aMapPositions[level.aMapPositions.size] = (287.193, 872.687, 2.125);
			level.aMapPositions[level.aMapPositions.size] = (25.0269, 429.534, 2.9673);
			level.aMapPositions[level.aMapPositions.size] = (543.135, 502.779, 2.125);
			level.aMapPositions[level.aMapPositions.size] = (113.011, 1245.24, 2.125);
			level.aMapPositions[level.aMapPositions.size] = (-51.7198, 944.783, 2.125);
			level.aMapPositions[level.aMapPositions.size] = (-72.7041, 660.102, 109.125);
			level.aMapPositions[level.aMapPositions.size] = (-432.749, 949.305, 2.125);
			level.aMapPositions[level.aMapPositions.size] = (-266.936, 744.539, 2.125);
			level.aMapPositions[level.aMapPositions.size] = (-980.276, 545.534, 2.10455);
			level.aMapPositions[level.aMapPositions.size] = (-761.818, 1350.12, 2.64234);
			level.aMapPositions[level.aMapPositions.size] = (-1485.65, 951.367, 2.125);
			level.aMapPositions[level.aMapPositions.size] = (-1792.09, 788.543, 138.125);
			level.aMapPositions[level.aMapPositions.size] = (-1917.18, 853.054, 10.125);
			level.aMapPositions[level.aMapPositions.size] = (-1811.2, 1097.06, 2.125);
			level.aMapPositions[level.aMapPositions.size] = (-1557.11, 554.769, 10.125);
			level.aMapPositions[level.aMapPositions.size] = (-1368.67, 781.209, 10.125);
			level.aMapPositions[level.aMapPositions.size] = (-1252.81, 504.326, 9.52696);
			level.aMapPositions[level.aMapPositions.size] = (-834.702, -427.551, 4.09188);
			level.aMapPositions[level.aMapPositions.size] = (-903.409, -789.797, 2.125);
			level.aMapPositions[level.aMapPositions.size] = (-1098.43, 102.059, 2.07478);
			level.aMapPositions[level.aMapPositions.size] = (-1935.04, 404.64, 2.12043);
			level.aMapPositions[level.aMapPositions.size] = (-2379, 75.4702, 20.1826);
			level.aMapPositions[level.aMapPositions.size] = (-2378.35, -513.943, 8.79478);
			level.aMapPositions[level.aMapPositions.size] = (-1640.58, -943.1, 2.88314);
			level.aMapPositions[level.aMapPositions.size] = (-1863.78, -1193, 4.75803);
			level.aMapPositions[level.aMapPositions.size] = (-1748.78, -1615.39, 10.125);
			level.aMapPositions[level.aMapPositions.size] = (-1173.06, -1662.98, 10.125);
			level.aMapPositions[level.aMapPositions.size] = (-833.165, -1555.27, 2.125);
			level.aMapPositions[level.aMapPositions.size] = (-747.123, -1194.62, 28.125);
			level.aMapPositions[level.aMapPositions.size] = (-1554.51, -1106.53, 137.868);
			level.aMapPositions[level.aMapPositions.size] = (416.604, -640.645, 144.125);
			level.aMapPositions[level.aMapPositions.size] = (-656.528, -1050.57, 136.821);
			level.aMapPositions[level.aMapPositions.size] = (-1232.24, -883.761, 138.125);
			level.aMapPositions[level.aMapPositions.size] = (-792.366, -1864.44, 146.125);
			level.aMapPositions[level.aMapPositions.size] = (-657.299, -1046.09, 2.64055);
			level.aMapPositions[level.aMapPositions.size] = (-259.121, -645.667, 6.80745);
			level.aMapPositions[level.aMapPositions.size] = (89.1026, -643.056, 3.39893);
			level.aMapPositions[level.aMapPositions.size] = (976.471, -1011.42, 2.125);
			level.aMapPositions[level.aMapPositions.size] = (465.862, -877.922, 2.125);
			level.aMapPositions[level.aMapPositions.size] = (54.5301, -1404.19, 2.125);
			level.aMapPositions[level.aMapPositions.size] = (-268.127, -1326.84, 2.125);
			level.aMapPositions[level.aMapPositions.size] = (-511.61, -1325.02, 8.125);
			level.aMapPositions[level.aMapPositions.size] = (-423.331, -1684.15, 26.125);
			level.aMapPositions[level.aMapPositions.size] = (-73.8287, -2043.01, 47.125);
			level.aMapPositions[level.aMapPositions.size] = (1042.39, -1584.84, 3.6079);
			level.aMapPositions[level.aMapPositions.size] = (655.371, -1789.61, 2.125);
			level.aMapPositions[level.aMapPositions.size] = (1235.3, -1807.25, 8.625);
			level.aMapPositions[level.aMapPositions.size] = (1175.72, -1576.56, 10.125);
			level.aMapPositions[level.aMapPositions.size] = (1478.72, -1399.3, 10.125);
			level.aMapPositions[level.aMapPositions.size] = (1554.98, -1293.13, -53.059);
			level.aMapPositions[level.aMapPositions.size] = (1952.07, -1010.79, 2.125);

			//Drops
			level.aDropPositions[level.aDropPositions.size] = (-1202.44, -115.282, 2.125);
			level.aDropPositions[level.aDropPositions.size] = (-896.894, 1114.22, 2.125);
			level.aDropPositions[level.aDropPositions.size] = (339.064, 684.039, 2.02757);
			level.aDropPositions[level.aDropPositions.size] = (1086.82, 1014.15, 2.125);
			level.aDropPositions[level.aDropPositions.size] = (1433.02, -41.1263, -53.875);
			level.aDropPositions[level.aDropPositions.size] = (1517.29, -1206.76, -56.0893);
			level.aDropPositions[level.aDropPositions.size] = (768.652, -1241.01, 2.125);
			level.aDropPositions[level.aDropPositions.size] = (-430.871, -854.83, 3.125);
			level.aDropPositions[level.aDropPositions.size] = (-2000.7, -358.412, -4.24828);
		break;
		case "mp_rundown":
			level.aMapPositions[level.aMapPositions.size] = (2725.2, -1698.16, 186.837);
			level.aMapPositions[level.aMapPositions.size] = (2023.95, -682.108, 46.125);
			level.aMapPositions[level.aMapPositions.size] = (524.768, 3303.41, 60.5327);
			level.aMapPositions[level.aMapPositions.size] = (2188, 267.574, 20.3007);
			level.aMapPositions[level.aMapPositions.size] = (2323.01, 1195.56, -68.1465);
			level.aMapPositions[level.aMapPositions.size] = (1800.49, 1792.69, -81.1327);
			level.aMapPositions[level.aMapPositions.size] = (-393.523, -1328.38, 28.9809);
			level.aMapPositions[level.aMapPositions.size] = (115.148, -1263.6, 26.7677);
			level.aMapPositions[level.aMapPositions.size] = (86.026, -1660.72, 32.4767);
			level.aMapPositions[level.aMapPositions.size] = (582.976, -2026.46, 129.368);
			level.aMapPositions[level.aMapPositions.size] = (962.029, -2106.48, 179.632);
			level.aMapPositions[level.aMapPositions.size] = (-609.746, 2458.1, 162.49);
			level.aMapPositions[level.aMapPositions.size] = (1422.46, -1887.23, 204.811);
			level.aMapPositions[level.aMapPositions.size] = (570.566, -1090.47, 33.6857);
			level.aMapPositions[level.aMapPositions.size] = (631.615, -354.601, 26.125);
			level.aMapPositions[level.aMapPositions.size] = (311.427, -509.416, 29.5101);
			level.aMapPositions[level.aMapPositions.size] = (1081.17, 1425.71, 66.4978);
			level.aMapPositions[level.aMapPositions.size] = (938.292, 829.716, 29.312);
			level.aMapPositions[level.aMapPositions.size] = (1640.8, 627.929, 7.25253);
			level.aMapPositions[level.aMapPositions.size] = (226.249, 214.887, 172.125);
			level.aMapPositions[level.aMapPositions.size] = (126.574, 847.7, 26.808);
			level.aMapPositions[level.aMapPositions.size] = (654.465, 265.573, 32.0519);
			level.aMapPositions[level.aMapPositions.size] = (954.122, -588.133, 30.125);
			level.aMapPositions[level.aMapPositions.size] = (1346.4, -1424.12, 118.125);
			level.aMapPositions[level.aMapPositions.size] = (2011.56, -1104.9, 146.076);
			level.aMapPositions[level.aMapPositions.size] = (2013.55, -2405.94, 214.125);
			level.aMapPositions[level.aMapPositions.size] = (864.948, -1811.64, 154.125);
			level.aMapPositions[level.aMapPositions.size] = (197.807, -1378.13, 38.125);
			level.aMapPositions[level.aMapPositions.size] = (397.417, -766.782, 28.0845);
			level.aMapPositions[level.aMapPositions.size] = (800.626, -376.283, 30.125);
			level.aMapPositions[level.aMapPositions.size] = (-189.03, -453.141, 28.125);
			level.aMapPositions[level.aMapPositions.size] = (1484.37, -650.508, 38.7282);
			level.aMapPositions[level.aMapPositions.size] = (39.7372, -629.227, 26.125);
			level.aMapPositions[level.aMapPositions.size] = (878.872, -1058.27, 27.7672);
			level.aMapPositions[level.aMapPositions.size] = (877.656, -2660.06, 212.125);
			level.aMapPositions[level.aMapPositions.size] = (741.93, -1605.52, 42.125);
			level.aMapPositions[level.aMapPositions.size] = (716.586, -2943.13, 204.125);
			level.aMapPositions[level.aMapPositions.size] = (81.5806, -2855.99, 152.75);
			level.aMapPositions[level.aMapPositions.size] = (-310.997, -2933.07, 122.917);
			level.aMapPositions[level.aMapPositions.size] = (-563.261, -2634.41, 111.667);
			level.aMapPositions[level.aMapPositions.size] = (525.286, -1081.3, 182.205);
			level.aMapPositions[level.aMapPositions.size] = (1094.44, -3072.61, 202.592);
			level.aMapPositions[level.aMapPositions.size] = (656.37, -1288.55, 213.125);
			level.aMapPositions[level.aMapPositions.size] = (1492.54, -3113.79, 202.222);
			level.aMapPositions[level.aMapPositions.size] = (1824.77, -3271.48, 202.125);
			level.aMapPositions[level.aMapPositions.size] = (2244.32, -2136.08, 350.125);
			level.aMapPositions[level.aMapPositions.size] = (1689.81, -2599.82, 350.125);
			level.aMapPositions[level.aMapPositions.size] = (317.592, -1510.11, 174.125);
			level.aMapPositions[level.aMapPositions.size] = (2451.38, -2967.32, 214.125);
			level.aMapPositions[level.aMapPositions.size] = (2869.45, -2645.04, 202.125);
			level.aMapPositions[level.aMapPositions.size] = (-590.718, -1771.54, 154.125);
			level.aMapPositions[level.aMapPositions.size] = (2591.22, -2313.13, 203.074);
			level.aMapPositions[level.aMapPositions.size] = (-252.03, -1747.05, 174.125);
			level.aMapPositions[level.aMapPositions.size] = (2396.85, -1581.46, 174.282);
			level.aMapPositions[level.aMapPositions.size] = (-374.088, -1398.44, 193.125);
			level.aMapPositions[level.aMapPositions.size] = (2455.25, -1248.93, 188.125);
			level.aMapPositions[level.aMapPositions.size] = (-358.661, -1428.56, 38.125);
			level.aMapPositions[level.aMapPositions.size] = (2633.93, -747.017, 122.528);
			level.aMapPositions[level.aMapPositions.size] = (-888.489, -1687.01, 22.6823);
			level.aMapPositions[level.aMapPositions.size] = (1846.09, -551.392, 182.125);
			level.aMapPositions[level.aMapPositions.size] = (-660.873, -1040.66, 27.2711);
			level.aMapPositions[level.aMapPositions.size] = (1918.73, -542.287, 46.125);
			level.aMapPositions[level.aMapPositions.size] = (-433.414, -1144.96, 35.125);
			level.aMapPositions[level.aMapPositions.size] = (1737.99, -614.14, 46.125);
			level.aMapPositions[level.aMapPositions.size] = (1427.76, -120.197, -113.997);
			level.aMapPositions[level.aMapPositions.size] = (652.218, 57.2234, -108.563);
			level.aMapPositions[level.aMapPositions.size] = (389.726, 881.448, 29.781);
			level.aMapPositions[level.aMapPositions.size] = (31.224, -253.173, -113.994);
			level.aMapPositions[level.aMapPositions.size] = (817.047, 1535.27, 186.125);
			level.aMapPositions[level.aMapPositions.size] = (500.426, 1646.89, 186.125);
			level.aMapPositions[level.aMapPositions.size] = (-623.924, -651.453, -100.467);
			level.aMapPositions[level.aMapPositions.size] = (955.365, 2257.17, 103.695);
			level.aMapPositions[level.aMapPositions.size] = (-1015.9, -1460.53, -113.905);
			level.aMapPositions[level.aMapPositions.size] = (1791.17, 2374.84, 68.2482);
			level.aMapPositions[level.aMapPositions.size] = (1176.94, 2670.55, 76.125);
			level.aMapPositions[level.aMapPositions.size] = (1199.49, 3043.17, 74.125);
			level.aMapPositions[level.aMapPositions.size] = (234.048, 2246.63, 173.309);
			level.aMapPositions[level.aMapPositions.size] = (-335.27, 1974.48, 197.839);
			level.aMapPositions[level.aMapPositions.size] = (-793.688, 959.433, 26.125);
			level.aMapPositions[level.aMapPositions.size] = (-1386.06, 579.609, 30.125);
			level.aMapPositions[level.aMapPositions.size] = (-1670.5, 273.847, 30.125);
			level.aMapPositions[level.aMapPositions.size] = (159.865, 211.936, 36.125);
			level.aMapPositions[level.aMapPositions.size] = (-608.449, -91.8003, 58.125);
			level.aMapPositions[level.aMapPositions.size] = (-523.906, -131.765, 194.125);
			level.aMapPositions[level.aMapPositions.size] = (-1716.1, 140.424, 25.7594);
			level.aMapPositions[level.aMapPositions.size] = (-963.953, 2.77153, 58.125);
			level.aMapPositions[level.aMapPositions.size] = (-1667.33, 434.135, 24.7523);
			level.aMapPositions[level.aMapPositions.size] = (-1935.39, 269.447, 42.1948);
			level.aMapPositions[level.aMapPositions.size] = (-1500.28, 471.571, 190.125);
			level.aMapPositions[level.aMapPositions.size] = (-2192.44, -450.835, 88.5939);
			level.aMapPositions[level.aMapPositions.size] = (-1405.69, 231.452, 209.125);
			level.aMapPositions[level.aMapPositions.size] = (-1384.57, -1364.57, 36.5302);
			level.aMapPositions[level.aMapPositions.size] = (-1471.23, 903.396, 59.4227);
			level.aMapPositions[level.aMapPositions.size] = (-1141.23, 1242.15, 49.1388);
			level.aMapPositions[level.aMapPositions.size] = (-285.585, 905.404, 40.125);
			level.aMapPositions[level.aMapPositions.size] = (-360.402, 1047.92, 40.125);

			//Drops
			level.aDropPositions[level.aDropPositions.size] = (1462.67, -2328.28, 232.131);
			level.aDropPositions[level.aDropPositions.size] = (1727.5, -1365.48, 136.667);
			level.aDropPositions[level.aDropPositions.size] = (1127.75, -147.103, -113.875);
			level.aDropPositions[level.aDropPositions.size] = (1244.3, 427.361, 132.374);
			level.aDropPositions[level.aDropPositions.size] = (-1432.95, -229.132, 150.919);
			level.aDropPositions[level.aDropPositions.size] = (-485.597, 501.491, 31.8294);
			level.aDropPositions[level.aDropPositions.size] = (-794.296, -602.421, 26.125);
			level.aDropPositions[level.aDropPositions.size] = (38.4571, -898.49, 23.9892);
			level.aDropPositions[level.aDropPositions.size] = (427.349, -37.0608, 26.125);
		break;
		case "mp_derail":
			level.aMapPositions[level.aMapPositions.size] = (-347.234, 1957.5, 127.75);
			level.aMapPositions[level.aMapPositions.size] = (283.541, 2605.31, 186.125);
			level.aMapPositions[level.aMapPositions.size] = (286.926, 3207.88, 242.125);
			level.aMapPositions[level.aMapPositions.size] = (458.644, 3290.43, 173.125);
			level.aMapPositions[level.aMapPositions.size] = (785.913, 3593.07, 145.316);
			level.aMapPositions[level.aMapPositions.size] = (846.691, 2753.61, 186.125);
			level.aMapPositions[level.aMapPositions.size] = (827.114, 1713.83, 128.045);
			level.aMapPositions[level.aMapPositions.size] = (843.834, 1554.69, 122.622);
			level.aMapPositions[level.aMapPositions.size] = (1003.06, 1633.76, 120.606);
			level.aMapPositions[level.aMapPositions.size] = (-457.563, -744.63, -1.44833);
			level.aMapPositions[level.aMapPositions.size] = (1193.14, 126.987, 143.69);
			level.aMapPositions[level.aMapPositions.size] = (752.407, 21.9222, 100.531);
			level.aMapPositions[level.aMapPositions.size] = (362.476, 583.67, 119.435);
			level.aMapPositions[level.aMapPositions.size] = (1.1458, 675.163, 116.125);
			level.aMapPositions[level.aMapPositions.size] = (-169.491, 712.924, 308.125);
			level.aMapPositions[level.aMapPositions.size] = (257.686, 1178.22, 116.125);
			level.aMapPositions[level.aMapPositions.size] = (373.73, 2653.62, 330.125);
			level.aMapPositions[level.aMapPositions.size] = (797.037, 2639.16, 330.125);
			level.aMapPositions[level.aMapPositions.size] = (-23.6497, 2090.77, 252.313);
			level.aMapPositions[level.aMapPositions.size] = (-506.639, 3281.84, 148.125);
			level.aMapPositions[level.aMapPositions.size] = (-438.247, 2080.71, 148.125);
			level.aMapPositions[level.aMapPositions.size] = (-1305.68, 2711.22, 111.218);
			level.aMapPositions[level.aMapPositions.size] = (-2502.9, 2462.32, 99.4811);
			level.aMapPositions[level.aMapPositions.size] = (-2226.29, 1829.94, 91.4491);
			level.aMapPositions[level.aMapPositions.size] = (-883.018, 1284.31, 27.125);
			level.aMapPositions[level.aMapPositions.size] = (-858.14, 305.775, -5.875);
			level.aMapPositions[level.aMapPositions.size] = (-1711.12, 32.4137, -21.1615);
			level.aMapPositions[level.aMapPositions.size] = (-1952.03, -765.827, 10.394);
			level.aMapPositions[level.aMapPositions.size] = (-2374.99, -880.24, 19.8523);
			level.aMapPositions[level.aMapPositions.size] = (-2269.37, -1230.71, 43.125);
			level.aMapPositions[level.aMapPositions.size] = (-2274.41, -1465.95, 43.125);
			level.aMapPositions[level.aMapPositions.size] = (-728.534, -2169.03, 320.125);
			level.aMapPositions[level.aMapPositions.size] = (76.4941, -2613.9, 339.125);
			level.aMapPositions[level.aMapPositions.size] = (337.481, -1160.02, 180.948);
			level.aMapPositions[level.aMapPositions.size] = (1102.98, -882.817, 110.137);
			level.aMapPositions[level.aMapPositions.size] = (1566.9, 2504.62, 129.592);
			level.aMapPositions[level.aMapPositions.size] = (1332.51, -1843.14, 63.8722);
			level.aMapPositions[level.aMapPositions.size] = (502.86, 1956.72, 142.516);
			level.aMapPositions[level.aMapPositions.size] = (-45.1933, 1868.11, 113.407);
			level.aMapPositions[level.aMapPositions.size] = (-619.353, -1242.2, 193.125);
			level.aMapPositions[level.aMapPositions.size] = (-1250.43, -1220.22, 102.537);
			level.aMapPositions[level.aMapPositions.size] = (-1204.58, 895.982, 35.4852);
			level.aMapPositions[level.aMapPositions.size] = (-946.814, -2113.55, 140.125);
			level.aMapPositions[level.aMapPositions.size] = (942.189, 1988.12, 186.125);
			level.aMapPositions[level.aMapPositions.size] = (-962.616, -1833.96, 141.885);
			level.aMapPositions[level.aMapPositions.size] = (931.632, 3200.36, 186.125);
			level.aMapPositions[level.aMapPositions.size] = (-1499.27, -2016.29, 111.526);
			level.aMapPositions[level.aMapPositions.size] = (-2064.94, -2217.31, 160.59);
			level.aMapPositions[level.aMapPositions.size] = (-1320.56, -3201.85, 116.436);
			level.aMapPositions[level.aMapPositions.size] = (-2433.36, 791.643, 41.717);
			level.aMapPositions[level.aMapPositions.size] = (-17.4119, -3024.47, 97.6485);
			level.aMapPositions[level.aMapPositions.size] = (1054.83, -2409.93, 114.261);
			level.aMapPositions[level.aMapPositions.size] = (848.815, -2425.73, 186.125);
			level.aMapPositions[level.aMapPositions.size] = (-406.5, -3075.51, 137.775);
			level.aMapPositions[level.aMapPositions.size] = (1970.83, -2464.63, 48.3838);
			level.aMapPositions[level.aMapPositions.size] = (2541.62, -3039.87, 190.104);
			level.aMapPositions[level.aMapPositions.size] = (2923.35, -2074.69, 69.3512);
			level.aMapPositions[level.aMapPositions.size] = (819.761, -393.793, 288.801);
			level.aMapPositions[level.aMapPositions.size] = (3260.78, -1291.68, 185.941);
			level.aMapPositions[level.aMapPositions.size] = (723.058, 1067.75, 151.401);
			level.aMapPositions[level.aMapPositions.size] = (2690.19, -1054.33, 61.9985);
			level.aMapPositions[level.aMapPositions.size] = (2076.09, -530.889, 94.7699);
			level.aMapPositions[level.aMapPositions.size] = (3422.44, -181.606, 108.975);
			level.aMapPositions[level.aMapPositions.size] = (3229.1, 811.879, 165.956);
			level.aMapPositions[level.aMapPositions.size] = (772.487, -1070.4, 176.391);
			level.aMapPositions[level.aMapPositions.size] = (1185.41, 1417.94, 157.233);
			level.aMapPositions[level.aMapPositions.size] = (1444.42, 531.908, 99.6082);
			level.aMapPositions[level.aMapPositions.size] = (2348.47, 778.636, 95.3108);
			level.aMapPositions[level.aMapPositions.size] = (-900.895, -779.32, -15.7479);
			level.aMapPositions[level.aMapPositions.size] = (-324.144, 2118.93, 130.125);
			level.aMapPositions[level.aMapPositions.size] = (-1105.54, 3018.87, 148.125);
			level.aMapPositions[level.aMapPositions.size] = (-31.6135, 1273.11, 122.665);
			level.aMapPositions[level.aMapPositions.size] = (136.302, 1427.37, 308.125);
			level.aMapPositions[level.aMapPositions.size] = (2763.28, 1183.42, 138.125);
			level.aMapPositions[level.aMapPositions.size] = (145.181, 1217.23, 308.125);
			level.aMapPositions[level.aMapPositions.size] = (341.266, 778.044, 308.125);
			level.aMapPositions[level.aMapPositions.size] = (87.4079, 463.996, 308.125);
			level.aMapPositions[level.aMapPositions.size] = (40.3741, 823.04, 116.125);
			level.aMapPositions[level.aMapPositions.size] = (2753.84, 2577.39, 138.282);
			level.aMapPositions[level.aMapPositions.size] = (29.8614, -61.6449, -5.89736);
			level.aMapPositions[level.aMapPositions.size] = (694.005, -238.377, -5.88511);
			level.aMapPositions[level.aMapPositions.size] = (3239.07, 3400.1, -5.875);
			level.aMapPositions[level.aMapPositions.size] = (1138.89, -151.562, -5.92307);
			level.aMapPositions[level.aMapPositions.size] = (2383.94, 3782.49, 123.581);
			level.aMapPositions[level.aMapPositions.size] = (816.439, 356.686, 157.994);
			level.aMapPositions[level.aMapPositions.size] = (2217.63, 3590.51, 211.063);
			level.aMapPositions[level.aMapPositions.size] = (2119.63, 1100.11, 138.085);
			level.aMapPositions[level.aMapPositions.size] = (1416.95, 4426.55, 216.081);
			level.aMapPositions[level.aMapPositions.size] = (1560.65, 1273.18, 140.625);
			level.aMapPositions[level.aMapPositions.size] = (1779.76, 2485.39, 143.967);
			level.aMapPositions[level.aMapPositions.size] = (1640.29, 1769.31, 128.156);
			level.aMapPositions[level.aMapPositions.size] = (2115.21, 3300.43, 424.125);
			level.aMapPositions[level.aMapPositions.size] = (1942.89, 1387.16, 143.363);
			level.aMapPositions[level.aMapPositions.size] = (1769.76, 3354.14, 434.258);
			level.aMapPositions[level.aMapPositions.size] = (2742.7, 2217.97, 138.125);
			level.aMapPositions[level.aMapPositions.size] = (1935.03, 2246.35, 288.125);
			level.aMapPositions[level.aMapPositions.size] = (1737.93, 3428.91, 161.899);
			level.aMapPositions[level.aMapPositions.size] = (1667.47, 3938.98, 222.243);
			level.aMapPositions[level.aMapPositions.size] = (939.264, 4144.18, 164.939);
			level.aMapPositions[level.aMapPositions.size] = (468.464, 4046.41, 124.809);
			level.aMapPositions[level.aMapPositions.size] = (1921.1, 3009.34, 288.125);
			level.aMapPositions[level.aMapPositions.size] = (663.973, 4414.03, 135.028);
			level.aMapPositions[level.aMapPositions.size] = (2454.95, 2867, 288.125);
			level.aMapPositions[level.aMapPositions.size] = (334.346, 3537.62, 186.125);
			level.aMapPositions[level.aMapPositions.size] = (2271.01, 3379.64, 288.125);
			level.aMapPositions[level.aMapPositions.size] = (1745.7, 3321.18, 288.125);
			level.aMapPositions[level.aMapPositions.size] = (-322.605, 3660.97, 151.917);
			level.aMapPositions[level.aMapPositions.size] = (2165.83, 3283.8, 152.125);
			level.aMapPositions[level.aMapPositions.size] = (-673.738, 3590.14, 141.423);
			level.aMapPositions[level.aMapPositions.size] = (1751.85, 3339.78, 152.125);
			level.aMapPositions[level.aMapPositions.size] = (2144.16, 2945.11, 152.125);
			level.aMapPositions[level.aMapPositions.size] = (1912.71, 2651.82, 152.125);
			level.aMapPositions[level.aMapPositions.size] = (2254.88, 2514.84, 214.125);
			level.aMapPositions[level.aMapPositions.size] = (2593.98, 2587.27, 214.125);
			level.aMapPositions[level.aMapPositions.size] = (2612.63, 2139.86, 152.125);
			level.aMapPositions[level.aMapPositions.size] = (2099.86, 2092.52, 152.125);
			level.aMapPositions[level.aMapPositions.size] = (-1974.89, -1790.85, 68.5093);
			level.aMapPositions[level.aMapPositions.size] = (1887.23, 2119.35, 152.125);
			level.aMapPositions[level.aMapPositions.size] = (853.825, -1719.86, 185.625);
			level.aMapPositions[level.aMapPositions.size] = (601.463, -1798.3, 117.057);
			level.aMapPositions[level.aMapPositions.size] = (13.9937, -1990.83, 125.711);
			level.aMapPositions[level.aMapPositions.size] = (-530.842, -1995.05, 143.666);
			level.aMapPositions[level.aMapPositions.size] = (-1289.11, -2241.29, 139.503);
			level.aMapPositions[level.aMapPositions.size] = (-696.985, -3412.81, 167.72);
			level.aMapPositions[level.aMapPositions.size] = (-416.563, -3669.97, 100.125);
			level.aMapPositions[level.aMapPositions.size] = (85.0329, -3634.92, 100.125);
			level.aMapPositions[level.aMapPositions.size] = (1685.53, -3598.9, 139.125);
			level.aMapPositions[level.aMapPositions.size] = (1014.13, -3689.56, 139.125);
			level.aMapPositions[level.aMapPositions.size] = (639.057, -3686.67, 125.846);
			level.aMapPositions[level.aMapPositions.size] = (580.237, -2472.24, 125.288);
			level.aMapPositions[level.aMapPositions.size] = (-848.992, -2431.07, 129.26);
			level.aMapPositions[level.aMapPositions.size] = (-649.315, -2304.22, 140.125);
			level.aMapPositions[level.aMapPositions.size] = (-387.083, -2128.07, 128.125);

			//Drops
			level.aDropPositions[level.aDropPositions.size] = (809.488, -359.146, 289.542);
			level.aDropPositions[level.aDropPositions.size] = (758.915, 731.326, 133.625);
			level.aDropPositions[level.aDropPositions.size] = (2167.41, 158.182, 16.3315);
			level.aDropPositions[level.aDropPositions.size] = (1298.79, 25.349, 140.054);
			level.aDropPositions[level.aDropPositions.size] = (-844.511, 227.53, 9.13808);
			level.aDropPositions[level.aDropPositions.size] = (1340.08, -2638.99, 95.854);
			level.aDropPositions[level.aDropPositions.size] = (9.86819, 3050.31, 131.616);
			level.aDropPositions[level.aDropPositions.size] = (2360.22, 1653.38, 138.121);
			level.aDropPositions[level.aDropPositions.size] = (777.83, 2492.26, 378.625);
			level.aDropPositions[level.aDropPositions.size] = (1160.49, 1374.15, 177.799);
			level.aDropPositions[level.aDropPositions.size] = (116.674, -666.384, 55.314);
			level.aDropPositions[level.aDropPositions.size] = (-404.847, -3056.84, 138.683);
		break;
		case "mp_fuel2":
			level.aMapPositions[level.aMapPositions.size] = (4057.73, -480.969, -151.517);
			level.aMapPositions[level.aMapPositions.size] = (-1061.26, 508.413, -13.875);
			level.aMapPositions[level.aMapPositions.size] = (-2185.13, 1600.59, -127.872);
			level.aMapPositions[level.aMapPositions.size] = (567.427, 1228.23, 12.6554);
			level.aMapPositions[level.aMapPositions.size] = (1358.01, 476.859, -27.875);
			level.aMapPositions[level.aMapPositions.size] = (1351.77, -108.184, 60.125);
			level.aMapPositions[level.aMapPositions.size] = (375.816, -2096.2, -245.933);
			level.aMapPositions[level.aMapPositions.size] = (-261.259, -1537.58, -148.305);
			level.aMapPositions[level.aMapPositions.size] = (-16.0307, -1089.31, 10.125);
			level.aMapPositions[level.aMapPositions.size] = (427.459, 560.838, 10.2951);
			level.aMapPositions[level.aMapPositions.size] = (542.296, -1229.58, 10.125);
			level.aMapPositions[level.aMapPositions.size] = (569.444, -912.362, 10.125);
			level.aMapPositions[level.aMapPositions.size] = (-296.265, -1175.36, 16.125);
			level.aMapPositions[level.aMapPositions.size] = (287.844, -272.814, 12.125);
			level.aMapPositions[level.aMapPositions.size] = (-286.433, 349.452, 9.86109);
			level.aMapPositions[level.aMapPositions.size] = (427.331, 175.198, 10.125);
			level.aMapPositions[level.aMapPositions.size] = (-685.223, -114.586, 14.0195);
			level.aMapPositions[level.aMapPositions.size] = (-459.55, -386.31, 14.125);
			level.aMapPositions[level.aMapPositions.size] = (-1116.65, -655.845, -21.875);
			level.aMapPositions[level.aMapPositions.size] = (-822.936, -379.475, 158.125);
			level.aMapPositions[level.aMapPositions.size] = (-677.174, -332.593, 158.125);
			level.aMapPositions[level.aMapPositions.size] = (-1337.45, 28.4097, 13.4564);
			level.aMapPositions[level.aMapPositions.size] = (-723.646, 219.725, 12.7463);
			level.aMapPositions[level.aMapPositions.size] = (-507.206, 510.931, -1.42395);
			level.aMapPositions[level.aMapPositions.size] = (103.185, -326.445, 10.125);
			level.aMapPositions[level.aMapPositions.size] = (27.9734, -1876.92, 66.125);
			level.aMapPositions[level.aMapPositions.size] = (870.113, -1615.81, 66.125);
			level.aMapPositions[level.aMapPositions.size] = (825.907, -2243.11, -69.875);
			level.aMapPositions[level.aMapPositions.size] = (351.108, -2116, -245.875);
			level.aMapPositions[level.aMapPositions.size] = (-6.18676, -1866.19, -229.875);
			level.aMapPositions[level.aMapPositions.size] = (486.98, -1744.59, -216.353);
			level.aMapPositions[level.aMapPositions.size] = (683.248, -1365.71, -245.875);
			level.aMapPositions[level.aMapPositions.size] = (208.986, -1409.39, -245.875);
			level.aMapPositions[level.aMapPositions.size] = (1366.93, -1750.31, -245.875);
			level.aMapPositions[level.aMapPositions.size] = (1534.94, -957.472, -105.489);
			level.aMapPositions[level.aMapPositions.size] = (328.505, -165.626, 168.717);
			level.aMapPositions[level.aMapPositions.size] = (982.777, -354.933, 12.125);
			level.aMapPositions[level.aMapPositions.size] = (1355.9, -340.925, 60.125);
			level.aMapPositions[level.aMapPositions.size] = (1267.14, -503.258, 49.7054);
			level.aMapPositions[level.aMapPositions.size] = (1877.84, -518.719, -60.6269);
			level.aMapPositions[level.aMapPositions.size] = (1616.9, -117.671, 27.9047);
			level.aMapPositions[level.aMapPositions.size] = (1062.13, 1460.45, -181.835);
			level.aMapPositions[level.aMapPositions.size] = (1517.97, 409.917, 66.4805);
			level.aMapPositions[level.aMapPositions.size] = (958.981, 851.486, 10.125);
			level.aMapPositions[level.aMapPositions.size] = (3415.52, 670.635, -149.875);
			level.aMapPositions[level.aMapPositions.size] = (1036.4, 422.415, 12.125);
			level.aMapPositions[level.aMapPositions.size] = (2235.74, -1857.65, -165.993);
			level.aMapPositions[level.aMapPositions.size] = (1908.14, -2187.99, -161.379);
			level.aMapPositions[level.aMapPositions.size] = (-262.188, 1069.07, 28.125);
			level.aMapPositions[level.aMapPositions.size] = (-116.078, 1082.48, 28.125);
			level.aMapPositions[level.aMapPositions.size] = (63.8537, -2687.88, -245.875);
			level.aMapPositions[level.aMapPositions.size] = (96.0215, 1444.4, -59.875);
			level.aMapPositions[level.aMapPositions.size] = (-863.169, -497.653, 0.177151);
			level.aMapPositions[level.aMapPositions.size] = (809.038, 1106.68, -45.6785);
			level.aMapPositions[level.aMapPositions.size] = (-508.014, -944.96, 0.664902);
			level.aMapPositions[level.aMapPositions.size] = (2107.88, 650.835, -154.2);
			level.aMapPositions[level.aMapPositions.size] = (-1068.72, 182.195, 158.125);
			level.aMapPositions[level.aMapPositions.size] = (-476.682, 34.1918, 158.125);
			level.aMapPositions[level.aMapPositions.size] = (3704.27, -366.546, -139.875);
			level.aMapPositions[level.aMapPositions.size] = (4040.81, -197.552, -139.875);
			level.aMapPositions[level.aMapPositions.size] = (-1051.63, 30.5232, 158.125);
			level.aMapPositions[level.aMapPositions.size] = (3044.96, 1458.72, -171.307);
			level.aMapPositions[level.aMapPositions.size] = (1529.99, 2021.45, -150.875);
			level.aMapPositions[level.aMapPositions.size] = (240.288, 1114.45, 10.125);
			level.aMapPositions[level.aMapPositions.size] = (591.204, 545.429, 12.125);
			level.aMapPositions[level.aMapPositions.size] = (2296.19, 2572.61, -160.505);
			level.aMapPositions[level.aMapPositions.size] = (1597.6, 2889.1, -178.43);
			level.aMapPositions[level.aMapPositions.size] = (1093.71, 2744.36, -176.177);
			level.aMapPositions[level.aMapPositions.size] = (1103.61, -230.595, 60.125);
			level.aMapPositions[level.aMapPositions.size] = (926.959, -677.017, 260.125);
			level.aMapPositions[level.aMapPositions.size] = (704.16, 2026.75, -133.567);
			level.aMapPositions[level.aMapPositions.size] = (535.064, -229.079, 260.125);
			level.aMapPositions[level.aMapPositions.size] = (530.778, 237.043, 260.125);
			level.aMapPositions[level.aMapPositions.size] = (341.105, 1829.28, -181.196);
			level.aMapPositions[level.aMapPositions.size] = (1113.02, 543.467, 260.125);
			level.aMapPositions[level.aMapPositions.size] = (-345.494, 2056.52, -134.104);
			level.aMapPositions[level.aMapPositions.size] = (2142.19, -23.0612, -169.56);
			level.aMapPositions[level.aMapPositions.size] = (-633.864, 1046.38, -43.9976);
			level.aMapPositions[level.aMapPositions.size] = (-1085.17, 1312.01, -126.989);
			level.aMapPositions[level.aMapPositions.size] = (-1260.2, 1705.89, -93.875);
			level.aMapPositions[level.aMapPositions.size] = (1311.6, -200.752, -219.875);
			level.aMapPositions[level.aMapPositions.size] = (1458.29, 443.013, -147.875);
			level.aMapPositions[level.aMapPositions.size] = (-408.953, 2180.41, -125.875);
			level.aMapPositions[level.aMapPositions.size] = (15.3523, 2186.69, -125.875);
			level.aMapPositions[level.aMapPositions.size] = (137.246, 2243.88, -125.875);
			level.aMapPositions[level.aMapPositions.size] = (756.901, 2181.27, -125.875);
			level.aMapPositions[level.aMapPositions.size] = (538.774, 98.2788, 12.125);
			level.aMapPositions[level.aMapPositions.size] = (733.101, 2928.22, -125.875);
			level.aMapPositions[level.aMapPositions.size] = (436.548, 8.01852, 12.125);
			level.aMapPositions[level.aMapPositions.size] = (-418.342, 2954.81, -93.875);
			level.aMapPositions[level.aMapPositions.size] = (612.648, -734.692, 12.125);
			level.aMapPositions[level.aMapPositions.size] = (-681.199, 2315.51, 38.125);
			level.aMapPositions[level.aMapPositions.size] = (-546.371, 2638.5, -129.875);
			level.aMapPositions[level.aMapPositions.size] = (-538.244, 2138.64, -129.875);
			level.aMapPositions[level.aMapPositions.size] = (1155.35, -1082.39, 10.125);
			level.aMapPositions[level.aMapPositions.size] = (-880.523, 2932.94, -136.396);
			level.aMapPositions[level.aMapPositions.size] = (-1231.33, 2594.64, -132.359);
			level.aMapPositions[level.aMapPositions.size] = (-127.034, -1095.36, 16.125);
			level.aMapPositions[level.aMapPositions.size] = (-967.896, 2143.93, -133.875);
			level.aMapPositions[level.aMapPositions.size] = (53.0929, -1320.8, -111.875);
			level.aMapPositions[level.aMapPositions.size] = (-1296.91, 1866.3, -133.637);
			level.aMapPositions[level.aMapPositions.size] = (-549.256, -1099.32, -51.3658);
			level.aMapPositions[level.aMapPositions.size] = (645.302, -1905.13, 66.125);
			level.aMapPositions[level.aMapPositions.size] = (-1633.98, 980.407, 58.125);
			level.aMapPositions[level.aMapPositions.size] = (-1235.01, 1322.24, 58.125);
			level.aMapPositions[level.aMapPositions.size] = (-1269.97, 749.467, 58.125);
			level.aMapPositions[level.aMapPositions.size] = (843.962, -2010.53, -69.875);
			level.aMapPositions[level.aMapPositions.size] = (-1209.7, 789.034, -93.875);
			level.aMapPositions[level.aMapPositions.size] = (-1451.97, 1093.99, -93.875);
			level.aMapPositions[level.aMapPositions.size] = (810.517, -1618.74, -69.875);
			level.aMapPositions[level.aMapPositions.size] = (-1476.03, 1310.81, -93.875);
			level.aMapPositions[level.aMapPositions.size] = (6.86534, -1648.59, -229.875);
			level.aMapPositions[level.aMapPositions.size] = (-1834.17, 2221.27, -133.875);
			level.aMapPositions[level.aMapPositions.size] = (-1622.38, 955.251, -93.875);
			level.aMapPositions[level.aMapPositions.size] = (-1797.64, 501.988, -13.875);
			level.aMapPositions[level.aMapPositions.size] = (688.061, -2148.38, -229.875);
			level.aMapPositions[level.aMapPositions.size] = (-1329.1, -379.187, 11.8226);
			level.aMapPositions[level.aMapPositions.size] = (-1892.55, -375.544, 15.7137);
			level.aMapPositions[level.aMapPositions.size] = (-1708.46, -671.159, -23.3039);
			level.aMapPositions[level.aMapPositions.size] = (-1213.98, -1190.24, -36.6404);
			level.aMapPositions[level.aMapPositions.size] = (688.1, -2516.53, -237.875);
			level.aMapPositions[level.aMapPositions.size] = (1534.59, -2824.21, -213.875);
			level.aMapPositions[level.aMapPositions.size] = (-1194.46, 236.366, 14.2988);
			level.aMapPositions[level.aMapPositions.size] = (-1940.71, 375.455, 16.868);
			level.aMapPositions[level.aMapPositions.size] = (1041.04, -1339.69, -245.875);
			level.aMapPositions[level.aMapPositions.size] = (-1710.03, -1576.1, -98.8388);
			level.aMapPositions[level.aMapPositions.size] = (-1295.55, -1718.89, -108.598);
			level.aMapPositions[level.aMapPositions.size] = (-254.256, -2747.73, -242.517);
			level.aMapPositions[level.aMapPositions.size] = (-459.446, -3063.37, -248.503);
			level.aMapPositions[level.aMapPositions.size] = (2834.61, -1565.38, -157.467);
			level.aMapPositions[level.aMapPositions.size] = (3385.32, -244.296, -158.978);
			level.aMapPositions[level.aMapPositions.size] = (-835.738, -2157.89, -233.875);
			level.aMapPositions[level.aMapPositions.size] = (-1332.2, -2115.71, -225.875);
			level.aMapPositions[level.aMapPositions.size] = (3510.77, -1108.23, -147.674);
			level.aMapPositions[level.aMapPositions.size] = (-1404.22, -2448.09, -241.239);
			level.aMapPositions[level.aMapPositions.size] = (-1327.7, -2718.09, -106.875);
			level.aMapPositions[level.aMapPositions.size] = (204.749, 1338.05, 28.125);

			//Drops
			level.aDropPositions[level.aDropPositions.size] = (2210.72, 1106.69, -150.875);
			level.aDropPositions[level.aDropPositions.size] = (1928.03, -67.116, 24.4965);
			level.aDropPositions[level.aDropPositions.size] = (1072.78, 887.329, 46.125);
			level.aDropPositions[level.aDropPositions.size] = (349.058, 218.382, 10.125);
			level.aDropPositions[level.aDropPositions.size] = (-318.875, 227.978, 8.89074);
			level.aDropPositions[level.aDropPositions.size] = (-60.3526, -1568.56, 118.125);
			level.aDropPositions[level.aDropPositions.size] = (470.605, -1744.09, -216.217);
			level.aDropPositions[level.aDropPositions.size] = (-499.655, -1697.67, -145.934);
			level.aDropPositions[level.aDropPositions.size] = (-734.892, -816.691, -15.4802);
			level.aDropPositions[level.aDropPositions.size] = (-897.908, 1244.55, -131.855);
			level.aDropPositions[level.aDropPositions.size] = (-140.613, 2597.73, -125.875);
			level.aDropPositions[level.aDropPositions.size] = (643.697, 1728.56, -172.01);
			level.aDropPositions[level.aDropPositions.size] = (-11.6615, 806.113, 10.125);
			level.aDropPositions[level.aDropPositions.size] = (-71.3699, -591.895, 10.125);
		break;
		case "mp_crash":
			level.aMapPositions[level.aMapPositions.size] = (3.41808, -901.514, 146.125);
			level.aMapPositions[level.aMapPositions.size] = (-9.28425, -456.682, 146.125);
			level.aMapPositions[level.aMapPositions.size] = (873.992, -828.494, 314.125);
			level.aMapPositions[level.aMapPositions.size] = (1391.11, 463.602, 142.569);
			level.aMapPositions[level.aMapPositions.size] = (222.866, 1163.4, 147.605);
			level.aMapPositions[level.aMapPositions.size] = (9.63544, 880.668, 147.251);
			level.aMapPositions[level.aMapPositions.size] = (698.176, 1042.99, 155.119);
			level.aMapPositions[level.aMapPositions.size] = (829.589, 854.685, 149.127);
			level.aMapPositions[level.aMapPositions.size] = (1122.76, 262.896, 161.311);
			level.aMapPositions[level.aMapPositions.size] = (480.05, 479.301, 157.473);
			level.aMapPositions[level.aMapPositions.size] = (940.055, -336.75, 122.64);
			level.aMapPositions[level.aMapPositions.size] = (1340.98, 144.507, 134.316);
			level.aMapPositions[level.aMapPositions.size] = (1318.26, -298.868, 82.8904);
			level.aMapPositions[level.aMapPositions.size] = (928.867, -806.324, 104.125);
			level.aMapPositions[level.aMapPositions.size] = (495.588, -954.939, 105.923);
			level.aMapPositions[level.aMapPositions.size] = (699.494, 99.7202, 162.125);
			level.aMapPositions[level.aMapPositions.size] = (974.828, -1544.88, 78.125);
			level.aMapPositions[level.aMapPositions.size] = (203.958, -1636.3, 59.3031);
			level.aMapPositions[level.aMapPositions.size] = (216.125, -1264.62, 84.2764);
			level.aMapPositions[level.aMapPositions.size] = (354.388, -1436.29, 108.462);
			level.aMapPositions[level.aMapPositions.size] = (499.571, -556.434, 139.125);
			level.aMapPositions[level.aMapPositions.size] = (705.182, -1658.97, 84.5683);
			level.aMapPositions[level.aMapPositions.size] = (394.656, -894.53, 105.802);
			level.aMapPositions[level.aMapPositions.size] = (130.09, -590.293, 282.125);
			level.aMapPositions[level.aMapPositions.size] = (-303.257, -2088.37, 214.627);
			level.aMapPositions[level.aMapPositions.size] = (382.327, -577.123, 282.125);
			level.aMapPositions[level.aMapPositions.size] = (-400.986, -1127.52, 92.6276);
			level.aMapPositions[level.aMapPositions.size] = (-102.248, -611.876, 126.208);
			level.aMapPositions[level.aMapPositions.size] = (288.659, -781.035, 146.125);
			level.aMapPositions[level.aMapPositions.size] = (-286.394, -512.509, 146.978);
			level.aMapPositions[level.aMapPositions.size] = (-5.87175, -595.052, 146.125);
			level.aMapPositions[level.aMapPositions.size] = (-50.2459, 137.435, 146.125);
			level.aMapPositions[level.aMapPositions.size] = (54.027, 518.972, 146.125);
			level.aMapPositions[level.aMapPositions.size] = (-262.033, 34.7654, 143.697);
			level.aMapPositions[level.aMapPositions.size] = (-201.927, 492.304, 236.799);
			level.aMapPositions[level.aMapPositions.size] = (-565.22, 503.803, 243.536);
			level.aMapPositions[level.aMapPositions.size] = (818.495, 1037.72, 147.535);
			level.aMapPositions[level.aMapPositions.size] = (1237.5, 1350.58, 144.875);
			level.aMapPositions[level.aMapPositions.size] = (-516.095, 1052.34, 267.125);
			level.aMapPositions[level.aMapPositions.size] = (1769.56, 1362.89, 146.125);
			level.aMapPositions[level.aMapPositions.size] = (1778.53, 850.373, 141.933);
			level.aMapPositions[level.aMapPositions.size] = (-89.5098, 1230.68, 224.647);
			level.aMapPositions[level.aMapPositions.size] = (-263.915, 990.196, 250.125);
			level.aMapPositions[level.aMapPositions.size] = (224.155, 1283.7, 146.104);
			level.aMapPositions[level.aMapPositions.size] = (146.768, 1520.86, 136.661);
			level.aMapPositions[level.aMapPositions.size] = (1499.01, 456.165, 590.125);
			level.aMapPositions[level.aMapPositions.size] = (1743.62, 468.127, 590.125);
			level.aMapPositions[level.aMapPositions.size] = (339.416, 1171.34, 147.125);
			level.aMapPositions[level.aMapPositions.size] = (1610.09, 442.996, 318.125);
			level.aMapPositions[level.aMapPositions.size] = (684.672, 1167.76, 283.22);
			level.aMapPositions[level.aMapPositions.size] = (716.703, 1404.65, 147.125);
			level.aMapPositions[level.aMapPositions.size] = (677.258, 1173.95, 147.125);
			level.aMapPositions[level.aMapPositions.size] = (370.196, 1942.19, 138.457);
			level.aMapPositions[level.aMapPositions.size] = (1767.05, 731.069, 150.125);
			level.aMapPositions[level.aMapPositions.size] = (-157.119, 1417.17, 237.322);
			level.aMapPositions[level.aMapPositions.size] = (1712.85, 346.638, 154.681);
			level.aMapPositions[level.aMapPositions.size] = (-845.402, 1241.52, 256.461);
			level.aMapPositions[level.aMapPositions.size] = (1296.54, -6.17152, 162.125);
			level.aMapPositions[level.aMapPositions.size] = (-529.672, 1797.04, 266.125);
			level.aMapPositions[level.aMapPositions.size] = (1771.02, -194.12, 82.3642);
			level.aMapPositions[level.aMapPositions.size] = (-115.093, 1813.02, 236.899);
			level.aMapPositions[level.aMapPositions.size] = (1779.19, -467.227, 78.056);
			level.aMapPositions[level.aMapPositions.size] = (-4.84937, 2246.71, 246.125);
			level.aMapPositions[level.aMapPositions.size] = (1092.4, -1009.23, 77.5343);
			level.aMapPositions[level.aMapPositions.size] = (1658.9, -1076.05, 75.125);
			level.aMapPositions[level.aMapPositions.size] = (1381.91, -1651.64, 76.125);
			level.aMapPositions[level.aMapPositions.size] = (-852.978, 1507.57, 420.064);
			level.aMapPositions[level.aMapPositions.size] = (-576.448, 1807.6, 427.9);
			level.aMapPositions[level.aMapPositions.size] = (-585.36, 1954.97, 401.799);
			level.aMapPositions[level.aMapPositions.size] = (1402.47, -1726.1, 236.125);
			level.aMapPositions[level.aMapPositions.size] = (1638.74, -1960.12, 212.125);
			level.aMapPositions[level.aMapPositions.size] = (-906.412, 1932.45, 400.125);
			level.aMapPositions[level.aMapPositions.size] = (1425.81, -1969.21, 76.125);
			level.aMapPositions[level.aMapPositions.size] = (-899.362, 2081.69, 264.125);
			level.aMapPositions[level.aMapPositions.size] = (-712.066, 2145.1, 264.125);

			//Drops
			level.aDropPositions[level.aDropPositions.size] = (1580.57, 87.3452, 135.038);
			level.aDropPositions[level.aDropPositions.size] = (427.091, -1438.74, 148.172);
			level.aDropPositions[level.aDropPositions.size] = (-408.71, 1380.74, 267.544);
			level.aDropPositions[level.aDropPositions.size] = (180.57, 1056.57, 152.185);
			level.aDropPositions[level.aDropPositions.size] = (1358.37, 1085.02, 178.623);
			level.aDropPositions[level.aDropPositions.size] = (619.784, 528.735, 145.808);
			level.aDropPositions[level.aDropPositions.size] = (241.826, -33.8508, 137.91);
			level.aDropPositions[level.aDropPositions.size] = (913.848, -500.49, 108.205);
		break;
		case "mp_strike":
			level.aMapPositions[level.aMapPositions.size] = (1023.11, -1225.29, 206.125);
			level.aMapPositions[level.aMapPositions.size] = (2107.54, -614.949, 26.125);
			level.aMapPositions[level.aMapPositions.size] = (1091.59, -961.271, 18.125);
			level.aMapPositions[level.aMapPositions.size] = (-1905.51, -192.297, 19.4445);
			level.aMapPositions[level.aMapPositions.size] = (-1947.57, 426.086, 23.2309);
			level.aMapPositions[level.aMapPositions.size] = (-1630.93, 315.028, 21.8008);
			level.aMapPositions[level.aMapPositions.size] = (-946.814, 62.0931, 26.125);
			level.aMapPositions[level.aMapPositions.size] = (113.106, -160.805, 18.125);
			level.aMapPositions[level.aMapPositions.size] = (-1376.2, -450.138, 22.0427);
			level.aMapPositions[level.aMapPositions.size] = (337.033, -501.642, 26.125);
			level.aMapPositions[level.aMapPositions.size] = (-918.1, -610.884, 26.125);
			level.aMapPositions[level.aMapPositions.size] = (347.732, 407.01, 26.125);
			level.aMapPositions[level.aMapPositions.size] = (-1567.87, -2742.54, 220.259);
			level.aMapPositions[level.aMapPositions.size] = (718.18, 927.866, 168.125);
			level.aMapPositions[level.aMapPositions.size] = (-1771.89, 1060.83, 26.0317);
			level.aMapPositions[level.aMapPositions.size] = (-1136.23, 739.357, 26.0472);
			level.aMapPositions[level.aMapPositions.size] = (-254.732, -1578.65, 147.215);
			level.aMapPositions[level.aMapPositions.size] = (894.551, -2115.21, 150.049);
			level.aMapPositions[level.aMapPositions.size] = (562.368, -1219.66, 80.3498);
			level.aMapPositions[level.aMapPositions.size] = (226.868, -1768.67, 118.688);
			level.aMapPositions[level.aMapPositions.size] = (1224.55, 249.579, 26.125);
			level.aMapPositions[level.aMapPositions.size] = (-220.532, -376.399, 34.125);
			level.aMapPositions[level.aMapPositions.size] = (-449.076, -380.542, 34.125);
			level.aMapPositions[level.aMapPositions.size] = (1128.82, 552.299, 26.0088);
			level.aMapPositions[level.aMapPositions.size] = (1089.98, 788.466, 32.125);
			level.aMapPositions[level.aMapPositions.size] = (1877.07, 1613.83, 26.125);
			level.aMapPositions[level.aMapPositions.size] = (1264.84, -527.483, 34.125);
			level.aMapPositions[level.aMapPositions.size] = (2742.18, 2602.21, 27.6921);
			level.aMapPositions[level.aMapPositions.size] = (892.194, -629.326, 34.125);
			level.aMapPositions[level.aMapPositions.size] = (808.449, -1104.22, 30.125);
			level.aMapPositions[level.aMapPositions.size] = (1456.19, 925.611, 168.125);
			level.aMapPositions[level.aMapPositions.size] = (431.449, -1082.55, 26.5615);
			level.aMapPositions[level.aMapPositions.size] = (346.539, -1086.14, 27.8809);
			level.aMapPositions[level.aMapPositions.size] = (33.5875, -896.768, 31.5037);
			level.aMapPositions[level.aMapPositions.size] = (66.9692, -1187.38, 82.125);
			level.aMapPositions[level.aMapPositions.size] = (791.995, 1562.8, 76.125);
			level.aMapPositions[level.aMapPositions.size] = (-459.654, -1291.7, 274.125);
			level.aMapPositions[level.aMapPositions.size] = (527.904, 62.3924, 18.125);
			level.aMapPositions[level.aMapPositions.size] = (1058.89, -25.8916, 26.125);
			level.aMapPositions[level.aMapPositions.size] = (-173.972, 521.16, 30.125);
			level.aMapPositions[level.aMapPositions.size] = (-81.5761, -489.118, 34.125);
			level.aMapPositions[level.aMapPositions.size] = (115.649, 349.013, 30.125);
			level.aMapPositions[level.aMapPositions.size] = (152.287, -771.114, 34.125);
			level.aMapPositions[level.aMapPositions.size] = (-297.193, -810.819, 34.125);
			level.aMapPositions[level.aMapPositions.size] = (-1005.04, -93.9205, 18.125);
			level.aMapPositions[level.aMapPositions.size] = (1262.28, 667.377, 32.125);
			level.aMapPositions[level.aMapPositions.size] = (-1108.8, -760.434, 22.125);
			level.aMapPositions[level.aMapPositions.size] = (-788.738, -620.599, 34.125);
			level.aMapPositions[level.aMapPositions.size] = (-954.345, 364.625, 26.125);
			level.aMapPositions[level.aMapPositions.size] = (278.977, -724.314, 26.125);
			level.aMapPositions[level.aMapPositions.size] = (-311.166, 595.145, 26.125);
			level.aMapPositions[level.aMapPositions.size] = (887.795, 155.317, 26.125);
			level.aMapPositions[level.aMapPositions.size] = (92.3569, 890.445, 26.125);
			level.aMapPositions[level.aMapPositions.size] = (-639.312, 1336.71, 34.125);
			level.aMapPositions[level.aMapPositions.size] = (1098.61, -140.685, 34.125);
			level.aMapPositions[level.aMapPositions.size] = (-1255.3, 1560.55, 34.125);
			level.aMapPositions[level.aMapPositions.size] = (987.083, -639.693, 34.125);
			level.aMapPositions[level.aMapPositions.size] = (1345.84, -1397.87, 30.125);
			level.aMapPositions[level.aMapPositions.size] = (-1356.02, -894.438, 17.125);
			level.aMapPositions[level.aMapPositions.size] = (-1731.83, -579.177, 36.125);
			level.aMapPositions[level.aMapPositions.size] = (700.112, -1672.33, 134.094);
			level.aMapPositions[level.aMapPositions.size] = (441.544, -1977.29, 141.336);
			level.aMapPositions[level.aMapPositions.size] = (149.755, -2165.54, 134.011);
			level.aMapPositions[level.aMapPositions.size] = (1855.93, 30.075, 34.125);
			level.aMapPositions[level.aMapPositions.size] = (785.556, -1547.41, 30.125);
			level.aMapPositions[level.aMapPositions.size] = (915.763, -1165.19, 206.125);
			level.aMapPositions[level.aMapPositions.size] = (-717.077, -749.923, 34.125);
			level.aMapPositions[level.aMapPositions.size] = (1302.49, -1560.89, 206.125);
			level.aMapPositions[level.aMapPositions.size] = (1455.7, -1313.72, 54.304);
			level.aMapPositions[level.aMapPositions.size] = (1471.6, -1862.17, 111.877);
			level.aMapPositions[level.aMapPositions.size] = (1943.97, -1487.32, 34.125);
			level.aMapPositions[level.aMapPositions.size] = (2396.73, -1048.67, 25.3517);
			level.aMapPositions[level.aMapPositions.size] = (-1524.92, 523.226, 29.125);
			level.aMapPositions[level.aMapPositions.size] = (1401.65, -482.443, 27.7073);
			level.aMapPositions[level.aMapPositions.size] = (1777.08, -454.377, 34.125);
			level.aMapPositions[level.aMapPositions.size] = (1963.06, 196.725, 26.125);
			level.aMapPositions[level.aMapPositions.size] = (-2409.54, -475.095, 11.2862);
			level.aMapPositions[level.aMapPositions.size] = (-1876.66, -608.359, 36.125);
			level.aMapPositions[level.aMapPositions.size] = (1968.7, 965.185, 26.125);
			level.aMapPositions[level.aMapPositions.size] = (-2153.52, -1178.28, 36.125);
			level.aMapPositions[level.aMapPositions.size] = (-2190.46, -844.263, 36.125);
			level.aMapPositions[level.aMapPositions.size] = (-2195.63, -1417.32, 36.125);
			level.aMapPositions[level.aMapPositions.size] = (-2335.31, -833.735, 36.125);
			level.aMapPositions[level.aMapPositions.size] = (-2437.56, -688.752, 36.125);
			level.aMapPositions[level.aMapPositions.size] = (-2280.15, -92.1632, 32.125);
			level.aMapPositions[level.aMapPositions.size] = (-1113.09, 282.983, 197.125);
			level.aMapPositions[level.aMapPositions.size] = (-1047.75, 365.761, 204.125);
			level.aMapPositions[level.aMapPositions.size] = (-1058.88, 423.955, 29.125);
			level.aMapPositions[level.aMapPositions.size] = (-1748.26, -1274.99, 18.125);
			level.aMapPositions[level.aMapPositions.size] = (-2346.27, 557.88, 23.6282);
			level.aMapPositions[level.aMapPositions.size] = (-2475.67, 1183.97, 25.6641);
			level.aMapPositions[level.aMapPositions.size] = (-1594.52, 1123.39, 90.125);
			level.aMapPositions[level.aMapPositions.size] = (-1424.86, -1514.2, 23.1309);
			level.aMapPositions[level.aMapPositions.size] = (-440.598, -944.637, 24.2014);
			level.aMapPositions[level.aMapPositions.size] = (-1474.84, 659.454, 90.125);
			level.aMapPositions[level.aMapPositions.size] = (-1425.45, 1164.07, 90.125);
			level.aMapPositions[level.aMapPositions.size] = (-1417.48, 1411.84, 34.125);
			level.aMapPositions[level.aMapPositions.size] = (-1042.38, -1733.59, 222.125);
			level.aMapPositions[level.aMapPositions.size] = (-1044, 2066.71, 34.125);
			level.aMapPositions[level.aMapPositions.size] = (-596.985, -1336.32, 122.416);
			level.aMapPositions[level.aMapPositions.size] = (-637.842, 1850.58, 26.125);
			level.aMapPositions[level.aMapPositions.size] = (-216.069, 1821.01, 26.125);
			level.aMapPositions[level.aMapPositions.size] = (-1602.79, -2037.46, 222.125);
			level.aMapPositions[level.aMapPositions.size] = (667.648, 834.41, 19.1481);
			level.aMapPositions[level.aMapPositions.size] = (183.172, 1147.21, 26.125);
			level.aMapPositions[level.aMapPositions.size] = (-861.214, -2704.61, 225.924);
			level.aMapPositions[level.aMapPositions.size] = (-547.462, -1925.02, 228.125);
			level.aMapPositions[level.aMapPositions.size] = (200.786, 1484.03, 38.125);
			level.aMapPositions[level.aMapPositions.size] = (308.779, 1900.62, 26.125);
			level.aMapPositions[level.aMapPositions.size] = (-1356, -2573.87, 226.125);
			level.aMapPositions[level.aMapPositions.size] = (1383.97, 937.799, 32.125);
			level.aMapPositions[level.aMapPositions.size] = (1015.66, 680.16, 168.125);
			level.aMapPositions[level.aMapPositions.size] = (1048.61, 1003.4, 32.125);
			level.aMapPositions[level.aMapPositions.size] = (1144.36, 1093.65, 26.125);
			level.aMapPositions[level.aMapPositions.size] = (1093.24, 1401.45, 25.0902);
			level.aMapPositions[level.aMapPositions.size] = (1843.81, 1086.1, 26.125);
			level.aMapPositions[level.aMapPositions.size] = (1348.16, 1600.78, 34.125);
			level.aMapPositions[level.aMapPositions.size] = (1984.45, 1830.36, 26.1247);
			level.aMapPositions[level.aMapPositions.size] = (1526.01, 2385.91, 26.2111);
			level.aMapPositions[level.aMapPositions.size] = (2146.02, 2040.73, 43.8998);
			level.aMapPositions[level.aMapPositions.size] = (2028.59, 2749.14, 26.1249);
			level.aMapPositions[level.aMapPositions.size] = (3307.21, 2770.53, 41.9482);

			//Drops
			level.aDropPositions[level.aDropPositions.size] = (1504.08, 470.933, 26.0388);
			level.aDropPositions[level.aDropPositions.size] = (1555.92, -882.169, 18.125);
			level.aDropPositions[level.aDropPositions.size] = (-1892.42, 167.362, 22.125);
			level.aDropPositions[level.aDropPositions.size] = (-640, 793.6, 539);
			level.aDropPositions[level.aDropPositions.size] = (528.734, 1074.14, 18.125);
			level.aDropPositions[level.aDropPositions.size] = (311.799, -86.2062, 15.4318);
			level.aDropPositions[level.aDropPositions.size] = (-1154.57, -255.761, 18.125);
			level.aDropPositions[level.aDropPositions.size] = (-849.327, -1479.12, 119.6);
		break;
		case "mp_overgrown":
			level.aMapPositions[level.aMapPositions.size] = (1461.67, -1837.44, -184.81);
			level.aMapPositions[level.aMapPositions.size] = (-4.58576, -1349.46, -181.102);
			level.aMapPositions[level.aMapPositions.size] = (-497.585, -4933, -148.234);
			level.aMapPositions[level.aMapPositions.size] = (369.231, -3895.43, -153.875);
			level.aMapPositions[level.aMapPositions.size] = (-187.094, -4012.82, -153.875);
			level.aMapPositions[level.aMapPositions.size] = (-731.052, -3774.23, 38.125);
			level.aMapPositions[level.aMapPositions.size] = (567.695, -1339.64, -165.878);
			level.aMapPositions[level.aMapPositions.size] = (-297.488, -5347.04, -270.24);
			level.aMapPositions[level.aMapPositions.size] = (892.595, -4606.14, -166.938);
			level.aMapPositions[level.aMapPositions.size] = (1131.59, -4316.15, -109.875);
			level.aMapPositions[level.aMapPositions.size] = (-646.966, -2430.2, -165.875);
			level.aMapPositions[level.aMapPositions.size] = (2114.6, -3767.29, -125.007);
			level.aMapPositions[level.aMapPositions.size] = (-557.437, -3267.53, -111.143);
			level.aMapPositions[level.aMapPositions.size] = (2393.54, -1971.66, -165.875);
			level.aMapPositions[level.aMapPositions.size] = (-607.98, -1748.26, -161.532);
			level.aMapPositions[level.aMapPositions.size] = (2594.27, -1301.51, -149.509);
			level.aMapPositions[level.aMapPositions.size] = (-583.075, -664.985, -173.881);
			level.aMapPositions[level.aMapPositions.size] = (-62.2348, -3957.98, 64.125);
			level.aMapPositions[level.aMapPositions.size] = (2135.37, -1025.98, -192.93);
			level.aMapPositions[level.aMapPositions.size] = (565.071, -3465.86, 26.125);
			level.aMapPositions[level.aMapPositions.size] = (157.598, 513.165, -165.875);
			level.aMapPositions[level.aMapPositions.size] = (934.054, -3801.87, -43.875);
			level.aMapPositions[level.aMapPositions.size] = (1230.23, -846.457, -181.875);
			level.aMapPositions[level.aMapPositions.size] = (250.278, 19.0385, -167.172);
			level.aMapPositions[level.aMapPositions.size] = (-124.743, -2087.26, -197.148);
			level.aMapPositions[level.aMapPositions.size] = (536.705, -1477.93, -151.245);
			level.aMapPositions[level.aMapPositions.size] = (376.34, -1765.48, -149.875);
			level.aMapPositions[level.aMapPositions.size] = (-371.454, 155.736, -165.875);
			level.aMapPositions[level.aMapPositions.size] = (-575.065, -31.1518, -165.875);
			level.aMapPositions[level.aMapPositions.size] = (1192.64, -98.7578, -308.135);
			level.aMapPositions[level.aMapPositions.size] = (476.939, -793.466, -171.544);
			level.aMapPositions[level.aMapPositions.size] = (155.458, -884.164, -173.875);
			level.aMapPositions[level.aMapPositions.size] = (791.073, -1563.4, -321.227);
			level.aMapPositions[level.aMapPositions.size] = (-282.503, -509.461, -173.875);
			level.aMapPositions[level.aMapPositions.size] = (1667.95, -1495.15, -188.09);
			level.aMapPositions[level.aMapPositions.size] = (1473.32, -1710.85, -181.875);
			level.aMapPositions[level.aMapPositions.size] = (-868.886, -1125.19, -159.875);
			level.aMapPositions[level.aMapPositions.size] = (-1381.03, -1570.48, -159.875);
			level.aMapPositions[level.aMapPositions.size] = (-1402.53, -948.007, -160.875);
			level.aMapPositions[level.aMapPositions.size] = (1873.46, -1763.2, -192.011);
			level.aMapPositions[level.aMapPositions.size] = (-1118.65, -2430.44, -177.556);
			level.aMapPositions[level.aMapPositions.size] = (-1488.9, -2440.99, -159.875);
			level.aMapPositions[level.aMapPositions.size] = (-856.208, -2871.55, -169.576);
			level.aMapPositions[level.aMapPositions.size] = (93.4922, -3215.26, -268.473);
			level.aMapPositions[level.aMapPositions.size] = (-876.339, -3281.94, -100.084);
			level.aMapPositions[level.aMapPositions.size] = (-82.9597, -4630.33, -269.875);
			level.aMapPositions[level.aMapPositions.size] = (-1273.43, -3124.7, -139.705);
			level.aMapPositions[level.aMapPositions.size] = (208.596, -5274.41, -300.564);
			level.aMapPositions[level.aMapPositions.size] = (852.015, -2869.01, -162.542);
			level.aMapPositions[level.aMapPositions.size] = (-1598.06, -3634.39, -95.875);
			level.aMapPositions[level.aMapPositions.size] = (615.25, -3290.85, -187.64);
			level.aMapPositions[level.aMapPositions.size] = (-1674.41, -4017.2, -118.279);
			level.aMapPositions[level.aMapPositions.size] = (790.272, -3686.89, -162.109);
			level.aMapPositions[level.aMapPositions.size] = (-2020.87, -4125.32, -105.148);
			level.aMapPositions[level.aMapPositions.size] = (2118.72, -1240.09, -204.199);
			level.aMapPositions[level.aMapPositions.size] = (997.599, -4231.06, -120.976);
			level.aMapPositions[level.aMapPositions.size] = (1356.24, -838.081, -181.875);
			level.aMapPositions[level.aMapPositions.size] = (581.402, -4233.55, -133.254);
			level.aMapPositions[level.aMapPositions.size] = (927.519, -4095.03, -121.938);
			level.aMapPositions[level.aMapPositions.size] = (-827.749, -3567.47, 57.125);
			level.aMapPositions[level.aMapPositions.size] = (-304.894, 69.1184, -164.36);
			level.aMapPositions[level.aMapPositions.size] = (1119.1, -4397.36, -3.875);
			level.aMapPositions[level.aMapPositions.size] = (-1018.4, -3511.65, 38.125);
			level.aMapPositions[level.aMapPositions.size] = (-890.471, -1690.89, -176.022);
			level.aMapPositions[level.aMapPositions.size] = (-1006.34, -3689.56, -97.875);
			level.aMapPositions[level.aMapPositions.size] = (1789.52, -4450.18, -117.486);
			level.aMapPositions[level.aMapPositions.size] = (-844.155, -3370.16, -97.875);
			level.aMapPositions[level.aMapPositions.size] = (-541.541, -3367.82, -69.3625);
			level.aMapPositions[level.aMapPositions.size] = (1087.92, -3657.22, -127.758);
			level.aMapPositions[level.aMapPositions.size] = (1310.13, -1090.44, -337.329);
			level.aMapPositions[level.aMapPositions.size] = (-533.125, -3782.79, -59.4518);
			level.aMapPositions[level.aMapPositions.size] = (1521.59, -3256.2, -144.596);
			level.aMapPositions[level.aMapPositions.size] = (-23.5191, -2248.96, -219.224);
			level.aMapPositions[level.aMapPositions.size] = (-979.944, -3872.19, -112.823);
			level.aMapPositions[level.aMapPositions.size] = (981.994, -2276.87, -149.875);
			level.aMapPositions[level.aMapPositions.size] = (1000.04, -2876.09, -21.875);
			level.aMapPositions[level.aMapPositions.size] = (-202.368, -3946.72, -285.552);
			level.aMapPositions[level.aMapPositions.size] = (-624.749, -4249.67, -120.427);
			level.aMapPositions[level.aMapPositions.size] = (1208.35, -2284.49, -21.875);
			level.aMapPositions[level.aMapPositions.size] = (-1947.46, -4795.74, -141.224);
			level.aMapPositions[level.aMapPositions.size] = (-501.463, -5346.52, -149.875);
			level.aMapPositions[level.aMapPositions.size] = (-1725.67, -3191.07, -126.105);
			level.aMapPositions[level.aMapPositions.size] = (-1894.21, -2823.16, -188.584);
			level.aMapPositions[level.aMapPositions.size] = (-1838.92, -2144.36, -169.875);
			level.aMapPositions[level.aMapPositions.size] = (-1018.18, -5238.07, -164.038);
			level.aMapPositions[level.aMapPositions.size] = (1447.38, -2382.95, -179.806);
			level.aMapPositions[level.aMapPositions.size] = (-940.881, -617.912, -172.997);
			level.aMapPositions[level.aMapPositions.size] = (957.952, -2864.58, -149.875);
			level.aMapPositions[level.aMapPositions.size] = (-912.781, 275.968, -165.875);
			level.aMapPositions[level.aMapPositions.size] = (1329.17, -2391.64, -149.875);
			level.aMapPositions[level.aMapPositions.size] = (-581.929, 435.317, -165.875);
			level.aMapPositions[level.aMapPositions.size] = (-380.79, 784.121, -157.875);
			level.aMapPositions[level.aMapPositions.size] = (638.952, 769.654, -155.538);
			level.aMapPositions[level.aMapPositions.size] = (231.897, -2013.76, -340.613);
			level.aMapPositions[level.aMapPositions.size] = (1447.03, 629.332, -305.47);
			level.aMapPositions[level.aMapPositions.size] = (1696.2, -151.22, -72.8516);
			level.aMapPositions[level.aMapPositions.size] = (2605.9, -605.29, -120.433);
			level.aMapPositions[level.aMapPositions.size] = (-406.013, -2479.18, -169.236);
			level.aMapPositions[level.aMapPositions.size] = (2598.74, -2344.88, -153.255);
			level.aMapPositions[level.aMapPositions.size] = (-782.254, -2305.01, -165.875);
			level.aMapPositions[level.aMapPositions.size] = (2579.47, -3212.24, -165.875);
			level.aMapPositions[level.aMapPositions.size] = (3024.26, -3618.28, -106.522);
			level.aMapPositions[level.aMapPositions.size] = (2431.49, -2457.85, -133.875);
			level.aMapPositions[level.aMapPositions.size] = (2787.93, -2277.58, -133.875);
			level.aMapPositions[level.aMapPositions.size] = (-333.771, -2095.08, 10.125);
			level.aMapPositions[level.aMapPositions.size] = (1681.13, -4462.83, -3.875);
			level.aMapPositions[level.aMapPositions.size] = (2971.12, -2688.05, -130.934);
			level.aMapPositions[level.aMapPositions.size] = (-770.876, -2176.18, 10.125);
			level.aMapPositions[level.aMapPositions.size] = (-511.99, -2164.46, 10.125);
			level.aMapPositions[level.aMapPositions.size] = (1105.58, -4088.47, -3.875);
			level.aMapPositions[level.aMapPositions.size] = (1666.05, -4444.13, -109.875);
			level.aMapPositions[level.aMapPositions.size] = (-556.7, -1869.1, -125.875);
			level.aMapPositions[level.aMapPositions.size] = (627.832, -3590.52, -161.875);
			level.aMapPositions[level.aMapPositions.size] = (-777.623, -2190.56, -125.875);

			//Drops
			level.aDropPositions[level.aDropPositions.size] = (391.1, -2431.92, -310.027);
			level.aDropPositions[level.aDropPositions.size] = (-1390.69, -4196.35, -117.268);
			level.aDropPositions[level.aDropPositions.size] = (-406.989, -1313.39, -180.389);
			level.aDropPositions[level.aDropPositions.size] = (1122.58, -885.946, -181.981);
			level.aDropPositions[level.aDropPositions.size] = (2051.5, -2177.55, -157.875);
			level.aDropPositions[level.aDropPositions.size] = (76.3533, -4693.28, -269.875);
			level.aDropPositions[level.aDropPositions.size] = (-1132.96, -2497.01, -145.308);
		break;
		case "mp_abandon":
			level.aMapPositions[level.aMapPositions.size] = (783.312, -845.595, -125.875);
			level.aMapPositions[level.aMapPositions.size] = (1229.34, -1187.36, -125.875);
			level.aMapPositions[level.aMapPositions.size] = (1048.16, 723.673, 30.125);
			level.aMapPositions[level.aMapPositions.size] = (3264.61, 948.129, -43.6651);
			level.aMapPositions[level.aMapPositions.size] = (2827.91, 889.323, -30.8577);
			level.aMapPositions[level.aMapPositions.size] = (2208.92, 716.881, -53.875);
			level.aMapPositions[level.aMapPositions.size] = (329.497, -1348.74, -47.1504);
			level.aMapPositions[level.aMapPositions.size] = (969.351, -566.239, -53.9725);
			level.aMapPositions[level.aMapPositions.size] = (1520.95, -563.912, -57.875);
			level.aMapPositions[level.aMapPositions.size] = (2194.34, -282.421, -53.875);
			level.aMapPositions[level.aMapPositions.size] = (1954.45, 304.46, -53.875);
			level.aMapPositions[level.aMapPositions.size] = (1173.85, 163.09, -51.875);
			level.aMapPositions[level.aMapPositions.size] = (2666.19, -845.274, 310.531);
			level.aMapPositions[level.aMapPositions.size] = (2253.03, -1376.66, 116.919);
			level.aMapPositions[level.aMapPositions.size] = (451.368, -2.2707, -52.875);
			level.aMapPositions[level.aMapPositions.size] = (2114.97, 171.278, 136.125);
			level.aMapPositions[level.aMapPositions.size] = (3442.6, -1902.7, -40.8673);
			level.aMapPositions[level.aMapPositions.size] = (226.903, 288.169, -53.875);
			level.aMapPositions[level.aMapPositions.size] = (2204.37, 402.607, 138.125);
			level.aMapPositions[level.aMapPositions.size] = (-468.907, 62.6852, -52.875);
			level.aMapPositions[level.aMapPositions.size] = (2569.9, 291.15, 138.125);
			level.aMapPositions[level.aMapPositions.size] = (793.758, -1887.17, -54.2267);
			level.aMapPositions[level.aMapPositions.size] = (2592.68, -248.011, -7.875);
			level.aMapPositions[level.aMapPositions.size] = (402.173, 755.024, -51.875);
			level.aMapPositions[level.aMapPositions.size] = (2319.8, -1498.96, -26.5125);
			level.aMapPositions[level.aMapPositions.size] = (1429.32, -2345.34, -8.18465);
			level.aMapPositions[level.aMapPositions.size] = (2526.95, -2478, -29.8212);
			level.aMapPositions[level.aMapPositions.size] = (1775.72, -2757.74, 64.4049);
			level.aMapPositions[level.aMapPositions.size] = (883.797, -2212.03, -51.1871);
			level.aMapPositions[level.aMapPositions.size] = (-371.47, -808.809, 110.125);
			level.aMapPositions[level.aMapPositions.size] = (3041.89, -1469.84, -3.31024);
			level.aMapPositions[level.aMapPositions.size] = (1372.56, -1696.77, -39.0133);
			level.aMapPositions[level.aMapPositions.size] = (2215.13, -1159, -9.89493);
			level.aMapPositions[level.aMapPositions.size] = (2938.33, -1142.08, -35.9036);
			level.aMapPositions[level.aMapPositions.size] = (-15.3376, -1090.33, 90.125);
			level.aMapPositions[level.aMapPositions.size] = (3010.7, -520.499, -51.6598);
			level.aMapPositions[level.aMapPositions.size] = (2638.47, 5.51099, 58.6716);
			level.aMapPositions[level.aMapPositions.size] = (618.348, -1520.85, -53.875);
			level.aMapPositions[level.aMapPositions.size] = (639.89, -2266.15, -47.875);
			level.aMapPositions[level.aMapPositions.size] = (77.7047, -1898.03, -47.8915);
			level.aMapPositions[level.aMapPositions.size] = (2642.83, 521.453, -41.875);
			level.aMapPositions[level.aMapPositions.size] = (3277.94, 492.436, -43.2698);
			level.aMapPositions[level.aMapPositions.size] = (3494.64, 621.249, -33.9077);
			level.aMapPositions[level.aMapPositions.size] = (2370.14, 1056.85, -52.403);
			level.aMapPositions[level.aMapPositions.size] = (2724.01, 1423.65, -43.6689);
			level.aMapPositions[level.aMapPositions.size] = (1820.9, -1643.06, -38.7155);
			level.aMapPositions[level.aMapPositions.size] = (123.554, -1421.75, -47.8012);
			level.aMapPositions[level.aMapPositions.size] = (2237.52, 1223.58, -53.9232);
			level.aMapPositions[level.aMapPositions.size] = (2245.44, -664.87, -7.875);
			level.aMapPositions[level.aMapPositions.size] = (-390.534, -1188.38, -61.875);
			level.aMapPositions[level.aMapPositions.size] = (1734.96, 1483.53, -79.1785);
			level.aMapPositions[level.aMapPositions.size] = (1413.64, 947.566, -27.4248);
			level.aMapPositions[level.aMapPositions.size] = (3587.29, -89.7747, -4.725);
			level.aMapPositions[level.aMapPositions.size] = (-531.823, -580.638, -61.875);
			level.aMapPositions[level.aMapPositions.size] = (2158.51, 1015.38, -53.875);
			level.aMapPositions[level.aMapPositions.size] = (1655.67, 776.088, -53.875);
			level.aMapPositions[level.aMapPositions.size] = (793.053, 705.425, 34.125);
			level.aMapPositions[level.aMapPositions.size] = (135.298, -614.458, -53.875);
			level.aMapPositions[level.aMapPositions.size] = (989.607, 1225.65, 11.4212);
			level.aMapPositions[level.aMapPositions.size] = (-826.224, 34.3158, -51.9441);
			level.aMapPositions[level.aMapPositions.size] = (556.226, 1071.33, -23.3482);
			level.aMapPositions[level.aMapPositions.size] = (-832.952, 430.722, -51.8897);
			level.aMapPositions[level.aMapPositions.size] = (21.8593, 1218.06, 17.3901);
			level.aMapPositions[level.aMapPositions.size] = (446.447, 1698.81, 13.5848);
			level.aMapPositions[level.aMapPositions.size] = (-527.91, 1371.59, -53.875);
			level.aMapPositions[level.aMapPositions.size] = (-652.771, 44.9838, -52.875);
			level.aMapPositions[level.aMapPositions.size] = (189.965, 1947.75, 13.4556);
			level.aMapPositions[level.aMapPositions.size] = (-51.6913, 445.717, -36.375);
			level.aMapPositions[level.aMapPositions.size] = (447.64, 1538.66, -8.42922);
			level.aMapPositions[level.aMapPositions.size] = (798.609, 1688.42, -30.7706);
			level.aMapPositions[level.aMapPositions.size] = (1056.6, 1890.93, 0.627851);
			level.aMapPositions[level.aMapPositions.size] = (-1218.9, -915.686, -52.8485);
			level.aMapPositions[level.aMapPositions.size] = (679.941, 595.832, -52.9736);
			level.aMapPositions[level.aMapPositions.size] = (1273.53, 1901.6, 6.125);
			level.aMapPositions[level.aMapPositions.size] = (1546.22, 2375.06, 6.125);
			level.aMapPositions[level.aMapPositions.size] = (1233.33, 2241.46, 80.326);
			level.aMapPositions[level.aMapPositions.size] = (140.19, -220.334, -52.875);
			level.aMapPositions[level.aMapPositions.size] = (464.02, -970.572, 90.125);
			level.aMapPositions[level.aMapPositions.size] = (1817.47, 2503.78, -53.875);
			level.aMapPositions[level.aMapPositions.size] = (1930.18, 2680.62, -53.875);
			level.aMapPositions[level.aMapPositions.size] = (2045.6, -702.945, -53.875);
			level.aMapPositions[level.aMapPositions.size] = (2638.51, -140.858, -44.6632);
			level.aMapPositions[level.aMapPositions.size] = (2114.17, 1694.71, -53.875);
			level.aMapPositions[level.aMapPositions.size] = (2558.44, 1562.12, -49.0209);
			level.aMapPositions[level.aMapPositions.size] = (3388.21, 57.9037, 161.547);
			level.aMapPositions[level.aMapPositions.size] = (2554.21, 2203.52, -37.6);
			level.aMapPositions[level.aMapPositions.size] = (2083.25, 848.295, 138.125);
			level.aMapPositions[level.aMapPositions.size] = (1772.15, 561.417, 146.125);
			level.aMapPositions[level.aMapPositions.size] = (2137.12, 197.675, -53.875);

			//Drops
			level.aDropPositions[level.aDropPositions.size] = (1077.89, -909.684, -45.875);
			level.aDropPositions[level.aDropPositions.size] = (-522.496, -1008.47, 109.125);
			level.aDropPositions[level.aDropPositions.size] = (570.187, -1636.57, -53.875);
			level.aDropPositions[level.aDropPositions.size] = (2756.33, 913.336, 12.3859);
			level.aDropPositions[level.aDropPositions.size] = (2879.39, -392.071, -36.87);
			level.aDropPositions[level.aDropPositions.size] = (1513.71, 263.177, 35);
			level.aDropPositions[level.aDropPositions.size] = (1693.7, 1194.73, -51.8767);
			level.aDropPositions[level.aDropPositions.size] = (747.706, 1344.59, 199);
			level.aDropPositions[level.aDropPositions.size] = (-63.3528, 488.47, 5);
			level.aDropPositions[level.aDropPositions.size] = (1839.74, -1915.21, 91.414);
		break;
	}
}

/* ============================================================================================ */

/*

*/