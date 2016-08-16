import kha.Assets;
import haxe.ds.Vector;

class AudioApp {
    	
	var sound:kha.Sound;
	var position:Int;
	var samplesPerSecond:Int = 41000;
	var BPM = 125.0;
	var TPB:Float;
	var samplesPerBeat = 0;
		
	var ct = 0.0;
	var updateTime = 0.0;
	var frequencyPowers:Vector<Float>;
	var frequencies = [
		Notes.G0,
		Notes.C4,
		Notes.G4,
		Notes.C5
	];
	

	var playing = false;
	
	public function new() {
		frequencyPowers = new Vector<Float>(frequencies.length);
		setBPM(120.0);
		
		kha.System.notifyOnRender(render);
		
        initSound();
	}
	
	function setBPM(bpm:Float){
		BPM = bpm;
		TPB = 60.0 / bpm;
		samplesPerBeat = Std.int(samplesPerSecond * 60 / bpm);
	}
	
	var cLen = 0.0;
	
	function initSound() {
		echoBuf = new Vector<Float>(echo);
		for(i in 0...echoBuf.length)  {
			echoBuf[i] = 0.0;
		}
		
		position = 0;
		playing = true;
		kha.audio2.Audio.audioCallback = stream;
	}
	
	var echo = 400;
	var echoBuf:Vector<Float>;
	var echoTicker = 0;
    
	function fmBass(tPos:Int, freq:Float):Float {
		var s = tPos / samplesPerSecond * 2.0;
		s *= freq * Math.PI;
		
		var a1 = 0.2;
		var w1 = 1.0;
		
		var a2 = 0.0002;
		var w2 = 0.01;
		
		var A2 = a2 * Math.cos(s * w2);
		var A1 = (a1) * Math.cos(s * (A2 +  w1));
		return A1;
		return Math.cos(s * freq * Math.PI) * 0.8 + Math.cos(s * freq * Math.PI * 1.2)* 0.5 + Math.cos(s * Math.PI * freq * 2.3) * 0.2;
	}
	
	function sin(tPos:Int, freq:Float):Float {
		var s = tPos / samplesPerSecond;
		return Math.cos(s * Math.max(0.0, freq) * Math.PI * 2.0);
	}
	
	function saw(tPos:Int, freq:Float):Float {
		var s = tPos / samplesPerSecond;
		var waveTime = 1.0 / Math.max(0.00001, freq);
		return  Math.max(-1.0, Math.min(1.0, (1.0 - ((s % waveTime) / waveTime)) * 2.0 - 1.0));
	}
	
	function pulse(tPos:Int, freq:Float, ratio:Float = 0.5) {
		var s = tPos / samplesPerSecond;
		var waveTime = 1.0 / freq;
		var r = s % waveTime;
		
		r /= waveTime;
		
		return (r < ratio) ? -1.0 : 1.0;
	}
	
	function square(tPos:Int, freq:Float):Float {
		var s = tPos / samplesPerSecond * 2.0;
		freq = 1.0 / freq;
		
		if(s  % (freq * 2.0) < freq) {
			return -1.0;
		}
		
		return 1.0;
	}
	
	function noise(tPos:Int) {
		return Math.random() * 2.0 - 1;
	}

	var arps = [
		[Notes.G3, Notes.AS4, Notes.D4],
		[Notes.G3, Notes.AS4, Notes.DS4],
		[Notes.F3, Notes.A4, Notes.C4],
		[Notes.F3, Notes.A4, Notes.D4],
		[Notes.DS3, Notes.G4, Notes.C4],
		[Notes.DS3, Notes.G4, Notes.DS4],
		[Notes.DS3, Notes.FS3, Notes.C4],
	];
	
	var ratios = [0.7, 0.5, 0.4, 0.3, 0.2];
	
	var audioBuf:Vector<Float>;
	var fadeInTime = 4.0;
	
	var bassHits = [1, 1, 0, 0, 1, 1, 0, 0, 1, 0, 1, 0];
	var bassSections = [Notes.G2, Notes.AS2, Notes.F2, Notes.F2, Notes.DS2, Notes.C2, Notes.D2];
	
