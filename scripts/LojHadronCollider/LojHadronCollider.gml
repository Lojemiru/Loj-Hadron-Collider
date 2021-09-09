#macro __LHC_VERSION "v1.0.0"
#macro __LHC_PREFIX "[Loj Hadron Collider]"
#macro __LHC_SOURCE "https://github.com/Lojemiru/Loj-Hadron-Collider"

function __lhc_log(_msg) {
	if (PR_WRITELOGS) {
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

global.__lhc_colRefX = [__lhc_CollisionDirection.LEFT, __lhc_CollisionDirection.NONE, __lhc_CollisionDirection.RIGHT];
global.__lhc_colRefY = [__lhc_CollisionDirection.UP, __lhc_CollisionDirection.NONE, __lhc_CollisionDirection.DOWN];
global.__lhc_interfaces = { };

///@func							lhc_init();
///@desc							Initializes the LHC system for the calling instance.
function lhc_init() {
	__lhc_xVelSub = 0;
	__lhc_yVelSub = 0;
	__lhc_colliding = noone;
	__lhc_collisionDir = __lhc_CollisionDirection.NONE;
	__lhc_continue = array_create(__lhc_Axis.LENGTH, true);
	__lhc_objects = array_create(0);
	__lhc_interfaces = array_create(0);
	__lhc_objLen = 0;
	__lhc_intLen = 0;
	__lhc_list = ds_list_create();
	// These two are used ONLY for behavior functions where we can't directly reference the input xVel/yVel
	__lhc_axisVel = array_create(__lhc_Axis.LENGTH, 0);
	__lhc_active = true;
}

///@func							lhc_cleanup();
///@desc							Cleanup event - MUST BE RUN TO PREVENT MEMORY LEAKS.
function lhc_cleanup() {
	__lhc_active = false;
	ds_list_destroy(__lhc_list);
}

///@func							lhc_interface_create(name, functionName, [functionName2], [...]);
function lhc_interface_create(_name) {
	// Have to create the array first to set its individual slot values in a struct. Can't be lazy like in most other cases.
	global.__lhc_interfaces[$ _name] = array_create(argument_count - 1);
	
	// Loop over arguments past name, set names in the global interface struct.
	var i = 0;
	repeat (argument_count - 1) {
		global.__lhc_interfaces[$ _name][i] = argument[i + 1];
		++i;
	}
}

lhc_interface_create("ISolid");

///@func							lhc_interface_inherit(name);
function lhc_interface_inherit(_name) {
	// Set interface tag.
	if (!asset_has_tags(self.object_index, _name, asset_object)) asset_add_tags(self.object_index, _name, asset_object);
	// Loop over global interface struct for name value, set local variables of the index name to an empty function.
	var i = 0;
	repeat (array_length(global.__lhc_interfaces[$ _name])) {
		variable_instance_set(self, global.__lhc_interfaces[$ _name][i], function() { });
	}
}

///@func							lhc_add(object/interface, function);
///@desc							Add a collision event for the specified object.
///@param object					The object to target.
///@param function					The function to run on collision.
function lhc_add(_object, _function) {
	if (!is_string(_object)) {
	    variable_instance_set(id, "__lhc_event_" + object_get_name(_object), _function);
		__lhc_objects[__lhc_objLen++] = _object;
	}
	else {
		variable_instance_set(id, "__lhc_ievent_" + _object, _function);
		__lhc_interfaces[__lhc_intLen++] = _object;
	}
}

// TODO: make remove and replace work with interfaces, because... sure. Why not.

///@func							lhc_remove(object);
///@desc							Remove a collision event for the specified object.
///@param object					The object to target.
function lhc_remove(_object) {
	if (!variable_instance_exists(id, "__lhc_event_" + object_get_name(_object))) {
		throw "LojHadronCollider user error: attempted to remove a collision that has not previously been defined!";
	}
	
	// Can't delete the method variable, so just set it to scream at us if it somehow gets referenced
	variable_instance_set(id, "__lhc_event_" + object_get_name(_object), function() { throw "LojHadronCollider internal error: Attempted to reference a removed internal collision event." });
	
	var newObjects = array_create(0),
		i = 0,
		j = 0;
	
	// Copy old array into new array, except for the object we're deleting
	repeat (array_length(__lhc_objects)) {
		if (__lhc_objects[i] != _object) {
			newObjects[j] = __lhc_objects[i];
			j++;
		}
		i++;
	}
	
	// Reset iterables
	__lhc_objects = newObjects;
	__lhc_objLen = array_length(__lhc_objects);
}

///@func							lhc_add(object, function);
///@desc							Replaces the collision event for the specified object.
///@param object					The object to target.
///@param function					The function to run on collision.
function lhc_replace(_object, _function) {
	if (!variable_instance_exists(id, "__lhc_event_" + object_get_name(_object))) {
		throw "LojHadronCollider user error: attempted to replace a collision that has not previously been defined!";
	}
	variable_instance_set(id, "__lhc_event_" + object_get_name(_object), _function);
}

// Internal. Used to determine whether or not we need to run full pixel-by-pixel processing.
function __lhc_collision_found() {
	var j, i = 0;
	
	// Iterate along collision list.
	repeat (ds_list_size(__lhc_list)) {
		// Interface check
		if (__lhc_intLen != 0 && asset_has_any_tag(__lhc_list[| i].object_index, __lhc_interfaces, asset_object)) {
			return true;
		}
		
		j = 0;
		// Iterate along collision event list.
		repeat (__lhc_objLen) {
			// If we find ANY object that matches, immediately return true.
			if (__lhc_list[| i].object_index == __lhc_objects[j] || object_is_ancestor(__lhc_list[| i].object_index, __lhc_objects[j])) {
				return true;
			}
			++j;
		}
		++i;
	}
	return false;
}



function __lhc_reduce_collision_list() {
	var hitInd = 0,
		hitList = [],
		i = 0,
		j,
		k,
		cancel,
		objRef;
	// Scan through list
	repeat (ds_list_size(__lhc_list)) {
		// Scan through object targets
		
		objRef = __lhc_list[| i].object_index;
		
		if (asset_has_any_tag(objRef, __lhc_interfaces, asset_object)) {
			cancel = false;
			k = 0;
			repeat (hitInd) {
				if (hitList[k] == objRef) {
					cancel = true;
					break;
				}
				++k;
			}
			if (!cancel) {
				hitList[hitInd++] = objRef;
			}
		}
		else {
	 		j = 0;
			repeat (__lhc_objLen) {
				// If not collided already and object index matches...
				if (object_is_ancestor(objRef, __lhc_objects[j]) || objRef == __lhc_objects[j]) {
					show_debug_message("AHHHHH");
					cancel = false;
					k = 0;
					repeat (hitInd) {
						if (hitList[k] == __lhc_objects[j]) {
							cancel = true;
							break;
						}
						++k;
					}
					if (!cancel) {
						hitList[hitInd++] = __lhc_objects[j];
					}
					break;
	 			}
				++j;
			}
		}
		++i;
	}
	
	return hitList;
}

/*
function __lhc_reduce_collision_list() {
	var j, i = 0;
	
	repeat (ds_list_size(__lhc_list)) {
		
		++i;
	}
}
*/


// Internal. Used to check for collisions and run the appropriate function when found.
function __lhc_check_substep(_list, _len, _axis, _xS, _yS) {
	var col, i = 0, j;
	// Iterate along collision event list.
	repeat (_len) {
		col = instance_place(x + _xS * (_axis == __lhc_Axis.X), y + _yS * (_axis == __lhc_Axis.Y), _list[i]);
		// If we find one of our objects at the target position, set colliding instance ref, run function, and reset colliding instance ref.
		if (col != noone) {
			__lhc_colliding = col;
			if (__lhc_intLen != 0 && asset_has_any_tag(col.object_index, __lhc_interfaces, asset_object)) {
				j = 0;
				repeat (__lhc_intLen) {
					if (asset_has_tags(col.object_index, __lhc_interfaces[j], asset_object)) {
						variable_instance_get(id, "__lhc_ievent_" + __lhc_interfaces[j])();
					}
					++j;
				}
			}
			else {
				variable_instance_get(id, "__lhc_event_" + object_get_name(_list[i]))();
			}
			__lhc_colliding = noone;
		}
		++i;
	}
	
	/*
	repeat (__lhc_objLen) {
		col = instance_place(x + _xS * (_axis == __lhc_Axis.X), y + _yS * (_axis == __lhc_Axis.Y), __lhc_objects[i]);
		// If we find one of our objects at the target position, set colliding instance ref, run function, and reset colliding instance ref.
		if (col != noone) {
			__lhc_colliding = col;
			variable_instance_get(id, "__lhc_event_" + object_get_name(__lhc_objects[i]))();
			__lhc_colliding = noone;
		}
		++i;
	}
	*/
}

///@func							lhc_move(xVel, yVel, [line = false], [precise = false]);
///@desc							Moves the calling instance by the given xVel and yVel.
///@param xVel						The horizontal velocity to move by.
///@param yVel						The vertical velocity to move by.
///@param [line]					Whether or not to use a single raycast for the initial collision check. Fast, but only accurate for a single-pixel hitbox.
///@param [precise]					Whether or not to use precise hitboxes for the initial collision check.
function lhc_move(_x, _y, _line = false, _prec = false) {
	if (!__lhc_active || (_x == 0 && _y == 0)) return; // No need to process anything if we aren't moving.
	
	// Subpixel buffering
	__lhc_axisVel[__lhc_Axis.X] = _x + __lhc_xVelSub;
	__lhc_axisVel[__lhc_Axis.Y] = _y + __lhc_yVelSub;
	__lhc_xVelSub = frac(__lhc_axisVel[__lhc_Axis.X]);
	__lhc_yVelSub = frac(__lhc_axisVel[__lhc_Axis.Y]);
	// The rounding here is important! Keeps negative velocity values from misbehaving.
	__lhc_axisVel[__lhc_Axis.X] = round(__lhc_axisVel[__lhc_Axis.X] - __lhc_xVelSub);
	__lhc_axisVel[__lhc_Axis.Y] = round(__lhc_axisVel[__lhc_Axis.Y] - __lhc_yVelSub);
	
	// Store signs for quick reference
	var s, list, len;
	s[__lhc_Axis.X] = sign(__lhc_axisVel[__lhc_Axis.X]);
	s[__lhc_Axis.Y] = sign(__lhc_axisVel[__lhc_Axis.Y]);
	
	// Rectangle vs. line general collision checks, dump into the __lhc_list to check in __lhc_collision_found()
	if (!_line) {
		collision_rectangle_list(bbox_left + __lhc_axisVel[__lhc_Axis.X] * (1 - s[__lhc_Axis.X]) / 2, bbox_top + __lhc_axisVel[__lhc_Axis.Y] * (1 - s[__lhc_Axis.Y]) / 2, bbox_right + __lhc_axisVel[__lhc_Axis.X] * (1 + s[__lhc_Axis.X]) / 2, bbox_bottom + __lhc_axisVel[__lhc_Axis.Y] * (1 + s[__lhc_Axis.Y]) / 2, all, _prec, true, __lhc_list, false);
	}
	else {
		var centerX = floor((bbox_right + bbox_left) / 2),
			centerY = floor((bbox_bottom + bbox_top) / 2);
		collision_line_list(centerX, centerY, centerX + __lhc_axisVel[__lhc_Axis.X], centerY + __lhc_axisVel[__lhc_Axis.Y], all, _prec, true, __lhc_list, false);
	}
	
	list = __lhc_reduce_collision_list();
	len = array_length(list);
	
	// If we've found an instance in our event list...
	if (len > 0) {
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
				__lhc_check_substep(list, len, domAxis, s[__lhc_Axis.X], s[__lhc_Axis.Y]);
				
				// Process position.
				domMult = s[domAxis] * __lhc_continue[domAxis];
				domCurrent += domMult; 
				x += domMult * (domAxis == __lhc_Axis.X);
				y += domMult * (domAxis == __lhc_Axis.Y);
					
				// Determine whether or not the subordinate axis should process this loop.
				subCurrentLast = subCurrent;
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
				__lhc_check_substep(list, len, subAxis, s[__lhc_Axis.X], s[__lhc_Axis.Y]);
				
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
	
	// Prep list for next set of collision detections.
	if (__lhc_active) ds_list_clear(__lhc_list);
	
	// Reset general collision step parameters.
	__lhc_collisionDir = __lhc_CollisionDirection.NONE;
	__lhc_continue[__lhc_Axis.X] = true;
	__lhc_continue[__lhc_Axis.Y] = true;
	__lhc_axisVel[__lhc_Axis.X] = 0;
	__lhc_axisVel[__lhc_Axis.Y] = 0;
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
		targX = bbox_right + (col.x - col.bbox_left) + 1 + __lhc_axisVel[__lhc_Axis.X];
	}
	else {
		targX = bbox_left - (col.bbox_right - col.x) - 1 + __lhc_axisVel[__lhc_Axis.X];
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
		targY = bbox_bottom + (col.y - col.bbox_top) + 1 + __lhc_axisVel[__lhc_Axis.Y];
	}
	else {
		targY = bbox_top - (col.bbox_bottom - col.y) - 1 + __lhc_axisVel[__lhc_Axis.Y];
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