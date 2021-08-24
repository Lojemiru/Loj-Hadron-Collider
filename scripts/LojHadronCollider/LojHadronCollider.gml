#macro __LHC_VERSION "1.1.0"

show_debug_message(@"
///----------------------------------------------------------------------------------------------------------\\\
     This project is using the Loj Hadron Collider v" + __LHC_VERSION + @", created by Lojemiru.
	 The LHC is released under the MIT license; please ensure that you have
	 reviewed and followed the terms of the license before releasing this project.
\\\----------------------------------------------------------------------------------------------------------///
");

enum __lhc_CollisionDirection {
	NONE,
	RIGHT,
	UP,
	LEFT,
	DOWN,
	LENGTH
}

global.__lhc_colRefX = [__lhc_CollisionDirection.LEFT, __lhc_CollisionDirection.NONE, __lhc_CollisionDirection.RIGHT];
global.__lhc_colRefY = [__lhc_CollisionDirection.UP, __lhc_CollisionDirection.NONE, __lhc_CollisionDirection.DOWN];

///@func							lhc_init();
///@desc							Initializes the LHC system for the calling instance.
function lhc_init() {
	__lhc_xVelSub = 0;
	__lhc_yVelSub = 0;
	__lhc_colliding = noone;
	__lhc_collisionDir = __lhc_CollisionDirection.NONE;
	__lhc_continueX = true;
	__lhc_continueY = true;
	__lhc_objects = array_create(0);
	__lhc_flagsX = array_create(0);
	__lhc_flagsY = array_create(0);
	__lhc_objLen = 0;
	__lhc_list = ds_list_create();
	__lhc_xCurrent = x;
	__lhc_yCurrent = y;
	// These two are used ONLY for behavior functions where we can't directly reference the input xVel/yVel
	__lhc_xVel = 0;
	__lhc_yVel = 0;
}

///@func							lhc_cleanup();
///@desc							Cleanup event - MUST BE RUN TO PREVENT MEMORY LEAKS.
function lhc_cleanup() {
	ds_list_destroy(__lhc_list);
}

///@func							lhc_add(object, function);
///@desc							Add a collision event for the specified object.
///@param object					The object to target.
///@param function					The function to run on collision.
function lhc_add(_object, _function) {
    variable_instance_set(id, "__lhc_event_" + object_get_name(_object), _function);
	__lhc_objects[__lhc_objLen] = _object;
	__lhc_flagsY[__lhc_objLen] = false;
	__lhc_flagsX[__lhc_objLen++] = false;
}

///@func							lhc_remove(object);
///@desc							Remove a collision event for the specified object.
///@param object					The object to target.
function lhc_remove(_object) {
	if (!variable_instance_exists(id, "__lhc_event_" + object_get_name(_object))) {
		throw "LojHadronCollider user error: attempted to remove a collision that has not previously been defined!";
	}
	
	// Can't delete the method variable, so just clean it up to nothing instead
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
	__lhc_flagsY = array_create(j, false);
	__lhc_flagsX = array_create(j, false);
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

function __lhc_reduce_collision_list(list, count) {
	var hitInd = 0,
		hitList = [],
		i = 0,
		j,
		k,
		cancel,
		objRef;
	// Scan through list
	repeat (count) {
		// Scan through object targets
		j = 0;
		repeat (__lhc_objLen) {
			// If not collided already and object index matches...
			objRef = list[| i].object_index;
			if (object_is_ancestor(objRef, __lhc_objects[j]) || objRef == __lhc_objects[j]) {
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
		++i;
	}
	
	return hitList;
}

function __lhc_check_substep(_x, _y, _hitList, _hitInd, _flags) {
	var notCollided = true,
		i = 0,
		col;
		
	repeat (_hitInd) {
		if (!_flags[i]) {
			col = instance_place(_x, _y, _hitList[i]);
			
			if (col != noone) {
				__lhc_colliding = col;
				variable_instance_get(id, "__lhc_event_" + object_get_name(_hitList[i]))();
				_flags[i] = true;
				__lhc_colliding = noone;
				notCollided = false;
			}
		}
		++i;
	}
	
	return notCollided;
}

///@func							lhc_move(xVel, yVel, [line = false], [precise = false]);
///@desc							Moves the calling instance by the given xVel and yVel.
///@param xVel						The horizontal velocity to move by.
///@param yVel						The vertical velocity to move by.
///@param [line]					Whether or not to use a single raycast for the initial collision check. Fast, but only accurate for a single-pixel hitbox.
///@param [precise]					Whether or not to use precise hitboxes for the initial collision check.
function lhc_move(_x, _y, _line = false, _prec = false) {
	if (_x == 0 && _y == 0) return;
	
	var i,
		count,
		_xVel = _x + __lhc_xVelSub,
		_yVel = _y + __lhc_yVelSub;
	__lhc_xVelSub = frac(_xVel);
	__lhc_yVelSub = frac(_yVel);
	_xVel -= __lhc_xVelSub;
	_yVel -= __lhc_yVelSub;
	
	__lhc_xVel = _xVel;
	__lhc_yVel = _yVel;
	
	var xS = sign(_xVel),
		yS = sign(_yVel);
		
	if (!_line) {
		count = collision_rectangle_list(bbox_left + _xVel * (1 - xS) / 2, bbox_top + _yVel * (1 - yS) / 2, bbox_right + _xVel * (1 + xS) / 2, bbox_bottom + _yVel * (1 + yS) / 2, all, _prec, true, __lhc_list, false);
	}
	else {
		var centerX = floor((bbox_right + bbox_left) / 2),
			centerY = floor((bbox_bottom + bbox_top) / 2);
		count = collision_line_list(centerX, centerY, centerX + _xVel, centerY + _yVel, all, _prec, true, __lhc_list, false);
	}
	
	if (count != 0) {
		var hitList = __lhc_reduce_collision_list(__lhc_list, count),
			hitInd = array_length(hitList);
			
		if (hitInd > 0) {
			var _xStart = x,
				_yStart = y,
				dist = point_distance(_xStart, _yStart, _xStart + _xVel, _yStart + _yVel),
				dir = point_direction(_xStart, _yStart, _xStart + _xVel, _yStart + _yVel),
				xVec = lengthdir_x(dist, dir) / dist,
				yVec = lengthdir_y(dist, dir) / dist,
				xTarg,
				yTarg,
				xRef = global.__lhc_colRefX,
				yRef = global.__lhc_colRefY;
			
			__lhc_xCurrent = x;
			__lhc_yCurrent = y;
			
			__lhc_continueX = xVec != 0;
			__lhc_continueY = yVec != 0;
			
			var i = 1;
			repeat (dist + 1) {
				if (__lhc_continueX) {
					xTarg = round(_xStart + xVec * i);
					
					__lhc_collisionDir = xRef[xS + 1];
					__lhc_check_substep(xTarg, __lhc_yCurrent, hitList, hitInd, __lhc_flagsX);
					
					__lhc_xCurrent += xVec * __lhc_continueX;
				}
				
				if (__lhc_continueY) {
					yTarg = round(_yStart + yVec * i);
					
					__lhc_collisionDir = yRef[yS + 1];
					__lhc_check_substep(__lhc_xCurrent, yTarg, hitList, hitInd, __lhc_flagsY);
					
					__lhc_yCurrent += yVec * __lhc_continueY;
				}
				
				if (!__lhc_continueX && !__lhc_continueY) {
					break;
				}
				++i;
			}
		}
	}

	x += _xVel * __lhc_continueX;
	y += _yVel * __lhc_continueY;

	ds_list_clear(__lhc_list);
	
	__lhc_flagsX = array_create(__lhc_objLen, false);
	__lhc_flagsY = array_create(__lhc_objLen, false);
	__lhc_collisionDir = __lhc_CollisionDirection.NONE;
	__lhc_continueX = true;
	__lhc_continueY = true;
	__lhc_xVel = 0;
	__lhc_yVel = 0;
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
	__lhc_continueX = false;
	x = __lhc_xCurrent;
}

///@func							lhc_stop_y();
///@desc							Collision event-exclusive function. Stops all further y-axis movement during this step.
function lhc_stop_y() {
	__lhc_continueY = false;
	y = __lhc_yCurrent;
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

///@func							lhc_collision_direction();
///@desc							Collision event-exclusive function. Returns the current collision direction as a member of the CollisionDirection enum.
function lhc_collision_direction() {
	return __lhc_collisionDir;
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
///@desc							Collision behavior function. Pushes the colliding instance to the appropriate bounding box edge on the horizontal axis only.
function lhc_behavior_push_horizontal() {
	var col = lhc_colliding();
	
	if (lhc_collision_right()) {
		lhc_colliding().x = bbox_right + (col.x - col.bbox_left) + 1 + __lhc_xVel;
	}
	else if (lhc_collision_left()) {
		lhc_colliding().x = bbox_left - (col.bbox_right - col.x) - 1 + __lhc_xVel;
	}
}

///@func							lhc_behavior_push_vertical();
///@desc							Collision behavior function. Pushes the colliding instance to the appropriate bounding box edge on the vertical axis only.
function lhc_behavior_push_vertical() {
	var col = lhc_colliding();
	
	if (lhc_collision_down()) {
		lhc_colliding().y = bbox_bottom + (col.y - col.bbox_top) + 1 + __lhc_yVel;
	}
	else {
		lhc_colliding().y = bbox_top - (col.bbox_bottom - col.y) - 1 + __lhc_yVel;
	}
}