	var bass = [Notes.G2, Notes.G3, Notes.G3, Notes.G2, Notes.G3, Notes.G3,Notes.G2, Notes.G3,
				Notes.DS2, Notes.DS3,Notes.DS2, Notes.DS3,Notes.DS2, Notes.DS3,Notes.DS2, Notes.DS3,
				Notes.C2, Notes.C3, Notes.C3, Notes.C2, Notes.C3, Notes.C3, Notes.C2, Notes.C3,
				Notes.D2, Notes.D3, Notes.D3, Notes.D2, Notes.D3, Notes.D3, Notes.D2, Notes.D3,
				Notes.G2, Notes.E3, Notes.G3, Notes.G2, Notes.E3, Notes.G3, Notes.G2, Notes.E3];

	function stream(samples:Int, buf:kha.audio2.Buffer) {
		samplesPerBeat = Std.int(samplesPerSecond * 60 / BPM);
		samplesPerSecond = buf.samplesPerSecond;
		
		var tickLen = 400;
		
		buf.writeLocation = 0;
		buf.readLocation = 0;	
		audioBuf = buf.data;
	
		for(i in 0...samples) {
			var tPos = (position + i) >> 1;
			
			var seconds = tPos / samplesPerSecond;
			var beats = tPos / samplesPerBeat;
			
			var sixtyfours:Int = Std.int(tPos / (samplesPerBeat >> 4));
			var thirtytwos:Int = Std.int(tPos / (samplesPerBeat >> 3));
			var sixteenths:Int = Std.int(tPos / (samplesPerBeat >> 2));
			
			var sixtyfoursRatio = (tPos / (samplesPerBeat >> 4)) % 1;
			
            buf.data[i] = 0;
           
            playing = true;
            
            var section = Std.int(tPos / (samplesPerBeat * 4));
            var arp = arps[section % arps.length];
            var arpSpeed = Std.int(samplesPerBeat / 2);
            var p = tPos % arpSpeed;
            
            var volume = Math.pow(1 - (p / arpSpeed), .9);
            
            p *= arp.length;
            p = Std.int(p / arpSpeed);
            p = arp.length - 1 - p;
            
            var ratio = Std.int(tPos / (samplesPerSecond * 0.66));
            //if(thirtytwos % 2 == 1) {
            var v = Math.max(0, Math.min(1.0, Math.max(0.0, ((seconds - TPB * 7 * 4) / (TPB * fadeInTime * 0.1)))));
            buf.data[i] += saw(tPos, arp[p]) * 0.03 * v * Math.max(0.3, volume);//pulse(tPos, arp[p], ratios[ratio % ratios.length]) * 0.08 * Math.max(0.2, volume);
            //}
            //buf.data[i] -= sin(tPos, arp[p]) * 0.1 * volume;
            //buf.data[i] += sin(tPos, Notes.G3) * 0.1;jkjju
            //buf.data[i] += sin(tPos, Notes.G2) * 0.1 * Math.min(1.0, seconds / 10) * saw(tPos, Notes.G1);
            var t = (echoTicker - Std.int(samplesPerSecond * 0.1)) % echo;
            if(t < 0) {
                t += echo;
            }
            
            if(bassHits[(sixtyfours >> 1) % bassHits.length] == 1) {
                var note = bassSections[(currentBeat>>4) % bassSections.length];
                buf.data[i] += (pulse(tPos, note * ((sixtyfours) % (3) + 1), ratios[sixteenths % ratios.length]) * 0.5) * 0.1 * Math.max(0.5, 1 - sixtyfoursRatio);
            }else{
                //buf.data[i] += (sin(tPos, Notes.G1) + square(tPos, Notes.G2) * 0.5) * 0.1 * Math.min(0.5, 1 - sixtyfoursRatio);
            }
            
            buf.data[i] *= 1.6;
            buf.data[i] += echoBuf[t] * 0.5;
            
            //buf.data[i] += sin(tPos, bass[thirtytwos % bass.length]) * 0.2;
            //buf.data[i] += noise(tPos) * 0.01 * Math.sin(beats * Math.PI / 10.0);
            
            buf.data[i] *= Math.min(1.0, Math.max(0.0, (seconds / (fadeInTime * TPB))));
        
            buf.data[i] *= 0.1;     
        
            echoBuf[echoTicker] = echoBuf[echoTicker] + buf.data[i];
            echoBuf[echoTicker] *= 0.5;
                                        
            echoTicker ++;
           
            if(echoTicker >= echo) {
                echoTicker = 0;
            }
		}
	
        for(i in 0...echoBuf.length) {
			var lEch = i - 2;
			
			lEch %= echo;
			if(lEch < 0) {
				lEch += echo;
			}
			
            echoBuf[i] = echoBuf[(lEch) % echo] * 0.2 
				+ echoBuf[i] * 0.2 
				+ echoBuf[(lEch + 1) % echo] * 0.2 
				+ echoBuf[(lEch + 3) % echo] * 0.2
				+ echoBuf[(lEch + 4	) % echo] * 0.2;
		}
		
		updateTime = haxe.Timer.stamp();
		
        if(position < 0) {
			position += samples;
			if(position > 0) {
				position = 0;
			}
		}else{
			position += samples;
		}
		
		/*
		for(i in 0...i) {
			buf.data[i] = sound.uncompressedData[(position)];
			position ++;
		}
		*/
		//position += buf.data.length >> 1;
	}
	
