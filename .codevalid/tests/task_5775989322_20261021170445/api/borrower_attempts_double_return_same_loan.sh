#!/usr/bin/env bash
set -euo pipefail
source .codevalid/tests/task_5775989322_20261021170445/api/_infra.sh

# Given
cv_step Given "a member has already returned their loan once" $LINENO
cv_member borrower; TOKEN=$CV_TOKEN
cv_book 1; BOOK=$CV_BOOK_ID
cv_borrow "$TOKEN" "$BOOK"; LOAN=$CV_LOAN_ID
cv_prereq "first return" $LINENO
cv_http POST "/loans/$LOAN/return" "" 200 -H "Authorization: Bearer $TOKEN"
FIRST=$(cv_q "SELECT returned_at FROM loans WHERE id = $LOAN")

# When
cv_step When "the borrower returns the same loan again" $LINENO
cv_http POST "/loans/$LOAN/return" "" -H "Authorization: Bearer $TOKEN"

# Then
cv_step Then "409 loan already returned, nothing changes" $LINENO
[ "$CV_HTTP_STATUS" = "409" ] || cv_fail "expected 409 got $CV_HTTP_STATUS" $LINENO
ERR=$(jq -r '.error' <<<"$CV_HTTP_BODY")
[[ "$ERR" == *"already returned"* ]] || cv_fail "expected error 'loan already returned' got '$ERR'" $LINENO
SECOND=$(cv_q "SELECT returned_at FROM loans WHERE id = $LOAN")
[ "$FIRST" = "$SECOND" ] || cv_fail "expected returned_at unchanged ($FIRST) got $SECOND" $LINENO
N=$(cv_q "SELECT count(*) FROM fees WHERE loan_id = $LOAN")
[ "$N" = "0" ] || cv_fail "expected no fee rows got $N" $LINENO

# Cleanup
cv_step Cleanup "remove created data" $LINENO
cv_cleanup
echo "CODEVALID_TEST_ASSERTION_OK:borrower_attempts_double_return_same_loan"
