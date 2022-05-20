#macro __LHC_VERSION "v1.2.2"
#macro __LHC_PREFIX "[Loj Hadron Collider]"
#macro __LHC_SOURCE "https://github.com/Lojemiru/Loj-Hadron-Collider"
#macro __LHC_EVENT "__lhc_event_"
#macro __LHC_VALIDATE if (!__lhc_active) return false
#macro LHC_WRITELOGS false

function __lhc_log(_msg) {
	if (LHC_WRITELOGS) {
		__lhc_log_force(_msg);
	}
}

function __lhc_log_force(_msg) {
	show_debug_message(__LHC_PREFIX + " " + _msg);
}

__lhc_log_force("Loading the Loj Hadron Collider " + __LHC_VERSION + " by Lojemiru...");
__lhc_log_force("For assistance, please refer to " + __LHC_SOURCE);

enum __lhc_CollisionDirection {
	NONE,
	RIGHT,
	UP,
	LEFT,
	DOWN,
	LENGTH
}

enum __lhc_Axis {
	X,
	Y,
	LENGTH
}

///@func							lhc_init();
///@desc							Initializes global data structures for the LHC. Must be called before the LHC can be used.
function lhc_init() {
	global.__lhc_colRefX = [__lhc_CollisionDirection.LEFT, __lhc_CollisionDirection.NONE, __lhc_CollisionDirection.RIGHT];
	global.__lhc_colRefY = [__lhc_CollisionDirection.UP, __lhc_CollisionDirection.NONE, __lhc_CollisionDirection.DOWN];
	global.__lhc_interfaces = { };
	__lhc_log_force("lhc_init() - Initialized.");
}

///@func							lhc_activate();
///@desc							Activates the LHC system for the calling instance.
function lhc_activate() {
	__lhc_xVelSub = 0;
	__lhc_yVelSub = 0;
	__lhc_colliding = noone;
	__lhc_collisionDir = __lhc_CollisionDirection.NONE;
	__lhc_continue = array_create(__lhc_Axis.LENGTH, true);
	__lhc_interfaces = array_create(0);
	__lhc_intLen = 0;
	__lhc_list = ds_list_create();
	__lhc_meetingList = ds_list_create();
	__lhc_axisVel = array_create(__lhc_Axis.LENGTH, 0);
	__lhc_active = true;
}

///@func							lhc_cleanup();
///@desc							Cleanup event - MUST BE RUN TO PREVENT MEMORY LEAKS.
function lhc_cleanup() {
	__lhc_active = false;
	
	try {
		ds_list_destroy(__lhc_list);
	}
	catch(e) {
		__lhc_log("Error in lhc_cleanup(): __lhc_list does not exist. Was an instance destroyed before it could run lhc_activate()? This is probably not a problem.");
	}
	
	try {
		ds_list_destroy(__lhc_meetingList);
	}
	catch(e) {
		__lhc_log("Error in lhc_cleanup(): __lhc_meetingList does not exist. Was an instance destroyed before it could run lhc_activate()? This is probably not a problem.");
	}
}

///@func							lhc_create_interface(name, [functionName], [...]);
///@desc							Creates an interface with the [optional] specified functions.
///@param name						The name of the interface.
///@param [function]				A function name to assign to the interface.
///@param [...]						More function names to assign to the interface.
function lhc_create_interface(_name) {
	// Have to create the array first to set its individual slot values in a struct. Can't be lazy like in most other cases.
	global.__lhc_interfaces[$ _name] = array_create(argument_count - 1);
	
	// Loop over arguments past name, set names in the global interface struct.
	var i = 0;
	repeat (argument_count - 1) {
		global.__lhc_interfaces[$ _name][i] = argument[i + 1];
		++i;
	}
	
	//__lhc_log("lhc_create_interface() - Created interface " + _name + " with " + string(argument_count - 1) + " functions.");
}

