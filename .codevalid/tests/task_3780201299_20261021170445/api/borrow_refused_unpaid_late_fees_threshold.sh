#!/usr/bin/env bash
set -euo pipefail
source .codevalid/tests/task_3780201299_20261021170445/api/_infra.sh

# Given
cv_step Given "a signed-in member with exactly 5.00 in unpaid late fees, no active loans, and an available book" $LINENO
SFX=$(cv_uniq)
EMAIL="borrow.fees.$SFX@example.com"
cv_register_member "$EMAIL" "Passw0rd-$SFX"
cv_prereq "seed past book and a returned late loan" $LINENO
OLD_BOOK=$(cv_seed_book "CV-FEE-$SFX-old" 1) || cv_fail "expected old book insert to succeed" $LINENO
[ -n "${OLD_BOOK:-}" ] || cv_fail "expected seeded old book id got empty" $LINENO
OLD_LOAN=$(cv_seed_returned_loan "$MEMBER_ID" "$OLD_BOOK") || cv_fail "expected returned loan insert to succeed" $LINENO
[ -n "${OLD_LOAN:-}" ] || cv_fail "expected seeded returned loan id got empty" $LINENO
cv_prereq "seed unpaid fee of 500 cents" $LINENO
FEE_ID=$(cv_sql "INSERT INTO fees (member_id, loan_id, amount_cents) VALUES ($MEMBER_ID, $OLD_LOAN, 500) RETURNING id") || cv_fail "expected unpaid fee insert to succeed" $LINENO
[ -n "${FEE_ID:-}" ] || cv_fail "expected seeded fee id got empty" $LINENO
cv_prereq "seed requested book with 2 copies" $LINENO
BOOK_ID=$(cv_seed_book "CV-FEE-$SFX-new" 2) || cv_fail "expected book insert to succeed" $LINENO
[ -n "${BOOK_ID:-}" ] || cv_fail "expected seeded book id got empty" $LINENO

# When
cv_step When "the member tries to borrow the available book via POST /loans" $LINENO
cv_http POST /loans "{\"book_id\":$BOOK_ID}" -H "Authorization: Bearer $MEMBER_TOKEN"

# Then
cv_step Then "the borrow is refused with 409 for unpaid fees and no loan is created" $LINENO
[ "$CV_HTTP_STATUS" = "409" ] || cv_fail "expected HTTP 409 got $CV_HTTP_STATUS: $CV_HTTP_BODY" $LINENO
ERR=$(printf '%s' "$CV_HTTP_BODY" | jq -r '.error // empty')
printf '%s' "$ERR" | grep -qi 'fee' || cv_fail "expected error mentioning fees got '$ERR'" $LINENO
N=$(cv_sql "SELECT count(*) FROM loans WHERE book_id = $BOOK_ID")
[ "$N" = "0" ] || cv_fail "expected no loan on requested book got $N" $LINENO

# Cleanup
cv_step Cleanup "delete the member, fee, loans and books created by this test" $LINENO
cv_cleanup "$MEMBER_ID" "$OLD_BOOK" "$BOOK_ID"
echo "CODEVALID_TEST_ASSERTION_OK:borrow_refused_unpaid_late_fees_threshold"
