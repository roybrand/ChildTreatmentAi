using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace ChildTreatment.Api.Data.Migrations
{
    /// <inheritdoc />
    public partial class ProfileInterviewAndWeeklySummary : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "InterviewMessages",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    FamilyId = table.Column<Guid>(type: "uuid", nullable: false),
                    ChildId = table.Column<Guid>(type: "uuid", nullable: false),
                    Role = table.Column<int>(type: "integer", nullable: false),
                    Kind = table.Column<int>(type: "integer", nullable: false),
                    Text = table.Column<string>(type: "text", nullable: false),
                    Completes = table.Column<bool>(type: "boolean", nullable: false),
                    PromptVersion = table.Column<string>(type: "text", nullable: true),
                    CreatedAt = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_InterviewMessages", x => x.Id);
                    table.ForeignKey(
                        name: "FK_InterviewMessages_Families_FamilyId",
                        column: x => x.FamilyId,
                        principalTable: "Families",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "WeeklySummaries",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    FamilyId = table.Column<Guid>(type: "uuid", nullable: false),
                    ChildId = table.Column<Guid>(type: "uuid", nullable: false),
                    WeekStart = table.Column<DateOnly>(type: "date", nullable: false),
                    WeekEnd = table.Column<DateOnly>(type: "date", nullable: false),
                    Content = table.Column<string>(type: "text", nullable: false),
                    LogEntries = table.Column<int>(type: "integer", nullable: false),
                    MoodAverage = table.Column<double>(type: "double precision", nullable: true),
                    PreviousMoodAverage = table.Column<double>(type: "double precision", nullable: true),
                    PromptVersion = table.Column<string>(type: "text", nullable: false),
                    CreatedAt = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_WeeklySummaries", x => x.Id);
                    table.ForeignKey(
                        name: "FK_WeeklySummaries_Families_FamilyId",
                        column: x => x.FamilyId,
                        principalTable: "Families",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateIndex(
                name: "IX_InterviewMessages_ChildId_CreatedAt",
                table: "InterviewMessages",
                columns: new[] { "ChildId", "CreatedAt" });

            migrationBuilder.CreateIndex(
                name: "IX_InterviewMessages_FamilyId",
                table: "InterviewMessages",
                column: "FamilyId");

            migrationBuilder.CreateIndex(
                name: "IX_WeeklySummaries_ChildId_WeekEnd",
                table: "WeeklySummaries",
                columns: new[] { "ChildId", "WeekEnd" });

            migrationBuilder.CreateIndex(
                name: "IX_WeeklySummaries_FamilyId",
                table: "WeeklySummaries",
                column: "FamilyId");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "InterviewMessages");

            migrationBuilder.DropTable(
                name: "WeeklySummaries");
        }
    }
}
