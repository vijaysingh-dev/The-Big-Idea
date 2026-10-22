# Salesforce Master Guide — Index

**Purpose**: Zero-to-architect Salesforce engineering, weighted toward Sales Cloud and Service Cloud. Depth-first, implementation-focused, revision-optimized. Every note is meant to be a complete picture of its topic — configuration, code, tradeoffs, failure modes, and how senior engineers actually use it in production orgs.

**How to read this**: Notes are ordered linearly by number. `Prev` and `Next` follow the numbering, not the folder — so you can read straight through from 01.1 to 25.12, or jump into any folder as a reference.

**Conventions used throughout**
- Every jargon term is expanded inline the first time it appears in a note.
- Code samples are production-shaped, not toy snippets.
- Each note ends with 2–3 external resources — official docs, papers, or well-regarded engineering writing.

---

## Navigation

### 01 — Salesforce Fundamentals

| File | Topic |
| --- | --- |
| [[01.1 - What is CRM]] | The business problem before the product |
| [[01.2 - SaaS vs PaaS vs IaaS]] | Where Salesforce sits in the cloud stack |
| [[01.3 - The Salesforce Ecosystem and Career Paths]] | Roles, certifications, job market reality |
| [[01.4 - Salesforce Editions and Licensing]] | What each edition unlocks, licensing traps |
| [[01.5 - Multi-Tenant Architecture]] | How one codebase serves every customer |
| [[01.6 - Metadata vs Data]] | The distinction the entire platform is built on |
| [[01.7 - Salesforce Clouds Overview]] | Sales, Service, Marketing, Commerce, Experience, CPQ, Data Cloud |
| [[01.8 - Lightning Platform and the Platform Stack]] | Runtime, storage, UI, API layers |
| [[01.9 - Classic vs Lightning Experience]] | What changed and what still leaks through |
| [[01.10 - Org Types and Org Strategy]] | Production, sandboxes, scratch orgs, dev orgs |
| [[01.11 - Release Cycle, Trust and Status]] | Three releases a year and how to survive them |
| [[01.12 - Salesforce Platform Architecture End to End]] | Request lifecycle from click to database |

### 02 — Data Model and Objects

| File | Topic |
| --- | --- |
| [[02.1 - Objects Overview]] | Standard, custom, external, big objects compared |
| [[02.2 - Standard Objects and the Core CRM Data Model]] | Account, Contact, Lead, Opportunity, Case and their wiring |
| [[02.3 - Custom Objects and Object Settings]] | Creating objects, naming, org limits |
| [[02.4 - Fields - Types and Behaviour]] | Every field type and when to use it |
| [[02.5 - Formula Fields]] | Compile-time evaluation, limits, performance |
| [[02.6 - Roll-Up Summary Fields]] | Native rollups, locking, and rollup alternatives |
| [[02.7 - Relationships - Lookup vs Master-Detail]] | Ownership, sharing, cascade behaviour |
| [[02.8 - Many-to-Many and Junction Objects]] | The standard N:N pattern |
| [[02.9 - Hierarchical and Self Relationships]] | Manager chains, parent accounts, recursion risk |
| [[02.10 - Delete Behaviour - Cascade and Restrict]] | What actually happens on delete |
| [[02.11 - Record Types and Page Layouts]] | One object, many business processes |
| [[02.12 - Schema Builder and Data Modelling Practice]] | Designing a schema end to end |
| [[02.13 - Data Import and Export Tools]] | Import Wizard, Data Loader, Bulk API, CLI |
| [[02.14 - External Objects and Salesforce Connect]] | Querying data you do not store |
| [[02.15 - Big Objects]] | Billions of rows, async queries, archival |

### 03 — Security and Sharing Model

