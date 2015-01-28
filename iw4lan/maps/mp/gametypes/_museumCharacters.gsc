//Mod Pack Menu - by 23Furious

#include common_scripts\utility;
#include maps\mp\_utility;
#include maps\mp\gametypes\_hud_util;

main()
{
	mapname = getDvar( "mapname" );
	if ( mapname == "ending" )
	{
              level thread precache();
              level thread price_arctic();
              level thread soap_arctic();
              level thread ghost_favela();
              level thread ghost_gulag();
              level thread jugg();
              level thread foley_trainer();
              level thread civilian();
              level thread civilian2();
              level thread makarov();
              level thread estate();
              level thread airborne_arctic();
              level thread price_zodiac();
              level thread ranger();
              level thread airborne_1();
              level thread airborne_2();
              level thread airborne_3();
              level thread shepherd();
              level thread militia();
              level thread dog();
              level thread soap_gulag();
              }
}

precache()
{

//******************Weapons and Shock******************//

        PreCacheShellShock( "af_chase_ending_wakeup" );
        PreCacheShellShock( "nosound" );
        precacheItem("winchester1200");

//******************SP animation******************//

        PrecacheMpAnim("german_shepherd_attackidle_bark");
        PrecacheMpAnim("german_shepherd_run");
        PrecacheMpAnim("killhouse_sas_price");
        PrecacheMpAnim("killhouse_sas_2");
        PrecacheMpAnim("favela_chaotic_crouchcover_fireA");
        PrecacheMpAnim("village_interrogationA_Price");
        PrecacheMpAnim("estate_ghost_radio");
        PrecacheMpAnim("training_intro_foley_begining");
        PrecacheMpAnim("hostage_chair_idle");
        PrecacheMpAnim("invasion_vehicle_cover_dialogue_guy1");
        PrecacheMpAnim("guardB_standing_cold_idle");
        PrecacheMpAnim("guardA_standing_cold_idle");
        PrecacheMpAnim("civilian_cellphonewalk");
        PrecacheMpAnim("civilian_hackey_guy1");
        PrecacheMpAnim("civilian_hackey_guy2");
        PrecacheMpAnim("german_shepherd_run_attack");
        PrecacheMpAnim("german_shepherd_death_front");
        PrecacheMpAnim("zodiac_trans_L2R");
        PrecacheMpAnim("civilian_sitting_talking_A_1");
        PrecacheMpAnim("civilian_smoking_A");
        PrecacheMpAnim("civilian_directions_1_B");
        PrecacheMpAnim("afchase_ending_shepherd_gun_monologue");
        PrecacheMpAnim("civilian_texting_standing");
        PrecacheMpAnim("airport_mkv_holdfire");
        PrecacheMpAnim("training_intro_foley_turnaround_1");
        PrecacheMpAnim("patrol_bored_idle_smoke");
        PrecacheMpAnim("parabolic_leaning_guy_idle_training");

//******************MP animation******************//

        PrecacheMpAnim("pb_shotgun_death_front");
        PrecacheMpAnim("pb_crouch_death_flip");
        PrecacheMpAnim("pb_stand_death_frontspin");
        PrecacheMpAnim("pb_death_run_right");
        PrecacheMpAnim("pb_stand_death_leg");

//******************Body models******************//

        precacheModel("german_sheperd_dog");
        precacheModel("body_tf141_assault_a");
        precacheModel("body_hero_seal_udt_ghost");
        precacheModel("body_us_army_assault_a");
        precacheModel("body_hero_soap_arctic");
        precacheModel("body_tf141_assault_a");
        precacheModel("body_tf141_assault_a");
        precacheModel("body_complete_sp_juggernaut");
        precacheModel("body_work_civ_male_a");
        precacheModel("body_airport_com_a");
        precacheModel("body_secret_service_smg");
        precacheModel("body_opforce_arctic_lmg");
        precacheModel("body_urban_civ_male_aa");
        precacheModel("body_opforce_sniper_ghillie");
        precacheModel("body_airborne_assault_a");
        precacheModel("body_secret_service_shotgun");
        precacheModel("body_vil_shepherd");
        precacheModel("body_militia_assault_aa_wht");
        precacheModel("body_militia_smg_ac_blk");
        precacheModel("body_desert_tf141_zodiac");
        precacheModel("mp_body_desert_tf141_assault_a");

        precacheModel("viewhands_us_army");

        precacheModel("body_hero_seal_udt_soap");


//******************Head models******************//

        precacheModel("head_hero_ghost_udt");
        precacheModel("head_hero_foley");
        precacheModel("head_hero_price_arctic");
        precacheModel("head_hero_soap_arctic");
        precacheModel("head_hero_ghost_soccom");
        precacheModel("head_work_civ_male_a_hostage");
        precacheModel("head_hero_dunn");
        precacheModel("head_opforce_arctic_a");
        precacheModel("head_vil_makarov");
        precacheModel("head_hero_nikolai");
        precacheModel("head_militia_bb_blk_hat");
        precacheModel("head_tf141_desert_a");
        precacheModel("head_shadow_co_b");

        precacheModel("head_airport_d");
        precacheModel("head_vil_shepherd");
        precacheModel("head_militia_a_wht");
        precacheModel("head_hero_price_desert_beaten");
        precacheModel("head_us_army_d");
        precacheModel("head_airborne_a");
        precacheModel("head_airborne_b");
        precacheModel("head_opforce_sniper_ghillie");
        precacheModel("head_hero_soap_udt");

//******************Shaders******************//

        precacheShader("stance_prone");
        precacheShader("stance_stand");
        precacheShader("stance_crouch");

}

