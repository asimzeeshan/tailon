#!/bin/sh
# tailon "errcode" mode: jump to a log entry from a time-based reference code.
#
# Some applications show users an opaque reference on their error page that is
# really the UTC epoch of the error in base36, optionally behind a prefix
# (APP-TJ77H9). This script decodes such a reference and prints the log entries
# written at that second, so support can go from a screenshot to the stack trace
# without hunting for a timestamp.
#
# Usage: errcode <logfile> <reference>
#
# Log entries are expected to start with a "YYYY/MM/DD HH:MM:SS" timestamp and
# may continue over several lines (stack traces). Set ERRCODE_TSFMT to a
# strftime format if your logs use another layout, e.g. "%Y-%m-%d %H:%M:%S".
# Works with busybox sh, date and awk.
file="$1"
ref="$2"
tsfmt="${ERRCODE_TSFMT:-%Y/%m/%d %H:%M:%S}"

code=$(printf '%s' "$ref" | tr -d ' \r\n' | tr 'a-z' 'A-Z')
code=${code##*-}
case "$code" in
    ''|*[!0-9A-Z]*)
        echo "errcode: paste a reference such as APP-TJ77H9 (got '$ref')"
        exit 1 ;;
esac

# base36 -> decimal using shell arithmetic only
digits=0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ
n=0
rest="$code"
while [ -n "$rest" ]; do
    c=${rest%"${rest#?}"}
    rest=${rest#?}
    idx=${digits%%"$c"*}
    n=$(( n * 36 + ${#idx} ))
done

# sanity: six characters decoding to 2020..2040, anything else is not a reference
if [ ${#code} -ne 6 ] || [ "$n" -lt 1577836800 ] || [ "$n" -gt 2208988800 ]; then
    echo "errcode: '$ref' is not a time-based reference (expected 6 characters after the prefix, e.g. APP-TJ77H9)"
    exit 1
fi

fmt() { date -u -d "@$1" +"$2"; }
minfmt=${tsfmt%:%S}
exact=$(fmt "$n" "$tsfmt")
minute=$(fmt "$n" "$minfmt")
before=$(fmt $(( n - 60 )) "$minfmt")
after=$(fmt $(( n + 60 )) "$minfmt")

echo "==> $ref = $exact UTC (epoch $n), file: $(basename "$file")"
echo

# print whole entries: the timestamp line plus continuation lines up to the next timestamp
entries() {
    awk -v pat="$1" '
        /^[0-9][0-9][0-9][0-9][\/-][0-9][0-9][\/-][0-9][0-9] / { p = (index($0, pat) == 1) }
        p { print }
    ' "$file"
}

out=$(entries "$exact")
if [ -n "$out" ]; then
    echo "==> entries at $exact:"
    echo "$out"
    exit 0
fi

echo "==> nothing at $exact, entries in $minute:"
out=$(entries "$minute")
if [ -n "$out" ]; then
    echo "$out"
    exit 0
fi

echo "(none)"
echo
echo "==> nothing in that minute either. Entries from $before to $after:"
for m in "$before" "$after"; do
    entries "$m"
done | sed -n '1,400p'
echo
echo "==> timestamps present in this file around then (nearest 20):"
hour=$(fmt "$n" "${minfmt%:%M}")
grep -o --text "^$hour:[0-9][0-9]:[0-9][0-9]" "$file" | uniq | tail -n 20
