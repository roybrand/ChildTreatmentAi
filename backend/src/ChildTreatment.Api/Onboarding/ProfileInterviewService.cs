using ChildTreatment.Api.Data;
using ChildTreatment.Api.Llm;
using ChildTreatment.Api.Safety;
using Microsoft.EntityFrameworkCore;

namespace ChildTreatment.Api.Onboarding;

public enum InterviewReplyKind { Reply, Crisis, Fallback, Unavailable }

public sealed record InterviewItem(Guid Id, ProfileSection Section, string Text, ProfileItemStatus Status);

public sealed record InterviewReply(
    InterviewReplyKind Kind,
    string Text,
    IReadOnlyList<CrisisContact> Contacts,
    IReadOnlyList<InterviewItem> Items,
    bool Complete);

/// <summary>Runs one interview turn for a family: loads the profile, hides names, stores the turn and the notes.</summary>
public sealed class ProfileInterviewService(
    AppDbContext db,
    ProfileAgent agent,
    CrisisRules crisisRules,
    TimeProvider time,
    ILogger<ProfileInterviewService> logger)
{
    private const int HistoryMessages = 40;

    /// <summary>
    /// The first question. Written by people, so the interview starts without a model call.
    /// The wording avoids gendered forms, because the child's gender is not known yet.
    /// </summary>
    public static string Opening(string childName) =>
        $"כדי שהליווי יתאים למשפחה שלכם, אשאל כמה שאלות על {childName}. " +
        "אפשר לענות בקצרה, לדלג על שאלה, ולעצור בכל רגע ולהמשיך בפעם אחרת. " +
        "כל דבר שארשום יוצג לכם לאישור.\n\n" +
        $"נתחיל מהדברים הטובים: מה הדברים האהובים על {childName}, ומה בא ל{childName} בקלות?";

    /// <returns>Null when the child does not exist in the current family.</returns>
    public async Task<InterviewReply?> SendAsync(Guid childId, string text, CancellationToken ct = default)
    {
        var child = await db.Children.FirstOrDefaultAsync(c => c.Id == childId, ct);
        if (child is null)
            return null;

        var now = time.GetUtcNow();
        var names = new Pseudonymizer(child.Nickname);

        var history = await LoadHistoryAsync(childId, names, ct);
        var existing = await db.ProfileItems
            .Where(i => i.ChildId == childId)
            .OrderBy(i => i.Section).ThenBy(i => i.CreatedAt)
            .ToListAsync(ct);
        var context = new InterviewContext
        {
            Age = child.AgeIn(now.Year),
            Items = existing.Select(i => new ProfileNote(i.Section, names.Hide(i.Text), i.Status)).ToList(),
        };

        // The parent's message is stored before the model is called, so it survives a failure.
        var parentMessage = new InterviewMessage
        {
            ChildId = childId,
            Role = CoachingRole.Parent,
            Kind = CoachingMessageKind.Normal,
            Text = text,
            CreatedAt = now,
        };
        db.InterviewMessages.Add(parentMessage);
        await db.SaveChangesAsync(ct);

        InterviewOutcome outcome;
        try
        {
            outcome = await agent.RespondAsync(context, history, names.Hide(text), ct);
        }
        catch (LlmUnavailableException ex)
        {
            logger.LogWarning(ex, "The Profile Agent could not be reached");
            return new InterviewReply(InterviewReplyKind.Unavailable, SafetyTexts.Unavailable, [], [], false);
        }

        var reply = new InterviewMessage
        {
            ChildId = childId,
            Role = CoachingRole.Coach,
            PromptVersion = outcome.PromptVersion,
            CreatedAt = time.GetUtcNow(),
        };
        var saved = new List<ProfileItem>();

        switch (outcome.Kind)
        {
            case InterviewOutcomeKind.Crisis:
                // Kept out of later history, as in the coach conversation.
                parentMessage.Kind = CoachingMessageKind.Crisis;
                reply.Kind = CoachingMessageKind.Crisis;
                reply.Text = outcome.Text;
                AddSafetyEvent(childId, SafetySource.ProfileInterviewInput, outcome.CrisisCategory!);
                break;

            case InterviewOutcomeKind.Fallback:
                logger.LogWarning("A Profile Agent reply was withheld: {Reason}", outcome.BlockReason);
                reply.Kind = CoachingMessageKind.Fallback;
                reply.Text = outcome.Text;
                AddSafetyEvent(childId, SafetySource.ProfileInterviewOutput, "reply_withheld");
                break;

            default:
                reply.Kind = CoachingMessageKind.Normal;
                reply.Text = names.Restore(outcome.Text);
                reply.Completes = outcome.Complete;
                foreach (var proposed in outcome.Items)
                {
                    var itemText = names.Restore(proposed.Text);
                    if (existing.Any(i => i.Section == proposed.Section && i.Text == itemText))
                        continue;

                    // The agent's wording of what the parent said is a suggestion until the parent accepts it.
                    // Other agents treat only confirmed items as fact.
                    var item = new ProfileItem
                    {
                        Id = Guid.NewGuid(),
                        ChildId = childId,
                        Section = proposed.Section,
                        Text = itemText,
                        Status = ProfileItemStatus.Suggested,
                        CreatedAt = reply.CreatedAt,
                    };
                    db.ProfileItems.Add(item);
                    saved.Add(item);
                }
                break;
        }

        db.InterviewMessages.Add(reply);
        await db.SaveChangesAsync(ct);

        var kind = outcome.Kind switch
        {
            InterviewOutcomeKind.Crisis => InterviewReplyKind.Crisis,
            InterviewOutcomeKind.Fallback => InterviewReplyKind.Fallback,
            _ => InterviewReplyKind.Reply,
        };
        return new InterviewReply(
            kind,
            reply.Text,
            kind == InterviewReplyKind.Crisis ? SafetyTexts.CrisisContacts : [],
            saved.Select(i => new InterviewItem(i.Id, i.Section, i.Text, i.Status)).ToList(),
            reply.Completes);
    }

    private void AddSafetyEvent(Guid childId, SafetySource source, string category) =>
        db.SafetyEvents.Add(new SafetyEvent
        {
            ChildId = childId,
            Source = source,
            Category = category,
            RulesVersion = crisisRules.Version,
            CreatedAt = time.GetUtcNow(),
        });

    private async Task<List<LlmMessage>> LoadHistoryAsync(Guid childId, Pseudonymizer names, CancellationToken ct)
    {
        var recent = await db.InterviewMessages
            .Where(m => m.ChildId == childId && m.Kind == CoachingMessageKind.Normal)
            .OrderByDescending(m => m.CreatedAt)
            .Take(HistoryMessages)
            .ToListAsync(ct);

        recent.Reverse();
        return recent
            .Select(m => new LlmMessage(
                m.Role == CoachingRole.Parent ? LlmRole.User : LlmRole.Assistant,
                names.Hide(m.Text)))
            .ToList();
    }
}