| File | Topic |
| --- | --- |
| [[03.1 - Security Model Overview]] | The layered model, top to bottom |
| [[03.2 - User Licenses and User Setup]] | License types and what they gate |
| [[03.3 - Profiles]] | What profiles still control, and their future |
| [[03.4 - Permission Sets and Permission Set Groups]] | The modern permission strategy |
| [[03.5 - Object Level Security - CRUD]] | Create, read, update, delete at object scope |
| [[03.6 - Field Level Security]] | FLS and where it silently fails |
| [[03.7 - Organization-Wide Defaults]] | The baseline every other rule builds on |
| [[03.8 - Role Hierarchy]] | Vertical record access |
| [[03.9 - Sharing Rules]] | Owner-based and criteria-based sharing |
| [[03.10 - Manual, Team and Implicit Sharing]] | The sharing you did not configure |
| [[03.11 - Apex Sharing and Programmatic Sharing]] | Share objects, sharing reasons, recalculation |
| [[03.12 - Public Groups, Queues and Territory Management]] | Grouping constructs and territory-based access |
| [[03.13 - Enforcing Security in Apex and SOQL]] | with sharing, WITH USER_MODE, stripInaccessible |
| [[03.14 - Login Policies, MFA and Session Security]] | Org-level access controls |
| [[03.15 - Security Interview Scenarios]] | Worked scenarios and how to reason through them |

### 04 — Sales Cloud

| File | Topic |
| --- | --- |
| [[04.1 - Sales Cloud Overview and the Sales Process]] | The pipeline model end to end |
| [[04.2 - Leads and Lead Management]] | Lead object, statuses, scoring, hygiene |
| [[04.3 - Lead Assignment Rules and Queues]] | Routing inbound demand |
| [[04.4 - Lead Conversion]] | What conversion actually does to your data |
| [[04.5 - Accounts - Business vs Person Accounts]] | B2B and B2C models, and the one-way door |
| [[04.6 - Contacts and Contact Roles]] | Buying committees, multi-account contacts |
| [[04.7 - Account Hierarchies and Account Teams]] | Enterprise account structures |
| [[04.8 - Opportunities and Sales Stages]] | Stage models, probability, forecast categories |
| [[04.9 - Opportunity Teams and Opportunity Splits]] | Credit allocation and comp |
| [[04.10 - Products, Price Books and Pricing]] | Standard vs custom price books, CPQ boundary |
| [[04.11 - Quotes, Orders and Contracts]] | Quote-to-cash on core platform |
| [[04.12 - Campaigns and Campaign Influence]] | Marketing attribution and ROI |
| [[04.13 - Forecasting and Revenue Management]] | Collaborative forecasting, custom forecast design |
| [[04.14 - Path, Kanban and Sales Productivity]] | Guided selling UI features |
| [[04.15 - Einstein for Sales]] | Lead and opportunity scoring, activity capture |
| [[04.16 - Approval Processes in the Sales Cycle]] | Discount approvals and multi-step chains |
| [[04.17 - Territory Management Deep Dive]] | Enterprise Territory Management model |
| [[04.18 - End to End Enterprise Sales Cloud Design]] | A full reference architecture |

### 05 — Service Cloud

| File | Topic |
| --- | --- |
| [[05.1 - Service Cloud Overview and the Support Model]] | Channels, agents, SLAs, escalation |
| [[05.2 - Cases and the Case Lifecycle]] | Case object, status models, closure |
| [[05.3 - Case Assignment and Auto-Response Rules]] | Routing and acknowledgement |
| [[05.4 - Escalation Rules]] | Time-based escalation mechanics |
| [[05.5 - Entitlements, Milestones and SLAs]] | Contractual service levels in data |
| [[05.6 - Email-to-Case and Web-to-Case]] | Inbound channel plumbing and limits |
| [[05.7 - Omni-Channel Routing]] | Capacity-based work distribution |
| [[05.8 - Service Console and Agent Productivity]] | Console app design |
| [[05.9 - Macros, Quick Text and Agent Shortcuts]] | Reducing handle time |
| [[05.10 - Salesforce Knowledge]] | Article types, versioning, data categories |
| [[05.11 - Live Chat and Digital Engagement]] | Chat, messaging, social channels |
| [[05.12 - CTI and Voice]] | Open CTI, Service Cloud Voice |
| [[05.13 - Field Service Basics]] | Work orders, service appointments, scheduling |
| [[05.14 - Service Analytics and Operational Reporting]] | The metrics support leaders actually watch |
| [[05.15 - Einstein for Service and Agentforce]] | Case classification, reply drafting, autonomous agents |
| [[05.16 - End to End Enterprise Service Cloud Design]] | A full reference architecture |

