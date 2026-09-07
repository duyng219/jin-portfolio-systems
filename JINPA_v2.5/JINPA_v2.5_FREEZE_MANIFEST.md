# JINPA v2.5 Freeze Manifest

## Freeze identity

- Status: **LIVE CANDIDATE — RE-FROZEN AFTER STAGE 2.10**
- Original release date: `2026-09-06`
- Stage 2.10 re-freeze date: `2026-09-08`
- Git branch before re-freeze commit: `main`
- Git HEAD before re-freeze commit: `c8eaacaacb9008eb06f1d8d4f813c81b394e9091`
- Initial-freeze pre-commit HEAD: `68995681a6fd627efa82a76fc1caad61a4881404`
- Main source: `JINPA_v2.5.mq5`
- Property version: `2.50`
- Visible panel title: `JINPA v2.5`
- Panel top: `Y = 40`
- Push identity: `JINPA WATCH`

## Frozen fingerprints

- Production-source fingerprint: `55f237018910755e080eed0806d52317fb1617d87927a86541e90271453ae120`
- EX5 SHA-256: `1530f97a45deec2b4fb8ac6455958e56a3c908d1e8a8b51603f615b1e69a2996`
- EX5 size: `348248` bytes
- JINPA_DEV protected main-source SHA-256: `8372781b14a43534ba9e741f5c454e95eacafe33afab1f04ad0b6738da57b71c`
- JINPA_v2.4 protected main-source SHA-256: `24b4e8ce39f64f50898fd016dfd9270f13ea7ff3c27549c1c1bfac029d49de2d`

The production-source fingerprint is the frozen `JINPA_v2.5.mq5` hash. Include-level behavior is additionally governed by the frozen component manifest; Stage 2.10 intentionally changed only the Structure Engine component. Documentation does not redefine either source baseline.

## Frozen component hash manifest

| Component | SHA-256 |
|---|---|
| `_core/infrastructure/magic_number_resolver.mqh` | `6a2fd752d04f168978bd5652c66d523a46f9e2d960b1502559da292dfc5517a9` |
| `watch/structure/PriceStructureEngine.mqh` | `147db186259ee045ba559aeea28ae19307a71d0f796cc9a402b7175a2cc36be2` |
| `watch/structure/StructureTypes.mqh` | `b65d563f56bf6b833ec5585b5b04b7a8ef6b72093ea1317dbbdf4df2c88f3dc7` |
| `watch/core/WatcherTypes.mqh` | `baf71d4ec52a10fb5fd358eba3dc21d6930e39de82ca8f3edea4c3b168868d5d` |
| `watch/core/WatcherLogger.mqh` | `e4e706cfe1d2d91ac88ddbb624579dd527ec8384d31a1b50c362ef07ed8fe2d1` |
| `watch/structure/StructureDebugRenderer.mqh` | `3d0d275b8e400421dec61a4d9749aea49709b04fc2b5fb31d46037df3074bdfa` |
| `watch/structure/StructureNotificationManager.mqh` | `46426bd12ec2660e554a0626965f1c32bb7edbf35d97ffd584cbedd904c6b51c` |
| `JINPA_v2.5.mq5` | `55f237018910755e080eed0806d52317fb1617d87927a86541e90271453ae120` |
| `_panel/panel_main.mqh` | `8197c59752a73aa91784addb01da454665d5a078e68582adac17d95ac613984c` |
| `_core/managers/position_manager.mqh` | `f91b2417ed75fd13572aa17871af9cdd9091d8c02321b0a853b01f8dbb965342` |
| `_core/managers/risk_manager.mqh` | `c50f97775a7def00e7c6f5efdd267bbea480c4f8a58a04249ed5eaf55daa4411` |
| `_core/managers/drawdown_manager.mqh` | `9f9ae6786a88088a7a3fa6f8127f360b64b7cd14ee9ac0c934792ffb68eb93d7` |

## Active architecture

```text
JINPA_v2.5.mq5
├── CJINPAPanel
├── IndicatorsManager
├── BarManager
├── RiskManager
├── DrawdownManager
├── PositionManager
│   └── PositionHelper
├── InfoDisplay
├── MagicNumberResolver
├── Market / STOP / LIMIT execution
├── Cancel / Close
├── ATR TSL
├── EXIT lifecycle
└── WatchIntegration
    ├── PriceStructureEngine
    │   ├── StructureTypes
    │   ├── WatcherTypes
    │   └── WatcherLogger
    ├── StructureDebugRenderer
    └── StructureNotificationManager
```

