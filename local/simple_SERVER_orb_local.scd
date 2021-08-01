/*

simple_SERVER.sc

- uses two sources for each access point (connected system)
- control azimuth and elevation of each source via OSC

- needs SC-HOA library installed

Henrik von Coler
2021-06-09

*/


/////////////////////////////////////////////////////////////////////////////////
// Server & Setup
/////////////////////////////////////////////////////////////////////////////////

// some server parameters
s.options.device               = "sprawl_SERVER";
s.options.device               = "ASIO : ASIO4ALL v2"
s.options.device               = "MME : Kopfhörer (Realtek USB Audio)"
s.options.numInputBusChannels  = 32;
s.options.numOutputBusChannels = 2;
s.options.maxLogins            = 4;
s.options.bindAddress          = "0.0.0.0";
s.options.memSize              = 250000; //increasing real time memory for the delay

s.options.device
// maximum number of access points to be used
~nSystems  = 16;

// number of in/out channels per access point (and jacktrip connection)
~nChannels = 2;

// two sources for each system
~nSources  = ~nChannels*~nSystems;

// HOA parameters
~hoa_order      = 4;
~n_hoa_channels = pow(~hoa_order + 1.0 ,2.0).asInteger;
s.quit;
s.boot;
(
s.waitForBoot({

	/////////////////////////////////////////////////////////////////////////////////
	// Synthdefs: 3rd oder encoder and decoder
	/////////////////////////////////////////////////////////////////////////////////

	SynthDef(\hoa_mono_encoder,
		{
			|
			in_bus     = nil, // audio input bus index
			out_bus    = nil, // audio output bus index
			//
			azim    = 0,
			elev    = 0
			|

			var sound = In.ar(in_bus);
			var bform = HOASphericalHarmonics.coefN3D(~hoa_order, azim, elev) * sound;

			Out.ar(out_bus, bform);

	}).add;

	// load HOA stuff for binaural decoder
	HOABinaural.loadbinauralIRs(s);
	s.sync;

	SynthDef(\hoa_binaural_decoder,
		{
			|
			in_bus  = nil, // audio input bus index
			out_bus = nil  // audio output bus index
			|

			var sig = HOABinaural.ar(~hoa_order, In.ar(in_bus,~n_hoa_channels));
			Out.ar(out_bus, sig/~nSources);

	}).add;
	s.sync;
	/*SynthDef(\flaechendelay, {|samplelen=0.3, delaytime=0.5,fb=1.0,wet=0.5, tempo=120, in_bus=nil, out_bus=nil|
		var sig,env,grain,delay;
		sig = In.ar(in_bus,1);
		delay=Greyhole.ar(sig);
		Out.ar(out_bus,wet*delay+(1-wet)*sig);
	}).add;*/

	SynthDef(\flaechendelay, {|samplelen=0.2, delaytime=0.5,fb=1.0,wet=0.8, tempo=120, in_bus=nil, out_bus=nil|
		var sig = In.ar(in_bus,1);
		var env=Decay2.ar(Impulse.ar(1/(4*delaytime)),0.02,samplelen);
		var grain=env*sig;
		var delay=CombL.ar(grain,2*samplelen,delaytime,fb);
		Out.ar(out_bus,LeakDC.ar(delay*wet+((1-wet)*sig)));
	}).add;
	s.sync;
	/*SynthDef(\flaechendelay, {|samplelen=0.3, delaytime=0.2,fb=1.0, tempo=120|
	Out.ar(~eff_bus,LeakDC.ar(CombL.ar(Decay2.ar(Impulse.ar(1/(4*delaytime)),0.02,samplelen)*In.ar(~sig_bus,2),2*samplelen,delaytime,fb)))}).add;
*/

	/////////////////////////////////////////////////////////////////////////////////
	// Encoders & Decoder
	/////////////////////////////////////////////////////////////////////////////////

	// audio bus for the encoded ambisonics signal
	~sig_BUS       = Bus.audio(s, ~nSources);
	~ambi_BUS      = Bus.audio(s, ~n_hoa_channels);

	// group for all encoders
	~encoder_GROUP = Group.new(s);
	s.sync;

	// add an encoder for each source
	~binaural_encoders = Array.fill(~nSources,	{arg i;

		Synth(\hoa_mono_encoder,
			[
				\in_bus,     ~sig_BUS.index+i,
				\out_bus,    ~ambi_BUS.index,
			],
			target: ~encoder_GROUP);

	});
	s.sync;

	// add one decoder after the encoder group
	~decoder = Synth.after(~encoder_GROUP, \hoa_binaural_decoder,
		[
			\in_bus,  ~ambi_BUS.index,
			\out_bus, 0,
	]);
	s.sync;
	//add a Delay for each source
	~delays=Array.fill(~nSources,	{arg i;

		Synth(\flaechendelay,
			[
				\in_bus,     s.options.numOutputBusChannels + i,
				\out_bus,    ~sig_BUS.index+i,
			]);

	});
	s.sync;
	/////////////////////////////////////////////////////////////////////////////////
	// Control
	/////////////////////////////////////////////////////////////////////////////////

	// create control buses for angle and delay parameters
	~azim_BUS = Bus.control(s,~nSources);
	~elev_BUS = Bus.control(s,~nSources);
	~wet_BUS  = Bus.control(s,~nSources);
	~samplelen_BUS  = Bus.control(s,~nSources);
	~delaytime_BUS  = Bus.control(s,~nSources);
	~fb_BUS  = Bus.control(s,~nSources);

	// map buses to encoder parameters
	~binaural_encoders.do({arg e, i; e.map(\azim, ~azim_BUS.index+i,\elev, ~elev_BUS.index+i)});
	~delays.do({arg e, i;
		e.map(\wet, ~wet_BUS.index+i,\samplelen, ~samplelen_BUS.index+i,\samplelen, ~samplelen_BUS.index+i,\delaytime, ~delaytime_BUS.index+i,\fb, ~fb_BUS.index+i)});

	s.sync;
	// OSC listener for azimuth
	OSCdef('azim',
		{
			arg msg, time, addr, recvPort;
			var azim = msg[2];
			~azim_BUS.setAt(msg[1],azim);
	}, '/source/azim');

	// OSC listener for elevation
	OSCdef('elev',
		{
			arg msg, time, addr, recvPort;
			var elev = msg[2];
			~elev_BUS.setAt(msg[1],elev);
	}, '/source/elev');
	OSCdef('samplelen',
		{
			arg msg, time, addr, recvPort;
			var samplelen = msg[2];
			~samplelen_BUS.setAt(msg[1],samplelen);
	}, '/source/samplelen');
	OSCdef('wet',
		{
			arg msg, time, addr, recvPort;
			var wet = msg[2];
			~wet_BUS.setAt(msg[1],wet);
	}, '/source/wet');
	OSCdef('delaytime',
		{
			arg msg, time, addr, recvPort;
			var delaytime = msg[2];
			~delaytime_BUS.setAt(msg[1],delaytime);
	}, '/source/delaytime');
	OSCdef('fb',
		{
			arg msg, time, addr, recvPort;
			var fb = msg[2];
			~fb_BUS.setAt(msg[1],fb);
	}, '/source/fb');

});
)
s.quit;
s.scope(40);

