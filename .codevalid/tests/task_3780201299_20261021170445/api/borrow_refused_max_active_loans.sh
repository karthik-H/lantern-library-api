#!/usr/bin/env bash
set -euo pipefail
source .codevalid/tests/task_3780201299_20261021170445/api/_infra.sh

# Given
cv_step Given "a signed-in member with exactly 3 active loans and a fourth book with available copies" $LINENO
SFX=$(cv_uniq)
EMAIL="borrow.max.$SFX@example.com"
cv_register_member "$EMAIL" "Passw0rd-$SFX"
BOOKS=()
for i in 1 2 3; do
  cv_prereq "seed book $i and an active loan on it" $LINENO
  B=$(cv_seed_book "CV-MAX-$SFX-$i" 1) || true
  [ -n "${B:-}" ] || cv_fail "expected seeded book id for loan $i got empty" $LINENO
  BOOKS+=("$B")
  L=$(cv_seed_active_loan "$MEMBER_ID" "$B") || true
  [ -n "${L:-}" ] || cv_fail "expected seeded active loan id for book $B got empty" $LINENO
done
cv_prereq "seed requested book with 2 copies" $LINENO
BOOK_ID=$(cv_seed_book "CV-MAX-$SFX-4" 2) || true
[ -n "${BOOK_ID:-}" ] || cv_fail "expected seeded book id got empty" $LINENO
BOOKS+=("$BOOK_ID")
N=$(cv_sql "SELECT count(*) FROM loans WHERE member_id = $MEMBER_ID AND returned_at IS NULL")
[ "$N" = "3" ] || cv_fail "expected 3 active loans in Given got $N" $LINENO

# When
cv_step When "the member tries to borrow the fourth book via POST /loans" $LINENO
cv_http POST /loans "{\"book_id\":$BOOK_ID}" -H "Authorization: Bearer $MEMBER_TOKEN"

# Then
cv_step Then "the borrow is refused with 409 and no new loan is created" $LINENO
[ "$CV_HTTP_STATUS" = "409" ] || cv_fail "expected HTTP 409 got $CV_HTTP_STATUS: $CV_HTTP_BODY" $LINENO
ERR=$(printf '%s' "$CV_HTTP_BODY" | jq -r '.error // empty')
printf '%s' "$ERR" | grep -qi 'loan limit' || cv_fail "expected error mentioning loan limit got '$ERR'" $LINENO
N=$(cv_sql "SELECT count(*) FROM loans WHERE member_id = $MEMBER_ID AND returned_at IS NULL")
[ "$N" = "3" ] || cv_fail "expected still 3 active loans got $N" $LINENO
N4=$(cv_sql "SELECT count(*) FROM loans WHERE book_id = $BOOK_ID")
[ "$N4" = "0" ] || cv_fail "expected no loan on requested book got $N4" $LINENO

# Cleanup
cv_step Cleanup "delete the member, loans and books created by this test" $LINENO
cv_cleanup "$MEMBER_ID" "${BOOKS[@]}"
echo "CODEVALID_TEST_ASSERTION_OK:borrow_refused_max_active_loans"