///@func							lhc_inherit_interface(interface);
///@desc							Inherits the function headers of the given interface.
///@param interface					The name of the interface to inherit from.
function lhc_inherit_interface(_interface) {
	if (!asset_has_any_tag(object_index, _interface, asset_object)) asset_add_tags(object_index, _interface, asset_object);
	
	// Loop over global interface struct for name value, set local variables of the index name to an empty function.
	var i = 0;
	repeat (array_length(global.__lhc_interfaces[$ _interface])) {
		variable_instance_set(self, global.__lhc_interfaces[$ _interface][i], function() { });
		++i;
	}
	
	//__lhc_log("lhc_inherit_interface() - Inherited interface " + _interface + ".");
}

///@func							lhc_assign_interface(interface, object, [...]);
///@desc							Assigns the input object[s] to the specified interface.
///@param interface					The name of the interface to assign objects to.
///@param object					An object to assign to the interface.
///@param [...]						More objects to assign to the interface.
function lhc_assign_interface(_interface) {
	var i = 1;
	repeat (argument_count - 1) {
		// Set interface tag.
		if (!asset_has_any_tag(argument[i], _interface, asset_object)) asset_add_tags(argument[i], _interface, asset_object);
		++i;
	}
	
	//__lhc_log("lhc_assign_interface() - assigned " + string(argument_count - 1) + " objects to interface " + _interface + ".");
}

///@func							lhc_add(interface, function);
///@desc							Add a collision event for the specified interface.
///@param interface					The interface to target.
///@param function					The function to run on collision.
function lhc_add(_interface, _function) {
	variable_instance_set(id, __LHC_EVENT + _interface, _function);
	__lhc_interfaces[__lhc_intLen++] = _interface;
}

///@func							lhc_remove(interface);
///@desc							Remove a collision event with the specified interface.
///@param interface					The interface to target.
function lhc_remove(_interface) {
	if (!variable_instance_exists(id, __LHC_EVENT + _interface)) {
		throw "LojHadronCollider user error: attempted to remove a collision that has not previously been defined!";
	}
	
	// Can't delete the method variable, so just set it to scream at us if it somehow gets referenced
	variable_instance_set(id, __LHC_EVENT + _interface, function() { throw "LojHadronCollider internal error: Attempted to reference a removed internal collision event." });
	
	var newInterfaces = array_create(0),
		i = 0,
		j = 0;
	
	// Copy old array into new array, except for the object we're deleting
	repeat (array_length(__lhc_interfaces)) {
		if (__lhc_interfaces[i] != _interface) {
			newInterfaces[j] = __lhc_interfaces[i];
			j++;
		}
		i++;
	}
	
	// Reset iterables
	__lhc_interfaces = newInterfaces;
	__lhc_intLen = array_length(__lhc_interfaces);
}

///@func							lhc_add(interface, function);
///@desc							Replaces the collision event with the specified interface.
///@param interface					The interface to target.
///@param function					The function to run on collision.
function lhc_replace(_interface, _function) {
	if (!variable_instance_exists(id, __LHC_EVENT + _interface)) {
		throw "LojHadronCollider user error: attempted to replace a collision that has not previously been defined!";
	}
	variable_instance_set(id, __LHC_EVENT + _interface, _function);
}


///@func							lhc_place_meeting(x, y, interface);
///@desc							Interface-based place_meeting().
///@param x							The x position to check for interfaces.
///@param y							The y position to check for interfaces.
///@param interface					The interface (or array of interfaces) to check for collisions.
function lhc_place_meeting(_x, _y, _interface) {
	__LHC_VALIDATE;
	instance_place_list(_x, _y, all, __lhc_meetingList, false);
	return __lhc_collision_found(__lhc_meetingList, _interface);
}

///@func							lhc_position_meeting(x, y, interface);
///@desc							Interface-based position_meeting().
///@param x							The x position to check for interfaces.
///@param y							The y position to check for interfaces.
///@param interface					The interface (or array of interfaces) to check for collisions.
function lhc_position_meeting(_x, _y, _interface) {
	__LHC_VALIDATE;
	instance_position_list(_x, _y, all, __lhc_meetingList, false);
	return __lhc_collision_found(__lhc_meetingList, _interface);
}

