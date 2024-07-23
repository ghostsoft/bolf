class_name LineCalculator extends Node

static func throughLine(p0 : Vector2i, p1 : Vector2i, distance : int) -> Array:
	var points = []
	var slope = (p1.y - p0.y) as float / (p1.x-p0.x) as float
	print(slope)

	if abs(slope) > 1:
		# y is primary
		for y in range(distance):
			var dx 
			var dy = p0.y
			if p1.y < p0.y:
				#line up
				dy -= y
				dx = (1/slope) * (dy - p0.y) + p0.x
			else:
				#line down
				dy += y
				dx = (1/slope) * (dy - p0.y) + p0.x
				
			points.append(Vector2i(round(dx), dy))
	else:
		# x is primary
		for x in range(distance):
			var dx = p0.x
			var dy
			if p1.x < p0.x:
				#line left
				dx -= x
				dy = slope * (dx - p0.x) + p0.y
			else:
				#line right
				dx += x
				dy = slope * (dx - p0.x) + p0.y
			
			points.append(Vector2i(dx, round(dy)))
			
	return points

# directly from roguebasin (python version)
# http://www.roguebasin.com/index.php/Bresenham%27s_Line_Algorithm#Python
static func bresenhamLine(start : Vector2i, end : Vector2i):
	# Bresenham's Line Algorithm
	# Produces a list of tuples from start and end
	
	# Setup initial conditions
	var x1 = start.x
	var y1 = start.y
	var x2 = end.x
	var y2 = end.y
	var dx = x2 - x1
	var dy = y2 - y1
	
	# Determine how steep the line is
	var is_steep = false
	if abs(dy) > abs(dx):
		is_steep = true
	
	# Rotate line
	if is_steep:
		var tmp_x1 = x1
		var tmp_x2 = x2
		x1 = y1
		y1 = tmp_x1
		x2 = y2
		y2 = tmp_x2

	# Swap start and end points if necessary and store swap state
	var swapped = false
	if x1 > x2:
		var tmp_x1 = x1
		var tmp_y1 = y1
		x1 = x2
		x2 = tmp_x1
		y1 = y2
		y2 = tmp_y1
		swapped = true

	# Recalculate differentials
	dx = x2 - x1
	dy = y2 - y1
	
	# Calculate error
	var error = (dx / 2.0) as int
	var ystep
	if y1 < y2:
		ystep = 1
	else:
		ystep = -1
	
	# Iterate over bounding box generating points between start and end
	var y = y1
	var points = []
	for x in range(x1, x2):
		var coord
		if is_steep:
			coord = Vector2i(y, x)
		else:
			coord = Vector2i(x, y)
		points.append(coord)
		error -= abs(dy)
		if error < 0:
			y += ystep
			error += dx
	
	# Reverse the list if the coordinates were swapped
	if swapped:
		points.reverse()
		points.push_front(start)
	return points

# directly from https://www.redblobgames.com/grids/line-drawing.html
static func supercover_line(p0 : Vector2, p1 : Vector2) -> Array[Vector2i]:
	var dx : float = p1.x-p0.x
	var dy : float = p1.y-p0.y
	var nx : float = absf(dx)
	var ny : float = absf(dy)
	var sign_x : int = 1 if dx > 0 else -1
	var sign_y : int = 1 if dy > 0 else -1

	var p = Vector2(p0.x, p0.y)
	var points : Array[Vector2i] = [Vector2i(floor(p.x), floor(p.y))]
	var ix : int = 0
	var iy : int = 0
	while (ix < nx || iy < ny):
		var decision = (1 + 2*ix) * ny - (1 + 2*iy) * nx
		if (decision == 0):
			#next step is diagonal
			p.x += sign_x
			p.y += sign_y
			ix += 1
			iy += 1
		elif (decision < 0):
			#next step is horizontal
			p.x += sign_x
			ix += 1
		else:
			#next step is vertical
			p.y += sign_y
			iy += 1
		points.append(Vector2i(floor(p.x), floor(p.y)));
	return points