price_arctic()
{
	level.character[1] = spawn("script_model", (-15436, 24048, -16360));
	level.character[1] setModel("body_tf141_assault_a");
	level.character[1].head = spawn("script_model", level.character[1].origin+(-4,0,52));
	level.character[1].head setmodel("head_hero_price_arctic");
	level.character[1].head.angles = (270,0,270);
	level.character[1].head linkto( level.character[1], "j_head" );
	level.character[1].healthTrigger = spawn("script_model", level.character[1].origin + (0,0,50) ); 
	level.character[1].healthTrigger setModel("com_plasticcase_enemy");
	level.character[1].healthTrigger hide();
	level.character[1].healthTrigger.angles = (90,0,0);
	level.character[1].healthTrigger setcandamage(true);
	level.character[1].healthTrigger linkto(level.character[1]);
	level.character[1].healthTrigger.health = 100;
	level.character[1] thread Damage_Tracker();
	for(;;)
	{
              if(isDefined(level.character[1].healthTrigger)){
	level.character[1] ScriptModelPlayAnim("killhouse_sas_price");
	level.character[1].head ScriptModelPlayAnim("killhouse_sas_price");}
              wait 19;
	}
}

soap_arctic()
{
	level.character[2] = spawn("script_model", (-15169.2, 24143.4, -16329.1));
	level.character[2] setModel("body_hero_soap_arctic");
	level.character[2].head = spawn("script_model", level.character[2].origin+(-4,0,52));
	level.character[2].head setmodel("head_hero_soap_arctic");
	level.character[2].head.angles = (270,0,270);
	level.character[2].head linkto( level.character[2], "j_head" );
	level.character[2].healthTrigger = spawn("script_model", level.character[2].origin + (0,0,50) ); 
	level.character[2].healthTrigger setModel("com_plasticcase_enemy");
	level.character[2].healthTrigger hide();
	level.character[2].healthTrigger.angles = (90,0,0);
	level.character[2].healthTrigger setcandamage(true);
	level.character[2].healthTrigger linkto(level.character[2]);
	level.character[2].healthTrigger.health = 100;
	level.character[2] thread Damage_Tracker();
	for(;;)
	{
              if(isDefined(level.character[2].healthTrigger)){
	level.character[2] ScriptModelPlayAnim("training_intro_foley_turnaround_1");}
              wait 13;
	}
}

ghost_favela()
{
	level.character[3] = spawn("script_model", (-15315.5, 23491.5, -16358));
	level.character[3] setModel("body_tf141_assault_a");
	level.character[3].head = spawn("script_model", level.character[3].origin+(-4,0,52));
	level.character[3].head setmodel("head_hero_ghost_soccom");
	level.character[3].head.angles = (270,0,270);
	level.character[3].head linkto( level.character[3], "j_head" );
	level.character[3].healthTrigger = spawn("script_model", level.character[3].origin + (0,0,50) ); 
	level.character[3].healthTrigger setModel("com_plasticcase_enemy");
	level.character[3].healthTrigger hide();
	level.character[3].healthTrigger.angles = (90,0,0);
	level.character[3].healthTrigger setcandamage(true);
	level.character[3].healthTrigger linkto(level.character[3], "tag_origin");
	level.character[3].healthTrigger.health = 100;
	level.character[3] thread Damage_Tracker();
	for(;;)
	{
              if(isDefined(level.character[3].healthTrigger)){
	level.character[3] ScriptModelPlayAnim("favela_chaotic_crouchcover_fireA");}
              wait 5;
	}
}