///@func							lhc_collision_circle(x, y, rad, interface, [prec] = false, [notme] = true);
///@desc							Interface-based collision_circle().
///@param x							The x coordinate of the center of the circle to check.
///@param y							The y coordinate of the center of the circle to check.
///@param rad						The radius (distance in pixels from its center to its edge).
///@param interface					The interface (or array of interfaces) to check for collisions.
///@param [prec]					Whether the check is based on precise collisions (true, which is slower) or its bounding box in general (false, faster). Defaults to false.
///@param [notme]					Whether the calling instance, if relevant, should be excluded (true) or not (false). Defaults to true.
function lhc_collision_circle(_x, _y, _r, _interface, _prec = false, _notme = true) {
	__LHC_VALIDATE;
	collision_circle_list(_x, _y, _r, all, _prec, _notme, __lhc_meetingList, false);
	return __lhc_collision_found(__lhc_meetingList, _interface);
}

///@func							lhc_collision_ellipse(x1, y1, x2, y2, interface, [prec] = false, [notme] = true);
///@desc							Interface-based collision_ellipse().
///@param x1						The x coordinate of the left side of the ellipse to check.
///@param y1						The y coordinate of the top side of the ellipse to check.
///@param x2						The x coordinate of the right side of the ellipse to check.
///@param y2						The y coordinate of the bottom side of the ellipse to check.
///@param interface					The interface (or array of interfaces) to check for collisions.
///@param [prec]					Whether the check is based on precise collisions (true, which is slower) or its bounding box in general (false, faster). Defaults to false.
///@param [notme]					Whether the calling instance, if relevant, should be excluded (true) or not (false). Defaults to true.
function lhc_collision_ellipse(_x1, _y1, _x2, _y2, _interface, _prec = false, _notme = true) {
	__LHC_VALIDATE;
	collision_ellipse_list(_x1, _y1, _x2, _y2, all, _prec, _notme, __lhc_meetingList, false);
	return __lhc_collision_found(__lhc_meetingList, _interface);
}

///@func							lhc_collision_line(x1, y1, x2, y2, interface, [prec] = false, [notme] = true);
///@desc							Interface-based collision_line().
///@param x1						The x coordinate of the start of the line.
///@param y1						The y coordinate of the start of the line.
///@param x2						The x coordinate of the end of the line.
///@param y2						The y coordinate of the end of the line.
///@param interface					The interface (or array of interfaces) to check for collisions.
///@param [prec]					Whether the check is based on precise collisions (true, which is slower) or its bounding box in general (false, faster). Defaults to false.
///@param [notme]					Whether the calling instance, if relevant, should be excluded (true) or not (false). Defaults to true.
function lhc_collision_line(_x1, _y1, _x2, _y2, _interface, _prec = false, _notme = true) {
	__LHC_VALIDATE;
	collision_line_list(_x1, _y1, _x2, _y2, all, _prec, _notme, __lhc_meetingList, false);
	return __lhc_collision_found(__lhc_meetingList, _interface);
}

///@func							lhc_collision_point(x, y, interface, [prec] = false, [notme] = true);
///@desc							Interface-based collision_point().
///@param x							The x coordinate of the point to check.
///@param y							The y coordinate of the point to check.
///@param interface					The interface (or array of interfaces) to check for collisions.
///@param [prec]					Whether the check is based on precise collisions (true, which is slower) or its bounding box in general (false, faster). Defaults to false.
///@param [notme]					Whether the calling instance, if relevant, should be excluded (true) or not (false). Defaults to true.
function lhc_collision_point(_x, _y, _interface, _prec = false, _notme = true) {
	__LHC_VALIDATE;
	collision_point_list(_x, _y, all, _prec, _notme, __lhc_meetingList, false);
	return __lhc_collision_found(__lhc_meetingList, _interface);
}

