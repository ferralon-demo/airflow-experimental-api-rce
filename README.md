# Apache Airflow — unauthenticated experimental-API DAG-source read (CVE-2020-13927) — `fix`

> ## ⚠️ DEMONSTRATION / CASE-STUDY BRANCH
> Byte-for-byte snapshot of **real** Apache Airflow source at a specific
> historical commit, for security-analysis demonstration only. **NOT for any
> real or production use.** Do not deploy, install, or depend on it.

## What this branch represents

The **fixed** state: Apache Airflow at commit `8807f73dfd`, the commit that
deleted the Experimental REST API wholesale (upstream PR
[#41434, "Delete experimental API"](https://github.com/apache/airflow/pull/41434),
shipped in **Airflow 3.0.0**).

| | |
|---|---|
| Upstream commit | `8807f73dfd22eed5e81932b0e9abe7a8fbad57bc` ("Delete experimental API (#41434)") |
| Date | 2024-08-16 |
| Snapshot tree OID | `c61ddd9a4d63b23b50effda22fde02180a370ed5` |
| Expected static verdict | **not_exploitable** (PoNE — sink symbol/path absent) |

## What changed vs `baseline`

This is a single real upstream commit deleting the entire experimental API
surface — not a guard-add, not a dependency bump:

- **Route package deleted.** `airflow/www/api/experimental/` — including
  `endpoints.py` (the Flask blueprint and all 18 decorated route handlers,
  `get_dag_code` among them) — is removed entirely.
- **Sink package deleted.** `airflow/api/common/experimental/` — including
  `get_code.py`, which held the reachable sink `get_code(dag_id)` — is removed
  entirely.
- **Registration removed.** `init_api_experimental()` in
  `airflow/www/extensions/init_views.py`, which called
  `app.register_blueprint(endpoints.api_experimental,
  url_prefix="/api/experimental")`, is deleted.

At `8807f73dfd`, `airflow.api.common.experimental.get_code.get_code` no longer
resolves anywhere in the tree, and there is no `http_route` decorator
registering the `/api/experimental/dags/<dag_id>/code` path.

`ResolveDependencySymbols(["airflow.api.common.experimental.get_code.get_code"])`
→ **0 matches** here ⇒ **not_exploitable**. Both the ingress and the sink
named by the advisory are gone — a **doubly** closed reachable path.

## Honesty note (structural signal, stated plainly)

Unlike cases where a fix renames or wraps the reachable symbol, this flip is a
**clean wholesale deletion**: the handler function, its containing module, the
sink function, its containing module, and the blueprint registration call are
all removed from the tree. There is no successor function carrying the same
behavior behind a new name — the entire experimental surface, including its
years-long deprecation warnings, is gone. This is the most unambiguous shape of
static flip: symbol-removal and path-removal both hold, with no guarded
refactor to caveat.

## Provenance & license

Not a fork — a real source snapshot; no upstream remote or git parents.
Upstream: <https://github.com/apache/airflow> @
`8807f73dfd22eed5e81932b0e9abe7a8fbad57bc`. Upstream `LICENSE` (Apache-2.0)
retained verbatim. `README.md` is the only authored file on this branch; all
other files are the upstream tree, unmodified.

The real `baseline → fix` diff is the open PR
[`baseline` ← `fix` (#1)](https://github.com/ferralon-demo/airflow-experimental-api-rce/pull/1).
Full index: [`main`](https://github.com/ferralon-demo/airflow-experimental-api-rce/tree/main).
