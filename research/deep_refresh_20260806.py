#!/usr/bin/env python3
from datetime import datetime, timezone
from pathlib import Path
import os
import deep_current

# Previous full-model cutoff: 5 August 2026, 6:24 AM Manila.
deep_current.START_TS = int(datetime(2026, 8, 4, 22, 24, tzinfo=timezone.utc).timestamp())
# Current requested cutoff: 6 August 2026, 12:27 AM Manila.
deep_current.END_TS = int(datetime(2026, 8, 5, 16, 27, tzinfo=timezone.utc).timestamp())
deep_current.OUT = Path(os.environ.get("DEEP_ANALYSIS_OUT", "research/deep-refresh-20260806-output"))
deep_current.main()
