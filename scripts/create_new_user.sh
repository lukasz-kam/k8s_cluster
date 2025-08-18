#!/bin/bash

if [ "$#" -ne 2 ]; then
  echo "Error: this scripts requires 2 arguments."
  echo "Usage: $0 <INSTANCE_ID> <USER_TO_CREATE>"
  exit 1
fi

INSTANCE_ID="$1"
CLUSTER_USER="$2"
S3_BUCKET="my-scripts-bucket-98634"
SCRIPT_NAME="new_cluster_user.sh"
KUBECONFIG_FILE="/tmp/kubeconfig-$CLUSTER_USER.yaml"
KUBECONFIG_LOCAL="kubeconfig-readonly.yaml"

[ -f "$KUBECONFIG_LOCAL" ] && rm "$KUBECONFIG_LOCAL"

COMMAND_ID=$(aws ssm send-command \
  --targets "Key=instanceIds,Values=$INSTANCE_ID" \
  --document-name "AWS-RunShellScript" \
  --comment "Copying and running create_user.sh" \
  --parameters "{\"commands\":[\"sudo aws s3 cp s3://$S3_BUCKET/$SCRIPT_NAME /tmp/$SCRIPT_NAME\",\"sudo chmod +x /tmp/$SCRIPT_NAME\",\"sudo /tmp/$SCRIPT_NAME $CLUSTER_USER\"]}" \
  --query "Command.CommandId" \
  --output text)

i=1
while [ $i -le 5 ]; do
  STATUS=$(aws ssm get-command-invocation \
    --command-id "$COMMAND_ID" \
    --instance-id "$INSTANCE_ID" \
    --query "Status" \
    --output text)

  if [ "$STATUS" != "Success" ]; then
    echo "Copying status: $STATUS"
  fi

  if [ "$STATUS" = "Success" ]; then
    echo "Script has been successfully downloaded to the instance."
    break
  fi

  i=$((i + 1))
  sleep 5
done

j=1
while [ $j -le 5 ]; do
  COMMAND_IDD=$(aws ssm send-command \
    --targets "Key=instanceIds,Values=$INSTANCE_ID" \
    --document-name "AWS-RunShellScript" \
    --parameters '{"commands":["sudo cat '"$KUBECONFIG_FILE"'"]}' \
    --query "Command.CommandId" --output text)

  aws ssm get-command-invocation \
    --command-id "$COMMAND_IDD" \
    --instance-id "$INSTANCE_ID" \
    --query "StandardOutputContent" \
    --output text > "$KUBECONFIG_LOCAL"

  if grep -q "apiVersion" "$KUBECONFIG_LOCAL"; then
    echo "The valid kubeconfig file has been downloaded."
    exit 0
  fi

  j=$((j + 1))
  echo "KUBECONFIG is not ready. Waiting 5 seconds before retrying..."
  sleep 5
done

echo "Error: Failed to download the correct KUBECONFIG file after multiple attempts."