///@func							lhc_collision_rectangle(x1, y1, x2, y2, interface, [prec] = false, [notme] = true);
///@desc							Interface-based collision_rectangle().
///@param x1						The x coordinate of the left side of the rectangle to check.
///@param y1						The y coordinate of the top side of the rectangle to check.
///@param x2						The x coordinate of the right side of the rectangle to check.
///@param y2						The y coordinate of the bottom side of the rectangle to check.
///@param interface					The interface (or array of interfaces) to check for collisions.
///@param [prec]					Whether the check is based on precise collisions (true, which is slower) or its bounding box in general (false, faster). Defaults to false.
///@param [notme]					Whether the calling instance, if relevant, should be excluded (true) or not (false). Defaults to true.
function lhc_collision_rectangle(_x1, _y1, _x2, _y2, _interface, _prec = false, _notme = true) {
	__LHC_VALIDATE;
	collision_rectangle_list(_x1, _y1, _x2, _y2, all, _prec, _notme, __lhc_meetingList, false);
	return __lhc_collision_found(__lhc_meetingList, _interface);
}

// Internal. Used to check if we actually need to perform costly substep movement.
function __lhc_collision_found(_list, _interface = __lhc_interfaces) {
	var objRef, i = 0;
	repeat (ds_list_size(_list)) {
		objRef = _list[| i].object_index;
		// If this object has any of our tags, return true!
		if (asset_has_any_tag(objRef, _interface, asset_object)) {
			ds_list_clear(_list);
			return true;
		}
		++i;
	}
	ds_list_clear(_list);
	return false;
}

// Internal. Used to call __lhc_check with the appropriate parameters for this substep.
function __lhc_check_substep(_axis, _xS, _yS) {	
	__lhc_check(x + _xS * (_axis == __lhc_Axis.X), y + _yS * (_axis == __lhc_Axis.Y));
}

// Internal. Used to check for collisions and run the appropriate function when found.
function __lhc_check(_x, _y) {
	if (!__lhc_active) return;
	// Get collision list.
	var len = instance_place_list(_x, _y, all, __lhc_list, false);
	// If we're colliding with anything, iterate over the __lhc_list.
	if (len > 0) {
		var i = 0, j, col;
		repeat (len) {
			if (!__lhc_active) return; // Emergency exit if we ran cleanup during a prior iteration
			col = __lhc_list[| i];
			// Check if it has ANY of our tags. If so...
			if (asset_has_any_tag(col.object_index, __lhc_interfaces, asset_object)) {
				__lhc_colliding = col;
				j = 0;
				// Scan through Interfaces and run relevant events.
				repeat (__lhc_intLen) {
					if (asset_has_any_tag(col.object_index, __lhc_interfaces[j], asset_object)) {
						variable_instance_get(id, __LHC_EVENT + __lhc_interfaces[j])();
					}
					++j;
				}
				__lhc_colliding = noone;
			}
			++i;
		}
	}
	
	// Prep list for next set of collision detections.
	if (__lhc_active) ds_list_clear(__lhc_list);
}

///@func							lhc_check_static();
///@desc							Checks the calling instance's collision mask for collisions with Interfaces and runs the corresponding event(s), if relevant.
function lhc_check_static() {
	// Directionless collision!
	__lhc_collisionDir = __lhc_CollisionDirection.NONE;
	__lhc_check(floor(x), floor(y));
}