### 06 — Formulas and Validation Rules

| File | Topic |
| --- | --- |
| [[06.1 - Formula Engine and Syntax]] | How formulas compile and evaluate |
| [[06.2 - Text, Logical and Picklist Functions]] | TEXT, ISPICKVAL, CASE, IF, AND, OR, REGEX |
| [[06.3 - Date and Datetime Functions]] | Time zones, business days, date math |
| [[06.4 - Cross-Object Formulas and Limits]] | Traversal, compile size, spanning limits |
| [[06.5 - Validation Rules]] | Enforcing invariants declaratively |
| [[06.6 - Formula Patterns and Anti-Patterns]] | IMAGE, HYPERLINK, and what not to do |

### 07 — Declarative Automation

| File | Topic |
| --- | --- |
| [[07.1 - Automation Landscape and Tool Selection]] | Choosing between flow, Apex, and config |
| [[07.2 - Flow Builder Fundamentals]] | Elements, variables, resources, debug |
| [[07.3 - Record-Triggered Flows]] | The workhorse automation type |
| [[07.4 - Before-Save vs After-Save Flows]] | Performance difference and constraints |
| [[07.5 - Screen Flows]] | Guided UI processes |
| [[07.6 - Scheduled and Autolaunched Flows]] | Batch-like and reusable automation |
| [[07.7 - Subflows and Reusability]] | Composition and shared logic |
| [[07.8 - Flow Error Handling and Fault Paths]] | Failing safely and observably |
| [[07.9 - Invocable Apex and Flow-Apex Interop]] | Extending flow with code |
| [[07.10 - Flow Limits and Performance]] | Where flows fall over at scale |
| [[07.11 - Approval Processes]] | Approval steps, entry criteria, recall |
| [[07.12 - Legacy Workflow and Process Builder Migration]] | Migrating retired automation |
| [[07.13 - Order of Execution]] | The single most important page on the platform |

### 08 — SOQL and SOSL

| File | Topic |
| --- | --- |
| [[08.1 - SOQL Fundamentals]] | Syntax, filtering, differences from SQL |
| [[08.2 - Relationship Queries]] | Parent traversal and child subqueries |
| [[08.3 - Subqueries and Semi-Joins]] | IN, NOT IN, and their limits |
| [[08.4 - Aggregate Queries, GROUP BY and HAVING]] | AggregateResult and grouping |
| [[08.5 - LIMIT, OFFSET, ORDER BY and Pagination]] | Paginating without wrecking performance |
| [[08.6 - FOR UPDATE and Record Locking]] | Pessimistic locking in Apex |
| [[08.7 - Dynamic SOQL]] | Runtime queries and injection safety |
| [[08.8 - SOSL and Full Text Search]] | When search beats query |
| [[08.9 - Indexes and Selective Queries]] | Standard, custom, and skinny table indexes |
| [[08.10 - Query Plan Tool and Query Optimization]] | Reading a query plan, fixing slow queries |

### 09 — Apex Fundamentals

| File | Topic |
| --- | --- |
| [[09.1 - Apex Language Overview]] | What Apex is, how it runs, how it differs from Java |
| [[09.2 - Variables, Data Types and Operators]] | Primitives, sObjects, null semantics |
| [[09.3 - Collections - Lists, Sets and Maps]] | The core of every bulkified pattern |
| [[09.4 - Control Flow and Loops]] | Loop forms and the SOQL-in-loop trap |
| [[09.5 - Classes, Constructors and Access Modifiers]] | Class structure, inner classes, sharing keywords |
| [[09.6 - Inheritance, Virtual and Abstract]] | Extending behaviour safely |
| [[09.7 - Interfaces and Polymorphism]] | Contracts and pluggable design |
| [[09.8 - Static Members and Class Level State]] | Transaction-scoped state and its dangers |
| [[09.9 - Enums and Constants]] | Type-safe options |
| [[09.10 - Exception Handling and Custom Exceptions]] | Catching, rethrowing, and what not to swallow |
| [[09.11 - JSON Serialization and Deserialization]] | Wrapper classes, untyped parsing, gotchas |
| [[09.12 - Generics, Type Casting and Reflection]] | Type.forName, dynamic instantiation |
| [[09.13 - Apex Coding Standards and Best Practices]] | What a senior reviewer looks for |

