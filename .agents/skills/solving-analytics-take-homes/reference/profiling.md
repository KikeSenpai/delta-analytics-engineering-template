# Profiling

Profile with `just query "..."`. The recipe wraps SQL in double quotes, so use single-quoted string literals and avoid backticks (the shell runs them as command substitution). For long sessions, `docker exec -it infra-spark-1 beeline -u jdbc:hive2://localhost:10000` is faster.

Write each finding as a fact with the query that produced it. A finding without a query is a guess.

## Per table

| Question | Typical query |
|----------|---------------|
| Row count vs file lines | `SELECT COUNT(*) FROM prod.raw.t` vs `wc -l data/t.csv` |
| Declared vs inferred types | `DESCRIBE TABLE prod.raw.t`, compared with raw file samples (`head data/t.csv`) |
| Grain and candidate keys | `SELECT COUNT(*), COUNT(DISTINCT k1), COUNT(DISTINCT k1, k2) FROM t` |
| Exact duplicates vs key duplicates | `GROUP BY` all columns vs `GROUP BY` key, `HAVING COUNT(*) > 1`; inspect the rows |
| Nulls and blanks per column | `SUM(CASE WHEN c IS NULL OR TRIM(c) = '' THEN 1 ELSE 0 END)` |
| Domains of categorical / status columns | `SELECT c, COUNT(*) FROM t GROUP BY c ORDER BY 2 DESC` (watch case, whitespace, synonyms) |
| Timestamps | min, max, unparseable count, formats present, time-of-day distribution, future dates, events before their parent's creation |
| Numerics and units | min, max, negatives, zeros, decimals, outliers; does the column name or metadata state a unit or currency? |
| Free text and PII | which columns are identifying; exclude them from models unless the brief needs them |

## Per relationship

For each foreign key: parent cardinality (1:1, 1:N, N:M), child rows with null key, child rows whose key has no parent. Split the non-matches:

- **Known absence:** the key is null or a documented sentinel; the event legitimately has no parent (walk-in, unassigned). Model it as an explicit "unknown / not applicable" member or a nullable FK, and count it.
- **Invalid reference:** the key is present but resolves nowhere. That is a data defect: keep the row, flag it, list the offending keys, and report the count. Silent inner joins drop it.

Check also: children whose dates fall outside the parent's validity, and parents with zero children (supply with no activity).

## Lifecycle and time

- List every status value and what it means for counting (does a cancelled record count as demand? as revenue?). If the brief does not say, choose, state the choice as an assumption, and show the alternative's impact in numbers.
- Identify which timestamp attributes an event to a period (created, scheduled, completed). Different choices change period totals; pick per KPI and write it down.
- Timezone and units: when source metadata does not establish them, label them as assumptions (for example, "times treated as local to the operating site; no offset in source").

## Anomalies

Record each anomaly with its identity (the keys), not just a count: duplicates, orphans, negative quantities, impossible sequences, out-of-range dates. Identities feed the known-defect seed used by tests (see [testing.md](testing.md)).

## Output: can / cannot support

End profiling with two lists:

- **Supported:** questions the data answers, with the columns that answer them.
- **Not supported:** questions it cannot answer and the extra data that would be needed. A classification, segment, or threshold that no source column or brief sentence defines goes here (or becomes a labelled, parameterised assumption), rather than being invented.
