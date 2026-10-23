#!/usr/bin/env bash
set -euo pipefail
source .codevalid/tests/task_5775989322_20261021170445/api/_infra.sh

# Given
cv_step Given "a member has an active loan of a 1-copy book due later today" $LINENO
cv_member borrower; TOKEN=$CV_TOKEN; MID=$CV_MEMBER_ID
cv_book 1; BOOK=$CV_BOOK_ID
cv_borrow "$TOKEN" "$BOOK"; LOAN=$CV_LOAN_ID
cv_prereq "move due_at to later today (the due date)" $LINENO
cv_q "UPDATE loans SET due_at = now() + interval '5 minutes' WHERE id = $LOAN" >/dev/null || cv_fail "expected due_at update to succeed" $LINENO
[ "$(cv_available "$BOOK")" = "0" ] || cv_fail "expected 0 available copies before return" $LINENO

# When
cv_step When "the borrower returns the loan" $LINENO
cv_http POST "/loans/$LOAN/return" "" -H "Authorization: Bearer $TOKEN"

# Then
cv_step Then "200 with returned loan, no fee charged and the copy available again" $LINENO
[ "$CV_HTTP_STATUS" = "200" ] || cv_fail "expected 200 got $CV_HTTP_STATUS" $LINENO
[ "$(jq -r '.loan.id' <<<"$CV_HTTP_BODY")" = "$LOAN" ] || cv_fail "expected loan.id $LOAN got $(jq -r '.loan.id' <<<"$CV_HTTP_BODY")" $LINENO
[ "$(jq -r '.loan.returned_at' <<<"$CV_HTTP_BODY")" != "null" ] || cv_fail "expected loan.returned_at set got null" $LINENO
jq -e 'has("fee")' <<<"$CV_HTTP_BODY" >/dev/null || cv_fail "expected fee key in response got $CV_HTTP_BODY" $LINENO
FEE=$(jq -r 'if .fee == null then 0 else .fee.amount_cents end' <<<"$CV_HTTP_BODY")
[ "$FEE" = "0" ] || cv_fail "expected fee 0 got $FEE" $LINENO
N=$(cv_q "SELECT count(*) FROM fees WHERE loan_id = $LOAN")
[ "$N" = "0" ] || cv_fail "expected no fee rows for loan got $N" $LINENO
AV=$(cv_available "$BOOK")
[ "$AV" = "1" ] || cv_fail "expected available_copies 1 after return got $AV" $LINENO

# Cleanup
cv_step Cleanup "remove created members, book, loan" $LINENO
cv_cleanup
echo "CODEVALID_TEST_ASSERTION_OK:borrower_returns_on_due_date_no_fee"