### 10 — Apex Database Layer

| File | Topic |
| --- | --- |
| [[10.1 - DML Statements]] | insert, update, delete and their semantics |
| [[10.2 - Database Class Methods and Partial Success]] | allOrNone, SaveResult, error handling |
| [[10.3 - Upsert, Merge and External IDs]] | Idempotent writes and dedupe |
| [[10.4 - Delete, Undelete and the Recycle Bin]] | Soft delete behaviour |
| [[10.5 - Savepoints, Rollback and Transaction Control]] | Manual transaction boundaries |
| [[10.6 - Bulkification Patterns]] | The single most important Apex discipline |
| [[10.7 - Mixed DML and Setup Objects]] | Why one transaction cannot touch both |
| [[10.8 - Record Locking and Deadlocks]] | UNABLE_TO_LOCK_ROW, root causes, fixes |
| [[10.9 - Data Skew]] | Ownership, lookup and account skew |

### 11 — Apex Triggers

| File | Topic |
| --- | --- |
| [[11.1 - Trigger Anatomy and Events]] | All seven trigger events |
| [[11.2 - Trigger Context Variables]] | Trigger.new, old, newMap, oldMap and friends |
| [[11.3 - Before vs After - Choosing the Right Event]] | Decision rules with examples |
| [[11.4 - One Trigger Per Object]] | Why ordering matters |
| [[11.5 - Trigger Handler Pattern]] | Building a clean handler layer |
| [[11.6 - Recursion Control and Static Guards]] | Stopping infinite loops correctly |
| [[11.7 - Bulkified Trigger Patterns]] | Real patterns for real data volumes |
| [[11.8 - Trigger Frameworks in the Wild]] | Comparing popular open-source frameworks |
| [[11.9 - Triggers and Order of Execution]] | Where triggers sit in the save pipeline |
| [[11.10 - Trigger Interview Scenarios]] | Hard scenarios and model answers |

### 12 — Asynchronous Apex

| File | Topic |
| --- | --- |
| [[12.1 - Why Async and the Async Landscape]] | Every async option compared |
| [[12.2 - Future Methods]] | The oldest option and its constraints |
| [[12.3 - Queueable Apex]] | Chaining, job IDs, complex state |
| [[12.4 - Batch Apex]] | start, execute, finish, and scoping |
| [[12.5 - Scheduled Apex]] | Cron, schedulable, deployment issues |
| [[12.6 - Transaction Finalizers]] | Reliable post-Queueable handling |
| [[12.7 - Apex Continuations]] | Long-running callouts from the UI |
| [[12.8 - Platform Events]] | Publish, subscribe, delivery semantics |
| [[12.9 - Change Data Capture]] | Streaming record changes |
| [[12.10 - Choosing the Right Async Tool]] | Decision matrix with production examples |

### 13 — Integration

| File | Topic |
| --- | --- |
| [[13.1 - Integration Fundamentals and Patterns]] | Request-reply, fire-and-forget, batch sync, pub-sub |
| [[13.2 - REST API]] | Core REST resources and usage |
| [[13.3 - SOAP API]] | Enterprise vs partner WSDL |
| [[13.4 - Bulk API 2.0]] | High-volume ingest and extract |
| [[13.5 - Composite and Composite Graph API]] | Batching calls and reducing round trips |
| [[13.6 - Metadata API and Tooling API]] | Programmatic org configuration |
| [[13.7 - GraphQL API]] | The newer query surface |
| [[13.8 - Streaming API and PushTopics]] | Legacy streaming, replay IDs |
| [[13.9 - Pub-Sub API and Event Relay]] | gRPC events and AWS EventBridge relay |
| [[13.10 - Authentication and OAuth Flows]] | Every OAuth flow and when to use it |
| [[13.11 - JWT Bearer Flow and Server to Server Auth]] | Headless integration auth |
| [[13.12 - Connected Apps and Auth Providers]] | Inbound and outbound identity |
| [[13.13 - Named Credentials and External Credentials]] | Secret management done properly |
| [[13.14 - Apex Callouts]] | HttpRequest, HttpResponse, timeouts, limits |
| [[13.15 - Building Apex REST and SOAP Services]] | Exposing Salesforce as an API |
| [[13.16 - External Services and Declarative Integration]] | OpenAPI-driven invocable actions |
| [[13.17 - Error Handling, Retries and Idempotency]] | Making integrations survive failure |
| [[13.18 - MuleSoft and Middleware Basics]] | When to put a broker in the middle |
| [[13.19 - Real World Integration Architectures]] | SAP, ERP, payments, AWS, Azure, Kafka |

