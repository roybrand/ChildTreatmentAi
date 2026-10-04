using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace ChildTreatment.Api.Data.Migrations
{
    /// <inheritdoc />
    public partial class PracticeRecords : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "PracticeRecords",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    FamilyId = table.Column<Guid>(type: "uuid", nullable: false),
                    ChildId = table.Column<Guid>(type: "uuid", nullable: false),
                    SubtopicId = table.Column<string>(type: "text", nullable: false),
                    GotIt = table.Column<bool>(type: "boolean", nullable: false),
                    CreatedAt = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_PracticeRecords", x => x.Id);
                    table.ForeignKey(
                        name: "FK_PracticeRecords_Families_FamilyId",
                        column: x => x.FamilyId,
                        principalTable: "Families",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateIndex(
                name: "IX_PracticeRecords_ChildId_SubtopicId_CreatedAt",
                table: "PracticeRecords",
                columns: new[] { "ChildId", "SubtopicId", "CreatedAt" });

            migrationBuilder.CreateIndex(
                name: "IX_PracticeRecords_FamilyId",
                table: "PracticeRecords",
                column: "FamilyId");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "PracticeRecords");
        }
    }
}
