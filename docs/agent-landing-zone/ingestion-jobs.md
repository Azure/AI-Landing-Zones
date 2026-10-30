# Jobs & schedules

Agent App Ingestion runs indexing and maintenance jobs inside its Container App.
Use schedules for recurring synchronization and manual triggers for a reviewed
one-off run. These jobs are separate from Search's service-managed native
Foundry IQ indexers.

!!! warning "Starting ingestion can change data"
    Startup jobs are enabled by default. Indexing replaces Search documents,
    purge jobs delete indexed copies or image blobs, and log cleanup deletes old
    run summaries. Review sources, target indexes, permissions and schedules
    before starting the service, including during local development.

## Jobs and startup

The service initializes configuration and mode-specific resources, mounts the
applicable administrative routes, configures telemetry and starts APScheduler.
Schedules use **five-field crontab** syntax:
`minute hour day-of-month month day-of-week`.
They are not six-field Azure Functions timers.

| Job type for manual execution | Schedule setting | Startup default |
| --- | --- | --- |
| `blob_index` | `CRON_RUN_BLOB_INDEX` | `0 * * * *`, hourly at minute 0 |
| `blob_purge` | `CRON_RUN_BLOB_PURGE` | `10 * * * *`, hourly at minute 10 |
| `sharepoint_index` | `CRON_RUN_SHAREPOINT_INDEX` | No schedule |
| `sharepoint_purge` | `CRON_RUN_SHAREPOINT_PURGE` | No schedule |
| `nl2sql_index` | `CRON_RUN_NL2SQL_INDEX` | No schedule |
| `nl2sql_purge` | `CRON_RUN_NL2SQL_PURGE` | No schedule |
| `multimodality_images_purge` | `CRON_RUN_IMAGES_PURGE` | No schedule, and the worker skips unless `MULTIMODAL=true` |
| Log cleanup, not a manual job type | `CRON_RUN_LOG_CLEANUP` | `0 * * * *`, plus immediate startup cleanup |

`RUN_JOBS_ON_STARTUP` defaults to `true`. Scheduled ingestion and purge jobs
also run sequentially in a background startup task, in this order: Blob index,
Blob purge, NL2SQL index, NL2SQL purge, SharePoint index, SharePoint purge and
image purge. The server does not wait for them before accepting requests.
Jobs without schedules are not included in that immediate sequence.

Setting `RUN_JOBS_ON_STARTUP=false` suppresses those immediate ingestion/purge
runs. It **does not disable cron or immediate log cleanup**. Unset or blank
Blob cron settings receive the startup defaults, so blanking them is not a
durable way to disable Blob work.

The process variable `SCHEDULER_TIMEZONE` selects a valid time-zone name.
An unset or invalid value uses the machine's local zone. Inspect the logged
zone and next run rather than assuming UTC. Invalid cron expressions fail
schedule setup.

## Configure and apply schedules

1. Confirm the selected [ingestion path](ingestion.md) and required source
   dependencies. Use a development corpus for the first run.
2. Set cron values through [Application settings](application-settings.md).
   Verify effective reads after writes, especially where duplicate labels exist.
3. If the administrative surface is mounted, use its configuration apply action
   or `POST /api/config/apply` to refresh configuration and reschedule known
   ingestion/purge jobs. This is an in-process refresh, not a Container App
   restart. It does not remount administrative routes or re-resolve deployment
   mode.
4. Inspect the returned rescheduled list and any failures, then verify the queue's
   next run and time zone. Restart when a changed setting requires fresh clients
   or changes the mounted surface.

Apply can remove a scheduled ingestion/purge job when its effective cron is
blank. For Blob jobs that temporary state does not survive a restart, which
restores blank startup defaults. A missing Blob cron receives its default
during apply too. Log-cleanup scheduling is established at startup and is not
part of the ingestion/purge apply map.

A genuine schedule-application failure returns `500` and can leave earlier
schedules applied. Configuration writes can also partially succeed.
A confirmed write remains applied even if best-effort local refresh fails.
Neither operation promises rollback. Check effective settings and schedules
before retrying a mutation.

## Run a job manually

Use the ingestion dashboard's run action, or the corresponding administrative
route, for example:

```http
GET https://<ingestion-app-host>/api/jobs/queue
POST https://<ingestion-app-host>/api/jobs/sharepoint_index/run
```

