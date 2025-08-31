#!/usr/bin/env bash
echo "Script starting..." >&2
echo "Arg1: '$1'" >&2

get_cli_for_role() {
  echo "In function with arg: '$1'" >&2
  case "$1" in
    "Director") echo "cat" ;;
    *) echo "unknown" ;;
  esac
}

result=$(get_cli_for_role "Director")
echo "Result: '$result'" >&2
