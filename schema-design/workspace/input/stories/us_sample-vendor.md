# Sample vendor onboarding
slug: sample-vendor
domain: VENDOR

## Description
A vendor can be registered and must belong to an organization. A vendor has a status.

## Acceptance Criteria
- A vendor record can be created with a name and a status.
- A vendor belongs to exactly one organization.

## Test Scenarios
### Register active vendor
Given an organization "Acme"
When a vendor "Globex" is registered under "Acme" with status active
Then the vendor is stored linked to "Acme" with status active
