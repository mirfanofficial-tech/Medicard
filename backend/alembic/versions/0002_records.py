"""records and extraction_jobs

Revision ID: 0002_records
Revises: 0001_initial
Create Date: 2026-09-01

"""
from collections.abc import Sequence

import sqlalchemy as sa

from alembic import op

revision: str = "0002_records"
down_revision: str | None = "0001_initial"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None

_ts = dict(server_default=sa.func.now(), nullable=False)


def upgrade() -> None:
    op.create_table(
        "records",
        sa.Column("id", sa.Uuid(), primary_key=True),
        sa.Column("patient_id", sa.Uuid(), nullable=False),
        sa.Column("type", sa.String(16), nullable=False),
        sa.Column("doc_date", sa.Date(), nullable=True),
        sa.Column("provider", sa.String(200), nullable=True),
        sa.Column("data", sa.JSON(), nullable=False),
        sa.Column("source_object_key", sa.String(300), nullable=True),
        sa.Column("verified", sa.Boolean(), nullable=False, server_default=sa.false()),
        sa.Column("verified_by", sa.Uuid(), nullable=True),
        sa.Column("verified_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("sensitive", sa.Boolean(), nullable=False, server_default=sa.false()),
        sa.Column("extraction_job_id", sa.Uuid(), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), **_ts),
        sa.Column("updated_at", sa.DateTime(timezone=True), **_ts),
        sa.ForeignKeyConstraint(["patient_id"], ["patients.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["verified_by"], ["users.id"], ondelete="SET NULL"),
    )
    op.create_index("ix_records_patient_id", "records", ["patient_id"])

    op.create_table(
        "extraction_jobs",
        sa.Column("id", sa.Uuid(), primary_key=True),
        sa.Column("patient_id", sa.Uuid(), nullable=False),
        sa.Column("record_id", sa.Uuid(), nullable=False),
        sa.Column("status", sa.String(16), nullable=False),
        sa.Column("raw_model_output", sa.JSON(), nullable=True),
        sa.Column("confidence_by_field", sa.JSON(), nullable=True),
        sa.Column("error", sa.String(500), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), **_ts),
        sa.Column("updated_at", sa.DateTime(timezone=True), **_ts),
        sa.ForeignKeyConstraint(["patient_id"], ["patients.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["record_id"], ["records.id"], ondelete="CASCADE"),
    )
    op.create_index("ix_extraction_jobs_patient_id", "extraction_jobs", ["patient_id"])
    op.create_index("ix_extraction_jobs_record_id", "extraction_jobs", ["record_id"])


def downgrade() -> None:
    op.drop_index("ix_extraction_jobs_record_id", "extraction_jobs")
    op.drop_index("ix_extraction_jobs_patient_id", "extraction_jobs")
    op.drop_table("extraction_jobs")
    op.drop_index("ix_records_patient_id", "records")
    op.drop_table("records")
