#!/bin/bash
# script for removing given, when, then:
grep -RIlZ --exclude-dir=.git --exclude-dir=bin --exclude-dir=obj --exclude-dir=.vs --exclude-dir=TestResults -e '\[Scope' -e '\[Binding' -e '\[Given' -e '\[When' -e '\[Then' . | xargs -0 sed -i '/\[Scope\|\[Binding\|\[Given\|\[When\|\[Then/d'
