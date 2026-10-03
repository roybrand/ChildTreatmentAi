# Privacy

The app holds mental-health information about minors. This is among the most sensitive data a product can hold.

Status: draft. A lawyer who knows Israeli privacy law must review this before the app is released to any family. Nothing here is legal advice.

## Principles

1. **Collect the minimum.** No school name, no ID number, no address, no photos. A first name or nickname is enough.
2. **Parent consent first.** A parent creates the family account and gives explicit consent before any data about a child is stored.
3. **The young person agrees too.** A child or teen is told, in words suited to their age, what the app records and who can see it.
4. **Nothing is sold or shared.** No advertising, no analytics that carry personal content, no use of family data to train models.
5. **Families can leave.** Export and full deletion are available from settings.

## Who sees what

| Data | Parent | Young person |
| --- | --- | --- |
| Parent's log, plans, coaching sessions | Yes | No |
| Brave ladder and steps | Yes | Yes |
| Check-in scores and trend | Yes | Yes |
| Young person's private notes (child mode) | **Open** | Yes |
| Young person's private notes (teen mode) | No | Yes |
| Safety alerts | Yes | Told that an alert was sent |

For teens, private notes stay private so the teen can be honest. The one exception is safety: crisis content triggers the crisis screen and a parent alert. The teen is told about this exception up front, during onboarding, so it never comes as a betrayal.

## Shared computers and browsers

The app also runs in a browser, and a family computer or tablet is often shared by the parent and the child. The table above must hold there too.

- In a browser the sign-in lasts only as long as the tab. Closing the tab signs the parent out. There is no "stay signed in".
- In a browser the parent is signed out after 15 minutes without activity. Anything open on top, such as a half-written log entry, is closed. The crisis screen stays open.
- The young person's side, when built, has its own sign-in. From it there is no way to reach the parent's log, plans, or coaching sessions, and the server refuses those requests for a young person's login.
- A teen's private notes get the same protection in the other direction.

Not yet covered: the browser's own history and password manager, and a parent who walks away within the 15 minutes.

## Data sent to the LLM

- Names and other identifying details are replaced with placeholders before a call and restored afterwards.
- Only the content needed for the task is sent. A weekly summary does not need the whole history.
- A teen's private notes are never sent to the LLM for parent-facing output.
- The LLM provider must not retain or train on the data. Confirm the provider's terms before launch.

## Storage and access

- Encryption in transit and at rest, plus field-level encryption for sensitive free text.
- Every read of sensitive data by staff or support is recorded in an audit log.
- Hosting location is not decided. It affects which law applies to data transfers.

## Open legal questions

- Requirements under the Israeli Protection of Privacy Law and its data security regulations for health data about minors
- Whether a database registration or a privacy officer is needed
- At what age a teen's own consent is required alongside the parent's
- What a parent is entitled to see of a teen's data, and whether the private-notes rule above holds legally
- Duty to report if the app learns of abuse or of risk to life
