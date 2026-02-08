#!/bin/bash
# claw-bench configuration
# Copy this file to config.sh and edit as needed

#=============================================================================
# SSH Mode Configuration
#=============================================================================

# Remote host (user@hostname or user@ip)
# export CLAW_HOST="ubuntu@192.168.1.100"

# Path to SSH private key
# export CLAW_SSH_KEY="$HOME/.ssh/id_rsa"

# Additional SSH options (optional)
# export CLAW_SSH_OPTS="-o StrictHostKeyChecking=no -o ConnectTimeout=10"

#=============================================================================
# API Mode Configuration (not yet implemented)
#=============================================================================

# Gateway URL
# export CLAW_GATEWAY="http://localhost:18789"

# Gateway auth token
# export CLAW_TOKEN="your-gateway-token"

#=============================================================================
# General Configuration
#=============================================================================

# Request timeout in seconds
# export CLAW_TIMEOUT=90

# Session ID prefix (default: bench-{pid}-{timestamp})
# export CLAW_SESSION="my-benchmark-session"
