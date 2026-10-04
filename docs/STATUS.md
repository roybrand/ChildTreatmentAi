# Status

Last updated: 2026-10-03

## Phase

The product is now a tutor. Decided by the founder on 2026-10-03; see [DECISIONS.md](DECISIONS.md) and [PRODUCT.md](PRODUCT.md).

What is switched on: the learner's profile interview, the first lesson (fractions with the Mixer game, set by the Tutor in the learner's world), and the emergency screen. The app opens on the lessons.

What is switched off: the family coaching module (Parent Coach, accommodation map, daily log, weekly summary). It is built, tested, and kept behind the `Features:FamilyCoaching` setting. Everything below under "Done" that concerns coaching describes that module.

Changed with the switch, on 2026-10-03, with no model calls:

- The profile holds what the learner loves, what is hard in learning, and what helps. The sections about anxiety, diagnoses, and the family are not in use, and the server refuses items for them
- A new interview prompt, `learner-profile/v1`, with its own scenario set of 11 and scoring guide. It writes down the practical learning need and never a diagnosis. **It has not been run against the model at all**
- The app shows two tabs, lessons and profile. Its name, consent text, and wording are rewritten for a tutor. The name "ללמוד בדרך שלי" is a working name
- 77 backend tests and 22 app tests pass

Changed on 2026-10-04 after the founder played the lesson, with no model calls:

- An empty part of the container looked the same as a part filled with white, so a container that was not full looked finished. The inside of the container is now grey, the built-in world mixes red and yellow, and the message says how many parts are missing
- The goal of the game read as "the same amount of colour". It now says to fill the container until the two colour circles match
- The lesson takes its look from the world: the Tutor also gives a symbol for the place, a face for whoever asks, the kind of container, and what that person says when the mix matches. The request is shown as that person's speech, and the screen is tinted with the two colours of the mix
- A lesson first opened before the profile had any interests is set in the learner's world the next time it is opened, and a button on the lesson screen asks the Tutor for another world
- A container with more parts is now drawn bigger, with every part the same size. Before, the "big bottle" was the same height cut into thinner parts, which contradicted the story. Wording that said "the same amount" now says "the same part of the whole"
- The lessons page asks for one interest when the profile has none, and a lesson restarts from its first step when its world changes
- Every step with a solution has a "להראות לי איך" button. It walks through the solution in five small animated pictures, with every number worked out by code from the step. The learner leaves it with "הבנתי, רוצה לנסות", which leaves the work to them, or "להמשיך הלאה", which fills the step in. Neither is marked
- **These changes to the Tutor's prompt have not been run against the model**

Curriculum and practice, built on 2026-10-04 with no model calls:

- The Ministry of Education's mathematics curriculum for grades 7 to 9 is in `curriculum/math-il.json`: 31 topics with their teaching hours and order, and 72 sub-topics. The topics and hours were read from the Ministry's document; tests check that each grade adds up to 150 hours and to the Ministry's split by domain
- 42 of the 72 sub-topics have a question generator: code that makes a question, its exact answer, and the steps of its solution. The 30 without are mostly word problems, proofs, constructions, and questions that need a graph or a drawing
- The app has a practice screen: grade, topic, sub-topic, then a set of five questions. An answer can be typed as a whole number, a fraction, or a decimal. Nothing is marked wrong, and the solution can be shown step by step at any time
- 95 backend tests and 24 app tests pass

Redesign on 2026-10-04, after the founder called the app a mess, with no model calls:

