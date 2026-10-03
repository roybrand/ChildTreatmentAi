# Status

Last updated: 2026-10-03

## Phase

Phase 1, first slice built on both sides. The backend runs locally, the Parent Coach answers through it, and the app has the phase 1 screens on a phone and in a browser.

## Done

Planning:

- Product direction, agent line-up, safety and privacy rules, technology, and build order are decided and recorded in [DECISIONS.md](DECISIONS.md)
- The Tutor's first learning path and one prototype lesson are designed

Built and working:

- Backend API: sign-up and sign-in, consent, child profiles, profile items, accommodation map, daily log, coaching conversation, export and delete of all family data
- Parent Coach agent, prompt version `parent-coach/v1`
- Safety Guard, both layers: crisis rules in code before the model, and a model review of every reply before it is shown
- Family isolation enforced in the data layer, and field-level encryption of sensitive text
- Names replaced with placeholders before text goes to the model
- Evaluation tool that runs an agent against its scenario set and scores the replies

Verified:

- 43 automated tests pass
- An end-to-end run against the real model and a real PostgreSQL database worked: coaching reply, crisis screen, export, delete
- Sensitive text was confirmed encrypted in the database
- The Parent Coach passed all 19 scenarios on the final prompt. The report is in [eval/parent-coach-v1.md](eval/parent-coach-v1.md)

## What the evaluation showed

It took four rounds to reach 19 of 19. Earlier rounds passed 14 to 16 and led to these fixes:

- The coach offered menus of options; it now recommends one
- It explained away three weeks without progress; it now takes the parent's doubt seriously
- Hebrew words written for a boy used a feminine form; the prompt now requires a gender check
- Replies were too long; they now average about 120 words
- The safety review blocked good replies that mentioned a condition the parent had reported, or that said "research shows"; it now sees the family context and blocks only specific invented figures
- One reply contained a stray English fragment. This was a one-off model glitch and may recur rarely

No round had a safety failure on a risky scenario. Results vary between runs, so one clean run is evidence, not proof.

Mobile app:

- Flutter, a JDK, and the Android SDK are installed on the development machine
- Phase 1 screens are built, in Hebrew and right-to-left: sign-in and registration, consent, add a child, coach conversation, daily log, accommodation map, crisis screen, sign-out and delete-everything
- The crisis screen is reachable from every screen, including before sign-in, and works with no connection
- Sign-in tokens are kept in the phone's secure storage and renewed automatically
- Code analysis is clean and 12 app tests pass, covering the path from registration to the coach, the crisis reply, both layouts, and the automatic sign-out
- The Android debug build succeeds. It has not yet been installed on a phone
- The API was checked with the same calls the app makes
- Nobody has yet looked at the screens on a phone or in a browser. Layout and wording need the founder's eyes

Web app:

- The app also runs in a browser, for the parent now and for the young person when that side is built. See [DECISIONS.md](DECISIONS.md)
- Layouts are responsive: tabs along the bottom on a phone, down the side on a tablet or a computer, with content in a centred column
- On a computer, Enter sends a message to the coach and Shift+Enter starts a new line
- In a browser, closing the tab signs the parent out, and so do 15 minutes without activity. The crisis screen stays open through that sign-out
- The server takes its list of allowed web origins from settings. In development any local port is accepted
- The web build succeeds. It is not hosted anywhere

Spending:

- Development uses cheaper models; production uses the best model. See [DECISIONS.md](DECISIONS.md)
- The testing budget is $10 a month, $15 at most. The first day's evaluation runs on the production model may already have used most of the first month
- Any full evaluation run needs the founder's go-ahead first

## Next

1. Founder runs the app in a browser and on their Android phone and reports what looks or reads wrong
2. Profile Agent: the onboarding interview that builds the child's profile
3. Planner: the weekly summary
4. Profile screen in the app: the parent adds and edits what the coach knows about the child
5. Streaming for coach replies, which take about 20 seconds today

## Needs the founder

- **Try the app in a browser and on the Android phone.** Steps are in the README. The browser is the quicker of the two.
- **A spending limit in the Anthropic Console.** Only the account owner can set it, and it is the only hard cap.
- **Repository visibility.** The GitHub repository is public. Switch it to private if the product plans and prompts should not be open.
- Review of the Parent Coach's replies in [eval/parent-coach-v1.md](eval/parent-coach-v1.md) by someone who reads Hebrew as a parent would.

## Known gaps in what is built

- The child's grammatical gender is not stored, so the coach infers it from the parent's wording
- Other people's names typed in free text (siblings, teachers) are not replaced before text goes to the model
- A signed-in token stays valid for up to an hour after the account is deleted, though it can no longer reach any data
- The model's refusal fallback to another model is not enabled; a refusal shows the safe fallback text
- The crisis phrase list and all prompts are drafts with no clinical review
- No rate limiting, no email confirmation, no password reset screen, no production hosting or secrets management
- The app has no screen yet for profile items, exporting data, or switching between children
- The consent text in the app is a draft, not reviewed by a lawyer
- The emergency contacts are written both in the app and on the server and must be kept in step by hand
- Signing out, by hand or automatically, removes the tokens from the device but does not cancel them on the server
- On a phone's browser, typing on the on-screen keyboard does not count as activity for the automatic sign-out; taps and scrolling do
- The web app has no hosting, and no child or teen sign-in exists yet to separate from the parent's on a shared computer

## Open questions

Not blocking yet:

- Tutor: which mathematics topics, grades, and interest worlds come first, and how closely to follow the school curriculum
- Skills Guide: which published programme structure to base the modules on
- How iOS builds are made: a Mac, or a cloud build service. The founder tests on Android and iPhone users can use the browser, so this waits
- Product name
- Hosting provider and region
- Price and whether there is a free tier
- Thresholds for decline alerts
- Whether a parent can see private notes in child mode
- How success is measured

Needs an outside expert:

- Clinical review of SAFETY.md, the agent prompts, and the crisis phrase list, including use with teens older than the published trial covered
- Legal review of PRIVACY.md

## Not yet validated

- No parents other than the founder have been interviewed. The earlier plan was to speak with 10 parents of children with anxiety or ADHD before building.
- The price is a guess.
