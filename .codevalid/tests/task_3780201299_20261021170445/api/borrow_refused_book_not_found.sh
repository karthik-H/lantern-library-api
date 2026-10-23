#!/usr/bin/env bash
set -euo pipefail
source .codevalid/tests/task_3780201299_20261021170445/api/_infra.sh

# Given
cv_step Given "eligible signed-in member and a book id that does not exist" $LINENO
SFX=$(cv_uniq)
cv_register_member "cv.nf.$SFX@example.com" "Passw0rd!$SFX"
MISSING_ID=$(cv_sql "SELECT coalesce(max(id), 0) + 1000000 FROM books")
[ -n "$MISSING_ID" ] || cv_fail "expected a missing book id got empty" $LINENO

# When
cv_step When "member requests to borrow the non-existent book" $LINENO
cv_http POST /loans "{\"book_id\":$MISSING_ID}" -H "Authorization: Bearer $MEMBER_TOKEN"

# Then
cv_step Then "borrow is refused with 404 'book not found' and no loan is created" $LINENO
[ "$CV_HTTP_STATUS" = "404" ] || cv_fail "expected 404 got $CV_HTTP_STATUS" $LINENO
ERR=$(printf '%s' "$CV_HTTP_BODY" | jq -r '.error // empty')
printf '%s' "$ERR" | grep -qi "book not found" \
  || cv_fail "expected error 'book not found' got '$ERR'" $LINENO
N=$(cv_sql "SELECT count(*) FROM loans WHERE member_id = $MEMBER_ID")
[ "$N" = "0" ] || cv_fail "expected 0 loans for member got $N" $LINENO

# Cleanup
cv_step Cleanup "remove member" $LINENO
cv_cleanup "$MEMBER_ID"

echo "CODEVALID_TEST_ASSERTION_OK:borrow_refused_book_not_found"
