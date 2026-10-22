#!/usr/bin/env bash
# Shared helpers for this feature's API tests. Sourced first by every script.
export BASE_URL="${BASE_URL:-http://app:6713}"
export DATABASE_URL="${DATABASE_URL:-postgresql://app:app@toxiproxy:5432/appdb}"

# --- CodeValid diagnosis markers (parsed by the test runner; do not edit) ---
# cv_step  <Given|When|Then|Cleanup> "<what this section does>" $LINENO
# cv_prereq "<setup being done>" $LINENO
# cv_http  <METHOD> <url|/path> [json-body] [expected-status] [extra curl args, e.g. -H "Authorization: Bearer $T"]
#          performs the request (relative paths go to $BASE_URL), prints REQUEST_*/RESPONSE_*
#          and CV_HTTP|METHOD|url|status|ms, sets CV_HTTP_STATUS CV_HTTP_BODY CV_HTTP_MS
#          CV_HTTP_BODY_FILE CV_HTTP_HEADERS_FILE. Call it directly, never inside $(...).
#          A 3-digit expected-status (with or without a body) is asserted: a different status
#          fails the test via cv_fail. Omit it to assert on $CV_HTTP_STATUS yourself.
# cv_http  <METHOD> <url> <http_status>          (legacy: marker only, right after your own curl)
# cv_fail  "<expected X got Y>" $LINENO           (prints marker, exits 1)
cv_step() { printf 'CV_STEP|%s|%s|line=%s\n' "${1:-}" "${2:-}" "${3:-}"; }
cv_prereq() { printf 'CV_PREREQ|%s|line=%s\n' "${1:-}" "${2:-}"; }
cv_fail() { printf 'CV_ASSERT_FAIL|%s|line=%s\n' "${1:-}" "${2:-}"; exit 1; }
_cv_is_int() { case "${1:-}" in ''|*[!0-9]*) return 1 ;; *) return 0 ;; esac; }
_cv_now_ms() {
  _cv_n=${EPOCHREALTIME:-}
  if [ -n "$_cv_n" ]; then _cv_secs_to_ms "$_cv_n"; return 0; fi
  _cv_n=$(date +%s%3N 2>/dev/null || true)
  _cv_is_int "$_cv_n" || _cv_n=$(( $(date +%s) * 1000 ))
  printf '%s' "$_cv_n"
}
_cv_ms_file() { printf '%s/.cv_last_ms.%s' "${TMPDIR:-/tmp}" "$$"; }
curl() {
  _cv_t0=$(_cv_now_ms)
  _cv_rc=0
  command curl "$@" || _cv_rc=$?
  _cv_t1=$(_cv_now_ms)
  printf '%s' "$((_cv_t1 - _cv_t0))" > "$(_cv_ms_file)" 2>/dev/null || :
  return $_cv_rc
}
# psql without a connection falls back to a local socket seed-test does not have; when
# DATABASE_URL is set and the call names no connection, connect through it.
psql() {
  if [ -n "${DATABASE_URL:-}" ]; then
    case " $* " in
      *" $DATABASE_URL "*|*" -h "*|*" --host"*|*" -d "*|*" --dbname"*|*"postgres://"*|*"postgresql://"*) ;;
      *) command psql "$DATABASE_URL" "$@"; return $? ;;
    esac
  fi
  command psql "$@"
}
_cv_secs_to_ms() {
  _cv_t=$(printf '%s' "${1:-0}" | tr ',' '.')
  _cv_s=${_cv_t%%.*}
  case "$_cv_t" in *.*) _cv_f=${_cv_t#*.}000 ;; *) _cv_f=000 ;; esac
  _cv_f=${_cv_f%"${_cv_f#???}"}
  while [ "${_cv_f#0}" != "$_cv_f" ]; do _cv_f=${_cv_f#0}; done
  _cv_is_int "$_cv_s" || _cv_s=0
  _cv_is_int "$_cv_f" || _cv_f=0
  printf '%s' "$(( _cv_s * 1000 + _cv_f ))"
}
_cv_is_status() { _cv_is_int "${1:-}" && [ ${#1} -eq 3 ]; }
cv_http() {
  if [ $# -ge 3 ] && [ $# -le 4 ] && _cv_is_status "$3" && { [ $# -eq 3 ] || _cv_is_int "$4"; }      && { [ -n "${4:-}" ] || [ -f "$(_cv_ms_file)" ]; }; then
    _cv_ms=${4:-}
    if [ -z "$_cv_ms" ] && [ -f "$(_cv_ms_file)" ]; then
      _cv_ms=$(cat "$(_cv_ms_file)" 2>/dev/null || true)
      rm -f "$(_cv_ms_file)" 2>/dev/null || :
    fi
    _cv_is_int "$_cv_ms" || _cv_ms=''
    printf 'CV_HTTP|%s|%s|%s%s\n' "$1" "$2" "$3" "${_cv_ms:+|$_cv_ms}"
    return 0
  fi
  _cv_method=${1:-GET}
  _cv_url=${2:-/}
  _cv_data=''
  _cv_expect=''
  if [ $# -ge 2 ]; then shift 2; else shift $#; fi
  if [ $# -ge 1 ] && ! _cv_is_status "$1"; then
    case "$1" in -*) ;; *) _cv_data=$1; shift ;; esac
  fi
  if [ $# -ge 1 ] && _cv_is_status "$1"; then _cv_expect=$1; shift; fi
  case "$_cv_url" in /*) _cv_url="${BASE_URL:-http://app:6713}$_cv_url" ;; esac
  CV_HTTP_BODY_FILE="${TMPDIR:-/tmp}/cv_http_body.$$"
  CV_HTTP_HEADERS_FILE="${TMPDIR:-/tmp}/cv_http_headers.$$"
  : > "$CV_HTTP_BODY_FILE"; : > "$CV_HTTP_HEADERS_FILE"
  printf 'REQUEST_HEADERS:\n%s %s\n' "$_cv_method" "$_cv_url"
  printf 'REQUEST_BODY:\n%s\n' "$_cv_data"
  if [ -n "$_cv_data" ]; then
    _cv_w=$(command curl -sS -X "$_cv_method" -H 'Content-Type: application/json' --data "$_cv_data" \
      -D "$CV_HTTP_HEADERS_FILE" -o "$CV_HTTP_BODY_FILE" -w '%{http_code} %{time_total}' "$@" "$_cv_url") || true
  else
    _cv_w=$(command curl -sS -X "$_cv_method" \
      -D "$CV_HTTP_HEADERS_FILE" -o "$CV_HTTP_BODY_FILE" -w '%{http_code} %{time_total}' "$@" "$_cv_url") || true
  fi
  CV_HTTP_STATUS=${_cv_w%% *}
  _cv_is_int "$CV_HTTP_STATUS" || CV_HTTP_STATUS=000
  case "$_cv_w" in *' '*) CV_HTTP_MS=$(_cv_secs_to_ms "${_cv_w#* }") ;; *) CV_HTTP_MS=0 ;; esac
  CV_HTTP_BODY=$(cat "$CV_HTTP_BODY_FILE" 2>/dev/null || true)
  printf 'RESPONSE_HEADERS:\n'; cat "$CV_HTTP_HEADERS_FILE" 2>/dev/null || true
  printf 'RESPONSE_BODY:\n%s\n' "$CV_HTTP_BODY"
  rm -f "$(_cv_ms_file)" 2>/dev/null || :
  printf 'CV_HTTP|%s|%s|%s|%s\n' "$_cv_method" "$_cv_url" "$CV_HTTP_STATUS" "$CV_HTTP_MS"
  if [ -n "$_cv_expect" ] && [ "$CV_HTTP_STATUS" != "$_cv_expect" ]; then
    cv_fail "expected HTTP $_cv_expect from $_cv_method $_cv_url got $CV_HTTP_STATUS: $(printf '%s' "$CV_HTTP_BODY" | head -c 300)" ""
  fi
  return 0
}
# --- end CodeValid diagnosis markers ---

# --- feature helpers (task_5775989322_20261021170445) ---
export CV_STAFF_EMAIL="${CV_STAFF_EMAIL:-staff@codevalid.test}"
export CV_STAFF_PASSWORD="${CV_STAFF_PASSWORD:-codevalid-staff-pass}"
CV_SUFFIX="$(date +%s%N)$RANDOM"
CV_MEMBER_IDS=()
CV_BOOK_IDS=()

# cv_q "<sql>"  -> prints a single scalar, fails the test on SQL error
cv_q() { psql -v ON_ERROR_STOP=1 -tAq -c "$1"; }

# cv_member <tag>  -> registers + logs in a member; sets CV_MEMBER_ID and CV_TOKEN
cv_member() {
  local email="cv_${1}_${CV_SUFFIX}@example.com"
  cv_http POST /auth/register "{\"email\":\"$email\",\"name\":\"CV $1\",\"password\":\"password123\"}" 201
  CV_MEMBER_ID=$(printf '%s' "$CV_HTTP_BODY" | jq -r '.member.id')
  CV_MEMBER_IDS+=("$CV_MEMBER_ID")
  cv_http POST /auth/login "{\"email\":\"$email\",\"password\":\"password123\"}" 200
  CV_TOKEN=$(printf '%s' "$CV_HTTP_BODY" | jq -r '.token')
  [ -n "$CV_TOKEN" ] && [ "$CV_TOKEN" != "null" ] || cv_fail "expected token for $email got none" $LINENO
}

# cv_staff -> logs in the startup staff account; sets CV_STAFF_TOKEN
cv_staff() {
  cv_http POST /auth/login "{\"email\":\"$CV_STAFF_EMAIL\",\"password\":\"$CV_STAFF_PASSWORD\"}" 200
  CV_STAFF_TOKEN=$(printf '%s' "$CV_HTTP_BODY" | jq -r '.token')
  [ "$(printf '%s' "$CV_HTTP_BODY" | jq -r '.member.role')" = "staff" ] || cv_fail "expected staff role got $CV_HTTP_BODY" $LINENO
}

# cv_book [copies] -> inserts a book row; sets CV_BOOK_ID
cv_book() {
  local isbn="97${CV_SUFFIX: -11}"
  CV_BOOK_ID=$(cv_q "INSERT INTO books (isbn, title, author, year, total_copies) VALUES ('$isbn', 'CV Book $CV_SUFFIX', 'CV Author', 2020, ${1:-1}) RETURNING id" | head -n1)
  _cv_is_int "$CV_BOOK_ID" || cv_fail "expected book id got '$CV_BOOK_ID'" $LINENO
  CV_BOOK_IDS+=("$CV_BOOK_ID")
}

# cv_borrow <token> <book_id> -> POST /loans; sets CV_LOAN_ID
cv_borrow() {
  cv_http POST /loans "{\"book_id\":$2}" 201 -H "Authorization: Bearer $1"
  CV_LOAN_ID=$(printf '%s' "$CV_HTTP_BODY" | jq -r '.loan.id')
  _cv_is_int "$CV_LOAN_ID" || cv_fail "expected loan id got '$CV_LOAN_ID'" $LINENO
}

# cv_available <book_id> -> echoes available_copies from GET /books/{id}
cv_available() {
  command curl -sS "$BASE_URL/books/$1" | jq -r '.book.available_copies'
}

cv_cleanup() {
  local m b
  m=$(IFS=,; echo "${CV_MEMBER_IDS[*]:-}")
  b=$(IFS=,; echo "${CV_BOOK_IDS[*]:-}")
  if [ -n "$m" ]; then
    psql -q -c "DELETE FROM fees WHERE member_id IN ($m); DELETE FROM holds WHERE member_id IN ($m); DELETE FROM loans WHERE member_id IN ($m);" >/dev/null || true
  fi
  if [ -n "$b" ]; then
    psql -q -c "DELETE FROM fees WHERE loan_id IN (SELECT id FROM loans WHERE book_id IN ($b)); DELETE FROM holds WHERE book_id IN ($b); DELETE FROM loans WHERE book_id IN ($b); DELETE FROM books WHERE id IN ($b);" >/dev/null || true
  fi
  [ -n "$m" ] && psql -q -c "DELETE FROM members WHERE id IN ($m);" >/dev/null || true
}
