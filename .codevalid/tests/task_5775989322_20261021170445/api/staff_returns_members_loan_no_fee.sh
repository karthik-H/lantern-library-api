#!/usr/bin/env bash
set -euo pipefail
source .codevalid/tests/task_5775989322_20261021170445/api/_infra.sh

# Given
cv_step Given "a member has an active loan due later today and a staff user is logged in" $LINENO
cv_member borrower; TOKEN=$CV_TOKEN
cv_book 1; BOOK=$CV_BOOK_ID
cv_borrow "$TOKEN" "$BOOK"; LOAN=$CV_LOAN_ID
cv_q "UPDATE loans SET due_at = now() + interval '5 minutes' WHERE id = $LOAN" >/dev/null || cv_fail "expected due_at update to succeed" $LINENO
cv_staff; STAFF=$CV_STAFF_TOKEN

# When
cv_step When "staff returns the member's loan" $LINENO
cv_http POST "/loans/$LOAN/return" "" -H "Authorization: Bearer $STAFF"

# Then
cv_step Then "200, loan returned, no fee, copy available" $LINENO
[ "$CV_HTTP_STATUS" = "200" ] || cv_fail "expected 200 got $CV_HTTP_STATUS" $LINENO
[ "$(jq -r '.loan.returned_at' <<<"$CV_HTTP_BODY")" != "null" ] || cv_fail "expected loan.returned_at set got null" $LINENO
FEE=$(jq -r 'if .fee == null then 0 else .fee.amount_cents end' <<<"$CV_HTTP_BODY")
[ "$FEE" = "0" ] || cv_fail "expected fee 0 got $FEE" $LINENO
N=$(cv_q "SELECT count(*) FROM fees WHERE loan_id = $LOAN")
[ "$N" = "0" ] || cv_fail "expected no fee rows got $N" $LINENO
R=$(cv_q "SELECT returned_at IS NOT NULL FROM loans WHERE id = $LOAN")
[ "$R" = "t" ] || cv_fail "expected loan returned in DB got $R" $LINENO
AV=$(cv_available "$BOOK")
[ "$AV" = "1" ] || cv_fail "expected available_copies 1 got $AV" $LINENO

# Cleanup
cv_step Cleanup "remove created data" $LINENO
cv_cleanup
echo "CODEVALID_TEST_ASSERTION_OK:staff_returns_members_loan_no_fee"
