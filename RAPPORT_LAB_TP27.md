# TP 27 - Rapport de Lab : Load Testing, Concurrency & Observability

## 📋 Résumé des Tests Effectués

---

## 1. Test de Concurrence (Load Test - 50 requêtes)

### Commande Exécutée
```powershell
.\scripts\loadtest-proof.ps1 -BookId 1 -ConcurrentRequests 50
```

### Résultats
```
========================================
  LOAD TEST - TP27 Proof Collection   
========================================
Book ID: 1
Concurrent Requests: 50
Ports: 8081, 8083, 8084

--- Initial Book State ---
Book: {"id":1,"title":"Load Test Book","author":"Author","stock":10,"price":29.99}
Initial Stock: 10

--- Launching 50 Concurrent Borrow Requests ---
Waiting for all requests to complete...

========================================
           RESULTS                     
========================================
Total Requests:    50
SUCCESS:           10
CONFLICTS (409):   40

--- Final Book State ---
Book: {"id":1,"title":"Load Test Book","author":"Author","stock":0,"price":29.99}
Final Stock: 0

========================================
          VALIDATION                   
========================================
[OK] Stock is non-negative: 0
[OK] Final stock = 0 (as expected)
[OK] 10 successful borrows = initial stock (10)
[OK] 40 conflicts (expected: >= 40)

========================================
  CONCLUSION: Pessimistic lock works!  
========================================
```

---

## 2. Stock Final = 0 (Vérification)

### Commande
```bash
curl http://localhost:8081/api/books
```

### Résultat
```json
[{"id":1,"title":"Load Test Book","author":"Author","stock":0,"price":29.99}]
```

✅ **Stock = 0** - Le verrou pessimiste a fonctionné correctement.

---

## 3. Test Fallback - Circuit Breaker

### Étapes
1. Arrêt du pricing-service :
```bash
docker-compose stop pricing-service
```

2. Appel au endpoint prix :
```bash
curl http://localhost:8081/api/books/1/pricing
```

### Résultat
```json
{"price":0.0,"bookId":1}
```

✅ **price = 0.0** - Le fallback fonctionne quand pricing-service est down.

---

## 4. Actuator Metrics - Resilience4j

### Commande
```bash
curl http://localhost:8081/actuator/metrics
```

### Métriques Resilience4j Disponibles
```
resilience4j.circuitbreaker.buffered.calls
resilience4j.circuitbreaker.calls
resilience4j.circuitbreaker.failure.rate
resilience4j.circuitbreaker.not.permitted.calls
resilience4j.circuitbreaker.slow.call.rate
resilience4j.circuitbreaker.slow.calls
resilience4j.circuitbreaker.state
resilience4j.retry.calls
```

### État du Circuit Breaker
```bash
curl http://localhost:8081/actuator/circuitbreakers
```

```json
{
  "circuitBreakers": {
    "pricingService": {
      "failureRate": "-1.0%",
      "bufferedCalls": 1,
      "failedCalls": 1,
      "state": "CLOSED"
    }
  }
}
```

---

## 📝 Conclusion (5 lignes)

### Pourquoi le verrou DB est nécessaire en multi-instances ?

Le verrou pessimiste (`SELECT ... FOR UPDATE`) est **indispensable en architecture multi-instances** car plusieurs instances de book-service (8081, 8083, 8084) partagent la **même base de données MySQL**. Sans ce verrou, des requêtes concurrentes pourraient lire la même valeur de stock simultanément, puis toutes décrémenter, causant un **stock négatif** (race condition). Le verrou au niveau de la base de données garantit qu'une seule transaction peut modifier le stock à la fois, **indépendamment du nombre d'instances** de l'application.

### Quel est le rôle du Circuit Breaker et du Fallback ?

Le **Circuit Breaker** protège l'application contre les **défaillances en cascade** lorsqu'un service externe (pricing-service) est indisponible. Il surveille le taux d'échecs et "ouvre" le circuit après un seuil défini (50% d'échecs sur 5 appels minimum), évitant d'appeler un service défaillant. Le **Fallback** fournit une **réponse de secours** (ici `price = 0.0`) permettant à l'application de continuer à fonctionner en mode dégradé plutôt que de planter complètement. Cette combinaison assure la **résilience** et la **disponibilité** du système.

---

## Architecture Testée

```
┌─────────────────────────────────────────────────────────────┐
│                      Load Balancer                          │
│              ↓              ↓              ↓                │
│        [book-service]  [book-service]  [book-service]       │
│          :8081           :8083           :8084              │
│              ↓              ↓              ↓                │
│         ─────────────────────────────────────               │
│                    @Lock(PESSIMISTIC_WRITE)                 │
│                           ↓                                 │
│                       [MySQL]                               │
│                        :3306                                │
└─────────────────────────────────────────────────────────────┘
                           ↓
                  [pricing-service] :8080
                  (Circuit Breaker + Fallback)
```
