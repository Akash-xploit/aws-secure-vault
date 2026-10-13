# Run from the repo root: source tests/env.sh
source .venv/bin/activate
export USER_POOL_ID=$(terraform -chdir=terraform output -raw user_pool_id)
export USER_POOL_CLIENT_ID=$(terraform -chdir=terraform output -raw user_pool_client_id)
export API=$(terraform -chdir=terraform output -raw api_url)
echo "API=$API"
