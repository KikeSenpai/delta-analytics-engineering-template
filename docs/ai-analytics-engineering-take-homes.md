# Can AI one-shot an analytics-engineering take-home? Evidence from two blind runs

*We gave AI agents the same analytics-engineering take-home three times, reviewed each result blind, and compared it with a human-refined reference. The short answer is "yes, with the right prompt and a verification loop"; the useful answer is what that prompt had to contain.*

The first AI solution to our take-home took seven minutes to write, built 20 dbt models, passed 79 of 80 tests, and was wrong in ways no test could catch. It labelled customers with a null group as `individual` (nothing in the source said so), invented seat-capacity bands (`up to 19`, `20–100`, `101–250`, `more than 250`) and price bands (`under 1,000 EUR`, `1,000–1,999 EUR`, `2,000 EUR or more`) that no brief asked for, and added two intermediate models and two snowflaked dimensions that no consumer needed. Turning it into something a human was willing to sign took a 600-message thread over two days.

Six weeks later, a different model under a stricter prompt produced a passing solution blind in 24 minutes, and a second blind run with a sharper prompt produced the best solution of the whole exercise in 38 minutes. The agent did not get smarter between those two runs. The prompt did.

This article is about what sits between "AI can write dbt models" and "AI can be trusted to answer a business question from a spreadsheet", why that gap is exactly what a take-home test now measures, and why we published the stack we used so candidates can spend their time on the gap instead of on Docker.

## What we did, in one table

