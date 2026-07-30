# LinkedIn Article: Building Developer Tooling with AI

---

**TITLE:** Building Developer Tooling with AI: Simplifying Database Workflows with Flyway CLI

**SUBTITLE:** Spoiler: It wasn't magic. It was collaboration.

---

Last week I needed to build a CLI tool for a customer demo. The scenario: multiple developers sharing a database, each needing to sync only their changes to version control.

But this usecase required parsing console outputs, parameterizing those and using them for subsequent commands - so it required deep experimentation and not a small amount of Powershell/Bash scripting, not to mention yuck... Regex. So, I paired with Claude.

Here's what I learned about AI-assisted development—the good, the bad, and the surprising.

---

**THE TASK**

Flyway (a database migration tool) has powerful CLI commands for comparing databases and generating scripts. But the workflow involves 7+ commands in the right sequence, parsing output, and passing cryptic "change IDs" between steps.

I wanted one command that does everything:

Sync-FlywayObjects -Objects "Sales.Orders"

Simple for developers. Complex under the hood.

---

**WHAT WORKED WELL**

𝗧𝗲𝘅𝘁 𝗽𝗮𝗿𝘀𝗶𝗻𝗴 𝘄𝗮𝘀 𝗶𝗻𝘀𝘁𝗮𝗻𝘁

Flyway outputs formatted tables. I needed regex to extract IDs. Writing that by hand? Tedious. Claude generated working patterns immediately.

This is where AI provides the most leverage—tasks that are straightforward but time-consuming.

𝗜𝘁𝗲𝗿𝗮𝘁𝗶𝗼𝗻 𝘄𝗮𝘀 𝗳𝗮𝘀𝘁

We didn't plan the architecture upfront. We started simple, tested, added features, hit bugs, fixed them, repeated.

AI's ability to refactor and extend code made this iterative approach practical. Each cycle took minutes, not hours.

𝗗𝗼𝗰𝘂𝗺𝗲𝗻𝘁𝗮𝘁𝗶𝗼𝗻 𝗲𝗺𝗲𝗿𝗴𝗲𝗱 𝗻𝗮𝘁𝘂𝗿𝗮𝗹𝗹𝘆

As we built, Claude added inline help, examples, and comments. Documentation wasn't an afterthought—it grew alongside the code.

---

**WHERE WE HIT A WALL**

The dry-run mode wasn't showing correct script previews. It would say "No script generated" for objects that clearly had changes.

After debugging together, we discovered something subtle:

Change IDs are context-specific.

When comparing Database A → Folder X, an object gets ID "ABC123" (type: Add).
When comparing Database A → Database B, the same object gets ID "XYZ789" (type: Edit).

We were using IDs from one context in a different context. They didn't match.

This wasn't something Claude could have known from training data. We discovered it by testing, hypothesizing, and observing behavior.

The fix required running a separate comparison in the right context and matching objects by name instead of ID.

---

**THE HONEST TRUTH ABOUT AI-ASSISTED DEV**

𝗜𝘁'𝘀 𝗻𝗼𝘁 𝗺𝗮𝗴𝗶𝗰.

Claude made educated guesses about CLI parameters. Some were wrong. We tested everything in my actual environment and fixed issues in real-time.

𝗖𝗼𝗺𝗽𝗹𝗲𝘅 𝗯𝘂𝗴𝘀 𝗿𝗲𝗾𝘂𝗶𝗿𝗲 𝗰𝗼𝗹𝗹𝗮𝗯𝗼𝗿𝗮𝘁𝗶𝗼𝗻.

The change ID bug wasn't solvable by AI alone. We figured it out together—me observing behavior, Claude helping debug systematically.

𝗧𝗵𝗲 𝗔𝗜 𝗶𝘀𝗻'𝘁 𝘁𝗵𝗲 𝗲𝘅𝗽𝗲𝗿𝘁. 𝗬𝗼𝘂 𝗮𝗿𝗲.

I know a lot about Flyway - as a Solutions Architect specializing in Flyway - it is my job to know how it scripts out database changes, and connects/auths/deploys to target databases to help enterprise teams be confident in their releases.

So much can go wrong in a database deployment - so my main goal with each engagement, is to make that final release to Prod boring... mundane - A Truly Noble Ambition.

I knew the desired workflow. I knew the pitfalls, expected behavior, and client needs. Claude accelerated the implementation, but the domain knowledge was mine.

---

**WHAT WE BUILT**

In one session:

→ A PowerShell script with -Objects, -All, -Mine, -DryRun parameters
→ A cross-platform bash version
→ Integration with SQL Server's default trace to show WHO made each change
→ Comprehensive documentation

The -Mine flag is my favorite. It queries the database to find changes made by your Windows login. In shared environments, you can sync just your work:

Sync-FlywayObjects -Mine

No more accidentally including someone else's half-finished changes.

My ultimate goals helping to make a processes that works for anyone - to scale database automation across large teams of heterogenous users (SQL Server, Oracle, Postgres, full-stack, DBAs, DB devs, DevOps/SRE/Release engineers).

And this is a great first start.

I'll publish the code soon but just the process of building it was eye-opening.

---

What's your experience with AI-assisted development? Have you found it changes HOW you approach problems, not just how fast you solve them?

#softwaredevelopment #ai #devtools #database #flyway #devops #automation
