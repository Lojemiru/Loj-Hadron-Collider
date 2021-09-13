lhc_init();

lhc_create_interface("ISolid");

lhc_assign_interface("ISolid", obj_solid, obj_bounce);

show_debug_overlay(true);