jugg()
{
	level.character[4] = spawn("script_model", (-14019.8, 22865.6, -16329.9));
	level.character[4] setModel("body_complete_sp_juggernaut");
              level.character[4].angles = (0, 8.5, 0);
	level.character[4].healthTrigger = spawn("script_model", level.character[4].origin + (0,0,50) ); 
	level.character[4].healthTrigger setModel("com_plasticcase_enemy");
	level.character[4].healthTrigger hide();
	level.character[4].healthTrigger.angles = (90,0,0);
	level.character[4].healthTrigger setcandamage(true);
	level.character[4].healthTrigger linkto(level.character[4]);
	level.character[4].healthTrigger.health = 500;
	level.character[4] thread Damage_Tracker();
	for(;;)
	{
              if(isDefined(level.character[4].healthTrigger)){
	level.character[4] ScriptModelPlayAnim("training_intro_foley_begining");}
              wait 15;
	}
}

ghost_gulag()
{
	level.character[5] = spawn("script_model", (-15319, 22436, -16359));
	level.character[5] setModel("body_hero_seal_udt_ghost");
	level.character[5].head = spawn("script_model", level.character[5].origin+(-4,0,52));
	level.character[5].head setmodel("head_hero_ghost_udt");
	level.character[5].head.angles = (270,0,270);
	level.character[5].head linkto( level.character[5], "j_head" );
	level.character[5].healthTrigger = spawn("script_model", level.character[5].origin + (0,0,50) ); 
	level.character[5].healthTrigger setModel("com_plasticcase_enemy");
	level.character[5].healthTrigger hide();
	level.character[5].healthTrigger.angles = (90,0,0);
	level.character[5].healthTrigger setcandamage(true);
	level.character[5].healthTrigger linkto(level.character[5]);
	level.character[5].healthTrigger.health = 100;
	level.character[5] thread Damage_Tracker();
	for(;;)
	{
              if(isDefined(level.character[5].healthTrigger)){
	level.character[5] ScriptModelPlayAnim("estate_ghost_radio");}
              wait 20;
	}
}

foley_trainer()
{
	level.character[6] = spawn("script_model", (-14574.6, 23112.9, -16330));
	level.character[6] setModel("body_us_army_assault_a");
	level.character[6].head = spawn("script_model", level.character[6].origin+(-4,0,52));
	level.character[6].head setmodel("head_hero_foley");
	level.character[6].head.angles = (270,0,270);
	level.character[6].head linkto( level.character[6], "j_head" );
	level.character[6].healthTrigger = spawn("script_model", level.character[6].origin + (0,0,50) ); 
	level.character[6].healthTrigger setModel("com_plasticcase_enemy");
	level.character[6].healthTrigger hide();
	level.character[6].healthTrigger.angles = (90,0,0);
	level.character[6].healthTrigger setcandamage(true);
	level.character[6].healthTrigger linkto(level.character[6]);
	level.character[6].healthTrigger.health = 100;
	level.character[6] thread Damage_Tracker();
	for(;;)
	{
              if(isDefined(level.character[6].healthTrigger)){
	level.character[6] ScriptModelPlayAnim("training_intro_foley_begining");}
              wait 10;
	}
}

civilian()
{
	level.character[7] = spawn("script_model", (-14596, 22370, -16329.5));
	level.character[7] setModel("body_work_civ_male_a");
              level.character[7].angles = (0, 60, 0);
	level.character[7].head = spawn("script_model", level.character[7].origin+(-4,0,52));
	level.character[7].head setmodel("head_work_civ_male_a_hostage");
	level.character[7].head.angles = (270,0,270);
	level.character[7].head linkto( level.character[7], "j_head" );
	level.character[7].healthTrigger = spawn("script_model", level.character[7].origin + (0,0,50) ); 
	level.character[7].healthTrigger setModel("com_plasticcase_enemy");
	level.character[7].healthTrigger hide();
	level.character[7].healthTrigger.angles = (90,0,0);
	level.character[7].healthTrigger setcandamage(true);
	level.character[7].healthTrigger linkto(level.character[7]);
	level.character[7].healthTrigger.health = 100;
	level.character[7] thread Damage_Tracker();
	for(;;)
	{
              if(isDefined(level.character[7].healthTrigger)){
	level.character[7] ScriptModelPlayAnim("hostage_chair_idle");}
              wait 18;
	}
}

