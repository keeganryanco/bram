# Competitor Learnings

This document tracks what Bram can learn from adjacent workout apps without copying their product shape. The goal is to keep Bram notes-first while improving onboarding, paywall conversion, subscription operations, Health integration, and the perceived polish of the brand.

## Product Principle

Bram should not become a routine builder, social tracker, or spreadsheet UI. The core experience stays:

> Write your workout. Bram tracks the rest.

Competitor ideas are useful only when they make that promise clearer, faster, calmer, or more valuable.

## Fitbod

### What Stands Out

- Onboarding feels more like a guided story than a form.
- The paywall is cleaner and easier to scan.
- Yearly is positioned as the preferred default.
- Monthly/yearly selection uses a simple toggle-style choice.
- The trial length is more generous than Bram's current 3 days.
- Pricing is materially higher than Bram's current launch pricing, which makes Bram's current price feel conservative.
- Purchase management appears to support web-based subscription management while still offering in-app purchase as an option.

### Onboarding Psychology

Fitbod's onboarding works because it gives users a sense that the app is building something for them. The screens feel like a sequence of commitments:

- "Tell us about you."
- "Tell us how you train."
- "Here is the plan/value we built from that."
- "Start with the app now."

Bram should use that same psychological arc, but adapted to notes-first tracking:

- Start with the user's current habit: Notes, paper, spreadsheet, or memory.
- Show that Bram understands natural workout writing.
- Connect that writing to durable outcomes: PRs, history, streaks, progress, next targets.
- Make the user feel like Bram is remembering their training before the paywall appears.

The story should pull Bram's value forward earlier. Users should not have to imagine what the app does after onboarding; they should see the note-to-progress loop before they are asked to pay.

### Paywall Learnings

Bram can improve the paywall before changing price or trial length:

- Make yearly feel like the obvious plan without making monthly feel hidden.
- Use a segmented yearly/monthly selector instead of stacked product cards if it reads cleaner.
- Keep the primary CTA focused on trial language, e.g. `Try Bram free`.
- Explain value as the outcome of notes-first logging, not as a generic feature list.
- Consider allowing vertical scroll if it makes the page more convincing and more premium.

Future pricing/trial ideas to revisit:

- Move from 3-day trial to 7-day trial once launch review and baseline conversion are stable.
- Consider whether a longer trial, potentially 14-30 days, improves habit formation enough to justify delayed revenue.
- Revisit pricing from the current `$7.99/mo` and `$49.99/yr` toward a higher premium position, potentially closer to `$12.99/mo` and `$75.99/yr`, after Bram's perceived value and retention justify it.

Do not change trial length or pricing until explicitly decided.

### Website Purchase Path

Website-first subscription routing is strategically important because it can improve margin and make promo/referral management easier. The product target would be:

- User can subscribe on the website.
- App recognizes web subscription access through Supabase/RevenueCat/Stripe-backed account entitlement.
- Settings `Manage Subscription` opens the correct management surface:
  - Apple subscription -> App Store subscription management.
  - Web subscription -> authenticated web billing portal.
- Promo codes and referral credits are easier to operate through the web billing system.

Policy constraint: Apple's current App Review Guidelines allow external purchase links in the United States storefront, while other regions may require specific StoreKit External Purchase Link entitlement behavior or may prohibit direct external purchase calls to action. Apple also tells users that external purchases are not managed by Apple and do not appear in App Store purchase history. This needs a dedicated compliance pass before implementation.

Technical planning questions:

- Stripe or RevenueCat Web Billing as source of truth?
- How do we unify Apple and web entitlements in Supabase without double-unlocking or ambiguous subscription status?
- How do we prevent web promo access from triggering App Review 3.1.1 issues in unsupported regions?
- How should Settings route management based on entitlement source?
- What copy makes the difference between Apple-managed and web-managed subscriptions clear without making the app feel complicated?

## Hevy

### What Stands Out

- Paywall includes reviews/social proof.
- Analytics and workout history feel strong.
- Starting/logging a workout can connect with Apple Health/Fitness behavior.
- Live workout notification behavior makes the workout feel active and system-integrated.

### Paywall Reviews

Reviews are a high-leverage paywall asset because they reduce risk. A user deciding whether to pay is not only asking "does this have features?" They are asking:

