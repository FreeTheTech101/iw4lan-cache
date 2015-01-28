#include common_scripts\utility;
#include maps\mp\_utility;
#include maps\mp\gametypes\_hud_util;

main()
{
	setDevDvar( "scr_fog_disable", "0" );
	
	ent = create_vision_set_fog( "estate_hilltop" );
	ent.startDist = 1600;
	ent.halfwayDist = 6164;
	ent.red = 0.333;
	ent.green = 0.421;
	ent.blue = 0.482;
	ent.maxOpacity = 1;
	ent.transitionTime = 0;
	
	
	ent = create_vision_set_fog( "estate_forest" );
	ent.startDist = 1117;
	ent.halfwayDist = 2252;
	ent.red = 0.309;
	ent.green = 0.383;
	ent.blue = 0.509;
	ent.maxOpacity = 0.49;
	ent.transitionTime = 0;

	
	ent = create_vision_set_fog( "estate_ambush_clearing" );
		ent.startDist = 650;
	ent.halfwayDist = 1000;
	ent.red = 0.309;
	ent.green = 0.383;
	ent.blue = 0.509;
	ent.maxOpacity = 0.49;
	ent.transitionTime = 0;

	ent = create_vision_set_fog( "estate_house_approach" );
	ent.startDist = 3650;
	ent.halfwayDist = 12000;
	ent.red = 0.309;
	ent.green = 0.383;
	ent.blue = 0.509;
	ent.maxOpacity = 0.402;
	ent.transitionTime = 0;

	
	ent = create_vision_set_fog( "estate_house_interior" );
	ent.startDist = 780;
	ent.halfwayDist = 2000;
	ent.red = 0.309;
	ent.green = 0.383;
	ent.blue = 0.509;
	ent.maxOpacity = 0.80;
	ent.transitionTime = 0;

	
	ent = create_vision_set_fog( "estate_forest_clearing" );
	ent.startDist = 1196;
	ent.halfwayDist = 4600;
	ent.red = 0.309;
	ent.green = 0.383;
	ent.blue = 0.509;
	ent.maxOpacity = 0.402;
	ent.transitionTime = 0;

	
	ent = create_vision_set_fog( "estate_house_backyard" );
	ent.startDist = 500;
	ent.halfwayDist = 8000;
	ent.red = 0.309;
	ent.green = 0.383;
	ent.blue = 0.509;
	ent.maxOpacity = 0.402;
	ent.transitionTime = 0;

	ent = create_vision_set_fog( "estate_birchfield" );
	ent.startDist = 331;
	ent.halfwayDist = 853;
	ent.red = 0.342;
	ent.green = 0.393;
	ent.blue = 0.48;
	ent.maxOpacity = 0.434;
	ent.transitionTime = 0;

	
	ent = create_vision_set_fog( "estate_finalfield" );
	ent.startDist = 450;
	ent.halfwayDist = 6318;
    ent.red = 0.350;
	ent.green = 0.434;
	ent.blue = 0.575;
	ent.maxOpacity = 1;
	ent.transitionTime = 0;

	
	ent = create_vision_set_fog( "estate_dragplayer" );
	ent.startDist = 3650;
	ent.halfwayDist = 12000;
    ent.red = 0.309;
	ent.green = 0.383;
	ent.blue = 0.509;
	ent.maxOpacity = 0.402;
	ent.transitionTime = 0;

	
	ent = create_vision_set_fog( "estate_throwplayer" );
	ent.startDist = 3650;
	ent.halfwayDist = 12000;
	ent.red = 0.309;
	ent.green = 0.383;
	ent.blue = 0.509;
	ent.maxOpacity = 0.402;
	ent.transitionTime = 0;

	
	ent = create_vision_set_fog( "estate_burnplayer" );
	ent.startDist = 3650;
	ent.halfwayDist = 12000;
	ent.red = 0.309;
	ent.green = 0.383;
	ent.blue = 0.509;
	ent.maxOpacity = 0.402;
	ent.transitionTime = 0;

	
	vision_set_fog_changes( "estate_hilltop", 0 );
}

