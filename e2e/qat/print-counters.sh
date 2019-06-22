#!/bin/bash
# Script to print QAT fw_counters.
cd /
FILES=$(find . -name fw_counters | grep debug/qat)
cat $FILES
