
/////////////////////////////////////////////////////////
(
// --- 1. SETUP INIZIALE E PERCORSI ---
var presetDir = Document.current.dir +/+ "syn";

// Crea la cartella 'syn' se non esiste
if(File.exists(presetDir).not) {
	"Creo la cartella syn...".postln;
	File.mkdir(presetDir);
};

// Inizializzazione parametri (Default)
~pParams = ~pParams ?? ( );
[
	[\ampGlobal, 0.5], [\wave, 0], [\detune, 0.002],
	[\cutoff, 2000], [\rq, 1.0],
	[\delayTime, 0.2], [\decayTime, 1.5], [\revMix, 0.2], [\revRoom, 0.4],
	// ADSRs
	[\aAtk, 0.01], [\aDec, 0.3], [\aSus, 0.5], [\aRel, 0.2],
	[\aAtkCurve, -4], [\aDecCurve, -4], [\aRelCurve, -4],
	[\fAtk, 0.1], [\fDec, 0.2], [\fSus, 0.3], [\fRel, 0.5], [\fAmt, 2000],
	[\fAtkCurve, -4], [\fDecCurve, -4], [\fRelCurve, -4],
	[\vAtk, 0.5], [\vDec, 0.1], [\vSus, 0.8], [\vRel, 0.5], [\vRate, 6], [\vDepth, 0.02],
	[\vAtkCurve, -4], [\vDecCurve, -4], [\vRelCurve, -4]
].do({|pair| if(~pParams[pair[0]].isNil) { ~pParams[pair[0]] = pair[1] } });


~openSynthControls = {
	var win, makeAdsrView, refreshGUI, scanPresets;
	var popPresets, txtName, btnSave;
	var uiRef = Dictionary.new; // Qui salviamo i riferimenti ai Knob per aggiornarli
	var adsrUpdaters = List.new; // Qui salviamo le funzioni per ridisegnare gli ADSR

	// Variabili temporanee per i controlli
	var menuWave, knobDetune, knobCutoff, knobRq, knobAmp;
	var knobDelayTime, knobDecayTime, knobRevMix, knobRevRoom;
	var knobFAmt, knobVRate, knobVDepth;

	win = Window("Synth Master Controller", Rect(50, 50, 520, 550)).front;

	// --- FUNZIONI DI SISTEMA ---

	// 1. Scansione cartella
	scanPresets = {
		var files = PathName(presetDir).files;
		var names = files.select({|f| f.extension == "syn"}).collect({|f| f.fileNameWithoutExtension});
		names;
	};

	// 2. Aggiornamento GUI
	refreshGUI = {
		// Aggiorna i Knob standard leggendo da ~pParams
		if(uiRef[\wave].notNil) { uiRef[\wave].value = ~pParams[\wave] };
		if(uiRef[\detune].notNil) { uiRef[\detune].value = ~pParams[\detune].linlin(0, 0.02, 0, 1) };
		if(uiRef[\cutoff].notNil) { uiRef[\cutoff].value = ~pParams[\cutoff].explin(20, 10000, 0, 1) };
		if(uiRef[\rq].notNil) { uiRef[\rq].value = ~pParams[\rq].linlin(0.05, 1.0, 1, 0) };
		if(uiRef[\ampGlobal].notNil) { uiRef[\ampGlobal].value = ~pParams[\ampGlobal] };

		if(uiRef[\delayTime].notNil) { uiRef[\delayTime].value = ~pParams[\delayTime].linlin(0.05, 0.5, 0, 1) };
		if(uiRef[\decayTime].notNil) { uiRef[\decayTime].value = ~pParams[\decayTime].linlin(0, 5, 0, 1) };
		if(uiRef[\revMix].notNil) { uiRef[\revMix].value = ~pParams[\revMix] };
		if(uiRef[\revRoom].notNil) { uiRef[\revRoom].value = ~pParams[\revRoom] };

		if(uiRef[\fAmt].notNil) { uiRef[\fAmt].value = ~pParams[\fAmt] / 5000 };
		if(uiRef[\vRate].notNil) { uiRef[\vRate].value = ~pParams[\vRate] / 15 };
		if(uiRef[\vDepth].notNil) { uiRef[\vDepth].value = ~pParams[\vDepth] / 0.1 };

		// Aggiorna gli ADSR
		adsrUpdaters.do({ |func| func.value });
	};

	// --- HELPER GRAFICO ADSR ---
	makeAdsrView = { |label, prefix|
		var envView, updateEnvShape, mainLayout;
		var kAtk, kDec, kRel;

		updateEnvShape = {
			var newEnv = Env.adsr(
				~pParams[(prefix++"Atk").asSymbol],
				~pParams[(prefix++"Dec").asSymbol],
				~pParams[(prefix++"Sus").asSymbol],
				~pParams[(prefix++"Rel").asSymbol],
				1.0,
				[
					~pParams[(prefix++"AtkCurve").asSymbol],
					~pParams[(prefix++"DecCurve").asSymbol],
					~pParams[(prefix++"RelCurve").asSymbol]
				]
			);
			envView.setEnv(newEnv);
			if(kAtk.notNil) { kAtk.value = ~pParams[(prefix++"AtkCurve").asSymbol].linlin(-8, 8, 0, 1) };
			if(kDec.notNil) { kDec.value = ~pParams[(prefix++"DecCurve").asSymbol].linlin(-8, 8, 0, 1) };
			if(kRel.notNil) { kRel.value = ~pParams[(prefix++"RelCurve").asSymbol].linlin(-8, 8, 0, 1) };
		};

		adsrUpdaters.add(updateEnvShape);

		mainLayout = VLayout(
			StaticText().string_(label).stringColor_(Color.white).align_(\center).font_(Font(bold:true)),
			envView = EnvelopeView()
				.keepHorizontalOrder_(true)
				.background_(Color.grey(0.9))
				.action_({ |v|
					var val = v.value;
					var x = val[0]; var y = val[1];
					if(x.notNil && { x.size >= 4 }) {
						~pParams[(prefix++"Atk").asSymbol] = (x[1] - x[0]).max(0.001);
						~pParams[(prefix++"Dec").asSymbol] = (x[2] - x[1]).max(0.001);
						~pParams[(prefix++"Sus").asSymbol] = y[2];
						~pParams[(prefix++"Rel").asSymbol] = (x[3] - x[2]).max(0.001);
						{ updateEnvShape.value; }.defer(0.05);
					};
				}),
			HLayout(
				VLayout(StaticText().string_("C.Atk").font_(Font(size:10)).align_(\center),
					kAtk = Knob().mode_(\vert).action_({|k| ~pParams[(prefix++"AtkCurve").asSymbol] = k.value.linlin(0, 1, -8, 8); updateEnvShape.value; })),
				VLayout(StaticText().string_("C.Dec").font_(Font(size:10)).align_(\center),
					kDec = Knob().mode_(\vert).action_({|k| ~pParams[(prefix++"DecCurve").asSymbol] = k.value.linlin(0, 1, -8, 8); updateEnvShape.value; })),
				VLayout(StaticText().string_("C.Rel").font_(Font(size:10)).align_(\center),
					kRel = Knob().mode_(\vert).action_({|k| ~pParams[(prefix++"RelCurve").asSymbol] = k.value.linlin(0, 1, -8, 8); updateEnvShape.value; }))
			).spacing_(2)
		);
		{ updateEnvShape.value; }.defer(0.1);
		mainLayout;
	};

	// --- CREAZIONE CONTROLLI (Prima del Layout!) ---

	// Oscillatori
	menuWave = PopUpMenu().items_(["Saw", "Square", "Triangle", "Sine"])
		.value_(~pParams[\wave])
		.action_({ |m| ~pParams[\wave] = m.value; });
	uiRef[\wave] = menuWave; // Assegnazione sicura

	knobDetune = Knob().value_(~pParams[\detune].linlin(0, 0.02, 0, 1))
		.action_({ |k| ~pParams[\detune] = k.value.linlin(0, 1, 0, 0.02); });
	uiRef[\detune] = knobDetune;

	knobCutoff = Knob().value_(~pParams[\cutoff].linlin(20, 10000, 0, 1))
		.action_({ |k| ~pParams[\cutoff] = k.value.linexp(0, 1, 20, 10000); });
	uiRef[\cutoff] = knobCutoff;

	knobRq = Knob().value_(~pParams[\rq].linlin(0.05, 1.0, 1, 0))
		.action_({ |k| ~pParams[\rq] = k.value.linlin(0, 1, 1.0, 0.05); });
	uiRef[\rq] = knobRq;

	knobAmp = Knob().value_(~pParams[\ampGlobal]).action_({ |k| ~pParams[\ampGlobal] = k.value; });
	uiRef[\ampGlobal] = knobAmp;

	// Effetti
	knobDelayTime = Knob().value_(~pParams[\delayTime].linlin(0.05, 0.5, 0, 1))
		.action_({|k| ~pParams[\delayTime] = k.value.linlin(0,1,0.05,0.5)});
	uiRef[\delayTime] = knobDelayTime;

	knobDecayTime = Knob().value_(~pParams[\decayTime].linlin(0, 5, 0, 1))
		.action_({|k| ~pParams[\decayTime] = k.value.linlin(0,1,0,5)});
	uiRef[\decayTime] = knobDecayTime;

	knobRevMix = Knob().value_(~pParams[\revMix]).action_({|k| ~pParams[\revMix] = k.value});
	uiRef[\revMix] = knobRevMix;

	knobRevRoom = Knob().value_(~pParams[\revRoom]).action_({|k| ~pParams[\revRoom] = k.value});
	uiRef[\revRoom] = knobRevRoom;

	// Modulazioni
	knobFAmt = Knob().value_(~pParams[\fAmt]/5000).action_({|k| ~pParams[\fAmt] = k.value * 5000 });
	uiRef[\fAmt] = knobFAmt;

	knobVRate = Knob().value_(~pParams[\vRate]/15).action_({|k| ~pParams[\vRate] = k.value * 15 });
	uiRef[\vRate] = knobVRate;

	knobVDepth = Knob().value_(~pParams[\vDepth]/0.1).action_({|k| ~pParams[\vDepth] = k.value * 0.1 });
	uiRef[\vDepth] = knobVDepth;


	// --- COSTRUZIONE LAYOUT FINALE ---

	win.layout = VLayout(
		// HEADER PRESETS
		View().background_(Color.grey(0.2)).layout_(
			HLayout(
				StaticText().string_("PRESET:").stringColor_(Color.white).font_(Font(bold:true)),
				popPresets = PopUpMenu().items_(scanPresets.value)
					.action_({ |menu|
						var filename = menu.item;
						var fullPath = presetDir +/+ filename ++ ".syn";
						if(File.exists(fullPath)) {
							var loadedParams = Object.readArchive(fullPath);
							if(loadedParams.notNil) {
								~pParams = loadedParams;
								txtName.string_(filename);
								refreshGUI.value; // Qui usiamo uiRef per aggiornare le manopole
							};
						};
					}),
				txtName = TextField().string_("Init").minWidth_(100),
				btnSave = Button().states_([["SAVE", Color.black, Color.green(0.8)]])
					.action_({
						var name = txtName.string;
						if(name.size > 0) {
							var path = presetDir +/+ name ++ ".syn";
							~pParams.writeArchive(path);
							popPresets.items_(scanPresets.value);
							popPresets.value_(popPresets.items.indexOfEqual(name) ?? 0);
						};
					})
			).margins_(5)
		),

		// OSCILLATORI E MASTER
		HLayout(
			VLayout(
				StaticText().string_("OSCILLATOR").align_(\center).font_(Font(bold:true)),
				menuWave, // Inseriamo la variabile pulita, NON uiRef[...]
				nil
			),
			VLayout(StaticText().string_("Detune").align_(\center).font_(Font(bold:true)), knobDetune),
			VLayout(
				StaticText().string_("FILTER").align_(\center).font_(Font(bold:true)),
				HLayout(
					VLayout(StaticText().string_("Cutoff").align_(\center), knobCutoff),
					VLayout(StaticText().string_("Res (RQ)"), knobRq)
				)
			),
			VLayout(StaticText().string_("MASTER").align_(\center).font_(Font(bold:true)), knobAmp)
		).spacing_(5),

		// INVIIUPPI (ADSR)
		View().background_(Color.grey(0.3, 0.5)).layout_(
			VLayout(
				HLayout(
					makeAdsrView.("AMP ADSR", "a"),
					makeAdsrView.("FILT ADSR", "f"),
					makeAdsrView.("VIB ADSR", "v")
				).spacing_(20)
			)
		),

		// EFFETTI E MODULAZIONI
		HLayout(
			VLayout(
				StaticText().string_("DELAY").align_(\center).font_(Font(bold:true)),
				HLayout(
					VLayout(StaticText().string_("Time").align_(\center), knobDelayTime),
					VLayout(StaticText().string_("Feedb").align_(\center), knobDecayTime)
				)
			),
			VLayout(
				StaticText().string_("REVERB").align_(\center).font_(Font(bold:true)),
				HLayout(
					VLayout(StaticText().string_("Mix").align_(\center), knobRevMix),
					VLayout(StaticText().string_("Room").align_(\center), knobRevRoom)
				)
			),
			VLayout(
				StaticText().string_("MOD DEPTHS").align_(\center).font_(Font(bold:true)),
				HLayout(
					VLayout(StaticText().string_("Filt.Amt").align_(\center), knobFAmt),
					VLayout(StaticText().string_("Vib.Rate").align_(\center), knobVRate),
					VLayout(StaticText().string_("Vib.Depth").align_(\center), knobVDepth)
				)
			)
		).spacing_(5)
	).spacing_(20);

	win.alwaysOnTop = true;
};
)