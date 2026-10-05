# Decisions

Newest first. Each entry records what was decided and why. To reverse a decision, add a new entry; do not edit the old one.

## 2026-10-05: English starts from the learner's world and widens in circles, and the world has named people

A learner's first English words come from the world they love, in three circles: the heart of the world, what is around it, and everyday life. A wider circle opens when the one before it has settled, and never closes again. The world also gets three named people, who take turns asking questions in every subject and greet the learner on the home page, a different one each day, with a word of the day. The model writes the people and the words once per learner; code makes and checks every question about them.

**Why:** founder's request: English from the learner's world but not only from it, widening as they grow comfortable, with characters from that world, so that the learner wants to open the app. Words from a loved world are the least frightening way into a foreign language, and circles let the vocabulary reach ordinary life without a list that feels like school.

**What we chose not to do:** streaks, points, daily goals, or anything a learner can lose by staying away. These bring people back through worry, which is the wrong pull for learners who already fear failing. What changes each day is only who greets and which word is shown. A circle that is not open is shown without a lock or a count.

**Cost:** one more model call and one review per learner, once.

## 2026-10-05: English is the second subject, starting with grammar made by code

English is added beside mathematics, for the same grades. It starts with grammar, following the grammatical structures in the Ministry of Education's English Curriculum 2020. A question is a sentence with a gap and a few words to choose from. Code builds the sentence from word lists whose forms are written out by hand, so the English is correct and the answer is known without a model.

**Why:** founder's decision to add English to the classes. Grammar comes first because it can be made and checked by code, as the mathematics is, at no cost per question.

**Cost of this choice:** grammar drills are the least of what learning a language needs, and the least like a game. Vocabulary and reading in the learner's own world need the Tutor to supply the words, which means model calls and their checks.

## 2026-10-04: The learner's world is wide, and questions are real situations in it

The world a lesson and its questions are set in is the whole field a learner's interest belongs to: beauty, with its nails, hair, make-up, and clothes, and not a nail polish stand. The Tutor names several different things sold in that world, and each story question uses one of them. A question's story is a situation someone running such a place would really meet: a delivery, an order, a discount, tips. When a first explanation does not land, the second one uses a different example from the same world of work.

**Why:** founder's decision. One product makes every question the same question, and a made-up task, such as placing bottles on two shelves in a ratio, teaches that mathematics is something done for its own sake. A real situation answers "why do I need this".

**Cost of this choice:** a new version of the Tutor's prompt, which has to pass its evaluation, and one more Tutor call for each learner whose world was written by the earlier version.

## 2026-10-04: The skill map follows the Israeli curriculum, and practice questions are made by code

The tutor follows the Ministry of Education's mathematics curriculum. Grades 7 to 9 are in the project as data, in `curriculum/math-il.json`: each grade's topics with their teaching hours and order, taken from the Ministry's curriculum document, and under each topic its sub-topics. A sub-topic names the code that makes its practice questions. Questions, their answers, and their step-by-step explanations are all made and checked by code, with exact arithmetic. No model is involved.

**Why:** founder's decision to build by grade, topic, and sub-topic. Following the official curriculum means a learner at home covers what their class covers, and a parent can see where they are. Making questions by code keeps the promise that the mathematics is never wrong, costs nothing to run, and lets every question carry its own explanation.

**Limits of this choice:** a generator makes one kind of question per sub-topic, with numbers that change. It does not make word problems, proofs, constructions, or questions about graphs, so the sub-topics that are mostly those have no questions yet. Sub-topic titles are sometimes ours and not the Ministry's wording, where one of its headings covers several skills.

**Not decided:** grades 1 to 6 and 10 to 12. They have their own Ministry documents and are not read yet.

## 2026-10-03: The product is a tutor. The family coaching side is switched off

The app is now a tutor for school-age learners who find school hard: lessons as games in the learner's own world, at their own pace. The first audience is ages 13 to 16 and the first subject is mathematics. The parent coaching side (Parent Coach, accommodation map, daily log, weekly summary) is switched off by the `Features:FamilyCoaching` setting. Its code, prompts, and evaluations are kept.

The profile changes with it. It holds what the learner loves, what is hard in learning, and what helps. It holds no diagnosis or condition, nothing about anxiety or the family, and no medication. The interview has its own prompt, `learner-profile/v1`, which writes down the practical learning need and never the label.

**Why:** founder's decision, after concluding that treatment is unfamiliar and restricted ground. A learning product is simpler in law, can be explained in a sentence, and can be tested with a few families quickly. It still serves the child who stays at home: they can keep learning without the app claiming to treat anything. Mental-health data about children is the most sensitive kind the app could hold; a profile of interests and learning needs is not.

