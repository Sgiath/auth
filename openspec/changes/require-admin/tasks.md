## 1. Plug Implementation

- [x] 1.1 Add `require_admin/2` plug function in `lib/auth.ex`
- [x] 1.2 Handle nil scope case (redirect to sign-in)
- [x] 1.3 Handle nil admin case (redirect to `/`)
- [x] 1.4 Handle admin present case (continue)

## 2. LiveView Hook Implementation

- [x] 2.1 Add `on_mount(:require_admin, ...)` clause in `lib/auth.ex`
- [x] 2.2 Call `mount_current_scope` at start (self-contained)
- [x] 2.3 Handle no session case (redirect to sign-in)
- [x] 2.4 Handle expired token case (redirect to `/auth/refresh`)
- [x] 2.5 Handle nil admin case (redirect to `/`)
- [x] 2.6 Handle admin present case (continue with socket)

## 3. Testing

- [x] 3.1 Add tests for `require_admin` plug scenarios
- [x] 3.2 Add tests for `:require_admin` hook scenarios
