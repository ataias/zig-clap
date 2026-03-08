#!/usr/bin/env fish
# Fish shell integration tests for completion generation.
# Usage: fish test_fish.sh <path-to-complete-demo-binary>
#
# This script:
# 1. Runs the binary with --generate-completion-script fish
# 2. Sources the generated script in fish
# 3. Uses `complete -C` to query completions and verify they are correct

set binary $argv[1]
if test -z "$binary"
    echo "Usage: fish test_fish.sh <binary>" >&2
    exit 1
end

set pass 0
set fail 0

function assert_contains
    set -l description $argv[1]
    set -l needle $argv[2]
    # remaining args are the haystack lines
    set -l haystack $argv[3..]

    for line in $haystack
        if string match -q -- "*$needle*" $line
            set pass (math $pass + 1)
            echo "  PASS: $description"
            return
        end
    end
    set fail (math $fail + 1)
    echo "  FAIL: $description — expected '$needle' in output:"
    for line in $haystack
        echo "    $line"
    end
end

function assert_not_contains
    set -l description $argv[1]
    set -l needle $argv[2]
    set -l haystack $argv[3..]

    for line in $haystack
        if string match -q -- "*$needle*" $line
            set fail (math $fail + 1)
            echo "  FAIL: $description — did NOT expect '$needle' but found it"
            return
        end
    end
    set pass (math $pass + 1)
    echo "  PASS: $description"
end

# Generate the completion script to a temp file and source it
set tmpfile (mktemp /tmp/fish-completion-test.XXXXXX.fish)
$binary --generate-completion-script fish > $tmpfile
if test $status -ne 0
    echo "FAIL: could not generate completion script" >&2
    rm -f $tmpfile
    exit 1
end

echo "Generated fish completion script:"
cat $tmpfile
echo "---"

source $tmpfile
rm -f $tmpfile

# Test 1: Root-level subcommand completions (no prefix)
echo "Test: root-level subcommand completions"
set root_completions (complete -C "complete-demo ")
assert_contains "subcommand 'up' listed" "up" $root_completions
assert_contains "subcommand 'exec' listed" "exec" $root_completions

# Test 2: Root-level flag completions (with - prefix, fish requires it)
echo "Test: root-level flag completions"
set root_flag_completions (complete -C "complete-demo -")
assert_contains "root flag --help listed" "--help" $root_flag_completions
assert_contains "root flag --verbose listed" "--verbose" $root_flag_completions

# Test 3: 'up' subcommand completions
echo "Test: 'up' subcommand completions"
set up_completions (complete -C "complete-demo up -")
assert_contains "up has --workspace-folder" "--workspace-folder" $up_completions
assert_not_contains "up does NOT have --remote-env" "--remote-env" $up_completions

# Test 4: 'exec' subcommand completions
echo "Test: 'exec' subcommand completions"
set exec_completions (complete -C "complete-demo exec -")
assert_contains "exec has --workspace-folder" "--workspace-folder" $exec_completions
assert_contains "exec has --remote-env" "--remote-env" $exec_completions

# Summary
echo ""
echo "Results: $pass passed, $fail failed"
if test $fail -gt 0
    exit 1
end
exit 0
