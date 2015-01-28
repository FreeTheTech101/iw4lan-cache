// _createart generated.  modify at your own risk. Changing values should be fine.
main()
{

	level.tweakfile = true;
 

	// * Fog section * 

	setDevDvar( "scr_fog_disable", "0" );
	
	setExpFog( 2315.28, 3009.05, 0.627317, 0.611552, 0.501961, 0.35, 0 );
	
	//setExpFog(     1000,             2000,          0,    0,     0,      1,          0.1,           0,         0,        0,                (-0.75,-0.29,0.58),           0,             1,            0 );
	//setExpFog( start distance, halfway distance, red, green, blue, max opacity, transition time, sun red, sun green, sun blue,      sun max opacity,       sun direction, sun begin fade angle, sun end fade angle )
	VisionSetNaked( "mp_cross_fire", 0 );

}
