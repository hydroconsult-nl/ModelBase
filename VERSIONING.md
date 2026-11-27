# Versioning

All Hydroconsult repositories (HYDROC01, HYDROC02, Catchment Builder, Channel Builder, HydroToolbox,
CMStochast, ModelBase) use the same version scheme. The CI checks it on every build.

## The number: `Major.Minor.Patch.Build`

| Part | Raise it when | Example |
|---|---|---|
| **Major** | Users must act or lose something: a new licence key, an incompatible configuration/XML format, a removed function | Signed licence keys → 4.0.0 for all tools |
| **Minor** | New functionality or changed behaviour that does not break existing work | Licence per module, a new tool |
| **Patch** | Bug fixes only, behaviour otherwise unchanged | Customer bug fixes |
| **Build** | Free; `0` in the files. Only Major.Minor.Patch is compared | |

Customers and release notes name three numbers: "Catchment Builder 3.5.1".
Lower parts reset when a higher part goes up (3.5.1 → 3.6.0 → 4.0.0).
Each repository has its own number; a tool without changes needs no release. Only a change that affects all
tools at once (such as the licence model) raises all of them to the same new major version.
The libraries (HYDROC01, HYDROC02) are versioned on their own; a tool's release notes state the HYDROC01
version it was built with.

## Where the version lives in this repository

These must all state the same Major.Minor.Patch:

- `ModelBase.vbproj`: `<Version>` (or `<FileVersion>`/`<AssemblyVersion>`)
- `InnoSetup/Modelbase.iss`: `#define MyAppVersion` (installer)
- `InnoSetup/releasenotes.txt`: the first `vX.Y.Z.0` heading (newest entry on top)

## Releasing

1. Branch `release/vX.Y.Z` from `main`.
2. Set the new version in every file listed above, with a new entry `vX.Y.Z.0` at the top of the release notes.
3. Open a pull request to `main`. The CI version check is **strict** for a branch `release/v…`:
   every file must state X.Y.Z, and X.Y.Z must be higher than every existing `v…` tag.
4. After the merge, tag the merge commit `vX.Y.Z` (`git tag vX.Y.Z <merge-commit>` and `git push origin vX.Y.Z`).
   The tag build runs the same strict check. Build the installer from that tagged commit.

A test build for a customer gets a pre-release tag such as `v3.2.0-beta.1`; the check compares 3.2.0.

## What the CI does

`.github/scripts/check-version.ps1` runs first in `.github/workflows/build.yml`.

- On a release (`release/v…` pull request or a `v…` tag) any mismatch fails the build.
- On other builds a mismatch is only a warning, so a repository whose files disagree today keeps building;
  fix it in the next release.

Run it locally from the repository root:

```powershell
.github/scripts/check-version.ps1 -Sources 'msbuild=ModelBase.vbproj','iss=InnoSetup/Modelbase.iss','releasenotes=InnoSetup/releasenotes.txt'
```

Add `-HeadRef release/vX.Y.Z` to check as if it were a release.

## Support

Bug fixes go into the newest minor version only. A customer on an older version is advised to upgrade.