civilian2()
{
	level.character[8] = spawn("script_model", (-14678.2, 22394.1, -16329.9));
	level.character[8] setModel("body_urban_civ_male_aa");
	level.character[8].head = spawn("script_model", level.character[8].origin+(-4,0,52));
	level.character[8].head setmodel("head_hero_nikolai");
	level.character[8].head.angles = (270,0,270);
	level.character[8].head linkto( level.character[8], "j_head" );
	level.character[8].healthTrigger = spawn("script_model", level.character[8].origin + (0,0,50) ); 
	level.character[8].healthTrigger setModel("com_plasticcase_enemy");
	level.character[8].healthTrigger hide();
	level.character[8].healthTrigger.angles = (90,0,0);
	level.character[8].healthTrigger setcandamage(true);
	level.character[8].healthTrigger linkto(level.character[8]);
	level.character[8].healthTrigger.health = 100;
	level.character[8] thread Damage_Tracker();
	for(;;)
	{
              if(isDefined(level.character[8].healthTrigger)){
	level.character[8] ScriptModelPlayAnim("civilian_cellphonewalk");}
              wait 14;
	}
}

makarov()
{
	level.character[9] = spawn("script_model", (-14426.7, 23455.3, -16330));
	level.character[9] setModel("body_airport_com_a");
	level.character[9].head = spawn("script_model", level.character[9].origin+(-4,0,52));
	level.character[9].head setmodel("head_vil_makarov");
	level.character[9].head linkto( level.character[9], "j_head", (-10,0,0), (0,0,0));
	level.character[9].healthTrigger = spawn("script_model", level.character[9].origin + (0,0,50) ); 
	level.character[9].healthTrigger setModel("com_plasticcase_enemy");
	level.character[9].healthTrigger hide();
	level.character[9].healthTrigger.angles = (90,0,0);
	level.character[9].healthTrigger setcandamage(true);
	level.character[9].healthTrigger linkto(level.character[9]);
	level.character[9].healthTrigger.health = 100;
	level.character[9] thread Damage_Tracker();
	for(;;)
	{
              if(isDefined(level.character[9].healthTrigger)){
	level.character[9] ScriptModelPlayAnim("village_interrogationA_Price");}
              wait 12;
	}
}

airborne_arctic()
{
	level.character[10] = spawn("script_model", (-15364.7, 24208.2, -16322.6));
	level.character[10] setModel("body_opforce_arctic_lmg");
	level.character[10].head = spawn("script_model", level.character[10].origin+(-4,0,52));
	level.character[10].head setmodel("head_opforce_arctic_a");
	level.character[10].head.angles = (270,0,270);
	level.character[10].head linkto( level.character[10], "j_head" );
	level.character[10].healthTrigger = spawn("script_model", level.character[10].origin + (0,0,50) ); 
	level.character[10].healthTrigger setModel("com_plasticcase_enemy");
	level.character[10].healthTrigger hide();
	level.character[10].healthTrigger.angles = (90,0,0);
	level.character[10].healthTrigger setcandamage(true);
	level.character[10].healthTrigger linkto(level.character[10]);
	level.character[10].healthTrigger.health = 100;
	level.character[10] thread Damage_Tracker();
	for(;;)
	{
              if(isDefined(level.character[10].healthTrigger)){
	level.character[10] ScriptModelPlayAnim("guardA_standing_cold_idle");}
              wait 11;
	}
}

