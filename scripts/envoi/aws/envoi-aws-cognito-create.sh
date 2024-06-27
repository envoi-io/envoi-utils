#!/usr/bin/env bash
# Create AWS Cognito resources needed by Envoi

DEFAULT_CALLBACK_URL="http://localhost:3000"

ENVOI_COGNITO_POOL_NAME=${ENVOI_COGNITO_POOL_NAME:-envoi}
ENVOI_COGNITO_USER_POOL_CLIENT_NAME=${ENVOI_COGNITO_USER_POOL_CLIENT_NAME:-envoi}
ENVOI_COGNITO_USER_POOL_CLIENT_CALLBACK_URL=${ENVOI_COGNITO_USER_POOL_CLIENT_CALLBACK_URL:-$DEFAULT_CALLBACK_URL}

ENVOI_VERBOSE_STYLE=${ENVOI_VERBOSE_COLOR:-"[0;33m"}  # yellow

log() {
  echo "$*"
}

verbose() {
  [[ "$VERBOSE" == "true" ]] && echo -e "\033${ENVOI_VERBOSE_STYLE}$1\033[0m"
}

ENVOI_COGNITO_CREATE_USER_POOL_RESPONSE=$(aws cognito-idp create-user-pool --no-cli-pager \
    --pool-name "$ENVOI_COGNITO_POOL_NAME" \
    --auto-verified-attributes email \
    --username-attributes email)
# aws cognito-idp create-user-pool seems to always return exit code 0
if [[ -z $ENVOI_COGNITO_CREATE_USER_POOL_RESPONSE ]]; then
  log "Error creating user pool"
  exit 1
fi
verbose "${ENVOI_COGNITO_CREATE_USER_POOL_RESPONSE}"

export ENVOI_COGNITO_CREATE_USER_POOL_RESPONSE
ENVOI_COGNITO_USER_POOL_ID=$(echo "$ENVOI_COGNITO_CREATE_USER_POOL_RESPONSE" | jq -r .UserPool.Id)

ENVOI_COGNITO_CREATE_USER_POOL_CLIENT_RESPONSE=$(aws cognito-idp create-user-pool-client \
                                                     --user-pool-id "$ENVOI_COGNITO_USER_POOL_ID" \
                                                     --client-name "$ENVOI_COGNITO_USER_POOL_CLIENT_NAME" \
                                                     --allowed-o-auth-flows-user-pool-client \
                                                     --allowed-o-auth-flows code implicit \
                                                     --allowed-o-auth-scopes openid profile email phone aws.cognito.signin.user.admin \
                                                     --prevent-user-existence-errors "ENABLED" \
                                                     --supported-identity-providers COGNITO \
                                                     --callback-urls "$ENVOI_COGNITO_USER_POOL_CLIENT_CALLBACK_URL" \
                                                     --generate-secret)
if [[ -z $ENVOI_COGNITO_CREATE_USER_POOL_CLIENT_RESPONSE ]]; then
  log "Error creating user pool client"
  exit 1
fi

export ENVOI_COGNITO_CREATE_USER_POOL_CLIENT_RESPONSE
verbose "$ENVOI_COGNITO_CREATE_USER_POOL_CLIENT_RESPONSE"
ENVOI_COGNITO_USER_POOL_CLIENT_ID=$(echo "$ENVOI_COGNITO_CREATE_USER_POOL_CLIENT_RESPONSE" | jq -r .UserPoolClient.ClientId)
ENVOI_COGNITO_USER_POOL_CLIENT_SECRET=$(echo "$ENVOI_COGNITO_CREATE_USER_POOL_CLIENT_RESPONSE" | jq -r .UserPoolClient.ClientSecret)

ENVOI_COGNITO_USER_POOL_HOST="${ENVOI_COGNITO_POOL_NAME}.auth.us-east-1.amazoncognito.com"
ENVOI_COGNITO_USER_POOL_URL="https://$ENVOI_COGNITO_USER_POOL_HOST"
ENVOI_COGNITO_USER_POOL_LOGIN_URL="$ENVOI_COGNITO_USER_POOL_URL/login"
ENVOI_COGNITO_USER_POOL_SIGNUP_URL="$ENVOI_COGNITO_USER_POOL_URL/signup"

export ENVOI_COGNITO_USER_POOL_CLIENT_ID
export ENVOI_COGNITO_USER_POOL_CLIENT_SECRET

export ENVOI_COGNITO_USER_POOL_ID
export ENVOI_COGNITO_POOL_NAME
export ENVOI_COGNITO_USER_POOL_HOST
export ENVOI_COGNITO_USER_POOL_URL
export ENVOI_COGNITO_USER_POOL_LOGIN_URL
export ENVOI_COGNITO_USER_POOL_SIGNUP_URL

verbose "$(cat <<EOF
{
  "cognito": {
    "userPool": {
      "id": "$ENVOI_COGNITO_USER_POOL_ID",
      "name": "$ENVOI_COGNITO_POOL_NAME",
      "host": "$ENVOI_COGNITO_USER_POOL_HOST",
      "url": "$ENVOI_COGNITO_USER_POOL_URL",
      "loginUrl": "$ENVOI_COGNITO_USER_POOL_LOGIN_URL",
      "signupUrl": "$ENVOI_COGNITO_USER_POOL_SIGNUP_URL",
      "client": {
        "id": "$ENVOI_COGNITO_USER_POOL_CLIENT_ID",
        "name": "$ENVOI_COGNITO_USER_POOL_CLIENT_NAME",
        "secret": "$ENVOI_COGNITO_USER_POOL_CLIENT_SECRET",
        "callbackUrl": "$ENVOI_COGNITO_USER_POOL_CLIENT_CALLBACK_URL"
      }
    }
  }
}
EOF
)"

#    "userPoolId": "$ENVOI_COGNITO_USER_POOL_ID",
#    "userPoolHost": "$ENVOI_COGNITO_USER_POOL_HOST",
#    "userPoolUrl": "$ENVOI_COGNITO_USER_POOL_URL",
#    "userPoolLoginUrl": "$ENVOI_COGNITO_USER_POOL_LOGIN_URL",
#    "userPoolSignupUrl": "$ENVOI_COGNITO_USER_POOL_SIGNUP_URL",
#    "userPoolClientId": "$ENVOI_COGNITO_USER_POOL_CLIENT_ID",
#    "userPoolClientSecret": "$ENVOI_COGNITO_USER_POOL_CLIENT_SECRET"
