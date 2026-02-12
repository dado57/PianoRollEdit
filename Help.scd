~openHelpWindow = {
// 1. Caricamento Immagine
var iv,t, scroll;

var helpString =
"GUIDA RAPIDA A GEMINI-PIANO ROLL STUDIO (v16.2)

INTRODUZIONE
Questo ambiente integra un sequencer grafico (Piano Roll) con un sintetizzatore sottrattivo completo. È progettato per la composizione rapida, la manipolazione di pattern MIDI e il sound design.

IL SINTETIZZATORE (Vedi Diagramma)
Lo strumento ('pianoSynth') è un sintetizzatore polifonico con:
- 2 Oscillatori: Forme d'onda selezionabili (Saw, Square, Triangle, Sine) con detune per suoni 'chorus'.
- Filtro Passa-Basso Risonante (RLPF): Controllato da Cutoff e Risonanza (RQ), modulabile dal proprio inviluppo ADSR.
- 3 Inviluppi ADSR Indipendenti: Per Ampiezza (Volume), Filtro e Vibrato.
- Modulazioni (LFO): Vibrato regolabile in velocità e profondità.
- Effetti Master: Delay (eco) e Reverb (riverbero) integrati.
> Premi il tasto 'SYNTH' nella barra principale per aprire l'editor completo dei parametri.

INTERFACCIA PIANO ROLL
- Griglia: L'asse verticale rappresenta l'altezza (note MIDI), l'asse orizzontale il tempo (Beat) riga verticale più marcata (battuta di 1/4)
- Le righe grigio scuro indicano le note fuori dalla scala selezionata.

UTILIZZO MOUSE
- Inserire Note: Doppio click sulla griglia per inserire una nota della durata dello Snap corrente.
- Selezionare:
    - Click su una nota per selezionarla (diventa gialla).
    - Shift + Click per aggiungere/rimuovere note dalla selezione.
    - Click e trascina (Lasso) su un'area vuota per selezionare più note.
- Spostare: Clicca e trascina il corpo di una nota selezionata.
- Ridimensionare: Clicca e trascina il bordo destro di una nota.
- Volume (Amp): Usa la rotella del mouse su una nota selezionata per cambiarne il volume (trasparenza). Shift+Rotella per regolazione fine.

BARRA DEGLI STRUMENTI (In alto)
- Undo: Annulla l'ultima operazione di modifica o inserimento (Max 30 passi). Anche Ctrl+Z.
- Nuovo/Salva/Carica: Gestione dei file di sequenza (.seq).
- Once/Loop: Decide se la riproduzione si ferma alla fine o ricomincia.
- Selettore Scala: Scegli la tonica, l'alterazione (#/b) e il tipo di scala (Maggiore, Minore, Cromatica). La griglia si adatta di conseguenza.
- Funzioni (Menu 'Funz.' + Tasto 'Esegui'): Applica trasformazioni alle note selezionate (es. specchia, shift temporale, accorcia/allunga, unisci/dividi note).
- Generatore (Menu 'Crea' + Tasto 'Crea'): Genera nuove note basate sulla scala e almeno una nota selezionate (Melodie, Bassi, Arpeggi, Accordi).

TASTIERA E SHORTCUT
- Barra Spaziatrice: Play / Stop.
- Tasti 1-0: Cambiano la griglia di Snap (da 1/1 a 1/16).
  KEY    1   2   3   4   5   6    7    8    9    0
  SNAP 4/4 2/4 1/3 1/4 1/6 1/8 1/12 1/16 1/24 1/32
- Tasto Canc/Backspace: Elimina le note selezionate.
- Frecce Su/Giù: Transpone le note selezionate di un semitono.
    - Alt+Frecce Su/Giù: Transpone di un'ottava.
    - Ctrl+Frecce: Duplica le note prima di spostarle.
    - Shift+Frecce Su/Giù: Muove di 1 semitono (ignora scala)
- Frecce Dx/Sx: Sposta le note nel tempo in base allo Snap.
    - Alt + Frecce Dx/Sx: Sposta di 4 beat.

END

grazie a Gemini-AI (programmi e immagine)

dadoSoft
";


~currentPath = Document.current.dir;
~myImage = Image.new(~currentPath +/+ "diagramma_synth.png");

// 2. Finestra principale
w = Window.new("Help", Rect(0,0, 800, 600)).front;

// 3. Creiamo lo ScrollView che occupa tutta la finestra
scroll = ScrollView(w, w.view.bounds.moveTo(0, 0)).hasBorder_(false);
scroll.canvas = View(); // Creiamo un contenitore interno per il layout

// 4. Elementi dell'interfaccia
// --- Titolo ---
t = StaticText().string_("Guida Edit PianoRoll + Synth").font_(Font("Arial", 28, true)).align_(\center);

// --- Area Immagine ---
// Usiamo una UserView che mantiene le proporzioni
iv = UserView().minHeight_(500).maxWidth_(800);
iv.drawFunc = { |view|
    var rect = view.bounds.moveTo(0,0);
    var ratio = ~myImage.width / ~myImage.height;
    var drawW = rect.width;
    var drawH = drawW / ratio;

    // Se l'altezza calcolata supera la vista, ridimensioniamo in base all'altezza
    if (drawH > rect.height) {
        drawH = rect.height;
        drawW = drawH * ratio;
    };

    ~myImage.drawInRect(Rect(
        (rect.width - drawW) / 2,
        (rect.height - drawH) / 2,
        drawW, drawH
    ));
};

// --- Testo Lungo ---
b = StaticText();
b.string = helpString;
b.align = \topLeft;

b.font = Font("Courier", 18);
// b.font = Font("Monaco", 20);
// Calcoliamo un'altezza approssimativa:
b.fixedHeight = (helpString.size / 2).max(600);


// 5. Applichiamo il Layout al contenitore dello ScrollView
scroll.canvas.layout = VLayout( // L'immagine può espandersi
    t, [iv, stretch: 1], b);

w.onClose = { ~myImage.free };
}