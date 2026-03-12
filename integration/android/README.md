# Android Host Smoke Pack

These files are source-owned host wrappers for generated Compose screens.

The test suite generates fresh `LoginScreen.kt` and `ProductDetailScreen.kt`
artifacts, distills their host-facing adapter surface, and runs `kotlinc`
against that distilled surface plus the wrappers in this folder. This proves the
generated `State`, `Actions`, and `Navigation` adapters can be consumed from
host-owned code without editing the generated sources.
