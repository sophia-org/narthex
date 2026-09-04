#!/bin/sh
# Enforces the data/logic separation mandated by docs/data-oriented-design.md.
# Narthex inherits this discipline from Hagia, where the separation was declared
# once, eroded across twenty of twenty-six modules, and had to be rebuilt. This
# project starts compliant and stays that way.
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$root"

work=$(mktemp -d)
trap 'rm -rf -- "$work"' EXIT HUP INT TERM
violations=$work/violations
: >"$violations"

# A module outside src/types declares no public record. The only admitted
# exception is an error type, which belongs to the module that raises it.
# Adding a name here must be a deliberate act with a reason, not a way to make
# the gate quiet.
allowed_public_type() {
    case "$1" in
    *Error) return 0 ;;
    esac
    return 1
}

# A module in src/types declares data only, and is a leaf: it may import the
# standard library and its siblings, nothing else, so data can never depend on
# behavior.
for file in src/types/*.nim; do
    awk -v file="$file" '
        /^(proc|func|method|converter|iterator|template|macro) / {
            name = $2
            sub(/[*(\[].*$/, "", name)
            printf "%s:%d declares routine %s; a types module holds data only\n", \
                file, NR, name
        }
        /^import / {
            line = $0
            sub(/^import[ \t]+/, "", line)
            if (line ~ /^std\//) next
            if (line ~ /^\.\/[A-Za-z_[]/) next
            printf "%s:%d imports %s; a types module may import only std and its siblings\n", \
                file, NR, line
        }
    ' "$file" >>"$violations"
done

for file in $(find src -name '*.nim' -not -path 'src/types/*' | sort); do
    awk -v file="$file" '
        /^type[ \t]*$/ { section = 1; next }
        /^type[ \t]+[A-Z]/ {
            name = $2
            if (name ~ /\*/) { sub(/\*.*$/, "", name); printf "%s\t%d\t%s\n", file, NR, name }
            section = 0
            next
        }
        /^[^ \t]/ { section = 0 }
        section && /^  [A-Z][A-Za-z0-9_]*\*/ {
            name = $1
            sub(/\*.*$/, "", name)
            printf "%s\t%d\t%s\n", file, NR, name
        }
    ' "$file"
done >"$work/public-types"

while IFS="$(printf '\t')" read -r file line name; do
    [ -n "${name:-}" ] || continue
    if ! allowed_public_type "$file:$name" && ! allowed_public_type "$name"; then
        printf '%s:%d declares public record %s outside src/types\n' \
            "$file" "$line" "$name" >>"$violations"
    fi
done <"$work/public-types"

if [ -s "$violations" ]; then
    while IFS= read -r line; do
        echo "data-oriented layout violation: $line" >&2
    done <"$violations"
    echo "" >&2
    echo "Records are data. Move the declaration into src/types and leave the" >&2
    echo "procedures behind, or state the exception in tools/$(basename "$0")." >&2
    exit 1
fi

modules=$(find src/types -name '*.nim' | wc -l | tr -d ' ')
records=$(cat src/types/*.nim | grep -cE '^  [A-Za-z_][A-Za-z0-9_]*\*' || true)
printf '%s\n' \
    "narthex_data_oriented_layout types_modules=$modules public_records=$records data_logic_separation=enforced"
