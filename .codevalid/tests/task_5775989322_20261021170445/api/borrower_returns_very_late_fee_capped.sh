#!/usr/bin/env bash
set -euo pipefail
source .codevalid/tests/task_5775989322_20261021170445/api/_infra.sh

# Given
cv_step Given "a member's loan was due 45 days 2 hours ago (46 started late days)" $LINENO
cv_member borrower; TOKEN=$CV_TOKEN; MID=$CV_MEMBER_ID
cv_book 1; BOOK=$CV_BOOK_ID
cv_borrow "$TOKEN" "$BOOK"; LOAN=$CV_LOAN_ID
cv_q "UPDATE loans SET borrowed_at = now() - interval '59 days 2 hours', due_at = now() - interval '45 days 2 hours' WHERE id = $LOAN" >/dev/null || cv_fail "expected due_at update to succeed" $LINENO

# When
cv_step When "the borrower returns the loan" $LINENO
cv_http POST "/loans/$LOAN/return" "" -H "Authorization: Bearer $TOKEN"

# Then
cv_step Then "200 with fee capped at 1000 cents" $LINENO
[ "$CV_HTTP_STATUS" = "200" ] || cv_fail "expected 200 got $CV_HTTP_STATUS" $LINENO
FEE=$(jq -r '.fee.amount_cents // "null"' <<<"$CV_HTTP_BODY")
[ "$FEE" = "1000" ] || cv_fail "expected fee.amount_cents 1000 (cap) got $FEE" $LINENO
DBFEE=$(cv_q "SELECT coalesce(sum(amount_cents),0) FROM fees WHERE loan_id = $LOAN AND member_id = $MID")
[ "$DBFEE" = "1000" ] || cv_fail "expected 1000 cents fee row got $DBFEE" $LINENO

# Cleanup
cv_step Cleanup "remove created data" $LINENO
cv_cleanup
echo "CODEVALID_TEST_ASSERTION_OK:borrower_returns_very_late_fee_capped"
