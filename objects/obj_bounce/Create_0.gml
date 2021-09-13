///

glow = 0;
col = c_navy;

bounce = function() {
	// Stop further movement
	lhc_stop();
	
	// Invert x or y depending on collision direction
	if (lhc_collision_horizontal()) {
		xVel *= -1;
	}
	else {
		yVel *= -1;
	}
	
	// Glow effect
	glow = 10;
}

lhc_activate();

lhc_add("ISolid", bounce);