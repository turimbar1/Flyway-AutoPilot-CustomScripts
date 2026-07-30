from sqlfluff.core.plugin import hookimpl


@hookimpl
def get_rules():
    # Import inside the hook (not at module top level) so the plugin
    # package initialises correctly when Flyway loads it.
    from .rules import Rule_CES01

    return [Rule_CES01]


@hookimpl
def get_configs_info():
    return {
        "ces_enabled_tables": {
            "definition": (
                "Comma-separated list of tables that currently have Change "
                "Event Streaming (CES) enabled, e.g. 'Orders,Customers,Payments'. "
                "Schema prefixes are ignored when matching, so 'Orders' also "
                "matches 'dbo.Orders' and '[dbo].[Orders]'."
            ),
            "default": "",
        },
    }
