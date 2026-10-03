using ChildTreatment.Api.Data;
using Microsoft.EntityFrameworkCore;

namespace ChildTreatment.Api.Tests;

public class FamilyIsolationTests
{
    private readonly string _database = Guid.NewGuid().ToString();
    private readonly Guid _familyA = Guid.NewGuid();
    private readonly Guid _familyB = Guid.NewGuid();

    private static ChildProfile NewChild(string name) =>
        new() { Id = Guid.NewGuid(), Nickname = name, BirthYear = 2015, CreatedAt = DateTimeOffset.UtcNow };

    [Fact]
    public async Task A_family_sees_only_its_own_rows()
    {
        await using (var a = TestSupport.Db(_database, _familyA))
        {
            a.Children.Add(NewChild("A"));
            await a.SaveChangesAsync();
        }
        await using (var b = TestSupport.Db(_database, _familyB))
        {
            b.Children.Add(NewChild("B"));
            await b.SaveChangesAsync();
        }

        // Separate context instances share one cached model, so this also proves the filter
        // reads the family of the context running the query, not of the first one created.
        await using var asA = TestSupport.Db(_database, _familyA);
        await using var asB = TestSupport.Db(_database, _familyB);
        await using var signedOut = TestSupport.Db(_database, null);

        Assert.Equal("A", (await asA.Children.SingleAsync()).Nickname);
        Assert.Equal("B", (await asB.Children.SingleAsync()).Nickname);
        Assert.Empty(await signedOut.Children.ToListAsync());
    }

    [Fact]
    public async Task New_rows_are_stamped_with_the_current_family()
    {
        await using var db = TestSupport.Db(_database, _familyA);
        var child = NewChild("A");
        db.Children.Add(child);
        await db.SaveChangesAsync();

        Assert.Equal(_familyA, child.FamilyId);
    }

    [Fact]
    public async Task Saving_a_row_for_another_family_is_refused()
    {
        await using var db = TestSupport.Db(_database, _familyA);
        var child = NewChild("B");
        child.FamilyId = _familyB;
        db.Children.Add(child);

        await Assert.ThrowsAsync<InvalidOperationException>(() => db.SaveChangesAsync());
    }

    [Fact]
    public async Task Saving_family_data_without_a_family_is_refused()
    {
        await using var db = TestSupport.Db(_database, null);
        db.Children.Add(NewChild("X"));

        await Assert.ThrowsAsync<InvalidOperationException>(() => db.SaveChangesAsync());
    }
}
