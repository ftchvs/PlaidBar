# VaultPeek — Feature & Design Brainstorm (2026-06-17)

> Structured brainstorm (research → diverge → cluster → score → recommend).
> Inputs: GOAL.md, PRD.md, post-mvp-roadmap.md, ux-audit-2026-06-13.md, merged-PR/Linear history,
> plus external research (Exa + web + Reddit/HN) on competitors, user sentiment, Plaid capabilities,
> and macOS-26 platform leverage. **No code changed.** Scoring is 1–5 (effort: 5 = easy).
> Weighting emphasizes north-star fit ×2 and impact ×2.

## BLUF

The product is already feature-rich for its north star (glanceable, local-first, menu-bar-first;
*not* a budgeting suite). The highest-leverage gaps are **not new finance scope** — they are:
1. **Making the menu-bar icon itself a signal** (the RepoBar/CodexBar move VaultPeek hasn't taken).
2. **Turning Plaid's instability into a transparency advantage** (connection health + never showing a confident wrong number).
3. **Native macOS-26 leverage** (App Intents/Shortcuts/Siri, Control Center, Widgets) — surfaces no Plaid SaaS competitor does well.
4. **Upgrading already-shipped features with real Plaid data** (Liabilities: APR, due dates, statement balance) and **forward-looking cash flow** (the #1-rated differentiator of Simplifi), all on-device.

## Research signal (what users actually say)

- **Post-Mint trauma → subscription fatigue + privacy distrust.** Refugees resent paying $95–180/yr "to see my own money" and a vocal cohort explicitly wants on-device-only data — VaultPeek's exact posture.
- **Plaid is the universal pain point.** Constant reconnect/re-auth churn, silent missing/duplicate transactions, distrust of a third party holding credentials. VaultPeek can't remove Plaid but can be radically more transparent about connection health and what stays local.
- **Glanceable beats full budgeting.** A wave of menu-bar micro-apps (Runtab, Balance Bar, Redline, StockBar) proves ambient one-glance demand — validating the north star and exposing concrete gaps (menu-bar title customization, reconnect transparency, balance snapshots, widgets/Control Center).
- **Competitor lessons:** Copilot = design benchmark, weak on sync reliability (local-first fixes this); Simplifi = safe-to-spend + 12-mo projection is its #1 differentiator; Monarch = Sankey flow + customizable dashboard "addictive"; MoneyMoney = local-encrypted-DB trust + AppleScript loyalty; Lunch Money = dev cult following via API/CLI + CSV-only option.

## Top 5 (scored, recommended)

| Rank | Idea | Score | Why it wins | Smallest first slice |
|------|------|-------|-------------|----------------------|
| 1 | **Signal Glyph** (menu-bar icon as a live meter) | 4.6 | Purest expression of the RepoBar north star; converts click-to-open into an ambient instrument; dim-when-stale ties to the trust thesis. The icon is the most underused real estate the product owns. | Render one hardcoded signal (highest credit utilization) as a 2-bar template meter in the existing `NSStatusItem`, dim-when-stale wired to the current stale flag. No config UI yet. |
| 2 | **Connection Health Strip** | 4.6 | Attacks the #1 documented abandonment cause (broken Plaid connections); the inverse of Copilot's top praise. Ensures the glanceable number is never silently wrong. | Per-item status row in the popover (Connected / Needs attention / Bank outage) from existing item-health data + a proactive notification on `ITEM_LOGIN_REQUIRED`. Repair flow second. |
| 3 | **Finance App Intents bundle** | 4.6 | One bundle lights up Spotlight + Shortcuts + Siri at once, all local against `PlaidBarCore`. "Ask Siri your finances, answered without the cloud" — positioning no Plaid suite offers. | Ship a single `GetSafeToSpendIntent` as an AppShortcut returning a snippet via existing Core formatters. Add `AccountEntity` + more intents next. |
| 4 | **Payments Due (Plaid Liabilities)** | 4.53 | Closes the biggest Plaid data gap — utilization is shown but APR/statement/due-date are invented. High-ROI decision data, stored as a daily on-device snapshot. | Request Liabilities scope at Link, fetch `/liabilities/get` on the daily sync, surface real APR + "next due date" next to one utilization gauge. Notifications follow. |
| 5 | **Projected Balance Line** | 4.53 | Extends shipped safe-to-spend + recurring detection into Simplifi's #1 differentiator (forward cash flow), fully on-device, without crossing into envelope budgeting. | Compute a 30-day projected-balance series in `PlaidBarCore` (balance − upcoming detected recurring outflows); render a dashed "forecast" line extending the existing trend chart. |

## All ideas by cluster (scored)

### Glanceable Menu-Bar Instrument
- **Signal Glyph** — 4.6 · icon as live meter/sparkline encoding one chosen signal; dims when stale.
- **Menu-Bar Title Picker** — 4.4 · choose the number in the title (cash / spend / safe-to-spend / utilization / net) + one-tap privacy-mask.
- **Summon Hotkey + Card Pinning** — 4.07 · global hotkey to summon popover anywhere; reorder/pin top summary cards.

### Trust & Data Integrity
- **Connection Health Strip** — 4.6 · per-item Connected/Needs-attention/Bank-outage + one-click update-mode repair.
- **Stale-Data Integrity Badges** — 4.53 · "data may be incomplete since <date>" on derived numbers when a sync has gaps; never color-alone.
- **Where Your Data Lives panel** — 4.53 · one-screen trust explainer (127.0.0.1, Keychain, local SQLite, no telemetry) + Plaid scope/deletion deep link.
- **Balance Time Machine (snapshot ledger)** — 4.33 · user-owned "what the bank said" snapshots + "what changed since last sync" diff.
- **Portable Export & Backup** — 3.93 · CSV/JSON export + documented SQLite path. "No shutdown can strip your data."

### Plaid Data Depth
- **Payments Due (Liabilities)** — 4.53 · real statement balance, minimum payment, due date, purchase APR.
- **Real Merchants (Enrich + PFCv2)** — 4.4 · Plaid confidence-scored categories + cached merchant logos; feed confidence into the Review Inbox.
- **Forgotten Subscription Finder** — 4.07 · flagship recurring view with "you may have forgotten this" + price-increase/trial-jump flags.
- **Live Balance Refresh** — 3.8 · back manual refresh with `/accounts/balance/get` for a genuinely live balance.
- **Net Worth Completion (Investments balance line)** — 3.73 · investments as a new filter, **balance line only** (no holdings/performance — stays inside non-goals).

### Forward-Looking Cash Flow (decision-grade, not budgeting)
- **Projected Balance Line** — 4.53 · 30–90 day on-device projection with predicted lows.
- **Pending-Aware Safe-to-Spend** — 4.53 · pending vs posted explicit; fold pending holds + optional pinned obligations into the math.
- **Income → Category Flow (local Sankey)** — 3.93 · read-only Swift Charts flow view for one period.
- **Watchlists** — 3.4 · per-merchant/category nudges via existing notifications (behavior nudge, not envelope budgeting).

### Native macOS Platform Leverage (Tahoe spine)
- **Finance App Intents bundle** — 4.6 · GetSafeToSpend / GetBalance / NextRecurringBills / CreditUtilization → Spotlight + Shortcuts + Siri.
- **Glanceable Widgets** — 4.07 · WidgetKit small/medium (balance / spend sparkline / safe-to-spend) from App Group cache.
- **Control Center Controls** — 4.0 · pinnable ControlWidgets (Safe-to-Spend, Utilization).
- **Spotlight Account Index** — 3.6 · index display names only (never balances) deep-linking into views.
- **Focus-Aware Privacy** — 3.13 · `SetFocusFilterIntent` auto-engages Privacy Mask in Work/shared Focus.

### On-Device Intelligence & Developer Surface
- **Zero-Setup NL Categorization tier** — 4.27 · Apple NaturalLanguage/Core ML default tier so users get smart categorization without installing Ollama.
- **Subscriptions Calendar** — 3.8 · month grid of recurring charges on due dates.
- **vaultpeek CLI** — 3.6 · bundled local CLI over the Hummingbird API (status / spend / bills / export) — a moat with the RepoBar/CodexBar crowd.
- **Local Take-Home Glance** — 3.4 · on-device income detection from inflow streams (no Plaid Income product).

### Native Polish
- **Scrub-to-Read Charts** — 3.6 · RuleMark + selection scrubbing + dim-past/future opacity.
- **Liquid Glass Popover Chrome** — 3.33 · `glassEffect`/`GlassEffectContainer` behind `#available(macOS 26)`, keeping numerics high-contrast.

## Cross-cutting areas of improvement

1. **Make staleness a first-class, color-independent design system** used consistently across glyph, derived numbers, charts, widgets, Control Center — never show a confident wrong number.
2. **Surface the trust story as a product surface** (onboarding panel + About link + Plaid scope/deletion deep link), not buried in SECURITY.md — differentiated marketing SaaS incumbents can't match.
3. **Reconcile three categorization engines** into one precedence order (Plaid PFCv2 → Apple NaturalLanguage tier → Ollama deep tier) so the Review Inbox only surfaces genuinely low-confidence items.
4. **Stand up one macOS-26 native foundation** (one App Intents bundle + shared App Group cache) that App Intents, Control Center, Widgets, and Spotlight all reuse — not bespoke per surface.
5. **Harden the popover for the translucent Tahoe menu bar** (legible small template glyph, tabular numerics everywhere, high-contrast over glass, gesture hit-testing that doesn't fight scroll).
6. **Guardrail for non-goal-adjacent features** (Investments balance line, watchlists, subscriptions calendar): stop at the read-only/glance line; never let them grow into envelope budgeting or a portfolio dashboard.
7. **Treat data ownership/portability as baseline trust** (export, documented SQLite path, user-owned snapshots) given Mint-exit trauma.

## Recommended next move

The top three (Signal Glyph, Connection Health Strip, Finance App Intents bundle) are **mutually reinforcing**
and all advance the same thesis: VaultPeek as a *trustworthy ambient instrument*, not just a popover.
A natural first epic is the **macOS-26 native foundation** (improvement area #4) since the App Intents bundle,
Widgets, and Control Center all depend on it.

Scores cluster tightly at the top (three at 4.6) → run `/decision` to sequence the first epic.
The Projected Balance Line carries the most modeling uncertainty → `/what-if` to pressure-test the forecast UX before committing.
