# Database DevOps for the Rest of Us: A CLI Workflow Full-Stack Developers Will Actually Use

*Bringing database change management to developers who aren't database experts—without the learning curve*

## The Challenge: Making Database Changes Accessible to Everyone

Enterprise organizations face a common challenge: how do you enable hundreds of developers across dozens of teams to safely make database changes?

Your DBA team can't review every column addition. Your platform team can't be a bottleneck for every stored procedure update. But without guardrails, you get schema drift, broken deployments, and audit nightmares.

**The reality for most teams today**: There is no sync tool. Developers manually script out their changes—right-click in SSMS, "Script Table As > ALTER To", paste into a migration file, hope they didn't miss anything. For complex objects like partitioned tables, temporal tables, or anything with engine-specific syntax, this manual approach is error-prone and tedious.

Some teams have adopted sync tools, but many are overly simplistic. They generate scripts that work for basic tables but choke on:
- Partitioning and storage configurations
- Temporal tables with history tracking
- Computed columns with complex expressions
- Database-specific syntax variations

The tools that *do* handle complexity well—like Flyway Desktop—require installation, training, and ongoing maintenance. That's fine for dedicated database developers. But what about the full-stack team that touches the database three times a year? What about the 15 teams sharing a development instance?

**The goal**: Give every developer a simple, reliable way to capture their database changes without requiring new tools, extensive training, or DBA intervention.

## The Complexity Behind "Simple"

Flyway is built on Redgate's Compare engine—the same technology that powers SQL Compare, battle-tested over 20+ years handling every corner case in SQL Server, Oracle, PostgreSQL, and MySQL. It understands your database engine deeply enough to generate correct, deployable scripts for even the most complex objects.

But the Flyway CLI, while powerful, has a learning curve. The workflow for syncing a single object involves multiple commands, parsing output, and understanding change IDs. That's fine for power users, but it's a barrier to adoption at scale.

And there's another challenge in shared environments. You run `flyway diff` and see 47 changes—but only 2 are yours. The rest belong to other developers working on different tickets. Syncing everything means your pull request includes untested changes, code reviewers can't tell what's yours, and the audit trail becomes meaningless.

## What Teams Actually Need

When we talk to enterprise teams, the same requirements come up:

1. **Low barrier to entry**: Developers shouldn't need to install specialized tools or learn complex CLI syntax
2. **Selective control**: Sync only what you changed, not everyone else's work-in-progress
3. **Correct scripts every time**: Handle complex objects—partitioning, temporal tables, computed columns—without manual intervention
4. **Pipeline-ready**: Integrate with existing CI/CD and ticketing systems
5. **Self-service**: Developers can sync their own changes without DBA bottlenecks

Flyway provides the engine to do all of this. The challenge is packaging it in a way that scales across teams with varying levels of database expertise.

## The Spectrum of Options

Flyway offers flexibility—but with that comes choices:

| Approach | Best For | Trade-offs |
|----------|----------|------------|
| **Flyway Desktop** | Dedicated DB developers, complex refactoring, visual feedback | Requires installation, learning curve, not pipeline-friendly |
| **Flyway CLI** | Power users, full automation, scripting | Steep learning curve, many commands to orchestrate |
| **Wrapper Script** | Everyone else—occasional devs, ticket-driven workflows, CI/CD | Less visual, requires PowerShell/Bash |

Flyway Desktop is excellent for teams doing heavy database development. But it's overhead for the full-stack developer who touches the database three times a year.

The CLI is powerful, but the workflow for selective sync involves 7+ commands:

```bash
flyway diff → parse output → flyway diff (again) → flyway generate → flyway migrate → flyway diff (again) → flyway model
```

That's a lot to remember—and easy to get wrong.

## The Solution: One Command

What if platform teams could give developers a single command that does everything right?

