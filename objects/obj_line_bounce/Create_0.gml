///
function vec2(_x, _y) constructor {
	x = _x;
	y = _y;
}

bounces = 5;
death = 60;

points = array_create(0);
points[0] = new vec2(x, y);

lhc_activate();

lhc_add("ISolid", function() {
	lhc_stop();
	if (xVel != 0 && lhc_collision_horizontal()) {
		xVel *= -1;
	}
	if (yVel != 0 && lhc_collision_vertical()) {
		yVel *= -1;
	}
	
	points[array_length(points)] = new vec2(x, y);
	
	if (bounces >= 0) {
		bounces--;
	}
	else {
		xVel = 0;
		yVel = 0;
		death = 1;
	}
});