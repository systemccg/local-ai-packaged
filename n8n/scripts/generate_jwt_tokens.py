#!/usr/bin/env python3
"""
Generate JWT tokens for test users

This script generates JWT tokens for Greg and Joanna to test the multi-tenant RAG Agent.

Requirements:
    pip install pyjwt

Usage:
    python3 generate_jwt_tokens.py
"""

import jwt
import time
from datetime import datetime, timedelta

# JWT Secret - from Supabase configuration
JWT_SECRET = "0xhb7bIcKWuuigEd0rulU4xA6SZ6l93cllRBwB1Y"

# Token expiration (24 hours from now)
EXPIRATION_HOURS = 24

# User data
USERS = {
    "greg": {
        "user_id": "b6015d8d-e018-46b2-a1ff-3598a13f10c1",
        "email": "gwasmuth@gmail.com",
        "tenant_id": "mk3029839",
        "tenant_name": "CoCreators",
        "role": "admin"
    },
    "joanna": {
        "user_id": "9578aa8f-886a-46ea-86ff-e4ccc3d983a1",
        "email": "jowasmuth@gmail.com",
        "tenant_id": "test-tenant-001",
        "tenant_name": "IOM",
        "role": "admin"
    }
}

def generate_jwt_token(user_data):
    """Generate a JWT token for the given user"""
    now = datetime.utcnow()
    exp = now + timedelta(hours=EXPIRATION_HOURS)

    payload = {
        "sub": user_data["user_id"],
        "email": user_data["email"],
        "tenant_id": user_data["tenant_id"],
        "role": user_data["role"],
        "iat": int(now.timestamp()),
        "exp": int(exp.timestamp())
    }

    token = jwt.encode(payload, JWT_SECRET, algorithm="HS256")
    return token

def main():
    print("=" * 80)
    print("JWT Token Generator for Multi-Tenant RAG Agent Testing")
    print("=" * 80)
    print()

    print("⚠️  IMPORTANT: Update JWT_SECRET in this script with your actual secret!")
    print(f"   Current secret: {JWT_SECRET[:20]}...")
    print()
    print("   You can find it in:")
    print("   - Supabase Dashboard → Settings → API → JWT Settings → JWT Secret")
    print("   - Or in your .env file as SUPABASE_JWT_SECRET")
    print()
    print("-" * 80)
    print()

    for name, user_data in USERS.items():
        token = generate_jwt_token(user_data)

        print(f"👤 {user_data['email']} ({user_data['tenant_name']})")
        print(f"   User ID: {user_data['user_id']}")
        print(f"   Tenant: {user_data['tenant_id']}")
        print(f"   Role: {user_data['role']}")
        print()
        print(f"   🔑 JWT Token:")
        print(f"   {token}")
        print()
        print(f"   Environment Variable:")
        print(f"   {name.upper()}_JWT_TOKEN={token}")
        print()
        print("-" * 80)
        print()

    print("📋 Copy these tokens to your n8n environment variables or use them in API calls")
    print()
    print("🧪 Test with curl:")
    print()

    greg_token = generate_jwt_token(USERS["greg"])
    print(f'curl -X POST http://localhost:5678/webhook/rag-chat \\')
    print(f'  -H "Authorization: Bearer {greg_token}" \\')
    print(f'  -H "Content-Type: application/json" \\')
    print(f'  -d \'{{"chatInput": "What documents do I have?", "sessionId": "test-session-1"}}\'')
    print()

if __name__ == "__main__":
    try:
        import jwt
    except ImportError:
        print("❌ Error: PyJWT not installed")
        print()
        print("Install it with:")
        print("  pip install pyjwt")
        exit(1)

    main()
