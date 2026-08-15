# Spec — Plaid Data Depth batch (AND-493 / 494 / 495 / 496)

> Status: **Approved (AC sign-off 2026-06-17)** · awaiting per-unit plan + go.
> Source: `docs/brainstorm-feature-ideas-2026-06-17.md` (cluster "Plaid Data Depth") + a requirements interview.
> Scope rule: lean only — no speculative features, no scope creep past these four issues.

## BLUF

Deepen the Plaid data layer with four units of differing real size (grounded against `main` @ a785cf1):

1. **Payments Due (AND-493)** — *new, largest.* Real credit Liabilities (APR / statement balance / minimum payment / next due date) replacing today's honest `"due not synced"` placeholder.
2. **Real Merchants (AND-494)** — *medium.* Category **confidence** into the Review Inbox + server-cached merchant **logos**. No new Plaid endpoint — the fields ride on the existing `/transactions/sync` response.
3. **Live Balance Refresh (AND-495)** — *small wiring.* Point manual refresh at the already-implemented `/accounts/balance/get`.
4. **Investments balance line (AND-496)** — *verify / likely already shipped.* Investment balances already flow into net worth and a filter exists; verify and close, or do minimal polish.

## Decisions (from interview)

| Decision | Choice | Implication |
|---|---|---|
| Liabilities re-link UX | **New links only + keep placeholder** | Request `liabilities` for new links; items without the scope keep utilization-only (no regression). Server handles "no scope" gracefully (`PRODUCT_NOT_SUPPORTED`/`PRODUCTS_NOT_READY` → treat as no data). No per-item migration UX. |
| Merchant logos | **Server-side fetch + local cache** | Server (already talks to Plaid) fetches logo images from Plaid's CDN, caches under the local data dir, serves via localhost. App stays localhost-only. Documented in the trust panel. |
| Liabilities storage | **[default] latest-only, not snapshot history** | Store the current statement/due/APR per credit account. A daily snapshot *ledger* is a separate feature (AND-490). |
| Payment-due notifications | **[default] out of scope this batch (fast-follow)** | Display first; reminders reuse the existing notification infra later. |
| Category confidence behavior | **[default] surface low-confidence as a Review Inbox reason** | Do NOT auto-recategorize; low/unknown confidence feeds the existing `uncategorized`-style review signal. |

## Grounded current state (key seams)

- **Link products:** only `["transactions"]` (`PlaidLinkConfiguration.swift:19`, env `PLAID_LINK_PRODUCTS`). `liabilities`/`investments` already in the supported allowlist (`:200-206`); `transactions` is mandatory (`:123`). Products are **not persisted per item** (`ItemModel`, `Database.swift`) → re-link needed for new scopes.
- **PlaidClient** (`PlaidClient.swift`): implements `/accounts/get`, `/accounts/balance/get`, `/transactions/sync`, link/exchange/remove. **Missing:** `/liabilities/get`, `/investments/holdings/get`.
- **Credit "invented" numbers:** utilization is **real** (`MenuBarSummary.swift:53-63`, from `limit`+`current`). APR / due date / statement / min payment are **not synced** — `AccountPresentation.swift:105-112` renders a hardcoded `"due not synced"`. This is the UI seam to fill.
- **Transactions:** PFCv2 `primary` → `SpendingCategory` (`TransactionRoutes.swift`); `PlaidCategory.confidenceLevel` is decoded but **discarded**; `logo_url`/`counterparties` are **not decoded** (`PlaidModels.swift` `PlaidTransaction`). `TransactionDTO` has no confidence/logo field. Review Inbox heuristics + insertion point at `TransactionReview.swift:229-231`.
- **Refresh:** manual `refreshAccounts()` calls `getAccounts()` (`AppState.swift:1489`); a `getBalances()` path exists (`:1523`). Auto refresh throttled twice/day (`AutomaticRefreshPolicy.swift`). No server cron — everything client-driven.
- **Investments:** investment accounts counted in net worth (`MenuBarSummary.netCash`), `.investment` presentation exists (`AccountPresentation.swift:207`), and an `"investments"` filter exists (`WealthSummaryFlyout.swift:373`).

## Verified Plaid API references

- **`/liabilities/get`** → `liabilities.credit[]`: `aprs[]` (`apr_percentage`, `apr_type` ∈ {purchase_apr, balance_transfer_apr, cash_apr, special}; array may be **empty**), `last_statement_balance`, `last_statement_issue_date`, `minimum_payment_amount`, `next_payment_due_date`, `last_payment_amount`, `last_payment_date`, `is_overdue`. (`/websites/plaid_api`, plaid.com/docs/api/products/liabilities)
- **Enrichment rides on `/transactions/sync`** (no `/transactions/enrich` needed): transaction-level `logo_url`, `website`, `merchant_name`, `merchant_entity_id`, `counterparties[]` (`name`,`type`,`logo_url`,`website`,`confidence_level`), `personal_finance_category.confidence_level` ∈ {VERY_HIGH, HIGH, MEDIUM, LOW, UNKNOWN}, `personal_finance_category_icon_url`.

---

## Units & acceptance criteria

