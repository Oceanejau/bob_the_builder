#!/bin/bash

set -e

SCRIPT="./bob_the_builder.sh"
TMP_DIR="./__tests_tmp"

pass() { echo "✅ $1"; }
fail() { echo "❌ $1"; exit 1; }

reset() {
  rm -rf "$TMP_DIR"
  mkdir -p "$TMP_DIR"
}

file_exists() { [ -f "$1" ] || fail "Missing file: $1"; }
dir_exists() { [ -d "$1" ] || fail "Missing dir: $1"; }
file_empty() { [ ! -s "$1" ] || fail "File not empty: $1"; }
file_contains() {
  grep -q "$2" "$1" || fail "File $1 does not contain $2"
}

echo "🧪 Running tests..."

# --- Test 1
reset
cat > $TMP_DIR/archi.txt <<EOF
src
  index.js
EOF

$SCRIPT $TMP_DIR/archi.txt $TMP_DIR/out --y
dir_exists "$TMP_DIR/out/src"
file_exists "$TMP_DIR/out/src/index.js"
pass "basic structure"

# --- Test 2
reset
cat > $TMP_DIR/archi.txt <<EOF
backend
  app.js
frontend
  index.html
EOF

$SCRIPT $TMP_DIR/archi.txt $TMP_DIR/out --y
dir_exists "$TMP_DIR/out/backend"
dir_exists "$TMP_DIR/out/frontend"
pass "multi-root"

# --- Test 3
reset
mkdir -p $TMP_DIR/out/src
echo "hello" > $TMP_DIR/out/src/index.js

cat > $TMP_DIR/archi.txt <<EOF
src
  index.js
EOF

$SCRIPT $TMP_DIR/archi.txt $TMP_DIR/out --force --y
file_empty "$TMP_DIR/out/src/index.js"
pass "overwrite"

# --- Test 4 (FIXED)
reset
mkdir -p $TMP_DIR/out/src
echo "hello" > $TMP_DIR/out/src/index.js

cat > $TMP_DIR/archi.txt <<EOF
src
  index.js
EOF

$SCRIPT $TMP_DIR/archi.txt $TMP_DIR/out --force --keep-backup

BACKUP=$(find $TMP_DIR/out -type d -name ".backup_*")

[ -n "$BACKUP" ] || fail "backup folder missing"
[ -f "$BACKUP/src/index.js" ] || fail "backup missing structure"

pass "backup structure"

# --- Test 5
reset
cat > $TMP_DIR/archi.txt <<EOF
src
  index.js
EOF

$SCRIPT $TMP_DIR/archi.txt $TMP_DIR/out --dry-run
[ ! -d "$TMP_DIR/out/src" ] || fail "dry-run created files"
pass "dry-run"

# --- Test 6
reset
cat > $TMP_DIR/archi.txt <<EOF
src
  index.js
EOF

OUTPUT=$($SCRIPT $TMP_DIR/archi.txt $TMP_DIR/out --preview)

echo "$OUTPUT" | grep "📁 src" >/dev/null || fail "preview missing dir"
echo "$OUTPUT" | grep "📄 index.js" >/dev/null || fail "preview missing file"

pass "preview"

# --- Test 7
if $SCRIPT fake.txt 2>/dev/null; then
  fail "should fail on missing file"
else
  pass "missing file"
fi

# --- Test A1: empty file
reset
touch $TMP_DIR/empty.txt

if $SCRIPT $TMP_DIR/empty.txt $TMP_DIR/out --y; then
  fail "empty file should not succeed"
else
  pass "empty file"
fi

# --- Test A2: no args
if $SCRIPT 2>/dev/null; then
  fail "no args should fail"
else
  pass "no args"
fi

# --- Test A3: unreadable file
reset
echo "src" > $TMP_DIR/archi.txt
chmod 000 $TMP_DIR/archi.txt

if $SCRIPT $TMP_DIR/archi.txt $TMP_DIR/out 2>/dev/null; then
  chmod 644 $TMP_DIR/archi.txt
  fail "unreadable file should fail"
else
  chmod 644 $TMP_DIR/archi.txt
  pass "unreadable file"
fi

# --- Test A4: existing dest
reset
mkdir -p $TMP_DIR/out

cat > $TMP_DIR/archi.txt <<EOF
src
EOF

$SCRIPT $TMP_DIR/archi.txt $TMP_DIR/out --y
dir_exists "$TMP_DIR/out/src"
pass "dest exists"

# --- Test A5: dest does not exist
reset
cat > $TMP_DIR/archi.txt <<EOF
src
EOF

