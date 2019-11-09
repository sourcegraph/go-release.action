#!/bin/sh

set -eux

EXT=''
if [ $GOOS == 'windows' ]; then
	EXT='.exe'
fi

export EXECUTABLE_PATH=$(mktemp)${EXT}

/build.sh

EVENT_DATA=$(cat $GITHUB_EVENT_PATH)
echo $EVENT_DATA | jq .
UPLOAD_URL=$(echo $EVENT_DATA | jq -r .release.upload_url)
UPLOAD_URL=${UPLOAD_URL/\{?name,label\}/}
RELEASE_NAME=$(echo $EVENT_DATA | jq -r .release.tag_name)
PROJECT_NAME=$(basename $GITHUB_REPOSITORY)
NAME="${PROJECT_NAME}_${RELEASE_NAME}_${GOOS}_${GOARCH}"

curl \
  -X POST \
  --data-binary $EXECUTABLE_PATH \
  -H 'Content-Type: application/octet-stream' \
  -H "Authorization: Bearer ${GITHUB_TOKEN}" \
  "${UPLOAD_URL}?name=${NAME}${EXT}"
curl \
  -X POST \
  --data $(md5sum $EXECUTABLE_PATH | cut -d ' ' -f 1) \
  -H 'Content-Type: text/plain' \
  -H "Authorization: Bearer ${GITHUB_TOKEN}" \
  "${UPLOAD_URL}?name=${NAME}${EXT}.md5"

tar cvfz tmp.tgz $EXECUTABLE_PATH
curl \
	-X POST \
	--data-binary tmp.tgz \
	-H 'Content-Type: application/gzip' \
	-H "Authorization: Bearer ${GITHUB_TOKEN}" \
	"${UPLOAD_URL}?name=${NAME}.tgz"
curl \
	-X POST \
	--data $(md5sum tmp.tgz | cut -d ' ' -f 1) \
	-H 'Content-Type: text/plain' \
	-H "Authorization: Bearer ${GITHUB_TOKEN}" \
	"${UPLOAD_URL}?name=${NAME}.tgz.md5"

rm -f $EXECUTABLE_PATH tmp.tgz