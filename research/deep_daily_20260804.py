#!/usr/bin/env python3
from datetime import datetime, timezone
from pathlib import Path
import os
import deep_current

deep_current.START_TS = int(datetime(2026, 8, 3, 14, 50, tzinfo=timezone.utc).timestamp())
deep_current.END_TS = int(datetime(2026, 8, 4, 0, 30, tzinfo=timezone.utc).timestamp())
deep_current.OUT = Path(os.environ.get("DEEP_ANALYSIS_OUT", "research/deep-daily-output"))
deep_current.main()
