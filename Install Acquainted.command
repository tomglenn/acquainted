#!/bin/zsh
set -eu
ACQUAINTED_PROJECT_DIR="${0:A:h}"
print 'Installing Acquainted...'
python3 "$ACQUAINTED_PROJECT_DIR/install.py"
print '\nPress Return to close this window.'
read -r
