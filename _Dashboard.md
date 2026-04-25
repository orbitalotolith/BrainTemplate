---
tags: [dashboard]
---
# Development Dashboard

## Active Projects

```dataview
TABLE WITHOUT ID
  file.link AS "Project",
  client AS "Client",
  status AS "Status"
FROM "_Docs"
WHERE contains(tags, "project") AND status = "active"
SORT file.name ASC
```

> If Dataview plugin is not enabled, this shows as a code block. Fallback:

| Project | Client | Status |
|---------|--------|--------|
| [[_Docs/<slug>/\|<Project Name>]] | <Category> | Active |

## Recent Dev Log Entries

```dataview
TABLE WITHOUT ID
  file.link AS "Entry",
  file.folder AS "Project",
  file.cday AS "Date"
FROM ""
WHERE contains(file.folder, "DevLog")
SORT file.cday DESC
LIMIT 10
```

## Recently Active
> Add projects here as you start working on them.

## Archived
> Move completed projects to an `_Archive/` folder within their client directory.

## Quick Links
- [[_ActiveSessions]]
- [[_HowThisWorks]]
- [[key-to-dev]]