///@func							lhc_move(xVel, yVel, [line = false], [precise = false]);
///@desc							Moves the calling instance by the given xVel and yVel.
///@param xVel						The horizontal velocity to move by.
///@param yVel						The vertical velocity to move by.
///@param [line]					Whether or not to use a single raycast for the initial collision check. Fast, but only accurate for a single-pixel hitbox.
///@param [precise]					Whether or not to use precise hitboxes for the initial collision check.
function lhc_move(_x, _y, _line = false, _prec = false) {
	// No need to process anything if we aren't moving.
	if (!__lhc_active) return;
	
	// Subpixel buffering
	__lhc_axisVel[__lhc_Axis.X] = _x + __lhc_xVelSub;
	__lhc_axisVel[__lhc_Axis.Y] = _y + __lhc_yVelSub;
	__lhc_xVelSub = frac(__lhc_axisVel[__lhc_Axis.X]);
	__lhc_yVelSub = frac(__lhc_axisVel[__lhc_Axis.Y]);
	// The rounding here is important! Keeps negative velocity values from misbehaving.
	__lhc_axisVel[__lhc_Axis.X] = round(__lhc_axisVel[__lhc_Axis.X] - __lhc_xVelSub);
	__lhc_axisVel[__lhc_Axis.Y] = round(__lhc_axisVel[__lhc_Axis.Y] - __lhc_yVelSub);
	
	// If we're not moving this step, do a static check and return.
	if (__lhc_axisVel[__lhc_Axis.X] == 0 && __lhc_axisVel[__lhc_Axis.Y] == 0) {
		lhc_check_static();
		return;
	}
	
	// Store signs for quick reference
	var s, check;
	s[__lhc_Axis.X] = sign(__lhc_axisVel[__lhc_Axis.X]);
	s[__lhc_Axis.Y] = sign(__lhc_axisVel[__lhc_Axis.Y]);
	
	// Rectangle vs. line general collision checks, dump into the __lhc_list to check in __lhc_collision_found()
	if (!_line) {
		check = collision_rectangle_list(bbox_left + __lhc_axisVel[__lhc_Axis.X] * (1 - s[__lhc_Axis.X]) / 2, bbox_top + __lhc_axisVel[__lhc_Axis.Y] * (1 - s[__lhc_Axis.Y]) / 2, bbox_right + __lhc_axisVel[__lhc_Axis.X] * (1 + s[__lhc_Axis.X]) / 2, bbox_bottom + __lhc_axisVel[__lhc_Axis.Y] * (1 + s[__lhc_Axis.Y]) / 2, all, _prec, true, __lhc_list, false);
	}
	else {
		var centerX = floor((bbox_right + bbox_left) / 2),
			centerY = floor((bbox_bottom + bbox_top) / 2);
		check = collision_line_list(centerX, centerY, centerX + __lhc_axisVel[__lhc_Axis.X], centerY + __lhc_axisVel[__lhc_Axis.Y], all, _prec, true, __lhc_list, false);
	}
	
	// If we've found an instance in our event list...
	if (check > 0 && __lhc_collision_found(__lhc_list)) {
		var domMult, subMult,
			// Copying to a var is faster than repeated global refs.
			xRef = global.__lhc_colRefX,
			yRef = global.__lhc_colRefY,
			// Load axes into their appropriate vars.
			axisBool = (abs(__lhc_axisVel[__lhc_Axis.X]) > abs(__lhc_axisVel[__lhc_Axis.Y])),
			domAxis = axisBool ? __lhc_Axis.X : __lhc_Axis.Y,
			subAxis = axisBool ? __lhc_Axis.Y : __lhc_Axis.X,
			// General var prep.
			subIncrement = false,
			domCurrent = 0,
			subCurrent = 0,
			subCurrentLast = 0;
		
		// Iterate along the dominant axis...
		repeat (abs(__lhc_axisVel[domAxis])) {
			// Dominant axis processing. Only enter if we're still in continue mode and haven't reached our target value yet.
			if (__lhc_continue[domAxis] && (domCurrent != __lhc_axisVel[domAxis])) {
				// Set collision direction for collision event calls.
				__lhc_collisionDir = (domAxis == __lhc_Axis.X) ? xRef[s[__lhc_Axis.X] + 1] : yRef[s[__lhc_Axis.Y] + 1];
				
				// Check our next step.
				__lhc_check_substep(domAxis, s[__lhc_Axis.X], s[__lhc_Axis.Y]);
				
				// Process position.
				domMult = s[domAxis] * __lhc_continue[domAxis];
				domCurrent += domMult; 
				x += domMult * (domAxis == __lhc_Axis.X);
				y += domMult * (domAxis == __lhc_Axis.Y);
					
				// Determine whether or not the subordinate axis should process this loop.
				subCurrentLast = subCurrent;
				// Relative positioning nonsense - I don't remember what led me to this exactly but it has to do with point-slope line form.
				// It works, and that's all I really need to know now.
				subCurrent = floor((__lhc_axisVel[subAxis] * domCurrent) / __lhc_axisVel[domAxis]);
				subIncrement = (subCurrent != subCurrentLast);
				subCurrent = subCurrentLast; // This is VITAL. Prevents stupid slidey shenanigans!
			}
			
			// Subordinate axis processing. Only enter if we've determined to process or stopped on the dominant axis,
			// are still in continue mode, and haven't reached our target value yet.
			if ((subIncrement || !__lhc_continue[domAxis]) && __lhc_continue[subAxis] && (subCurrent != __lhc_axisVel[subAxis])) {
				// Set collision direction for collision event calls.
				__lhc_collisionDir = (subAxis == __lhc_Axis.X) ? xRef[s[__lhc_Axis.X] + 1] : yRef[s[__lhc_Axis.Y] + 1];
				
				// Check our next step.
				__lhc_check_substep(subAxis, s[__lhc_Axis.X], s[__lhc_Axis.Y]);
				
				// Process position.
				subMult = s[subAxis] * __lhc_continue[subAxis];
				subCurrent += subMult;
				x += subMult * (subAxis == __lhc_Axis.X);
				y += subMult * (subAxis == __lhc_Axis.Y);
			}
			
			// Quick exit if we've stopped on both axes.
			if (!__lhc_continue[__lhc_Axis.X] && !__lhc_continue[__lhc_Axis.Y]) {
				break;
			}
		}
	}
	else {
		// We haven't collided with anything, so we jump to our target position.
		x += __lhc_axisVel[__lhc_Axis.X];
		y += __lhc_axisVel[__lhc_Axis.Y];
	}
	
	// Reset general collision step parameters.
	__lhc_collisionDir = __lhc_CollisionDirection.NONE;
	__lhc_continue[__lhc_Axis.X] = true;
	__lhc_continue[__lhc_Axis.Y] = true;
}

