# juce-windows-ci

Build, test and package JUCE audio plug-ins for Windows for free on GitHub Actions, from a Mac, without owning a PC.

Made by Tommy Martin. Built while running [ClubPlugins](https://clubplugins.com).

## What this is

A template repository: one GitHub Actions workflow plus a tiny example plug-in to prove it works. You push to GitHub, click "Run workflow", and a few minutes later you download a Windows build from the run page. The workflow:

1. fetches JUCE at a pinned tag (cached),
2. builds your plug-in as a Windows x64 VST3 with MSVC, Ninja and sccache,
3. runs your unit-test executable on the runner,
4. validates the VST3 with [pluginval](https://github.com/Tracktion/pluginval) at strictness 5,
5. packs a plain ZIP with a SHA-256 file and tests it the way a user would (unzip, copy into the system VST3 folder, validate that copy, remove it),
6. optionally builds an Inno Setup installer and tests silent install, upgrade and uninstall,
7. optionally fetches ONNX Runtime (hash-checked) for plug-ins that run a neural network,
8. uploads everything as artifacts.

It came out of porting a commercial Mac-only plug-in suite to Windows without a Windows machine. The lessons from that are in [docs/LESSONS.md](docs/LESSONS.md); the part you will hit first is [Troubleshooting](#troubleshooting).

## JUCE licence: read this first

This repository contains **no JUCE source**. CMake downloads JUCE from the official repository when you configure. JUCE is dual-licensed: AGPLv3, or a commercial JUCE licence (with tiers, some of them free below a revenue limit; check the current terms on [juce.com](https://juce.com)). Which one applies to you depends on what you ship and how. You are responsible for having a JUCE licence that fits your plug-in; downloading it in CI does not change that. The example plug-in and the scripts here are MIT.

## Quick start (push to GitHub, download the ZIP from Actions)

You need a GitHub account and `git`. Nothing else, no Windows PC.

1. Click "Use this template" on GitHub (or copy these files into your own repository). Public repositories get GitHub-hosted runners for free. On a private repository Windows minutes count double against your plan's included minutes (check GitHub's current billing page).
2. Push it. Nothing runs on push; the workflow is manual on purpose.
3. Open the repository on GitHub, **Actions** tab, **windows** on the left, **Run workflow**. The defaults build and test the ZIP. Tick **installer** to also build and test the Inno Setup installer.
4. Wait. We have not timed the tiny example on Windows; a mid-size real plug-in took us about 19 minutes on a cold cache and the job is capped at 60 minutes (`timeout-minutes`).
5. Open the finished run. At the bottom, **Artifacts**: download `GainExample-0.1.0-Windows-x64` (the ZIP and its `.sha256`). Unzip it on any Windows PC and follow `Install - read me.txt`.

Command line equivalent (needs the [GitHub CLI](https://cli.github.com)):

```bash
gh workflow run windows.yml --ref main -f strictness=5 -f installer=true
gh run watch
gh run download --name GainExample-0.1.0-Windows-x64
```

### Use it for your own plug-in

Change four lines in `.github/workflows/windows.yml` under `env:`:

| Variable | Meaning |
|---|---|
| `PLUGIN_NAME` | the `juce_add_plugin(<name>` target and its `PRODUCT_NAME`, without spaces |
| `VST3_TARGET` | the CMake target that builds the VST3 (`<name>_VST3`) |
| `TEST_TARGET` | your unit-test exe target, or empty to skip |
| `ISS_FILE` | your Inno Setup script, or empty to skip the installer |

and replace `CMakeLists.txt` and `Source/` with yours (keep the line `project(<Name> VERSION x.y.z ...)`: the workflow reads the version from it). If your project already uses JUCE as a submodule, delete the `FetchContent` block and the `-DFETCHCONTENT_SOURCE_DIR_JUCE` line, and check the submodule out in the workflow instead.

### Workflow inputs

| Input | Default | What it does |
|---|---|---|
| `juce_tag` | `9.0.3` | JUCE tag or commit to build against |
| `build_type` | `Release` | `Release` or `RelWithDebInfo` |
| `strictness` | `5` | pluginval level, 1 to 10 |
| `unit_tests` | on | build and run the unit-test exe |
| `package_zip` | on | build the ZIP and test it |
| `installer` | off | build the Inno Setup installer and test install, upgrade, uninstall |
| `onnxruntime` | off | fetch the official ONNX Runtime CPU package (see below) |

The same inputs work when another workflow calls this one (`workflow_call`). To build on version tags, uncomment the `push:` block at the top of the workflow.

## What is in the box

| Path | What |
|---|---|
| `.github/workflows/windows.yml` | the workflow |
| `CMakeLists.txt`, `Source/` | the example plug-in: one gain parameter, a small editor. Original code, a stand-in for yours |
| `Test/unit_test.cpp` | headless test exe: DSP, state round trip, editor rendered to an image at three sizes |
| `scripts/make_zip.ps1`, `scripts/test_zip.ps1` | pack the ZIP and prove it works |
| `installer/GainExample.iss` | Inno Setup script: installs to `Common Files\VST3`, removes the previous copy first |
| `scripts/fetch_onnxruntime.ps1` | download, hash-check and expand ONNX Runtime |
| `scripts/sync_from_mac.sh` | keep a Windows branch in step with your Mac branch (see [LESSONS](docs/LESSONS.md)) |
| `tools/lint.sh` | cheap checks you can run on a Mac before pushing |
| `docs/` | lessons learned, signing and SmartScreen notes, portable FFT note |

## Tested

Honest status:

- **On macOS (Apple silicon, CMake 4.x, JUCE 9.0.3):** the example plug-in configures (both with CMake fetching JUCE from the tag and with a local JUCE checkout), builds as a VST3 and the unit-test executable builds and passes (10 checks). `tools/lint.sh` parses the workflow as YAML and checks that every script it calls exists. `scripts/sync_from_mac.sh` was run against a toy repository (take, merge, clean-tree guard).
- **Not run locally:** anything that needs Windows. The workflow, the PowerShell scripts and the Inno Setup script cannot run on a Mac, and `actionlint` was not installed when this was written (`brew install actionlint`, then `tools/lint.sh` uses it).
- **In CI:** the same workflow pattern (JUCE pinned and cached, MSVC x64 with Ninja and sccache, test exe, pluginval strictness 5, ZIP packaging and ZIP test, Inno Setup installer with silent install, upgrade and uninstall) ran green in the private CI of the project it was extracted from, for real plug-ins. This repository's example is a cleaned-up, renamed version of that pattern, so **the first run on your repository is its first run in this exact form**: expect to fix a typo or two. Please open an issue with the log if something is off.

## ONNX Runtime (optional)

For plug-ins that run a neural network. Set the `onnxruntime` input; the workflow runs `scripts/fetch_onnxruntime.ps1`, which downloads `onnxruntime-win-x64-<version>.zip` from the official [microsoft/onnxruntime](https://github.com/microsoft/onnxruntime/releases) releases, **fails if its SHA-256 differs from the one pinned in the workflow** (`ORT_VERSION`, `ORT_SHA256`), and exports `ORT_ROOT`. The workflow passes it to CMake as `-DORT_ROOT=...`. Wiring it into your target:

```cmake
if(ORT_ROOT)
    target_include_directories(MyPlugin PRIVATE "${ORT_ROOT}/include")
    target_link_libraries(MyPlugin PRIVATE "${ORT_ROOT}/lib/onnxruntime.lib")
    add_custom_command(TARGET MyPlugin POST_BUILD COMMAND ${CMAKE_COMMAND} -E copy_if_different
        "${ORT_ROOT}/lib/onnxruntime.dll" "$<TARGET_FILE_DIR:MyPlugin>")     # next to the plug-in DLL
endif()
```

Ship `onnxruntime.dll` inside the VST3 bundle next to your DLL, and ship its licence file. When you change `ORT_VERSION`, take the new hash from the release page and keep it pinned. Speed warning: see Troubleshooting.

## Free route, signing and SmartScreen

You do not need a code-signing certificate to test. The ZIP route ([docs/SIGNING.md](docs/SIGNING.md)) has no installer `.exe` for SmartScreen to judge; it is unsigned, so tell testers to tick **Unblock** on the ZIP before unzipping if Windows marks it as downloaded. For a public release, the notes on Azure Artifact Signing and traditional certificates are in [docs/SIGNING.md](docs/SIGNING.md).

## Troubleshooting

Real problems from porting a Mac plug-in suite to Windows through CI alone.

| Symptom | Cause and fix |
|---|---|
| `git clone` / checkout fails on the runner, or on a Windows tester's PC, with "invalid path" | A tracked file name has a character Windows cannot create: `\ / : * ? " < > \|`, a trailing dot or space, or a reserved name (`CON`, `PRN`, `AUX`, `NUL`, `COM1`...). We had 69 data files named after song titles containing `\|`. Rename them on your Mac branch. `git ls-files \| grep -E '[:*?"<>\|]'` finds them. |
| Your own code fails on Windows at run time with the same kind of file name | You build a folder or file name from a title ("Artist\|Title") at run time. Sanitise every name you create from user or metadata text, not only the ones in the repo. |
| A test that opens an editor window and checks its size fails on the runner, while the same render passes at other scales | The runner's virtual display is small and top-level windows can be limited to the display. Do not assert a size of a real OS window on a headless runner. Render the editor to an image (`createComponentSnapshot`) and print the sizes so the log tells you why. See `Test/unit_test.cpp`. We did not prove the display size was the cause in our case; we stopped depending on it. |
| Test passes locally, times out on the runner | Runners are small machines (2 vCPU in our private-repo runs; GitHub's documentation lists the current specs). A neural-network step that took 5 s per minute of audio on an Apple-silicon Mac took about 30 s per minute on the runner. Give CPU-bound tests generous limits, or measure and print instead of asserting a time. |
| `error C2...` on code that compiles with clang | MSVC does not accept GNU extensions: string-literal operator templates, statement expressions, `__builtin_popcount` (use `std::popcount` with C++20), `typeof`. Build with C++20 on MSVC and use the standard forms. |
| `unistd.h` / `sys/resource.h` not found | POSIX headers. Guard with `#if JUCE_WINDOWS` and use `_getpid`, `SetPriorityClass` and friends. |
| `/D...` flag arrives as a Windows path | In git-bash, an argument starting with `/` is rewritten into a path. Pass compiler flags as `-D...`, not `/D...`, in `bash` steps. |
| Resources linked with `.incbin` in an assembler file fail to link | That is Mach-O assembler syntax. Use `juce_add_binary_data` (portable) or an `.rc` resource. |
| Link errors for Accelerate, Core ML, AudioToolbox | Apple-only. Put them behind `if(APPLE)` / `#if JUCE_MAC`, provide a plain C++ fallback ([docs/PORTABLE_FFT.md](docs/PORTABLE_FFT.md)) and ONNX Runtime for Core ML models. |
| Data lands in `C:\Users\you\Library\...` or `C:\Library\...` | You hard-coded macOS paths. Use JUCE's special locations (`userApplicationDataDirectory` is `%APPDATA%` on Windows) and map machine-wide data to `%PROGRAMDATA%`. In Debug builds `juce::File("/Library/...")` also asserts on Windows. |
| The workflow does not appear in the Actions tab | GitHub lists workflow files it has seen on the default branch. Merge it to the default branch once, or call it from a workflow that is there (`workflow_call`), or start it by API with `ref`. |
| First run is very slow | Cold caches: JUCE, sccache. The second run is much faster. Keep the JUCE cache key on the tag. |
| Installer silent test cannot find the uninstall key | The registry key is `{AppId}_is1` where AppId is the GUID in the `.iss`. Never change it between versions. |
| `git` hangs on your Mac | If your repo lives in an iCloud-synced folder (Desktop, Documents), the file provider can stall git. Work from a clone outside it. |

## Licence

MIT. See `LICENSE`. JUCE, ONNX Runtime, pluginval and Inno Setup have their own licences; this repository ships none of them.
