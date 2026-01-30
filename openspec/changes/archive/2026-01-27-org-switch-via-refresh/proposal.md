## Why

Apps need a supported way to switch organizations without a full sign-in redirect. Today the library can refresh tokens with an organization id but exposes no app-facing flow, leading to custom workarounds and inconsistent behavior.

## What Changes

- Refresh endpoint is POST-only and accepts optional `organization_id` to switch organization context.
- Session org context updates from the WorkOS response to keep tokens and `org_id` aligned.
- Usage guidance documents how apps trigger org switching (POST body + return_to) with an example.

## Capabilities

### New Capabilities

- `organization-switching`: Allow authenticated sessions to switch org context via refresh token and update session scope.

### Modified Capabilities

## Impact

- `SgiathAuth.Controller.refresh/2` public contract, route method, and LiveView flow.
- Session keys: `:access_token`, `:refresh_token`, `:org_id`.
- Documentation and usage guidance.
