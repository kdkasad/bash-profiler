#!/usr/bin/env bash

#
# Profiles execution of shell scripts
#
# Copyright (C) 2025  Kian Kasad <kian@kasad.com>
#
# You are free to use, modify, and redistribute this script subject to the
# following conditions:
#   1. You preserve the above copyright notice.
#   2. You make any modifications or derivative works publicly available and free
#      of charge.
#   3. This script may not be used as the basis for any CS 252 assignments
#      without express written permission from the author.
#

# Check Bash version
if [ -z "$BASH_VERSINFO" ]
then
    echo 'Cannot detect Bash version. Are you running this with Bash?' >&2
    exit 1
fi
if [ "${BASH_VERSINFO[0]}" -lt 4 ] || [ "${BASH_VERSINFO[0]}" -eq 4 -a "${BASH_VERSINFO[1]}" -lt 1 ]
then
    echo 'Bash version 4.1 or greater is required for this script.' >&2
    echo "You appear to be running version $BASH_VERSION." >&2
    exit 1
fi

# Save script name
argv0="$0"

# Print top-level usage information
usage() {
    cat << EOF
Usage:
    $argv0 [-h]
    $argv0 profile [-h] [-f DATA_FILE] [--] <SCRIPT> [ARGS...]
    $argv0 analyze [-h] [-p] [DATA_FILE]

Subcommands:
    profile    Measure the execution of the given script.
    analyze    Analyze the raw data generated by the \`profile' subcommand.
EOF
}

# Print `profile' subcommand's usage information
usage_profile() {
    cat << EOF
Usage:
    $argv0 profile [-h] [-f DATA_FILE] [--] <SCRIPT> [ARGS...]

Description:
    Profiles the Bash script given by SCRIPT. If ARGS are provided, they are
    passed to the script.

Options:
    -h              Show this usage information.
    -f DATA_FILE    Output data to DATA_FILE. Defaults to \`profiler.log'.
EOF
}

# Print `analyze' subcommand's usage information
usage_analyze() {
    cat << EOF
Usage:
    $argv0 analyze [-h] [-p] [DATA_FILE]

Description:
    Analyzes the raw profile data produced by \`$argv0 profile'.
    Reads data from DATA_FILE, which defaults to \`profiler.log' if not set.

    Produces an output which looks similar to the raw data, but consists of
    lines in the following format.

    DURATION NEST COMMAND

    The columns are separated by spaces. DURATION is the time taken by the
    command in seconds, with microsecond precision. NEST is a sequence of
    repeated \`+' characters, indicating the level of nesting. This is the same
    as the nesting indicator printed by \`set -x'. COMMAND is the command run.

Options:
    -h    Show this usage information.
    -s    Sort the output by duration.
    -t    Format the output in a table using column(1).
EOF
}

# Profiler implementation
profile() {
    # Set default options
    local file=profiler.log

    # Parse arguments
    while getopts ":hf:" opt
    do
        case "$opt" in
            \?) echo "Unrecognized option: \`-$OPTARG'" >&2; exit 2 ;;
            :) echo "Missing argument for option \`-$OPTARG'" >&2; exit 2 ;;
            h) usage_profile; exit 0 ;;
            f) file="$OPTARG" ;;
        esac
    done
    shift $(( OPTIND - 1 ))

    # Print microsecond time in trace output
    export PS4='+ $EPOCHREALTIME '
    # Open a file descriptor for writing to $file and save it in $tracefd
    exec {tracefd}>"$file"
    # Send trace output to $tracefd
    BASH_XTRACEFD="$tracefd"
    # Enable tracing, source script, and disable tracing
    set -x
    source "$@"
    set +x
    # Un-redirect the trace output. This also closes the file descriptor.
    unset BASH_XTRACEFD

    # Remove "source" line from output and change last line to only include the
    # timestamp with no name.
    sed -i -e 1d -e '$s/\(+\+ [0-9\.]\+\) .*$/\1/' "$file"
}

analyze() {
    # Set defaults
    local file=profiler.log
    local -a sortcmd=(cat) tablecmd=(cat)

    # Parse options
    while getopts ":hst" opt
    do
        case "$opt" in
            \?) echo "Unrecognized option: \`-$OPTARG'" >&2; exit 2 ;;
            :) echo "Missing argument for option \`-$OPTARG'" >&2; exit 2 ;;
            h) usage_analyze; exit 0 ;;
            s) sortcmd=(sort -n) ;;
            t) tablecmd=(column -t -l 3 -N DURATION,NESTLVL,CMD -R DURATION) ;;
        esac
    done
    shift $(( OPTIND - 1 ))

    # Get file argument
    if [ $# -ge 1 ]
    then
        file="$1"
    fi

    # Declare variables
    local timestamp nestlvl cmd next_timestamp next_nestlvl next_cmd duration
    # Open file as a file descriptor so we can re-use the same stream
    exec {fd}<"$file";
    # Read first line
    read -r nestlvl timestamp cmd <&"$fd"
    # Process each line
    while read -r next_nestlvl next_timestamp next_cmd
    do
        duration="$(echo "scale=6; $next_timestamp" - "$timestamp" | bc)"
        # Prepend leading zero
        if [ "${duration:0:1}" = . ]
        then
            duration="0$duration"
        fi
        echo "$duration" "$nestlvl" "$cmd"

        timestamp="$next_timestamp"
        nestlvl="$next_nestlvl"
        cmd="$next_cmd"
    done <&"$fd" | "${sortcmd[@]}" | "${tablecmd[@]}"
    # Close file descriptor
    exec {fd}<&-
}

# Parse arguments
if [ $# -lt 1 ]
then
    usage >&2
    exit 2
fi
subcommand="$1"
shift
case "$subcommand" in
    -h)
        usage
        exit 0
        ;;
    profile | analyze)
        "$subcommand" "$@"
        ;;
    *)
        echo "Unrecognized subcommand: \`$subcommand'" >&2
        exit 2
        ;;
esac
