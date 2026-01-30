## Why

The auth library supports checking for authenticated users and organization membership, but lacks a built-in mechanism to restrict routes/LiveViews to admin users (dev team members with admin profiles). Apps need to manually check `scope.admin` in each protected route.

## What Changes

- Add `require_admin/2` plug for controller routes that checks `scope.admin` is not nil
- Add `:require_admin` on_mount hook for LiveView that mirrors `require_organization` behavior
- Non-admin users redirected to `/` (not an error page, just quiet redirect)

## Capabilities

### New Capabilities

- `admin-authorization`: Authorization checks for admin-only routes and LiveViews

### Modified Capabilities

<!-- None - this adds new functionality without changing existing behavior -->

## Impact

- `lib/auth.ex`: New plug and on_mount hook functions
- Consumer apps can use `plug :require_admin` and `on_mount :require_admin`
- No breaking changes to existing functionality
