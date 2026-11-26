# cool_fox (CGBJ Runtime Continuation)

[![CI](https://github.com/DoubleGhosty/cool_fox/actions/workflows/ci.yml/badge.svg)](https://github.com/DoubleGhosty/cool_fox/actions/workflows/ci.yml)
[![PortWatch VI](https://img.shields.io/badge/PortWatch%20VI-91.5%25%20Playable-brightgreen)](https://portwatch-vi.xyz/#effort-cgbj)

Active community continuation and development branch of `cool_fox` (the CGBJ runtime, ranked **#1 / 91.5% Playable** on PortWatch VI).

This build unites the cutting-edge optimizations from leading PortWatch projects (`avatarmanz`, `codec-d`, `DexNom`, `Belobug`, and community contributors) into a unified, verified runtime for both AMD Radeon and NVIDIA GeForce GPUs.

---

## Key Features & Improvements

- **Pareto Memory Residency & 32 GB RAM Support:** Adaptive GPU memory residency limits, preventing WDDM paging exhaustion (`0x8007000E`) on mid-range and 32 GB systems.
- **Shader LOD Slot Fix (PR #2):** Leaves unused LOD slots undefined in array texture coordinate queries, resolving DXIL validator errors on retail shaders.
- **NVIDIA & Video Stream Synchronization (PR #6):** Synchronous flush for decoded video frame copies, eliminating stutter and repeated frames in opening videos during multithreaded recording (`VICTORY_THIN=1`), and constant ambient lighting (`VICTORY_AMBIENT=constant:0.8`).
- **Wine / Proton & DXIL Robustness (PR #10):** Code-generated root signatures replacing fragile comment pragmas for vkd3d-shader, single-latch DXIL loop CFG normalization, and 256 MiB pipeline worker stack.
- **Voxel Visibility Recovery:** Restores wave64 mask provenance when restored from scalar copies, enabling foliage and volumetric voxel visibility shaders to pass compilation.
- **Custom Resolution & Scaling:** `VICTORY_OUTPUT=1920x1080` (or `2560x1440`) and `VICTORY_RENDER_SCALE=0.667..1.0` with the 4K backbuffer pool check bypass.
- **Frame Rate Unlock:** `VICTORY_FRAME_INTERVAL_MS=16.667` (60 FPS) or `8.333` (120 FPS) while keeping game simulation clock strictly at 1.00x.
- **Renderer Port 5 (Zero-Copy CBV):** `VICTORY_PORT_CBV=1` reads constant buffers as raw bytes in-place, eliminating ~22,000 buffer copies per frame.

---

## How to Run

You need Windows 10/11 x64, a CPU with AVX2, a Direct3D 12 GPU with shader model 6.6 and mesh shaders, the Rust toolchain pinned in `rust-toolchain.toml` (rustup installs it on the first build), the MSVC C++ build tools with a Windows SDK, and your own legal Xbox Series dump of the game.

### Build from Source

```powershell
git clone https://github.com/DoubleGhosty/cool_fox.git
cd cool_fox
cargo build --release --locked -p victory
```

### Launch

`VICTORY_GAME_DIR` is the folder of your dump that holds `game_scarlett_master.exe`. Keep it outside this checkout.

```powershell
$env:VICTORY_GAME_DIR = 'D:\Games\MyDump'
.\Play-VIctory.cmd
```

The launcher stops with a message if `game_scarlett_master.exe` is not in that folder. It runs `victory-3d-rtx-pareto-residency.exe` from an extracted Windows release when there is one, otherwise `target\release\victory.exe`, keeps its shader cache in `%LOCALAPPDATA%\VIctory\cache-pareto` (`VICTORY_CACHE_DIR` moves it) and starts the Series X profile. Every `VICTORY_...` variable set before it runs is kept, so one setting can be tried without editing the file:

```powershell
$env:VICTORY_THIN = '1'   # faster recording; on NVIDIA the faces of playable people go
.\Play-VIctory.cmd
```

On a card with 4-8 GB of memory, `Play-VIctory-4GB.cmd` is the same launcher with fewer title buffers copied to the card (4 MiB and up, at most 256 MiB of them) and the driver's background shader work off:

```powershell
.\Play-VIctory-4GB.cmd
```

If the card still runs out of memory, `$env:VICTORY_CONSOLE = 'series-s'` makes the title ask for less, at the price of people's heads in the world.

### Known issues

- With `series-s`, or `VICTORY_THIN=1` on NVIDIA, people's heads in the world draw only their eyes and teeth.
- `VICTORY_JOIN_PARTS=8` repeats frames of the opening video.
- Trees, plants and far buildings flicker outdoors in some places.
- Rooms with little direct light are dark without ray tracing (`scripts\play.ps1 -RayTracing`).
- Textures of what just came into view appear late while the title streams.
- The first run with a new driver or a new build stutters while the driver makes pipelines (`victory warm` makes them ahead).
- Recording a frame in the world makes the title's own watchdog end it.

### Diagnostics build

For measuring and debugging. `scripts\play.ps1` reads your paths from `victory.toml` and, without `-Safe`, turns `VICTORY_THIN` and `VICTORY_JOIN_PARTS` on.

```powershell
copy victory.example.toml victory.toml      # then set your paths, outside this folder
cargo build --locked --profile diag -p victory --features diagnostics
scripts\play.ps1 -Exe <your dump folder>\game_scarlett_master.exe
```

`scripts\play.ps1 -Safe` leaves out the newest, faster ways; try it first when
something is wrong. `-RayTracing` turns the title's ray-traced indirect light on.

Before the first run, ahead of time (both can be stopped and go on later):

```powershell
target\diag\victory.exe shaders <the shader archives>   # every shader translated, minutes
target\diag\victory.exe warm --used                     # pipelines earlier runs drew with, for a new driver or build
```

Commands, debugging switches and upstream's own description:
[docs/README-fxceless.md](docs/README-fxceless.md). Every `VICTORY_...` switch is
described in a comment where it is read.

## What is different here

In short; the reasons and the measurements are in [docs/findings.md](docs/findings.md).

- **List calls are written down, not carried out, on the title's threads**
  (`VICTORY_THIN`): eight threads of ours translate them.
- **Submissions are prepared by a thread of ours and joined**
  (`VICTORY_ASYNC_SUBMIT`, `VICTORY_JOIN_PARTS`), with what can be spread over
  threads spread: refreshes, compares (AVX2), descriptor records, landings.
- **What shaders wrote comes back beside the write guards**, by the dwords that
  changed, on a thread of its own (`VICTORY_RELAY`, `VICTORY_LAND`).
- **Buffer fills that need bytes still on the card are done on the card**
  (`VICTORY_CARD_STEPS`) instead of waiting for it.
- **The title's writes are caught more cheaply**: one view opened at a fault,
  blocks that rest, places in the title's code that look before they write.
- **Textures go up on a copy queue of their own** and a slot shows one only after
  its upload ran, which also ended a device loss that came every 15 minutes or so.
- **Boats float**: textures that shaders write and the title's CPU reads go back
  to title memory (from fxceless and Geckomacabre, on by default here).
- **Frame record and replay** with per-pass times and shader variants compared
  turn by turn ([docs/replay.md](docs/replay.md)).

## Upstream & Acknowledgements

- **codec-d / CGBJ:** Original `cool_fox` runtime and pareto residency architecture.
- **AvatarManz (VIctory-7900XTX):** Multi-threaded command list recording, framerate unlocking, and renderer ports.
- **DexNom:** Wave64 lowering, scalar recovery, and shader structure passes.
- **Belobug:** Ambient lighting and integer target blend protections.
- **Marvisak & fxceless:** Foundational VIctory compatibility layer.

**Legal notice:** This repository contains no copyrighted game code, assets, or executables. All code is licensed under GPL-3.0-or-later.

## Credits

This is a tree of other people's work with more on top. The history is kept, and
commits taken from elsewhere name the commit and its author.

- **[VIctory](https://github.com/Marvisak/VIctory)** by Marvisak and its
  contributors: the loader, the runtime services, the Direct3D 12 back end and
  the shader recompiler.
- **[fxceless/victory-fork](https://github.com/fxceless/victory-fork)**: the fork
  this one started from, and the people whose pull requests it carries.
- **[DexNom/VIctory](https://github.com/DexNom/VIctory)**: ray tracing fixes,
  cube gradients, sparse textures.
- **[Belobug/VIctory-Belobug-AMD](https://github.com/Belobug/VIctory-Belobug-AMD)**:
  the ambient light idea, pipeline workers, and work by romainhedouin.
- **[FQY55kai/ZJOU-VICTORY](https://github.com/FQY55kai/ZJOU-VICTORY)**.
- **[myokex/victory-amd](https://github.com/myokex/victory-amd)**: the guard over
  every view of a page (with Spexivus, joroyt and tightfall), and Joshua Odom's
  reads into title memory.
- **Geckomacabre** and **cxy0072019-sketch**: the texture read-back.
- **[XCL](https://github.com/ivall/xcl)** (GPL-2.0-only) was read for how the same
  title behaves under another layer; no code of it is here.
- This fork's changes were made with [Claude Code](https://claude.com/claude-code).

## License

GPL-3.0-or-later, as VIctory. See [LICENSE](LICENSE); the one file that is not
covered is named in [docs/asset-policy.md](docs/asset-policy.md).
