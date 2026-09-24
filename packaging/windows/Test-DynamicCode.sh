#!/usr/bin/env bash
# Test trusted, locally generated code using the source checkout's native SDK.
set -eo pipefail
source "$(dirname "$0")/environment.sh"
case_dir=${1:-$WM_PROJECT_DIR/platforms/$WM_OPTIONS/code-stream-smoke}
mkdir -p "$case_dir"
cd "$case_dir"
cat > inputDict <<'EOF'
FoamFile { format ascii; class dictionary; object inputDict; }
value #codeStream
{
    code
    #{
        os << (40 + 2);
    #};
};
EOF
foamDictionary inputDict -expand > log.first 2>&1
grep -Eq 'value[[:space:]]+42;' log.first
find dynamicCode -name '*.dll' -print | grep -q .
foamDictionary inputDict -expand > log.cached 2>&1
grep -Eq 'value[[:space:]]+42;' log.cached
echo 'PASS: native codeStream compilation, DLL loading and cached reuse'
