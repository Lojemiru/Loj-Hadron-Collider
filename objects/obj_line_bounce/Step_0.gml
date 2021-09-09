///
lhc_move(xVel, yVel, true);

if (death >= 0) death--;
else instance_destroy();

// This code causes significant slowdowns for line rendering between so many points.
// Disable it for a more accurate test of actual engine performance.
if (xVel != 0 || yVel != 0) {
	points[array_length(points)] = new vec2(x, y);
}