### Unit 1 — Payments Due (AND-493)
**User value:** the credit card shows real statement balance, minimum payment, next due date, and purchase APR instead of `"due not synced"`.

**AC**
- [ ] Link requests `liabilities` for **new links only**; items lacking the scope keep utilization-only with **no regression**. A `/liabilities/get` call for an unscoped item is handled gracefully (no error surfaced; placeholder retained).
- [ ] New `PlaidClient.getLiabilities` → `/liabilities/get`; new `LiabilitiesRoutes`; latest liabilities stored per credit account (**latest-only**).
- [ ] New `LiabilityDTO` (Core) carries: purchase APR, statement balance, statement issue date, minimum payment, next due date, last payment amount/date, is-overdue.
- [ ] Credit account detail replaces the placeholder with **purchase APR + next due date + statement balance + minimum payment**; a "Payments Due" summary shows the **soonest** due date across cards.
- [ ] Empty `aprs[]` / missing fields degrade gracefully (omit the field, never show 0% or a fake date).
- [ ] Due-soon / overdue never communicated by **color alone** (`ACCESSIBILITY.md`).
- [ ] Demo fixtures include liabilities so the UI is exercisable via `--demo`.
- **Out of scope:** payment-due notifications; per-item "reconnect" prompt; snapshot history.
- **Files:** `PlaidLinkConfiguration`, `PlaidClient`+`PlaidModels`, new `LiabilitiesRoutes`, `LiabilityDTO`, latest-liability storage, `AccountPresentation.swift:105-112`, credit UI, demo fixtures. **API:** `/liabilities/get`.

### Unit 2 — Real Merchants (AND-494)
**User value:** the Review Inbox stops flagging confidently-categorized transactions, and merchants show real logos.

**AC**
- [ ] Preserve `personal_finance_category.confidence_level` (currently discarded) → new `categoryConfidence` on `TransactionDTO`, set in the server transform.
- [ ] `TransactionReview.evaluate` treats **LOW/UNKNOWN** confidence as a review signal and **does not** flag VERY_HIGH/HIGH items that today trip the `uncategorized`/`newMerchant` heuristics. **No auto-recategorization.**
- [ ] Decode transaction `logo_url` → server **fetches + caches** the image under the local data dir (best-effort, deduped by URL/merchant); a localhost endpoint serves cached logos; the app loads logos **only from localhost**.
- [ ] Missing/failed logo → monogram/SF Symbol fallback; logo fetch never blocks sync or the UI.
- [ ] Trust / "Where Your Data Lives" copy documents that the **server** fetches logo images from Plaid's CDN.
- **Out of scope:** counterparties beyond the primary merchant; category icon URLs.
- **Files:** `PlaidModels`+`TransactionRoutes` (decode/transform), `TransactionDTO`, `TransactionReview.swift:229-231`, new server logo cache + endpoint, app logo view, trust copy. **API:** existing `/transactions/sync` fields (no new endpoint).

### Unit 3 — Live Balance Refresh (AND-495)
**User value:** a manual refresh reflects a genuinely live balance, not Plaid's cached one.

**AC**
- [ ] Manual ("force") refresh uses `/accounts/balance/get` (live) for balances; automatic throttled refresh is **unchanged** (no extra Plaid balance calls on auto ticks — cost control).
- [ ] No UI regression; balances reconcile with the accounts list.
- **Files:** `AppState.refreshAccounts` / `RefreshService` wiring. **API:** existing `/accounts/balance/get` + `serverClient.getBalances()`.

### Unit 4 — Investments balance line (AND-496)
**User value:** investment account balances are visible in net worth and as a filter.

**AC**
- [ ] Verify with a sandbox investment item that investment-type accounts return via `/accounts/get` (no investments product needed for balance-only), are counted in net worth, and appear under the existing `investments` filter.
- [ ] **If already satisfied → close AND-496 as done with evidence.** If a gap exists, minimal balance-line polish only (no holdings/positions/performance — non-goal).
- **Files:** likely none, or `WealthSummaryFlyout` polish.

---

## Dependencies & sequencing

- Units 1 & 2 both touch `PlaidModels` + the server routes area, but **different structs/routes** (liabilities vs transactions) → mergeable with light coordination.
- Units 1 (liabilities fetch on refresh) & 3 both touch the refresh path → **sequence 3 before/with 1**.
- Suggested order: **3 → 1 → 2 → 4** (or 4 first if it closes immediately). Not fully parallel — accepted when the cluster was chosen.

## Implementation-time verifications (do during build, per workflow step 2)

- Exact Plaid → DTO field mapping for liabilities (Swift `Decodable` against sandbox payloads).
- Confidence threshold wording (LOW vs LOW+UNKNOWN) once seen against sandbox data.
- Logo cache: storage path under `~/.vaultpeek/`, eviction/size cap, and that the localhost logo endpoint is auth-gated like other `/api/*` routes (or intentionally open like `/health`).
- Sandbox can exercise Liabilities + enriched transactions (custom sandbox user if needed).

## Non-goals (guardrails)

No envelope budgeting, no investment holdings/performance, no app→external-host calls (logos are **server**-fetched), no payment automation. Investments stays a balance line; merchants stay display-only.
