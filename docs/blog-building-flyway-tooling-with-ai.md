# Building Developer Tooling with AI: A Real Session Building Flyway Automation

*How I used Claude to learn the Flyway CLI, parse command output, hit roadblocks, and build a production-ready sync script—in one session*

## The Starting Point

I had a customer demo coming up. The scenario: multiple developers sharing a development database, each needing to sync only their changes to version control. Flyway Desktop handles this beautifully with its GUI, but this customer wanted a CLI-based workflow—something they could give to full-stack developers without mandating new tool installations.

I knew Flyway's CLI could do this, but the command orchestration was complex. Rather than spending hours reading documentation and experimenting, I decided to pair with Claude to build the tooling.

What followed was a fascinating session in AI-assisted development.

## Phase 1: Learning the CLI

I started by asking Claude to help me understand Flyway's diff, generate, and model commands. But here's the thing—Claude's training data might not include the latest Flyway Enterprise features. So instead of trusting assumptions, we tested everything.

```powershell
flyway diff -source=development -target=schemaModel
```

Claude would propose a command, I'd run it, and we'd analyze the output together. When something didn't work, we'd adjust. This iterative loop was faster than reading documentation because we were learning *my specific environment*—my flyway.toml configuration, my database structure, my edge cases.

**Key insight**: AI doesn't need to know everything upfront. It can learn from command output in real-time.

## Phase 2: Parsing the Output

Flyway's diff command outputs a formatted table:

```
+-----------------------------+--------+-------------+-----------+-------------------+
| Id                          | Change | Object Type | Schema    | Name              |
+-----------------------------+--------+-------------+-----------+-------------------+
| qYeSVUalajMMv8YBVPOVHGPiruo | Edit   | Procedure   | Logistics | AddMaintenanceLog |
| knByn_3KWTffGJwjmAhrDr7x.uA | Edit   | Procedure   | Sales     | Sales by Year     |
+-----------------------------+--------+-------------+-----------+-------------------+
```

We needed to extract those cryptic change IDs to pass to subsequent commands. Claude wrote regex patterns to parse this table format, extracting the change ID, object type, schema, and name into PowerShell objects.

```powershell
if ($line -match '^\|\s*(\S+)\s*\|\s*(\w+)\s*\|\s*(\w+)\s*\|\s*(\w+)\s*\|\s*([^|]+)\s*\|') {
    $changeId = $matches[1].Trim()
    $changeType = $matches[2].Trim()
    # ...
}
```

This worked on the first try—a reminder that AI excels at text parsing tasks that would be tedious to write manually.

## Phase 3: The Workflow Takes Shape

We built out the core workflow:

1. `flyway diff` to find changes between development and schema-model
2. Filter to only the objects the user specified
3. `flyway generate` to create a migration script
4. `flyway migrate` to apply it to shadow
5. `flyway model` to update schema-model from shadow

Each step required understanding Flyway's parameters. Some weren't obvious:
- `-diff.buildEnvironment` to specify where to build for comparison
- `-generate.changes` to limit which changes to script
- `-redgateCompare.sqlserver.options.behavior.includeDependencies=false` to avoid pulling in related objects

We discovered these by testing commands and reading error messages together.

## Phase 4: The Roadblock

Then we hit a wall.

The dry-run mode wasn't showing the correct migration script preview. It would say "No migration script generated" for objects that clearly had changes.

After debugging, we discovered the issue: **change IDs are context-specific**.

