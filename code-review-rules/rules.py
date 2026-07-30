from sqlfluff.core.rules import BaseRule, LintResult
from sqlfluff.core.rules.crawlers import SegmentSeekerCrawler


class Rule_CES01(BaseRule):
    """ALTER TABLE statement targets a table with Change Event Streaming (CES) enabled."""

    groups = ("all",)
    name = "custom.ces_alter_table"
    crawl_behaviour = SegmentSeekerCrawler({"alter_table_statement"})
    is_fix_compatible = False
    config_keywords = ["ces_enabled_tables"]

    def _eval(self, context):
        table_ref = context.segment.get_child("table_reference")
        if table_ref is None:
            return None

        # A table_reference is schema-qualified (e.g. dbo.Orders); the table
        # name itself is the last identifier segment.
        identifiers = table_ref.get_children("naked_identifier", "quoted_identifier")
        if not identifiers:
            return None

        table_name = identifiers[-1].raw.strip("[]\"").lower()
        ces_tables = {
            name.strip().lower()
            for name in self.ces_enabled_tables.split(",")
            if name.strip()
        }

        if table_name in ces_tables:
            return LintResult(
                anchor=context.segment,
                description=(
                    f"ALTER TABLE on '{identifiers[-1].raw}' is flagged (CES01): this table has "
                    "Change Event Streaming (CES) enabled. Disable CES on it before deploying "
                    "this migration, then re-enable it afterwards."
                ),
            )

        return None
