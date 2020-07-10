#!/bin/bash
# vim: tw=0

( while true; do date; echo '{{{'; echo '{{{'; mega_upt.sh; echo '}}}'; echo '{{{'; mega_ps.sh; echo '}}}'; echo '{{{'; mega_top.sh; echo '}}}'; echo '}}}'; sleep 300s; done ) | tee $(date +%Y-%m-%d_%H:%M).log
