#!/usr/bin/env bash
set -euo pipefail
source .codevalid/tests/task_5775989322_20261021170445/api/_infra.sh

# Given
cv_step Given "member A has an active loan; member B (not staff) is logged in" $LINENO
cv_member owner; TOKEN_A=$CV_TOKEN
cv_book 1; BOOK=$CV_BOOK_ID
cv_borrow "$TOKEN_A" "$BOOK"; LOAN=$CV_LOAN_ID
cv_member other; TOKEN_B=$CV_TOKEN

# When
cv_step When "member B tries to return member A's loan" $LINENO
cv_http POST "/loans/$LOAN/return" "" -H "Authorization: Bearer $TOKEN_B"

# Then
cv_step Then "request refused (403/404) and the loan stays active" $LINENO
case "$CV_HTTP_STATUS" in 403|404) ;; *) cv_fail "expected 403 or 404 got $CV_HTTP_STATUS" $LINENO ;; esac
jq -e '.error' <<<"$CV_HTTP_BODY" >/dev/null || cv_fail "expected error body got $CV_HTTP_BODY" $LINENO
R=$(cv_q "SELECT returned_at IS NULL FROM loans WHERE id = $LOAN")
[ "$R" = "t" ] || cv_fail "expected loan still active got returned_at set" $LINENO
N=$(cv_q "SELECT count(*) FROM fees WHERE loan_id = $LOAN")
[ "$N" = "0" ] || cv_fail "expected no fee rows got $N" $LINENO
AV=$(cv_available "$BOOK")
[ "$AV" = "0" ] || cv_fail "expected available_copies 0 got $AV" $LINENO

# Cleanup
cv_step Cleanup "remove created data" $LINENO
cv_cleanup
echo "CODEVALID_TEST_ASSERTION_OK:unauthorized_member_attempts_return_other_members_loan"
