#!/usr/bin/env bash
set -euo pipefail
source .codevalid/tests/task_5775989322_20261021170445/api/_infra.sh

# Given
cv_step Given "a logged-in member and a loan id that does not exist" $LINENO
cv_member borrower; TOKEN=$CV_TOKEN
MAXID=$(cv_q "SELECT coalesce(max(id),0) FROM loans")
_cv_is_int "$MAXID" || cv_fail "expected max loan id got '$MAXID'" $LINENO
LOAN=$((MAXID + 1000000))

# When
cv_step When "the member returns the nonexistent loan" $LINENO
cv_http POST "/loans/$LOAN/return" "" -H "Authorization: Bearer $TOKEN"

# Then
cv_step Then "404 loan not found" $LINENO
[ "$CV_HTTP_STATUS" = "404" ] || cv_fail "expected 404 got $CV_HTTP_STATUS" $LINENO
ERR=$(jq -r '.error' <<<"$CV_HTTP_BODY")
[[ "$ERR" == *"not found"* ]] || cv_fail "expected error containing 'not found' got '$ERR'" $LINENO

# Cleanup
cv_step Cleanup "remove created member" $LINENO
cv_cleanup
echo "CODEVALID_TEST_ASSERTION_OK:return_nonexistent_loan"
