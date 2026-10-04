# Agents

Status: the Parent Coach, the Profile Agent's interview, the Planner's weekly summary, and the Safety Guard are built. The Skills Guide and the Tutor are design only. This file defines how many agents there are, what each one does, and how we build and improve them.

## What is switched on

The product is a tutor. See [DECISIONS.md](DECISIONS.md).

| Agent | State |
| --- | --- |
| Tutor | On. Sets a hand-built game in the learner's world. Prompt `tutor/v1` |
| Profile Agent | On, as the learner's profile interview. Prompt `learner-profile/v1`. It asks what the learner loves, what is hard in learning, and what helps, and holds no diagnosis |
| Safety Guard | On for everything a model writes and every free text a person types |
| Parent Coach | Off, with the family coaching module. Prompt `parent-coach/v2` |
| Planner | Off. Its weekly summary belongs to the family coaching module. For the tutor it will later adapt lesson length, difficulty, and order |
| Skills Guide | Not built, and not planned for the tutor |

The sections below describe every agent as designed, including those switched off.

## What "agent" means here

An agent is one role played by the LLM. Each agent has:

- its own prompt, kept as a versioned file in the repo
- a fixed list of data it may read and data it may write
- a defined output format
- its own rules about what it must never do

Agents do not talk to each other directly and do not decide which agent runs next. Ordinary server code does that. Agents share information only through three stores: the **profile**, the **plan**, and the **event log**. This keeps every step traceable: for any message a parent or child saw, we can say which agent wrote it, from which prompt version, using which data.

## The line-up

Five agents and one guard.

| # | Agent | Speaks to | Job in one line |
| --- | --- | --- | --- |
| 1 | Parent Coach | Parent | Coaches the parent through reducing accommodation and responding supportively |
| 2 | Skills Guide | Young person | Teaches anxiety-coping skills from cognitive behavioural therapy through structured exercises |
| 3 | Tutor | Young person | Teaches school material in a way that fits this child's interests, difficulties, and state |
| 4 | Profile Agent | Parent (onboarding only) | Builds and maintains the picture of who the child is |
| 5 | Planner | Nobody directly | Adapts lessons and treatment steps to what is happening, and writes the weekly summary |
| – | Safety Guard | Nobody directly | Checks every input and every output. Can stop any agent |

How the founder's original list maps onto this:

- "CBT agent" is the Skills Guide. The name changed because it teaches skills and does not conduct therapy.
- "Tutor agent" is the Tutor.
- "Profile agent" is the Profile Agent.
- "Dynamic adaptation of the classes and treatments" is the Planner.
- "Parent agent treatment" is the Parent Coach.
- The Safety Guard is an addition.

## How they fit together

```
            Parent                         Young person
              |                                 |
   +----------+----------+            +---------+---------+
   |                     |            |                   |
Parent Coach      Profile Agent   Skills Guide          Tutor
   |              (onboarding)        |                   |
   +----------+----------+------------+---------+---------+
              |                                 |
              v                                 v
   +-------------------------------------------------------+
   |   Profile        Plan           Event log             |
   |   who the child  what we are    everything that       |
   |   is             doing now      happened              |
   +-------------------------------------------------------+
              ^                                 ^
              |                                 |
        Profile Agent                        Planner
        (keeps profile current)              (adapts the plan, weekly summary)

   Safety Guard wraps every arrow that reaches a person.
```

## 1. Parent Coach

**Purpose.** Guide the parent through the parent-led anxiety treatment cycle: map accommodations, pick one, plan the change and the words to announce it, log each day, review, move on.

**Speaks to.** The parent, in conversation.

**Reads.** Profile, plan, the parent's log, check-in trends, the latest weekly summary. Never a teen's private notes.

**Writes.** Accommodation map, accommodation plans, announcement scripts, coaching messages, proposed brave-ladder steps.

**Also supports the parent.** A parent's own history and stress shape how they respond. The coach can ask about this, with the parent's consent, and take it into account. It does not treat the parent. If the parent needs help of their own, it says so and points to professional support.

**Must never.** Everything in the coaching rules of [SAFETY.md](SAFETY.md): no diagnosis, no medication advice, no forcing or punishing the child, no promises.

**Good looks like.** The parent leaves each session with one concrete thing to do or say, feels supported and not judged, and the advice stays inside the method.

## 2. Skills Guide

**Purpose.** Teach the young person coping skills drawn from cognitive behavioural therapy: understanding what anxiety is and how it works in the body, noticing and questioning anxious thoughts, relaxation and grounding, and taking brave steps.

**Speaks to.** The young person. How it speaks depends on mode:

- **Teen mode (12 and up).** Guided exercises in conversation. The exercise has a fixed structure (for example: situation, thought, feeling, another way to see it) and the agent guides the teen through it using their own words and interests.
- **Child mode (under 12).** The agent prepares an activity for the parent and child to do together. It does not converse with a young child alone.