### 14 — Lightning Web Components

| File | Topic |
| --- | --- |
| [[14.1 - LWC Overview and the Component Model]] | Web standards, shadow DOM, Locker |
| [[14.2 - Component Structure and Metadata]] | HTML, JS, CSS, meta.xml, targets |
| [[14.3 - Templates and Directives]] | if:true, for:each, key, conditional rendering |
| [[14.4 - Reactivity and Decorators]] | api, track, wire and reactive fields |
| [[14.5 - Component Lifecycle Hooks]] | constructor through disconnectedCallback |
| [[14.6 - Parent to Child Communication]] | Public properties and methods |
| [[14.7 - Child to Parent Communication and Events]] | CustomEvent, bubbling, composed |
| [[14.8 - Lightning Message Service]] | Cross-DOM and cross-technology messaging |
| [[14.9 - Slots and Composition]] | Building reusable container components |
| [[14.10 - Calling Apex - Wire vs Imperative]] | Cacheable, error shape, when to use each |
| [[14.11 - refreshApex and Cache Invalidation]] | Keeping the UI truthful |
| [[14.12 - Lightning Data Service and Record Forms]] | Zero-Apex record access |
| [[14.13 - Base Components and lightning-datatable]] | Standard building blocks, inline edit |
| [[14.14 - Navigation and NavigationMixin]] | Routing inside Lightning Experience |
| [[14.15 - Styling, SLDS and Design Tokens]] | Theming without fighting the platform |
| [[14.16 - Error Handling and Toasts]] | User-facing failure handling |
| [[14.17 - Performance and Rendering]] | Rerender cost, lazy loading, large lists |
| [[14.18 - Jest Testing for LWC]] | Unit testing components properly |
| [[14.19 - Deploying and Exposing Components]] | App Builder, Experience Cloud, quick actions |

### 15 — Aura Components

| File | Topic |
| --- | --- |
| [[15.1 - Aura Architecture and Where It Survives]] | Why you still meet Aura in 2026 |
| [[15.2 - Aura Components, Attributes and Expressions]] | Markup and controller model |
| [[15.3 - Aura Events]] | Component vs application events |
| [[15.4 - Aura to LWC Migration]] | Interop and incremental migration |

### 16 — Governor Limits and Performance

| File | Topic |
| --- | --- |
| [[16.1 - Why Governor Limits Exist]] | Multi-tenancy enforced at runtime |
| [[16.2 - SOQL and DML Limits]] | The limits you hit first |
| [[16.3 - CPU Time and Heap Size]] | The limits that are hardest to debug |
| [[16.4 - Callout and Async Limits]] | Callouts, future, queueable, batch ceilings |
| [[16.5 - Platform Event and Streaming Limits]] | Event delivery allocations |
| [[16.6 - Concurrency and Long Running Requests]] | The ten-second concurrency rule |
| [[16.7 - Designing Around Limits]] | Architectural patterns that avoid limits |
| [[16.8 - Platform Cache]] | Org and session cache, partitions, eviction |
| [[16.9 - Skinny Tables and Custom Indexes]] | Support-managed performance tools |
| [[16.10 - Performance Profiling Workflow]] | A repeatable method for slow transactions |

### 17 — Platform Features

