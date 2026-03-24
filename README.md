TOKEN=$(az account get-access-token --query accessToken --output tsv)
SUB_ID=$(az account show --query id --output tsv)
APIM_URL="https://uniview-apim-new.azure-api.net/rag/api/query"
DEV_SUB_KEY="xxxxxxxxxxxxxxxxxxxxxxxx"

echo "================================================"
echo "  SECURITY & COMPLIANCE TEST REPORT"
echo "  $(date)"
echo "================================================"

# Test 1 - Auth
echo ""
echo "--- TEST 1: Authentication ---"
HTTP=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$APIM_URL" \
  -H "Content-Type: application/json" \
  -d '{"question": "test"}')
[ "$HTTP" = "401" ] && echo "✅ PASS - No key returns 401" || echo "❌ FAIL - Expected 401 got $HTTP"

HTTP=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$APIM_URL" \
  -H "Ocp-Apim-Subscription-Key: wrong-key" \
  -H "Content-Type: application/json" \
  -d '{"question": "test"}')
[ "$HTTP" = "401" ] && echo "✅ PASS - Invalid key returns 401" || echo "❌ FAIL - Expected 401 got $HTTP"

# Test 2 - HTTP Method
echo ""
echo "--- TEST 2: HTTP Method Validation ---"
HTTP=$(curl -s -o /dev/null -w "%{http_code}" -X GET "$APIM_URL" \
  -H "Ocp-Apim-Subscription-Key: $DEV_SUB_KEY")
[ "$HTTP" = "404" ] || [ "$HTTP" = "405" ] && echo "✅ PASS - GET returns $HTTP" || echo "❌ FAIL - Expected 404/405 got $HTTP"

HTTP=$(curl -s -o /dev/null -w "%{http_code}" -X DELETE "$APIM_URL" \
  -H "Ocp-Apim-Subscription-Key: $DEV_SUB_KEY")
[ "$HTTP" = "404" ] || [ "$HTTP" = "405" ] && echo "✅ PASS - DELETE returns $HTTP" || echo "❌ FAIL - Expected 404/405 got $HTTP"

# Test 3 - Security Headers
echo ""
echo "--- TEST 3: Security Headers ---"
HEADERS=$(curl -si -X POST "$APIM_URL" \
  -H "Ocp-Apim-Subscription-Key: $DEV_SUB_KEY" \
  -H "Content-Type: application/json" \
  -d '{"question": "test"}')

echo "$HEADERS" | grep -q "X-Frame-Options: DENY" \
  && echo "✅ PASS - X-Frame-Options: DENY" \
  || echo "❌ FAIL - X-Frame-Options missing"

echo "$HEADERS" | grep -q "X-Content-Type-Options: nosniff" \
  && echo "✅ PASS - X-Content-Type-Options: nosniff" \
  || echo "❌ FAIL - X-Content-Type-Options missing"

echo "$HEADERS" | grep -q "X-XSS-Protection" \
  && echo "✅ PASS - X-XSS-Protection present" \
  || echo "❌ FAIL - X-XSS-Protection missing"

echo "$HEADERS" | grep -q "Strict-Transport-Security" \
  && echo "✅ PASS - HSTS present" \
  || echo "❌ FAIL - HSTS missing"

echo "$HEADERS" | grep -q "Server:" \
  && echo "❌ FAIL - Server header exposed" \
  || echo "✅ PASS - Server header removed"

# Test 4 - Cache
echo ""
echo "--- TEST 4: Cache ---"
RESP1=$(curl -si -X POST "$APIM_URL" \
  -H "Ocp-Apim-Subscription-Key: $DEV_SUB_KEY" \
  -H "Content-Type: application/json" \
  -d '{"question": "cache test question"}')
CACHE1=$(echo "$RESP1" | grep "X-Cache:" | awk '{print $2}' | tr -d '\r')

RESP2=$(curl -si -X POST "$APIM_URL" \
  -H "Ocp-Apim-Subscription-Key: $DEV_SUB_KEY" \
  -H "Content-Type: application/json" \
  -d '{"question": "cache test question"}')
CACHE2=$(echo "$RESP2" | grep "X-Cache:" | awk '{print $2}' | tr -d '\r')

[ "$CACHE1" = "MISS" ] && echo "✅ PASS - First request Cache MISS" || echo "❌ FAIL - Expected MISS got $CACHE1"
[ "$CACHE2" = "HIT" ] && echo "✅ PASS - Second request Cache HIT" || echo "❌ FAIL - Expected HIT got $CACHE2"