Everything below comes from eight recorded agent threads and three Git branches in the public [delta-analytics-engineering-template](https://github.com/KikeSenpai/delta-analytics-engineering-template) repository. The exercise is a real take-home that we received; the company is substituted with a fictional "Uber Air" marketplace throughout, and the only data in play is the six small source files the exercise shipped with (20 trips, 20 orders, 20 customers, 5 customer groups, 10 aircraft, 19 aircraft models).

| Step | When | Agent | Mode | Output | Measured result |
| --- | --- | --- | --- | --- | --- |
| Original solve | 2026-08-30 | OpenAI-backed model (operator records it as GPT-5.6 Sol) | medium | branch `take-home/air-service`, 20 models | `dbt test` PASS=79 WARN=1 of 80; no MinIO in that template version |
| Human refinement | 2026-10-10 to 10-11 | Fireworks-hosted model (name not recorded) | low | same branch, commit `17e4134`, 16 models | `dbt run` 16/16, `dbt test` PASS=73 WARN=1 of 74; ~11 implementation rounds, 600 messages, roughly 60–70 human messages |
| Blind eval attempt 1 | 2026-10-11, 24 min | Anthropic-backed model (operator records it as Claude Opus 5.5) | medium | `eval/air-service-attempt-1-medium`, 11 models | `just verify` clean: 11/11 models, tests PASS=61 WARN=3 of 64 before and after restart; 6 raw + 11 analytics tables in MinIO |
| Blind review of attempt 1 | 2026-10-11, 13 min | OpenAI-backed reviewer | high | verdict | PASS, no blockers, several non-blocking findings |
| Reference comparison of attempt 1 | 2026-10-11, 6 min | OpenAI-backed reviewer | high | verdict | PASS; "no further attempt materially necessary", with five prompt lessons |
| Blind eval attempt 2 | 2026-10-11, 38 min | Anthropic-backed model (operator records it as Claude Opus 5.5) | medium | `eval/air-service-attempt-2-medium`, 20 models | `just verify` clean: 20/20 models, tests 99/99 before and after restart; 6 raw + 21 analytics tables in MinIO; mutation checks recorded |
| Blind review + comparison of attempt 2 | 2026-10-11, 6 min | OpenAI-backed reviewer | high | verdict | PASS; "attempt 2 is the better evaluation result"; "stop iterating" |
| Skill distillation | 2026-10-12, 4 min | Anthropic-backed model | medium | `.agents/skills/solving-analytics-take-homes` on `main` | commit `7f3db7f` |

A note on attribution, because it matters for a fair reading. Amp routes a "mode" (low, medium, high) to a model, and the thread metadata records the provider and the mode, not the model name. The model names above are what the operator set the routing to at the time; the threads themselves only prove "OpenAI provider, medium mode" and "Anthropic provider, medium mode". Token and dollar costs were not recorded in any of these threads, so this article has no cost comparison. Solver runs used medium mode; every reviewer ran in high mode. Those are different budgets and the reviewers' findings should be read with that in mind.

## Are take-home tests still relevant?

The strongest argument against take-homes in 2026 is simple: if an agent can produce a passing solution blind in 24 minutes, a take-home no longer proves that the candidate can write the SQL. That is true, and it is worth saying plainly rather than pretending otherwise.

But "can write the SQL" was never the interesting signal. What the three runs show is that the SQL was the cheap part every time. The expensive part was the sequence of small judgments that nobody wrote down in the brief:

- Does a null `customer_group_id` mean "individual customer", or just "no group recorded"? The first AI solution assumed the former. The human asked for evidence ("an assumption with no evidence, if not show it to me"), there was none, and the final label became `no group recorded`, distinct from `unknown group` for the seven customers whose group id pointed at a group that does not exist in the extract.
- Does a trip with zero orders belong in the model? It is supply with no demand; drop it and utilization becomes a lie. All three AI runs preserved the 12 zero-order trips, but only because the brief and later prompts said to.
- Is "low cost vs premium" answerable from this data? The brief asked about it. There is no fare class column; price conflates distance and tier; aircraft size is an imperfect proxy. The first solution invented price bands to answer it. The human removed them and wrote the question down as unsupported instead.
- When the window for "weekly active users" is a calendar week, is it Monday-start or Sunday-start? Rolling or calendar? Attempt 1 chose rolling 7/30-day windows with a 28-day date spine and completeness flags; the reference chose calendar day, Monday-start week, and month. Both are defensible. Neither is right unless it is written down.

None of these is a coding skill. They are the skill of noticing that a decision is being made, finding out whether the data or the brief supports it, and refusing to invent a classification when they do not. That skill is what an analytics engineer is paid for, and a take-home remains one of the few places where an employer can watch a candidate exercise it on an unfamiliar dataset.

So the honest reframe is this. A take-home no longer proves the candidate can build a star schema. It can still prove whether the candidate can tell when a star schema is wrong, and whether they will say so. Employers who want that signal should redesign the exercise around it:

- **Grade the assumptions log, not the model count.** The reference solution ended with 16 models; the best blind run ended with 20; the leanest passing run had 11. The reviewers never scored on count. They scored on whether each model served a question in the brief and whether each rule traced to a profiled fact.
- **Plant something unsupported in the brief.** "Low cost vs premium" was the trap in this exercise, whether the authors meant it or not. The right answer was "not supported by the data; here is what would be needed", and a candidate who invents bands to answer it has told you something important.
- **Ask for semantics in writing.** What counts as an active user, which timestamp attributes an event to a period, how cancelled orders affect revenue, and whether a ratio with a zero denominator is 0 or null. An agent will happily pick one silently; a candidate who writes them down is doing the job.
- **Assume AI was used, and ask for the verification evidence.** Test counts that went red on purpose, reconciliations recomputed from the raw source rather than from the model, and a storage check after a restart. These are hard to fake and easy to grade.
- **Respect the timebox.** If the exercise claims 2–4 hours, do not also require the candidate to assemble a Spark cluster. More on this below.

What a take-home can no longer tell you is whether the candidate typed the code. Decide whether you care, and if you do, use a live session instead.

## The stack: a Databricks-shaped lakehouse that runs on a laptop

Every run in this article executed on the same public template. We built it because the take-home brief, like most, asked for Databricks-style answers (Delta tables, a three-level catalog, dbt, a CI/CD story) while offering no environment to produce them in.

```text
┌──────────────────────┐   Thrift JDBC :10000   ┌──────────────────────────┐
│ dbt-spark / Beeline  │───────────────────────▶│ Spark 4.1 Thrift Server  │
│ (just run/test/query)│                        │ Delta 4.3 + S3A          │
└──────────────────────┘                        └─────┬──────────────┬─────┘
                                                      │              │
                                 1. resolve table,    │              │ 2. read/write Parquet
                                    get location +    │              │    + _delta_log
                                    vended credentials│              │
                                                      ▼              ▼
                                        ┌──────────────────┐  ┌──────────────────────────┐
                                        │ Unity Catalog OSS│  │ MinIO                    │
                                        │ 0.5.0 (metadata, │  │ s3://delta-warehouse     │
                                        │ uc-db volume)    │  │ (minio-data volume)      │
                                        └──────────────────┘  └──────────────────────────┘
```

The split is the one Databricks uses: **Unity Catalog owns metadata, object storage owns data, Spark has no storage keys of its own.** For every table, the Unity Catalog Spark connector asks UC for the table's location and credentials, then reads and writes Parquet files and the `_delta_log` through S3A against MinIO. `uc-init` creates the `prod` catalog with storage root `s3://delta-warehouse/prod` and the `raw`, `analytics`, and `default` schemas under it, so every table created by `just load-raw`, `dbt seed`, or `dbt run` is a UC-managed table whose files land in the bucket.

Two honest deviations from Databricks. UC OSS 0.5.0 cannot call MinIO's STS, so the vended credentials are the static MinIO root keys rather than short-lived, table-scoped tokens; the data path is the same, the credential lifetime is not. And UC OSS rejects `CREATE VIEW` (`MISSING_CATALOG_ABILITY.VIEWS`), so every dbt model, including staging, materializes as a Delta table. The first AI run discovered that the hard way: its staging and intermediate models were configured as views and failed on the stack until they were switched to tables.

The developer surface is deliberately boring:

| Layer | Choice | Why |
| --- | --- | --- |
| Orchestration | Docker Compose, `just infra-up` | One startup command; `--wait` on healthchecks in dependency order (MinIO → bucket → UC → UC bootstrap → Spark) |
| Raw landing | `just load-raw` (Beeline, not dbt) | Simulates a data-engineering team landing CSVs in `prod.raw`; keeps dbt for transformations only |
| Transformations | dbt-spark, `file_format='delta'`, `incremental_strategy='merge'` | Carries over unchanged to `dbt-databricks` in production |
| Python | UV | Lockfile, one `uv sync` |
| SQL style | SQLFluff (sparksql dialect, dbt templater) | Uppercase keywords, lowercase identifiers, 120 columns; `just ci` runs parse + lint without Docker |
| Proof | `just storage-check`, `just verify` | Every `prod.raw` and `prod.analytics` table must have `_delta_log` and Parquet files in `s3://delta-warehouse/...`; `verify` runs the full load → seed → run → test → storage-check → restart → re-test loop and deletes the volumes on exit |
| Agent guidance | `AGENTS.md` + project skill `solving-analytics-take-homes` | The workflow distilled from this exercise, loadable by any agent working in the repo |

The template ships no sample data and never generates any. `just verify` fails at `load-raw` if `data/` is empty, and that is intended: the candidate's data is the candidate's data.

## Why we published it

Most take-home briefs we have seen say "this should take 2–4 hours". The budget rarely includes the part where the candidate finds a Spark image that works with Delta, discovers that the Spark 4 Thrift Server does not see `--packages` jars, pins a `hadoop-aws` version that matches the image's Hadoop client, and works out why Unity Catalog will not create a view. On this template, that cost was paid once: the Spark Dockerfile bakes the pinned Delta, Unity Catalog connector, and `hadoop-aws` 3.4.2 jars into `$SPARK_HOME/jars` precisely because of the classloader issue, and the README explains the view limitation so nobody rediscovers it.

Unpaid environment work is the part of a take-home that is disrespectful of candidate time, because it measures nothing the employer cares about and it is where the "4 hours" quietly becomes a weekend. With the environment solved and an agent doing the first pass, the timebox becomes plausible again, and the candidate's hours go where they should:

1. Reading the brief and listing what the reviewer will actually grade.
2. Profiling the data until it has no surprises (this exercise had seven orphan group references, six null groups, two trips whose local end time precedes the start, five "Booked" orders on trips that also had "Finished" ones, and 12 trips with no orders).
3. Inspecting the tables the agent produced and checking the semantics against their own criteria.
4. Overriding the agent where it invented something, and documenting the override.

That last step is the whole job. The refinement thread in this exercise is 600 messages long not because the model was slow but because a human kept asking why there were two aggregate tables and not one, whether a column was referenced anywhere, which attribute answered low cost versus premium, and finally to remove the arbitrary segmentation from aircraft. Each of those questions removed something. The solution got smaller and better.

## Can AI one-shot it? Three runs, three answers

### Run 1: fast, plausible, over-built

The original solve ran on 2026-08-30 in Amp's medium mode against an OpenAI-backed model. The initial solution, static checks only, was pushed seven minutes after the brief arrived. It could not run on the stack at first because Docker Compose was unavailable in that sandbox; two hours later, after the template gained a Docker-free runtime, the run completed end to end with `PASS=20` models and `PASS=79 WARN=1 ERROR=0 TOTAL=80` tests. The one warning was the seven customers whose group reference pointed nowhere, kept visible rather than repaired, which was the right call.

What the tests could not catch:

- An analyst-maintained `city_geography` seed (29 cities) mapping to countries and regions, with no citation.
- Seat-capacity and price bands with arbitrary thresholds.
- `individual` as the label for a null group id.
- Two intermediate models (`int_*__orders_enriched`, `int_*__trip_order_metrics`) and two snowflaked dimensions (`dim_customer_groups`, `dim_aeroplane_models`) that pushed joins and rollups into the facts.
- Five `mart_*` tables whose grains were not stated.

Also worth recording: the template at that time had no MinIO. Tables were stored on the local filesystem. So this run has no storage proof comparable to the later ones, which is one reason cross-run comparisons in this article are indicative rather than controlled.

### The human refinement: deletion as the main activity

Between 2026-10-10 and 2026-10-11 a human worked through the first solution in a low-mode thread. The final branch, commit `17e4134`, has 16 models: six staging, three dimensions (`dim_geographies`, `dim_customers`, `dim_aeroplanes`), two thin facts (`fct_orders` at one row per seat order, `fct_trips` at one row per scheduled trip including the 12 with zero orders), and five `agg_*` reporting tables with explicit grains (period, service date × region pair, directional city pair, group type × group name, manufacturer × model). The customer-group and aircraft-model snowflakes were flattened into their parents, the intermediate layer was deleted, every invented band was removed, and the documentation was rewritten so it no longer referenced models that did not exist.

Semantics were written down for the first time: active user = customer with a `booked` or `finished` order for a trip starting in the period; realized revenue = finished-order listed value (a proxy, not accounting revenue); booked GMV = booked-order listed value; cancelled orders count for neither. The reconciliation query that closed the thread reads `realized,booked,total,check_sum = 18900.00,9900.00,28800.00,28800.00`.

What the refinement thread does *not* contain is a final `just storage-check` or restart proof after the last refactor. The final recorded checks are `just ci` clean, `just run` 16/16, and `just test` PASS=73 WARN=1. The comparison reviewer later flagged this: the reference had the better architecture and the weaker final runtime evidence.

### Blind attempt 1: lean and credible

On 2026-10-11 at 20:24 a fresh thread in medium mode (Anthropic provider) received the brief and these constraints, paraphrased from the prompt: solve from `origin/main` only; do not inspect any `take-home/*` branch or prior thread; profile everything first; build a minimal DAG with one clear grain per model; preserve zero-demand trips; do not invent segments, tiers, distance bands, or lifecycle semantics; define active users, revenue proxies, and time attribution explicitly; keep bad references rather than fixing them; run the clean Docker/MinIO/Unity Catalog verification; commit and push.

Twenty-four minutes and 104 messages later it pushed 11 models: six staging, `dim_aircraft`, `dim_customer` (with group attributes denormalized onto it), `fct_order`, `fct_trip`, and `metrics_active_customers_daily` with rolling DAU/WAU/MAU on a 28-day spine. It deliberately did not build a group dimension, a geography layer, route or aircraft marts, or any derived short/long or premium measure, and said why in the docs. It ran a clean `just verify`: 11/11 models, `PASS=61 WARN=3 ERROR=0 TOTAL=64` before and after restart, six raw and 11 analytics tables with Delta logs in MinIO, raw row counts unchanged after restart.

One procedural wrinkle. The brief said not to touch `take-home/*`, but the source files existed only on that branch. The agent noticed the conflict, read the coordinating thread to locate the files, and fetched exactly the six data files from `take-home/air-service` through the GitHub Contents API. It did not list or read anything else from that branch. For attempt 2 the prompt was fixed to authorize those six paths explicitly. This is the kind of ambiguity a real candidate would email about; an agent resolves it and moves on, and the operator has to check afterwards whether it resolved it acceptably.

The high-mode blind reviewer, with no access to the reference, returned **PASS, no blocking defects, another medium attempt not warranted**. Its most important finding was about test design: three anomaly tests warned at the known count (five stale Booked orders, two end-before-start trips, seven unresolved groups) and failed only above it, while the documentation claimed "any new occurrence fails the build". If one known defect disappeared and a new one appeared, the count would not move. The fix is to test by identity, not by threshold. It also found that the active-customer invariant test (`DAU <= WAU <= MAU`) would pass on all zeros, and that some revenue reconciliations reused upstream calculated fields rather than recomputing from source.

The reference comparison, also high mode, listed where each side was better. Attempt 1 won on direct JSON ingestion with Delta column mapping, demonstrated clean restart and storage verification, anomaly visibility, rolling-window completeness flags, the CI/CD write-up, revenue-proxy naming (`gross_booking_value_eur`, `realized_revenue_proxy_eur`), and PII minimization. The reference won on thin facts with separate reporting aggregates, regional reporting, more tests with raw-source coverage, an independent per-order value assertion, uppercased seat numbers for uniqueness, and the wording `no group recorded` versus attempt 1's `no_group`, which infers more than a null proves. Verdict: PASS, no further attempt materially necessary, and five prompt lessons if one were run anyway.

### Blind attempt 2: the prompt lessons, applied

We ran it anyway, because the lessons were cheap to encode. The attempt 2 prompt kept everything from attempt 1 and added: thin atomic facts with descriptors in dimensions (flat star); separate consumer-ready reporting marts with explicit grains for service day, route, aircraft model, customer, customer group, and DAU/WAU/MAU; route and aircraft reporting kept separate to avoid mixed-grain rollups; an identity-aware known-defect register with tests that detect both new and resolved defects; reconciliations recomputed from raw source status and value, not from derived fields; exact boundary tests for rolling and calendar windows; and explicit authorization to read the six data files from the reference branch.

Thirty-eight minutes and 144 messages later: 20 models (six staging, `dim_date`, `dim_customer_group`, `dim_customer`, `dim_aircraft`, `dim_route`, `fct_trip`, `fct_order`, and seven `agg_*` tables), a `known_source_defects.csv` seed, six singular tests, three dbt unit tests for window boundaries, and 99 tests passing before and after restart. The thread records mutation checks: it altered the WAU/MAU window bounds, treated booked as realized, and removed a row from the defect register, confirmed the corresponding tests went red, and restored them. One real runtime failure along the way: two reporting models failed on a Spark/Delta scalar `MIN(date)` issue and were rewritten with a window `MIN(...) OVER ()`.

The reviewer recorded a blind PASS before opening the other branches, then compared:

| Criterion | Attempt 1 | Reference (human-refined) | Attempt 2 |
| --- | --- | --- | --- |
| Models / tests / model SQL lines | 11 / 64 / 181 | 16 / 74 / 384 | 20 / 99 / 617 |
| Fact thinness | order fact carries trip descriptors; trip fact carries order rollups | thin | thin, conformed keys |
| Reporting marts | 1 | 5 | 7 |
| Known-defect tests | count thresholds | 1 warning, no register | identity register, symmetric detection |
| Reconciliations | partly circular | per-order value assertion | raw status/value, trip, membership, activity |
| Activity windows | rolling | calendar | rolling and calendar, boundary unit tests |
| Regional analysis | not supported, stated | 29-city geography seed, uncited | not supported, stated |
| Final runtime proof | clean verify + restart | run/test only after last refactor | clean verify + restart |

Verdict: "attempt 2 is the better evaluation result"; recommendation: "stop iterating on new solve attempts" and make targeted corrections. The corrections are the interesting part, because they are exactly the kind of thing a candidate reviewing an agent's output should catch:

- **Empty utilization regressed to `NULL`.** A route or day with no orders should show 0 utilization when the denominator exists; attempt 2 surfaces null. The reference zero-filled. This is a semantic regression that 99 passing tests did not notice because no test asserted the rule.
- **The docs claimed something false about dbt.** They stated that a failed data test in `dbt build` preserves the prior table. It does not: models materialize before data tests run, and `just load-raw` drops and recreates raw tables. The template's limitation is now documented in the skill so the next solution does not repeat the claim.
- **"Local time" was asserted, not assumed.** The source timestamps carry no timezone. Treating them as local wall-clock is plausible (it explains the two trips that end before they start, both crossing the date line) but it belongs in the assumptions list.
- **Reconciliations checked grand totals, not attribution.** €18,900 realized across the whole dataset can be right while the per-route split is wrong. Reconcile every slice the brief reports on.

### So, can it one-shot?

Measured: two blind runs, two PASS verdicts from a high-mode reviewer that had no reference, zero blocking defects, 24 and 38 minutes of wall-clock time. On that evidence, yes.

Opinion, and the part we think generalizes: the pass had almost nothing to do with the model and almost everything to do with five things the operator controlled.

1. **Prompt quality.** Attempt 1 and attempt 2 ran in the same mode on the same provider on the same day. The difference between "credible lean solution with threshold tests" and "flat star with identity-tested defects and boundary unit tests" was a paragraph of requirements copied from a reviewer's findings.
2. **Environment.** The original run could not execute at all for its first two hours; the blind runs had a one-command stack with a storage check and a restart loop built in. "Verified on the stack" is only a claim when the stack exists.
3. **Source access.** Attempt 1 had to improvise around a prompt that forbade the only place the data lived. Attempt 2 was told where the data was. Ambiguity costs time and, worse, produces behaviour the operator then has to audit.
4. **Verification discipline.** The runs that recorded `just verify` output, storage checks after restart, and mutation checks were the runs the reviewers trusted. The reference, with the best architecture, lost ground because its final state lacked that evidence.
5. **Evaluation criteria.** Both reviewers graded against written criteria (grain, additivity, evidence behind each rule, independence of reconciliations, red-ability of tests). Without them "PASS" would have meant "looks fine".

Change any one of those and the one-shot stops being one-shot. That is also why the result of this exercise is a skill file rather than a model recommendation.

## Lessons that made it into the project skill

After the second review, the findings from all three runs were distilled into a project skill, `solving-analytics-take-homes`, committed to `main` as `7f3db7f`. It is an eight-step workflow with four reference documents (profiling, modeling, testing, deliverables). Each rule below exists because a run in this article got it wrong, or got it right only after being told.

| Lesson | Evidence | What the skill says |
| --- | --- | --- |
| Profile until the data has no surprises | Every run found the same seven orphan groups, six null groups, 12 zero-order trips, two date-line trips, five Booked-on-Finished-trip orders; the runs differed in what they did about them | Every column used downstream has a query-backed fact behind it; end with a "can / cannot support" list |
| Thin facts, dimensions own descriptors, explicit reporting layer | Run 1 pushed rollups into facts via intermediates; attempt 1 carried trip descriptors on `fct_order`; the reference and attempt 2 kept facts thin | Facts are keys, timestamps, degenerate ids, additive measures, status; reporting aggregates are built from facts and dims, never back into them, with grain and additivity stated per measure |
| No invented classifications | Price bands, seat bands, `individual`, an uncited geography seed | Use only classifications the brief or the source defines; otherwise list the question as unsupported or make it a named, labelled `var` |
| Preserve zero demand | 12 of 20 trips had no orders; utilization is meaningless without them | Spine × activity with `COALESCE` to 0; null only for a genuinely undefined ratio, and the YAML says so |
| Write the semantics down | Active user, revenue proxy, time attribution, rolling vs calendar were all chosen silently in run 1 and differently across runs | Activity, status, time attribution, windows (with inclusive/exclusive bounds and a deterministic as-of date), and revenue proxies are written in the deliverable and sourced |
| Reconcile independently, per slice | Attempt 1's revenue check reused `fct_order` to validate `fct_trip`; attempt 2 reconciled totals but not route/date/group attribution | Recompute from `source('raw', ...)` with separate SQL; reconcile every slice the brief reports on; return offending rows |
| Test the window edges | Attempt 1's only window test was `DAU <= WAU <= MAU` | Events on the as-of date, exactly N days before, one day either side; month start and end; repeat entities; cancellation-only entities |
| Known defects by identity | Count thresholds pass when one defect is swapped for another | Seed the known keys; test that the flagged set equals the seed |
| Prove storage, then restart | The run with the best model had the weakest final storage evidence | `just storage-check` before and after `just down && just infra-up`; `just verify` last because it deletes the volumes |
| Blind review, then reference comparison | Every reviewer recorded a verdict before seeing the reference; the comparison then surfaced where each side was better | Review with the same references as a rubric; report findings with file, line, and the source fact that contradicts the claim |
| Be honest about what dbt does on failure | Attempt 2's docs claimed failed tests preserve prior tables | `dbt run` replaces tables before `dbt test`; say so, and describe write-audit-publish as the ideal rather than the implemented behaviour |

The last row is worth dwelling on because it is where agents and candidates fail the same way: by writing the CI/CD answer they think the reviewer wants rather than the one the repository implements. The skill asks for both, labelled "ideal" and "constrained", and asks which one the repo actually does.

## Methodology, limitations, reproducibility

**What was held constant.** One brief, privacy-substituted. Six source files, byte-identical across all runs (attempt 2 records their SHA-256 sums in its docs). One repository. Solver runs in medium mode; reviewer runs in high mode. Reviewers were instructed to record a blind verdict before reading any other branch, and the threads show they did.

**What was not controlled, and why the comparison is indicative, not a benchmark.**

- The original solve ran six weeks earlier on a different template state (no MinIO, Docker initially unavailable). Its lack of storage proof is an artefact of the environment, not of the model.
- Different providers for the solve runs (OpenAI in August, Anthropic in October), and model names are the operator's routing records rather than something the threads prove.
- Reviewers ran in high mode; solvers in medium. The reviewers were, by construction, spending more than the solvers.
- One dataset, and a tiny one: 20 orders. Several lessons (zero-demand preservation, identity-based defect tests) matter more at this scale than they would on a million rows, and others (incremental strategy, partitioning) never came up.
- Attempt 2's prompt was written after reading attempt 1's review. That is the point of the experiment, but it means attempt 2 is not a second independent sample of "can the model one-shot it"; it is a sample of "can the operator write a prompt that one-shots it".
- The same operator ran the refinement, wrote the eval prompts, and chose the reviewers. There was no independent grader.
- No costs recorded.
- Both blind runs read the six data files from the reference branch (attempt 1 without explicit permission, attempt 2 with). Neither read anything else there, as far as the thread logs show, but "as far as the logs show" is the strength of that claim.

**Reproducing it.** Clone the repository, `just setup`, copy `.env.example` to `.env`, `just infra-up`. Put your own CSVs in `data/` and run `just load-raw`, then `just run`, `just test`, `just storage-check`. The three solution branches ([`take-home/air-service`](https://github.com/KikeSenpai/delta-analytics-engineering-template/tree/take-home/air-service), [`eval/air-service-attempt-1-medium`](https://github.com/KikeSenpai/delta-analytics-engineering-template/tree/eval/air-service-attempt-1-medium), [`eval/air-service-attempt-2-medium`](https://github.com/KikeSenpai/delta-analytics-engineering-template/tree/eval/air-service-attempt-2-medium)) are public and each includes its own docs with the exact verification output. The project skill lives at [`.agents/skills/solving-analytics-take-homes/`](https://github.com/KikeSenpai/delta-analytics-engineering-template/tree/main/.agents/skills/solving-analytics-take-homes) and any agent that supports project skills can load it; a human can read it as a checklist.

## What this leaves open

The experiment answered the question we asked: with a solved environment, a specific prompt, and a review loop, an agent can produce a take-home solution that a strict reviewer passes blind. It did not answer the question employers are actually asking, which is whether a candidate who submits such a solution understands it.

Our guess, and it is a guess, is that the interview after the take-home is now where the signal lives. Ask the candidate why `fct_trip` keeps zero-order trips. Ask what `no group recorded` means and how it differs from `unknown group`. Ask them to make one test go red. Ask which question in the brief their model cannot answer, and what data would fix that. An agent produced all four answers in this exercise; the candidate's job was to know they were the right ones.

If you run a take-home and want to try this, the template is public and the skill is in it. If you are a candidate and the brief says "4 hours" with no environment, you now have one.

<!--
Editor notes (not rendered)

Image suggestions
1. Hero (16:9): the four-box architecture (dbt → Spark → Unity Catalog / MinIO) rendered as a clean diagram with the UC/MinIO split highlighted. Purpose: set the "Databricks-shaped, local" frame before the reader scrolls.
2. After "Three runs, three answers": a horizontal timeline from 2026-08-30 to 2026-10-12 with the eight threads as dots, grouped into solve / refine / eval / review / skill. Purpose: make the chronology scannable.
3. Beside the attempt comparison table: a small bar chart of models / tests / SQL lines for the three branches (11/64/181, 16/74/384, 20/99/617). Purpose: show that the best-reviewed run was neither the smallest nor the largest.

Title alternatives
- "What a take-home test measures now that AI can write the dbt models"
- "AI wrote the star schema; a human had to delete the invented segments"
- "Take-home tests in the AI era: 20 models, 99 tests, and the questions a human still has to ask"
-->