When you diff `development → schemaModel`, an object might have change ID `ABC123` with change type "Add" (it's in dev but not in the model).

But when you diff `development → shadow`, that *same object* has a different change ID `XYZ789` with change type "Edit" (it exists in shadow but differs).

The dry run was using change IDs from the first diff for the generate preview, but generate was running against a different diff context. The IDs didn't match.

**The fix**: Run a separate diff from development to shadow specifically for the generate preview, then match objects by name to get the correct change IDs for that context.

```powershell
# Run diff from development to target (shadow) to get correct change IDs
$genDiffCommand = "flyway diff `"-diff.source=development`" `"-diff.target=$Target`""
$genDiffOutput = Invoke-Expression $genDiffCommand

# Parse and match by object name, not change ID
foreach ($obj in $matchedChanges) {
    $matched = $genChanges | Where-Object { $_.FullName -eq $obj.FullName }
    if ($matched) {
        $genChangeIds += $matched.ChangeId
    }
}
```

This was a subtle bug that required understanding Flyway's internal model. Claude didn't know this upfront—we discovered it together by testing and analyzing behavior.

## Phase 5: Feature Creep (The Good Kind)

Once the core script worked, we added features:

**`-DryRun` mode**: Preview changes without modifying anything. Shows both the schema-model diff and the migration script that would be generated.

**`-Mine` parameter**: Queries SQL Server's default trace to find which objects *you* modified, then syncs only those. Perfect for shared development databases.

```powershell
.\Sync-FlywayObjects.ps1 -Mine -DryRun

# Output:
# Found 3 changes:
#   - Logistics.AddMaintenanceLog [Procedure] - Edit (by RED-GATE\andrew.pierce)
#   - Sales.Sales by Year [Procedure] - Edit (by RED-GATE\andrew.pierce)  
#   - dbo.MissionDetail [Table] - Edit (by unknown)
# 
# Step 3: Filtering for requested objects...
#   ✓ Your change: Logistics.AddMaintenanceLog
#   ✓ Your change: Sales.Sales by Year
#   ✗ Skipping: dbo.MissionDetail (by unknown)
```

**Cross-platform support**: Created a bash version for Linux/Mac users.

**Auto-generated descriptions**: Pulls git branch and username to create meaningful migration names.

## What I Learned About AI-Assisted Development

### 1. Test Everything in Your Environment

Claude made educated guesses about Flyway parameters, but we validated every command. Sometimes the syntax was slightly off, or a parameter didn't exist in my version. The feedback loop of "try it → see the error → fix it" was fast and effective.

### 2. AI Excels at Text Parsing

Writing regex to parse Flyway's table output by hand would have been tedious. Claude generated working patterns immediately. This is where AI provides the most leverage—tasks that are straightforward but time-consuming.

### 3. Complex Bugs Require Collaboration

The change ID mismatch wasn't something Claude could have known from training data. We discovered it together by observing behavior, forming hypotheses, and testing. The AI's role shifted from "knowing the answer" to "helping debug systematically."

### 4. Documentation Emerges Naturally

As we built the script, Claude added comprehensive comment-based help, examples, and inline comments. The documentation wasn't an afterthought—it emerged alongside the code.

### 5. Iteration Beats Planning

We didn't design the full architecture upfront. We started with a minimal script, tested it, added features, hit bugs, fixed them, and repeated. The AI's ability to refactor and extend code made this iterative approach practical.

## The End Result

In one session, we produced:

- **Sync-FlywayObjects.ps1**: A production-ready PowerShell script with `-Objects`, `-All`, `-Mine`, `-DryRun`, and `-SkipGenerate` parameters
- **sync-flyway-objects.sh**: A cross-platform bash equivalent
- **Comprehensive documentation**: Both inline help and a blog post explaining use cases
- **FLYWAY_AI_CONTEXT.md**: A reference document for future AI sessions on this codebase

The script handles the full workflow—diff, filter, generate, migrate, model—in a single command. It queries SQL Server's default trace to show who made each change. It generates correct migration scripts for complex objects like partitioned tables and temporal tables (thanks to Flyway's Compare engine).

And it's something I can hand to a full-stack developer with zero Flyway knowledge. They run one command, specify their objects, and they're done.

## Would I Do This Again?

Absolutely. The session took a few hours, but manually building this would have taken much longer—especially the debugging phase where we had to understand Flyway's change ID behavior.

The key was treating Claude as a collaborator, not an oracle. When it didn't know something, we figured it out together. When it made mistakes, we corrected them in real-time. When it suggested something that worked, we moved fast.

AI-assisted development isn't about AI writing code while you watch. It's about accelerating your workflow—handling the tedious parts so you can focus on the interesting problems.

Like figuring out why change IDs don't match across diff contexts. That was the interesting problem. And solving it together was the fun part.

---

*The Sync-FlywayObjects scripts built in this session are available in the [Flyway-AutoPilot-FastTrack](https://github.com/red-gate/Flyway-AutoPilot-FastTrack) repository.*