~sig_BUS.scope;
~test={Out.ar(2,SinOsc.ar(100,pi,1))}.play;
~test2={Out.ar(4,SinOsc.ar(200,0,1))}.play;
~test3={Out.ar(6,SinOsc.ar(300,0,1))}.play;
~test4={Out.ar(8,SinOsc.ar(400,0,1))}.play;
~test5={Out.ar(10,SinOsc.ar(500,0,1))}.play;
~test6={Out.ar(12,SinOsc.ar(600,0,1))}.play;
~test7={Out.ar(14,SinOsc.ar(700,0,1))}.play;
~test8={Out.ar(16,SinOsc.ar(800,0,1))}.play;
~test.free;~test2.free;~test3.free;~test4.free;~test5.free;~test6.free;~test7.free;~test8.free;

~delaytime_BUS.scope;
~delaytime={Out.kr(~delaytime_BUS,0.4!32)}.play;
~delaytime.free;
~fb_BUS.scope;
~fb={Out.kr(~fb_BUS,1!32)}.play;
~fb.free;
~samplelen_BUS.scope;
~samplelen={Out.kr(~samplelen_BUS,0.2!32)}.play;
~samplelen.free;
~tempo_BUS.scope;
~tempo={Out.kr(~tempo_BUS,120!32)}.play;
~tempo.free;
~wet_BUS.scope;
~wet0={Out.kr(~wet_BUS,0!32)}.play;
~wet={Out.kr(~wet_BUS,1!32)}.play;
~wet.free;