```powershell
# Sync specific objects
.\Sync-FlywayObjects.ps1 -Objects "Sales.Orders", "Sales.GetOrderTotal"

# Sync only YOUR changes (queries SQL Server default trace)
.\Sync-FlywayObjects.ps1 -Mine

# Or on Linux/Mac
./sync-flyway-objects.sh -o "Sales.Orders,Sales.GetOrderTotal"
```

This approach:
- **Zero learning curve**: Developers specify what they changed, the script handles the rest
- **Correct scripts every time**: Uses Flyway's Compare engine for complex objects
- **Self-service**: No DBA required for routine changes
- **Pipeline-ready**: Integrates with CI/CD and ticketing systems
- **Cross-platform**: PowerShell for Windows, Bash for Linux/Mac

## How Organizations Are Using This

### Scenario 1: Shared Development Database

A retail company has 15 developers sharing a development SQL Server instance. Each developer works on separate tickets, making unrelated changes throughout the day.

**Before**: Developers avoided syncing because they didn't want to pull in everyone else's changes. The schema-model drifted from reality.

**After**: Each developer syncs only their own changes:
```powershell
# Automatically sync only changes made by the current Windows user
.\Sync-FlywayObjects.ps1 -Mine
```

Or syncs specific objects:
```bash
./sync-flyway-objects.sh -o "Inventory.Products,Inventory.GetStockLevel" \
    -d "TICKET-4521-inventory-updates"
```

Pull requests now contain only the relevant changes. Code reviews are focused. Deployments are predictable.

### Scenario 2: Ticket-Driven Automation

A financial services company tracks database changes in Jira. Each ticket has an "Objects Changed" field listing the affected database objects.

Their CI pipeline reads this metadata and automatically syncs the specified objects:

```yaml
# Azure DevOps pipeline
- script: |
    OBJECTS=$(curl -s "https://jira.company.com/api/ticket/$TICKET_ID" | jq -r '.objectsChanged')
    ./sync-flyway-objects.sh -o "$OBJECTS" -d "$TICKET_ID"
  displayName: 'Sync Database Changes'
```

No manual intervention. Full traceability. Audit-friendly.

### Scenario 3: Large Schema Performance

A manufacturing company has a database with over 20,000 objects. A full `flyway diff` takes 15+ minutes.

**Before**: Developers would start a diff, go get coffee, come back, forget what they were doing.

**After**: They run the sync script in the background:
```bash
nohup ./sync-flyway-objects.sh -o "Production.WorkOrder" > sync.log 2>&1 &
```

The script handles the waiting. Developers stay productive.

### Scenario 4: Code Review Workflow

Before creating a pull request, developers preview exactly what will be committed:

```powershell
.\Sync-FlywayObjects.ps1 -Objects "Sales.Customers" -DryRun
```

Output:
```
Found 3 changes:
  - Sales.Customers [Table] - Edit (by RED-GATE\jsmith at 2026-02-27 10:15)
  - Sales.Orders [Table] - Edit (by RED-GATE\mjones at 2026-02-27 09:30)
  - Inventory.Products [Table] - Edit (by RED-GATE\jsmith at 2026-02-26 14:20)

Objects to process:
  - Sales.Customers (by RED-GATE\jsmith)

Schema Model Changes Preview:
-----------------------------
--- Tables/Sales.Customers.sql
+++ Tables/Sales.Customers.sql
+[LoyaltyTier] [nvarchar] (20) NULL,

Migration Script Preview:
-------------------------
--- V015__main_Edit_Sales_Customers_jsmith.sql ---
ALTER TABLE [Sales].[Customers] ADD
[LoyaltyTier] [nvarchar] (20) NULL
GO
```

The dry run mode also queries SQL Server's default trace to show **who made each change**. In shared development environments, this is invaluable—you can immediately see "Sarah made this change, not me" and avoid syncing the wrong objects.

No surprises. No guessing. Clear communication.

## How It Works

The script orchestrates the Flyway CLI commands in the correct sequence:

