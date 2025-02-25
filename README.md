# Bash profiler

A Bash script to profile Bash scripts.

<div align=center>
<a href="https://asciinema.org/a/Y85qgYo76n6MskQaCS51iBopI" target="_blank"><img src="https://asciinema.org/a/Y85qgYo76n6MskQaCS51iBopI.svg" /></a>
</div>

# Features

- [x] Get timings of shell script execution with per-command
      granularity.
- [ ] Provide more useful data analysis, e.g.:
  - [ ] Aggregate data from commands matching certain patterns.
  - [ ] Include source file and line number of commands run.
  - [ ] Aggregate data per source line rather than per command.

# Installation

Nice and easy:
```
$ git clone https://github.com/kdkasad/bash-profiler.git
$ cd bash-profiler
```

# Usage

The profiler is split into two phases:
measurement (profiling) and interpretation of the measurement data
(analysis).

## 1. Profiling

Use the `profile` subcommand to profile the execution of a script:
```
$ ./profiler.sh profile [-h] [-f DATA_FILE] [--] <SCRIPT> [ARGS...]
```
This will outptut timing data to the file named by `DATA_FILE`, or to
`profiler.log` if no filename is set. This data can be used directly
(see [Raw data format](#raw-data-format)), but you likely want to
perform analysis on the data next.

## 2. Analysis

This step will turn the raw data into the execution duration for each
command. Run the analyzer with the `analyze` subcommand:
```
$ ./profiler.sh analyze [-h] [-s] [-t] [DATA_FILE]
```
If no `DATA_FILE` is given, `profiler.log` is used. The data is read
from the file and output in the following space-separated format:
```txt
DURATION NESTLVL COMMAND
```
- `DURATION` is the duration, in seconds, of the command, with
  microsecond precision.
- `NESTLVL` is a sequence of plus (`+`) characters representing the
  level of nesting of the given command. This is the same output you
  might expect from the `-x` shell option.
- `COMMAND` is the command run.

### Options
- `-s`: Sorts the output in non-decreasing order by command duration.
- `-t`: Aligns the output columns in a table. Requires the GNU
  `column(1)` program. This option should only be used for displaying
  the data for humans and should not be used to produce parseable
  output.

### Sample output
```txt
0.000056 ++ rss_readable=0
0.000434 ++ cpu_seconds=0
0.000089 +++ format_time 0
0.000037 +++ local -i h m s=0
0.000013 +++ ((  h=s/3600  ))
0.000009 +++ ((  m=(s%3600)/60  ))
0.000011 +++ ((  s%=60  ))
```

# Raw data format
The raw data format produced by the `profile` subcommand is very
similar to that produced by the `analyze` subcommand. It consists of
the following space-separated columns:
```
NESTLVL TIMESTAMP COMMAND
```
Here, `NESTLVL` and `COMMAND` the same as described earlier.
`TIMESTAMP` is the time at which the command was executed by the
shell, as a value in seconds since the UNIX epoch with microsecond
precision.

The last line of the raw data will have no command column. It
represents the time at which execution returned from the script being
profiled to the profiler. This can be used to determine the execution
duration of the last command in the script.
