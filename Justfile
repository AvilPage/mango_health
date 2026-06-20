# Mango Health release commands

# SSH target and domain — update before first deploy
pb_host := "ubuntu@mango-health-api.avilpage.com"
pb_domain := "mango-health-api.avilpage.com"
acme_email := "anand@avilpage.com"

# Bootstrap the t4g.nano (installs Docker + Caddy, one-time setup)
init-server:
    deploymate init --machine {{pb_host}} --email {{acme_email}}

# Deploy / update PocketBase on the server
deploy:
    deploymate deploy --machine {{pb_host}} --email {{acme_email}}

# Start PocketBase server + run iOS app on connected iPhone
dev:
    #!/usr/bin/env bash
    set -e

    # Start PocketBase in background
    echo "==> Starting PocketBase..."
    pocketbase serve --http=0.0.0.0:8090 --hooksDir=pb_migrations &
    PB_PID=$!
    trap "echo '==> Stopping PocketBase...'; kill $PB_PID 2>/dev/null" EXIT INT TERM

    # Wait for PocketBase to be ready
    for i in $(seq 1 10); do
        if curl -sf http://127.0.0.1:8090/api/health > /dev/null 2>&1; then
            echo "==> PocketBase ready at http://0.0.0.0:8090 (LAN: http://192.168.29.160:8090)"
            break
        fi
        sleep 1
    done

    # Find iPhone device ID (prefer wired, falls back to wireless after 5s timeout)
    IPHONE=$(flutter devices --device-timeout 5 2>/dev/null | grep -i "iphone\|ios" | grep -v "simulator\|emulator" | awk -F'•' '{print $2}' | tr -d ' ' | head -1)

    if [ -z "$IPHONE" ]; then
        echo "⚠️  No iPhone found. Plug in your iPhone and unlock it, then re-run."
        echo "    Available devices:"
        flutter devices 2>/dev/null | grep -v "^$"
        exit 1
    fi

    echo "==> Launching on device: $IPHONE"
    flutter run -d "$IPHONE"

# Start only PocketBase (admin UI at http://127.0.0.1:8090/_/)
pb:
    pocketbase serve --http=0.0.0.0:8090 --hooksDir=pb_migrations

# Reset PocketBase superuser password on remote server
# Usage: just reset-password email newpassword
reset-password email password:
    ssh {{pb_host}} "docker exec \$(docker ps --filter name=pocketbase -q | head -1) /pb/pocketbase superuser upsert {{email}} {{password}}"

migrate:
    pocketbase migrate up --hooksDir=pb_migrations

# Enable Google OAuth2 on the users collection.
# Usage: just setup-google <admin_email> <admin_password> <google_client_id> <google_client_secret>
setup-google admin_email admin_password client_id client_secret:
    #!/usr/bin/env bash
    set -e

    PB_URL="https://{{pb_domain}}"

    echo "==> Authenticating as superuser at $PB_URL..."
    TOKEN=$(curl -sf -X POST "$PB_URL/api/collections/_superusers/auth-with-password" \
      -H "Content-Type: application/json" \
      -d "{\"identity\":\"{{admin_email}}\",\"password\":\"{{admin_password}}\"}" \
      | python3 -c "import sys,json; print(json.load(sys.stdin)['token'])")

    echo "==> Fetching users collection..."
    COLLECTION_ID=$(curl -sf "$PB_URL/api/collections/users" \
      -H "Authorization: $TOKEN" \
      | python3 -c "import sys,json; print(json.load(sys.stdin)['id'])")

    echo "==> Enabling Google OAuth2..."
    curl -sf -X PATCH "$PB_URL/api/collections/$COLLECTION_ID" \
      -H "Authorization: $TOKEN" \
      -H "Content-Type: application/json" \
      -d "{
        \"oauth2\": {
          \"enabled\": true,
          \"mappedFields\": {\"id\":\"\",\"name\":\"name\",\"username\":\"\",\"avatarURL\":\"avatar\"},
          \"providers\": [{
            \"name\": \"google\",
            \"clientId\": \"{{client_id}}\",
            \"clientSecret\": \"{{client_secret}}\",
            \"authUrl\": \"\",
            \"tokenUrl\": \"\",
            \"userApiUrl\": \"\",
            \"displayName\": \"\",
            \"pkce\": null
          }]
        }
      }" | python3 -c "import sys,json; d=json.load(sys.stdin); print('✅ Google OAuth2 enabled!' if 'id' in d else f'❌ Error: {d}')"

rel:
    #!/usr/bin/env bash
    set -e

    echo "==> Building APK..."
    flutter build apk --release

    echo "==> Building AAB..."
    flutter build appbundle --release

    APK=build/app/outputs/flutter-apk/app-release.apk
    AAB=build/app/outputs/bundle/release/app-release.aab

    echo "==> Copying to home directory..."
    cp "$APK" ~/mango_health.apk
    cp "$AAB" ~/mango_health.aab
    echo "    ~/mango_health.apk"
    echo "    ~/mango_health.aab"

    DEVICES=$(adb devices 2>/dev/null | grep -v "List of devices" | grep "device$" | awk '{print $1}')
    if [ -z "$DEVICES" ]; then
        echo "==> No ADB devices connected, skipping push."
    else
        for DEVICE in $DEVICES; do
            echo "==> Pushing APK to device: $DEVICE"
            adb -s "$DEVICE" push "$APK" /sdcard/Download/mango_health.apk
        done
    fi

    echo "==> Done."
