# JINPA Changelog

## v3.0 LIVE — Corrective Stage 2 release

- Built from the frozen v2.5 production base.
- Preserves the v2.5 LIVE panel, trade-comment workflow, execution, risk, Magic, Daily DD and CSV schema.
- Transplants the validated Stage 2 Structure, renderer semantics and seven notification groups from v3.1 DEV.
- Status: frozen production; Stage 3 development is prohibited in this tree.
- Known limitations: generation ordinals are session/history-relative; notification dedup is session-local with no persistence or retry; renderer object pruning is deferred.

## v2.4

- Tach rieng `ATRFactorSL` va `ATRFactorTSL`.
- Giu cau hinh hien tai: `ATRFactorSL = 2.5`, `ATRFactorTSL = 3.5`, `TSLStepATR = 2.5` va `TSLMode = TSL_STEP`.
- Nang metadata, panel title va ten file export CSV len JINPA v2.4.
