#!/bin/bash
set -uo pipefail

NS="devops-portfolio"
ERRORS=0

ok() { echo "  [OK]   $1"; }
fail() { echo "  [FAIL] $1"; ERRORS=$((ERRORS+1)); }

echo "================================================="
echo "  VERIFICACIÓN HELM & INGRESS (TP10B - RENDER)"
echo "================================================="
echo ""

echo "--- 1. Validación de Renderizado (Render First) ---"
if helm template mi-app ./devops-portfolio -f values-prod.yaml > /dev/null 2>&1; then
    ok "Helm template renderizó las plantillas sin errores"
else
    fail "Error al ejecutar helm template"
fi
echo ""

echo "--- 2. Estado del Release de Helm ---"
STATUS=$(helm status mi-app -n $NS 2>/dev/null | grep "STATUS:" | awk '{print $2}')
if [ "$STATUS" = "deployed" ]; then
    ok "Release 'mi-app' -> $STATUS"
else
    fail "Release 'mi-app' -> $STATUS"
fi
echo ""

echo "--- 3. Pods en Kubernetes ---"
kubectl get pods -n $NS --no-headers 2>/dev/null | while read line; do
    NAME=$(echo $line | awk '{print $1}')
    READY=$(echo $line | awk '{print $2}')
    POD_STATUS=$(echo $line | awk '{print $3}')
    if [ "$POD_STATUS" = "Running" ]; then
        ok "$NAME -> $POD_STATUS ($READY)"
    else
        fail "$NAME -> $POD_STATUS ($READY)"
    fi
done
echo ""

echo "--- 4. Ingress y Enrutamiento Capa 7 ---"
INGRESS_HOST=$(kubectl get ingress -n $NS -o jsonpath='{.items[0].spec.rules[0].host}' 2>/dev/null)
if [ -n "$INGRESS_HOST" ]; then
    ok "Ingress 'mi-app-devops-portfolio-ingress' configurado para host: $INGRESS_HOST"
else
    fail "No se encontró configuración de Ingress"
fi
echo ""

echo "--- 5. Pruebas de Salud HTTP vía Ingress ---"
for PATH_ENDPOINT in "/" "/health" "/api/notes"; do
    CODE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 "http://devops-portfolio.dev:30080$PATH_ENDPOINT" 2>/dev/null || echo "000")
    if [ "$CODE" = "200" ]; then
        ok "Endpoint $PATH_ENDPOINT -> HTTP $CODE"
    else
        fail "Endpoint $PATH_ENDPOINT -> HTTP $CODE"
    fi
done
echo ""

if [ "$ERRORS" -eq 0 ]; then
    echo "=== TODO PERFECTO: Todos los checks pasaron ==="
else
    echo "=== ATENCIÓN: $ERRORS checks fallaron ==="
fi
