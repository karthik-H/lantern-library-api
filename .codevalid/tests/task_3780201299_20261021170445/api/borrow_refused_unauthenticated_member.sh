#!/usr/bin/env bash
set -euo pipefail
source .codevalid/tests/task_3780201299_20261021170445/api/_infra.sh

# Given
cv_step Given "an available book with 2 copies and no signed-in member" $LINENO
SFX=$(cv_uniq)
cv_prereq "seed book with 2 copies" $LINENO
BOOK_ID=$(cv_seed_book "UNA$SFX" 2)
[ -n "$BOOK_ID" ] || cv_fail "expected seeded book id got empty" $LINENO

# When
cv_step When "borrow is attempted without a token and with an invalid token" $LINENO
cv_http POST /loans "{\"book_id\":$BOOK_ID}"
NO_AUTH_STATUS=$CV_HTTP_STATUS
cv_http POST /loans "{\"book_id\":$BOOK_ID}" -H "Authorization: Bearer not.a.valid.token$SFX"
BAD_AUTH_STATUS=$CV_HTTP_STATUS

# Then
cv_step Then "both requests are rejected with 401 and no loan is created" $LINENO
[ "$NO_AUTH_STATUS" = "401" ] || cv_fail "expected 401 without token got $NO_AUTH_STATUS" $LINENO
[ "$BAD_AUTH_STATUS" = "401" ] || cv_fail "expected 401 with invalid token got $BAD_AUTH_STATUS" $LINENO
N=$(cv_sql "SELECT count(*) FROM loans WHERE book_id = $BOOK_ID")
[ "$N" = "0" ] || cv_fail "expected 0 loans on book got $N" $LINENO

# Cleanup
cv_step Cleanup "remove book" $LINENO
cv_cleanup "" "$BOOK_ID"

echo "CODEVALID_TEST_ASSERTION_OK:borrow_refused_unauthenticated_member"
