#!/bin/bash
# =============================================================================
# launch-instance.sh - Launch a clawdbot EC2 instance for benchmarking
# =============================================================================
# Usage: ./infra/launch-instance.sh [model-id]
#   model-id: Optional Bedrock model ID to configure (default: mistral.mistral-large-3-675b-instruct)
#
# Outputs instance ID to stdout, logs to stderr
# Returns: 0 on success, 1 on failure

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BENCH_DIR="$(dirname "$SCRIPT_DIR")"

# Load environment
if [ -f "$BENCH_DIR/.env" ]; then
  set -a
  source "$BENCH_DIR/.env"
  set +a
elif [ -f "$BENCH_DIR/../.env.local" ]; then
  # Fall back to parent clawgo .env.local
  set -a
  source "$BENCH_DIR/../.env.local"
  set +a
fi

# Configuration with defaults
AWS_REGION="${AWS_REGION:-us-east-2}"
CLAWGO_AMI_ID="${CLAWGO_AMI_ID:?Error: CLAWGO_AMI_ID not set}"
CLAWGO_SECURITY_GROUP_ID="${CLAWGO_SECURITY_GROUP_ID:?Error: CLAWGO_SECURITY_GROUP_ID not set}"
CLAWGO_KEY_PAIR_NAME="${CLAWGO_KEY_PAIR_NAME:-}"
BENCHMARK_INSTANCE_TYPE="${BENCHMARK_INSTANCE_TYPE:-t3.small}"
BEDROCK_REGION="${BEDROCK_REGION:-us-east-1}"

# Model configuration
MODEL_ID="${1:-mistral.mistral-large-3-675b-instruct}"

# Generate unique identifiers
BENCH_ID="bench-$(date +%s)-$$"
INSTANCE_SECRET=$(uuidgen | tr '[:upper:]' '[:lower:]')

log() {
  echo "[$(date '+%H:%M:%S')] $*" >&2
}

log "Launching benchmark instance..."
log "  Region: $AWS_REGION"
log "  AMI: $CLAWGO_AMI_ID"
log "  Type: $BENCHMARK_INSTANCE_TYPE"
log "  Model: $MODEL_ID"

