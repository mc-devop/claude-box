#!/usr/bin/env bash
# The project's checks. Healthy output ends with ALL PASSED.
cd "$(dirname "$0")/.." || exit 1
status=0
echo "== Links"; python3 tests/check_links.py . || status=1
echo; if [ "$status" = 0 ]; then echo "ALL PASSED"; else echo "SOME FAILED"; fi
exit "$status"
