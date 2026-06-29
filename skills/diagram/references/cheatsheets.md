| State machines | `plantuml` or `mermaid` | Both have state support |

## Syntax Cheat Sheets

### C4-PlantUML (`c4plantuml`) — Architecture Models

```plantuml
@startuml
!include <C4/C4_Container>

Person(customer, "Customer", "Mobile app user")
System_Boundary(ecom, "E-Commerce") {
    Container(web, "Web App", "React", "Serves the storefront")
    Container(api, "API Gateway", "Go", "Routes requests")
    Container(catalog, "Catalog Service", "Rust", "Product data")
    ContainerDb(db, "PostgreSQL", "Relational", "Order data")
}
System_Ext(stripe, "Stripe", "Payment processor")

Rel(customer, web, "Uses", "HTTPS")
Rel(web, api, "Calls", "gRPC")
Rel(api, catalog, "Fetches products", "gRPC")
Rel(api, db, "Reads/Writes", "SQL")
Rel(api, stripe, "Charges", "HTTPS")
@enduml
```

### PlantUML (`plantuml`) — Deployment & Sequence

**Deployment diagram:**
```plantuml
@startuml
node "AWS us-east-1" {
    cloud "VPC" {
        node "EKS Cluster" {
            component [Gateway Pod] as gw
            component [Service Pod] as svc
        }
        database "RDS" as db
    }
}
actor "User" as user
user --> gw : HTTPS
gw --> svc : gRPC
svc --> db : SQL
@enduml
```

**Sequence diagram:**
```plantuml
@startuml
actor Client
participant "API Gateway" as GW
participant "Auth Service" as Auth
database "Redis" as Cache
database "Postgres" as DB

Client -> GW: POST /login
GW -> Auth: ValidateCredentials(user, pass)
Auth -> DB: SELECT user WHERE email=$1
DB --> Auth: user record
Auth -> Cache: SET session:token
Auth --> GW: JWT token
GW --> Client: 200 OK {token}
@enduml
```

### Mermaid (`mermaid`) — Flowcharts & ER

**Flowchart:**
````
flowchart TD
    A[User Request] --> B{Authenticated?}
    B -->|Yes| C[Authorize]
    B -->|No| D[Return 401]
    C --> E{Permission OK?}
    E -->|Yes| F[Process Request]
    E -->|No| G[Return 403]
    F --> H[Return Result]
````

**ER diagram:**
````
erDiagram
    CUSTOMER ||--o{ ORDER : places
    ORDER ||--|{ LINE-ITEM : contains
    PRODUCT ||--o{ LINE-ITEM : "ordered in"
    CUSTOMER {
        string id PK
        string email
        string name
    }
    ORDER {
        string id PK
        string customer_id FK
        date created_at
        string status
    }
````

### D2 (`d2`) — Modern Block Diagrams

```
direction: right
server: API Server {
  shape: rectangle
  style.fill: "#E3F2FD"
}
database: PostgreSQL {
  shape: cylinder
  style.fill: "#FFF3E0"
}
server -> database: SQL queries {
  style.stroke: "#4CAF50"
}
cache: Redis {
  shape: hexagon
  style.fill: "#FFEBEE"
}
server -> cache: GET/SET {
  style.stroke: "#F44336"
}
```

### GraphViz (`graphviz`) — Network & Dependency

```dot
digraph G {
    rankdir=LR;
    node [shape=box, style=rounded];

    edge [color="#2196F3"];

    frontend [label="React Web App", fillcolor="#E3F2FD", style="filled"];
    gateway [label="API Gateway\n(Envoy)", fillcolor="#E8F5E9", style="filled"];
    auth [label="Auth Service", fillcolor="#FFF3E0", style="filled"];

    frontend -> gateway;
    gateway -> auth;
    gateway -> catalog [label="gRPC"];
    gateway -> checkout [label="gRPC"];
    catalog -> db [label="SQL"];
    checkout -> db [label="SQL"];
