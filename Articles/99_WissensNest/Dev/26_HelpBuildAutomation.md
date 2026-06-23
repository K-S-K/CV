# WissensNest

## In-App Help — Build Automation

### Problem

The published documentation lives in `Doc/Pub/` as the source of truth.
The Blazor UI serves static files from `wwwroot/`. These two locations must stay in sync,
but duplicating files into the project tree by hand invites drift and requires every author
to remember an extra step.

---

### Solution — MSBuild `<Copy>` Target

A single `<Target>` block in `WissensNest.UI.csproj` copies the entire `Doc/Pub/` tree
into `wwwroot/help/` before every build:

```xml
<Target Name="CopyHelpContent" BeforeTargets="Build">
  <ItemGroup>
    <HelpSourceFiles Include="$(MSBuildThisFileDirectory)../../../Doc/Pub/**/*" />
  </ItemGroup>
  <Copy SourceFiles="@(HelpSourceFiles)"
        DestinationFiles="@(HelpSourceFiles->'$(MSBuildThisFileDirectory)wwwroot/help/%(RecursiveDir)%(Filename)%(Extension)')"
        SkipUnchangedFiles="true" />
</Target>
```

#### How the path resolves

`$(MSBuildThisFileDirectory)` expands to the directory containing the `.csproj` file —
`Src/Services/WissensNest.UI/`. Three `../` steps up reach the repository root,
then `Doc/Pub/` is the source. The glob `**/*` captures every file in every subdirectory.

`%(RecursiveDir)` is the MSBuild item metadata that holds the path from the glob root
to the file's directory (e.g. `User/` or `Architecture/`). Combined with
`%(Filename)%(Extension)` this reconstructs the full relative path under `wwwroot/help/`,
preserving the original directory structure exactly.

#### Why `SkipUnchangedFiles="true"`

Without this flag MSBuild copies every file on every build regardless of whether it changed.
With it, each file's timestamp is compared between source and destination; only modified files
are copied. Incremental builds that touch no documentation files have zero overhead.

#### Why `BeforeTargets="Build"`

The target runs before the main `Build` target so the files are present whenever
`dotnet build` or `dotnet run` triggers a build. This covers both explicit builds
and the Blazor hot-reload loop.

---

### `.gitignore` Entry

`wwwroot/help/` is a generated directory — its content is always derivable from `Doc/Pub/`.
Committing it would duplicate every documentation file in the repository.

```gitignore
# Generated help content — copied from Doc/Pub/ by MSBuild on every build
Src/Services/WissensNest.UI/wwwroot/help/
```

The entry uses the full path from the repository root so it is unambiguous and does not
accidentally ignore any other `wwwroot/help/` directory in a different project.

---

### What Gets Copied

| Source (`Doc/Pub/`) | Destination (`wwwroot/help/`) |
| --- | --- |
| `index.md` | `index.md` |
| `User/*.md` | `User/*.md` |
| `Architecture/*.md` | `Architecture/*.md` |
| `images/*.svg` | `images/*.svg` |

Any new file added under `Doc/Pub/` appears under `wwwroot/help/` on the next build
with no configuration change required.

---

### Limitations

- **Deletions are not propagated.** If a file is removed from `Doc/Pub/`, the stale copy
  under `wwwroot/help/` remains until the directory is cleaned manually or the project
  is rebuilt from scratch (`dotnet build --no-incremental` or delete `wwwroot/help/`).
- **No publish-time copy.** The target runs only during `Build`. If the project is published
  with `dotnet publish --no-build`, the copy does not run and `wwwroot/help/` must exist
  from a prior build. Add `BeforeTargets="Build;Publish"` if publish-only flows are needed.