**Reads.** Profile (age, interests, triggers, what calms), the current skills module, the brave ladder.

**Writes.** Exercise content, completed exercise records, a note of which skills were practised. A teen's exercise content is private to the teen; the parent sees only that an exercise was done.

**Structure, not open conversation.** The skills are organised as a programme of modules in a set order. The agent personalises wording and examples inside a module. It does not hold free-form therapeutic conversation and does not choose what to treat. Structured digital programmes of this kind have research support for young people's anxiety; an unstructured AI therapist does not.

**Must never.** Act as a therapist, interpret the young person's past or family, push a brave step, continue an exercise when the young person shows distress, or keep going after a crisis signal.

**Good looks like.** The young person learns one skill at a time, in their own language, and can use it without the app.

## 3. Tutor

**Purpose.** Teach school material to a child who finds school hard, so that learning becomes possible again and a source of confidence.

**Speaks to.** The young person.

**Reads.** Profile (interests, learning difficulties, reading level, what works), the learning plan, mastery records, today's check-in.

**Writes.** Lessons, practice items, feedback, mastery records, observations about what helped or did not.

**How it teaches.**

- Builds examples from what the child loves.
- Works in short pieces, with one idea at a time.
- Fits the child's difficulties: text read aloud, fewer words on screen, more time, visual steps.
- Treats a mistake as information. No red crosses, no timers, no scores compared with others. This matters most for children who fear failing.
- Notices today's state. After a low check-in it offers a shorter, easier session or none.

**Teaching method: discover it through what you love.** Proposed by the founder on 2026-10-03. Each topic is taught as a small visual game set in the child's own interest, and it starts from why the idea was needed before showing how it is solved. A lesson runs in six steps:

1. **A real problem** from the child's world. For ratios: mixing a lipstick shade, choosing gears for a bike, working out how much water a plant needs.
2. **Play.** The child moves things on screen and sees what happens. There is no losing, no timer, and no lives.
3. **Discover.** The child notices the rule themselves.
4. **Name it.** The Tutor shows that this rule is the school topic, and why people needed it.
5. **Practise** with a few more cases in the same world.
6. **Bridge to school.** The same idea in the notation the child will meet in class and in a test. Without this step the understanding does not carry over.

How this is built:

- The games are a small library of interactive templates, built and tested by hand: a balance for equations, a mixer for ratios, a number line, an area grid, a slicer for fractions. The Tutor does not invent games on the fly.
- The Tutor chooses the template, sets it in the child's interest, picks the numbers, and guides the conversation around it.
- All arithmetic is checked by code. The Tutor never decides alone whether an answer is right.
- The link between the interest and the topic must be real. Colour mixing really is ratios. Where no honest link exists, the Tutor uses the nearest real one and does not paste a theme onto an unrelated problem.

Mathematics is the first subject.

**Stays on topic.** The Tutor teaches. If the young person brings up distress, it responds with one warm sentence, offers the calming tools, and lets the Safety Guard decide whether more is needed. It does not counsel.

**Must never.** Do the child's graded schoolwork for them, shame or pressure, compare the child with others, or hold a conversation about feelings beyond the handover described above.

**Good looks like.** The child finishes a session having understood something, and wants to come back.

**Not yet decided.** Which mathematics topics and grades come first, which interest worlds are built first, and how closely the Tutor follows the Israeli school curriculum.

## 4. Profile Agent

**Purpose.** Hold an accurate, current picture of the child so every other agent can fit its work to this child.

**Speaks to.** The parent, during the onboarding interview and occasional follow-up questions. A teen can view and edit the "about me" part of their own profile directly, without the agent.

**Reads.** Onboarding answers, the event log.

**Writes.** The profile, organised as:

| Section | Examples |
| --- | --- |
| Basics | Age, grade, mode |
| Strengths and interests | What they love, what they are good at |
| Anxiety picture | Triggers, what they avoid, how it shows, family accommodations |
| What calms | What has helped, what makes it worse |
| Learning picture | Difficulties, reading level, formats that work |
| Other conditions | Only what the parent reports from a professional |
| Family context | Optional: the parent's own history and current stress |
| What has worked | Kept current from the event log |

**Two kinds of entry.** Each item is either **confirmed** (the parent or teen said it) or **suggested** (the agent noticed a pattern). A suggestion is shown to the parent to accept or reject. Other agents treat only confirmed items as fact.

**Must never.** Record a diagnosis the parent did not report, infer a condition, or put content from a teen's private notes into anything the parent can see.

**Good looks like.** A new agent session can read the profile and immediately speak to this child as someone who knows them.

