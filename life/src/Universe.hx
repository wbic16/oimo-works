import muun.la.Vec4;

class Universe {
	public var refLevel:Level;

	final sampler:Sampler;

	var camX:Float;
	var camY:Float;
	var camZ:Float;
	var camHX:Float;
	var camHY:Float;
	var camHZ:Float;
	var camAspect:Float;
	var timeFract:Float;

	public function new(sampler:Sampler, aspect:Float) {
		this.sampler = sampler;
		refLevel = Level.generateRandomLevel(sampler);
		camX = 0.5;
		camY = 0.5;
		camZ = 0.5;
		camHX = 0.5;
		camHY = camHX / aspect;
		camHZ = camHX / aspect;
		camAspect = aspect;
		timeFract = 0;
	}

	public function cameraWidth():Float {
		return (2 * camHX) + (0.5 * camHZ);
	}

	public function cameraHeight():Float {
		return (2 * camHY) + (0.5 * camHZ);
	}

	public function setCameraAspect(aspect:Float):Void {
		camAspect = aspect;
		camHY = camHX / camAspect;
		camHZ = camHX / camAspect;
	}

	public function translateCamera(tx:Float, ty:Float, tz:Float):Void {
		camX += 2 * camHX * tx;
		camY += 2 * camHY * ty;
		camZ += 2 * camHZ * tz;
		normalizeTranslation();
	}

	public function scaleCamera(scale:Float):Void {
		camHX *= scale;
		camHY = camHX / camAspect;
		camHZ = camHX / camAspect;
	}

	function normalizeTranslation():Void {
		final ix = Math.floor(camX);
		final iy = Math.floor(camY);
		if (ix != 0 || iy != 0) {
			camX -= ix;
			camY -= iy;
			refLevel.translate(ix, iy);
			trace(refLevel.toString());
		}
	}

	public function normalizeZoom(resolutionX:Float):Void {
		var normalized = false;
		while (resolutionX / (2 * camHX * 2048) < 2) {
			goUp();
			normalized = true;
		}
		while (resolutionX / (2 * camHX * 2048 * 2048) > 2) {
			goDown();
			normalized = true;
		}
		if (normalized)
			trace(refLevel.toString());
	}

	public function getViewInfo(resX:Float, resY:Float, resZ:Float):{
		visibleTiles:Array<Array<Array<Int>>>,
		cameraBounds:Array<Float>,
		rawCameraBounds:Array<Float>
	} {
		final marginW = 2 * camHX / resX;
		final marginH = 2 * camHY / resY;
		final marginZ = 2 * camHZ / resZ;
		final hw = camHX + marginW;
		final hh = camHY + marginH;
		final hz = camHZ + marginZ;
		final minX = Math.floor((camX - hw) * 4);
		final maxX = Math.floor((camX + hw) * 4);
		final minY = Math.floor((camY - hh) * 4);
		final maxY = Math.floor((camY + hh) * 4);
		final minZ = Math.floor((camZ - hz) * 4);
		final maxZ = Math.floor((camZ + hz) * 4);
		final w = maxX - minX + 1;
		final h = maxY - minY + 1;
		final z = maxZ - minZ + 1;
		assert(w <= 16 && h <= 16 && z <= 16);
		final res = [for (z in 0..z) [for (y in 0...h) [for (x in 0...w) [0, 0, 0]]]];
		final time = refLevel.time;
		for (z in minZ...maxZ + 1) {
			for (y in minY...maxY + 1) {
				for (x in minX...maxX + 1) {
					final pattern = refLevel.getPatternOfCell(x >> 2, y >> 2, z >> 2);
					final tile = sampler.getTile(time, pattern, x & 3, y & 3, z & 3);
					final ptile = sampler.getTile(time - 1, pattern, x & 3, y & 3, z & 3);
					final iy = y - minY;
					final ix = x - minX;
					final iz = z - minZ;
					res[iz][iy][ix][0] = tile;
					res[iz][iy][ix][1] = ptile;
				}
			}
		}
		final offX = minX / 4;
		final offY = minY / 4;
		final offZ = minZ / 4;
		return {
			visibleTiles: res,
			cameraBounds: [camX - camHX - offX, camY - camHY - offY, camZ - camHZ - offZ, camX + camHX - offX, camY + camHY - offY, camZ + camHZ - offZ],
			rawCameraBounds: [camX - camHX, camY - camHY, camZ - camHZ, camX + camHX, camY + camHY, camZ + camHZ]
		};
	}

	public function step(speedCoeff:Float):Void {
		final speed = speedCoeff * Math.pow(Main.PERIOD, Math.log(max(camHX, camHY)) / Math.log(2048)) * 50;
		timeFract += speed;
		final delta = Math.floor(timeFract);
		if (delta != 0) {
			timeFract -= delta;
			if (refLevel.forward(delta))
				trace(refLevel.toString());
		}
	}

	public function getTimeFract():Int {
		return Std.int(Main.PERIOD * timeFract);
	}

	function goUp():Void {
		camX += refLevel.posX;
		camY += refLevel.posY;
		camZ += refLevel.posZ;
		camX /= 2048;
		camY /= 2048;
		camZ /= 2048;
		camHX /= 2048;
		camHY /= 2048;
		camHZ /= 2048;
		timeFract = refLevel.time / Main.PERIOD;
		refLevel = refLevel.getParent();
		trace("going up");
	}

	function goDown():Void {
		camX *= 2048;
		camY *= 2048;
		camX += (Math.random() * 2 - 1) * 1e-9;
		camY += (Math.random() * 2 - 1) * 1e-9;
		camHX *= 2048;
		camHY *= 2048;
		camHZ *= 2048;
		final posX = Math.floor(camX);
		final posY = Math.floor(camY);
		final posZ = Math.floor(camZ);
		camX -= posX;
		camY -= posY;
		camZ -= posZ;
		refLevel = refLevel.makeSubLevel(posX, posY, posZ, Std.int(timeFract * Main.PERIOD));
		timeFract = Main.TRANSITION_END / Main.PERIOD;
		trace("going down");
	}
}