estate()
{
	level.character[11] = spawn("script_model", (-15285.8, 23136.4, -16339.2));
	level.character[11] setModel("body_opforce_sniper_ghillie");
	level.character[11].head = spawn("script_model", level.character[11].origin+(-4,0,52));
	level.character[11].head setmodel("head_opforce_sniper_ghillie");
	level.character[11].head.angles = (270,0,270);
	level.character[11].head linkto( level.character[11], "j_head" );
	level.character[11] ScriptModelPlayAnim("civilian_hackey_guy1");
	level.character[11].healthTrigger = spawn("script_model", level.character[11].origin + (0,0,50) ); 
	level.character[11].healthTrigger setModel("com_plasticcase_enemy");
	level.character[11].healthTrigger hide();
	level.character[11].healthTrigger.angles = (90,0,0);
	level.character[11].healthTrigger setcandamage(true);
	level.character[11].healthTrigger linkto(level.character[11]);
	level.character[11].healthTrigger.health = 100;
	level.character[11] thread Damage_Tracker();
}

price_zodiac()
{
	level.character[12] = spawn("script_model", (-13967, 23883, -16346));
	level.character[12] setModel("body_desert_tf141_zodiac");
	level.character[12].head = spawn("script_model", level.character[12].origin+(-4,0,52));
	level.character[12].head setmodel("head_hero_price_desert_beaten");
	level.character[12].head.angles = (270,0,270);
	level.character[12].head linkto( level.character[12], "j_head" );
	level.character[12].healthTrigger = spawn("script_model", level.character[12].origin + (0,0,50) ); 
	level.character[12].healthTrigger setModel("com_plasticcase_enemy");
	level.character[12].healthTrigger hide();
	level.character[12].healthTrigger.angles = (90,0,0);
	level.character[12].healthTrigger setcandamage(true);
	level.character[12].healthTrigger linkto(level.character[12]);
	level.character[12].healthTrigger.health = 100;
	level.character[12] thread Damage_Tracker();
	for(;;)
	{
              if(isDefined(level.character[12].healthTrigger)){
	level.character[12] ScriptModelPlayAnim("zodiac_trans_L2R");}
              wait 10;
	}
}

ranger()
{
	level.character[13] = spawn("script_model", (-14440.2, 24098.3, -16330));
	level.character[13] setModel("body_us_army_assault_a");
	level.character[13].head = spawn("script_model", level.character[13].origin+(-4,0,52));
	level.character[13].head setmodel("head_us_army_d");
	level.character[13].head.angles = (270,0,270);
	level.character[13].head linkto( level.character[13], "j_head" );
	level.character[13].healthTrigger = spawn("script_model", level.character[13].origin + (0,0,50) ); 
	level.character[13].healthTrigger setModel("com_plasticcase_enemy");
	level.character[13].healthTrigger hide();
	level.character[13].healthTrigger.angles = (90,0,0);
	level.character[13].healthTrigger setcandamage(true);
	level.character[13].healthTrigger linkto(level.character[13]);
	level.character[13].healthTrigger.health = 100;
	level.character[13] thread Damage_Tracker();
	for(;;)
	{
              if(isDefined(level.character[13].healthTrigger)){
	level.character[13] ScriptModelPlayAnim("civilian_sitting_talking_A_1");}
              wait 9.8;
	}
}

airborne_1()
{
	level.character[14] = spawn("script_model", (-14665.6, 23460.6, -16329.9));
	level.character[14] setModel("body_secret_service_shotgun");
	level.character[14].head = spawn("script_model", level.character[14].origin+(-4,0,52));
	level.character[14].head setmodel("head_airport_d");
	level.character[14].head.angles = (270,0,270);
	level.character[14].head linkto( level.character[14], "j_head" );
	level.character[14] ScriptModelPlayAnim("civilian_smoking_A");
	level.character[14].healthTrigger = spawn("script_model", level.character[14].origin + (0,0,50) ); 
	level.character[14].healthTrigger setModel("com_plasticcase_enemy");
	level.character[14].healthTrigger hide();
	level.character[14].healthTrigger.angles = (90,0,0);
	level.character[14].healthTrigger setcandamage(true);
	level.character[14].healthTrigger linkto(level.character[14]);
	level.character[14].healthTrigger.health = 100;
	level.character[14] thread Damage_Tracker();
}