**What this reverses:** "Anxiety first", "Parent side is built first", and the place of the Parent Coach as the centre of the product. The decision that the app does not send families to therapy stays in force for the coaching module if it returns.

**What stays:** parental consent, family isolation, encryption, name hiding, the crisis rules on any free text, the safety review of everything a model writes, and the rule that the mathematics is checked by code.

**If the coaching module returns:** as a separate product, built with a child mental-health professional.

**Still needed before real families use it:** a privacy and consent review for children's data, which is lighter than for health data and still required.

## 2026-10-03: The Tutor is built now, and it writes the world, not the game

The teaching side is started ahead of the young person's check-in and calming tools, which were next in the build order. The first lesson is the Mixer lesson on fractions. The Tutor writes the world the game is set in, from the child's confirmed interests, once per lesson, and it is kept. It writes no numbers, checks no answers, and does not converse with the child. Shared games and chat between children are left for later.

**Why:** founder's decision: the heart of the app is a child learning through games in their own world and at their own pace. Keeping the Tutor to words and colours means a model can never get the mathematics wrong or say something unplanned to a child in the middle of a lesson, and it costs two model calls per lesson per child.

**Cost of this choice:** the Tutor cannot yet respond to what a child does in the game. That comes later, inside a fixed structure, and needs its own safety design.

## 2026-10-03: The app does not send families to therapy

Outside signs of danger, no agent recommends therapy, an assessment, or a professional. The coach, the Planner, and the safety review were changed to match, as prompt versions `parent-coach/v2`, `planner/v2`, and `safety-review/v2`. The crisis rules and the emergency screen are unchanged, and no agent advises against professional help.

**Why:** founder's decision. The app is meant as a home for families who have had enough of the system, where a child learns through games at their own pace. A parent who opens up and is told to see a professional hears one more door closing. This came from the founder's own first message to the coach, which the safety review withheld because the reply did not send them to a professional first.

**What this reverses:** the coach used to suggest a professional assessment when a child was out of school for a long stretch or when weeks of work brought no change.

**Risk accepted:** a family whose child needs more than the app can give will not hear that from the app unless a sign of danger appears. Claude raised this and recommended keeping the danger rules, which the founder has not asked to change. The clinical review listed in [STATUS.md](STATUS.md) should look at this decision in particular.

## 2026-10-03: A withheld reply gets one more try before the fallback

When the safety review withholds an agent's reply, the agent is asked once to write it again, with the reviewer's reason in hand. The second reply goes through the same review. Only if that one is withheld too does the parent see the fixed fallback text. This applies to the Parent Coach, the Profile Agent, and the Planner. The fallback text was also rewritten so that it does not read as blaming the parent's wording.

**Why:** the founder wrote a long, serious first message to the coach and got only the fallback, which reads as a brush-off. The review had withheld the reply because it did not recommend professional help first. That is something the coach can fix when told, and a parent left with nothing after opening up may not write again. Nothing unreviewed is ever shown: this revises "an unclear review blocks" only by adding a second attempt.

**Cost of this choice:** a withheld reply now costs four model calls and about twice the wait.

## 2026-10-03: The weekly summary is asked for by the parent, and its numbers are counted by code

The parent asks for the week's summary with a button. It covers the last seven days of the log, needs at least two log entries, and is written at most once a day. The count of entries and the parent's average mood, this week and the week before, are counted by code and shown next to the written summary. A pattern the Planner does not clearly mark as observed is shown as a guess. The Planner proposes and never changes the plan.

**Why:** a scheduled summary for every family is a model call nobody asked for, and the testing budget is small. Numbers counted by code cannot be written away, which is how "never hide a decline" is enforced and not only requested in the prompt. Decided by Claude; the founder can overrule it.

**Not done yet:** a scheduled summary with a reminder, and giving the latest summary to the Parent Coach.

## 2026-10-03: What the Profile Agent writes down waits for the parent

During the onboarding interview the Profile Agent writes down what the parent said as profile items. Each item is shown to the parent at once and stays a suggestion until the parent accepts it. The coach and the Planner use only accepted items. A rejected item is kept, hidden, so it is not proposed again. What the parent types into the profile directly is accepted from the start. The first interview question is fixed text written by people, so the interview opens without a model call.

**Why:** the profile shapes how every agent speaks about the child, and the agent's wording of what a parent said can be wrong. A wrong line about a child, most of all a condition nobody diagnosed, must not become a fact because a model wrote it. The cost is one tap per item. Decided by Claude; the founder can overrule it.

