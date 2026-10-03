# Decisions

Newest first. Each entry records what was decided and why. To reverse a decision, add a new entry; do not edit the old one.

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