# Test 5 - Backend Cycling
echo ""
echo "--- TEST 5: Backend Cycling (4 B1 then 4 B2) ---"
sleep 5
PREV_BACKEND=""
SWITCH_COUNT=0
for i in {1..8}; do
  RESPONSE=$(curl -si -X POST "$APIM_URL" \
    -H "Ocp-Apim-Subscription-Key: $DEV_SUB_KEY" \
    -H "Content-Type: application/json" \
    -d "{\"question\": \"cycle test $i $(date +%s%N)\"}")
  BACKEND=$(echo "$RESPONSE" | grep "X-Backend-Active:" | awk '{print $2}' | tr -d '\r')
  echo "  Request $i → $BACKEND"
  if [ "$BACKEND" != "$PREV_BACKEND" ] && [ -n "$PREV_BACKEND" ]; then
    SWITCH_COUNT=$((SWITCH_COUNT + 1))
  fi
  PREV_BACKEND=$BACKEND
done
[ "$SWITCH_COUNT" -ge 1 ] && echo "✅ PASS - Backend switched $SWITCH_COUNT time(s)" || echo "❌ FAIL - No backend switching detected"

# Test 6 - Circuit Breaker
echo ""
echo "--- TEST 6: Circuit Breaker ---"
curl -s -o /dev/null -X PUT \
  "https://management.azure.com/subscriptions/$SUB_ID/resourceGroups/rg-intertek-eu2-dev/providers/Microsoft.ApiManagement/service/uniview-apim-new/backends/fastapi-backend-1?api-version=2023-05-01-preview" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"properties": {"url": "https://broken.azurecontainerapps.io", "protocol": "http"}}'

sleep 3

RESPONSE=$(curl -si -X POST "$APIM_URL" \
  -H "Ocp-Apim-Subscription-Key: $DEV_SUB_KEY" \
  -H "Content-Type: application/json" \
  -d "{\"question\": \"circuit test $(date +%s%N)\"}")
HTTP=$(echo "$RESPONSE" | grep "HTTP/" | awk '{print $2}')
BACKEND=$(echo "$RESPONSE" | grep "X-Backend-Active:" | awk '{print $2}' | tr -d '\r')

[ "$HTTP" = "200" ] && [ "$BACKEND" = "backend2" ] \
  && echo "✅ PASS - Circuit tripped, failover to backend2" \
  || echo "❌ FAIL - Expected backend2 got HTTP=$HTTP Backend=$BACKEND"

# Restore backend 1
curl -s -o /dev/null -X PUT \
  "https://management.azure.com/subscriptions/$SUB_ID/resourceGroups/rg-intertek-eu2-dev/providers/Microsoft.ApiManagement/service/uniview-apim-new/backends/fastapi-backend-1?api-version=2023-05-01-preview" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"properties": {"url": "https://ca-fastapi.lemonbay-bab22214.eastus2.azurecontainerapps.io", "protocol": "http"}}'

echo "  Backend 1 restored ✅"

# Test 7 - Subscription Key Not in Response
echo ""
echo "--- TEST 7: Sensitive Data Not Exposed ---"
RESP=$(curl -si -X POST "$APIM_URL" \
  -H "Ocp-Apim-Subscription-Key: $DEV_SUB_KEY" \
  -H "Content-Type: application/json" \
  -d '{"question": "test"}')
echo "$RESP" | grep -qi "subscription-key\|api-key\|$DEV_SUB_KEY" \
  && echo "❌ FAIL - Subscription key exposed in response" \
  || echo "✅ PASS - Subscription key not exposed"

# Test 8 - HTTPS Only
echo ""
echo "--- TEST 8: HTTPS Enforced ---"
HTTP=$(curl -s -o /dev/null -w "%{http_code}" -X POST \
  "http://uniview-apim-new.azure-api.net/rag/api/query" \
  -H "Ocp-Apim-Subscription-Key: $DEV_SUB_KEY" \
  -H "Content-Type: application/json" \
  -d '{"question": "test"}' 2>/dev/null || echo "000")
[ "$HTTP" = "000" ] || [ "$HTTP" = "301" ] || [ "$HTTP" = "403" ] \
  && echo "✅ PASS - HTTP not accessible (got $HTTP)" \
  || echo "⚠️  CHECK - HTTP returned $HTTP"

echo ""
echo "================================================"
echo "  TEST REPORT COMPLETE"
echo "================================================"
