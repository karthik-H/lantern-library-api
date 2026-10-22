#!/usr/bin/env bash
set -euo pipefail
source .codevalid/tests/task_5775989322_20261021170445/api/_infra.sh

# Given
cv_step Given "member A borrowed the only copy and returned it; member B cannot borrow beforehand" $LINENO
cv_member first; TOKEN_A=$CV_TOKEN
cv_member second; TOKEN_B=$CV_TOKEN; MID_B=$CV_MEMBER_ID
cv_book 1; BOOK=$CV_BOOK_ID
cv_borrow "$TOKEN_A" "$BOOK"; LOAN_A=$CV_LOAN_ID
cv_prereq "member B is blocked while the copy is on loan" $LINENO
cv_http POST /loans "{\"book_id\":$BOOK}" 409 -H "Authorization: Bearer $TOKEN_B"
cv_prereq "member A returns the copy" $LINENO
cv_http POST "/loans/$LOAN_A/return" "" 200 -H "Authorization: Bearer $TOKEN_A"

# When
cv_step When "member B borrows the same book" $LINENO
cv_http POST /loans "{\"book_id\":$BOOK}" -H "Authorization: Bearer $TOKEN_B"

# Then
cv_step Then "201 loan created for member B on that book" $LINENO
[ "$CV_HTTP_STATUS" = "201" ] || cv_fail "expected 201 got $CV_HTTP_STATUS" $LINENO
[ "$(jq -r '.loan.member_id' <<<"$CV_HTTP_BODY")" = "$MID_B" ] || cv_fail "expected loan.member_id $MID_B got $(jq -r '.loan.member_id' <<<"$CV_HTTP_BODY")" $LINENO
[ "$(jq -r '.loan.book_id' <<<"$CV_HTTP_BODY")" = "$BOOK" ] || cv_fail "expected loan.book_id $BOOK" $LINENO
[ "$(jq -r '.loan.returned_at' <<<"$CV_HTTP_BODY")" = "null" ] || cv_fail "expected new loan active" $LINENO
AV=$(cv_available "$BOOK")
[ "$AV" = "0" ] || cv_fail "expected available_copies 0 after re-borrow got $AV" $LINENO

# Cleanup
cv_step Cleanup "remove created data" $LINENO
cv_cleanup
echo "CODEVALID_TEST_ASSERTION_OK:return_then_borrow_same_copy_again"
