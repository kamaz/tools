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

while getopts "a:d:" opt; do 
	case $opt in
		a) 
			echo "Application $OPTARG"
			APP_NAME=${OPTARG}
			;;
		d)
			DATABASE_NAME=${OPTARG}
			;;
		\?)
			echo "Invalid option: -$OPTARG"
			exit 1
			;;
		:)
			echo "Invalid option: -$OPTARG" 
		    exit 1
			;;
	esac
done 

if [ "${APP_NAME}x" = x ]; then
	echo "Application is not defined" 	
	exit 1
fi

#
# Backup configuration
############################################################
BACKUP_LIST=(data config attachments confluence.cfg.xml stash-config.properties)
if [ "${DATABASE_NAME}x" = "x" ]; then
	DATABASE_NAME=[TODO: database name to be backup]
fi

#
# AWS configuration
############################################################
ACCESS_KEY_ID=[TODO:add access key id]
SECRET_ACCESS_KEY=[TODO:add secret access key id]
BUCKET_NAME=[TODO:add bucket name]

#
# Application configuration
############################################################
APP_BASE_DIR=[TODO: define app base directury e.g. /application/atlassian]
# if you use current that points to latest version of the product you will 
# need to suffix APP_DIR with '/current'
APP_DIR=${APP_BASE_DIR}/${APP_NAME}
APP_DATA_DIR=${APP_BASE_DIR}/${APP_NAME}/data

#
# DB Configuration
############################################################
DB_USER=[TODO: database username to archive]
DB_PASS=[TODO: password]

#
# Archive configuration
############################################################
BUNDLE_BASE_DIR=[TODO: temporary directory where bundle is created /media/ephemeral0/backup]
BUNDLE_DIR=${BUNDLE_BASE_DIR}/${APP_NAME}
TAG=$(date +'%Y%m%d%H%M%S')
BUNDLE_NAME=${TAG}_${APP_NAME}
BUNDLE_ARCHIVE=${TAG}_${APP_NAME}.tar.gz
BUNDLE=${BUNDLE_DIR}/${BUNDLE_NAME}
#
# data directory where atlassian stores data files
BUNDLE_DATA_DIR=${BUNDLE}/data 

function init() {
	mkdir -p ${BUNDLE}
	mkdir -p ${BUNDLE_DATA_DIR}
}

#mysqldump --databases 
#
# Recover mysql --user=username --password database < dumpfile.sql
#####
function dumpDatabase() {
	echo "Archiving database ${DATABASE_NAME}"
	mysqldump \
		--user=${DB_USER} \
		--password=${DB_USER} \
		--add-drop-database \
		--host=localhost \
		--create-options \
		--single-transaction \
		${DATABASE_NAME} > ${BUNDLE}/database.sql
	
}

function dumpData() {
	echo "Archiving attachments"
	for item in ${BACKUP_LIST[*]}; do
		if [ -f ${APP_DATA_DIR}/${item} ]; then 
			cp ${APP_DATA_DIR}/${item} ${BUNDLE_DATA_DIR}
		fi
		if [ -d ${APP_DATA_DIR}/${item} ]; then 
			cp -r ${APP_DATA_DIR}/${item} ${BUNDLE_DATA_DIR}
		fi
	done
}

function bundle() {
	echo "Bundling"
	cd ${BUNDLE_DIR}
	tar -czf ${BUNDLE_ARCHIVE} ${BUNDLE_NAME}
	rm -rf ${BUNDLE}
}

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
		--upload-file ${BUNDLE}.tar.gz \
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
	init
	dumpDatabase
	dumpData
	bundle
	send
	verify
}

#
# Main method
############################################################
main
