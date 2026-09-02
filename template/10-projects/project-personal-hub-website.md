---
id: project-personal-hub-website
type: project
status: active
owner: {{OWNER}}
created: 2026-09-01
updated: 2026-09-01
tags: [personal-hub, web, architecture, decision-record]
relatedPeople: []
dueDate:
---

# Personal Hub Website

## Summary

Build a static-first personal hub website that serves as a single entry point to multiple personal projects (journals, blog, media log, and project boards). The hub should stay simple and inexpensive in the first phase while preserving a clean migration path to more advanced hosting/runtime options later.

## Decisions made

1. **Hub + modular repos:** Use one repository per personal project, plus one dedicated hub repository that aggregates links and metadata through static registry files.
2. **Initial hosting platform:** Use Neocities for phase one as the best current fit for static-first deployment with near-zero cost and minimal operational overhead.
3. **Content and data model:** Keep content in Markdown/MDX (or plain static files) inside Git repositories; do not introduce a permanent relational database in the initial phase.
4. **Build/runtime posture:** Keep all deliverables deployable as static output; Astro is an acceptable optional static site generator when it improves ergonomics.
5. **Complexity constraint:** Avoid backend services and persistent runtime infrastructure in the initial phase unless a trigger condition is met.
6. **Governance and AI experimentation direction:** Treat this project as a place to experiment with AI-assisted coding and multi-agent governance patterns using explicit guardrails.

## Deferred decisions / future triggers

1. **When to add dynamic backend capabilities:** Defer until static-only workflows fail on clear needs (for example auth-protected areas, server-side personalization, or non-trivial write paths).
2. **Platform migration decision point:** Re-evaluate Neocities if deployment limits, asset workflows, access control, or automation needs exceed static-host comfort.
3. **Future platform candidates:** Keep Cloudflare Pages/Workers/R2/Access/D1 as explicit migration options when triggers are hit.
4. **Identity/auth model:** Defer authentication and identity architecture until protected content or multi-user workflows become required.
5. **Search/indexing sophistication:** Start simple (static navigation + curated links); revisit full-text or semantic indexing only if content scale materially hurts discoverability.

## Initial repo and deployment topology

```text
personal-hub/                      # hub repo (landing + registry aggregation)
  content/
    registry/
      projects.json                # static metadata/index of linked project repos
  public/                          # static assets
  (optional) astro.config.*        # only if Astro is used

journal-site/                      # independent repo
blog-site/                         # independent repo
media-log-site/                    # independent repo
project-boards-site/               # independent repo
```

Initial deployment shape:

1. Each project repo publishes static output independently.
2. Hub repo publishes static output to Neocities.
3. Hub registry files provide navigation and aggregation links to project surfaces.
4. No cross-repo runtime coupling is required; integration remains metadata-driven.

## Next-step checklist (documentation/planning only)

1. Draft a short architecture note defining the hub registry schema (`projects.json` fields, ownership, update workflow).
2. Define naming and ownership conventions for project repos (slug format, branch strategy, release expectations).
3. Write a content model note for Markdown/MDX usage rules (frontmatter minimums, linking conventions, media handling).
4. Draft a Neocities deployment runbook (manual and scripted publish flow, rollback notes, environment constraints).
5. Add a migration playbook note with explicit triggers and phased path to Cloudflare Pages/Workers/R2/Access/D1.
6. Draft an AI-governance process note covering spec-first workflow, branch isolation, independent review, and human approval gates for deployments/secrets.
7. Capture risks/assumptions log entries (vendor dependency, maintenance load, metadata drift between repos).

## Notes

This project deliberately prioritizes low-cost, low-ops execution in phase one. Any move toward dynamic infrastructure should be justified by explicit trigger conditions rather than speculative pre-optimization.

## Related

- Neocities (initial host)
- Cloudflare Pages / Workers / R2 / Access / D1 (future options)
- AI-assisted coding workflow guardrails
