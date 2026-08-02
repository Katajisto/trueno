// @Entity is what registers a type with the engine; see src/entities.jai.
Test_Marker :: struct {
	#as using base : Entity;
	base.type = Test_Marker;

	PARTS :: Entity_Part.[];
} @Entity

game_engine_config :: () {
}

game_init :: () {
}

game_ui :: (theme: *GR.Overall_Theme) {
	
}

game_tick :: (dt: float64) {
}

game_draw :: () {
}
