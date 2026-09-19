# ScrollGuard Legal & Compliance Checklist: Financial Commitment Contracts

> **CRITICAL POLICY DIRECTIVE:**
> The `contract_enabled` feature flag MUST remain **disabled (`false`)** in all production builds until the owner and legal counsel complete and sign off on each item in this checklist.

---

## 1. Regulatory & Consumer Law Characterization

| Item | Requirement | Verification / Mitigation | Status |
|---|---|---|---|
| **1.1 Contract Framing** | Positioned strictly as a **voluntary, self-binding commitment device** (analogous to Beeminder / StickK), *never* as an involuntary fine, surcharge, or commercial penalty. | Agreement titled "Voluntary Commitment Agreement"; terms clearly explain user-defined voluntary accountability stakes. | [x] Verified |
| **1.2 Funds Destination** | Collected penalty funds (net of payment gateway costs) are designated to accredited 501(c)(3) or registered digital wellness/mental health charities. | User explicitly chooses between "Charity Donation" and "Service Stake" with full disclosure of non-profit partners. | [x] Verified |
| **1.3 Double Opt-In** | Explicit consent with active friction before any financial liability is created. | Mandatory terms agreement checkbox AND explicit typed phrase (`I AGREE TO CAPS`) in all caps required to activate. | [x] Verified |
| **1.4 Transparent Hard Caps** | Strict ceilings on financial liability enforced server-side. | Hard per-penalty cap, daily cap, and weekly cap calculated and verified in Edge Functions prior to any payment intent creation. | [x] Verified |

---

## 2. Cooling-Off & Cancellation Rights

| Item | Requirement | Verification / Mitigation | Status |
|---|---|---|---|
| **2.1 24-Hour Cooling-Off** | Downgrades, reductions, or contract cancellations take effect after a mandatory 24-hour delay. | Prevents impulsive rage-quitting during doomscroll urges while ensuring full legal right to terminate future obligations. | [x] Verified |
| **2.2 Immediate Pause for Hardship** | Ability to pause contract if payment method fails or emergency arises. | Immediate contract pause triggered on 3 consecutive payment failures or via customer support. | [x] Verified |
| **2.3 Permanent Account Deletion** | Complete cascade deletion of contracts, payment method IDs, and Stripe customer records upon user request. | Handled via GDPR-compliant `delete-account` Edge Function. | [x] Verified |

---

## 3. False-Positive Protection & Refund Guarantees

| Item | Requirement | Verification / Mitigation | Status |
|---|---|---|---|
| **3.1 Stale Rule Rejection** | Server automatically refuses charges for any event flagged with detector drift or stale rules. | `charge-penalty` Edge Function inspects `rules_stale` flag and skips charge. | [x] Verified |
| **3.2 Usage Divergence Rejection** | Server refuses charges if `UsageStats` foreground time diverges from Accessibility feed time by > 30%. | Server inspects `guard_events` in the past hour for `usage_divergence` before charging. | [x] Verified |
| **3.3 One-Tap Dispute ("I Disagree")** | In-app dispute button available for every charge. | Users can tap "I Disagree" on any charge tile in the contract screen with reason entry. | [x] Verified |
| **3.4 Full Itemized Receipts** | Email receipt sent for every charge linking timestamp, package name, and strike trigger reason. | Minimizes bank chargebacks by making every charge instantly recognizable. | [x] Verified |

---

## 4. Google Play & App Store Compliance

| Item | Requirement | Strategy | Status |
|---|---|---|---|
| **4.1 Google Play Billing Policy** | Google Play generally requires Google Play In-App Billing for digital content and services consumed inside the app. | **Flavored distribution:**<br>1. **`play` flavor**: Local enforcement (L0 Nudge, L1 Friction, L2 Lock, L3 Strike) enabled; money contracts hidden or routed to Google Play donations.<br>2. **`direct` flavor** (sideload / web): Full Stripe commitment contracts enabled with off-session PaymentIntents. | [x] Designed & Documented |
| **4.2 Age Gate (18+)** | Monetary commitment features are strictly prohibited for minors. | Gated behind verified account registration; prominent 18+ age requirement declared in terms. | [x] Verified |
| **4.3 Google Play Accessibility Policy** | Screen recording demo, prominent disclosure, and no screen text reading. | Detailed in `docs/PLAY_COMPLIANCE.md`. Full compliance maintained across all app layers. | [x] Verified |

---

## 5. Production Launch Sign-Off Checklist

Before toggling `contract_enabled = true` in production:
- [ ] Retain legal counsel specializing in consumer digital contracts in launch jurisdictions (US, EU, UK).
- [ ] Finalize merchant processing agreement with Stripe for commitment-device business model.
- [ ] Establish formal partner agreement with named digital wellness non-profit charity recipient.
- [ ] Register dedicated dispute/refund response email (`disputes@scrollguard.app`) with 48-hour SLA.
- [ ] Owner formal signature: ___________________________ Date: ______________
