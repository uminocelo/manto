# Manto Milestones

Tracked against the current codebase. Each milestone is grounded in a concrete gap
in the code; file/line references point at the relevant code so work can start fast.

Status legend: `[x]` done, `[]` open, `[~]` in progress (uncommitted work exists).

## Roadmap (from README)

- [x] MVP: Live editor + preview
- [x] Local content folder
- [x] Page navigation & wiki-style links
- [x] Metadata (frontmatter)
- [x] Static site generator mode
- [x] Theming
- [] **Publishing** → see M1

## M1 — Publishing & drafts — [x] done

Content is currently all-or-nothing: every `.md` file is listed, editable, and
rendered into the static site.

- `draft: true` / `published: false` in front matter; `draft:` pages hidden from
  `/` and from `mix manto.build` output
- `published_at` / `updated_at` front matter surfaced in the editor and static site
- Editor shows a clear published/draft state per page

Status notes:

- `mix manto.build` now skips drafts (logs the skip count) and renders
  `published_at` / `updated_at` lines when present
- The editor sidebar and editing header show a "Draft"/"draft" badge, and the
  header shows `Published`/`Updated` dates
- `/` is a static landing page that never lists pages, so draft filtering is N/A
  there; the public surface is the static build
- Front matter values are now typed (booleans/integers) in the Parser, the subset
  of M3 needed here; full list/date typing is still open in M3

Code touchpoints:

- `lib/manto/content/content.ex:10` — `list_pages/0` returns every `*.md`; needs a
  `list_pages(opts)` that filters on metadata
- `lib/mix/tasks/manto.build.ex:41` — renders all pages unconditionally
- `lib/manto/content/parser.ex:57` — front matter parsing (see M3 for the parser
  upgrade this depends on)
- `lib/manto_web/live/editor_live.html.heex:4` — page list in the sidebar

## M2 — Page delete & rename — [x] done

`Manto.Content` can list, read, and write but never delete or rename; the editor
has no such actions. Pages can only be created and saved.

- `Content.delete_page/1` and `Content.rename_page/2` (writes + `.md` path move)
- Editor toolbar actions with confirm; error flash on failure (missing file, etc.)
- Tests: delete removes the file, rename updates the sidebar, cleanup via `on_exit`

Status notes:

- `delete_page/1` returns `:ok | {:error, :not_found | reason}`; `rename_page/2`
  guards `:not_found` (source missing) and `:already_exists` (target present)
- Editor has a rename form (sluggified target) and a `phx-confirm` delete button
  in the editing pane; both refresh the sidebar and `push_navigate` on success
- Success flashes rely on `put_flash` + `push_navigate`, so they are affected by
  the M4 flash bug — new tests assert navigation + file effects, not the flash

Code touchpoints:

- `lib/manto/content/content.ex` — only `list_pages/1` (opts), `get_page/1`, `save_page/2`
- `lib/manto_web/live/editor_live.ex:21` — `"save"` event is the only mutating path
- `lib/manto_web/live/editor_live.html.heex:23` — new-page form is the only page action

## M3 — Real front matter parsing — [x] done

Front matter is parsed with `String.split(line, ":", parts: 2)` — no YAML lists,
booleans, or dates. `tags: a, b` becomes the plain string `"a, b"`. This blocks
M1 (drafts) and tags taxonomies.

- Parse scalars, lists, and dates; type-aware values (string / list / boolean / iso-date)
- Keep string keys; `metadata/1` stays the public API (used by `editor_live.ex:56`
  and `manto.build.ex:45`)
- Test matrix covering list/boolean/date values and malformed input

Status notes:

- `parse_value/1` now types booleans, integers, comma-separated lists, YAML
  `- item` block lists, and ISO 8601 `Date`/`DateTime` structs; matching
  surrounding quotes are stripped, malformed dates stay strings, and empty or
  blank lines are skipped
- Block lists accumulate onto the current key's value via `add_front_matter_line/2`
  (tracking the last parsed key), so `authors:` + `- a` lines produce a list
- `metadata/1` still returns a string-keyed map; existing consumers
  (`editor_live.ex`, `manto.build.ex`) are unchanged and their tests pass
- Parser test suite grew to 10 tests (list/boolean/date/quote/malformed matrix);
  suite is 34 tests with only the 2 known M4 flash failures

Code touchpoints:

- `lib/manto/content/parser.ex` — `parse_value/1` (`:88`), `parse_front_matter/1` +
  `add_front_matter_line/2` (`:73`), `parse_front_matter_line/1` (`:86`)
- `test/manto/content/parser_test.exs:5` — existing metadata tests to extend

## M4 — Editor flash bug (fix) + unsaved-changes guard — [x] done

Two tests fail on `main` because the "created"/"Draft created!" flash set with
`put_flash` before `push_navigate` never renders (`test/manto_web/live/editor_live_test.exs:17,27`).

- Fix flash propagation so the toast appears after redirect (and flip the 2 tests green)
- Add an unsaved-changes guard: navigating away with unsaved edits warns first;
  `localStorage` autosave restores a draft on next visit

