///

step++;

if (step % stepRate[instInd] == 0 && !collision_rectangle(room_width / 2 - 32, room_height / 2 - 32, room_width / 2 + 32, room_height / 2 + 32, inst[instInd], false, false)) {

	var b = instance_create_depth(room_width / 2, room_height / 2, -4000, inst[instInd]);

	var dir = point_direction(b.x, b.y, mouse_x, mouse_y)

	b.xVel = lengthdir_x(instSpeed[instInd], dir);
	b.yVel = lengthdir_y(instSpeed[instInd], dir);

}

if (keyboard_check_pressed(ord("M"))) {
	instance_destroy(inst[instInd]);
	instInd++;
	if (instInd >= instSize) instInd = 0;	
}