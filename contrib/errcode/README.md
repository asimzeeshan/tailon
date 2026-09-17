# search and errcode modes

Two extra modes for the mode dropdown, added purely through the config file. No change
to the tailon binary is needed.

| mode | what it does |
|---|---|
| `search` | greps the whole file instead of the last N lines, ignores case, prints line numbers, then keeps following |
| `errcode` | takes a reference code that encodes the UTC epoch of an error in base36 (for example `APP-TJ77H9`) and prints the log entries written at that second, stack trace lines included. Falls back to the surrounding minute, then the minutes either side, then lists the nearest timestamps in the file |

## Why `search` exists

The stock `grep` mode is `tail -n N -F file | grep`, so it only ever sees the last N
lines. Looking for something from yesterday returns nothing unless N is raised first.
`search` chains grep behind `tail -n +1 -F` instead.

## Install

1. Put `errcode.sh` where the tailon process can execute it as `/usr/local/bin/errcode`.
   With Docker, mount it read-only:

   ```yaml
   volumes:
     - ./tailon.toml:/tailon.toml:ro
     - ./errcode.sh:/usr/local/bin/errcode:ro
   ```

2. Use `tailon.toml` from this directory (adjust `relative-root`) and start tailon with
   `-c /tailon.toml` followed by your filespecs.

Both files are single-file bind mounts in that setup, so recreate the container after
editing either one (`docker compose up -d --force-recreate tailon`).

## Notes

- `errcode.sh` needs only `sh`, `date`, `awk`, `grep` and `sed`; busybox versions are fine.
  busybox `date` wants `-d @epoch`.
- The grep actions use GNU long options. busybox 1.37 no longer accepts them, so on Alpine
  install GNU grep (`apk add grep`). Without `--line-buffered` live output stalls.
- The search box reaches the script as one argument and is only ever treated as data.
- Timestamps are read as UTC. Set `ERRCODE_TSFMT` if your log lines do not start with
  `YYYY/MM/DD HH:MM:SS`.
