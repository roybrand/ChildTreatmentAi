# Status

Last updated: 2026-10-03

## Phase

Phase 1, first slice built. The backend runs locally and the Parent Coach answers through it. There is no mobile app yet.

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

## Next

1. Install Flutter and scaffold the mobile app (needs the founder, see below)
2. Profile Agent: the onboarding interview that builds the child's profile
3. Planner: the weekly summary
4. Mobile screens for phase 1: sign-in, consent, onboarding, accommodation map, daily log, coach conversation, crisis screen
5. Streaming for coach replies, which take about 20 seconds today

## Needs the founder

- **Flutter is not installed on this machine.** Installing it is a large download and changes the system path, so it waits for a go-ahead.
- **Which phone for testing:** iPhone, Android, or both.
- Review of the Parent Coach's replies in [eval/parent-coach-v1.md](eval/parent-coach-v1.md) by someone who reads Hebrew as a parent would.

## Known gaps in what is built

- The child's grammatical gender is not stored, so the coach infers it from the parent's wording
- Other people's names typed in free text (siblings, teachers) are not replaced before text goes to the model
- A signed-in token stays valid for up to an hour after the account is deleted, though it can no longer reach any data
- The model's refusal fallback to another model is not enabled; a refusal shows the safe fallback text
- The crisis phrase list and all prompts are drafts with no clinical review
- No rate limiting, no email confirmation, no production hosting or secrets management

## Open questions

Not blocking yet:

- Tutor: which mathematics topics, grades, and interest worlds come first, and how closely to follow the school curriculum
- Skills Guide: which published programme structure to base the modules on
- How iOS builds are made: a Mac, or a cloud build service
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
