#!/usr/bin/env bash
set -euo pipefail
source .codevalid/tests/task_3780201299_20261021170445/api/_infra.sh

# Given
cv_step Given "eligible member already has an active loan on a book with 3 copies" $LINENO
SFX=$(cv_uniq)
cv_register_member "cv.dup.$SFX@example.com" "Passw0rd!$SFX"
cv_prereq "seed book with 3 copies" $LINENO
BOOK_ID=$(cv_seed_book "DUP$SFX" 3)
[ -n "$BOOK_ID" ] || cv_fail "expected seeded book id got empty" $LINENO
cv_prereq "seed active loan on the book for the member" $LINENO
LOAN_ID=$(cv_seed_active_loan "$MEMBER_ID" "$BOOK_ID")
[ -n "$LOAN_ID" ] || cv_fail "expected seeded loan id got empty" $LINENO

# When
cv_step When "member requests to borrow the same book again" $LINENO
cv_http POST /loans "{\"book_id\":$BOOK_ID}" -H "Authorization: Bearer $MEMBER_TOKEN"

# Then
cv_step Then "borrow is refused with 409 and no second loan exists" $LINENO
[ "$CV_HTTP_STATUS" = "409" ] || cv_fail "expected 409 got $CV_HTTP_STATUS" $LINENO
ERR=$(printf '%s' "$CV_HTTP_BODY" | jq -r '.error // empty')
printf '%s' "$ERR" | grep -qi "already have this book on loan" \
  || cv_fail "expected error 'you already have this book on loan' got '$ERR'" $LINENO
N=$(cv_sql "SELECT count(*) FROM loans WHERE member_id = $MEMBER_ID AND book_id = $BOOK_ID AND returned_at IS NULL")
[ "$N" = "1" ] || cv_fail "expected 1 active loan for member/book got $N" $LINENO

# Cleanup
cv_step Cleanup "remove member, loans and book" $LINENO
cv_cleanup "$MEMBER_ID" "$BOOK_ID"

echo "CODEVALID_TEST_ASSERTION_OK:borrow_refused_duplicate_book_on_loan"