**Also decided:** the Profile Agent does not record medication names or doses, other people's names, or a school's name, and writes a condition down only when the parent says a professional diagnosed it.

## 2026-10-03: The app also runs in a browser, for parent and young person

The same Flutter code is built as a responsive web app as well as a phone app. Both the parent's side and the young person's side are supported in the browser. This reverses "a web version is out of scope" and revises the Flutter entry below, which chose a phone app over a web app. The phone app stays, and stays the place for reminders and alerts.

**Why:** founder's decision.

- A child does lessons and homework on a tablet or a computer. Many younger children have no phone, and activities for under-12s are done by the parent and child together at one screen.
- There is no way to build the iPhone app yet. A browser is the only way a parent with an iPhone can use it.
- A link is easier than an install for the first parents who try it.
- Coaching is long-form writing, which is easier at a keyboard.
- It is one codebase, so the cost is responsive layouts, not a second app.

**Conditions:**

- A browser may be on a computer the whole family uses. In a browser the sign-in lasts only as long as the tab, and the parent is signed out after 15 minutes without activity. The crisis screen is never closed by that sign-out.
- When the young person's side is built, it gets its own sign-in and cannot reach the parent's log, plans, or coaching from the same browser. See [PRIVACY.md](PRIVACY.md).
- Lessons work by touch and by mouse. See [TUTOR_LESSONS.md](TUTOR_LESSONS.md).

**Cost of this choice:** browser storage is weaker than a phone's secure storage, browser notifications are unreliable, and the web app needs hosting and a list of allowed origins on the server.

## 2026-10-03: Cheaper models while testing, the best model in production

Production settings use the most capable model for the coach and for the safety review. Development settings use Claude Sonnet 5.5 at low effort for the coach and Claude Haiku 4.5 for the review. The evaluation tool defaults to the testing models and prints the estimated cost of each run.

**Why:** founder's decision. The testing budget is $10 a month, $15 at most. A coaching message costs roughly 2 cents on the testing models against roughly 5 to 8 cents on the production model.

**Cost of this choice:** replies during testing are weaker than production replies, mainly longer and less polished. A prompt version must still pass the full scenario set on the production models before it is released, and that run needs the founder's go-ahead because of its cost.

## 2026-10-03: Every agent reply is reviewed by the model before it is shown, and an unclear review blocks

The coach's reply goes through a second model call that checks it against the safety rules. Anything not clearly passed is withheld and replaced by a fixed fallback text.

**Why:** a withheld reply costs the parent a retry. A harmful reply shown to a parent costs far more. The price is a slower answer and twice the model cost per reply.

## 2026-10-03: The child's name never goes to the model

The app replaces the child's name with a placeholder before any text is sent and restores it in the reply. Only the birth year is stored, not the birth date.

**Why:** the privacy principle of collecting and sharing the minimum.

## 2026-10-03: Lessons come in two styles and the young person chooses

Every Tutor lesson is available in a realistic studio style and a playful cartoon style. The young person picks and can switch at any time. Details are in [TUTOR_LESSONS.md](TUTOR_LESSONS.md).

**Why:** founder's decision. A 15-year-old may love cartoons or feel talked down to by them, and age does not tell us which. Letting the young person choose also gives them some control, which matters for an anxious child.

**Cost of this choice:** the artwork for each interest world is made twice. The game logic is built once.

## 2026-10-03: The Tutor teaches through visual games set in the child's interests

Each topic is taught as a small visual game in the child's own interest world, starting from why the idea was needed. Mathematics is the first subject. The games are a small library of hand-built templates; the Tutor sets them in the child's interest and code checks all arithmetic.

**Why:** founder's idea. It answers "why do I need this", it lets an anxious child explore without being tested, and teaching through a child's interests has research support. Hand-built templates and code-checked arithmetic keep the games reliable.

## 2026-10-03: Five agents and a safety guard

The system has five agents: Parent Coach, Skills Guide, Tutor, Profile Agent, and Planner, plus a Safety Guard that checks every input and output. Agents share information only through the profile, the plan, and the event log, and server code decides which agent runs. Details are in [AGENTS.md](AGENTS.md).

**Why:** the founder set out the roles: a CBT agent, a tutor, a profile agent, dynamic adaptation, and parent treatment. Each became one agent with a narrow job, which makes each one testable and reviewable on its own. Keeping orchestration in code makes every message traceable.

## 2026-10-03: Agents may speak with a young person, inside a fixed structure

This revises the earlier rule of no AI chat on the young person's side. The Tutor and the Skills Guide speak with young people. Open-ended therapeutic conversation stays out of scope permanently.