airborne_2()
{
	level.character[15] = spawn("script_model", (-14516.4, 23406.2, -16329.9));
	level.character[15] setModel("body_airborne_assault_a");
	level.character[15].head = spawn("script_model", level.character[15].origin+(-4,0,52));
	level.character[15].head setmodel("head_airborne_b");
	level.character[15].head.angles = (270,0,270);
	level.character[15].head linkto( level.character[15], "j_head" );
	level.character[15] ScriptModelPlayAnim("civilian_directions_1_B");
	level.character[15].healthTrigger = spawn("script_model", level.character[15].origin + (0,0,50) ); 
	level.character[15].healthTrigger setModel("com_plasticcase_enemy");
	level.character[15].healthTrigger hide();
	level.character[15].healthTrigger.angles = (90,0,0);
	level.character[15].healthTrigger setcandamage(true);
	level.character[15].healthTrigger linkto(level.character[15]);
	level.character[15].healthTrigger.health = 100;
	level.character[15] thread Damage_Tracker();
}

airborne_3()
{
	level.character[16] = spawn("script_model", (-14544.8, 24202.9, -16329.9));
	level.character[16] setModel("body_airborne_assault_a");
	level.character[16].head = spawn("script_model", level.character[16].origin+(-4,0,52));
	level.character[16].head setmodel("head_airborne_a");
	level.character[16].head.angles = (270,0,270);
	level.character[16].head linkto( level.character[16], "j_head" );
	level.character[16] ScriptModelPlayAnim("civilian_hackey_guy2");
	level.character[16].healthTrigger = spawn("script_model", level.character[16].origin + (0,0,50) ); 
	level.character[16].healthTrigger setModel("com_plasticcase_enemy");
	level.character[16].healthTrigger hide();
	level.character[16].healthTrigger.angles = (90,0,0);
	level.character[16].healthTrigger setcandamage(true);
	level.character[16].healthTrigger linkto(level.character[16]);
	level.character[16].healthTrigger.health = 100;
	level.character[16] thread Damage_Tracker();
}

shepherd()
{
	level.character[17] = spawn("script_model", (-13998, 23717.1, -16328.3));
	level.character[17] setModel("body_vil_shepherd");
	level.character[17].head = spawn("script_model", level.character[17].origin+(-4,0,52));
	level.character[17].head setmodel("head_vil_shepherd");
	level.character[17].head.angles = (270,0,270);
	level.character[17].head linkto( level.character[17], "j_head" );
	level.character[17].healthTrigger = spawn("script_model", level.character[17].origin + (0,0,50) ); 
	level.character[17].healthTrigger setModel("com_plasticcase_enemy");
	level.character[17].healthTrigger hide();
	level.character[17].healthTrigger.angles = (90,0,0);
	level.character[17].healthTrigger setcandamage(true);
	level.character[17].healthTrigger linkto(level.character[17]);
	level.character[17].healthTrigger.health = 100;
	level.character[17] thread Damage_Tracker();
              for(;;)
              {
              if(isDefined(level.character[17].healthTrigger)){
	level.character[17] ScriptModelPlayAnim("afchase_ending_shepherd_gun_monologue");}
              wait 15.11;
              }
}

militia()
{
	level.character[18] = spawn("script_model", (-15376.5, 23409.2, -16325.5));
	level.character[18] setModel("body_militia_assault_aa_wht");
	level.character[18].head = spawn("script_model", level.character[18].origin+(-4,0,52));
	level.character[18].head setmodel("head_militia_a_wht");
	level.character[18].head.angles = (270,0,270);
	level.character[18].head linkto( level.character[18], "j_head" );
	level.character[18].healthTrigger = spawn("script_model", level.character[18].origin + (0,0,50) ); 
	level.character[18].healthTrigger setModel("com_plasticcase_enemy");
	level.character[18].healthTrigger hide();
	level.character[18].healthTrigger.angles = (90,0,0);
	level.character[18].healthTrigger setcandamage(true);
	level.character[18].healthTrigger linkto(level.character[18]);
	level.character[18].healthTrigger.health = 100;
	level.character[18] thread Damage_Tracker();
              for(;;)
              {
              if(isDefined(level.character[18].healthTrigger)){
	level.character[18] ScriptModelPlayAnim("estate_ghost_radio");}
              wait 17.32;
              }
}

dog()
{
	level.character[19] = spawn("script_model", (-15208.6, 23404.1, -16328.8));
	level.character[19] setModel("german_sheperd_dog");
              level.character[19].angles = (3.56975, 130.683, -1.14649);
	level.character[19].healthTrigger = spawn("script_model", level.character[19].origin + (0,0,50) ); 
	level.character[19].healthTrigger setModel("com_plasticcase_enemy");
	level.character[19].healthTrigger hide();
	level.character[19].healthTrigger.angles = (90,0,0);
	level.character[19].healthTrigger setcandamage(true);
	level.character[19].healthTrigger linkto(level.character[19]);
	level.character[19].healthTrigger.health = 100;
	level.character[19] thread Damage_Tracker_2();
	level.character[19] ScriptModelPlayAnim("german_shepherd_attackidle_bark");
}

