# ModelBase
Een desktopapplicatie voor het beheer van hydrologische en hydraulische simulatiemodellen

## Build
Standalone: `git clone` this repository, open `ModelBase.sln` and build, or
`msbuild ModelBase.sln /restore /p:Configuration=Release`.
HYDROC01 (and through it HYDROC02) comes from the hydroconsult NuGet feed (see below). MapWinGIS (x64) must be
installed to run ModelBase, not to build it. ModelBase targets net7.0-windows and uses the net48 HYDROC01
(package or project) through .NET's compatibility fallback.

Development: with HYDROC01 and HYDROC02 checked out next to this repository (`..\HYDROC01`, `..\HYDROC02`),
open `ModelBase.Dev.sln`: HYDROC01 and HYDROC02 are then project references, so changes in the libraries are
built and can be debugged together with ModelBase. Force one with `/p:UseHYDROC01Project=true` or `false`.
The HYDROC01 package version is `HYDROC01Version` in ModelBase.vbproj.

## Releasing ModelBase
Releases are built in the development layout, as before: HYDROC01, HYDROC02 and ModelBase checked out
side by side (e.g. in `C:\GITHUB`), on the commits you want to ship. Build `ModelBase.Dev.sln` (Release)
and make the installer from `InnoSetup\`. No NuGet feed, tag or version bump is needed for this.

The HYDROC01 package and `HYDROC01Version` only matter for a standalone checkout and for CI. Publishing a new
HYDROC01 package (a tag on HYDROC01) and raising `HYDROC01Version` is optional. Note that a release built in the
development layout contains the HYDROC01 that was checked out, which can be newer than `HYDROC01Version`.

## Feed and login (once per PC)
The Hydroconsult packages are on GitHub Packages (`https://nuget.pkg.github.com/hydroconsult-nl/index.json`).
GitHub Packages always needs a login, also for reading. Create a personal access token (classic) with scope
`read:packages` and store it once in your user NuGet configuration (Visual Studio and MSBuild then use it):

```
dotnet nuget add source https://nuget.pkg.github.com/hydroconsult-nl/index.json --name hydroconsult --username <github-user> --password <token> --store-password-in-clear-text
```

## Versioning
Version numbers follow [VERSIONING.md](VERSIONING.md); the CI checks that all files state the same version.
