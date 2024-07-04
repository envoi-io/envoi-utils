#!/usr/bin/env bash

#ENVOI_APP_NAME=""
#ENVOI_ENV_NAME=""
#
#if [ -n "$ENVOI_APP_NAME" ]; then
#  echo "Error: ENVOI_APP_NAME must be set."
#  exit 1
#fi

CONTENT_ADMIN_APP_URL=${CONTENT_ADMIN_APP_URL:-"http://localhost:3000/admin"}
CONTENT_SCREENING_APP_URL=${CONTENT_SCREENING_APP_URL:-"http://localhost:3000/screening"}
CONTENT_SUBMISSION_APP_URL=${CONTENT_SUBMISSION_APP_URL:-"http://localhost:3000/submission"}

if [ -z "$ENVOI_MONGODB_CONNECTION_STRING" ]; then
  echo "Error: ENVOI_MONGODB_CONNECTION_STRING must be set."
  exit 1
fi

ENVOI_COGNITO_CONFIG_JSON="$(cat <<EOF
{
  "screeningRedirectURL": "${CONTENT_SCREENING_APP_URL}",
  "submissionRedirectURL": "${CONTENT_SUBMISSION_APP_URL}",
  "adminRedirectURL": "${CONTENT_ADMIN_APP_URL}",
  "oauth2TokenUrl": "https://${ENVOI_COGNITO_USER_POOL_HOST}/oauth2/token",
  "loginCognitoUrl": "https://${ENVOI_COGNITO_USER_POOL_HOST}/login",
  "signupCognitoUrl": "https://${ENVOI_COGNITO_USER_POOL_HOST}/signup",
  "cognitoUserPoolId": "${ENVOI_COGNITO_USER_POOL_ID}",
  "cognitoWebDomain": "${ENVOI_COGNITO_USER_POOL_HOST}",
  "cognitoUrl": "https://${ENVOI_COGNITO_USER_POOL_HOST}/login",
  "cognitoTokenType": "token",
  "clientId": "${ENVOI_COGNITO_USER_POOL_CLIENT_ID}",
  "clientSecret": "${ENVOI_COGNITO_USER_POOL_CLIENT_SECRET}",
  "keys": { "keys": [] }
}
EOF
)"

ENVOI_MONGODB_COGNITO_QUERY="$(cat <<EOF
db.flixConfig.updateOne({ }, { \$set: { "config.authentication.key": "cognito", "config.authentication.cognito": ${ENVOI_COGNITO_CONFIG_JSON} } });
EOF
)"
echo "${ENVOI_MONGODB_COGNITO_QUERY}"
mongosh "${ENVOI_MONGODB_CONNECTION_STRING}" --eval "${ENVOI_MONGODB_COGNITO_QUERY}"
