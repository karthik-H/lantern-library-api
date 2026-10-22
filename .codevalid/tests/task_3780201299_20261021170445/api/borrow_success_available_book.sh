#!/usr/bin/env bash
set -euo pipefail
source .codevalid/tests/task_3780201299_20261021170445/api/_infra.sh

# Given
cv_step Given "an eligible signed-in member (no loans, no fees) and a book with 2 available copies" $LINENO
SFX=$(cv_uniq)
EMAIL="borrow.ok.$SFX@example.com"
cv_register_member "$EMAIL" "Passw0rd-$SFX"
cv_prereq "seed book with 2 copies" $LINENO
BOOK_ID=$(cv_seed_book "CV-OK-$SFX" 2) || true
[ -n "${BOOK_ID:-}" ] || cv_fail "expected seeded book id got empty" $LINENO
BEFORE_EPOCH=$(cv_sql "SELECT extract(epoch FROM now())::bigint")

# When
cv_step When "the member borrows the book via POST /loans" $LINENO
cv_http POST /loans "{\"book_id\":$BOOK_ID}" -H "Authorization: Bearer $MEMBER_TOKEN"

# Then
cv_step Then "a 201 loan is returned for this member and book, due 14 days after borrow time" $LINENO
[ "$CV_HTTP_STATUS" = "201" ] || cv_fail "expected HTTP 201 got $CV_HTTP_STATUS: $CV_HTTP_BODY" $LINENO
LOAN_ID=$(printf '%s' "$CV_HTTP_BODY" | jq -r '.loan.id')
[ -n "$LOAN_ID" ] && [ "$LOAN_ID" != "null" ] || cv_fail "expected loan.id got $LOAN_ID" $LINENO
RESP_MEMBER=$(printf '%s' "$CV_HTTP_BODY" | jq -r '.loan.member_id')
[ "$RESP_MEMBER" = "$MEMBER_ID" ] || cv_fail "expected loan.member_id $MEMBER_ID got $RESP_MEMBER" $LINENO
RESP_BOOK=$(printf '%s' "$CV_HTTP_BODY" | jq -r '.loan.book_id')
[ "$RESP_BOOK" = "$BOOK_ID" ] || cv_fail "expected loan.book_id $BOOK_ID got $RESP_BOOK" $LINENO
RETURNED=$(printf '%s' "$CV_HTTP_BODY" | jq -r '.loan.returned_at')
[ "$RETURNED" = "null" ] || cv_fail "expected loan.returned_at null got $RETURNED" $LINENO
OVERDUE=$(printf '%s' "$CV_HTTP_BODY" | jq -r '.loan.overdue')
[ "$OVERDUE" = "false" ] || cv_fail "expected loan.overdue false got $OVERDUE" $LINENO
# due_at - borrowed_at == 14 days, checked in the database row
DIFF=$(cv_sql "SELECT extract(epoch FROM (due_at - borrowed_at))::bigint FROM loans WHERE id = $LOAN_ID")
[ "$DIFF" = "1209600" ] || cv_fail "expected due_at - borrowed_at = 1209600s (14 days) got $DIFF" $LINENO
BORROWED_EPOCH=$(cv_sql "SELECT extract(epoch FROM borrowed_at)::bigint FROM loans WHERE id = $LOAN_ID")
DELTA=$(( BORROWED_EPOCH - BEFORE_EPOCH ))
{ [ "$DELTA" -ge -1 ] && [ "$DELTA" -le 60 ]; } || cv_fail "expected borrowed_at near request time got delta ${DELTA}s" $LINENO
# response due_at agrees with the row
RESP_DUE_EPOCH=$(cv_sql "SELECT extract(epoch FROM '$(printf '%s' "$CV_HTTP_BODY" | jq -r '.loan.due_at')'::timestamptz)::bigint")
ROW_DUE_EPOCH=$(cv_sql "SELECT extract(epoch FROM due_at)::bigint FROM loans WHERE id = $LOAN_ID")
[ "$RESP_DUE_EPOCH" = "$ROW_DUE_EPOCH" ] || cv_fail "expected response due_at epoch $ROW_DUE_EPOCH got $RESP_DUE_EPOCH" $LINENO
ACTIVE=$(cv_sql "SELECT count(*) FROM loans WHERE member_id = $MEMBER_ID AND book_id = $BOOK_ID AND returned_at IS NULL")
[ "$ACTIVE" = "1" ] || cv_fail "expected 1 active loan row got $ACTIVE" $LINENO

# Cleanup
cv_step Cleanup "delete the member, loan and book created by this test" $LINENO
cv_cleanup "$MEMBER_ID" "$BOOK_ID"
echo "CODEVALID_TEST_ASSERTION_OK:borrow_success_available_book"