# Generate UserData script
# This is a minimal bootstrap that configures clawdbot for benchmarking
USERDATA=$(cat <<'USERDATA_EOF'
#!/bin/bash
set -ex

# Configuration from environment
INSTANCE_SECRET="__INSTANCE_SECRET__"
MODEL_ID="__MODEL_ID__"
BEDROCK_REGION="__BEDROCK_REGION__"
AWS_ACCESS_KEY_ID="__AWS_ACCESS_KEY_ID__"
AWS_SECRET_ACCESS_KEY="__AWS_SECRET_ACCESS_KEY__"

# Note: We're inside cloud-init, don't wait for it
# Just give services a moment to settle
sleep 5

# Create benchmark marker
mkdir -p /opt/claw-bench
echo "$INSTANCE_SECRET" > /opt/claw-bench/instance-secret
echo "benchmark" > /opt/claw-bench/mode
date -u +"%Y-%m-%dT%H:%M:%SZ" > /opt/claw-bench/launch-time

# Configure AWS region (credentials come from instance profile)
mkdir -p /home/ubuntu/.aws
cat > /home/ubuntu/.aws/config << AWSEOF
[default]
region = $BEDROCK_REGION
AWSEOF
# Only write credentials if provided (fallback for no instance profile)
if [ -n "$AWS_ACCESS_KEY_ID" ] && [ -n "$AWS_SECRET_ACCESS_KEY" ]; then
  cat > /home/ubuntu/.aws/credentials << AWSEOF
[default]
aws_access_key_id = $AWS_ACCESS_KEY_ID
aws_secret_access_key = $AWS_SECRET_ACCESS_KEY
AWSEOF
  chmod 600 /home/ubuntu/.aws/credentials
fi
chown -R ubuntu:ubuntu /home/ubuntu/.aws

# Patch clawdbot config if patch script exists (fast path)
if [ -f /opt/clawgo/patch-config.sh ]; then
  /opt/clawgo/patch-config.sh "$INSTANCE_SECRET" "benchmark" "http://localhost:8222" \
    "$AWS_ACCESS_KEY_ID" "$AWS_SECRET_ACCESS_KEY" "$BEDROCK_REGION" \
    "amazon-bedrock/$MODEL_ID" "$(echo $MODEL_ID | cut -d. -f1)"
else
  # Legacy path: Generate minimal clawdbot.json
  mkdir -p /home/ubuntu/.clawdbot

  # Create required .env file (systemd expects this)
  cat > /home/ubuntu/.clawdbot/.env << ENVEOF
# Clawdbot environment for benchmarking
CLAWDBOT_MODE=benchmark
AWS_DEFAULT_REGION=$BEDROCK_REGION
ENVEOF

  cat > /home/ubuntu/.clawdbot/clawdbot.json << CLAWEOF
{
  "gateway": {
    "port": 18789,
    "mode": "local",
    "bind": "lan",
    "auth": { "token": "$INSTANCE_SECRET" }
  },
  "models": {
    "providers": {
      "amazon-bedrock": {
        "baseUrl": "https://bedrock-runtime.$BEDROCK_REGION.amazonaws.com",
        "api": "bedrock-converse-stream",
        "auth": "aws-sdk",
        "models": [
          {
            "id": "$MODEL_ID",
            "name": "benchmark-model",
            "input": ["text"],
            "contextWindow": 131072,
            "maxTokens": 8192
          }
        ]
      }
    }
  },
  "agents": {
    "defaults": {
      "model": {
        "primary": "amazon-bedrock/$MODEL_ID"
      }
    }
  },
  "tools": {
    "web": {
      "fetch": {"enabled": true, "maxChars": 50000}
    }
  }
}
CLAWEOF
  chown -R ubuntu:ubuntu /home/ubuntu/.clawdbot
fi

# Clear any stale sessions
rm -rf /home/ubuntu/.clawdbot/sessions/* 2>/dev/null || true
rm -rf /home/ubuntu/.clawdbot/agents/*/sessions/* 2>/dev/null || true

# Stop any running clawdbot
systemctl stop clawdbot 2>/dev/null || true
pkill -f clawdbot || true
sleep 2

# Start clawdbot service
systemctl start clawdbot
systemctl enable clawdbot

# Wait for gateway to be ready
for i in $(seq 1 60); do
  if curl -sf http://localhost:18789/ >/dev/null 2>&1; then
    echo "Gateway ready after ${i}s" >> /opt/claw-bench/boot.log
    echo "ready" > /opt/claw-bench/status
    exit 0
  fi
  sleep 2
done

echo "Gateway timeout" >> /opt/claw-bench/boot.log
echo "timeout" > /opt/claw-bench/status
exit 1
USERDATA_EOF
)

# Replace placeholders in UserData
USERDATA="${USERDATA//__INSTANCE_SECRET__/$INSTANCE_SECRET}"
USERDATA="${USERDATA//__MODEL_ID__/$MODEL_ID}"
USERDATA="${USERDATA//__BEDROCK_REGION__/$BEDROCK_REGION}"
USERDATA="${USERDATA//__AWS_ACCESS_KEY_ID__/${AWS_ACCESS_KEY_ID:-}}"
USERDATA="${USERDATA//__AWS_SECRET_ACCESS_KEY__/${AWS_SECRET_ACCESS_KEY:-}}"

# Base64 encode UserData
USERDATA_B64=$(echo "$USERDATA" | base64)

# Build AWS CLI command
AWS_CMD="aws ec2 run-instances --region $AWS_REGION"
AWS_CMD+=" --image-id $CLAWGO_AMI_ID"
AWS_CMD+=" --instance-type $BENCHMARK_INSTANCE_TYPE"
AWS_CMD+=" --security-group-ids $CLAWGO_SECURITY_GROUP_ID"
AWS_CMD+=" --user-data $USERDATA_B64"
AWS_CMD+=" --metadata-options HttpTokens=required,HttpPutResponseHopLimit=1,HttpEndpoint=enabled"
AWS_CMD+=" --iam-instance-profile Name=clawgo-relay-server"
AWS_CMD+=" --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=claw-bench-$BENCH_ID},{Key=ManagedBy,Value=claw-bench},{Key=BenchId,Value=$BENCH_ID},{Key=Model,Value=$MODEL_ID}]'"

# Add key pair if specified
if [ -n "$CLAWGO_KEY_PAIR_NAME" ]; then
  AWS_CMD+=" --key-name $CLAWGO_KEY_PAIR_NAME"
fi

AWS_CMD+=" --query 'Instances[0].InstanceId' --output text"

log "Launching EC2 instance..."
INSTANCE_ID=$(eval $AWS_CMD)

if [ -z "$INSTANCE_ID" ] || [ "$INSTANCE_ID" = "None" ]; then
  log "ERROR: Failed to launch instance"
  exit 1
fi

log "Instance launched: $INSTANCE_ID"

# Save instance metadata
mkdir -p "$BENCH_DIR/.instances"
cat > "$BENCH_DIR/.instances/$INSTANCE_ID.json" << EOF
{
  "instanceId": "$INSTANCE_ID",
  "benchId": "$BENCH_ID",
  "modelId": "$MODEL_ID",
  "instanceSecret": "$INSTANCE_SECRET",
  "region": "$AWS_REGION",
  "launchTime": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
}
EOF

# Output instance ID for scripting
echo "$INSTANCE_ID"