Absent from the active compile graph: MarketRadar, `CMarketRadar`, `JINPA_RADAR_`, DEV `CUIManager`, DEV `COrderExecutor`, SymbolScanner, SymbolsList, multi-symbol orchestration, `OnTimer`, heartbeat, Stage 3 Regime/Phase, Setup Engine, and Signal Engine. Dormant legacy helpers on disk are not active production dependencies.

## Validated milestones

- M1 — Production baseline
- M2 — Auto Magic and logging
- M3 — Execution and pending-order fixes
- M4 — EXIT lifecycle
- M5 — Structure Engine
- M6 — Structure Renderer
- M7 — Notification and Push
- M8 — Full integration and regression
- M9-A/A1/A2 — Live lifecycle and UI acceptance
- M9-B — Demo execution PASS
- M9-C — TSL and EXIT PASS with untested partial close/`OUT_BY`
- M9-D — Push, Daily DD, and live-candidate validation PASS with known limitations
- Stage 2.10 — Break-Origin Core reassignment PASS; re-frozen

## Stage 2.10 corrected Structure baseline

The pre-Stage-2.10 141/142-event baselines remain historical evidence and are not authoritative for corrected Core reassignment semantics.

Targeted deterministic golden baseline per codebase:

| Event | Count |
|---|---:|
| SWING | 2 |
| CORE_BREAK_CANDIDATE | 1 |
| CYCLE_CHANGED | 1 |
| CORE_SWING_INITIALIZED | 1 |
| Duplicates | 0 |

Canonical first divergence: old New Core High `LH(2) @ 110`; corrected New Core High `HH(4) @ 120`. Symmetric LL, legacy LH/HL, false-break retention, multiple-origin replacement, SwingType preservation, bootstrap/sequential parity, and DEV/v2.5 parity all passed.

## Runtime validation boundary

- Six of six entry paths, cancel/close both sides, Magic, comments, risk sizing, and LIMIT fixes: runtime verified.
- BUY/SELL TSL, natural/trailing SL EXIT, and manual EXIT: runtime verified.
- Structure Engine and renderer: runtime verified.
- Real phone Push and zero true duplicate Push: runtime verified.
- Daily DD OFF/ON, entry halt, safe Close, and Structure/Renderer independence: runtime verified.
- DD/Notification and DD/TSL control-flow independence: static verified, with prior subsystem runtime evidence.
- Daily rollover: harness verified.
- Final account inventory after M9-D: clean.

## Protected states

- `JINPA_v2.4`: previous stable production reference; unchanged.
- `JINPA_DEV`: development/R&D line; Stage 2.10 Engine patch matches v2.5 byte-for-byte.
- Existing user-owned DEV deletions remain untouched.

## Known limitations

1. Partial close runtime is not tested.
2. `OUT_BY` runtime is not tested.
3. Notification queue dispatches at most one item per new bar.
4. Notification dedup is session-local.
5. Push has no retry.
6. Push queue is not persistent.
7. Renderer retains historical chart objects.
8. Renderer has no pruning.
9. Object count grows with chart history.
10. Strategy Tester Journal may buffer output until pause, stop, or completion.
11. Unknown-symbol fallback Magic `109999` may collide across unsupported symbols.
12. Pending-margin behavior may vary by broker, symbol, and account.
13. Applying templates while the EA is attached may leave stale Trade Log `LogRow` objects.
14. Daily DD state is memory/session based and resets through its daily lifecycle.
15. DD scaling at 2–3% is source-verified; runtime triggering used a lower safe threshold.
16. Live production beyond Exness Demo remains the user's operational responsibility.

## M9-E documentation additions

- `JINPA_v2.5_RELEASE.md`
- `JINPA_v2.5_FREEZE_MANIFEST.md`

**NO PRODUCTION BEHAVIOR SOURCE CHANGED DURING M9-E.**

No file was staged, committed, pushed, or tagged by M9-E.

## Current re-freeze boundary

Stage 2.10 changes only `watch/structure/PriceStructureEngine.mqh` plus release bookkeeping. Rollback reference remains `JINPA_v2.4`. The next development milestone is Stage 2.11 in `JINPA_DEV`; Stage 3 has not started.
