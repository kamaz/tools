#!/bin/bash
############################################################
#
#  Copyright 2012 Kamil Zuzda
#
#   Licensed under the Apache License, Version 2.0 (the "License");
#   you may not use this file except in compliance with the License.
#   You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
#   Unless required by applicable law or agreed to in writing, software
#   distributed under the License is distributed on an "AS IS" BASIS,
#   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#   See the License for the specific language governing permissions and
#   limitations under the License.
#
############################################################

#
# AWS configuration
############################################################
ACCESS_KEY_ID=[TODO:add access key id]
SECRET_ACCESS_KEY=[TODO:add secret access key id]
BUCKET_NAME=[TODO:add bucket name]

#
# Archive configuration
############################################################
BUNDLE_DIR=[TODO:you track backup directory]
BUNDLE_ARCHIVE=$(ls -tr ${BUNDLE_DIR} | tail -n 1)
BUNDLE=${BUNDLE_DIR}/${BUNDLE_ARCHIVE}

#
# http://docs.aws.amazon.com/AmazonS3/2006-03-01/dev/RESTAuthentication.html
#
# Authorization = "AWS" + " " + AWSAccessKeyId + ":" + Signature;
# Signature = Base64( HMAC-SHA1( YourSecretAccessKeyID, UTF-8-Encoding-Of( StringToSign ) ) );
# 
# StringToSign = HTTP-Verb + "\n" +
# 	Content-MD5 + "\n" +
# 	Content-Type + "\n" +
# 	Date + "\n" +
# 	CanonicalizedAmzHeaders +
# 	CanonicalizedResource;
# 
# CanonicalizedResource = [ "/" + Bucket ] +
# 	<HTTP-Request-URI, from the protocol name up to the query string> +
# 	[ sub-resource, if present. For example "?acl", "?location", "?logging", or "?torrent"];
# 
# CanonicalizedAmzHeaders = <described below>
#

function send() {
	echo "Sending"
	#
	# http://docs.aws.amazon.com/AmazonS3/latest/API/RESTObjectPUT.html 
	# $(du -b /media/ephemeral0/backup/confluence/20130206002221_confluence.tar.gz | awk '{print $1}'))
	#############################################################################
	current_time=$(date +'%a, %d %b %Y %H:%M:%S %Z')
	signature=$(printf "PUT\n\n\n%s\n/%s/%s" "${current_time}" "${BUCKET_NAME}" "${BUNDLE_ARCHIVE}"| openssl dgst -sha1 -hmac ${SECRET_ACCESS_KEY} -binary | openssl enc -base64)

	curl \
		--request PUT \
		--header "Date: ${current_time}" \
		--header "Authorization: AWS ${ACCESS_KEY_ID}:${signature}" \
		--upload-file ${BUNDLE} \
		https://${BUCKET_NAME}.s3.amazonaws.com/${BUNDLE_ARCHIVE}
}


function verify() {
	echo "Verifying"
	current_time=$(date +'%a, %d %b %Y %H:%M:%S %Z')
	signature=$(printf "HEAD\n\n\n%s\n/%s/%s" "${current_time}" "${BUCKET_NAME}" "${BUNDLE_ARCHIVE}"| openssl dgst -sha1 -hmac ${SECRET_ACCESS_KEY} -binary | openssl enc -base64)
	response_code=$(curl    --head \
							--silent \
							--write-out %{http_code} \
							-o /dev/null \
							--request HEAD \
							--header "Date: ${current_time}" \
							--header "Authorization: AWS ${ACCESS_KEY_ID}:${signature}" \
							https://${BUCKET_NAME}.s3.amazonaws.com/${BUNDLE_ARCHIVE})
	if [ "${response_code}" != "200" ]; then
		echo "File has not been backed up"
		exit 2
	fi
}

function main() {
	send
	verify
}

#
# Main method
############################################################
main
