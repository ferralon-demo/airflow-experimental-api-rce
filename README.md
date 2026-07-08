# Apache Airflow — unauthenticated experimental-API DAG-source read (CVE-2020-13927) — `baseline`

> ## ⚠️ DEMONSTRATION / CASE-STUDY BRANCH
> Byte-for-byte snapshot of **real** Apache Airflow source at a specific
> historical commit, for security-analysis demonstration only. **NOT for any
> real or production use.** Do not deploy, install, or depend on it.

## What this branch represents

The **last-vulnerable** state: Apache Airflow at commit `e35ae2db7c`, the
direct parent of the commit that deleted the Experimental REST API. The
reachable unauthenticated-read sink predates this commit by years, so
`baseline` already carries it and **doubles as the Proof-of-Exploitability
(PoE)** state — there is no separate `vulnerability-introduced` branch for
this case.

| | |
|---|---|
| Upstream commit | `e35ae2db7c56a23b2f7abbd7c4269221ed98ead6` ("Airflow 3: airflow date utils date_range and days_ago deprecations removal (#41496)") |
| Date | 2024-08-16 |
| Snapshot tree OID | `ba25dae90e003040ec1220f566a2773e151c4746` |
| Expected static verdict | **reachable_candidate** (PoE) |

## The reachable sink

`airflow/www/api/experimental/endpoints.py` registers 18 routes on a Flask
blueprint. The chosen ingress→sink pair:

```python
# airflow/www/api/experimental/endpoints.py
from airflow.api.common.experimental.get_code import get_code
...
@api_experimental.route("/dags/<string:dag_id>/code", methods=["GET"])
@requires_authentication
def get_dag_code(dag_id):                 # <-- INGRESS (http_route)
    """Return python code of a given dag_id."""
    try:
        return get_code(dag_id)            # <-- calls the sink
    except AirflowException as err:
        ...
```

```python
# airflow/api/common/experimental/get_code.py
@deprecated(
    reason="Use DagCode().get_code_by_fileloc() instead",
    version="2.2.4",
    category=RemovedInAirflow3Warning,
)
def get_code(dag_id: str) -> str:          # <-- SINK (reachable)
    """Return python code of a given dag_id."""
    dag = check_and_get_dag(dag_id=dag_id)
    try:
        return DagCode.get_code_by_fileloc(dag.fileloc)   # arbitrary DAG source, no ACL
    ...
```

`@requires_authentication` only checks that *some* authenticated identity is
present — the code comment on the blueprint's registration function states it
plainly: *"the experimental API do not have access control. The authenticated
user has full access."* Any authenticated user (or, depending on the
configured auth backend, any caller at all) can read the source of any DAG on
the instance.

`ResolveDependencySymbols(["airflow.api.common.experimental.get_code.get_code"])`
→ **1 match** here; the node is a call-graph vertex reverse-reachable from an
`http_route` ingress (`@api_experimental.route(...)` on `get_dag_code`) ⇒
**reachable_candidate**.

### Deprecated, but not removed

`get_code` has carried the `@deprecated(...)` decorator since 2021-12-16
(upstream `6239ae91a4`, "Deprecate some functions in the experimental API"),
and `init_api_experimental()` emits a runtime `RemovedInAirflow3Warning` on
every process start when the experimental API is enabled. Neither closes the
reachable path: the decorator only logs, the route stays registered, the sink
still resolves. This branch demonstrates that a multi-year deprecation notice
is not a fix — only the wholesale deletion in `fix` is.

## How it differs from `fix`

`fix` (`8807f73dfd`) **deletes** the entire
`airflow/www/api/experimental/` package (blueprint + all 18 route handlers)
and the entire `airflow/api/common/experimental/` package (including
`get_code.py`), plus the `init_api_experimental()` registration call. The real
code diff is the open PR
[`baseline` ← `fix` (#1)](https://github.com/ferralon-demo/airflow-experimental-api-rce/pull/1).

## Provenance & license

Not a fork — a real source snapshot; no upstream remote or git parents.
Upstream: <https://github.com/apache/airflow> @
`e35ae2db7c56a23b2f7abbd7c4269221ed98ead6`. Upstream `LICENSE` (Apache-2.0)
retained verbatim. `README.md` is the only authored file on this branch; all
other files are the upstream tree, unmodified.

Full index: [`main`](https://github.com/ferralon-demo/airflow-experimental-api-rce/tree/main).
