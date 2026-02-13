// 16.2 11/02/2026 12:30
// Super Collider 3.14.1 November 23, 2025
// DadoSoft - Italy 02/2026

// carica SynthControls e Help
~cPath = Document.current.dir;
(~cPath +/+ "SynthControls.scd").load;
(~cPath +/+ "Help.scd").load;
~cPathSeq = Document.current.dir +/+ "seq";
(

s.waitForBoot {

// --- 1. SynthDef ---
SynthDef(\pianoSynth, { |out=0, freq=440, amp=0.2, gate=1, // durata=1,
    cutoff=2000, rq=1, wave=0, detune=0.002,
    delayTime=0.2, decayTime=2, revMix=0.3, revRoom=0.5,
    aAtk=0.01, aDec=0.3, aSus=0.5, aRel=0.1,           // ADSR
	aAtkCurve= -4, aDecCurve= -4, aRelCurve= -4,       // <- Curve
    fAtk=0.01, fDec=0.3, fSus=0.5, fRel=0.1, fAmt=2000,
	fAtkCurve= -4, fDecCurve= -4, fRelCurve= -4,       // <- Curve
    vAtk=0.1, vDec=0.2, vSus=0.7, vRel=0.5, vRate=6, vDepth=0.01,
    vAtkCurve= -4, vDecCurve= -4, vRelCurve= -4 |      // <- Curve

	var aEnv, fEnv, vEnv, sig, osc1, osc2, vib;

	aEnv = EnvGen.ar(Env.adsr(aAtk, aDec, aSus, aRel, 1.0, [aAtkCurve, aDecCurve, aRelCurve]), gate, doneAction: 2);
    fEnv = EnvGen.ar(Env.adsr(fAtk, fDec, fSus, fRel, 1.0, [fAtkCurve, fDecCurve, fRelCurve]), gate);
    vEnv = EnvGen.ar(Env.adsr(vAtk, vDec, vSus, vRel, 1.0, [vAtkCurve, vDecCurve, vRelCurve]), gate);

    vib = SinOsc.kr(vRate) * (vDepth * vEnv);

    osc1 = Select.ar(wave, [
        VarSaw.ar(freq * (1 + vib), 0, 0.3),
        Pulse.ar(freq * (1 + vib), 0.5),
        LFTri.ar(freq * (1 + vib)),
        SinOsc.ar(freq * (1 + vib)) ]);

    osc2 = Select.ar(wave, [
        VarSaw.ar(freq * (1 + detune + vib), 0, 0.3),
        Pulse.ar(freq * (1 + detune + vib), 0.5),
        LFTri.ar(freq * (1 + detune + vib)),
        SinOsc.ar(freq * (1 + detune + vib)) ]);

    sig = (osc1 + (osc2 * 0.5)) * amp;
    sig = RLPF.ar(sig, (cutoff + (fEnv * fAmt)).clip(20, 20000), rq.clip(0.1, 1.0)) * aEnv;
    sig = sig + CombL.ar(sig, 0.5, delayTime, decayTime, 0.3);
    sig = FreeVerb.ar(sig, revMix, revRoom);

    Out.ar(out, Pan2.ar(sig, 0));
}).add;

};


///////////////////////////////////////////////////////////////////////////////////
// --- 2. SEQUENCE ---
~createSequence = { |notes|
    (
        list: List.new,
        _add: { |self, note|
            var n = note.copy;
            n[\beat] = (n[\beat] ?? 0).max(0);
            n[\midinote] = (n[\midinote] ?? 60).clip(0, 127);
            n[\sustain] = (n[\sustain] ?? 1).max(0.01);
            n[\amp] = (n[\amp] ?? 0.8).clip(0, 1); // <- default a 0.8
            self.list.add(n);
            n;
        },
        _remove: { |self, note| self.list.remove(note) }
    );
};

////////////////////////////////////////////////////////////////////////////////
// --- 3. EDITOR ---
~openPianoRoll = { |sequence|
	var titolo = "DadoSoft - Edit PianoRoll 16.2 -";

	var playNote = { |note|
      var p = ~pParams;
      var beatDur = 60 / bpm; // Trasforma i BPM in durata del singolo beat
        (
        instrument: \pianoSynth,
        midinote: note[\midinote],

        // --- LOGICA DEL TEMPO ---
        // Calcoliamo la durata del GATE in secondi.
        // Moltiplichiamo per 0.9 per lasciare un piccolo "stacco" (legato)
        // tra le note ed evitare che si fondano.
        sustain: (note[\sustain] * beatDur) * 0.9,

        amp: (note[\amp] ?? 0.8) * (p[\ampGlobal] ?? 1),

        // Parametri passati al SynthDef
        wave: p[\wave], detune: p[\detune], cutoff: p[\cutoff], rq: p[\rq],
        aAtk: p[\aAtk], aDec: p[\aDec], aSus: p[\aSus], aRel: p[\aRel],
        fAtk: p[\fAtk], fDec: p[\fDec], fSus: p[\fSus], fRel: p[\fRel], fAmt: p[\fAmt],
        vAtk: p[\vAtk], vDec: p[\vDec], vSus: p[\vSus], vRel: p[\vRel],
		aAtkCurve: p[\aAtkCurve], aDecCurve: p[\aDecCurve], aRelCurve: p[\aRelCurve],
        fAtkCurve: p[\fAtkCurve], fDecCurve: p[\fDecCurve], fRelCurve: p[\fRelCurve],
        vAtkCurve: p[\vAtkCurve], vDecCurve: p[\vDecCurve], vRelCurve: p[\vRelCurve],
        vRate: p[\vRate], vDepth: p[\vDepth],
        delayTime: p[\delayTime], decayTime: p[\decayTime],
        revMix: p[\revMix], revRoom: p[\revRoom]
    ).play;
};

	var win, uv, sidebarWidth=50, beatSize=80;
 	var selectedNotes, dragMode, lastMousePos, dragTarget, selectionRect, mouseDownPoint;
    var hSnap = 0.25, getCurrentSnap;
	var playRoutine, isPlaying = false, playSequence, stopSequence, playheadPos = 0;
	var bpmField, statusLabel, bpm = 120;
	var topToolbar, saveFile, loadFile;
	var sliderH, sliderV;
	var currentNotaKey = 0;
	var noteMenu;
	var listaNoteD=["C","C#","D","DB#","E","F","F#","G","G#","A","A#","B"];
    var listaNoteB=["C","Db","D","Eb","E","F","Gb","G","Ab","A","Bb","B"];
	var listaNote = listaNoteD;

	var isLoop = false; // continuare a suonare

	var maxBeats = 100;

	// Limiti di visualizzazione iniziale
	var visibleBeatRange = [0, 16];
	var visibleMidiRange = [46, 74];

	var paths;

	// Undo
	var undoStack = List.new;
	var undoSelect = List.new;
	var maxUndo = 30;

	var saveState = { // SAVE
		undoStack.add(sequence.list.collect({ |item| item.copy }));
		undoSelect.add(selectedNotes.collect({ |item| item.copy}));
		if(undoStack.size > maxUndo) {
			undoStack.removeAt(0);
			undoSelect.removeAt(0);	}; };

	var performUndo = { // UNDO
		if(undoStack.size > 0) {
			var lastN = undoStack.pop;
			var lastS = undoSelect.pop;
			sequence.list.clear;
			sequence.list.addAll(lastN);
			selectedNotes.clear;
			lastS.do { |oldNote|
				var found = sequence.list.detect { |n|
					(n[\beat] == oldNote[\beat]) && (n[\midinote] == oldNote[\midinote])};
				if(found.notNil) { selectedNotes.add(found) };
			};
			{ uv.refresh;
				statusLabel.string = "Status: Undo (" ++ undoStack.size ++ ")";
			}.defer;}
		{statusLabel.string = "Status: Nulla da annullare";	}; };

    // --- LOGICA SCALE ---
    var scaleMenu, scalaAttuale, scalaScelta = 'Maggiore';

    var scales = (
		'Maggiore': [0, 2, 4, 5, 7, 9, 11],
		'Minore': [0, 2, 3, 5, 7, 8, 10],
		'dado': [0, 2, 3, 5, 7, 8, 9],
		'Cromatica': (0..11),
		'Dorica': Scale.dorian.degrees ,
        'Frigia': Scale.phrygian.degrees ,
        'Lidia': Scale.lydian.degrees ,
        'Misolidia': Scale.mixolydian.degrees ,
        'Locria': Scale.locrian.degrees ,
        'Min Armonica': Scale.harmonicMinor.degrees	,
        'Min Melodica': Scale.melodicMinor.degrees
		 );

  var moveInScale = { |midi, direction| // direction: 1 per su, -1 per giù
    var pc = midi % 12;
    var octave = (midi / 12).floor * 12;
    var extScale = (scalaAttuale - 12) ++ scalaAttuale ++ (scalaAttuale + 12);
    var nextNote;

    if (direction > 0)
		{nextNote = extScale.detect { |deg| deg > pc };}
		{ nextNote = extScale.reverse.detect { |deg| deg < pc };};
      octave + nextNote;
};


	var snapToScale = { |midi|
      var pc = midi % 12;
      var octave = (midi / 12).floor * 12;
      var extendedScale = scalaAttuale ++ (scalaAttuale + 12) ++ (scalaAttuale - 12);
      var nearest = extendedScale.minItem({ |item| (item - pc).abs });
      octave + nearest; };

	// get
	var getVSize = { uv.bounds.height / (visibleMidiRange[1] - visibleMidiRange[0] + 1) };
    var getBeatSize = { (uv.bounds.width - sidebarWidth) / (visibleBeatRange[1] - visibleBeatRange[0]) };

	var getNoteRect = { |note|
        var bSize = getBeatSize.value, vSize = getVSize.value;
        var x = ((note[\beat] - visibleBeatRange[0]) * bSize) + sidebarWidth;
        var y = (visibleMidiRange[1] - note[\midinote]) * vSize;
        Rect(x, y, note[\sustain] * bSize, vSize);
    };

	var getMusicPos = { |p|
        var bSize = getBeatSize.value, vSize = getVSize.value;
        var beat = ((p.x - sidebarWidth) / bSize + visibleBeatRange[0]).trunc(hSnap).max(0);
		var midi = ((visibleMidiRange[1] - (p.y / vSize))+1).trunc.clip(0, 127);
        [beat, snapToScale.value(midi)];
    };

	var getNomeNota = { |y| // coordinata schermo a nome nota esempio C#4
		var vSize = getVSize.value;
        var midiNum = ((visibleMidiRange[1] - (y / vSize))+1).trunc.clip(0, 127);
		var noteIndex = midiNum % 12;
		var octave = ((midiNum / 12).floor - 1).asInteger  ;
		var noteString = listaNote[noteIndex] ++ octave.asString;
        noteString;
    };

	// --- CREA da nota ---
	var creaMenu, applyCrea;
	var creaList = [ "Arpeggio","Accordi","BassoTempiForti", "Basso", "Melodia","Melodia8","Ritmo" ];

	// --- TRASFORMA da selezione ---
    var processMenu, applyTransformation;
    var transformList = [
		"Specchia Verticale", "Specchia Orizzontale","Ritmo>Melodia",
        "Inserisci Pause", "Shift Sinistra (Ciclico)", "Shift Destra (Ciclico)",
		"Accorcia 20%", "Accorcia 50%","Allunga 100%",
		"Unisci Note", "Dividi in 2", "Dividi in 3","Dimezza","Raddoppia"  ];

////////////////////////// fine VAR ///////////////////

	// Funzioni
  ~makeWalkingNoRepeat = { // makeWalkingNoRepeat
     var currentNote, steps, direction, scaleRange;
     scaleRange = (0..6);
     currentNote = [0, 2, 4].choose;
     Routine {
        currentNote.yield;
		loop { direction = [-1, 1].choose; steps = rrand(1, 4);
          steps.do {
            var nextNote = currentNote + direction;
            if (nextNote < 0 or: { nextNote > 6 }) {
              direction = direction * -1;
              nextNote = currentNote + direction; };
              currentNote = nextNote;
              currentNote.yield;
            }; }  }; };

  ~fillConPause = { |noteSelection|
    var sorted = noteSelection.sort({ |a, b| a[\beat] < b[\beat] });
    var filledSelection = List.new;
    var lastEnd = sorted.first[\beat];
    sorted.do { |note, i|
        var currentStart = note[\beat];
        if (currentStart > lastEnd) {
            filledSelection.add((
                \beat: lastEnd,
                \sustain: currentStart - lastEnd,
                \amp: 0,
                // \isRest: true
            )); };
        filledSelection.add(note);
        lastEnd = currentStart + note[\sustain]; };
    if (lastEnd > 0) {
        var nextWholeBeat = lastEnd.ceil; // Arrotonda all'intero superiore
        if (nextWholeBeat > lastEnd) {
            filledSelection.add((
                \beat: lastEnd,
                \sustain: nextWholeBeat - lastEnd,
                \amp: 0,
                // \isRest: true
            )); };  };
    filledSelection; };


  applyTransformation = { // Transformation su selezionate
      var action = transformList[processMenu.value];
      if(selectedNotes.size > 0) {
		var sorted = selectedNotes.asArray.sort({ |a, b| a[\beat] < b[\beat] });
		saveState.value;

	case

	{action == "Inserisci Pause"} { // Inserisci Pause
			var conPause = ~fillConPause.value(selectedNotes);
			conPause.do { |n|
			selectedNotes.do { |n| sequence[\_remove].value(sequence, n) };
			sequence[\_add].value(sequence, (
			    beat: n[\beat],
			    midinote: n[\midinote],
			    sustain: n[\sustain],
			    amp: n[\amp] )); }; }

	{action == "Ritmo>Melodia"} { // No repeat
			var ottavaBase, tonica;
			tonica = selectedNotes.collect({ |n| n[\midinote] }).maxItem;
			ottavaBase = (tonica / 12).floor * 12;
			~myWB = ~makeWalkingNoRepeat.value;
		selectedNotes.do { |n|
		    sequence[\_add].value(sequence, (
			beat: n[\beat],
			midinote: 12 + ottavaBase + scalaAttuale[~myWB.next],
			sustain: n[\sustain],
			amp: n[\amp] )); }; }


	{action == "Allunga 100%" } { // Allunga 100
             var start = selectedNotes.collect({ |n| n[\beat] }).minItem;
             selectedNotes.do { |n|
               n[\sustain] = n[\sustain] * 2;   };  }

	{action == "Dimezza" } {
             var start = selectedNotes.collect({ |n| n[\beat] }).minItem;
             selectedNotes.do { |n|
               n[\beat] = ((n[\beat] - start) * 0.5) + start;
               n[\sustain] = n[\sustain] * 0.5;   };  }

	{action == "Raddoppia" } {
             var start = selectedNotes.collect({ |n| n[\beat] }).minItem;
             selectedNotes.do { |n|
               n[\beat] = ((n[\beat] - start) * 2) + start;
               n[\sustain] = n[\sustain] * 2;   };  }

    {action == "Specchia Verticale" } {
            var midis = sorted.collect(_[\midinote]);
            var center = (midis.minItem + midis.maxItem) / 2;
            selectedNotes.do { |n|
			n[\midinote] = snapToScale.value((2 * center - n[\midinote]).round) }; }

    {action == "Specchia Orizzontale" } {
             var start = sorted.first[\beat], end = sorted.collect({|n| n[\beat] + n[\sustain]}).maxItem;
             selectedNotes.do { |n| n[\beat] = start + (end - (n[\beat] + n[\sustain])) }; }

    {action == "Shift Sinistra (Ciclico)" } {// Shift Sinistra (Ciclico)
             var first = sorted.first;
             var shiftAmt = first[\sustain];
             var lastNoteEnd = sorted.collect({|n| n[\beat] + n[\sustain]}).maxItem;
             sorted.do { |n, i| if(i > 0) { n[\beat] = n[\beat] - shiftAmt } };
             first[\beat] = lastNoteEnd - shiftAmt; }

          {action == "Shift Destra (Ciclico)" } {
            var last = sorted.last;
            var shiftAmt = last[\sustain];
            var selectionStart = sorted.first[\beat];
            sorted.do { |n, i| if(i < (sorted.size-1)) { n[\beat] = n[\beat] + shiftAmt } };
            last[\beat] = selectionStart;}

          {action == "Accorcia 20%" } {
			selectedNotes.do { |n| n[\sustain] = (n[\sustain] * 0.8).max(0.05) }; }

          {action == "Accorcia 50%" } {
			selectedNotes.do { |n| n[\sustain] = (n[\sustain] * 0.5).max(0.05) }; }

          {action == "Unisci Note" } {
            var minB = sorted.first[\beat],
			maxE = sorted.collect({|n| n[\beat] + n[\sustain]}).maxItem;
            var midi = sorted.first[\midinote];
            selectedNotes.do { |n| sequence[\_remove].value(sequence, n) };
            selectedNotes = [sequence[\_add].value(
					sequence,(beat: minB, midinote: midi, sustain: maxE - minB))].asList; }

          {action.beginsWith("Dividi") } {
                var div = if(action.endsWith("2")) { 2 } { 3 };
                var newSelection = List.new;
                selectedNotes.do { |n|
                    var dur = n[\sustain] / div;
                    var baseBeat = n[\beat];
                    n[\sustain] = dur;
                    newSelection.add(n);
                    (div - 1).do { |i|
                        newSelection.add(sequence[\_add].value(sequence, (
                            beat: baseBeat + ((i + 1) * dur),
                            midinote: n[\midinote],
                            sustain: dur
                        )));
                    };
                };
                selectedNotes = newSelection;
            };

            uv.refresh;
			uv.focus;
            statusLabel.string = "Status: OK (" ++ action ++ ")";
        }
		{ statusLabel.string = "Status: Nessuna selezione!"; };
    };



	applyCrea = { // Crea
      var action = creaList[creaMenu.value];
      if(selectedNotes.size > 0) {
         var sorted = selectedNotes.asArray.sort({ |a, b| a[\beat] < b[\beat] });
         saveState.value;

    case // scelta CREA

	{action == "Ritmo" } {// RITMO
	  var lastBeat, startPoint, currentPos, tonica,vol;
	  var duratePossibili = [0.25, 0.5, 0.75]; // 1/16, 1/8, 1/8 puntato
	  var maxBeat = 4.0;
	  lastBeat = selectedNotes.collect({ |n| n[\beat] }).maxItem;
	  tonica = selectedNotes.collect({ |n| n[\midinote] }).maxItem;
      startPoint = lastBeat + hSnap;
      currentPos = 0;
      while { currentPos < maxBeat } {
		var durata, probPausa;
		if ((currentPos % 1.0)==0){vol=1.0}{vol=0.5};
        durata = duratePossibili.choose;
        if (currentPos + durata > maxBeat) { durata = maxBeat - currentPos };
        probPausa = 0.2.coin; // (es. 20% di probabilità di pausa)
        if (probPausa.not) { // nota nella scala
            sequence[\_add].value(sequence, (
                beat: startPoint + currentPos,
                midinote: tonica,
                sustain: durata ,
				amp: vol ));
            }; currentPos = currentPos + durata; };}

	{action == "Melodia" } {// MELODIA
	   var lastBeat, startPoint, ottavaBase, tonica;
       var maxBeat = 4.0;
       var step = 0.5; // Muoviamoci per ottavi
       lastBeat = selectedNotes.collect({ |n| n[\beat] }).maxItem;
       tonica = selectedNotes.collect({ |n| n[\midinote] }).maxItem;
       ottavaBase = (tonica / 12).floor * 12;
       startPoint = lastBeat + hSnap;
       8.do { |i|
         var currentBeat = startPoint + (i * step);
         sequence[\_add].value(sequence, (
           beat: currentBeat,
           midinote: ottavaBase + scalaAttuale.choose,
			sustain: step)); }; }

	{action == "Melodia8" } {// Melodia8
	  var lastBeat, lastMidi, startPoint;
	  lastBeat = selectedNotes.collect({ |n| n[\beat] }).maxItem;
      lastMidi = selectedNotes.collect({ |n| n[\midinote] }).maxItem;
      startPoint = lastBeat + hSnap;
      8.do { |i|
        var salto = [-2, -1, 1, 2].choose;
		var nuovaNotaMidi = lastMidi + salto;
        sequence[\_add].value(sequence, (
          beat: startPoint + (i * hSnap),
          midinote: nuovaNotaMidi,
          sustain: hSnap  ));
		  lastMidi = nuovaNotaMidi; }; }

	{action == "Basso" } {// Basso
      var lastBeat, startPoint, currentPos, lastMidi, tonica;
      var duratePossibili = [0.25, 0.5, 0.75]; // 1/16, 1/8, 1/8 puntato
      var maxBeat = 4.0;
      lastBeat = selectedNotes.collect({ |n| n[\beat] }).maxItem;
      tonica = selectedNotes.collect({ |n| n[\midinote] }).maxItem;
      startPoint = lastBeat + hSnap;
      currentPos = 0;
      lastMidi = tonica;
      while { currentPos < maxBeat } {
        var durata, notaMidi, probPausa;
        durata = duratePossibili.choose;
        if (currentPos + durata > maxBeat) { durata = maxBeat - currentPos };
        probPausa = 0.1.coin; // (es. 10% di probabilità di pausa)
        if (probPausa.not) { // nota nella scala
            var grado = scalaAttuale.choose; // Scegliamo grado scala
            notaMidi = ( (tonica / 12).floor * 12 ) + grado;
            if ((notaMidi - lastMidi).abs > 12) { notaMidi = notaMidi - 12 };
            sequence[\_add].value(sequence, (
                beat: startPoint + currentPos,
                midinote: notaMidi,
                sustain: durata * 0.98 ));
            lastMidi = notaMidi;
        }; currentPos = currentPos + durata; };}

	{action == "BassoTempiForti" } {// Basso Tempi Forti
      var lastBeat, startPoint, currentPos, tonica;
      var scalaDo = [0, 2, 4, 5, 7, 9, 11];
      var maxBeat = 4.0;
      var ottavaBase;
      lastBeat = selectedNotes.collect({ |n| n[\beat] }).maxItem;
      tonica = selectedNotes.collect({ |n| n[\midinote] }).maxItem;
      ottavaBase = (tonica / 12).floor * 12;
      startPoint = lastBeat + hSnap;
      currentPos = 0;
      8.do { |i|
        var notaMidi, probabilità, durata;
        probabilità = if(i % 2 == 0) { 0.7 } { 0.3 }; //forti 0.7 deboli 0.3
        if (probabilità.coin) {
            if (i == 0) { // SCELTA DELLA NOTA:
                notaMidi = ottavaBase + 0; //TONICA
            } { if (i % 2 == 0) {notaMidi = ottavaBase + [0, 7].choose;}
							{ notaMidi = ottavaBase + scalaAttuale.choose;};};
            durata = if(i % 2 == 0) { 0.5 } { 0.25 }; // forte + lunga
            sequence[\_add].value(sequence, (
                beat: startPoint + (i * 0.5),
                midinote: notaMidi,
                sustain: durata * 0.8)); }; }; }

	{action == "Arpeggio" } { // ARPEGGIO
	  var lastBeat, startPoint, ottavaBase, tonica;
      var scalaR = scalaAttuale.copyRange(0, scalaAttuale.size - 2).add(12);
      var maxBeat = 4.0;
      var step = 0.5;
	scalaAttuale.postln;
      lastBeat = selectedNotes.collect({ |n| n[\beat] }).maxItem;
      tonica = selectedNotes.collect({ |n| n[\midinote] }).maxItem;
      ottavaBase = (tonica / 12).floor * 12;
      startPoint = lastBeat + hSnap;
      4.do { |i|
        var currentBeat = startPoint + (i * step* 4);
        var noteArpeggio = scalaR.select {|item, i| i.even };
        4.do { |j|
            sequence[\_add].value(sequence, (
            beat: currentBeat + (j * (step)),
            midinote: ottavaBase + noteArpeggio[j],
            sustain: 1 )); }; }; }

	{action == "Accordi" } {   // ACCORDO (4 note)
      var lastBeat, startPoint, ottavaBase, tonica,scalaR,nota;
      var maxBeat = 4.0;
      var step = 1; // 1/4
   	  scalaR = scalaAttuale.copyRange(0, scalaAttuale.size - 2).add(12);
	  scalaR.postln;
	  lastBeat = selectedNotes.collect({ |n| n[\beat] }).maxItem;
      tonica = selectedNotes.collect({ |n| n[\midinote] }).maxItem;
      ottavaBase = (tonica / 12).floor * 12;
      startPoint = lastBeat + hSnap;
      4.do { |i|
        var currentBeat = startPoint + (i * step);
        var noteArpeggio = scalaR.select {|item, i| i.even };
        4.do { |j|
            sequence[\_add].value(sequence, (
            beat: currentBeat ,
            midinote: ottavaBase + noteArpeggio[j],
            sustain: step*0.9 )); }; }; } // fine accordi

		};// fine scelta CREA
			uv.refresh;
		    uv.focus;
            statusLabel.string = "Status: OK (" ++ action ++ ")";
         { statusLabel.string = "Status: Nessuna selezione!"; };
    };

	selectedNotes = List.new;

	stopSequence = { playRoutine.stop; isPlaying = false;
		playheadPos = 0; { statusLabel.string = "Status: Pronto"; uv.refresh; }.defer; };

    saveFile = { FileDialog({ |paths| var p = paths[0].asString;
		if(p.endsWith(".seq").not){p=p++".seq"};
		sequence.list.asArray.writeArchive(p);
		win.name = titolo + p;
	}, {},fileMode: 0,acceptMode: 1,
	    path: ~cPathSeq
	); };


  loadFile = { FileDialog({ |paths|
	var d = Object.readArchive(paths[0]);
	if(d.isSequenceableCollection)
	    {sequence.list.clear;
		d.do{|n| sequence.list.add(n)};
		win.name = titolo + paths[0];
		uv.refresh;}; },
	  cancelFunc: {"ko".postln;},
	  fileMode: 1,acceptMode: 0,path: ~cPathSeq  ); };

  playSequence = {
    var notesToPlay, startTime, maxBeat, beatDuration;
    notesToPlay = if(selectedNotes.size > 0) { selectedNotes } { sequence.list };
    if(notesToPlay.isEmpty) { ^this };

    startTime = if(selectedNotes.size > 0) { notesToPlay.collect(_[\beat]).minItem } { 0 };
    maxBeat = (notesToPlay.collect({|n| n[\beat] + n[\sustain]}).maxItem ? (startTime + 4));
    beatDuration = 60/bpm;

    isPlaying = true;

    playRoutine = Routine({ // CICLO DI LOOP PRINCIPALE
        while({ isPlaying }) {
            var startClock = Main.elapsedTime;
            var sortedNotes = notesToPlay.copy.sort({ |a, b| a[\beat] < b[\beat] });
            var currentBeat = startTime;

            // Routine per la testina visiva (GUI)
            var guiRoutine = Routine({
                while({ isPlaying }) {
                    playheadPos = startTime + ((Main.elapsedTime - startClock) / beatDuration);
                    { uv.refresh }.defer;
                    (1/30).wait;
                };
            }).play(AppClock);

            // RIPRODUZIONE NOTE
            sortedNotes.do { |note|
                var delta = note[\beat] - currentBeat;
                if(delta > 0) { (delta * beatDuration).wait };
                if(isPlaying) { playNote.value(note) };
                currentBeat = note[\beat];
            };

            // Aspetta la fine dell'ultima nota
            ((maxBeat - currentBeat) * beatDuration).max(0).wait;

            guiRoutine.stop; // Fermiamo SEMPRE la GUI alla fine del tempo

            if(isLoop.not) { // 2. Gestione Loop vs Once
                isPlaying = false;
				{ stopSequence.value }.defer;
            };

        }; // fine while

        { stopSequence.value }.defer;

    }).play(SystemClock);
};


// --- SETUP UI ---
	win = Window(titolo, Rect(10, 10, 1100, 700)).front;
	win.acceptsMouseOver = true; // per leggere x,y con move

	uv = UserView().background_(Color.gray(0.12)).canFocus_(true);

	statusLabel = StaticText().string_("Status: Pronto").fixedWidth_(180);

	bpmField = NumberBox().value_(bpm).clipLo_(40).clipHi_(300).fixedWidth_(40).action_({ |obj| bpm = obj.value; });

	noteMenu = PopUpMenu().items_(listaNote).action_({ |obj|
		currentNotaKey = obj.value;uv.refresh;uv.focus; }).fixedWidth_(40);

	scaleMenu = PopUpMenu().items_(scales.keys.asArray.sort).action_({ |obj| scalaScelta = obj.items[obj.value].asSymbol; uv.refresh;uv.focus; }).fixedWidth_(90);

	processMenu = PopUpMenu().items_(transformList).fixedWidth_(150);

	creaMenu = PopUpMenu().items_(creaList).fixedWidth_(150);

	sliderH = RangeSlider().orientation_(\horizontal).lo_(0).hi_(0.16).action_({|sl|
		visibleBeatRange = [sl.lo * maxBeats, sl.hi * maxBeats];
		uv.refresh;
	});

	sliderV = RangeSlider().orientation_(\vertical).lo_(0.4).hi_(0.6).action_({|sl|
		visibleMidiRange = [sl.lo * 127, sl.hi * 127].round;
		uv.refresh;
	});

// LAYOUT VERT
   win.layout = VLayout(
		HLayout( // LAY alto
			Button().states_([["Undo"]])
			  .action_({ performUndo.value;uv.focus; }).fixedWidth_(50),

			Button().states_([["Nuovo"]])
			  .action_({ sequence.list.clear; uv.refresh;uv.focus; }).fixedWidth_(50),

			Button().states_([["Salva"]])
			  .action_({ saveFile.value;uv.focus; }).fixedWidth_(50),

			Button().states_([["Carica"]])
			  .action_({ loadFile.value;uv.focus; }).fixedWidth_(50),

			StaticText().string_("  ").fixedWidth_(10),

			Button().states_([["Once", Color.black],
				["Loop", Color.black, Color.yellow]]).action_({ |a|
				if(a.value == 0, {isLoop=false }, {isLoop=true});
				uv.focus; }).fixedWidth_(40),

			/*Button().states_([["#", Color.black], ["b", Color.black]]).action_({ |a|
				if(a.value == 0, {listaNote = listaNoteD}, {listaNote = listaNoteB};uv.focus;);
				noteMenu.items_(listaNote);}).fixedWidth_(20),*/

			Button().states_([["#", Color.black], ["b", Color.black]]).action_({ |a|
				if(a.value == 0, {listaNote = listaNoteD}, {listaNote = listaNoteB});
				noteMenu.items_(listaNote);}).fixedWidth_(20),

			StaticText().string_(" Scala:").fixedWidth_(30) ,

			noteMenu,

			scaleMenu,

			StaticText().string_(" Funz.:").fixedWidth_(30),

			processMenu,

			Button().states_([["Esegui", Color.black, Color.yellow]]).action_({
				applyTransformation.value }).fixedWidth_(55),

			StaticText().string_(" Crea:").fixedWidth_(30),

			creaMenu,

			Button().states_([["Crea", Color.black, Color.yellow]]).action_({
				applyCrea.value }).fixedWidth_(55),

			Button().states_([["SYNTH", Color.black, Color.grey(0.8)]])
			  .action_({ ~openSynthControls.value }).fixedWidth_(55),

			Button().states_([["Aiuto", Color.white, Color.blue(0.7)]]).action_({

				~openHelpWindow.value;

			}).fixedWidth_(55),

			nil ),
		// slider zoom Verticale
		HLayout( uv, sliderV.fixedWidth_(15) ),

		// slider zoom Orizzontale
		HLayout( StaticText().fixedWidth_(sidebarWidth),sliderH.fixedHeight_(15) ),

		HLayout(statusLabel, StaticText().string_("BPM:").fixedWidth_(30), bpmField, nil)
	);

    // impone scalaScelta
	scaleMenu.valueAction_(scaleMenu.items.indexOfEqual(scalaScelta.asSymbol));

	// --- DISEGNO ---
	uv.drawFunc = { |v|
 		var bSize = getBeatSize.value;
		var vSize = getVSize.value;
		var h = v.bounds.height, w = v.bounds.width;
		var fvBeat, lvBeat;
		scalaAttuale = (scales[scalaScelta] + currentNotaKey) % 12;

		// 1. Griglia MIDI
		// righe orizzontali
		(visibleMidiRange[0].asInteger..visibleMidiRange[1].asInteger).do { |m|
			var y = (visibleMidiRange[1] - m) * vSize;

			if(scalaAttuale.includes(m % 12).not) {
				Pen.fillColor_(Color.gray(0.30));
				Pen.addRect(Rect(sidebarWidth, y, w, vSize)).fill; };

			Pen.strokeColor_(if(m % 12 == 11) { Color.gray(1.0) } { Color.gray(0.2) });
			Pen.line(sidebarWidth @ y, w @ y).stroke;

			if(m % 12 == 0) {
				Pen.fillColor_(Color.gray(0.6));
				Pen.stringAtPoint("C"++((m/12)-1).asInteger, 5@y); };
		};

		// 2. Griglia Temporale e NUMERI BEAT
		// righe verticali
		fvBeat = (visibleBeatRange[0] / hSnap).floor * hSnap;
        lvBeat = (visibleBeatRange[1] / hSnap).ceil * hSnap;
        (fvBeat, fvBeat + hSnap .. lvBeat).do { |b|
			var x = ((b - visibleBeatRange[0]) * bSize) + sidebarWidth;
			if(x >= sidebarWidth) {
				var riga= (((b % 1.0)*10000).trunc)/10000;

				Pen.strokeColor_(if(riga == 0.0 || (riga > 0.95))
					{ Color.gray(0.8) } { Color.gray(0.6) });
               	Pen.line(x @ 24, x @ h).stroke;
				if(riga == 0.0 || (riga > 0.95)) {
                    Pen.fillColor_(Color.white.alpha_(0.8));
                    Pen.stringAtPoint(b.round.asInteger.asString, (x + 2) @ 2);
                };
            };
        };

	// 3. Note
	sequence.list.do { |n|
    var r = getNoteRect.value(n);
    if((r.left < w) && (r.right > sidebarWidth)) {
        var baseColor = Color.cyan(0.7);
		var selectColor = Color.yellow(1.0);
		var pauseColor = Color.blue(0.5);
        var noteColor = if(selectedNotes.includes(n))
	       { var amp = n[\amp] ?? 0; // Se è nil, diventa 0
     		 if(amp == 0) {pauseColor} {selectColor.alpha_(amp) };}
    	     	          {baseColor.alpha_(n[\amp] ?? 0.8) };
        Pen.fillColor_(noteColor);
        Pen.addRect(r).fill.strokeRect(r);
    };};

	if(isPlaying) {
		var px = ((playheadPos - visibleBeatRange[0]) * bSize) + sidebarWidth;
		if(px >= sidebarWidth && (px <= w))
			{ Pen.strokeColor_(Color.red); Pen.line(px@0, px@h).stroke; };
		};
		if(selectionRect.notNil)
		{ Pen.fillColor_(Color.white.alpha_(0.1)); Pen.addRect(selectionRect).fill; };
	}; // fine uv.drawFunc


	// --- MOUSE ---
	selectedNotes = List.new;
    uv.mouseDownAction = { |v, x, y, mod, buttonNumber, clickCount|
		var mPos = x@y, mMusic = getMusicPos.value(mPos);
		var hitNote = sequence.list.detect { |n|
			getNoteRect.value(n).containsPoint(mPos) };

		v.focus; mouseDownPoint = mPos;
		if (clickCount == 2) { saveState.value;
			sequence[\_add].value(sequence,
				(beat: mMusic[0], midinote: mMusic[1], sustain: hSnap)); }

		   {if (hitNote.notNil) {

                if (mod.isShift) {
				    if(selectedNotes.includes(hitNote))
				      {selectedNotes.remove(hitNote)}
				      {selectedNotes.add(hitNote)} }

			  { if(selectedNotes.includes(hitNote).not)
				  {selectedNotes = [hitNote].asList} };

				dragTarget = hitNote;
			dragMode = if (x > (getNoteRect.value(hitNote).right - 10))
			{ \resize } { \move };

            } { if (mod.isShift.not) { selectedNotes = List.new }; dragMode = \lasso; };
		};
		lastMousePos = mPos; uv.refresh;
	};

	uv.mouseMoveAction = { |v, x, y|
		var mPos = x@y, curM = getMusicPos.value(mPos);
		var lastM = getMusicPos.value(lastMousePos ? mPos);
		var deltaB = curM[0] - lastM[0], deltaN = curM[1] - lastM[1];

		case
		{dragMode == \move } { selectedNotes.do { |n|
			n[\beat] = (n[\beat] + deltaB).max(0);
			n[\midinote] = snapToScale.value(n[\midinote] + deltaN).clip(0, 127); }; }

		{dragMode == \resize } { selectedNotes.do { |n|
			n[\sustain] = (n[\sustain] + deltaB).max(0.01) }; }

		{dragMode == \lasso } {
			selectionRect = Rect.fromPoints(mouseDownPoint, mPos);
			sequence.list.do { |n|
				if(selectionRect.intersects(getNoteRect.value(n)))
				{ if(selectedNotes.includes(n).not) { selectedNotes.add(n) }; }; }; };

		lastMousePos = mPos; uv.refresh;
	};

	uv.mouseUpAction = { dragTarget = nil; dragMode = nil; selectionRect = nil;
		saveState.value;
		uv.refresh; };

	uv.mouseOverAction = { |view, x, y|
		statusLabel.string = "Status: "++ getNomeNota.value(y);
		};

	// Volume \amp
	uv.mouseWheelAction = { |v, x, y, mod, delX, delY|
    if(selectedNotes.size > 0) {
        var sensitivity = if(mod.isShift) { 0.002 } { 0.01 };
        saveState.value;
        selectedNotes.do { |n|
            n[\amp] = ( (n[\amp] ?? 0.8) + (delY * sensitivity) ).clip(0.0, 1.0);
        };

        statusLabel.string = "Status: Volume %".format(selectedNotes[0][\amp].round(0.01));

        uv.refresh; }; };

	// --- TASTIERA (CTRL/ALT Ripristinati) ---15

	uv.keyDownAction = { |v, char, mod, unicode, keycode|
		var stepNote = if(mod.isAlt) { 12 } { 1 }, stepB = if(mod.isAlt) { 4 } { hSnap };

		case
		{ keycode == 32 } { if(isPlaying) { stopSequence.value } { playSequence.value }; }
		{ char == $1 } { hSnap = 4/4 * 4.0; }
		{ char == $2 } { hSnap = 2/4 * 4.0; }
		{ char == $3 } { hSnap = 1/3 * 4.0; }
		{ char == $4 } { hSnap = 1/4 * 4.0; }
		{ char == $5 } { hSnap = 1/6 * 4.0; }
		{ char == $6 } { hSnap = 1/8 * 4.0; }
		{ char == $7 } { hSnap = 1/12 * 4.0; }
		{ char == $8 } { hSnap = 1/16 * 4.0; }
		{ char == $9 } { hSnap = 1/24 * 4.0; }
		{ char == $0 } { hSnap = 1/32 * 4.0; }
		{ char.ascii == 26} { performUndo.value }// CTRL+Zz

		// Frecce + Ctrl + Alt

// --- FRECCIA SU (keycode 38) ---
  {keycode == 38} { saveState.value;
    if(mod.isCtrl)
	  { selectedNotes.do{|n| sequence[\_add].value(sequence, n.copy)} };
    selectedNotes.do { |n|
        var current = n[\midinote];
        var pc = current % 12;
        var octave = (current / 12).floor * 12;
        n[\midinote] = case
            { mod.isAlt }   { (current + 12).clip(0, 127) } // Salto Ottava
            { mod.isShift } { (current + 1).clip(0, 127) }  // Semitono
            { var extScale = scalaAttuale ++ (scalaAttuale + 12);
              var nextPC = extScale.detect({ |grado| grado > (pc + 0.01) });
              if(nextPC.notNil) { (octave + nextPC).clip(0, 127) } { current };
            }; }; }

// --- FRECCIA GIÙ (keycode 40) ---
  {keycode == 40} { saveState.value;
    if(mod.isCtrl)
	  { selectedNotes.do{|n| sequence[\_add].value(sequence, n.copy)} };
    selectedNotes.do { |n|
      var current = n[\midinote];
      var pc = current % 12;
      var octave = (current / 12).floor * 12;
      n[\midinote] = case
        { mod.isAlt }   { (current - 12).clip(0, 127) } // Salto Ottava
        { mod.isShift } { (current - 1).clip(0, 127) }  // Semitono
        { var extScale = (scalaAttuale - 12) ++ scalaAttuale;
          var prevPC = extScale.select({ |grado| grado < (pc - 0.01) }).maxItem;
          if(prevPC.notNil) { (octave + prevPC).clip(0, 127) } { current };
            }; }; }

		{ keycode == 39 } {saveState.value;  if(mod.isCtrl)
			{selectedNotes.do{|n| sequence[\_add].value(sequence, n.copy)}};
			selectedNotes.do{|n| n[\beat] = (n[\beat]+stepB).max(0);  };}

		{ keycode == 37 } {saveState.value;  if(mod.isCtrl)
			{selectedNotes.do{|n| sequence[\_add].value(sequence, n.copy)}};
			selectedNotes.do{|n| n[\beat] = (n[\beat]-stepB).max(0);  };}

		// Tasti Canc Del
		{ [127, 8, 46].includes(unicode) } {saveState.value;
			selectedNotes.do { |n|
				sequence[\_remove].value(sequence, n) };
			    selectedNotes = List.new; };

		uv.refresh;
	};

	win.onClose = { stopSequence.value };
	uv.focus;  };

~mySeq = ~createSequence.value;
~openPianoRoll.value(~mySeq);
)
