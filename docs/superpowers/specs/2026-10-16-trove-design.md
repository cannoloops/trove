# Trove — design

Clipboard manager per macOS ispirato a Paste (pasteapp.io): stessa esperienza generale
(barra di card in basso, anteprime, ricerca, incolla rapido), migliorata con ricerca
intelligente locale e backup su Google Drive.

## Perché
L'utente vuole un'alternativa personale a Paste, funzionante su questo Mac, senza
abbonamento e con dati che restano in locale (backup sulla propria cartella Drive).

## Obiettivi (decisi dall'utente)
- **History** illimitata: retention "per sempre".
- **Preview**: card con anteprima per testo, rich text, link, immagini, file, colori;
  anteprima estesa con barra spaziatrice.
- **Search** intelligente:
  - fuzzy/substring tollerante + filtri per tipo, app di origine e data;
  - OCR del testo nelle immagini (Vision, on-device);
  - semantica on-device (NaturalLanguage sentence embeddings, it/en), nessun cloud.
- **Incolla senza formattazione** (⇧↩ o ⌥ click), oltre a incolla normale (↩).
- **Backup** della history nella cartella locale di Google Drive per desktop
  (`~/Library/CloudStorage/GoogleDrive-*/My Drive/Trove/`), periodico + manuale, con ripristino.
- **UI**: barra orizzontale in basso stile Paste.
- **Scorciatoia globale** personalizzabile (default ⇧⌘V) e **avvio al login**.

## Non-obiettivi (prima versione)
- Pinboard, incolla in sequenza, sync bidirezionale multi-Mac, OAuth Google, LLM cloud.
- Distribuzione su App Store / notarizzazione.

## Anti-obiettivi
- Dati degli appunti inviati a servizi esterni.
- Catturare password: i contenuti marcati `org.nspasteboard.ConcealedType` /
  `TransientType` vengono ignorati sempre (scelta mia, sicurezza di base).
- App lenta all'apertura: la barra deve apparire istantanea.

## Vincoli
- macOS 27, Xcode 26.3, Swift 6.2. Nessun certificato Apple: firma con certificato
  self-signed locale "Trove Local Signing" nel Keychain di login, così il permesso
  Accessibilità sopravvive alle ricompilazioni (deciso dall'utente).
- Incollare nell'app attiva richiede il permesso Accessibilità (CGEvent ⌘V).

## Scelte tecniche (mie)
- SwiftPM: target libreria `TroveCore` (logica, testabile) + eseguibile `Trove`;
  script `scripts/build.sh` assembla `Trove.app` (LSUIElement, menu bar) e la installa
  in `/Applications`.
- Storage: SQLite di sistema (C API) in `~/Library/Application Support/Trove/`,
  tabella `items` + FTS5 tokenizer `trigram` su testo+OCR+titolo+app; immagini come file
  PNG in `blobs/`. Deduplica per hash: ricopiare un elemento lo riporta in cima.
- Monitor: polling `NSPasteboard.changeCount` ogni 0,4 s.
- Ricerca ibrida: risultati FTS (trigram) + punteggio fuzzy in Swift + similarità coseno
  degli embedding (scan lineare; limite ~100k elementi, poi indice ANN).
  Sintassi filtri nel campo di ricerca e chip cliccabili per tipo.
- Hotkey: Carbon `RegisterEventHotKey` (nessuna dipendenza). Login: `SMAppService`.
- Backup: `VACUUM INTO` del DB + copia incrementale dei blob nella cartella Drive;
  ogni 24 h e a richiesta. Ripristino dal menu impostazioni.
- Link: titolo/icona via `LPMetadataProvider`, in cache.

## Lasciato al builder
Layout di dettaglio delle card, palette, animazioni, scorciatoie secondarie
(⌘1…9 incolla diretto, ⌫ elimina, frecce per navigare).
