## Context

Current auth flow stores `org_id` only at callback time. Refresh uses the stored refresh token but does not pass `organization_id`, so apps cannot switch org context without re-auth. LiveView runs over WebSocket, so it cannot update session cookies without a full HTTP request; token expiry in long-lived sessions needs an explicit reload path.

## Goals / Non-Goals

**Goals:**

- Allow apps to trigger org switching via a POST refresh endpoint by providing `organization_id`.
- Keep session tokens and `org_id` aligned with the WorkOS response.
- Move refresh operations to POST-only and document the new usage with an example.
- Provide a LiveView-friendly POST refresh pattern using a client hook and `return_to`.

**Non-Goals:**

- Backward compatibility with GET refresh requests.
- New dedicated switch endpoint or UI flow.
- Organization membership discovery or validation in the library.

## Decisions

- Make refresh operations POST-only and accept optional `organization_id` in the POST body.
  - Rationale: minimal surface area, consistent with current refresh behavior, avoids additional routing config.
  - Alternatives: new `/auth/switch-org` endpoint (clearer semantics but more wiring), or full AuthKit re-auth flow (extra round-trip).
- Pass `organization_id` into `authenticate_with_refresh_token/3` and set `:org_id` from the WorkOS response.
  - Rationale: ensures session state reflects authoritative org context from tokens, avoids trust in request params.
  - Alternative: accept and store request org_id (risk of mismatch if WorkOS rejects or returns different org).
- Document a LiveView client hook that POSTs to refresh with `return_to`, triggering a full page reload.
  - Rationale: LiveView cannot update cookies without an HTTP response; a hook provides an explicit refresh path.
  - Alternative: add a helper GET page that auto-posts to refresh, but this adds another endpoint.
- On refresh failure (including invalid org switch), keep current behavior: clear session and unauthenticate.
  - Rationale: consistent fallback, avoids partial or stale auth state.

## Risks / Trade-offs

- [Apps must add a client hook to refresh] -> Provide a ready-to-copy hook and example usage in docs.
- [No local membership validation] -> Rely on WorkOS to reject invalid orgs; document that apps may validate membership before calling refresh.
- [Param misuse could create confusion] -> Always set org_id from response, not request.
