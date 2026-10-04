# Product

## The problem

Some children and teenagers do not fit the way school teaches. They fall behind, stop believing they can learn, and some stop going. The lessons they meet are built around nothing they care about, move at a pace that is not theirs, and mark every mistake.

## The idea

A tutor that teaches through games set in the learner's own world, at the learner's own pace.

- **Their world.** A learner who loves cosmetics meets fractions by mixing a nail polish shade. A learner who loves football meets the same idea by mixing the team's drink. The app builds a profile of what each learner loves and sets every lesson in it.
- **Games and pictures, not worksheets.** Each idea is a small game the learner plays, with the result visible on screen, and only afterwards the notation used in class.
- **No pressure.** Nothing is marked wrong. There are no timers, no marks, and no comparison with anyone. A lesson can stop anywhere and resume later.
- **Reliable.** The games are built and tested by hand, and code checks every number and every answer. The AI writes the story around the game. It never decides whether an answer is right.

The app is a learning product. It is not therapy, does not diagnose, and does not replace a teacher or a clinician. See [SAFETY.md](SAFETY.md).

## Who it is for

- **Learners** of school age who find school hard, for whatever reason: learning feels impossible, lessons are too fast, or they are not at school at all. The first audience is ages 13 to 16.
- **Parents**, who create the account, give consent, and see their child's learning progress.

A child's difficulty has many possible causes. The app does not ask which, and holds no diagnosis. It asks what the learner loves, what is hard in learning, and what helps.

## What the first version does

| Area | Feature | State |
| --- | --- | --- |
| Account | Parent sign-up, consent, learner profiles, export and delete of all data | Built |
| Profile | A short interview with the parent about what the learner loves, what is hard in learning, and what helps. Each item waits for the parent to accept it | Built |
| Lessons | Fractions with the Mixer game, set by the Tutor in the learner's world | Built |
| Practice | The Israeli curriculum for grades 7 to 9 by grade, topic, and sub-topic, with practice questions made and checked by code and a step-by-step solution for each | Built for 42 of 72 sub-topics |
| Practice | Questions set in the learner's world, word problems, and questions about graphs and shapes | Next |
| Practice | Grades 1 to 6 and 10 to 12 | Later |
| Lessons | More game templates: a balance for equations, a hundred bar for percentages | Next |
| Lessons | Hints and step-by-step explanations when a learner is stuck | Next |
| Learner | The learner's own sign-in | Next |
| Parent | A view of learning progress | Next |
| Both | Emergency screen reachable from everywhere | Built |

The first subject is mathematics, following the Israeli Ministry of Education's curriculum, starting with grades 7 to 9.

## How a lesson works

1. **A real problem** from the learner's world.
2. **Play.** The learner changes something on screen and sees what happens.
3. **Discover.** The learner notices the rule.
4. **Name it.** The lesson says what the rule is called and why people needed it.
5. **Practise** with a few more cases in the same world.
6. **Bridge to school.** The same idea in the notation used in class.

The first lesson and the learning path are in [TUTOR_LESSONS.md](TUTOR_LESSONS.md).

## What sets it apart

AI tutors are a crowded field. This one is built from the experience of a child who did not fit school:

- Nothing is marked wrong, nothing is timed, nothing is ranked.
- The lesson is in the learner's world, with a real link between that world and the idea, not a theme pasted on.
- The mathematics is checked by code, so it is never wrong.

## Later ideas

- **Games built in the background.** An AI workflow that proposes new games for a skill, generates them, runs automated checks on the mathematics, the code, and the content, and puts the ones that pass in a queue for review. Learners only ever see a published, tested game. This comes after two or three games built by hand have shown what a good one looks like.
- **Games learners play together, with chat.** So that learners build friendships and confidence. Putting children in contact with each other needs its own safety and privacy design first: who can meet whom, what a parent sees and approves, how messages are checked, and what the law requires for minors.
- **Family coaching for anxiety.** A parent coaching module was built first and is switched off. See below.
- **More subjects:** English, physics.

## The family coaching module, switched off

The project began as an app for families of children with anxiety, coaching the parent with the principles of parent-led anxiety treatment. That part is built: a Parent Coach, an accommodation map, a daily log, and a weekly summary. It is switched off by a setting and its code is kept. If it returns, it returns as a separate product, built with a child mental-health professional. The reasons are in [DECISIONS.md](DECISIONS.md), and its design is in [AGENTS.md](AGENTS.md) and [SAFETY.md](SAFETY.md).

## Out of scope

- Open-ended conversation between an AI and a child about feelings. Permanently
- Diagnosing, or holding diagnoses
- School or municipality integrations

## Where it runs

- A phone app for Android and iOS, and the same app in a browser on a phone, a tablet, or a computer.
- Lessons are expected mostly on a tablet or a computer.

## Business model

- Sold to parents as a monthly subscription. The price is not set and not validated.
- Possible later channel: schools and municipalities, once there is usage data.

## Language and market

- Hebrew and right-to-left from day one. First market is Israel.

## How we will know it works

Tested with a small group of families before anything else is built on top:

- Learners come back for another lesson without being told to
- A learner can do the school-notation questions at the end of a lesson
- Parents say they would pay

There is no honest way to predict success or revenue before that test.
