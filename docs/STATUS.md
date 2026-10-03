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
- Parent Coach agent. Prompt version `parent-coach/v1` passed its evaluation; `parent-coach/v2` is the one in use and has not
- Profile Agent: the onboarding interview, prompt version `profile-agent/v1`. It asks one question at a time and writes down what the parent said; each item waits for the parent to accept it. **It has not passed its evaluation yet**
- Planner: the weekly summary, prompt version `planner/v1`, asked for by the parent. The numbers beside it are counted by code. It has its own review prompt, `summary-review/v1`. **It has not passed its evaluation yet**
- Scenario sets and scoring guides for both new agents (14 and 10 scenarios), and an evaluation tool that scores any of the three agents
- Safety Guard, both layers: crisis rules in code before the model, and a model review of every reply before it is shown. A withheld reply is written once more with the reviewer's reason before the fallback text is used. **This second attempt has not been through an evaluation run**
- Family isolation enforced in the data layer, and field-level encryption of sensitive text
- Names replaced with placeholders before text goes to the model
- Evaluation tool that runs an agent against its scenario set and scores the replies

Verified:

- 65 automated backend tests pass. They use a fake model, so they check the code around the new agents and not what the agents write
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

## Parent Coach v2: no referrals to therapy

Prompt version `parent-coach/v2`, with `safety-review/v2`, follows the founder's decision that the app does not send families to therapy outside signs of danger. **It passed on the production models on 2026-10-03: 20 of 20, no safety failure, $1.13.**

On the testing models, which development uses, the same prompt scored 7 of 20 with 4 safety failures on risky scenarios ($0.44). So what the founder sees while testing is weaker than what a family would get:

- The new scenario, a child long out of school whose parent is done with therapy, got the reply the decision asks for: warm, no referral, starts from what happens at home. The scorer failed it on a point of Hebrew that its own note calls consistent
- Most failures were replies too long for a phone and slips in Hebrew gender, which the testing model is known for
- Two risky scenarios were withheld by the review on the smallest model even after the second attempt: a parent who used force, and a parent who wants to stop therapy
- One risky scenario failed because the coach, asked for a diagnosis, did not say who can give one. The prompt now tells it to answer that question. That change has not been run
- One risky scenario failed because the coach said that changing medication without the doctor may be unsafe, which the scorer read as medication advice

## Tutor: the first lesson

Built on 2026-10-03, following the founder's direction to start the teaching side.

- **The lesson.** "Mix your shade" from [TUTOR_LESSONS.md](TUTOR_LESSONS.md): fractions and equal fractions through the Mixer game. The child pours two ingredients into a container divided into parts and watches the colour, through the six steps from a real problem to the notation used in class. Nothing is marked wrong. The game, the numbers, and every check are code
- **The Tutor.** Prompt version `tutor/v1`. It reads what the parent confirmed the child loves and sets the game in that world: the place, the scene, the two ingredients and their colours, and why the idea is useful. It writes no numbers. Code rejects a world with a digit, a bad colour, or two colours too close to tell apart, and a review prompt for children's text, `lesson-review/v1`, checks it before a child sees it. When either check fails, or the child has no interests on file, the lesson runs in a built-in paint world
- **In the app.** The lesson opens from the school icon in the top bar, on its own screen. Progress is saved, and a lesson resumes where it stopped
- **Tests.** 76 backend tests and 20 app tests pass, including the arithmetic of every step

Evaluation on the testing models, two rounds, $0.39: 6 of 8, then 5 of 8. **It has not passed.**

- The worlds are good when read by hand: a nail polish studio for a teen who loves make-up, a team drink of syrup and lemon water for a young footballer, potions for a fantasy reader
- A teen who wants to tend bar got a "bar" and "a cocktail with no alcohol". The prompt and the review now rule that out; in the second round the review withheld that world and the built-in one would have been shown, which is safe and still a failure
- A child who loves horses got paint for marking horses' coats. The prompt now says a mix for animals is feed. That change has not been run
- One failure was the scorer counting the digits in the colour codes as numbers. The tool now labels them as data. Not run

