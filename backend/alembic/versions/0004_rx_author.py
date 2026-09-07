"""records.authored_by_doctor_id

Revision ID: 0004_rx_author
Revises: 0003_access
Create Date: 2026-09-01

"""
from collections.abc import Sequence

import sqlalchemy as sa

from alembic import op

revision: str = "0004_rx_author"
down_revision: str | None = "0003_access"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    with op.batch_alter_table("records") as batch:
        batch.add_column(sa.Column("authored_by_doctor_id", sa.Uuid(), nullable=True))
        batch.create_foreign_key(
            "fk_records_authored_by_doctor_id",
            "doctors",
            ["authored_by_doctor_id"],
            ["id"],
            ondelete="SET NULL",
        )


def downgrade() -> None:
    with op.batch_alter_table("records") as batch:
        batch.drop_constraint("fk_records_authored_by_doctor_id", type_="foreignkey")
        batch.drop_column("authored_by_doctor_id")