create_vision_set_fog( fogset )
{
	if ( !isdefined( level.vision_set_fog ) )
		level.vision_set_fog = [];
	ent = SpawnStruct();
	ent.name = fogset;

	level.vision_set_fog[ fogset ] = ent;
	return ent;
}


vision_set_fog_changes( vision_set, transition_time )
{
	do_fog = vision_set_changes( vision_set, transition_time );
	if ( do_fog && IsDefined( get_vision_set_fog( vision_set ) ) )
		fog_set_changes( vision_set, transition_time );
}



vision_set_changes( vision_set, transition_time )
{
	if ( !isdefined( level.vision_set_transition_ent ) )
	{
		level.vision_set_transition_ent = SpawnStruct();
		level.vision_set_transition_ent.vision_set = "";
		level.vision_set_transition_ent.time = 0;
	}

	// this the same vision set we're already doing?
	if ( level.vision_set_transition_ent.vision_set == vision_set && level.vision_set_transition_ent.time == transition_time )
		return false;// no fog

	level.vision_set_transition_ent.vision_set = vision_set;
	level.vision_set_transition_ent.time = transition_time;

	VisionSetNaked( vision_set, transition_time );

	//iprintlnbold( vision_set );
	SetDvar( "vision_set_current", vision_set );

	return true;// do fog
}

get_vision_set_fog( fogset )
{
	if ( !isdefined( level.vision_set_fog ) )
		level.vision_set_fog = [];

	ent = level.vision_set_fog[ fogset ];
	//assertex( IsDefined( ent ), "visiont set fog: " + fogset + "does not exist, use create_vision_set_fog( " + fogset + " ) in your level_fog.gsc." );
	return ent;
}


fog_set_changes( fog_set, transition_time )
{
	if ( !isdefined( level.fog_transition_ent ) )
	{
		level.fog_transition_ent = SpawnStruct();
		level.fog_transition_ent.fogset = "";
		level.fog_transition_ent.time = 0;
	}


	if ( !isdefined( level.fog_set ) )
		level.fog_set = [];

	ent = level.fog_set[ fog_set ];
	if ( !isdefined( ent ) )
	{
		AssertEx( IsDefined( level.vision_set_fog ), "Fog set:" + fog_set + " does not exist, use create_fog( " + fog_set + " ) or create_vision_set_fog( " + fog_set + " ); in your /createart/level_fog.gsc" );
		ent = level.vision_set_fog[ fog_set ];
	}

	AssertEx( IsDefined( ent ), "Fog set:" + fog_set + " does not exist, use create_fog( " + fog_set + " ) or create_vision_set_fog( " + fog_set + " ); in your /createart/level_fog.gsc" );

	//if ( !isdefined( ent ) )
	//	return;

	// transition time override
	if ( !isdefined( transition_time ) )
		transition_time = ent.transitiontime;
	AssertEx( IsDefined( transition_time ), "Fog set: " + fog_set + " does not have a transition_time defined and a time was not specified in the function call." );

	// this the same fog set we're already doing?
	if ( level.fog_transition_ent.fogset == fog_set && level.fog_transition_ent.time == transition_time )
		return;

	if ( IsDefined( ent.sunRed ) )
	{
		SetExpFog(
		ent.startDist,
		ent.halfwayDist,
		ent.red,
		ent.green,
		ent.blue,
		ent.maxOpacity,
		transition_time,
		ent.sunRed,
		ent.sunGreen,
		ent.sunBlue,
		ent.sunDir,
		ent.sunBeginFadeAngle,
		ent.sunEndFadeAngle,
		ent.normalFogScale );
	}
	else
	{
		SetExpFog(
		ent.startDist,
		ent.halfwayDist,
		ent.red,
		ent.green,
		ent.blue,
		ent.maxOpacity,
		transition_time );
	}

	level.fog_transition_ent.fogset = fog_set;
	level.fog_transition_ent.time = transition_time;
}