///@func							lhc_colliding();
///@desc							Collision event-exclusive function. Returns the current colliding instance.
function lhc_colliding() {
	return __lhc_colliding;
}

///@func							lhc_stop();
///@desc							Collision event-exclusive function. Stops all further movement during this step.
function lhc_stop() {
	lhc_stop_x();
	lhc_stop_y();
}

///@func							lhc_stop_x();
///@desc							Collision event-exclusive function. Stops all further x-axis movement during this step.
function lhc_stop_x() {
	__lhc_continue[__lhc_Axis.X] = false;
}

///@func							lhc_stop_y();
///@desc							Collision event-exclusive function. Stops all further y-axis movement during this step.
function lhc_stop_y() {
	__lhc_continue[__lhc_Axis.Y] = false;
}

///@func							lhc_get_vel_x();
///@desc							Collision event-exclusive function. Returns the integer-rounded x-axis velocity for this movement step.
function lhc_get_vel_x() {
	return __lhc_axisVel[__lhc_Axis.X];
}

///@func							lhc_get_vel_y();
///@desc							Collision event-exclusive function. Returns the integer-rounded y-axis velocity for this movement step.
function lhc_get_vel_y() {
	return __lhc_axisVel[__lhc_Axis.Y];
}

///@func							lhc_get_offset_x();
///@desc							Gets the current subpixel x-axis offset.
function lhc_get_offset_x() {
	return __lhc_xVelSub;
}

///@func							lhc_get_offset_y();
///@desc							Gets the current subpixel y-axis offset.
function lhc_get_offset_y() {
	return __lhc_yVelSub;
}

///@func							lhc_set_offset_x(x);
///@desc							Sets the current subpixel x-axis offset.
///@param x							The value to set the subpixel x-axis offset to.
function lhc_set_offset_x(_x) {
	__lhc_xVelSub = _x;
}

///@func							lhc_set_offset_y(y);
///@desc							Sets the current subpixel y-axis offset.
///@param y							The value to set the subpixel y-axis offset to.
function lhc_set_offset_y(_y) {
	__lhc_yVelSub = _y;
}

///@func							lhc_add_offset_x(x);
///@desc							Adds the given value to the current subpixel x-axis offset.
///@param x							The value to add to the subpixel x-axis offset.
function lhc_add_offset_x(_x) {
	__lhc_xVelSub += _x;
}

