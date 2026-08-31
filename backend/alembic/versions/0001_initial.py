"""initial schema: users, patients, doctors, otp_challenges

Revision ID: 0001_initial
Revises:
Create Date: 2026-08-31

"""
from collections.abc import Sequence

import sqlalchemy as sa

from alembic import op

revision: str = "0001_initial"
down_revision: str | None = None
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None

_ts = dict(server_default=sa.func.now(), nullable=False)


def upgrade() -> None:
    op.create_table(
        "users",
        sa.Column("id", sa.Uuid(), primary_key=True),
        sa.Column("role", sa.String(16), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), **_ts),
        sa.Column("updated_at", sa.DateTime(timezone=True), **_ts),
    )

    op.create_table(
        "patients",
        sa.Column("id", sa.Uuid(), primary_key=True),
        sa.Column("user_id", sa.Uuid(), nullable=True),
        sa.Column("name", sa.String(120), nullable=False),
        sa.Column("dob", sa.Date(), nullable=True),
        sa.Column("phone", sa.String(32), nullable=True),
        sa.Column("cnic_hash", sa.String(64), nullable=True),
        sa.Column("medicard_code", sa.String(16), nullable=False),
        sa.Column("guardian_patient_id", sa.Uuid(), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), **_ts),
        sa.Column("updated_at", sa.DateTime(timezone=True), **_ts),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["guardian_patient_id"], ["patients.id"], ondelete="SET NULL"),
        sa.UniqueConstraint("medicard_code", name="uq_patients_medicard_code"),
    )
    op.create_index("ix_patients_user_id", "patients", ["user_id"])
    op.create_index("ix_patients_phone", "patients", ["phone"])
    op.create_index("ix_patients_medicard_code", "patients", ["medicard_code"])
    op.create_index("ix_patients_guardian_patient_id", "patients", ["guardian_patient_id"])

    op.create_table(
        "doctors",
        sa.Column("id", sa.Uuid(), primary_key=True),
        sa.Column("user_id", sa.Uuid(), nullable=False),
        sa.Column("name", sa.String(120), nullable=False),
        sa.Column("email", sa.String(255), nullable=False),
        sa.Column("password_hash", sa.String(255), nullable=False),
        sa.Column("licence_no", sa.String(64), nullable=False),
        sa.Column("specialty", sa.String(120), nullable=True),
        sa.Column("hospital", sa.String(200), nullable=True),
        sa.Column("status", sa.String(32), nullable=False),
        sa.Column("reviewed_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("reviewed_note", sa.String(500), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), **_ts),
        sa.Column("updated_at", sa.DateTime(timezone=True), **_ts),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="CASCADE"),
        sa.UniqueConstraint("user_id", name="uq_doctors_user_id"),
        sa.UniqueConstraint("email", name="uq_doctors_email"),
    )
    op.create_index("ix_doctors_email", "doctors", ["email"])

    op.create_table(
        "otp_challenges",
        sa.Column("id", sa.Uuid(), primary_key=True),
        sa.Column("phone", sa.String(32), nullable=False),
        sa.Column("code_hash", sa.String(255), nullable=False),
        sa.Column("purpose", sa.String(16), nullable=False),
        sa.Column("expires_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("attempts", sa.Integer(), nullable=False),
        sa.Column("consumed_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), **_ts),
        sa.Column("updated_at", sa.DateTime(timezone=True), **_ts),
    )
    op.create_index("ix_otp_challenges_phone", "otp_challenges", ["phone"])


def downgrade() -> None:
    op.drop_table("otp_challenges")
    op.drop_index("ix_doctors_email", "doctors")
    op.drop_table("doctors")
    for ix in (
        "ix_patients_guardian_patient_id",
        "ix_patients_medicard_code",
        "ix_patients_phone",
        "ix_patients_user_id",
    ):
        op.drop_index(ix, "patients")
    op.drop_table("patients")
    op.drop_table("users")