Status notes:

- The "flash bug" was a test artifact, not an app bug: `push_navigate` already
  carries `put_flash` across a live redirect (verified with LiveViewTest's
  `follow_redirect/2`). The failing "created" test opened a brand-new connection
  (`live(conn, to)`) instead of following the redirect, so the flash was never
  there. It now matches the redirect tuple and calls `follow_redirect/2`.
- The second failure was genuine: the `@new` flag existed but the template never
  surfaced it. Added a `#new-draft-notice` ("Draft created!") shown when
  `@new`, cleared on save — matches the test and the "unsaved new page" UX.
- Added `EditorGuard` hook (`assets/js/editor_guard.js`), wired via `app.js`:
  - `input` listener marks dirty + debounced autosave to
    `localStorage["manto:draft:<page>"]`
  - `beforeunload` + capture-phase click/submit interceptors on
    `a[data-phx-link]` and non-save `phx-submit` forms confirm before leaving
  - on mount, a stored draft is pushed to the LiveView via `restore_draft`
    (optimistically filled into the textarea)
- LiveView side: `handle_event("restore_draft", ...)` reloads the page body, and
  `save` pushes `draft_saved` so the hook clears storage and marks clean
- Suite is fully green: 35 tests, 0 failures (was 2 known M4 failures)

Code touchpoints:

- `lib/manto_web/live/editor_live.ex:32-49` — `new_page` does `put_flash` + `push_navigate`
- `lib/manto_web/live/editor_live.ex:17-19` — `"update"` only reassigns in memory
- `test/manto_web/live/editor_live_test.exs:5,21` — the failing tests

## M5 — Rich MDEx rendering — [x] done

The parser enables only `front_matter_delimiter` + `table` (`parser.ex:8`), while
MDEx ships emoji shortcodes and built-in syntax highlighting — both already proven
in the (unused) `hello/2` action (`page_controller.ex:20-21`).

- Add `shortcodes` and syntax highlighting to `@mdex_opts` so editor preview and
  static builds render them
- Keep `render_html/2` returning a plain string; prefer opt-in options over always-on

Status notes:

- `@mdex_opts` now sets `extension: [front_matter_delimiter: "---", table: true,
  shortcodes: true]` plus an explicit `syntax_highlight: [formatter:
  {:html_inline, theme: "onedark"}]` (MDEx's default theme, now visible/controllable
  instead of implicit)
- Only opt-in extensions are enabled (no always-on kitchen sink); both consumers go
  through `render_html/2` so the editor preview (`editor_live.ex:126`) and static
  build (`manto.build.ex:54`) render emoji + highlighted code for free
- New parser tests: `:smile:` → 😄, and fenced code emits `<code class="language-…"`
  with an `athl` highlighted `<pre>`
- Suite: 37 tests, 0 failures

Code touchpoints:

- `lib/manto/content/parser.ex:8` — `@mdex_opts`
- `lib/manto_web/controllers/page_controller.ex:19-23` — working shortcode example

## M6 — Wiki-link integrity

`rewrite_wiki_links/2` rewrites `[[X]]` to `/editor/X` without checking the target
exists, so broken links render silently.

- After rewriting, cross-check targets against `Content.list_pages/0`
- Surface broken links in the editor sidebar and in static build output (a warnings list)

Code touchpoints:

- `lib/manto/content/parser.ex:47-55` — `rewrite_wiki_links/2`
- `lib/mix/tasks/manto.build.ex:41-56` — where a per-build warnings report would print

## M7 — Static site generator v2

`manto.build` emits one hardcoded `<html>` shell per page with a plain nav
(`manto.build.ex:58-80`). No site config, index, or feed.

- `manto.site` config (title, base URL) read from `config/` or a `manto.json`
- Generate `index.html`, `rss.xml`, `sitemap.xml`; copy static assets (images)
- Optional per-page `tags` taxonomy pages

Code touchpoints:

- `lib/mix/tasks/manto.build.ex:58-80` — `page_template/1`
- `priv/themes/*.css` — theme copy already handled at `manto.build.ex:38-39`

## M8 — PWA / offline (in progress)

Uncommitted work exists: `assets/js/service-worker.js`, `assets/manifest.json`, the
manifest link + SW registration script in `root.html.heex`, and `static_paths`
updated in `lib/manto_web.ex:20`.

- Bundle `service-worker.js` through esbuild/`app.js` instead of the inline
  registration script (inline scripts violate the repo convention in AGENTS.md)
- Fix the path mismatch: registered at `/js/service-worker.js`, file lives under `assets/js/`
- Commit `manifest.json` + `service-worker.js` once wired and tested

## Housekeeping

- **Remove dead code**: `PageController.hello/2` has no route (`router.ex` lists only
  `/`, `/editor`, `/editor/:page`)
- **Error handling**: `Content.save_page/2` uses `File.write!` with no rescue path;
  surface write failures as error flashes instead of crashing
- **Re-run gate**: every milestone must pass `mix precommit` (see AGENTS.md) — note
  M4 is required before the suite is fully green
