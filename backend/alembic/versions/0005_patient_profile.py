"""patients: gender, blood_group, address

Revision ID: 0005_patient_profile
Revises: 0004_rx_author
Create Date: 2026-09-02

"""
from collections.abc import Sequence

import sqlalchemy as sa

from alembic import op

revision: str = "0005_patient_profile"
down_revision: str | None = "0004_rx_author"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    with op.batch_alter_table("patients") as batch:
        batch.add_column(sa.Column("gender", sa.String(16), nullable=True))
        batch.add_column(sa.Column("blood_group", sa.String(8), nullable=True))
        batch.add_column(sa.Column("address", sa.String(300), nullable=True))


def downgrade() -> None:
    with op.batch_alter_table("patients") as batch:
        batch.drop_column("address")
        batch.drop_column("blood_group")
        batch.drop_column("gender")
