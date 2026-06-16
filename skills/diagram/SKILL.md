---
name: diagram
description: Generate high-quality architecture diagrams (SVG) from natural language using Kroki's 22+ diagram engines. Supports C4 model, PlantUML, Mermaid, D2, GraphViz, BPMN, and more. Use when user asks for diagrams, architecture charts, flowcharts, sequence diagrams, deployment topologies, infrastructure graphs, or any visual documentation of system design.
---

# Diagram Generation via Kroki

Generates diagrams by writing diagram source code → calling the `kroki` MCP server → saving the SVG/PNG result to disk. The MCP tool `generate_diagram` returns visual output directly; save it to a file with a descriptive name.

## Quick Start

1. Identify the right diagram **type** (see guide below)
2. Write the diagram **source code** in that syntax
3. Call the MCP tool:
   ```
   kroki: generate_diagram(diagramType, source, format="svg")
   ```
4. Save the returned SVG/PNG to disk with a `.svg` or `.png` extension

## Diagram Type Selection Guide

| Scenario | Use `diagramType` | Why |
|----------|------------------|-----|
| System architecture (context/container/component) | `c4plantuml` | Purpose-built for C4 model |
| Deployment topologies, network diagrams | `plantuml` | Best node/edge layout |
| Sequence/interaction flows | `plantuml` or `mermaid` | Both excel here |
| Data pipelines, ETL flows | `mermaid` | Clean linear flow layout |
| Database schemas, ER diagrams | `mermaid` or `erd` | ER-specific shapes |
| Class/hierarchy diagrams | `plantuml` | Full UML class support |
| Network topology, dependency graphs | `graphviz` | Radially-tuned layouts |
| Infrastructure diagrams (rack/network) | `nwdiag` or `rackdiag` | Domain-specific shapes |
| Business process models | `bpmn` | BPMN 2.0 standard |
| Quick block diagrams | `d2` | Cleanest modern syntax |
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
}
```

## Output & Naming Conventions

- Default to `format="svg"` for infinite scalability (all diagram types)
- Use `format="png"` only for `plantuml` and `c4plantuml` types (other types do not support raster output via Kroki)
- `format="pdf"` available for `plantuml` and `c4plantuml` only
- JPEG is **not supported** by Kroki at all — do not request it
- Name files descriptively: `<system>-<view>-<diagram-type>.svg`
  - `ecommerce-container-diagram.svg`
  - `auth-sequence-flow.svg`
  - `microservices-deployment.svg`
- Save to a dedicated directory (default: `./diagrams/`), create if missing

## Error Recovery

1. **Syntax error from Kroki** → Check the diagram type enum matches (`c4plantuml` not `c4-plantuml`)
2. **Rendering looks wrong** → Verify quotes around labels with special chars; use single-line labels
3. **Returned data is empty** → Ensure `source` is not empty; Kroki may 4xx on bad input

## MCP Tool Reference

Three tools available on the `kroki` MCP server:

- `generate_diagram(diagramType, source, format)` → Returns SVG/PNG image data — **use this by default**
- `generate_png_diagram_with_custom_dpi(diagramType, source, dpi)` → High-DPI PNG
- `get_diagram_url(diagramType, source, format)` → Returns a Kroki URL for sharing