The job type is one of the identifiers in the table above. A job can be run
manually without a cron schedule. `202 Accepted` means queued, not completed.
`409 Conflict` means the same job type is already tracked as running, including
a cron-triggered run. Wait and inspect that run rather than repeatedly submitting.

The registry, lock and tracking are process-local. They are not a distributed
lock across replicas, and the manual duplicate check is not an exclusive lock
between different job types. Plan index and purge windows so they do not race
over the same corpus. Do not infer cross-replica serialization from `409`.

Manual runs and configuration mutations require the exact `Admin` role when
Entra is configured. Classic development without a configured tenant has an
open development gate. Administrative reads and the file-unblock route do not
have that same unconditional gate. Restrict access to the administrative
surface through the deployment's network and access controls rather than
exposing it publicly. Hosted mode without
the administrative panel does not mount these routes, although jobs still run.
[Administration](operations.md) describes the dashboard and mode-specific
availability. [Application authentication](application-auth.md) covers access.
[API reference](application-api.md) supplies request and response schemas.

## Index, purge and cleanup effects

| Job | What the operator must account for |
| --- | --- |
| Blob index | Processes new or changed files from `DOCUMENTS_STORAGE_CONTAINER` and optional `BLOB_PREFIX`. It replaces a parent's old chunks, which is not an atomic swap. Processing failure can leave content missing or partial. Per-file logs track retry attempts and blocking. |
| Blob purge | Intended to remove indexed Blob documents missing from the selected container/prefix. The initialization limitation below currently prevents this cleanup. |
| SharePoint index | Processes configured lists/libraries and reconciles supported ACLs even for unchanged content. See [permission synchronization](sharepoint.md#permission-synchronization). |
| SharePoint purge | Deletes indexed copies of missing items in enumerated collections. It is not complete source retirement or filter reconciliation. Empty or unavailable collections are skipped. |
| NL2SQL index | Indexes JSON metadata from `queries/`, `tables/` and `measures/`, including embeddings. It does not copy database rows. |
| NL2SQL purge | Deletes metadata index documents whose corresponding metadata blobs no longer exist. It does not delete database tables or rows. |
| Image purge | Deletes image blobs not referenced by `relatedImages` in its configured Search index. A wrong index/container pair can make live images look unreferenced. |
| Log cleanup | Keeps at most `MAX_LOG_RUN_FILES` run-summary blobs, default `500`, deleting the oldest excess summaries. It is not a retained audit archive. |

!!! warning "Blob cleanup limitation"
    The supplied Blob purge worker fails during credential initialization before
    comparing source and index state. A running schedule does not establish that
    deleted source files have disappeared from Search. Inspect failed runs and
    verify stale indexed content explicitly. If removal is required, use a
    separately authorized, scoped Search cleanup rather than relying on this
    job or broadening its permissions.

The Blob comparison is intended to scan all `source=blob` documents in the
target index against the selected container/prefix. Do not share that cleanup
target with unrelated Blob corpora and assume the prefix limits both sides.
Blob scans and parent deletions are bounded by time and paging limits, so
verify every affected chunk rather than relying only on summary counts.

The image purger reads `AZURE_SEARCH_INDEX_NAME` (default `ragindex`) and
`STORAGE_CONTAINER_IMAGES` (default `documents-images`). These are not aliases
for the custom indexer's `SEARCH_RAG_INDEX_NAME` and
`DOCUMENTS_IMAGES_STORAGE_CONTAINER`. Align them deliberately before scheduling
image cleanup. A failed or invalid reference scan stops the purger rather than
treating unknown state as an empty reference set.

## Inspect results and recover

Use the queue for scheduled/running work, run summaries for outcomes, and
per-file logs for errors, blocked files and confirmed indexed/deleted counts.
The default summary container is `JOBS_LOG_CONTAINER=jobs`. Health probes
`/healthz` and `/readyz` establish process availability, not indexing success.
A run wrapper completing does not prove that every source item was indexed.

Correct the cause of a blocked file before using the dashboard's unblock action
or `POST /api/files/unblock`. Unblocking resets its control log so a later
index run can retry. It does not immediately index the file or restore deleted
chunks. See [Administration](operations.md) for file controls and
[Monitoring & audit](application-monitoring.md) for job correlations,
document events and provenance.

Retain source documents and configuration separately from disposable run logs.
Rolling back an image does not restore Search documents, image blobs or deleted
summaries, and does not undo App Configuration writes or unblock controls.
Recovery can require separately authorized source restoration, scoped cleanup
and reingestion. Verify all affected chunks and citations before returning a
protected source to service.
