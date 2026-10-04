using System.Linq.Expressions;
using System.Reflection;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Identity.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Storage.ValueConversion;

namespace ChildTreatment.Api.Data;

/// <summary>Holds the family the current request acts for. Set once per request, after sign-in.</summary>
public sealed class CurrentFamily
{
    public Guid? FamilyId { get; set; }
}

public class AppDbContext(
    DbContextOptions<AppDbContext> options,
    CurrentFamily currentFamily,
    FieldProtector protector)
    : IdentityDbContext<AppUser, IdentityRole<Guid>, Guid>(options)
{
    public DbSet<Family> Families => Set<Family>();
    public DbSet<ChildProfile> Children => Set<ChildProfile>();
    public DbSet<ProfileItem> ProfileItems => Set<ProfileItem>();
    public DbSet<Accommodation> Accommodations => Set<Accommodation>();
    public DbSet<ParentLogEntry> ParentLogEntries => Set<ParentLogEntry>();
    public DbSet<CoachingMessage> CoachingMessages => Set<CoachingMessage>();
    public DbSet<SafetyEvent> SafetyEvents => Set<SafetyEvent>();
    public DbSet<InterviewMessage> InterviewMessages => Set<InterviewMessage>();
    public DbSet<WeeklySummary> WeeklySummaries => Set<WeeklySummary>();
    public DbSet<ChildLesson> ChildLessons => Set<ChildLesson>();
    public DbSet<PracticeRecord> PracticeRecords => Set<PracticeRecord>();

    // Read by the query filters below on every query, so each request sees only its own family.
    private Guid CurrentFamilyId => currentFamily.FamilyId ?? Guid.Empty;

    protected override void OnModelCreating(ModelBuilder builder)
    {
        base.OnModelCreating(builder);

        var encrypt = new ValueConverter<string, string>(
            plain => protector.Protect(plain),
            stored => protector.Unprotect(stored));

        foreach (var entityType in builder.Model.GetEntityTypes())
        {
            var clr = entityType.ClrType;

            foreach (var property in clr.GetProperties()
                         .Where(p => p.GetCustomAttribute<EncryptedAttribute>() is not null))
            {
                builder.Entity(clr).Property(property.Name).HasConversion(encrypt);
            }

            if (typeof(IFamilyOwned).IsAssignableFrom(clr))
            {
                builder.Entity(clr).HasQueryFilter(FamilyFilter(clr));
                builder.Entity(clr).HasIndex(nameof(IFamilyOwned.FamilyId));
                builder.Entity(clr)
                    .HasOne(typeof(Family))
                    .WithMany()
                    .HasForeignKey(nameof(IFamilyOwned.FamilyId))
                    .OnDelete(DeleteBehavior.Cascade);
            }
        }

        builder.Entity<CoachingMessage>().HasIndex(m => new { m.ChildId, m.CreatedAt });
        builder.Entity<ParentLogEntry>().HasIndex(e => new { e.ChildId, e.Date });
        builder.Entity<InterviewMessage>().HasIndex(m => new { m.ChildId, m.CreatedAt });
        builder.Entity<WeeklySummary>().HasIndex(s => new { s.ChildId, s.WeekEnd });
        builder.Entity<ChildLesson>().HasIndex(l => new { l.ChildId, l.LessonId }).IsUnique();
        builder.Entity<PracticeRecord>().HasIndex(p => new { p.ChildId, p.SubtopicId, p.CreatedAt });
    }

    // Builds: e => e.FamilyId == this.CurrentFamilyId
    private LambdaExpression FamilyFilter(Type entityType)
    {
        var entity = Expression.Parameter(entityType, "e");
        var familyId = Expression.Property(entity, nameof(IFamilyOwned.FamilyId));
        var current = Expression.Property(
            Expression.Constant(this),
            typeof(AppDbContext).GetProperty(nameof(CurrentFamilyId), BindingFlags.Instance | BindingFlags.NonPublic)!);
        return Expression.Lambda(Expression.Equal(familyId, current), entity);
    }

    public override Task<int> SaveChangesAsync(CancellationToken cancellationToken = default)
    {
        StampFamily();
        return base.SaveChangesAsync(cancellationToken);
    }

    public override int SaveChanges()
    {
        StampFamily();
        return base.SaveChanges();
    }

    // New rows take the current family. A row for any other family is refused.
    private void StampFamily()
    {
        foreach (var entry in ChangeTracker.Entries<IFamilyOwned>())
        {
            if (entry.State is not (EntityState.Added or EntityState.Modified))
                continue;

            if (currentFamily.FamilyId is not { } familyId)
                throw new InvalidOperationException("Family-owned data cannot be saved without a current family.");

            if (entry.State == EntityState.Added && entry.Entity.FamilyId == Guid.Empty)
                entry.Entity.FamilyId = familyId;

            if (entry.Entity.FamilyId != familyId)
                throw new InvalidOperationException("Attempt to save data for a different family.");
        }
    }
}