**As built.** The onboarding interview, prompt `profile-agent/v1`. The first question is fixed text. Each turn returns the next question and the items written down from the parent's last message. Items are stored as suggestions and shown to the parent at once to accept or reject. Crisis rules run on every parent message before the model, and the safety review reads both the question and the items. Not built yet: follow-up questions outside the interview, suggestions drawn from the event log, the teen's "about me", and the child's grammatical gender.

## 5. Planner

**Purpose.** Keep the plan fitted to what is really happening. This is the dynamic adaptation of lessons and treatment.

**Speaks to.** Nobody directly. Its output appears as proposals to the parent, as changes to the next lesson, and as the weekly summary.

**Reads.** Profile, plan, event log: check-ins, parent log, brave-step attempts, exercise completion, tutor mastery records.

**Writes.** The plan and the weekly summary.

**What it may change, and who approves.**

| Change | Approval |
| --- | --- |
| Lesson length, difficulty, format, and topic order | Automatic |
| Which calming tool is suggested, and reminder timing | Automatic |
| Making a brave step smaller after a failed attempt | Automatic |
| A new or harder brave step | Parent approves; a teen also agrees |
| Which accommodation to reduce next, and how fast | Parent approves |
| Moving to the next skills module | Automatic, after the current one is completed |
| Pausing the programme after a decline | Automatic, and the parent is told |
| Anything in [SAFETY.md](SAFETY.md) | Never |

The rule behind the table: easing off is automatic, stepping up needs a person.

**Weekly summary.** What happened, what patterns appear, what worked, what is proposed for next week. It names patterns in plain words and separates what was observed from what is a guess.

**Must never.** Raise difficulty or pace on its own, hide a decline, or present a guess as a finding.

**Good looks like.** The parent reads the summary and recognises their week in it, and the plan for next week feels right-sized.

**As built.** The weekly summary only, prompt `planner/v1`. The parent asks for it; it reads the confirmed profile, the accommodations, and the last seven days of the log. The entry count and mood averages are counted by code and shown beside the text. The summary passes the safety review, which also reads the week's log, before it is stored or shown. Not built yet: a scheduled summary, plan adaptation, and check-in data, which arrives with phase 2.

## Safety Guard

Not an agent in the same sense. It is mostly rule-based code, with an LLM check as a second layer.

- **On every input** from a parent or young person: rule and keyword checks for crisis signals run first, in code, before any agent sees the text. A hit shows the crisis screen and stops the agent.
- **On every output** before it reaches a person: an LLM check against the rules for that agent. A failed check blocks the message and a safe fallback is shown.
- **On check-in data:** decline detection, by rule.

The LLM layer can add a block. It can never remove one raised by the rules. Full rules are in [SAFETY.md](SAFETY.md).

## Build phases

| Phase | What is built | Agents live |
| --- | --- | --- |
| 1 | Parent onboarding, accommodation cycle, daily log, weekly summary | Parent Coach, Profile Agent, Planner (summary only), Safety Guard |
| 2 | Young person's check-in, calming tools, brave steps. No agent conversation yet | Planner adaptation added |
| 3 | Learning | Tutor |
| 4 | Coping skills programme | Skills Guide |

Phases 3 and 4 put an agent in conversation with a young person. Neither is released to any family until a clinician has reviewed the prompts and the test results.

## How we build and improve an agent

The same seven steps for every agent.

1. **Specification.** The section for that agent in this file: purpose, data, limits, what good looks like.
2. **Prompt.** Written as a file in the repo with a version number. Every change is a new version.
3. **Scenario set.** A written collection of situations the agent must handle, in three groups:
   - ordinary cases
   - hard cases: an angry parent, a teen who answers in one word, a parent who wants to quit
   - risky cases: hints of self-harm, a parent describing force, a request for medication advice
4. **Scoring guide.** For each agent, the questions a reviewer asks of a response. For the Parent Coach, for example: Is there one concrete next step? Are both acceptance and confidence present? Does it stay inside the method? Does it avoid every forbidden behaviour?
5. **Run and score.** Every prompt version is run against the full scenario set. A second LLM scores against the guide, and a person reads a sample. A version that fails any risky case is not released.
6. **Clinical review.** A child psychologist reads the prompt, the scenarios, and a sample of responses.
7. **Learn from use.** Parents and teens can mark a response as helpful or not and say why. Marked responses become new scenarios.

The lived experience of parents, and of adults who were anxious children, is a source of scenarios, especially hard ones: the quiet child who looks fine, fear of failing, a tense home.

## Open questions

- Tutor: which mathematics topics, grades, and interest worlds come first, and how closely to follow the school curriculum
- Skills Guide: which published programme structure to base the modules on
- Whether a teen can use the Tutor and Skills Guide without the parent using the Parent Coach
- Which Claude model each agent uses
- Who the reviewing clinician will be