- "Do people like me actually use this?"
- "Will this fit my workout style?"
- "Is this app polished enough to trust with my training history?"
- "Will I regret subscribing?"

Bram should consider adding reviews once there are enough real reviews worth showing. This may justify a scrollable paywall if the layout feels premium and deliberate.

Possible review formats:

- One compact quote card under the main CTA/product selector.
- A horizontal carousel of 2-3 short reviews.
- A "Loved by lifters who used to track in Notes" review section.
- Short App Store review snippets with star treatment, if legally and visually clean.

Rules for Bram:

- Use real user/App Store review text only.
- Keep each review short and specific.
- Avoid generic praise.
- Prefer reviews that reinforce Bram's core positioning: easy like Notes, actually remembers progress.
- Do not let reviews push the paywall into marketing-page clutter.

### Apple Health Workout Tracking

Hevy's Health integration suggests a larger Bram opportunity: when the user is actively working out, Bram should feel connected to the workout, not just a passive note editor.

Potential future behavior:

- Bram detects a likely active workout when the user is writing sets over time rather than pasting a completed note.
- Bram starts or suggests starting an Apple Health workout session when appropriate.
- A Live Activity or live notification shows workout duration and basic state.
- The live notification includes a lightweight action like `Not tracking` so users can correct Bram if they are backfilling.
- Bram learns from that feedback and gets better at distinguishing active tracking from historical logging.

This could improve:

- Workout duration accuracy.
- Apple Health integration depth.
- Calorie estimates.
- Recovery/readiness context.
- User trust that Bram understands what is happening now.

The hard product problem is preserving Bram's simple main screen. The main note UI should not become crowded with start/stop workout controls. The live notification/Live Activity may be the right place for tracking state because it lets Bram be active without adding permanent UI.

### Tracking vs Logging Heuristic

Bram needs a learning layer around workout state:

- Fast paste or multi-exercise note completion likely means backfill/logging.
- Slow set-by-set writing over several minutes likely means active tracking.
- Health workout already active likely means tracking.
- User taps `Not tracking` from a live notification -> lower future tracking confidence in similar contexts.
- User accepts Health/live tracking prompts -> raise future tracking confidence.

This should be privacy-safe and local-first where possible. Analytics should only track coarse state transitions, not note text.

## Bram Opportunities

### Onboarding

Make onboarding feel like a story:

1. The user's current workout tracking habit is valid.
2. Bram understands natural workout notes.
3. Bram turns notes into progress history.
4. Bram can use goals, Health, and reminders as context.
5. The paywall feels like the natural next step after the user sees the loop.

Avoid:

- More form density.
- Overexplaining AI.
- More disclaimers.
- Screens that feel like settings before the user has felt value.

### Paywall

Near-term without price changes:

- Improve visual hierarchy.
- Prefer yearly more clearly.
- Consider toggle-based plan choice.
- Add review/social proof once there are real reviews.
- Keep trial framing simple.
- Make the copy feel Bram-specific, not generic premium app copy.

Later:

- Test 7-day trial.
- Revisit pricing.
- Evaluate website-first subscriptions and billing portal.

### Apple Health and Live Workout State

Longer-term:

- Add active workout detection.
- Explore Live Activity/live notification behavior.
- Consider Apple Health workout session write/start support.
- Let users correct tracking state without adding heavy main-screen controls.

### Algorithm/Product Coherence

The simpler Bram's UI gets, the more coherent the backend logic has to be. If the UI stays nearly invisible, Bram has to be very good at:

- Parsing natural workout notes.
- Understanding active vs backfilled workout state.
- Resolving exercise identity.
- Knowing when suggestions are useful.
- Learning user routines and split patterns.
- Using Health context without making the app feel clinical.

## Open Decisions

- Do we move to a 7-day trial, and when?
- Do we raise monthly/yearly pricing before or after the next paywall pass?
- Do we keep a no-scroll paywall or allow a premium scrollable paywall with reviews?
- Do we use RevenueCat Web Billing, Stripe, or another web billing setup?
- Do we pursue external purchase links only for U.S. storefront first?
- What is the minimum viable version of live workout tracking that does not compromise the notes-first UI?

## References

- Apple App Review Guidelines, section 3.1.1 and external purchase link rules: https://developer.apple.com/app-store/review/guidelines/
- Apple user-facing explanation of external purchases: https://support.apple.com/en-us/118126
