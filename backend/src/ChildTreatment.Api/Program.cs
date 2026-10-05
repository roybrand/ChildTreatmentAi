using System.Security.Claims;
using System.Text.Json.Serialization;
using ChildTreatment.Api;
using ChildTreatment.Api.Coaching;
using ChildTreatment.Api.Data;
using ChildTreatment.Api.Endpoints;
using ChildTreatment.Api.Learning;
using ChildTreatment.Api.Llm;
using ChildTreatment.Api.Onboarding;
using ChildTreatment.Api.Planning;
using ChildTreatment.Api.Safety;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddSingleton(TimeProvider.System);
builder.Services.AddSingleton(FieldProtector.FromBase64(builder.Configuration["Encryption:Key"]));
builder.Services.AddScoped<CurrentFamily>();
builder.Services.AddDbContext<AppDbContext>(options =>
    options.UseNpgsql(builder.Configuration.GetConnectionString("Default")));

builder.Services.AddAuthorization();
builder.Services
    .AddIdentityApiEndpoints<AppUser>(options =>
    {
        options.User.RequireUniqueEmail = true;
        // Length over composition rules: easier to type on a phone and no weaker.
        options.Password.RequiredLength = 10;
        options.Password.RequireDigit = false;
        options.Password.RequireLowercase = false;
        options.Password.RequireUppercase = false;
        options.Password.RequireNonAlphanumeric = false;
    })
    .AddRoles<IdentityRole<Guid>>()
    .AddEntityFrameworkStores<AppDbContext>();

builder.Services.ConfigureHttpJsonOptions(options =>
    options.SerializerOptions.Converters.Add(new JsonStringEnumConverter()));
builder.Services.AddProblemDetails();
// The web app is served from another origin. Development allows any local port; everywhere
// else only the origins listed under Cors:AllowedOrigins, and none if the list is empty.
var webOrigins = builder.Configuration.GetSection("Cors:AllowedOrigins").Get<string[]>() ?? [];
var allowLocalOrigins = builder.Environment.IsDevelopment();
builder.Services.AddCors(options => options.AddPolicy("WebApp", policy =>
    policy.SetIsOriginAllowed(origin =>
            webOrigins.Contains(origin, StringComparer.OrdinalIgnoreCase)
            || (allowLocalOrigins && new Uri(origin).IsLoopback))
        .AllowAnyHeader().AllowAnyMethod()));

builder.Services.Configure<FeatureOptions>(builder.Configuration.GetSection("Features"));
builder.Services.Configure<LlmOptions>(builder.Configuration.GetSection("Llm"));
var promptOptions = builder.Configuration.GetSection("Prompts").Get<PromptOptions>() ?? new PromptOptions();
var promptStore = new PromptStore(promptOptions);
builder.Services.AddSingleton(promptStore);
builder.Services.AddSingleton(CrisisRules.Load(promptStore.Root));
builder.Services.AddSingleton<ILlmClient, AnthropicLlmClient>();
builder.Services.AddScoped<SafetyReviewer>();
builder.Services.AddScoped<ParentCoachAgent>();
builder.Services.AddScoped<ParentCoachService>();
builder.Services.AddScoped<ProfileAgent>();
builder.Services.AddScoped<ProfileInterviewService>();
builder.Services.AddScoped<WeeklySummaryAgent>();
builder.Services.AddScoped<WeeklySummaryService>();
builder.Services.AddSingleton(Curriculum.Load());
builder.Services.AddScoped<TutorAgent>();
builder.Services.AddScoped<WorldGuideAgent>();
builder.Services.AddScoped<LessonService>();

var app = builder.Build();

app.UseExceptionHandler();
app.UseStatusCodePages();
app.UseCors("WebApp");
app.UseAuthentication();
app.UseAuthorization();

// Resolve the signed-in parent's family once, so every query in the request is limited to it.
app.Use(async (context, next) =>
{
    var userId = context.User.FindFirstValue(ClaimTypes.NameIdentifier);
    if (Guid.TryParse(userId, out var id))
    {
        var db = context.RequestServices.GetRequiredService<AppDbContext>();
        context.RequestServices.GetRequiredService<CurrentFamily>().FamilyId =
            await db.Users.Where(u => u.Id == id).Select(u => u.FamilyId).FirstOrDefaultAsync();
    }
    await next();
});

app.MapGet("/health", () => Results.Ok(new { status = "ok" }));
// Reachable without signing in: a person in a crisis must never meet a login screen first.
app.MapGet("/api/crisis-contacts", () => new CrisisNotice(SafetyTexts.Crisis, SafetyTexts.CrisisContacts));
// The app asks which parts of the product are switched on, so it shows only those.
app.MapGet("/api/features", (Microsoft.Extensions.Options.IOptions<FeatureOptions> features) => new
{
    familyCoaching = features.Value.FamilyCoaching,
    profileSections = features.Value.ProfileSections.OrderBy(s => s).Select(s => s.ToString()),
});
app.MapGroup("/auth").MapIdentityApi<AppUser>();
app.MapFamilyEndpoints();
app.MapChildEndpoints();
app.MapAgentEndpoints();

if (app.Environment.IsDevelopment())
{
    using var scope = app.Services.CreateScope();
    await scope.ServiceProvider.GetRequiredService<AppDbContext>().Database.MigrateAsync();
}

app.Run();

public partial class Program;
