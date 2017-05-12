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

# Ensure that the PDF document was generated.
URL="$(curl -d '' \
  https://www.overleaf.com/docs/"$DOCUMENT_ID"/pdf |
  sed -r -n '/"https?:.*\.pdf"/s#.*"(https?://[^"]*\.pdf)".*#\1#p')"
[ -z "$URL" ] && die 9 Unexpected response when generating PDF
curl "$URL" | head -c 1 >/dev/null ||
  die 10 Unexpected response when generating PDF

# Retrieve a ticket number.
TICKET="$(curl -b $COOKIE_JAR \
  https://www.overleaf.com/docs/"$DOCUMENT_ID"/exports/gallery |
  xmllint --html --xpath "//input[@name='authenticity_token']/@value" - 2>/dev/null |
  sed -n -r '/^ value=".*"$/s/^ value="(.*)"$/\1\n/p')"
[ -z "$TICKET" ] && die 11 Failed to download ticket number

# Publish the document.
RESPONSE=`mktemp`
trap 'rm $RESPONSE' EXIT
curl --form-string utf8='✓' \
     --form-string authenticity_token="$TICKET" \
     --form-string published_ver[title]="$TITLE" \
     --form-string published_ver[author]="$AUTHOR" \
     --form-string published_ver[description]="$DESCRIPTION" \
     --form-string published_ver[license]="$LICENSE" \
     --form-string published_ver[show_source]="$SHOW_SOURCE" \
     --form-string commit='Submit to Overleaf Gallery' \
     -b "$COOKIE_JAR" >$RESPONSE \
     https://www.overleaf.com/docs/"$DOCUMENT_ID"/exports/gallery
grep <$RESPONSE -qF 'Thanks for submitting to our gallery!' ||
  die 12 Upload failed: "`cat $RESPONSE`"
