Platform.userExtensionDir

Quarks.install("https://github.com/florian-grond/SC-HOA")

MethodOverride.printAll

s.options.device = "ASIO : ASIO4ALL v2";
"MME : Kopfhörer (Realtek USB Audio)"

s.options.device               = "sprawl_SERVER";

ServerOptions.outDevices;
s.boot;
s.quit;

// create the Ambisonics mix bus: 4 is nice order

~order     = 4;
~nHOA      = (pow(~order+1,2)).asInteger;
~ambi_BUS  = Bus.audio(s,~nHOA);

~ambi_BUS.scope;


~sig_bus=Bus.audio(s,1);
~eff_bus=Bus.audio(s,1);
s.nodetree

// set parameters in spherical coordinates
~endoder_A.set(\azim,1.6)
~endoder_A.set(\elev,0)

~endoder_A = {arg azim=0, elev=0;
	azim=MouseX.kr(-3,3);
	elev=MouseY.kr(-1.6,1.6);
Out.ar(~ambi_BUS,HOASphericalHarmonics.coefN3D(~order,azim,elev)*In.ar(~eff_bus,1));
      }.play;

~endoder_B.set(\wr,0.2)
~endoder_B.set(\w,0.3)
~endoder_B = {arg wr=0.5, w=2;
	var azim,elev;
	azim=(1-SinOsc.kr(wr))*SinOsc.kr(1-SinOsc.kr(w),0.5pi,0.8);
	elev=(1-SinOsc.kr(wr))*Saw.kr(wr);
Out.ar(~ambi_BUS,HOASphericalHarmonics.coefN3D(~order,azim,elev)*In.ar(~eff_bus,1));
      }.play;

~endoder_C = FuncStream({arg perms=1;
	var d=Array.fill(~nHOA, {arg i; i.rand}).normalize;
	Out.ar(~ambi_BUS,d.permute(perms)*In.ar(~eff_bus,1));
});

~endoder_C = {arg ...coeff;
	Out.ar(~ambi_BUS,coeff*In.ar(~eff_bus,1));
      };

d=Array.fill(~nHOA, {arg i; i.rand}).normalize(-2,2);
d=Array.rand2(~nHOA, 2);
~endoder_C.play;
~endoder_C.set(\coeff, Array.rand2(~nHOA, 2));

HOABinaural.loadbinauralIRs(s);
~decoder = {HOABinaural.ar(~order, In.ar(~ambi_BUS,~nHOA),0,0)}.play;
~decoder.moveAfter(~endoder_A);
~decoder.moveAfter(~endoder_B);
~decoder.moveAfter(~endoder_C);

~hoa=Group.new;
~source=Group.head(s);


SynthDef(\flaechendelay, {|samplelen=0.3, delaytime=0.2,fb=1.0, tempo=120|
	Out.ar(~eff_bus,LeakDC.ar(CombL.ar(Decay2.ar(Impulse.ar(1/(4*delaytime)),0.02,samplelen)*In.ar(~sig_bus,2),2*samplelen,delaytime,fb)))}).add;

SynthDef(\signal, {Out.ar(~sig_bus, SinOsc.ar(270,0,0.1))}).add;
SynthDef(\scopeLR, {(In.ar(0)-In.ar(1)).scope;}).add;


x=Synth(\signal,target:~source);
x=Synth(\signal);
x.free;
a=Synth.after(x,\flaechendelay);
a.free;
a.set(\delaytime, 0.1)
a.set(\delaytime, 1)
a.set(\fb, -1)
a.set(\samplelen, 0.6)
a.set(\samplelen, 8)
s.scope(8);
c=4;
d.permute(c)
HOASphericalHarmonics.coefN3D(~order,0,0)



~endoder_A.group=1047;
~endoder_A.nodeID;
~decoder.group(~hoa)
~hoa.group;

~decoder.release;

//"C:/Users/vluxm/AppData/Local/SuperCollider/Help/Overviews/Methods.html"



{Out.ar(0,0.3*SinOsc.ar(270)!2)}.play;
{Out.ar(0,In.ar(~eff_bus,2))}.play;


HOABinaural.listHeadphones();

HOABinaural.headPhones.do { |item, index|
			[index, item].postln
		}

Array.fill(~nHOA, {arg i; }).normalize
{Rand(-1.5,1.5)}
a.postln;

(
// in this case a new object is returned
var y, z;
z = [1, 2, 3, 4];
y = z.insert(1, 999);
z.postln;
y.postln;
)
a = (0..10) ++ (0..10);
['a', 'b', 'c'].do({ arg item, i; [i, item].postln; });
x = [ 1.4, 2.5, 3.7];
6.do({|i| x.permute(i).postln;});

z = Pan2.ar;
z.postln;
z.source.postln;


