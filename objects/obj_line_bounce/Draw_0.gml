///

for (var i = 0; i < array_length(points) - 1; i++) {
	draw_line_color(points[i].x, points[i].y, points[i + 1].x, points[i + 1].y, c_aqua, c_orange);
}