# Case 411863 Reproduction Kit (GitHub OIDC -> Artifactory)

This folder reproduces the behavior from case `411863`: an OIDC token from GitHub Actions appears to have broader read access than the configured scoped group.

## Goal

Reproduce and compare:

- OIDC token exchange token from `/access/api/v1/oidc/token`
- Admin-issued token from `/access/api/v1/tokens` with the same `username` and `scope`

against an npm repository (`npm-internal`) that should be denied for the scoped group.

## Files

- `.github/claims/simulation-web-app-claims.json`: claims file for GitHub repo mapping
- `.github/workflows/repro-oidc-scope.yml`: workflow to request OIDC token and test npm access
- `scripts/verify_token_access.sh`: local helper to test token behavior and collect evidence

## Prerequisites

1. GitHub repo under your account/org (for example, a repo in `harryv-art`).
2. JFrog platform admin access on your instance.
3. An npm package that exists in `npm-internal` to test a deterministic download URL.

## Artifactory Setup (mirror case conditions)

1. Create or identify groups:
   - `github-repo-simulation-web-app` (the scoped group used by OIDC mapping)
   - `readers` (Auto Join enabled, with read to `npm-internal`)
2. Ensure `github-repo-simulation-web-app` **does not** have read permission to `npm-internal`.
3. Ensure `github-repo-simulation-web-app` has permissions only to the intended repos (for example `cargo-internal` and `prod`).
4. Configure GitHub OIDC integration with an identity mapping whose token spec is:

```json
{
  "username": "github-simulation-web-app",
  "scope": "applied-permissions/groups:github-repo-simulation-web-app",
  "expires_in": 3600
}
```

5. Use the claims file in `.github/claims/simulation-web-app-claims.json`.

## GitHub Secrets/Variables

Configure these in your repository settings:

- `JF_URL` (example: `https://harryv1.jfrog.io`)
- `JF_OIDC_PROVIDER` (OIDC integration name in Artifactory, example: `github`)
- `JF_OIDC_IDENTITY` (OIDC identity mapping name, example: `simulation-web-app`)
- `NPM_TEST_URL` (exact package tarball URL in `npm-internal`)
- `JF_ADMIN_TOKEN` (optional, only for the admin token comparison step in workflow)

## Run

1. Commit this folder content to your GitHub repo.
2. Trigger the workflow from the Actions tab (`workflow_dispatch`).
3. Inspect output for:
   - OIDC token request status
   - npm tarball fetch status using OIDC token
   - optional admin-issued token fetch status for side-by-side comparison

## Expected Result (case-like behavior)

- If the anomaly reproduces:
  - OIDC token fetch to `npm-internal` returns `200`
  - Admin token fetch with same `username` + `scope` returns `403`

- If behavior is fixed/strict:
  - both paths should return `403` for `npm-internal`.

## Notes

- Keep the package URL and repository fixed for both tests so only token source differs.
- Record timestamp and timezone from workflow logs for correlation with server-side debug logs.