///@func							lhc_add_offset_y(y);
///@desc							Adds the given value to the current subpixel y-axis offset.
///@param y							The value to add to the subpixel y-axis offset.
function lhc_add_offset_y(_y) {
	__lhc_yVelSub += _y;
}

///@func							lhc_collision_right();
///@desc							Collision event-exclusive function. Returns whether or not the current collision is occuring on the right of this instance.
function lhc_collision_right() {
	return __lhc_collisionDir == __lhc_CollisionDirection.RIGHT;
}

///@func							lhc_collision_down();
///@desc							Collision event-exclusive function. Returns whether or not the current collision is occuring on the bottom of this instance.
function lhc_collision_down() {
	return __lhc_collisionDir == __lhc_CollisionDirection.DOWN;
}

///@func							lhc_collision_left();
///@desc							Collision event-exclusive function. Returns whether or not the current collision is occuring on the left of this instance.
function lhc_collision_left() {
	return __lhc_collisionDir == __lhc_CollisionDirection.LEFT;
}

///@func							lhc_collision_up();
///@desc							Collision event-exclusive function. Returns whether or not the current collision is occuring on the top of this instance.
function lhc_collision_up() {
	return __lhc_collisionDir == __lhc_CollisionDirection.UP;
}

///@func							lhc_collision_static();
///@desc							Collision event-exclusive function. Returns whether or not the current collision is occuring in the static check event.
function lhc_collision_static() {
	return __lhc_collisionDir == __lhc_CollisionDirection.NONE;
}

///@func							lhc_collision_horizontal();
///@desc							Collision event-exclusive function. Returns whether or not the current collision is occuring on the left or right of this instance.
function lhc_collision_horizontal() {
	return (lhc_collision_right() || lhc_collision_left());
}

///@func							lhc_collision_vertical();
///@desc							Collision event-exclusive function. Returns whether or not the current collision is occuring on the top or bottom of this instance.
function lhc_collision_vertical() {
	return (lhc_collision_down() || lhc_collision_up());
}

///@func							lhc_behavior_push();
///@desc							Collision behavior function. Pushes the colliding instance to the appropriate bounding box edge.
function lhc_behavior_push() {
	lhc_behavior_push_horizontal();
	lhc_behavior_push_vertical();
}

///@func							lhc_behavior_push_horizontal();
///@desc							Collision behavior function. Pushes the colliding instance to the appropriate bounding box edge on the horizontal axis.
function lhc_behavior_push_horizontal() {
	if (!lhc_collision_horizontal()) return;
	
	var col = lhc_colliding(),
		targX;
	
	if (lhc_collision_right()) {
		targX = bbox_right + (col.x - col.bbox_left) + 1 + lhc_get_vel_x();
	}
	else {
		targX = bbox_left - (col.bbox_right - col.x) - 1 + lhc_get_vel_x();
	}
	
	with (col) {
		lhc_move(targX - x, 0);
	}
}

///@func							lhc_behavior_push_vertical();
///@desc							Collision behavior function. Pushes the colliding instance to the appropriate bounding box edge on the vertical axis.
function lhc_behavior_push_vertical() {
	if (!lhc_collision_vertical()) return;
	
	var col = lhc_colliding(),
		targY;
	
	if (lhc_collision_down()) {
		targY = bbox_bottom + (col.y - col.bbox_top) + 1 + lhc_get_vel_y();
	}
	else {
		targY = bbox_top - (col.bbox_bottom - col.y) - 1 + lhc_get_vel_y();
	}
	
	with (col) {
		lhc_move(0, targY - y);
	}
}

///@func							lhc_behavior_stop_on_axis();
///@desc							Collision behavior function. Stops calling instance on the appropriate axis. Does NOT manage x/y velocity variables.
function lhc_behavior_stop_on_axis() {
	if (lhc_collision_horizontal()) {
		lhc_stop_x();
	}
	
	if (lhc_collision_vertical()) {
		lhc_stop_y();
	}
}

__lhc_log_force("Loaded.");
