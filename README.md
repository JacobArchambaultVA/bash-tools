# bash-tools

Utility Bash scripts for working across repos and test files.

## Requirements

- Bash shell (Git Bash, WSL, or Linux/macOS shell)
- Standard Unix tools used by the scripts: `find`, `xargs`, `awk`, `grep`, `sed`, `perl`

## Scripts

### `gittools/supergit.sh`

Defines a `supergit` Bash function that runs the same command in all immediate subdirectories of the current folder, in parallel.

- Uses `JOBS` env var for parallelism (defaults to CPU count, fallback `8`)
- Prints a header for each repo directory before running the command

Example:

```bash
source gittools/supergit.sh
cd ~/source/repos
supergit git status -sb
supergit git pull --ff-only
```

Optional parallelism limit:

```bash
JOBS=4 supergit git fetch --all --prune
```

### `dotnet-tools/build-ped-services.sh`

Cleans and builds all PED Services projects using MSBuild. It finds all `*-Combined*.sln` solution files under `ped-services-*` directories and runs `dotnet clean` and `dotnet build` with the `debug-combined` configuration for each.

Tracks successes and failures, reporting a summary at the end.

Usage (run from parent repos folder):

```bash
cd ~/source/repos
bash dotnet-tools/build-ped-services.sh
```

### `UnitTests/add-test-category.sh`

Adds `TestCategory("UnitTest")` to MSTest methods in `.cs` files under:

`PayerEDI.TAS.CXM/PayerEDI.TAS.CXM.QA.837SpecFlow`

It replaces:

- `[TestMethod]`

with:

- `[TestMethod, TestCategory("UnitTest")]`

Usage (run from repo root):

```bash
bash UnitTests/add-test-category.sh
```

### `UnitTests/SpecFlow/count-specflow-files-across-repos.sh`

Counts `.feature` files grouped by repository when run from a parent repos folder (for example `~/source/repos`).

Usage:

```bash
cd ~/source/repos
bash /path/to/bash-tools/UnitTests/SpecFlow/count-specflow-files-across-repos.sh
```

### `UnitTests/SpecFlow/count-specflow-tests-per-file.sh`

Finds all `.feature` files under the current directory and prints a tab-separated list of:

- file path
- number of `scenario` occurrences in each file (case-insensitive whole-word match)

Usage:

```bash
cd /path/to/repo-or-parent-folder
bash /path/to/bash-tools/UnitTests/SpecFlow/count-specflow-tests-per-file.sh
```

### `UnitTests/SpecFlow/delete-dangling-specflow-files.sh`

Recursively deletes all `*.feature.cs` generated code files from the current directory and subdirectories.

Useful for cleaning up auto-generated SpecFlow code files that are no longer needed or to reset code generation state.

Usage:

```bash
cd /path/to/repo
bash /path/to/bash-tools/UnitTests/SpecFlow/delete-dangling-specflow-files.sh
```

### `UnitTests/SpecFlow/remove-attributes.sh`

Removes SpecFlow attributes from source files recursively.

It removes lines containing these attributes:

- `[Scope`
- `[Binding`
- `[Given`
- `[When`
- `[Then`

It excludes common build/tool directories (`.git`, `bin`, `obj`, `.vs`, `TestResults`).

It accepts an optional directory argument (defaults to current directory).

Usage:

```bash
cd /path/to/target/repo
chmod +x /path/to/bash-tools/UnitTests/SpecFlow/remove-attributes.sh
/path/to/bash-tools/UnitTests/SpecFlow/remove-attributes.sh

# Or pass a specific directory to process
/path/to/bash-tools/UnitTests/SpecFlow/remove-attributes.sh /path/to/target/repo
```

## Add `supergit` to your shell startup (`~/.bashrc`)

To make `supergit` available in every shell session:

1. Open your home `.bashrc` file:

```bash
nano ~/.bashrc
```

2. Add this line (update the path if needed):

```bash
source ~/source/repos/bash-tools/gittools/supergit.sh
```

3. Reload your shell config:

```bash
source ~/.bashrc
```

4. Verify it works:

```bash
type supergit
```

For Git Bash on Windows, `~` usually maps to your user profile home in Git Bash, so the same steps apply.

## Safety Notes

- Several scripts perform in-place edits (`perl -i`, `sed -i`). Commit or stash changes first.
- Run from the expected working directory noted above to avoid editing/counting unintended files.
