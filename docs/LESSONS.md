# Lessons from porting a Mac-only JUCE suite to Windows without a Windows PC

These come from doing it for real, through GitHub Actions only, over a few days. They are generic: nothing here depends on a particular plug-in.

## What CI can and cannot prove

CI on a `windows-latest` runner covers: the MSVC build, your headless tests (DSP, state, rendering the editor to an image), pluginval at strictness 5 and up, packaging, silent install/upgrade/uninstall of an installer, and "no plain-text strings in the binary" style checks. Render and null tests against your Mac renders need a tolerance: clang and MSVC are not bit-exact.

CI cannot prove: how the plug-in behaves in real Windows DAWs (Ableton Live, FL Studio, Cubase, REAPER, Bitwig), HiDPI scaling at 125, 150 and 175 %, SmartScreen and antivirus reactions, ASIO in a standalone app. Plan three to five Windows beta testers for those.

## Keep the Windows work on a branch, sync from the Mac side

While your main branch is moving (or frozen for a release), keep the Windows edits on a long-lived branch and bring Mac changes over with a three-way merge against the commit the branch was copied from. `scripts/sync_from_mac.sh` does exactly that: for every file the Mac side changed since BASE it takes the Mac version if the Windows branch never touched the file, three-way merges if both changed it, and lists conflicts. Write the new BASE into `.windows-sync-base` afterwards. When your freeze lifts, upstream the Windows edits to main and drop the branch.

## Things that broke, in the order we met them

1. **File names.** Windows cannot create files whose names contain `\ / : * ? " < > |`, end in a dot or space, or are reserved device names. One tracked directory of 69 files named after song titles (with `|` in them) made the whole checkout fail on the runner. A sparse checkout of just the folders you need also avoids dragging such data into CI. Separately, anything your code builds from metadata at run time needs the same sanitising.
2. **GNU-only C++.** String-literal operator templates, `__builtin_*` intrinsics, statement expressions. Use C++20 and the standard replacements (`std::popcount`). If a header uses a trick for string obfuscation or compile-time tables, expect to rewrite it in the standard form.
3. **POSIX headers and tools.** `unistd.h`, `sys/resource.h`, `getpid`, `nice`, hard-coded `/bin/sh` and `/usr/bin/python3`. Wrap, or replace with Win32 calls and `juce::ChildProcess` without a shell. A command like `a && b` run through `/bin/sh` becomes two child processes.
4. **Apple frameworks.** Accelerate (vDSP FFT, BLAS), Core ML, AVFoundation, Core Audio. Give each a plain C++ or cross-platform replacement behind `#if JUCE_MAC`. For a neural network: export to ONNX, run it with ONNX Runtime (CPU provider is enough to start), and compare against your original on the same input before trusting it. Our ONNX vs PyTorch differences were around 1e-4 on peaks near 1.0, about -80 to -90 dB relative, which is far below audibility but above a strict self-test threshold chosen for Core ML, so decide the Windows test bar deliberately.
5. **Binary resources.** `.incbin` in an assembler `.S` file is Mach-O specific. `juce_add_binary_data` is the portable route.
6. **Paths.** Hard-coded `~/Library/...` becomes `C:\Users\you\Library\...` on Windows, which "works" in the wrong place; `/Library/Application Support` becomes `C:\Library`. Map to `%APPDATA%` (per-user data, no admin needed), `%LOCALAPPDATA%` (machine-local state such as caches and trial markers) and `%PROGRAMDATA%` (shared data; creating it needs admin, so create it in the installer). `juce::File` with an absolute Mac path asserts on Windows in Debug builds.
7. **Linker flags.** `-Wl,-dead_strip` and friends are Apple-only. MSVC equivalents: `/OPT:REF /OPT:ICF`, and `/DEBUG:NONE` for release.
8. **Tests that touch the machine.** Rosetta checks, malloc-zone hooks and `RTLD_NEXT` audio-thread watchdogs are macOS-only: print "skipped" on Windows instead of failing.

## Updates

If your plug-in checks an update feed, give the feed a **per-platform download key** (for example `products.<name>.windows`) so one feed serves both platforms. HTTP from JUCE on Windows works through `juce::URL` with `JUCE_USE_CURL=0` (WinINet). "Updates remove old versions" is the installer's job on Windows: an Inno Setup `[InstallDelete]` entry for the old bundle folder replaces the Trash.

## Licence and trial data without admin rights

No keychain on Windows; keep licence and trial state as files. Per-user files in `%APPDATA%\<Product>\` need no admin. The installer needs admin only to write `C:\Program Files\Common Files\VST3\`. If you want a no-admin install, VST3 hosts also scan a per-user folder (`%LOCALAPPDATA%\Programs\Common\VST3`, from the VST3 specification); check that your target DAWs read it.

## GitHub Actions details worth knowing

- Windows minutes bill double on private repositories. Make the workflow manual (`workflow_dispatch`) until you trust it.
- A workflow file is only listed in the Actions tab once GitHub has seen it on the default branch; run branch-only workflows through one that is registered (`workflow_call`) or by API with `ref`.
- `ilammy/msvc-dev-cmd` puts `cl` on the path; use Ninja and `sccache` (`mozilla-actions/sccache-action`) with `CMAKE_*_COMPILER_LAUNCHER`. `CMAKE_POLICY_DEFAULT_CMP0141=NEW` with `CMAKE_MSVC_DEBUG_INFORMATION_FORMAT=Embedded` makes sccache usable with MSVC (no separate PDB).
- Pin everything: JUCE by tag or commit, pluginval by version, ONNX Runtime by version and SHA-256, third-party sources by commit.
- Preinstalled on the runner image (check the image's software list): Inno Setup 6, WiX 3.
- Upload a raw-VST3 artifact `if: always()` so you can inspect failed runs; keep the ZIP and installer artifacts for 30 days, the rest for 14.
- Print what you assert: sizes, counts, hashes. A CI log is the only debugger you have.
