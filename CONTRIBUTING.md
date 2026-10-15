# Contributing

Thanks for helping make follow-ups dependable. Start with an issue describing a concrete workflow and the expected behavior. Keep changes focused. New connectors need a provider permission/distribution review, synthetic fixtures, connection-health handling and a documented disconnect flow.

## Development

The deployment target is macOS 14+, but building needs Swift 6+ and the macOS 26 SDK (Xcode 26+ or matching Command Line Tools). `./scripts/test.sh` runs the Swift Testing suite. `./scripts/build-app.sh` creates `dist/Holdlet.app`. Open the package in Xcode for debugging if installed. Use `--demo --show` to inspect sample data without credentials; demo fixtures cannot schedule real alerts.

Tests should verify behavior, especially cancellation, rescheduling, clock boundaries, disconnected sources, privacy and failure recovery. Do not add assertions that merely mirror a trivial getter. Run the complete suite after a behavior change and build the `.app` before submitting UI changes.

## Pull requests

Explain the trigger/problem, resulting behavior, validation, and remaining limits. Include synthetic screenshots for UI changes. Never attach real inboxes, message bodies, auth codes, API responses with personal data, credentials or local state files. All contributions use Apache-2.0. Keep third-party license notices if adding dependencies.

## Design

Use native system type and symbols, neutral translucent modules, round controls and clear hierarchy. Honor privacy and accessibility settings. Avoid hidden network services, unsolicited AI calls and additional permission prompts without a concrete user-facing need.