	function goertzel(x:Vector<Float>, N:Int, frequency:Float, samplerate:Int, S:Int = 0):Float {
		var Skn:Float;
		var Skn1:Float;
		var Skn2:Float;
		
		Skn = Skn1 = Skn2 = 0;
		
		for (i in 0...N) {
			Skn2 = Skn1;
			Skn1 = Skn;
			Skn = 2 * Math.cos(2 * Math.PI * frequency / samplerate) * Skn1 - Skn2;
			if(i * 2 + S + 1 < x.length && S >= 0) {
				Skn += (x[i * 2 + S] + x[i * 2 + S + 1]) / 2.0;
			}
		}
		
		var WNk:Float = Math.exp(-2 * Math.PI * frequency/samplerate); // this one ignores complex stuff
		//float WNk = exp(-2*j*PI*k/N);
		return Math.abs(Skn - WNk*Skn1);
		return Math.abs(Math.min(1, Math.max(Skn - WNk*Skn1, -1.0)));
	}


	var currentBeat = 0;
	var startRotation = 0.0;
	var randomSize = 0.0;
	function doBeat(beat:Int){
		if(beat % 4 == 0){
			startRotation = Math.random() * Math.PI * 2;
		}
		randomSize = Math.random() * 3;
	}
	
	function render(buffer:kha.Framebuffer) {
		
		var sinceLast = haxe.Timer.stamp() - updateTime;
		var dt = Std.int(sinceLast * samplesPerSecond);
		if(audioBuf != null){
			for(i in 0...frequencyPowers.length) {
				frequencyPowers[i] = goertzel(audioBuf, 1100, frequencies[i], samplesPerSecond, dt);
			}
			var max = 1.0;
			for(i in 0...frequencyPowers.length) {
				max = Math.max(max, frequencyPowers[i]);
			}
			
			for(i in 0...frequencyPowers.length) {
				frequencyPowers[i] /= max;
			}
		}

		
		var songTime:Float = (position / samplesPerSecond / 2.0) + sinceLast;
		
		var b = buffer.g2;        
        
		if(songTime % (TPB / 4) < 0.05 && playing){
			var beat = Std.int(songTime / (TPB / 4));
			if(beat > currentBeat) {
				currentBeat = beat;
				doBeat(beat);
			}
		}
     
       
        		
        b.begin(true);
		
		b.color = kha.Color.White;
		
		var x = 0;// Math.cos(haxe.Timer.stamp()) * 100;
		var rd = Math.PI * 2 / frequencyPowers.length;
		for(i in 0...frequencyPowers.length) {
			var a = i * rd;// + startRotation;
			var c = Math.cos(a);
			var s = Math.sin(a);
			var x = buffer.width * 0.5;
			var y = buffer.height * 0.5;
			var r = 50;
			var p = frequencyPowers[i];
			b.drawLine(x + c * (r + (p * 5)), 
					   y + s * (r + (p * 5)), 
					   x + c * (r + p * 150),
					   y + s * (r + p * 150), 2 + randomSize);
		}
		
		b.end();
	}
}