# SeaView for macOS

[![DOI](https://zenodo.org/badge/1232537259.svg)](https://doi.org/10.5281/zenodo.20143976)

A macOS port of [OpenSeaSeis](https://github.com/JohnWStockwellJr/OpenSeaSeis) (the open-source SeaSeis seismic processing package by Bjorn Olofsson, now maintained by the Colorado School of Mines). The upstream build script is Linux-only and breaks in several places under Apple Clang. This fork adds a macOS build tree, the source patches needed for Apple Clang and modern macOS, and a `jpackage`-based pipeline that produces a drag-installable `SeaView.app` bundled into a `.dmg`.

## What you get

- **`seaseis`** CLI with the standard module suite (RAY2D excluded — see notes below)
- **`libcsJNIlib.dylib`** — the JNI bridge SeaView uses to read SEGY/SeaSeis/SEGD/RSF files
- **`SeaView.app`** packaged into **`SeaView-<ver>.dmg`** via `jpackage`, including its own embedded JRE so the user does not need a separate Java install

## Quick start (end users)

1. Grab `SeaView-1.0.dmg` from the Releases page.
2. Double-click to mount.
3. Drag `SeaView.app` to `/Applications`.
4. Launch from Launchpad or Spotlight; open SEGY files via **File → Open**.

### First launch on macOS

The bundle is ad-hoc signed but not notarized, so Gatekeeper blocks it the first time. On macOS Sequoia and later the right-click-Open shortcut no longer works for non-notarized apps; you have to clear it once from System Settings:

1. Double-click `SeaView.app`. A dialog will appear saying macOS could not verify the app. Click **Done**.
2. Open **System Settings → Privacy & Security**, scroll to the **Security** section, find the line that says *"SeaView" was blocked…* and click **Open Anyway**.
3. Authenticate with Touch ID or your password. SeaView launches.

After that first approval, subsequent launches go straight through. If you prefer a one-liner that skips the Settings dance entirely, open Terminal and run:

```bash
xattr -dr com.apple.quarantine /Applications/SeaView.app
```

then double-click as normal.

## Build from source

### Prerequisites

| Tool                | Tested version                                     | Notes                                                     |
| ------------------- | -------------------------------------------------- | --------------------------------------------------------- |
| Apple Command Line Tools | Apple Clang 21 (Xcode CLT)                    | provides `clang++`, `ld`, `/usr/bin/install_name_tool`    |
| `gfortran`          | Homebrew (`brew install gcc`)                      | only needed if `BUILD_F77=1` (default)                    |
| JDK with `jpackage` | Temurin OpenJDK 21+ (tested on 26.0.1)             | needed both as JNI source and to package the `.dmg`       |

Set `JAVA_HOME` to a JDK that has `jpackage` (the script falls back to `/usr/libexec/java_home` if unset).

```bash
brew install gcc                                # gfortran for the F77 modules
brew install --cask temurin                     # or download Temurin manually
export JAVA_HOME=$(/usr/libexec/java_home -v 21+)
```

### Build

```bash
git clone https://github.com/aaronjgirard/seaview_macOS.git
cd seaview_macOS
./make_seaseis_macos.sh
```

A clean build takes ~2 minutes on Apple Silicon. Outputs land in a sibling directory of the repo:

```
../lib_v3.00/
├── bin/seaseis                  # CLI
├── lib/libgeolib.so             # core libs (.so on disk; macOS dylib internally)
│   libcseis_system.so
│   libcseis_help.so
│   libsegy.so / libsegd.so
│   libmod_*.so                  # processing modules
│   libcsJNIlib.dylib            # JNI bridge for SeaView
│   CSeisLib.jar / SeaView.jar
└── doc/SeaSeis_help.html
```

To rebuild from scratch, wipe and re-run:

```bash
rm -rf ../lib_v3.00 && ./make_seaseis_macos.sh
```

### Package the `.dmg`

```bash
bash src/make/macos/package_seaview_dmg.sh
```

The script stages the JNI dylib and jars from `lib_v3.00/lib/`, runs `jpackage --type app-image`, ad-hoc-signs the bundle with `codesign --force --deep --sign -`, and then wraps the signed app-image into a dmg. The signing step is what makes the bundle survive Gatekeeper's quarantine check: without it, "Open Anyway" clears the `.app`'s quarantine bit but not the nested `libcsJNIlib.dylib`, and the JVM dies at startup trying to dlopen an unsigned library (Dock icon bounces, then disappears).

`dist/SeaView-1.0.dmg` is what you ship. Override the version with `bash src/make/macos/package_seaview_dmg.sh 1.1`.

## What this fork changes vs upstream

All Linux build files are untouched. The macOS-specific work is additive:

- **New top-level driver**: `make_seaseis_macos.sh`
- **New build tree**: `src/make/macos/` with macOS forks of `cmake.sh`, `Makefile_libs`, `Makefile_segy`, `Makefile_segd`, `Makefile_main`, `Makefile_seaview`, `Makefile_build`, `set_environment.sh`, `check_dirs.sh`, `prepare_cseis_build.sh`, plus a new `fix_install_names.sh`
- **`src/include/cseis_modules.txt`**: `RAY2D` removed (the `wfront` Fortran code references methods that no longer exist on `csMatrixFStyle`; not needed for SeaView's read-side use case)
- **`src/cs/modules/ray2d/`**: deleted
- **`src/cs/geolib/methods_orientation.cc:65`**: `0.0001` → `0.0001f` so Apple Clang's `std::max` overload resolves
- **`src/cs/geolib/geolib_platform_dependent.h`**: `#define stat64 stat` added in the `__APPLE__` branch (`csFileUtils.cc` keeps using `stat64`)
- **`src/cs/jni/csNativeSegyReader.cc`, `csNativeSeismicReader.cc`, `csNativeRSFReader.cc`**: ordered-comparison-on-pointer (`jmethodID <= 0`) replaced with `== NULL`. Apple Clang 21 rejects the comparison; older Clang quietly accepted it.

## Two macOS-specific quirks worth knowing about

**1. Apple `ld` is stricter about cross-library symbols.** GNU `ld` lets a shared library leave undefined symbols to be resolved at load time. On macOS this is opt-in: the build needs `-Wl,-undefined,dynamic_lookup`. Without it, `libcseis_system.so` fails to link because it references `libsegy` symbols that aren't yet built when `Makefile_libs` runs.

**2. Install names need rewriting after the link.** The Linux Makefiles set the SONAME to a bare filename like `libgeolib.so`. On macOS that becomes the install name, and `dyld` will not find it via the executable's `-rpath`. After linking, `src/make/macos/fix_install_names.sh` rewrites every shared library's install id and every consumer's `LC_LOAD_DYLIB` entries to absolute paths under `lib_v3.00/lib`. Two prerequisites for that to work:

- **Use Apple's `install_name_tool`**, not a `conda` or `homebrew` shim. Conda's wrapper accepts the same arguments and exits 0 even when it silently no-ops. The fix script hard-pins `/usr/bin/install_name_tool`.
- **Link with `-Wl,-headerpad_max_install_names`**. Without it, growing a load command from `libgeolib.so` to `/Users/.../lib_v3.00/lib/libgeolib.so` overruns the header pad and `install_name_tool -change` fails with `larger updated load commands do not fit (the program must be relinked, ...)`. Both flags are baked into `GLOBAL_FLAGS` in `make_seaseis_macos.sh`.

If you ever rebuild and `seaseis` reports `Library not loaded: libcseis_help.so`, the headerpad rewrite is the first thing to check.

## Limitations

- **RAY2D module disabled.** The `wfront` ray-tracing code uses methods (`getFirstDim`, `getSecondDim`) that are not on `csMatrixFStyle` in this OpenSeaSeis tree. SeaView does not need it. To re-enable it you'd need to fix the source rather than just unmask it in `cseis_modules.txt`.
- **MPI, FFTW, and SU support are off** in `make_seaseis_macos.sh`. Flip the `BUILD_*` flags at the top of the script if you need them; FFTW will additionally need a Homebrew install and the include/lib paths adjusted.
- **The `.dmg` is ad-hoc signed, not notarized.** Gatekeeper still blocks it on first launch (see "First launch on macOS" above). True one-click installs require an Apple Developer ID and notarization, which are out of scope here.
- **arm64 only.** The shipped dmg is a thin Mach-O arm64 binary. Intel Macs need to build from source.
- **Only the JNI consumers were ported.** The XCSeis JNI library (used by the `xseaseis` GUI, a separate app) is intentionally not built — `cmake.sh` skips it.

## Attribution

OpenSeaSeis is © Colorado School of Mines, originally written by Bjorn Olofsson (2006). See the upstream repo for the full copyright and license:
- <https://github.com/JohnWStockwellJr/OpenSeaSeis>
- `OpenSeaSeis_LEGAL_STATEMENT` and `LICENSE` at the root of this repo.

This fork only adds the macOS build infrastructure and the source patches above; the seismic-processing code itself is unchanged.

## Acknowledgements

Thanks to **Necati Gülünay** ([n.gulunay@protonmail.com](mailto:n.gulunay@protonmail.com)) for testing the v1.0 and v1.0.1 macOS builds on Apple Silicon and surfacing the Gatekeeper / nested-dylib signing issue that motivated the signed packaging script.
