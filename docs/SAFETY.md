# Safety

These rules override feature requests. If a feature conflicts with a rule here, the rule wins until the rule itself is changed and the change is recorded in [DECISIONS.md](DECISIONS.md).

Status: draft written by the builders. It has not been reviewed by a clinician. A review by a child psychologist is required before the app is released to any family.

## What the app is

A support tool for families. It is not therapy, not a medical device, and not a substitute for a clinician. Onboarding and the settings screen say this plainly.

## Rules for the coaching agent (parent side)

The agent must never:

1. Diagnose, or suggest that a child has or lacks a condition.
2. Give any advice about medication.
3. Tell a parent to force, punish, shame, or physically move a child toward a feared situation.
4. Advise stopping or avoiding professional treatment.
5. Present itself as a therapist, psychologist, or doctor.
6. Promise an outcome or a timeline.

The agent must always:

1. Frame change as something the parent does in their own behaviour, at a manageable pace.
2. Keep both halves of a supportive statement: acceptance and confidence.
3. Recommend professional help when the log describes something beyond its scope (see escalation below).
4. Say so when it is unsure, and avoid inventing clinical facts.

## Rules for the young person's side

1. No open-ended therapeutic conversation, ever. An agent that speaks with a young person works inside a fixed structure: the Tutor teaches a lesson, the Skills Guide runs a defined exercise. See [AGENTS.md](AGENTS.md).
2. No agent converses alone with a child under 12 about feelings or coping. In child mode the Skills Guide prepares activities for the parent and child to do together.
3. An agent stops its exercise or lesson when the young person shows distress, offers the calming tools, and hands over to the Safety Guard. It does not counsel.
4. Every message from an agent to a young person passes the Safety Guard before it is shown.
5. No agent that speaks with a young person is released to any family until a clinician has reviewed its prompt and test results.
6. Brave steps are offered, never pushed. Skipping a step has no penalty and no guilt messaging.
7. No streak mechanics or rewards that punish a bad day.
8. A crisis button is reachable from every screen.
9. Easing off is automatic; stepping up needs a person. The Planner may make things easier on its own, but a harder brave step or a faster pace needs the parent's approval, and a teen's agreement.

## Escalation

The app stops coaching and shows the crisis screen when any of these appear in a log, a note, or a check-in:

- Self-harm or suicidal thoughts, in the child or the parent
- Harm to others
- Abuse or neglect
- The child not eating, not sleeping, or not leaving bed for days
- A sudden severe change in behaviour

The crisis screen shows emergency contacts for Israel and tells the family to contact a professional. Contacts to verify before launch: ERAN emotional first aid (1201), Magen David Adom (101), police (100).

Detection of these cases must not depend on the LLM alone. Keyword and rule checks run first, in code. See [ARCHITECTURE.md](ARCHITECTURE.md).

## Decline alerts

If check-ins show a sharp drop or a sustained low, the parent gets an alert. The alert describes the pattern, not the content of any private note. The exact thresholds are not yet defined.

## Known limits of the evidence

- The published trial of the parent-led approach this app draws on studied children aged roughly 7 to 14. Use with older teens goes beyond that trial and needs a clinician's view.
- An app delivering this method through an AI agent has not been tested. The research covers the method as delivered by trained therapists.

Neither point may be hidden or softened in marketing.

## Before launch

- Clinical review of this file and of every agent prompt
- A written test set of risky parent messages, run against every prompt change
- A way for parents to report a harmful or wrong response