1. **Diff** development → schemaModel (find what changed)
2. **Filter** to requested objects (extract relevant change IDs)
3. **Generate** migration script (development → migrations with shadow build)
4. **Migrate** to shadow database (apply the migration)
5. **Model** from shadow → schemaModel (update the folder from what migrations produce)

This workflow ensures the schema-model represents what your migrations *actually create*, not just a copy of development. That's a subtle but important distinction—it catches errors where migrations don't perfectly reproduce the source.

### Why the Compare Engine Matters

Under the hood, Flyway uses Redgate's Compare engine—the same technology behind SQL Compare, refined over 20+ years. This isn't a simple text diff. It understands:

- **Partitioned tables**: Generates correct `ALTER PARTITION SCHEME` and `ALTER PARTITION FUNCTION` statements
- **Temporal tables**: Handles system-versioned tables with history tables correctly
- **Computed columns**: Preserves expressions and persistence settings
- **Filegroups and storage**: Respects where objects are physically stored
- **Dependencies**: Understands that you can't drop a table referenced by a foreign key

When you run the sync script on a complex object, you get a migration script that actually works—not a best-guess approximation that fails in production.

## Getting Started

### Prerequisites
- Flyway Enterprise Edition (for diff/model commands)
- A `flyway.toml` with `development` and `shadow` environments defined
- Git (optional, for auto-generating descriptions)

### Basic Usage

```bash
# PowerShell (Windows)
.\Sync-FlywayObjects.ps1 -Objects "Schema.TableName"

# Bash (Linux/Mac)
./sync-flyway-objects.sh -o "Schema.TableName"

# Multiple objects
.\Sync-FlywayObjects.ps1 -Objects "Sales.Orders","Sales.GetOrderTotal"

# Sync only YOUR changes (queries SQL Server default trace)
.\Sync-FlywayObjects.ps1 -Mine

# Sync all changes (use with caution in shared environments!)
.\Sync-FlywayObjects.ps1 -All

# Preview mode
.\Sync-FlywayObjects.ps1 -Objects "Sales.Orders" -DryRun

# Custom description
.\Sync-FlywayObjects.ps1 -Objects "Sales.Orders" -Description "TICKET-1234-add-status-column"
```

## Choosing the Right Tool for Each Team

Not every team needs the same approach. Here's how to think about it:

| Team Profile | Recommended Approach |
|--------------|---------------------|
| Dedicated DB developers | Flyway Desktop for rich visual feedback and dependency analysis |
| Full-stack teams (occasional DB changes) | Sync script—zero install, minimal learning |
| Platform/DevOps teams | Sync script integrated into CI/CD pipelines |
| Large schemas (10k+ objects) | Sync script running in background |
| Training new developers | Flyway Desktop to learn the concepts, then script for daily use |

The approaches complement each other. Many organizations use Flyway Desktop for their core database team while providing the sync script to everyone else.

## Scaling Database DevOps Across the Organization

The real value of this approach isn't the script itself—it's what it enables:

**For Developers**: Make database changes the same way you make code changes. No special tools, no waiting for DBAs, no manual scripting.

**For Platform Teams**: Provide a standardized workflow that works across all teams. Integrate with existing ticketing systems. Maintain audit trails automatically.

**For DBAs**: Stop being a bottleneck for routine changes. Focus on architecture, performance, and complex migrations while developers handle their own table tweaks.

**For the Organization**: Ship faster. Every team that can self-serve database changes is a team that doesn't need to wait in a queue.

The barrier to database DevOps adoption isn't usually technical—it's the learning curve and tooling overhead. By wrapping Flyway's powerful engine in a simple interface, you remove that barrier.

One command. Correct scripts. Self-service. That's how you scale database development across teams.

---

*The Sync-FlywayObjects scripts are available in the [Flyway-AutoPilot-FastTrack](https://github.com/red-gate/Flyway-AutoPilot-FastTrack) repository. Contributions welcome.*
