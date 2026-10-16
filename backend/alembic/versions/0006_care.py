"""care plans + daily care logs

Revision ID: 0006_care
Revises: 0005_patient_profile
Create Date: 2026-10-16

"""
from collections.abc import Sequence

import sqlalchemy as sa

from alembic import op

revision: str = "0006_care"
down_revision: str | None = "0005_patient_profile"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.create_table(
        "care_plans",
        sa.Column("id", sa.Uuid, primary_key=True),
        sa.Column("patient_id", sa.Uuid, sa.ForeignKey("patients.id", ondelete="CASCADE"),
                  nullable=False, index=True),
        sa.Column("doctor_id", sa.Uuid, sa.ForeignKey("doctors.id", ondelete="SET NULL")),
        sa.Column("record_id", sa.Uuid, sa.ForeignKey("records.id", ondelete="SET NULL")),
        sa.Column("diet", sa.JSON, nullable=False),
        sa.Column("activity", sa.JSON, nullable=False),
        sa.Column("tests", sa.JSON, nullable=False),
        sa.Column("follow_up_date", sa.Date),
        sa.Column("notes", sa.String(1000)),
        sa.Column("active", sa.Boolean, nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(),
                  nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(),
                  nullable=False),
    )
    op.create_table(
        "care_logs",
        sa.Column("id", sa.Uuid, primary_key=True),
        sa.Column("patient_id", sa.Uuid, sa.ForeignKey("patients.id", ondelete="CASCADE"),
                  nullable=False, index=True),
        sa.Column("item_key", sa.String(120), nullable=False),
        sa.Column("log_date", sa.Date, nullable=False),
        sa.Column("done", sa.Boolean, nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(),
                  nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(),
                  nullable=False),
        sa.UniqueConstraint("patient_id", "item_key", "log_date"),
    )


def downgrade() -> None:
    op.drop_table("care_logs")
    op.drop_table("care_plans")
