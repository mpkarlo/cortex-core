# tools

Optional, independent utilities that consume a Cortex instance's derived index
(`_meta/index.json`, see `template/_meta/schemas/index.schema.json`) rather than
parsing Markdown directly. No tool depends on another tool, and no tool is
required for a Cortex instance to be useful.

- `webui/` — local UI for browsing/visualizing an instance (not yet built)
- `timeline/` — timeline/chronological view (not yet built)
- `importers/` — one-off data import scripts (e.g. from another PKM tool)
- `scripts/` — small standalone utilities usable without a full instance

If a tool grows its own dependency tree, release cadence, or external audience,
split it into its own repository at that point — don't provision separate repos
speculatively before a tool exists.