$SCRIPT $TMP_DIR/archi.txt $TMP_DIR/newout --y
dir_exists "$TMP_DIR/newout/src"
pass "dest not exists"

# --- Test B1: bad indentation (1 space)
reset
cat > $TMP_DIR/archi.txt <<EOF
src
 index.js
EOF

if $SCRIPT $TMP_DIR/archi.txt $TMP_DIR/out --y 2>/dev/null; then
  fail "should fail on bad indentation"
else
  pass "bad indentation rejected"
fi

# --- Test B2: tabs
reset
printf "src\n\tindex.js\n" > $TMP_DIR/archi.txt

$SCRIPT $TMP_DIR/archi.txt $TMP_DIR/out --y
file_exists "$TMP_DIR/out/src/index.js"
pass "tabs"

# --- Test B3: trailing slash
reset
cat > $TMP_DIR/archi.txt <<EOF
src/
  index.js
EOF

$SCRIPT $TMP_DIR/archi.txt $TMP_DIR/out --y
dir_exists "$TMP_DIR/out/src"
pass "trailing slash"

# --- Test B4: dot file
reset
cat > $TMP_DIR/archi.txt <<EOF
.env
EOF

$SCRIPT $TMP_DIR/archi.txt $TMP_DIR/out --y
file_exists "$TMP_DIR/out/.env"
pass "dotfile"

# --- Test B5: root == basepath
reset
mkdir -p $TMP_DIR/app
cat > $TMP_DIR/archi.txt <<EOF
app
  index.js
EOF

$SCRIPT $TMP_DIR/archi.txt $TMP_DIR/app --y
file_exists "$TMP_DIR/app/index.js"
pass "root equals basepath"

# --- Test B6: lenient mode
reset
cat > $TMP_DIR/archi.txt <<EOF
src
 index.js
   deep.js
EOF

$SCRIPT $TMP_DIR/archi.txt $TMP_DIR/out --lenient --y

file_exists "$TMP_DIR/out/src/index.js"
file_exists "$TMP_DIR/out/src/deep.js"
pass "lenient mode"

# --- Test B7: lenient weird indent (real case)
reset
cat > $TMP_DIR/archi.txt <<EOF
src
 index.js
   deep.js
EOF

$SCRIPT $TMP_DIR/archi.txt $TMP_DIR/out --lenient --y

file_exists "$TMP_DIR/out/src/index.js"
file_exists "$TMP_DIR/out/src/deep.js"
pass "lenient weird indent"

# --- Test C1: nested creation
reset
cat > $TMP_DIR/archi.txt <<EOF
a
  b
    c
      file.txt
EOF

$SCRIPT $TMP_DIR/archi.txt $TMP_DIR/out --y
file_exists "$TMP_DIR/out/a/b/c/file.txt"
pass "nested creation"

# --- Test C2: skip existing
reset
mkdir -p $TMP_DIR/out/src
echo "hello" > $TMP_DIR/out/src/index.js

cat > $TMP_DIR/archi.txt <<EOF
src
  index.js
EOF

printf "k" | $SCRIPT $TMP_DIR/archi.txt $TMP_DIR/out --y
file_empty "$TMP_DIR/out/src/index.js"
pass "skip existing"

# --- Test D1: quiet
reset
cat > $TMP_DIR/archi.txt <<EOF
src
EOF

OUTPUT=$($SCRIPT $TMP_DIR/archi.txt $TMP_DIR/out --quiet --y)

echo "$OUTPUT" | grep -q "." && fail "quiet not working"
pass "quiet"

# --- Test D2: no-backup
reset
mkdir -p $TMP_DIR/out/src
echo "hello" > $TMP_DIR/out/src/index.js

cat > $TMP_DIR/archi.txt <<EOF
src
  index.js
EOF

$SCRIPT $TMP_DIR/archi.txt $TMP_DIR/out --force --no-backup
BACKUP=$(find $TMP_DIR/out -type d -name ".backup_*")

[ -z "$BACKUP" ] || fail "backup should not exist"
pass "no-backup"

# --- Test E1: spaces in path
reset
cat > "$TMP_DIR/archi.txt" <<EOF
src
  file.txt
EOF

$SCRIPT "$TMP_DIR/archi.txt" "$TMP_DIR/my folder" --y
file_exists "$TMP_DIR/my folder/src/file.txt"
pass "spaces in path"

# --- Test E2: weird names
reset
cat > $TMP_DIR/archi.txt <<EOF
...
  .env
EOF

$SCRIPT $TMP_DIR/archi.txt $TMP_DIR/out --y
file_exists "$TMP_DIR/out/.../.env"
pass "weird names"



echo ""
echo "🎉 ALL TESTS PASSED"