**Why:** the founder wants a tutor and a CBT agent for the child. The risk identified earlier was an unstructured AI therapist alone with an anxious child. A structured skills programme and a tutor that stays on topic are different things, and structured digital programmes have research support.

**Conditions:** fixed structure, no agent alone with a child under 12 on feelings, stop on distress, every message checked by the Safety Guard, clinical review before release to any family. These are in [SAFETY.md](SAFETY.md).

## 2026-10-03: The CBT agent is called the Skills Guide

**Why:** it teaches coping skills. It does not conduct therapy, and the name should not suggest that it does, to users or to app store reviewers.

## 2026-10-03: Parent side is built first

The parent coaching side is built and usable before the young person's side is started.

**Why:** it is the part with research support, it is the smaller build, and it works even when the child does not take part. Decided by Claude after the founder delegated the choice; the founder can overrule it.

## 2026-10-03: Flutter mobile app, ASP.NET Core backend

The app is a native mobile app built with Flutter for iOS and Android. The backend stays ASP.NET Core with PostgreSQL. This replaces the earlier plan for a mobile web app.

**Why:** the founder asked for a fully mobile app and left the technology choice to Claude.

- Flutter over a web app: reliable notifications for daily reminders and safety alerts, an icon on the phone, secure on-device storage, and biometric lock.
- Flutter over React Native: right-to-left layout is built into the framework, the app looks the same on both platforms, and it handles the smooth animation the calming tools need.
- ASP.NET Core over Python: the backend is accounts, records, scheduled jobs, and calls to an LLM API, none of which needs Python. The founder is a .NET developer and can read, debug, and run it without help.
- One backend language, not a combination: a second language adds deployment and maintenance work with nothing gained.

**Cost of this choice:** two app stores to publish to, stricter store review for a children's health app, and iOS builds that need a Mac or a cloud build service.

## 2026-10-03: School age, 6 to 18

The app supports school-age children, roughly ages 6 to 18 (grades 1 to 12). Teen mode starts at 12, the move to junior high.

**Why:** founder's decision. School is where these children struggle, so school age is the natural boundary. The split at 12 is a proposal and may move after clinical review.

## 2026-10-03: Anxiety first

The first product treats anxiety only. The long-term vision is wider: children who do not fit at school. Co-occurring conditions such as ADHD and learning difficulties are recorded in the profile and shape the agent's tone and pacing, but the method stays anxiety treatment. The architecture stays condition-neutral so a second programme can be added later.

**Why:** each condition needs a different method. One method for one condition can be reviewed by a clinician and explained to a parent in a sentence. Anxiety is common and is often what lies behind school refusal.

## 2026-10-03: The app serves all families, not one child

The app is built for any school-age child or teen with anxiety. The young person's side has a child mode and a teen mode.

**Why:** the tools first sketched (faces, colours, celebrations) suit younger children and would feel childish to a teenager. A product for all families needs both.

## 2026-10-03: Project documents come before code

Six documents are written and kept current: product, architecture, safety, privacy, status, decisions.

**Why:** founder's request, so that every working session starts from the same shared picture.

## Earlier: The parent is at the centre, not an AI therapist for the child

The AI agent coaches the parent. It does not hold therapy conversations with the child.

**Why:** an agent talking alone with an anxious child can misread them, push too hard, or miss real distress with nobody aware of it. Parent-led treatment has research support and works even when the child will not engage.

## Earlier: Built on parent-led anxiety treatment principles, without the SPACE name

The parent side follows the principles of SPACE (Supportive Parenting for Anxious Childhood Emotions, Eli Lebowitz, Yale). The product does not use that name. User-facing text says "based on research on parent-led anxiety treatment".

**Why:** SPACE is a published programme belonging to others. The app is not that programme and must not claim to be.

## Earlier: The app never handles a crisis itself

A sharp decline alerts the parent. Crisis content shows emergency contacts and stops the coaching.

**Why:** an app cannot assess or manage risk to a child's life.

## Earlier: Sell to parents first

Parents pay a monthly subscription. Schools and municipalities may come later.

**Why:** parents feel the problem most and decide quickly. Institutions pay more but take far longer.

## Earlier: Care-team hub set aside

The first idea was a shared space for parent, teacher, counsellor, and therapist. It is out of scope for version 1.

**Why:** the direction moved to parent-led coaching. The hub remains a likely later addition.

## Earlier: Stack

ASP.NET Core, PostgreSQL, mobile web front end, an LLM API, Hebrew and right-to-left from day one.

**Why:** it matches the founder's .NET skills, and families will not install another native app.

The mobile web front end was replaced by Flutter on 2026-10-03. See above.