| File | Topic |
| --- | --- |
| [[17.1 - Custom Metadata Types]] | Deployable, queryable configuration |
| [[17.2 - Custom Settings]] | Hierarchy and list settings, and their limits |
| [[17.3 - Custom Labels and Translation]] | Localization strategy |
| [[17.4 - Static Resources]] | Bundling assets and third-party libraries |
| [[17.5 - Files, ContentDocument and ContentVersion]] | The file data model |
| [[17.6 - Email Services - Inbound and Outbound]] | Sending, receiving, deliverability, limits |
| [[17.7 - Reports and Dashboards]] | Report types, custom report types, folders |
| [[17.8 - List Views, Search and Einstein Search]] | Findability at scale |
| [[17.9 - Experience Cloud Basics]] | External users, sharing sets, guest access |
| [[17.10 - Slack, Heroku and Mobile SDK Touchpoints]] | Adjacent platform surfaces |

### 18 — Enterprise Architecture and Design Patterns

| File | Topic |
| --- | --- |
| [[18.1 - Salesforce Well-Architected Framework]] | The official architecture guidance, summarized |
| [[18.2 - Layered Architecture on the Platform]] | Separation of concerns in Apex |
| [[18.3 - Service Layer]] | Business logic boundaries |
| [[18.4 - Domain Layer]] | Object-oriented sObject behaviour |
| [[18.5 - Selector Layer]] | Centralizing queries |
| [[18.6 - Unit of Work]] | Batching DML across a transaction |
| [[18.7 - fflib Apex Commons in Practice]] | The reference implementation |
| [[18.8 - Dependency Injection and Testability]] | Seams, mocks, and stub API |
| [[18.9 - Factory, Strategy and Singleton in Apex]] | Classic patterns adapted to Apex |
| [[18.10 - Custom Metadata Driven Architecture]] | Configuration over deployment |
| [[18.11 - Event Driven Architecture on Salesforce]] | Decoupling with events |
| [[18.12 - Package Design - Unlocked, Managed, 1GP vs 2GP]] | Modularity and ISV structure |

### 19 — Testing

| File | Topic |
| --- | --- |
| [[19.1 - Apex Testing Fundamentals]] | Test context, isolation, SeeAllData |
| [[19.2 - Assertions and Test Design]] | Testing behaviour, not coverage |
| [[19.3 - TestSetup and Test Data Factories]] | Reusable, maintainable test data |
| [[19.4 - Test.startTest and Test.stopTest]] | Fresh limits and async flushing |
| [[19.5 - Mocking Callouts]] | HttpCalloutMock, multi-request mocks |
| [[19.6 - Testing Async Apex]] | Batch, queueable, scheduled, platform events |
| [[19.7 - Testing Triggers and Bulk Behaviour]] | Proving bulk safety |
| [[19.8 - Testing Security and Sharing]] | runAs and permission testing |
| [[19.9 - Flow Testing]] | Native flow tests and their gaps |
| [[19.10 - Code Coverage, Quality and CI Gates]] | Coverage as a floor, not a goal |

### 20 — Logging, Debugging and Troubleshooting

| File | Topic |
| --- | --- |
| [[20.1 - Debug Logs and Log Levels]] | Reading a log without drowning |
| [[20.2 - Trace Flags and Log Management]] | Targeting the right user and window |
| [[20.3 - Developer Console and Log Inspector]] | Execution tree, timeline, stack depth |
| [[20.4 - Heap Dumps and Checkpoints]] | Inspecting memory state |
| [[20.5 - Custom Logging Frameworks]] | Persistent, queryable application logs |
| [[20.6 - Event Monitoring and Operational Visibility]] | Org-level telemetry |
| [[20.7 - Common Errors and How to Read Them]] | Decoding the errors you will actually see |
| [[20.8 - Production Incident Playbook]] | Triage under pressure |

### 21 — Deployment and DevOps

| File | Topic |
| --- | --- |
| [[21.1 - Metadata, Source of Truth and Deployment Concepts]] | Org-based vs source-based development |
| [[21.2 - Change Sets]] | The legacy path and its failure modes |
| [[21.3 - Salesforce CLI and SFDX]] | The modern toolchain |
| [[21.4 - Dev Hub and Scratch Orgs]] | Ephemeral development environments |
| [[21.5 - Unlocked Packages]] | Modular deployment done right |
| [[21.6 - Managed Packages and ISV Basics]] | Namespaces, upgrades, subscriber orgs |
| [[21.7 - Git Branching Strategies for Salesforce]] | Branching models that survive metadata |
| [[21.8 - CI-CD Pipelines]] | GitHub Actions, Azure DevOps, Jenkins |
| [[21.9 - Static Analysis, PMD and Code Review]] | Automated quality gates |
| [[21.10 - Deployment Strategies, Rollback and Hotfixes]] | Shipping safely to production |
| [[21.11 - Sandbox Strategy and Data Seeding]] | Environment management at scale |