- **Welcome page.** The app opens on the learner's own world: its symbol and name, a greeting by name, the world's colours as the background, and its symbols drifting behind the page. Two large doors lead to the lesson and to the topic map
- **Topic map.** Three tabs: home, topics, profile. The topics page has the grade as three large buttons, then each area of mathematics with its topics as cards, and each topic's sub-topics as buttons in plain view. A sub-topic without questions is shown and marked as coming
- **Questions as scenes.** A question is asked by the character from the learner's world, on a dark stage in the world's colours, and the character answers when the answer fits. Nine kinds of question are told as stories from the world, using the place and the things sold there: prices, discounts, orders, shelves, a sign, a delivery box. The other 33 are still plain mathematics inside the same scene
- **The home page is a tree by class.** Changed on 2026-10-04 after the founder said the main page should not lead with one lesson. The page opens on the learner's own class, worked out from their age, then the subject, then the subject's areas, topics, and sub-topics. Each sub-topic shows what it has: a lesson, practice, or "בקרוב". The Mixer lesson now sits on the sub-topic it teaches, equal fractions, in grades 5 and 6. Mathematics is the only subject with content; English and science are shown as coming. The tabs are home and profile
- Grades 5 and 6 were added with topic names only, from the Ministry's overview page. Their hours and sub-topics were not read from the Ministry's per-grade documents, so their sub-topic titles are ours. The file says so
- The learner's class is not stored. It is taken as age minus six, which is wrong for a child who is a year ahead or behind
- **Pictures of a solution.** Asked for by the founder on 2026-10-04: a solution should be seen, not only read. A question can now carry a picture, described by the server as numbers worked out with the answer and drawn by the app in the world's colours. Two exist. Sharing in a ratio is drawn as two shelves, with everything laid out in equal groups so the ratio is the number of groups on each shelf; the things are small bottles where the world's container is a bottle. A percentage is drawn as a hundred squares with the percent filled. The pieces arrive one after another. The other 41 kinds of question have no picture yet
- **When a learner does not get it.** The founder could not follow the first explanation of sharing in a ratio: "equal parts" meant nothing. It is now told as dealing out in rounds, in words and in the picture: each round puts a few on the first shelf and a few on the second, and the rounds are counted. A question can also carry a second explanation, told another way and more slowly. It is one tap away after the first, and it ends by saying that moving on is fine. Only sharing in a ratio has a second explanation so far
- **An easier question after a miss.** A question the learner did not get on their own, meaning the answer did not fit or the solution was shown, is followed by one of the same kind with smaller numbers, and says so. Every kind of question has an easy form: each range a generator draws from is narrowed to its small end. An easy question is not followed by another
- **What did not land is remembered.** Each question's outcome is stored: the sub-topic, and whether the learner got it on their own. No question and no answer is kept. A sub-topic is marked "לחזור לזה" when fewer than two of its latest three questions went well, and "הולך טוב" otherwise. The home page lists every sub-topic to come back to, from all classes, above the tree. The marks are words, never scores
- **The parent's view.** A third tab, "להורים", shows how practice is going: questions tried in the last seven days, how many were solved without seeing the solution, and how many sub-topics were practised; the sub-topics worth returning to, with the rule in plain words; and every sub-topic practised, with its counts and the date it was last practised. It reports facts and gives no grade. It is not locked: with one sign-in for parent and learner, the learner can open it too
- **A fixed cast of cartoon figures.** Founder's choice on 2026-10-04: start with a fixed set and decide about generated images later. Eight figures are drawn in code as vector faces, so there are no image files. Each blinks, and its face changes between asking and pleased. A world always gets the same figure, chosen from the world's name. The figure greets the learner on the welcome page, asks the questions, and makes the request in the lesson
- **Limits of the cast.** The figures are faces and shoulders only, with two expressions. They do not fit a world: a nail studio and a football pitch can get the same figure. Full-body characters, scenes, and figures that belong to a world need an illustrator or generated images. The backdrop symbols are still emoji
- The Tutor's world now also carries a greeting, the things sold in the world, and its symbols. **This addition to the Tutor's prompt has not been run against the model.** A world written before this is rebuilt the next time it is read, which is one more Tutor call
- Not done: questions set in the learner's world, a record of what each learner has practised or mastered, and grades 1 to 6 and 10 to 12
- The Hebrew of the questions and solutions was written by Claude and has not been read by a mathematics teacher
- Not done: real pictures. The faces and symbols are emoji. Drawn or generated artwork for each world is a separate piece of work

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

1. Founder plays the lesson and goes through the profile interview, and says what feels wrong
2. Run the evaluations of the two agents that are switched on, `learner-profile` and `tutor`. Needs the founder's go-ahead; about $0.50 for both on the testing models, about $1 on the production models
3. A mathematics teacher reads the practice questions and solutions, a sample from each sub-topic
4. Questions for the 30 sub-topics that have none, starting with word problems, and questions set in the learner's world
5. A record of what each learner practised, and a progress view for the parent
6. A second game template, a balance for equations, tied to its sub-topic in the skill map
7. The learner's own sign-in
8. Grades 1 to 6, then 10 to 12, from their own Ministry documents

For the family coaching module, only if it is switched on again:

- Give the Parent Coach the latest weekly summary, then re-run its evaluation
- Streaming for coach replies, which take about 20 seconds today
- The young person's check-in, calming tools, and brave steps

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
