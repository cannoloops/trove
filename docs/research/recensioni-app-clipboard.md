# Recensioni e feedback sui clipboard manager macOS

Data ricerca: 2026-10-16. Citazioni brevi, con URL. Nota: sono riportate solo cose effettivamente lette.

## Limiti della ricerca
- **Reddit non era accessibile** (fetch bloccato): nessun dato da r/macapps, r/mac, r/raycast.
- Nessuna recensione utente trovata per Clipy, CopyClip (listing senza rating) e poco per Alfred/Pastebot (solo review editoriali e commenti HN).
- App Store: ho letto i feed RSS delle recensioni (ultime 50) di Paste, PastePal, Maccy (US store). Sono un campione recente, non statistico.
- HN: abbreviato "HN" sotto; URL nel formato `https://news.ycombinator.com/item?id=N`.

## Paste (pasteapp.io)
Fonti: [App Store feed](https://itunes.apple.com/us/rss/customerreviews/page=1/id=967805235/sortby=mostrecent/json) (4.19/5, 1333 voti nel listing US), [HN Maccy thread](https://news.ycombinator.com/item?id=31867121), [Product Hunt](https://www.producthunt.com/p/general/best-clipboard-manager-for-mac).

**Apprezzato**
- Indispensabile nel flusso di lavoro multi-dispositivo: "Absolutely Essential!" (Mac, iPad, iPhone), review 2026-05-06 (App Store feed).
- UI non invasiva: "it's not in the way, it's not another window" (Jonas Wouters, Product Hunt).
- Vale l'abbonamento per alcuni: "100% worth it", Benjamin Harrison (Product Hunt).
- Ricerca nell'archivio, multi-copy, nuova ricerca AI (review 2026-04-06, App Store feed).
- UI stile Windows facile da adottare (clashmeifyoucan, HN 31867121).

**Lamentele**
- **Prezzo/modello**: la maggioranza delle recensioni 1-2 stelle del 2026 riguarda il costo: "$90 perpetual license", abbonamento $29.99/anno, utenti storici passati ad abbonamento ("original buyers moved to a subscription", 2026-08-04). Anche "Lifetime payment option is way two costly" (2026-10-01). Già nel 2020: "I only wish they offered a lifetime plan" (Laar Bear).
- **Onboarding percepito ingannevole**: paywall mostrato dopo il setup, "Forces Subscription Before Trial" (2026-02-08), "Not actually free" (2026-05-25).
- **AI non gradita**: "Subscriber for years, unacceptable injection of AI" (2026-10-02), "No AI Garbage" (2026-09-28).
- **Affidabilità**: perdita di dati/pinned (2026-10-09), sync iCloud che non completa o perde dati (2026-05-11, 2026-02-04), freeze, crash all'avvio su M4 (2026-07-20), ricerca lenta o inaffidabile (Glascodash 2023). Supporto poco reattivo (Gregork 2025).
- **Processo helper** difficile da rimuovere senza Terminale (2026-02-15).
- Privacy: dati in iCloud "default unsafe" (cromka, HN 31867121); cartella iCloud creata senza chiedere (TheXash 2021).
- Troppo "in your face" (mattio, HN 31867121); "feature creep and bloat" (2026-09-04); ricerca cinese non supportata (2026-02-19).

**Richieste**: azioni Shortcuts/automazione (Joel Arnold 2020; "Mac release lost shortcut actions", 2026-03-15), aprire su una board specifica (2026-08-19), barra laterale e miglior supporto Remote Desktop (2026-04-30).

## Raycast Clipboard History
Fonti: [HN Raycast for Windows](https://news.ycombinator.com/item?id=46025505), [HN ClipBook launch](https://news.ycombinator.com/item?id=40648404), [Product Hunt](https://www.producthunt.com/p/general/best-clipboard-manager-for-mac).

**Apprezzato**: tutto-in-uno launcher+clipboard (pzrsa, HN 31867121); le password di 1Password non finiscono in history ([HN 29807300](https://news.ycombinator.com/item?id=29807300)); azioni sulle voci più comode che in Paste (Jonas Wouters, PH); estensione gratuita con Cmd+Shift+V ([HN 40653297](https://news.ycombinator.com/item?id=40653297)).

**Lamentele**: storia illimitata a pagamento: "unlimited clipboard history is behind a $10/month paywall" (danpalmer, HN 40648404); "Pay (again, monthly) for unlimited clipboard history" (rane, HN 46025505); finestra non ridimensionabile, preview insufficiente per codice ([HN 40655894](https://news.ycombinator.com/item?id=40655894)); la modale "hides my current context" (Christophe Pasquier, PH); "too complicated" ([HN 38978352](https://news.ycombinator.com/item?id=38978352)).

**Richiesta**: incollare le copie precedenti con scorciatoia (girishso, HN 40648404).

## Maccy
Fonti: [App Store feed](https://itunes.apple.com/us/rss/customerreviews/page=1/id=1527619437/sortby=mostrecent/json) (App Store $9.99), [GitHub issues](https://github.com/p0deje/Maccy/issues), [HN Maccy](https://news.ycombinator.com/item?id=31867121).

**Apprezzato**: semplice e veloce, "daily driver"; "Great DITTO on Mac" (2025-11-05); "Feels native"; utile per prompt AI e codice (feed); open source ("stick with Maccy as it is open source", james2doyle, HN 40648404); successore di Flycut (alsko, HN 31867121). Recensioni quasi tutte 5 stelle.

**Lamentele** (da GitHub, per reazioni +1):
- Storia illimitata non supportata: [#310](https://github.com/p0deje/Maccy/issues/310) (52 +1, aperta).
- Memoria che cresce nel tempo: [#384](https://github.com/p0deje/Maccy/issues/384) (38 +1, aperta).
- Regressioni dopo aggiornamenti macOS: freeze su Sonoma ([#566](https://github.com/p0deje/Maccy/issues/566), [#617](https://github.com/p0deje/Maccy/issues/617)), label errate su Tahoe ([#1113](https://github.com/p0deje/Maccy/issues/1113)), campo password ([#743](https://github.com/p0deje/Maccy/issues/743)).
- Nessuna esclusione password: "This is the most annoying thing with Maccy for me" (zmmmmm, HN 40648404); dati salvati in chiaro (oangemangut, HN 31867121).
- Preview/immagini deboli: "pretty poor visuals when copy pasting images" (lwouis, HN 31867121); UI "clunky and slow" vs Alfred (2025-07-24).

**Richieste**: incolla/elimina più voci ([#239](https://github.com/p0deje/Maccy/issues/239)), pin che occupano troppo spazio ([#307](https://github.com/p0deje/Maccy/issues/307)), pulizia a tempo ([#805](https://github.com/p0deje/Maccy/issues/805)), ricerca più veloce (2023-12-11, feed), preferiti.

## PastePal
Fonte: [App Store feed](https://itunes.apple.com/us/rss/customerreviews/page=1/id=1503446680/sortby=mostrecent/json) (4.14/5, 189 voti); [PH](https://www.producthunt.com/p/general/best-clipboard-manager-for-mac).

**Apprezzato**: prezzo una tantum e sviluppatore reattivo ("Hidden gem", 2025-09-08), collezioni, trasformazioni testo con JavaScript e OCR (2025-08-14), coda di incolla (2025-08-20), sync iCloud a quattro dispositivi (2026-09-17), "No subscription" (2025-10-30, switcher da Paste).

**Lamentele**: sync iCloud lenta/inaffidabile con perdita di clip ("Sync Is a Dealbreaker", 2026-06-05); crash/chiusura automatica (2026-09-08); trial con limiti e paywall ("Required me to pay to paste", 2025-06-02); non può escludere 1Password in trial; tastiera iOS non aggiorna; manca OCR nella ricerca ("No OCR", 2026-09-21); regressione finestra (2026-08-30).

**Richieste**: evidenziare termini di ricerca (2026-07-30), ordinamento alfabetico e separatori nel multi-incolla (2025-04-12), colori/icone collezioni.

## Alfred
Fonti: HN [40648404](https://news.ycombinator.com/item?id=40648404), [31867121](https://news.ycombinator.com/item?id=31867121), [46025505](https://news.ycombinator.com/item?id=46025505).
- **Pro**: blocco app (es. 1Password) e scadenza history (lelandfe), cancellazione singola voce, licenza una tantum ("my license key is still working", pier25), "stood the time remarkably well" (rane).
- **Contro**: preview non ridimensionabile ([HN 40668216](https://news.ycombinator.com/item?id=40668216)); "The filters don't work for my needs" (CyberDildonics). Retention 3 mesi (Brajeshwar, [HN 40653443](https://news.ycombinator.com/item?id=40653443)).

## ClipBook
Fonte: [HN launch, 141 punti](https://news.ycombinator.com/item?id=40648404). Gratuito.
- **Pro**: "Looks amazing, love the simplicity" (nico); finestra ridimensionabile per preview.
- **Contro**: "it seems to miss a lot of copy events?" (alambra); closed source "slightly sus" (smcleod); binario da 245-600MB (HN); timore keylogger (disintegrator).
- **Richieste**: esclusione password (zmmmmm), shortcut personalizzabili, finestra sullo schermo del cursore (mdavid626), immagini, integrazione vim.

## Pastebot, Flycut, Clipy, CopyClip
- **Pastebot**: $39 con 1 anno di aggiornamenti, oppure $24.99/anno su MAS ([MacStories](https://www.macstories.net/reviews/pastebot-3-doubles-down-on-mac-clipboard-automation-and-introduces-two-new-business-models/)). Limite principale: nessuna versione iPhone/iPad. Pro: stack e automazione (trauco, HN 31867121).
- **Flycut**: amato da alcuni ("daily-driver", jshreder) ma "only copied text and was abandoned" (jackthetab), entrambi in HN 40648404.
- **Clipy**: apprezzato come free/open source (crossroadsguy, HN 31867121). CopyClip: nessun feedback trovato.

## Altri e trend 2025-26
- Moltissimi nuovi "Show HN" nel 2025-26 (PasteBar, CopyMagic, HyperPaste, Cliptop, ClickIt, Copify...): [ricerca HN](https://hn.algolia.com/api/v1/search?query=clipboard%20manager%20mac&tags=story). Posizionamento ricorrente: gratis, offline, local-only, open source, senza abbonamento.
- **macOS Tahoe 26** ha cronologia clipboard in Spotlight ([HN 45261196](https://news.ycombinator.com/item?id=45261196)): minaccia per le app semplici.

## Sintesi: pain point e bisogni non soddisfatti (per frequenza/intensità)
1. **Modello di prezzo** (altissima): Paste (abbonamento/$90), Raycast (storia illimitata a pagamento). Cercano una tantum, trial senza carta, no paywall dopo onboarding. Opportunità: prezzo una tantum chiaro, trial onesto.
2. **Affidabilità e perdita dati** (alta): sync iCloud fallita, crash, freeze, copy event persi (Paste, PastePal, ClipBook, Maccy memory leak). La "memoria" del clipboard deve essere sicura. Il backup su Google Drive di Trove può differenziarsi se robusto, con export/restore verificabile.
3. **Privacy/sicurezza** (alta): esclusione app/password manager, dati in chiaro, closed source sospetto, helper nascosti. Opportunità: esclusioni di default, cifratura, scadenza, trasparenza.
4. **AI non richiesta** (media, intensa): utenti Paste si irritano per AI attivata per default. La ricerca semantica on-device di Trove dovrebbe essere opt-in e locale.
5. **Preview e finestra** (media): preview troppo piccola o non ridimensionabile per codice/testo lungo (Alfred, Raycast, Maccy, ClipBook). Opportunità diretta per la barra a card.
6. **Ricerca** (media): lenta/inaffidabile (Paste, Maccy), manca OCR (PastePal), no highlight termini, no cinese. Corrisponde alla ricerca fuzzy+OCR+semantica di Trove.
7. **Azioni multi-item** (media): incolla/elimina più voci ([#239](https://github.com/p0deje/Maccy/issues/239)), coda, separatori, ordinamento.
8. **Automazione** (bassa-media): Shortcuts/URL scheme persi o mancanti in Paste.
9. **Cronologia illimitata/retention configurabile** ([#310](https://github.com/p0deje/Maccy/issues/310)).
10. **Disinstallazione pulita, permessi** (bassa): helper non rimovibile, richieste Accessibility sgradite.

Nota: i punti 1-3 sono ben supportati (molte fonti); 4-10 hanno poche menzioni individuali e vanno validati.
