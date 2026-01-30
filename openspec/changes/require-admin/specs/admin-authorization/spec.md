## ADDED Requirements

### Requirement: Admin authorization plug

The system SHALL provide a `require_admin/2` plug that restricts controller routes to users with a non-nil `admin` field in their scope.

#### Scenario: Admin user accesses protected route

- **WHEN** a user with `scope.admin` not nil accesses a route protected by `require_admin`
- **THEN** the request continues normally

#### Scenario: Non-admin user accesses protected route

- **WHEN** a user with `scope.admin` equal to nil accesses a route protected by `require_admin`
- **THEN** the user is redirected to `/`
- **AND** the connection is halted

#### Scenario: Unauthenticated user accesses protected route

- **WHEN** a user with nil scope accesses a route protected by `require_admin`
- **THEN** the user is redirected to the sign-in path
- **AND** the connection is halted

### Requirement: Admin authorization LiveView hook

The system SHALL provide an `:require_admin` on_mount hook that restricts LiveViews to users with a non-nil `admin` field in their scope.

#### Scenario: Admin user mounts protected LiveView

- **WHEN** a user with `scope.admin` not nil mounts a LiveView with `on_mount :require_admin`
- **THEN** the mount continues with scope assigned

#### Scenario: Non-admin user mounts protected LiveView

- **WHEN** a user with `scope.admin` equal to nil mounts a LiveView with `on_mount :require_admin`
- **THEN** the socket halts with redirect to `/`

#### Scenario: Unauthenticated user mounts protected LiveView

- **WHEN** a user with no session mounts a LiveView with `on_mount :require_admin`
- **THEN** the socket halts with redirect to sign-in path

#### Scenario: Expired token user mounts protected LiveView

- **WHEN** a user with expired access token mounts a LiveView with `on_mount :require_admin`
- **THEN** the socket halts with redirect to `/auth/refresh` with return_to parameter

### Requirement: Admin check is self-contained

The `:require_admin` hook SHALL mount the current scope internally, following the same pattern as `:require_organization`.

#### Scenario: Hook mounts scope before checking

- **WHEN** `:require_admin` hook is used without prior `:mount_current_scope`
- **THEN** the hook loads the scope from session before checking admin field
