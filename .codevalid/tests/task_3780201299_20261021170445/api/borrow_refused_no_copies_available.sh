#!/usr/bin/env bash
set -euo pipefail
source .codevalid/tests/task_3780201299_20261021170445/api/_infra.sh

# Given
cv_step Given "a 1-copy book is on loan to another member; requester is eligible" $LINENO
SFX=$(cv_uniq)
cv_register_member "cv.other.$SFX@example.com" "Passw0rd!$SFX"
OTHER_ID=$MEMBER_ID
cv_register_member "cv.nocopy.$SFX@example.com" "Passw0rd!$SFX"
cv_prereq "seed book with 1 copy" $LINENO
BOOK_ID=$(cv_seed_book "NOC$SFX" 1)
[ -n "$BOOK_ID" ] || cv_fail "expected seeded book id got empty" $LINENO
cv_prereq "seed active loan of the only copy to the other member" $LINENO
LOAN_ID=$(cv_seed_active_loan "$OTHER_ID" "$BOOK_ID")
[ -n "$LOAN_ID" ] || cv_fail "expected seeded loan id got empty" $LINENO

# When
cv_step When "eligible member requests to borrow the book" $LINENO
cv_http POST /loans "{\"book_id\":$BOOK_ID}" -H "Authorization: Bearer $MEMBER_TOKEN"

# Then
cv_step Then "borrow is refused with 409 'no copy available' and no loan is created" $LINENO
[ "$CV_HTTP_STATUS" = "409" ] || cv_fail "expected 409 got $CV_HTTP_STATUS" $LINENO
ERR=$(printf '%s' "$CV_HTTP_BODY" | jq -r '.error // empty')
printf '%s' "$ERR" | grep -qi "no copy available" \
  || cv_fail "expected error containing 'no copy available' got '$ERR'" $LINENO
N=$(cv_sql "SELECT count(*) FROM loans WHERE member_id = $MEMBER_ID")
[ "$N" = "0" ] || cv_fail "expected 0 loans for requester got $N" $LINENO

# Cleanup
cv_step Cleanup "remove members, loans and book" $LINENO
cv_cleanup "$MEMBER_ID"
cv_cleanup "$OTHER_ID" "$BOOK_ID"

echo "CODEVALID_TEST_ASSERTION_OK:borrow_refused_no_copies_available"
