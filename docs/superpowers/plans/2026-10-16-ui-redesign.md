# Trove — redesign UI/UX (macOS 26, stile proprio)

## Obiettivo
Pannello, anteprima, impostazioni e toast in stile macOS Tahoe nativo, senza i segnali tipici delle UI "generate da AI",
mantenendo l'identità di Trove. Nessun cambio a logica, scorciatoie, ricerca, incolla.

## Fonti
- Apple HIG + Liquid Glass: vetro solo sul livello di controllo/navigazione (pannello, campo di ricerca, toast), mai sul contenuto (card);
  niente vetro su vetro; tinta solo per significato; colori e stili semantici; raggi concentrici; Reduce Transparency/Motion.
- Anti "AI slop": niente glow, gradienti decorativi, icone sparkle/wand, un colore per ogni cosa, badge senza informazione,
  ombre forti; gerarchia con peso e colori secondari, un solo accento, raggi e spaziature da un unico punto.
- Riferimenti: Paste (card giustificate da contenuto visivo, colore solo come identità), Raycast/Alfred (tastiera, hint ⌘N, sobrietà).

## Cosa resta (identità Trove)
- Oro come **unico accento**, usato solo per: wordmark, selezione, focus della ricerca.
- Card che prendono forma dal contenuto (codice come editor, link come dominio, colore a tutta card, immagini a tutta card).
- Cartellino in basso (icona app, app, quando, dettaglio). Etichette del giorno verticali tra le card.
- Barra degli hint con keycap.

## Cosa cambia
1. **Theme**: token unici (raggi 6/10/14 + concentrico, colori adattivi chiaro/scuro, accento oro più scuro in chiaro). Sparisce il dark forzato:
   il pannello segue l'aspetto di sistema.
2. **Pannello**: `NSGlassEffectView` (Liquid Glass) al posto di `NSVisualEffectView` + velo `ink` sovrapposto. Animazione d'apertura
   senza slide con Reduce Motion.
3. **Barra superiore**: wordmark più piccolo; ricerca con lente fissa (via `sparkle.magnifyingglass`), placeholder più corto,
   "per significato" come etichetta sobria; filtri in `Picker` segmentato nativo solo testo.
4. **Card**: superficie piatta adattiva + filo 0.5pt, selezione = anello oro concentrico 2pt senza glow né sollevamento;
   via la striscia arcobaleno per app (l'icona app basta); cartellino separato da hairline, non da velo nero;
   badge linguaggio neutro; link non più in oro pesante; sintassi codice con palette stile Xcode (non oro);
   icona testo-da-terminale `terminal` al posto di `wand.and.sparkles`, lucchetto in secondario.
5. **Etichette giorno**: secondario, non oro.
6. **Stato vuoto**: `ContentUnavailableView` nativo.
7. **Anteprima**: niente sfondo/dark forzato (popover di sistema), hint con le stesse keycap del pannello.
8. **Impostazioni**: testi esplicativi come footer di sezione, percorso Drive su una riga (troncato al centro, completo in tooltip),
   etichetta del toggle segreti più corta.
9. **Toast**: capsula Liquid Glass, niente bordo oro.

## Verifica
- `swift build` e `swift test` verdi.
- `Trove --snapshot` in chiaro e scuro: confronto prima/dopo di pannello, ricerca, anteprima, impostazioni.
- Scorciatoie e menu contestuali invariati (stesso codice in `PanelController`/`contextMenu`).