static func dda_supercover(p0 : Vector2, p1 : Vector2) -> Array[Vector2i]:
	var out : Array[Vector2i]
	var x0 := p0.x
	var x1 := p1.x
	var y0 := p0.y
	var y1 := p1.y
	var vx = x1-x0	# get the differences
	var vy = y1-y0
	var dx = sqrt(1 + pow((vy/vx),2))	# length of vector <1, slope>
	var dy = sqrt(1 + pow((vx/vy),2))	# length of vector <1/slope, 1>

	var ix = floor(x0)
	var iy = floor(y0)	# initialize starting positions
	var sx	# sx is the increment direction
	var ex	# ex is the distance from x0 to ix
	if vx < 0:
		sx = -1
		ex = (x0-ix) * dx
	else:
		sx = 1
		ex = (ix + 1-x0) * dx	# subtract from 1 instead of 0 to make up for flooring ix

	var sy
	var ey
	if vy < 0:
		sy = -1
		ey = (y0-iy) * dy
	else:
		sy = 1
		ey = (iy + 1-y0) * dy

	var done = false
	var _len = sqrt(pow(vx,2) + pow(vy,2))
	while not done:
		if min(ex,ey) <= _len:
			var rx= ix
			var ry = iy
			if ex < ey:
				ex = ex + dx
				ix = ix + sx
			else:
				ey = ey + dy
				iy = iy + sy
			out.append(Vector2i(rx,ry))
		elif not done:	# return the final two coordinates
			done = true
			out.append(Vector2i(ix,iy))
	return out

static func dda_subpixel(p0 : Vector2, p1 : Vector2) -> Array[Vector2i]:
	var a : float
	var aa : float
	var b : float
	var d : float
	var i : int
	
	var out : Array[Vector2i]
	var x0 : float = p0.x
	var x1 : float = p1.x
	var y0 : float = p0.y
	var y1 : float = p1.y
	
	# end points
	out.append(Vector2i(floor(p0.x), floor(p0.y)))
	out.append(Vector2i(floor(p1.x), floor(p1.y)))
	
	#x-axis pixel cross
	var a0 : float = 1.0
	var a1 : float = 0.0
	var n : int = 0
	if (x0<x1):
		#a0=ceil(x0)
		a0=floor(x0)
		a1=floor(x1)
		d=(y1-y0)/(x1-x0)
		a=a0; b=y0+(a0-x0)*d
		n=absf(a1-a0)
	elif (x0>x1):
		#a0=ceil(x1)
		a0=floor(x1)
		a1=floor(x0)
		d=(y1-y0)/(x1-x0)
		a=a0; b=y1+(a0-x1)*d
		n=absf(a1-a0)
	if (a0<=a1):
		aa = a
		i = 0
		while(i <= n):
			out.append(Vector2i(floor(aa), floor(b)))
			out.append(Vector2i(floor(a), floor(b)))
			i += 1
			aa = a
			a += 1
			b += d
	
	#y-axis pixel cross
	a0= 1.0
	a1= 0.0
	n= 0.0
	if (y0<y1):
		#a0=ceil(y0)
		a0=floor(y0)
		a1=floor(y1)
		d=(x1-x0)/(y1-y0)
		a=a0; b=x0+(a0-y0)*d
		n=absf(a1-a0)
	elif (y0>y1):
		#a0=ceil(y1)
		a0=floor(y1)
		a1=floor(y0)
		d=(x1-x0)/(y1-y0)
		a=a0; b=x1+(a0-y1)*d
		n=absf(a1-a0)
	if (a0<=a1):
		aa = a
		i = 0
		while(i <= n):
			out.append(Vector2i(floor(b), floor(aa)))
			out.append(Vector2i(floor(b), floor(a)))
			i += 1
			aa = a
			a += 1
			b += d
	return out

static func dda(p0 : Vector2, p1 : Vector2) -> Array[Vector2]:
	var out : Array[Vector2]
	var x0 := p0.x
	var x1 := p1.x
	var y0 := p0.y
	var y1 := p1.y
	
	var dx = abs(x0 - x1)
	var dy = abs(y0 - y1)
	
	var steps = maxf(dx, dy)
	
	var xinc = dx / steps
	var yinc = dy / steps
	
	var x := x0
	var y := y1
	
	for i in range(steps):
		out.append(Vector2(x,y))
		x = x + xinc
		y = y + yinc
	return out

# directly from https://www.redblobgames.com/grids/line-drawing.html
static func simpleLine(p0 : Vector2i, p1 : Vector2i) -> Array[Vector2i]:
	var points : Array[Vector2i] = []
	var n = diagonalDistance(p0, p1)
	
	for i in range(n):
		var t = 0.0
		if n == 0:
			t = 0.0
		else:
			t = (i / n) as float
		
		points.push_front(roundPoint(lerpPoints(p0, p1, t)))
	
	return points

static func diagonalDistance(p0 : Vector2i, p1 : Vector2i) -> float:
	var dx = p1.x - p0.x
	var dy = p1.y - p0.y
	return max(abs(dx), abs(dy))

static func roundPoint(p : Vector2i) -> Vector2i:
	return Vector2i(round(p.x), round(p.y))

static func lerpPoints(p0 : Vector2i, p1 : Vector2i, t : float) -> Vector2i:
	return Vector2i(lerpf(p0.x, p1.x, t), lerpf(p0.y, p1.y, t))
