/*

- uses two sources for each access point (connected system)
- control parameters via OSC

- needs SC-HOA library installed


2021-06-09

*/


/////////////////////////////////////////////////////////////////////////////////
// Server & Setup
/////////////////////////////////////////////////////////////////////////////////

// some server parameters
s.options.device               = "sprawl_SERVER";
s.options.numInputBusChannels  = 32;
s.options.numOutputBusChannels = 2;
s.options.maxLogins            = 4;
s.options.bindAddress          = "0.0.0.0";
s.options.memSize              = 250000; //increasing real time memory for the delay


// maximum number of access points to be used
~nSystems  = 16;

// number of in/out channels per access point (and jacktrip connection)
~nChannels = 2;

// two sources for each system
~nSources  = ~nChannels*~nSystems;

// HOA parameters
~hoa_order      = 3;
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
			Out.ar(out_bus, Limiter.ar(sig,1.0)); // Limiter included

	}).add;
	s.sync;
	// SynthDef of the Mono-Delay: samplelen= lenght of the sample which gets delayed [sec]
	// delaytime= time between the delayed samples [sec]
	// fb= feedback means the time for the echoes to decay by 60 decibels [sec]
	// wet= mix of the original and the delayed signal. wet=0 means original signal only, wet=1 delayed signal only
	// needs an input and output bus

	SynthDef(\flaechendelay, {|samplelen=0.2, delaytime=0.5,fb=1.0,wet=0, in_bus=nil, out_bus=nil|
		var sig = In.ar(in_bus,1); //Input signal
		var env=Decay2.kr(Impulse.kr(1/(4*delaytime)),0.02,samplelen); //Envelope for one delay grain. Beat is 4/4 --> freq = 1/(4*delaytime)
		var grain=env*sig; // One Grain on the first beat
		var delay=CombL.ar(grain,2*samplelen,delaytime,fb); // Echoing the Grain
		Out.ar(out_bus,LeakDC.ar(delay*wet+((1-wet)*sig))); // Mix with Dry Signal
	}).add;
	s.sync;


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
	// create control buses for delay parameters
	~wet_BUS  = Bus.control(s,~nSources);
	~samplelen_BUS  = Bus.control(s,~nSources);
	~delaytime_BUS  = Bus.control(s,~nSources);
	~fb_BUS  = Bus.control(s,~nSources);

	// map buses to encoder and delay parameters
	~binaural_encoders.do({arg e, i; e.map(\azim, ~azim_BUS.index+i,\elev, ~elev_BUS.index+i)});
	~delays.do({arg e, i;
		e.map(\wet, ~wet_BUS.index+i,\samplelen, ~samplelen_BUS.index+i,\samplelen, ~samplelen_BUS.index+i,\delaytime, ~delaytime_BUS.index+i,\fb, ~fb_BUS.index+i)});

	s.sync;

	/// Orbital Spatializing
	// w_azim= frequency of the azimuthal orbit
	// w_elev= frequency of the elevational orbit
	// the phase array determines the initial position on the orbits (pairwise, so each participant gets one location)
	SynthDef(\orbits, {|w_azim = 0.0, w_elev = 0.0|
		var phase = Array.fill(~nSources,{arg i; 2*pi/~nSources*(i-(i%2))});
		Out.kr(~azim_BUS,LFSaw.kr(w_azim,phase,pi));
		Out.kr(~elev_BUS,LFSaw.kr(w_elev,phase,pi));
	}).add;
	s.sync;
	//start the orbits
	~orbits=Synth(\orbits);
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

		// OSC listener for samplelength
	OSCdef('samplelen',
		{
			arg msg, time, addr, recvPort;
			var samplelen = msg[2];
			~samplelen_BUS.setAt(msg[1],samplelen);
	}, '/source/samplelen');

		// OSC listener for wetness
	OSCdef('wet',
		{
			arg msg, time, addr, recvPort;
			var wet = msg[2];
			~wet_BUS.setAt(msg[1],wet);
	}, '/source/wet');

		// OSC listener for delaytime
	OSCdef('delaytime',
		{
			arg msg, time, addr, recvPort;
			var delaytime = msg[2];
			~delaytime_BUS.setAt(msg[1],delaytime);
	}, '/source/delaytime');

		// OSC listener for feedback
	OSCdef('fb',
		{
			arg msg, time, addr, recvPort;
			var fb = msg[2];
			~fb_BUS.setAt(msg[1],fb);
	}, '/source/fb');

		// OSC listener for azimuthal frequency
	OSCdef('w_azim',
		{
			arg msg, time, addr, recvPort;
			var w_azim  = msg[2];
			~orbits.set(\w_azim, w_azim);
	}, '/source/w_azim');

		// OSC listener for elevational frequency
	OSCdef('w_elev',
		{
			arg msg, time, addr, recvPort;
			var w_elev = msg[2];
			~orbits.set(\w_elev,w_elev);
	}, '/source/w_elev');

});
)


