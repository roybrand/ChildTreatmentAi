# Product

## The problem

Children and teens with anxiety often get too little help. Therapy is expensive, waiting lists are long, schools lack the training and time, and some children refuse to take part in therapy at all. Parents are left managing it alone, and the natural things they do to calm their child (reassuring again and again, speaking for them, avoiding the feared situation) relieve the moment but keep the anxiety going.

## The idea

Put the parent at the centre. Research on parent-led anxiety treatment shows that changing how the parent responds can reduce the child's anxiety, even when the child does not take part in treatment. The app coaches the parent through that process day by day, and gives the child or teen a small set of safe self-help tools.

The app supports families. It is not therapy, does not diagnose, and does not replace a clinician. See [SAFETY.md](SAFETY.md).

## Who it is for

- **Parents** of a child or teen with anxiety. They are the customer and the main user.
- **Children and teens** with anxiety, including those who also have ADHD or learning difficulties. The young person's side adapts to age.
- Supported ages: school age, roughly 6 to 18. Teen mode starts at 12.

## Scope and vision

The first product treats anxiety only. The long-term vision is to help children who do not fit at school, with further programmes added one at a time. A child's other conditions, such as ADHD or learning difficulties, are recorded in their profile and shape the agent's tone and pacing, but the method stays anxiety treatment.

## Parent side: the coaching agent

The parent works with an AI coaching agent through a repeating cycle:

1. **Map.** The agent helps the parent list everything the family does because of the child's anxiety (the accommodations).
2. **Pick one.** The parent chooses a single accommodation to reduce, starting with something manageable.
3. **Plan.** The agent drafts the exact words for telling the child about the change: calm, supportive, and not a punishment.
4. **Daily log.** The parent records what happened, how the child reacted, and how they responded.
5. **Coaching.** The agent reviews the log and helps the parent stay supportive without slipping back into accommodating.
6. **Next step.** Once one accommodation is reduced, move to the next.

Two principles run through every agent response:

- **Supportive statements** combine acceptance with confidence: "I know this is really scary for you, and I know you can handle it."
- **Reducing accommodation** is something the parent changes in their own behaviour. The parent never forces the child to do anything.

The parent also gets:

- A **brave ladder**: small, gradual steps toward hard things such as going outside, seeing a friend, or a school visit.
- A **weekly summary** of patterns across the logs and the child's check-ins.

## Young person's side

The same tools exist for every age, but the presentation differs.

| Tool | Child mode (younger) | Teen mode (older) |
| --- | --- | --- |
| Feelings check-in | Faces or colours, no words needed | Quick scale plus optional private note |
| Calming tools | Animated breathing, favourite-place visualisation | Breathing, grounding exercises, short audio |
| Brave steps | Steps from the ladder, each ending in a celebration | Steps the teen helps choose, with a plain progress view |
| Lessons | Tutor lessons built around the child's interests | Same, pitched for teens |
| Coping skills | Activities the parent and child do together | Guided exercises with the Skills Guide |

Teen mode has a different tone (no cartoon rewards) and different privacy rules: a teen needs to trust that private notes stay private. See [PRIVACY.md](PRIVACY.md).

Two agents speak with the young person, both in later phases and both inside a fixed structure: the **Tutor** teaches school material, and the **Skills Guide** teaches coping skills. Neither holds open-ended therapeutic conversation. See [AGENTS.md](AGENTS.md) and [SAFETY.md](SAFETY.md).

## All features

| Area | Feature | Phase |
| --- | --- | --- |
| Parent | Onboarding interview that builds the child's profile | 1 |
| Parent | Accommodation map | 1 |
| Parent | Plan for reducing one accommodation, with the words to announce it | 1 |
| Parent | Daily log | 1 |
| Parent | Coaching conversation | 1 |
| Parent | Weekly summary | 1 |
| Parent | Optional reflection on the parent's own history and stress | 1 |
| Parent | Brave ladder: build, approve steps, follow progress | 2 |
| Parent | Decline alerts | 2 |
| Young person | Feelings check-in | 2 |
| Young person | Calming tools, available offline | 2 |
| Young person | Brave steps | 2 |
| Young person | "About me" profile a teen can view and edit | 2 |
| Young person | Lessons with the Tutor | 3 |
| Young person | Coping skills programme with the Skills Guide | 4 |
| Both | Plan that adapts to what is happening | 2 onward |
| Both | Crisis screen reachable from everywhere | 1 |
| Both | Export and delete all data | 1 |

## Safety behaviour visible to users

- If check-ins show a sharp decline, the app alerts the parent.
- The app never tries to handle a crisis itself. It shows emergency contacts and directs the family to human help.

## Out of scope for version 1

- Open-ended therapeutic chat for the child or teen. This is out of scope permanently, not only for version 1
- Care-team hub (inviting teachers, counsellors, therapists)
- School or municipality integrations
- Parent-to-parent community or chat

## Where it runs

- A phone app for Android and iOS, and the same app in a browser on a phone, a tablet, or a computer.
- Both the parent's side and the young person's side work in the browser. Lessons in particular are expected on a tablet or a computer.
- Reminders and safety alerts come through the phone app.

## Build order

Four phases: parent coaching, then the young person's basic tools, then the Tutor, then the Skills Guide. The parent side comes first because it is the part with research support, and a parent can use it alone from day one. The phases are set out in [AGENTS.md](AGENTS.md).

The care-team hub was the first idea explored and remains a likely later addition.

## Business model

- Sold to parents as a monthly subscription. Earlier estimate: about ₪30–50 a month. Not validated.
- Possible later channel: schools and municipalities, once there is usage data.

## Language and market

- Hebrew and right-to-left from day one. First market is Israel.
- User-facing text describes the method as "based on research on parent-led anxiety treatment". It does not use the name of any published programme.

## How we will know it works

Not yet defined. Candidates: parents completing the daily log, number of accommodations reduced, change in check-in trend over 8–12 weeks, subscription retention.
