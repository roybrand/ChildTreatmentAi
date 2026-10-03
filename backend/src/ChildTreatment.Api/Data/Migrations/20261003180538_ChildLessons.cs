using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace ChildTreatment.Api.Data.Migrations
{
    /// <inheritdoc />
    public partial class ChildLessons : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "ChildLessons",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    FamilyId = table.Column<Guid>(type: "uuid", nullable: false),
                    ChildId = table.Column<Guid>(type: "uuid", nullable: false),
                    LessonId = table.Column<string>(type: "text", nullable: false),
                    World = table.Column<string>(type: "text", nullable: false),
                    FromTutor = table.Column<bool>(type: "boolean", nullable: false),
                    StepReached = table.Column<int>(type: "integer", nullable: false),
                    CompletedAt = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    PromptVersion = table.Column<string>(type: "text", nullable: true),
                    CreatedAt = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_ChildLessons", x => x.Id);
                    table.ForeignKey(
                        name: "FK_ChildLessons_Families_FamilyId",
                        column: x => x.FamilyId,
                        principalTable: "Families",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateIndex(
                name: "IX_ChildLessons_ChildId_LessonId",
                table: "ChildLessons",
                columns: new[] { "ChildId", "LessonId" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_ChildLessons_FamilyId",
                table: "ChildLessons",
                column: "FamilyId");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "ChildLessons");
        }
    }
}
