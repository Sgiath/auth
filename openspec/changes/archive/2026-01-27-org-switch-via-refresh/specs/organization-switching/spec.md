## ADDED Requirements

### Requirement: Refresh is POST-only

The system SHALL perform refresh operations only on POST requests to the refresh endpoint.

#### Scenario: GET refresh is rejected

- **WHEN** a client sends a GET request to the refresh endpoint
- **THEN** no session refresh occurs and the request is rejected

### Requirement: Accept organization_id on refresh

The system SHALL accept an optional organization_id on POST refresh requests and SHALL include it in the token refresh request.

#### Scenario: Switch request includes organization_id

- **WHEN** an authenticated session POSTs to the refresh endpoint with organization_id
- **THEN** the refresh request to WorkOS includes organization_id

### Requirement: Align session org to WorkOS response

The system SHALL set the session org_id from the organization_id returned by WorkOS on successful refresh.

#### Scenario: Refresh succeeds with organization_id in response

- **WHEN** WorkOS returns new tokens and an organization_id
- **THEN** the session stores access_token, refresh_token, and org_id from the response

### Requirement: Clear session on failed org switch

The system SHALL clear the session when a refresh attempt with organization_id fails.

#### Scenario: Refresh fails due to invalid org switch

- **WHEN** WorkOS rejects the refresh request with organization_id
- **THEN** the session is cleared and the user is unauthenticated