### 22 — Security Architecture and Compliance

| File | Topic |
| --- | --- |
| [[22.1 - Salesforce Shield Overview]] | What Shield actually buys you |
| [[22.2 - Platform Encryption]] | Deterministic vs probabilistic, functional tradeoffs |
| [[22.3 - Field Audit Trail and Data Retention]] | Long-horizon history |
| [[22.4 - Data Mask and Sandbox Data Privacy]] | Safe non-production data |
| [[22.5 - Secure Apex Coding and OWASP on Platform]] | Injection, XSS, CRUD/FLS enforcement |
| [[22.6 - GDPR, HIPAA and Compliance Patterns]] | Data subject rights in a CRM |
| [[22.7 - AppExchange Security Review]] | What the review checks for |
| [[22.8 - Threat Modelling a Salesforce Org]] | Structured security analysis |

### 23 — Large Data Volumes and Enterprise Scenarios

| File | Topic |
| --- | --- |
| [[23.1 - What Counts as Large Data Volume]] | Thresholds and symptoms |
| [[23.2 - LDV Data Modelling Strategies]] | Divisions, partitioning, denormalization |
| [[23.3 - Sharing at Scale and Sharing Recalculation]] | The most common enterprise bottleneck |
| [[23.4 - Archiving with Big Objects and External Storage]] | Data lifecycle management |
| [[23.5 - Bulk Data Loading at Scale]] | Load ordering, deferred sharing, parallelism |
| [[23.6 - Query Performance at Scale]] | Selectivity under tens of millions of rows |
| [[23.7 - Async Processing at Scale]] | Batch chaining, flex queue, throughput |
| [[23.8 - Real Failure Scenarios and Root Causes]] | Locking, recursion, mixed DML, limit blowups |
| [[23.9 - Capacity Planning and Org Health]] | Storage, limits, technical debt tracking |

### 24 — AI on the Platform

| File | Topic |
| --- | --- |
| [[24.1 - Einstein Platform Overview]] | Predictive and generative features across clouds |
| [[24.2 - Data Cloud Fundamentals]] | Data model, harmonization, identity resolution |
| [[24.3 - Prompt Builder and Prompt Templates]] | Grounded prompts on CRM data |
| [[24.4 - Agentforce Fundamentals]] | Topics, actions, agent design |
| [[24.5 - Einstein Trust Layer]] | Masking, grounding, zero retention |
| [[24.6 - Extending AI Features with Apex and LWC]] | Custom actions and UI |
| [[24.7 - Designing AI Features Responsibly on CRM Data]] | Evaluation, guardrails, failure modes |

### 25 — Interview Preparation

| File | Topic |
| --- | --- |
| [[25.1 - How Salesforce Interviews Actually Work]] | Round structure and signals |
| [[25.2 - Admin and Configuration Questions]] | Core declarative question bank |
| [[25.3 - Apex Questions]] | Language and design question bank |
| [[25.4 - Trigger and Async Questions]] | The highest-frequency topic |
| [[25.5 - SOQL and Governor Limit Questions]] | Query and limit reasoning |
| [[25.6 - LWC Questions]] | Frontend question bank |
| [[25.7 - Integration Questions]] | API, auth, and pattern questions |
| [[25.8 - Sales Cloud Scenario Questions]] | Business-process reasoning |
| [[25.9 - Service Cloud Scenario Questions]] | Support-process reasoning |
| [[25.10 - System Design and Architecture Rounds]] | Whiteboard-level design |
| [[25.11 - Live Coding and Debugging Exercises]] | Practice problems with solutions |
| [[25.12 - Certification Roadmap]] | Which certs matter and in what order |

---

## Start here

[[01.1 - What is CRM]]
