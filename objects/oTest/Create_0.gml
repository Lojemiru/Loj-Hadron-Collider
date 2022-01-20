/// @description Insert description here
// You can write your code in this editor
lhc_activate();

lhc_add("ISlope", function() {
	interactedSlope = noone;
	if (lhc_collision_horizontal()) {
        var _v = sign(lhc_get_vel_x());
    
        // Ceiling slopes - shift downwards to prevent clipping.
        if (!lhc_place_meeting(x + _v, y + 1, "ISolid")) {
            y++;
			interactedSlope = lhc_colliding();
        }
        // Floor slopes - shift upwards to move along slope.
        else if (!lhc_place_meeting(x + _v, y - 1, "ISolid")) {
            y--;
			interactedSlope = lhc_colliding();
        }
    }
});

lhc_add("ISolid", function() {
	if (lhc_colliding() != interactedSlope) {
		if (lhc_collision_horizontal()) {
			lhc_stop_x();
		}
		else if (lhc_collision_vertical()) {
			lhc_stop_y();
		}
	}
});