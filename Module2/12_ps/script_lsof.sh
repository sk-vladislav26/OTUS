#!/bin/bash
for p in /proc/[0-9]*; do
  c=$(cat $p/comm 2>/dev/null) || continue
  for f in $p/fd/*; do
    echo "${p#/proc/} $c $(readlink $f 2>/dev/null)"
  done
done