~azim_BUS.scope;
32.do{arg i; ~delays[i].set(\delaytime, 0.1);}
32.do{arg i; ~delays[i].set(\samplelen, 0.4);}
32.do{arg i; ~delays[i].set(\wet, 1);}
32.do{arg i; ~delays[i].set(\tempo, 140);}
32.do{arg i; ~delays[i].set(\fb, 0.5);}

//PANNING
//sources get placed on the sphere with equal distances and rotate on moving circles 'spirals'
~pan={var phase;
	phase = Array.fill(~nSources,{arg i; 2*pi/~nSources*(i-(i%2))});
	Out.kr(~azim_BUS,LFSaw.kr(0.3,phase,pi));
	Out.kr(~elev_BUS,LFSaw.kr(0.32,phase,pi));
};

~pan3=~pan.play;
~pan3.free;
~pan2={Out.kr(~azim_BUS,LFSaw.kr(1,0,pi)!~nSources)}.play;
~pan2.free;

s.plotTree;
s.scope(224);

w=Window("Scopes",Rect(100,100,800,800)).front;
w.view.decorator = FlowLayout(w.view.bounds);
a=Stethoscope.new(s,~n_hoa_channels, ~ambi_BUS.index, rate:'audio',view:w.view).size;
b=Stethoscope.new(s,~nSources, ~elev_BUS.index, rate:'control',view:w.view).size;
c=Stethoscope.new(s,~nSources, ~azim_BUS.index, rate:'control',view:w.view).size;
d=Stethoscope.new(s,~nSources, ~wet_BUS.index, rate:'control',view:w.view).size;
f=Stethoscope.new(s,~nSources, ~fb_BUS.index, rate:'control',view:w.view).size;
g=Stethoscope.new(s,~nSources, ~delaytime_BUS.index, rate:'control',view:w.view).size;
h=Stethoscope.new(s,~nSources, ~samplelen_BUS.index, rate:'control',view:w.view).size;
i=Stethoscope.new(s,~nSources, ~tempo_BUS.index, rate:'control',view:w.view).size;
w.onClose = { a.free;b.free; c.free; d.free; e.free; f.free; g.free; h.free; i.free }; // don't forget this
w.front;



{CombN.ar(Decay2.ar(Impulse.ar(1/(4*0.3)),0.02,0.1)*SinOsc.ar(100,pi,1),2,0.3,3)}.plot(2.5)
{EnvGen.kr(Env.adsr(0.03,0.5,0.9,0.1,1),Impulse.kr(0.8))}.plot(2)
{ LFPulse.ar(Line.kr(100, 800, 0.1)) }.plot(0.1);


{SinOsc.ar(100,pi,1)}.plot(1)
{
    CombN.ar(
        SinOsc.ar(500.rrand(1000), 0, 0.2) * Line.kr(1, 0, 0.1),
        0.3,
        0.25,
        6
    )
}.scope;