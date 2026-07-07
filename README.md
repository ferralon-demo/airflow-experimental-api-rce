# Apache Airflow — unauthenticated experimental-API DAG-source read (CVE-2020-13927)

Case study of a missing-authentication vulnerability (CWE-306) in Apache
Airflow's Experimental REST API: a Flask blueprint route with no access
control beyond "any authenticated user" exposed arbitrary DAG source code
(and DAG triggering) to any caller. Reconstructed from real upstream source at
two historical commits to demonstrate reachability-based static analysis.

> ## ⚠️ DEMONSTRATION / CASE-STUDY REPOSITORY
> This repository reconstructs **real open-source code at specific historical
> commits** to demonstrate security analysis. It is **NOT for any real or
> production use**. Do **not** deploy, install, or depend on it. The code here
> is a byte-for-byte snapshot of Apache Airflow at the mapped commits.

## Synopsis

| | |
|---|---|
| **Advisory** | [CVE-2020-13927](https://nvd.nist.gov/vuln/detail/CVE-2020-13927) — default allow-all authentication on Airflow's Experimental REST API |
| **Weakness** | CWE-306 (missing authentication for a critical function) |
| **Affected surface** | `airflow/www/api/experimental/` — removed wholesale in **Airflow 3.0.0** |
| **Sink** | `get_code(dag_id)` in `airflow/api/common/experimental/get_code.py` — reads and returns arbitrary DAG source off disk by `fileloc` |
| **Ingress** | `@api_experimental.route("/dags/<string:dag_id>/code", methods=["GET"])` on handler `get_dag_code`, `airflow/www/api/experimental/endpoints.py` |
| **Archetype** | **A** — reachable first-party sink; the fix **deletes** both the route and the sink module |

### Why SCA misses this
A software-composition scanner sees only "the app depends on `apache-airflow`
— no version bump is even required here, since the vulnerable surface was
opt-in and shipped unchanged across the entire 2.x line." It cannot say
**which route** and **which symbol** carried the unauthenticated read, nor
confirm that a given release no longer exposes it. Reachability analysis keys
on the specific sink — `get_code` — reached from the decorated Flask route,
and observes that both are **absent** in the fixed tree.

### Deprecation ≠ removal
Airflow flagged this surface as deprecated years before removing it: since
2021-12 (`6239ae91a4`, "Deprecate some functions in the experimental API"),
`get_code` carried an `@deprecated(version="2.2.4",
category=RemovedInAirflow3Warning)` decorator, and `init_api_experimental()`
emitted a runtime `warnings.warn(...)` stating plainly that "the experimental
API do not have access control. The authenticated user has full access." Both
mitigations are **already present** at this case's `baseline` (2024-08-16) —
years after the deprecation — and neither closes the reachable path: the
decorator only logs a warning, the route is still registered, the sink still
resolves. Only the **wholesale deletion** in `fix` flips the static verdict.
This case ships no separate `failed-fix` branch because the deprecation
predates `baseline` by years rather than sitting between `baseline` and `fix`
as a distinct historical stage; it is documented here instead.

## Provenance

Upstream project: **Apache Airflow** — <https://github.com/apache/airflow>.
This is **not a fork**: a fresh repository with real source **snapshots** at
the commits below. No upstream remote, no upstream git parents. The upstream
`LICENSE` (Apache-2.0) is retained verbatim on every code branch.

| Stage | Branch | Upstream commit | Date | Snapshot tree OID |
|---|---|---|---|---|
| baseline (last-vulnerable, doubles as PoE) | `baseline` | [`e35ae2db7c`](https://github.com/apache/airflow/commit/e35ae2db7c56a23b2f7abbd7c4269221ed98ead6) | 2024-08-16 | `ba25dae90e003040ec1220f566a2773e151c4746` |
| fix | `fix` | [`8807f73dfd`](https://github.com/apache/airflow/commit/8807f73dfd22eed5e81932b0e9abe7a8fbad57bc) | 2024-08-16 | `c61ddd9a4d63b23b50effda22fde02180a370ed5` |

Upstream PR closing the reachable path:
[apache/airflow#41434 — "Delete experimental API"](https://github.com/apache/airflow/pull/41434),
merged 2024-08-16, shipped in **Airflow 3.0.0**.

There is **no failed-fix stage**: the fix is a single, clean wholesale
deletion. There is also no separate `vulnerability-introduced` stage — the
reachable sink predates the earliest practical baseline (it has existed since
2016, `AIRFLOW-3865`), so `baseline` already carries it and doubles as the PoE
branch.

## Branch map

| Branch | State | Expected static verdict |
|---|---|---|
| [`baseline`](https://github.com/ferralon-demo/airflow-experimental-api-rce/tree/baseline) | Airflow @ `e35ae2db7c` — `get_dag_code` route + `get_code` sink present (deprecated, not removed) | **reachable_candidate** (PoE) |
| [`fix`](https://github.com/ferralon-demo/airflow-experimental-api-rce/tree/fix) | Airflow @ `8807f73dfd` — entire experimental API package deleted (route + sink both gone) | **not_exploitable** (PoNE — sink symbol/path absent) |

## Pinned tags

Annotated git tags pin the significant stage commits above so the vulnerable-through-fixed
narrative has stable references even as branches move.

| Tag | Commit | Pins |
|---|---|---|
| [`poe`](https://github.com/ferralon-demo/airflow-experimental-api-rce/tree/poe) | `565d7442` | `baseline` (vulnerable, reachable_candidate) |
| [`pone`](https://github.com/ferralon-demo/airflow-experimental-api-rce/tree/pone) | `8b34e414` | `fix` (not_exploitable) |

## PR map

The transition PR carries the reviewable diff. It is left **open** (never
merged; `main` stays README-only).

| PR | base ← head | Shows |
|---|---|---|
| [#1](https://github.com/ferralon-demo/airflow-experimental-api-rce/pull/1) | `baseline` ← `fix` | the real Airflow `e35ae2db7c → 8807f73dfd` fix diff (route + sink wholesale deletion) |

## License

Each code branch retains the upstream Apache Airflow `LICENSE` (Apache-2.0)
verbatim. The only file authored for this case study is `README.md` (this
index, specialized per branch).
