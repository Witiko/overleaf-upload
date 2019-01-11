#!/bin/sh
die() { EXITCODE=$1; shift; printf '%s\n' "$*"; exit $EXITCODE; }

# Source the passed file.
[ -e "$1" ] && . "$1"

# Perform sanity checks
[ -z "$TITLE" ] && die 1 Undefined / empty TITLE
[ -z "$AUTHOR" ] && die 2 Undefined / empty AUTHOR
[ -z "$DESCRIPTION" ] && die 3 Undefined / empty DESCRIPTION
[ -z "$LICENSE" ] && die 4 Undefined / empty LICENSE
[ -z "$SHOW_SOURCE" ] && die 5 Undefined / empty SHOW_SOURCE
[ -z "$COOKIE_JAR" ] && die 6 Undefined / empty COOKIE_JAR
[ -e "$COOKIE_JAR" ] || die 7 $COOKIE_JAR does not exist
[ -z "$DOCUMENT_ID" ] && die 8 Undefined / empty DOCUMENT_ID

curl_() {
  curl -H 'User-Agent: Mozilla/5.0 (X11; Linux x86_64; rv:64.0) Gecko/20100101 Firefox/64.0' -s --retry 5 --location -b "$COOKIE_JAR" "$@"
}

RESPONSE=`mktemp`
trap 'rm $RESPONSE' EXIT

echo 'Retrieving CSRF token' >&2
curl_ https://www.overleaf.com/project/$DOCUMENT_ID >$RESPONSE
if grep --silent csrfToken <$RESPONSE
then
  CSRF_TOKEN="$(sed -nr '/window\.csrfToken/s/.*window\.csrfToken = "([^"]*)".*/\1/p' <$RESPONSE | head -n 1)"
else
  die 9 Cannot retrieve CSRF token from the project page: "`cat $RESPONSE`"
fi

echo 'Publishing document' >&2
curl_ https://www.overleaf.com/project/$DOCUMENT_ID/export/96 \
  -H 'Content-Type: application/x-www-form-urlencoded; charset=UTF-8' \
  -H 'X-CSRF-Token: '"$CSRF_TOKEN" \
  -H 'X-Requested-With: XMLHttpRequest' \
  --data-urlencode title="$TITLE" \
  --data-urlencode author="$AUTHOR" \
  --data-urlencode description="$DESCRIPTION" \
  --data-urlencode license="$LICENSE" \
  --data-urlencode showSource="$SHOW_SOURCE" \
  >$RESPONSE
if ! grep --silent 'export_v1_id' <$RESPONSE
then
  die 10 Publishing failed '(post)': "`cat $RESPONSE`"
else
  EXPORT_ID="$(sed -r 's/.*"export_v1_id":(.*)[},].*/\1/' <$RESPONSE)"
fi

echo '"status_summary":"pending","status_detail":"Starting up"' >$RESPONSE
while grep --silent -F '"status_summary":"pending"' <$RESPONSE
do
  STATUS_SUMMARY="$(sed -r 's/.*"status_summary":"([^"]*)".*/\1/' <$RESPONSE)"
  STATUS_DETAIL="$(sed -r 's/.*"status_detail":"([^"]*)".*/\1/' <$RESPONSE)"
  printf 'Waiting for document to be published (%s: %s)\n' "$STATUS_SUMMARY" "$STATUS_DETAIL" >&2
  curl_ https://www.overleaf.com/project/5c381f90819e564c3d6152cc/export/$EXPORT_ID \
    >$RESPONSE
  sleep 5s
done

if ! grep --silent -F '"status_summary":"succeeded"' <$RESPONSE
then
  die 11 Publishing failed '(status)': "`cat $RESPONSE`"
fi

echo Done! >&2
