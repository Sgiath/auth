## Context

The auth library already has two patterns for route protection:

- `require_authenticated_user/2` plug + `:require_authenticated` hook - checks `scope.user`
- `require_organization/2` plug + `:require_organization` hook - checks `scope.org`

The `Scope` struct has an `admin` field populated via the optional `load_admin/1` callback on the profile module. This represents dev team members with admin profiles in the consuming app's database.

## Goals / Non-Goals

**Goals:**

- Add `require_admin/2` plug mirroring existing authorization plugs
- Add `:require_admin` on_mount hook mirroring existing hooks
- Non-admin users silently redirected to `/`
- Self-contained hook (handles all auth states internally)

**Non-Goals:**

- Configurable redirect path (hardcoded to `/` for simplicity)
- Admin permission levels or roles (just binary admin/not-admin check)
- Custom error pages or flash messages for unauthorized access

## Decisions

### 1. Mirror `require_organization` structure exactly

**Decision**: Copy the exact pattern from `require_organization` for both plug and hook.

**Rationale**: Consistency with existing codebase. Developers already understand this pattern. The hook handles three states: no session, expired token (needs refresh), and valid scope.

**Alternative considered**: Composable hook that only checks `scope.admin` (expects prior mount). Rejected because other hooks are self-contained - mixing patterns would be confusing.

### 2. Redirect to `/` for non-admins

**Decision**: Non-admin users redirect to root path, not an error page.

**Rationale**: Admin routes are typically invisible to regular users. A 403 page implies they found something they shouldn't access. Silent redirect to home feels cleaner - they just end up where they should be.

### 3. No flash message

**Decision**: No "you don't have permission" flash message.

**Rationale**: Flash messages draw attention to the admin interface's existence. If a non-admin hits an admin route (likely via direct URL), silently redirecting is less intrusive.

## Risks / Trade-offs

**[Debugging difficulty]** Silent redirects can be confusing during development.  
→ Mitigation: Add Logger.debug when redirecting non-admin users.

**[Hardcoded redirect]** Can't customize redirect path per-app.  
→ Mitigation: Accept this limitation for now. Can add config option later if needed.
