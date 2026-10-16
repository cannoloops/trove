# Trove: idee per l'era AI e agenti (ricerca, ottobre 2026)

## Metodo e limiti
Ho cercato sul web e aperto le pagine citate. **Non ho trovato thread Reddit o Hacker News utili**: le prove vengono da issue GitHub di claude-code (mirror claudeissues.com), forum OpenAI, Product Hunt, directory MCP, doc Raycast e blog. Affermazioni basate solo su snippet di ricerca (pagine non aperte) sono marcate "non verificato" e senza link. Le citazioni sono brevi, tratte dalle pagine aperte.

Legenda: **[FORTE]** più fonti dirette e ripetute; **[MEDIO]** una fonte diretta o più fonti indirette; **[DEBOLE]** speculativo.

---

## Classifica

### 1. Pulizia del testo copiato da TUI di agenti [FORTE]
- **Bisogno**: copiando dal terminale di Claude Code si ottengono a capo rigidi, padding, escape ANSI e indentazione extra. Citazioni: "Every visual line break becomes a hard newline in the clipboard." ([#48037](https://claudeissues.com/issue/48037-copying-text-from-terminal-output-includes-hard-line-breaks-at-every-wrapped-lin)); il padding porta "reverse-video escape codes" che rompono heredoc e Python ([#23014](https://claudeissues.com/issue/23014-bug-tui-copy-paste-includes-trailing-whitespace-padding-and-ansi-escapes-ink-ren), aperta, senza risposta dei maintainer). Altri: comandi multilinea con `\` spezzati ([#35446](https://claudeissues.com/issue/35446-add-copy-button-for-code-blocks-in-terminal-output)), spazi iniziali nei code block ([#66967](https://claudeissues.com/issue/66967-bug-code-blocks-in-assistant-responses-have-leading-whitespace-when-copied)); ricorrente anche per Codex CLI ([thread OpenAI](https://community.openai.com/t/a-copy-button-in-codex-cli-at-the-end-of-the-response-will-go-along-way/1397661)).
- **Esistente**: workaround `/copy` di Claude Code (Markdown grezzo); il [Claude Code Paste Cleaner](https://trevorfox.com/2026/07/clean-up-claude-code-copy-paste/) è un tool web a incolla manuale (rimuove decorazioni, riunisce le righe, ripristina blockquote/liste/fence).
- **Proposta Trove**: azione "Pulisci" su qualsiasi clip e regola automatica opzionale per clip provenienti da Terminal/iTerm/Ghostty/Warp/VS Code/Cursor: strip ANSI, trim del padding a fine riga, unwrap dei paragrafi (euristica: non toccare codice/indentazione coerente, rispettare `\`), rimozione di bullet/spinner dei TUI. Mostra diff originale/pulito, tienili entrambi (scelta con Shift+Invio). Tutto deterministico, on-device, nessun LLM necessario.

### 2. Redazione di segreti e PII prima dell'incolla in LLM/agenti [FORTE]
- **Bisogno**: esiste una categoria di prodotti dedicata. [PrePaste](https://www.producthunt.com/products/prepaste) (Product Hunt, open source, offline) promette "preventing accidental leaks into LLMs, AI coding assistants, emails" e di rilevare "PII, API keys and other secrets". Il fatto che [ClipMCP](https://glama.ai/mcp/servers/susmetaa01/clipmcp) classifichi i clip `sensitive` conferma il bisogno lato clipboard. Non verificato (solo snippet): numerose estensioni Chrome (SafePaste, Swap Sensitive, ChatShield, PasteSecure) e un progetto ClipRedact con ripristino dopo la risposta.
- **Esistente**: estensioni solo-browser; PrePaste lavora su qualsiasi app; i clipboard manager classici (es. Raycast, Maccy) in genere escludono app/tipi concealed ma non redigono.
- **Proposta Trove**: (a) scanner locale (regex per chiavi AWS/GitHub/Anthropic/OpenAI, JWT, `.env`, IBAN, carte con Luhn; opzionalmente entropia) che marca i clip e mostra un badge; (b) azione "Incolla redatto" con segnaposto stabili (`<API_KEY_1>`); (c) **round-trip**: mappa locale dei segnaposto per ripristinare i valori quando si incolla la risposta del modello (idea vista solo in ClipRedact, non verificata); (d) i clip sensibili non vengono mai inviati al backup Drive in chiaro né esposti via MCP.

### 3. Server MCP locale per la cronologia, con filtri di sicurezza [FORTE sulla domanda, MEDIO sul valore]
- **Bisogno**: più server MCP esistono già. ClipMCP (macOS, SQLite locale, 9 tool tra cui `semantic_search` e `get_debug_context`, che raggruppa errori/codice/log recenti; i dati sensibili "never shown to your AI assistant in full unless you explicitly request it"). Il wrapper Maccy ([vlad-ds](https://glama.ai/mcp/servers/@vlad-ds/maccy-clipboard-mcp/blob/00c57626b59c5f655f02ae02e85bbeec975e8ee0/README.md)) risulta "Inactive" e la pagina non elenca tool. Non verificato: clipboard-mcp (Rust, get/set/watch) e altri.
- **Proposta Trove**: server MCP stdio integrato (`trove mcp`), **sola lettura di default**: `search_clips` (usa la ricerca semantica on-device), `get_recent`, `get_clip` (testo/OCR di immagini), `get_pinned_snippets`. Esclusi per default i clip sensibili e le app in blacklist; log locale di cosa l'agente ha letto; scrittura (`set_clip`) solo con conferma. Valore: "usa quello che ho copiato prima" senza reincollare.

### 4. Bundle di contesto: più clip/file in un prompt strutturato [MEDIO-FORTE]
- **Bisogno**: Simon Willison ha creato [files-to-prompt](https://www.simonwillison.net/2024/Oct/16/files-to-prompt-04) con output "Claude XML-style markup" da pipare in `pbcopy`. Non verificato (snippet): decine di tool simili (aicp, promptify-cli con conteggio token, toprompt, snippy, gclip).
- **Esistente**: tutti CLI; nessun clipboard manager nativo noto con multi-selezione e formato prompt.
- **Proposta Trove**: modalità "Raccolta": seleziona N clip (e file copiati dal Finder), scegli formato (Markdown con fence + nome file, XML `<document>`, plain), vedi **stima token** e avviso per soglie di contesto, poi un unico incolla. Salva la raccolta come "bundle" riutilizzabile. Ordine e intestazioni con app/URL sorgente.

### 5. Screenshot/immagini verso agenti CLI: OCR e incolla come percorso [MEDIO]
- **Bisogno**: richiesta di incollare immagini in CLI ([#12644](https://github.com/anthropics/claude-code/issues/12644)): "The Claude Code CLI has no way to accept images or screenshots." Chiusa ad agosto 2026: i maintainer dicono che si usa Ctrl+V (Alt+V su Windows). Nei commenti compaiono workaround (script Kitty/tmux, demone macOS "clipaste") e fallimenti quando la clipboard contiene un riferimento a file o c'è già testo. Altri report (solo snippet, non verificato) parlano di regressioni su Terminal.app e VS Code.
- **Proposta Trove**: per ogni immagine, OCR on-device (Vision) già indicizzato, più due azioni: "Incolla come testo OCR" e "Incolla come percorso file" (salva PNG in cartella temporanea e mette il path, utile per agenti che leggono file e per terminali dove Ctrl+V immagine fallisce). Nessuna dipendenza dal supporto immagini del terminale.

### 6. Incolla HTML come Markdown [MEDIO]
- **Bisogno**: gli input dei chatbot accettano solo testo; la clipboard ha l'HTML ma si perde. L'autore della [newsletter pnote](https://newsletter.pnote.eu/p/better-copy-paste-for-llms?open=false) propone la conversione "HTML in Markdown" prima dell'incolla, usando oggi un tool web.
- **Proposta Trove**: azione/preferenza "Incolla come Markdown" (da rappresentazione HTML conservata nel clip; immagini diventano alt text o OCR). Complementa il già previsto "incolla testo semplice". On-device, deterministico.

### 7. Snippet/prompt con variabili e riferimenti alla cronologia [MEDIO]
- **Bisogno/riferimento**: Raycast offre `{clipboard}`, `{clipboard offset=1}` e `{selection}` in Snippet, Quicklink e AI Commands ([doc](https://manual.raycast.com/dynamic-placeholders)). È il modello d'uso già diffuso per richiamare prompt riutilizzabili.
- **Proposta Trove**: libreria di prompt con segnaposto `{clip}`, `{clip-2}`, `{selezione}`, `{data}`, `{app}`, `{bundle}`; compilazione e incolla da barra. Importa/esporta Markdown (così il team li versiona accanto a `CLAUDE.md`/`AGENTS.md`).

### 8. "Copia ultima risposta dell'agente" e cattura dei risultati [MEDIO-DEBOLE]
- **Bisogno**: un utente Codex chiede un pulsante copia perché trasferisce spesso report in ChatGPT per validazione ([thread](https://community.openai.com/t/a-copy-button-in-codex-cli-at-the-end-of-the-response-will-go-along-way/1397661)): flusso "ChatGPT progetta, Codex implementa, ChatGPT rivede". Un altro utente cita un tool terzo (Codexometer) che copia l'output finale con una hotkey.
- **Proposta Trove**: puro lato Trove è difficile (non legge le sessioni). Fattibile: preset "copia ultimo blocco" tramite Accessibility sulla finestra frontmost, oppure tag automatico di clip generati da terminale/agente per filtrarli ("Output agenti"). Da validare con prototipo.

### 9. Ponte clipboard per sessioni SSH/tmux (OSC 52) [MEDIO-DEBOLE]
- **Bisogno**: su SSH Claude Code usa OSC 52, "Over SSH, Claude Code cannot run the clipboard program on your local laptop" ([guida aident](https://aident.ai/blog/fix-claude-code-copy-paste-ssh-tmux)); la copia può sembrare riuscita ma incolla vuoto.
- **Proposta Trove**: difficile da risolvere dall'app (la clipboard remota non passa da macOS). Possibile solo documentare/rilevare terminali che bloccano OSC 52 o offrire un piccolo helper. Priorità bassa.

### 10. Categorie automatiche per clip da sviluppo (errore, stack trace, log, comando) [MEDIO-DEBOLE]
- **Bisogno**: ClipMCP classifica in `error`, `code`, `url`, `sensitive` e li raggruppa in `get_debug_context`.
- **Proposta Trove**: classificazione locale (regole + Foundation Models solo se serve), filtri rapidi e "bundle di debug" (ultimo errore + codice + comando) incollabile in un agente. Si integra con 3 e 4.

### 11. Trasformazioni rapide con LLM locale (JSON pretty, base64, case, riassunto) [DEBOLE/speculativo]
- Nessuna fonte aperta che lo richieda come bisogno insoddisfatto: i trasformatori deterministici sono comuni. Proposta: pochi trasformatori deterministici (JSON, base64, URL decode, case, strip citazioni) e uno solo con Foundation Models ("riassumi/riscrivi") perché on-device e privato. Non investire molto finché non c'è evidenza.

### 12. Compressione di log/stack trace lunghi prima dell'incolla [DEBOLE]
- Non verificato: una estensione (SafePaste) dichiara di accorciare log rumorosi. Proposta: "Riduci": deduplica righe ripetute, tronca frame di librerie, mantiene prima/ultima parte; mostra token risparmiati. Utile ma senza prova diretta.

### 13. Registro di ciò che è stato incollato verso LLM (audit) [DEBOLE/speculativo]
- Nessuna fonte. Proposta: tag "inviato a: ChatGPT/Claude/Terminale" per clip incollati in quelle app, con avviso se un clip sensibile viene incollato. Sinergia con 2, ma solo se emerge richiesta enterprise.

---

## Sintesi di priorità
1. **Subito (evidenza forte, costo basso, on-device)**: idee 1, 2, 6, 5.
2. **Poi (forte valore differenziante)**: idee 4 e 3, che sfruttano ricerca semantica e OCR già previsti.
3. **Dopo**: 7, 10. **Prototipare/validare**: 8, 9. **Rimandare**: 11, 12, 13.

Nota: le issue di claude-code potrebbero essere chiuse dopo nuove release; il bisogno di fondo (TUI che sporca la clipboard) resta valido per Codex, Cursor e altri terminali, ma andrebbe verificato su versioni correnti.