soap_gulag()
{
	level.character[20] = spawn("script_model", (-15260, 22435, -16359));
	level.character[20] setModel("body_hero_seal_udt_soap");
	level.character[20].head = spawn("script_model", level.character[20].origin+(-4,0,52));
	level.character[20].head setmodel("head_hero_soap_udt");
	level.character[20].head.angles = (270,0,270);
	level.character[20].head linkto( level.character[20], "j_head" );
	level.character[20].healthTrigger = spawn("script_model", level.character[20].origin + (0,0,50) ); 
	level.character[20].healthTrigger setModel("com_plasticcase_enemy");
	level.character[20].healthTrigger hide();
	level.character[20].healthTrigger.angles = (90,0,0);
	level.character[20].healthTrigger setcandamage(true);
	level.character[20].healthTrigger linkto(level.character[20]);
	level.character[20].healthTrigger.health = 100;
	level.character[20] thread Damage_Tracker("patrol_bored_idle_smoke");
              for(;;)
              {
              if(isDefined(level.character[20].healthTrigger)){
	level.character[20] ScriptModelPlayAnim("patrol_bored_idle_smoke");}
              wait 18.42;
              }
}

Damage_Tracker()
{
	while(1)
	{
		self.healthTrigger waittill("damage", eInflictor, attacker, victim, iDamage, iDFlags, sMeansOfDeath, sWeapon, vPoint, vDir, sHitLoc, psOffsetTime);
		attacker thread maps\mp\gametypes\_damagefeedback::updateDamageFeedback(sHitLoc);
		self.healthTrigger.health -= iDamage;
		if(self.healthTrigger.health <= 0)
		{
		attacker thread maps\mp\gametypes\_rank::scorePopup( 100, 0, (1, 1, 0.5), 0 );
                            attacker thread maps\mp\gametypes\_rank::underScorePopup("Killed Character!", (1, 1, 0.5), 0);
		self playdeathSound();
		playFx(level.bloodfx,self.origin+(0,0,50));
                            self thread doDeathAnim();
		wait 0.01;
                            self.healthTrigger delete();
                            wait 0.01;
                            self.healthTrigger = undefined;
                            self thread delete_character_over_time();
		break;
		}
	wait 0.06;
	}
}

Damage_Tracker_2()
{
	while(1)
	{
		self.healthTrigger waittill("damage", eInflictor, attacker, victim, iDamage, iDFlags, sMeansOfDeath, sWeapon, vPoint, vDir, sHitLoc, psOffsetTime);
		attacker thread maps\mp\gametypes\_damagefeedback::updateDamageFeedback(sHitLoc);
		self.healthTrigger.health -= iDamage;
		if(self.healthTrigger.health <= 0)
		{
		attacker thread maps\mp\gametypes\_rank::scorePopup( 100, 0, (1, 1, 0.5), 0 );
                            attacker thread maps\mp\gametypes\_rank::underScorePopup("Killed Character!", (1, 1, 0.5), 0);
		self playSound("dog_neckbreak");
		playFx(level.bloodfx,self.origin+(0,0,50));
                            self ScriptModelPlayAnim("german_shepherd_death_front");
		wait 0.01;
                            self.healthTrigger delete();
                            wait 0.01;
                            self.healthTrigger = undefined;
                            self thread delete_character_over_time();
		break;
		}
	wait 0.06;
	}
}

delete_character_over_time()
{
wait 26;
self delete();
self.head delete();
}

doDeathAnim()
{
deathAnim = randomInt(5);
   switch(deathAnim)
   {
   case 0: self ScriptModelPlayAnim("pb_shotgun_death_front"); break;
   case 1: self ScriptModelPlayAnim("pb_crouch_death_flip"); break;
   case 2: self ScriptModelPlayAnim("pb_stand_death_frontspin"); break;
   case 3: self ScriptModelPlayAnim("pb_death_run_right"); break;
   case 4: self ScriptModelPlayAnim("pb_stand_death_leg"); break;
   }
}