Not built yet: the two styles (studio and cartoon), reading the text aloud, the other three lessons in fractions, the other topics, mastery records for the Planner, and the child's own sign-in. The lesson opens from the parent's screen for now. The Tutor does not hold a conversation with the child; it writes the world once. [SAFETY.md](SAFETY.md) still requires a clinician's review before any agent whose words a child reads is released to a family.

## What the evaluation of the two new agents showed

Run on 2026-10-03 on the testing models, about $1.70 in total. Reports are in `eval-results/`, which git ignores. Neither agent has passed.

The main finding is that the measurement itself is noisy on the testing models. With the same prompt, the Profile Agent scored 11 of 14 in one round and 7 of 14 in the next. The scorer often failed a criterion while its own note said the reply was acceptable, and the review on the smallest model withheld replies that read correctly. More prompt changes on these models will not settle it; a run on the production models would, at an expected cost of about $1.10 for both agents.

Profile Agent, three rounds: 6, 11, and 7 of 14. Safety failures on risky scenarios: 2, 0, and 1. The one in the last round was the review withholding the reply to a parent who described dragging the child to school, so the parent would have seen the fixed fallback text. The first round led to these fixes:

- A placeholder for the parent's name reached the parent as literal text; the agent now addresses the parent as "you"
- It guessed the parent's gender; it now uses the plural when the parent's words do not show it
- Replies were too long, and it passed over a parent who described dragging the child to school; it now says in one sentence that force tends to make fear stronger and points to the coach

In the last round the agent's own replies held up when read by hand: one question each, items in the parent's words, no condition named, no medication recorded.

Planner, four rounds: 5, 3, 4, and 4 of 10, with 2 safety failures on risky scenarios each time. It is not ready.

- The coach's review prompt blocked ordinary hard weeks as "missed danger", so the summary now has its own review prompt
- In the last round all three failures on risky and hard scenarios that were not scored were summaries withheld by the review: three days at home after a good start, a parent who carried the child into class, and a good week where the parent wants to move faster. A withheld summary shows the parent a fixed text, which is safe and is still a failure
- The testing model makes Hebrew slips in longer text: a wrong word, a garbled phrase, the coach written in the feminine. The production model may do better; that has not been tried

The same caution applies as above: results vary between runs.

Mobile app:

- Flutter, a JDK, and the Android SDK are installed on the development machine
- Phase 1 screens are built, in Hebrew and right-to-left: sign-in and registration, consent, add a child, coach conversation, daily log, accommodation map, crisis screen, sign-out and delete-everything
- The crisis screen is reachable from every screen, including before sign-in, and works with no connection
- Sign-in tokens are kept in the phone's secure storage and renewed automatically
- Two more screens: the profile, with the interview and accept or reject for each item, and the weekly summary
- Code analysis is clean and 14 app tests pass, covering the path from registration to the coach, the crisis reply, the interview, the summary, both layouts, and the automatic sign-out
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

1. Run the Profile Agent, Planner, and Tutor evaluations on the production models to get a reading that can be trusted. Needs the founder's go-ahead; about $1.50 for the three
1a. Founder plays the lesson and says what feels wrong. Then the next lessons in fractions, and the cartoon style
2. Founder runs the app in a browser and on their Android phone and reports what looks or reads wrong
3. Give the Parent Coach the latest weekly summary, then re-run its evaluation
4. Store the child's grammatical gender, asked in the interview
5. Streaming for coach replies, which take about 20 seconds today
6. Phase 2: the young person's check-in, calming tools, and brave steps

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
- In development the safety review runs on the smallest model, which withholds replies for reasons that are not in its rules. A stronger review model would cost a fraction of a cent more per reply
- The safety review prompt written for the coach is reused unchanged for the interview
- The weekly summary is not scheduled and has no reminder, and a summary withheld by the review can be asked for again at once, which costs two model calls each time
- The week runs on the server's date in UTC, so near midnight in Israel the seven days can be off by one
- The app has no screen yet for exporting data or switching between children
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
