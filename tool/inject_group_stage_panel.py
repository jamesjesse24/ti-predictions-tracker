#!/usr/bin/env python3
"""Insert the group-stage status panel into lib/main.dart.

This helper is used once by the temporary branch workflow so the large existing
main.dart file can be changed deterministically without replacing unrelated UI.
"""

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MAIN = ROOT / "lib" / "main.dart"

IMPORT = "import 'group_stage_status_panel.dart';"
IMPORT_ANCHOR = "import 'background_worker.dart';"

PANEL_ANCHOR = """          _AccuracyPanel(
            percentage: percentage,
            settled: controller.settled,
            hits: controller.hits,
            misses: controller.misses,
            activeTeams: activeTeams,
          ),
          const SizedBox(height: 24),
          _SectionHeader(
"""

PANEL_REPLACEMENT = """          _AccuracyPanel(
            percentage: percentage,
            settled: controller.settled,
            hits: controller.hits,
            misses: controller.misses,
            activeTeams: activeTeams,
          ),
          const SizedBox(height: 24),
          GroupStageStatusPanel(controller: controller),
          const SizedBox(height: 24),
          _SectionHeader(
"""


def main() -> None:
    text = MAIN.read_text(encoding="utf-8")

    if IMPORT not in text:
        if IMPORT_ANCHOR not in text:
            raise SystemExit("Could not find main.dart import anchor")
        text = text.replace(
            IMPORT_ANCHOR,
            f"{IMPORT_ANCHOR}\n{IMPORT}",
            1,
        )

    if "GroupStageStatusPanel(controller: controller)" not in text:
        if PANEL_ANCHOR not in text:
            raise SystemExit("Could not find dashboard insertion anchor")
        text = text.replace(PANEL_ANCHOR, PANEL_REPLACEMENT, 1)

    MAIN.write_text(text, encoding="utf-8")
    print("Group-stage status panel inserted into lib/main.dart")


if __name__ == "__main__":
    main()
