# Trove user guide

## What gets saved

Every copy (⌘C) from any app: text, rich text, links, images, files and colors, together with the app it came from. Copying the same thing again moves it to the top instead of duplicating it.

Never saved: content that password managers and similar apps mark as concealed or transient ([nspasteboard.org](https://nspasteboard.org) types, 1Password), and copies made inside Trove itself.

History is kept until you delete it: one item with ⌘⌫ in the panel, or everything from **Settings › History › Delete All History…**.

## Pasting

↩ pastes into the app that was frontmost when you opened the panel. This needs the **Accessibility** permission (Settings › General shows whether it is granted). Without it, Trove copies the item and asks for the permission; in the meantime you can paste with ⌘V.

- **↩** pastes the item as it was copied, with formatting.
- **⇧↩** pastes plain text.
- Images pasted into a terminal (Terminal, iTerm2, Ghostty, Warp, WezTerm, kitty, Alacritty) become a file path, so CLI agents like Claude Code or Codex can read them.

### Smart paste

**⌥↩** pastes a version ready for agents and chats, in any app:

- **Terminal cleanup**: text copied from a terminal or an agent TUI loses ANSI escapes, box-drawing frames, trailing padding, common indentation and lines hard-wrapped by the terminal. Text that doesn't look like terminal output is left alone.
- **Secrets** are replaced with stable placeholders such as `<OPENAI_KEY_1>` or `<PASSWORD_1>`.
- **Personal data**: Italian tax codes and VAT numbers (checksum-validated), email addresses and Italian phone numbers become `<CF_1>`, `<PIVA_1>`, `<EMAIL_1>`, `<PHONE_1>`. Plain ↩ never touches personal data, even in AI apps.
- Images become a file path.

Items show a hint when ⌥↩ would change them (secrets found, terminal text).

### Secrets in AI chats

When you paste with ↩ into the ChatGPT, Codex, Claude, Perplexity or Gemini desktop apps, secrets are replaced automatically and a notice tells you how many were hidden. Turn this off in **Settings › AI and agents**. In terminals ↩ always pastes the exact text (for example `export API_KEY=…`).

Detected: private keys (PEM), Anthropic, OpenAI, GitHub, GitLab, Hugging Face, npm, AWS, Slack, Google, Stripe keys and tokens, JWTs, Bearer tokens, `…_PASSWORD=`/`…_TOKEN=`/`…_API_KEY=` variables, `"password": "…"` style JSON/YAML keys, passwords in URLs (`user:pass@host`), card numbers and IBANs. Detection is deliberately conservative, because a false positive would change what you paste.

In the browser, masking isn't automatic. When you paste with ⌘V into claude.ai, chatgpt.com, gemini.google.com or perplexity.ai (Safari, Chrome, Arc, Brave, Edge, Firefox), Trove offers to hide what it found. The same offer appears when you press ⌘V in the desktop apps. ⌥↩ always pastes the masked version.

## Backup and restore

Trove can back up to **Google Drive for desktop**. Install it and sign in, then Trove writes to `My Drive/Trove` (the folder name follows your Drive language) and Drive syncs it.

- **Automatic backup** is off by default; when enabled it runs at most once every 24 hours (Settings › Backup to Google Drive). The backup is not encrypted: it contains your whole history, secrets included.
- **Back Up Now** is in the menu bar icon and in Settings.
- **Restore from Backup…** replaces the history on this Mac with the backup and relaunches Trove. The backup is checked before anything local is touched.

To move to a new Mac: install Trove and Google Drive, wait for `My Drive/Trove` to sync, then restore.

## Privacy

Trove has no account, no server and no analytics. Text recognition and the semantic index run on your Mac, and everything is stored there:

- `~/Library/Application Support/Trove`: database and images
- `~/Library/Caches/io.github.cannoloops.trove`: temporary files for pasting images as paths

Trove only goes online to check for updates (GitHub Releases). If you turn them on, Google Drive syncs the backup folder and **Settings › History › Show titles of copied links** opens copied links to read their titles. Links with `?…` parameters or credentials are never opened.

Images pasted into a terminal are copied to the cache folder above and deleted after 24 hours, when the item is deleted, or when you clear the history.

## Troubleshooting

**↩ copies but does not paste.** The Accessibility permission is missing or stale (this happens once when updating from 1.0.0, or with ad-hoc-signed local builds). Open System Settings › Privacy & Security › Accessibility, remove Trove with −, then add it again, or use the button in Trove's Settings.

**⇧⌘V does nothing.** Another app (Raycast, Alfred, another clipboard manager) may already use the shortcut. Change it in either app: Trove's is under Settings › General › Open Trove.

**"Trove can't be opened" / "unidentified developer".** See [Install](../README.md#install).

**Search by meaning feels weak.** With Apple Intelligence available Trove also tags items by meaning on-device; without it, it falls back to local sentence embeddings only. Settings › History shows which one is active.

**Google Drive for desktop not found.** Trove looks for `~/Library/CloudStorage/GoogleDrive-*`. Make sure Drive is installed and signed in, then reopen Settings.

## Uninstall

Quit Trove from the menu bar icon, then:

```bash
rm -rf /Applications/Trove.app ~/Library/Application\ Support/Trove ~/Library/Caches/io.github.cannoloops.trove
```

```bash
defaults delete io.github.cannoloops.trove
```

Remove Trove from System Settings › Privacy & Security › Accessibility and from General › Login Items & Extensions. The Google Drive backup is not touched.
