# Apartment Management App — Plan Index

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a mobile app for apartment management with role-based access for admins and tenants.

**Architecture:** Expo Router v3 (file-based navigation), NativeWind v4 (Tailwind styling), Supabase (auth + PostgreSQL + RLS). Auth state drives routing: unauthenticated → `(auth)/login`, admin → `(admin)`, tenant → `(tenant)`.

**Tech Stack:** Expo SDK 52, Expo Router v3, NativeWind v4, Supabase, TanStack Query v5, Zustand v5, TypeScript, Jest, React Native Testing Library

---

## Execution Order

Implement plans in this order — each builds on the previous:

| # | Plan File | Deliverable |
|---|-----------|-------------|
| 1 | [Foundation](./2026-05-03-apt-mgmt-01-foundation.md) | Project setup, design system, Supabase schema, auth |
| 2 | [Properties & Units](./2026-05-03-apt-mgmt-02-properties-units.md) | Admin can manage properties and units |
| 3 | [Tenants](./2026-05-03-apt-mgmt-03-tenants.md) | Admin can manage tenants and link to units |
| 4 | [Billing](./2026-05-03-apt-mgmt-04-billing.md) | Admin can generate and track bills (daily/monthly) |
| 5 | [Contracts](./2026-05-03-apt-mgmt-05-contracts.md) | Admin can create/view contracts for monthly tenants |
| 6 | [Tenant Portal](./2026-05-03-apt-mgmt-06-tenant-portal.md) | Tenant can view their bills and contract |

## Project Structure

```
apartment-manager/
├── app/
│   ├── _layout.tsx                  # Root: auth provider + role routing
│   ├── +not-found.tsx
│   ├── (auth)/
│   │   ├── _layout.tsx
│   │   └── login.tsx
│   ├── (admin)/
│   │   ├── _layout.tsx              # Bottom tab navigator
│   │   ├── index.tsx                # Dashboard
│   │   ├── tenants/
│   │   │   ├── _layout.tsx
│   │   │   ├── index.tsx
│   │   │   ├── new.tsx
│   │   │   └── [id].tsx
│   │   ├── properties/
│   │   │   ├── _layout.tsx
│   │   │   ├── index.tsx
│   │   │   ├── new.tsx
│   │   │   ├── [id].tsx
│   │   │   └── [propertyId]/units/
│   │   │       ├── _layout.tsx
│   │   │       ├── index.tsx
│   │   │       ├── new.tsx
│   │   │       └── [id].tsx
│   │   ├── billing/
│   │   │   ├── _layout.tsx
│   │   │   ├── index.tsx
│   │   │   ├── new.tsx
│   │   │   └── [id].tsx
│   │   └── contracts/
│   │       ├── _layout.tsx
│   │       ├── index.tsx
│   │       ├── new.tsx
│   │       └── [id].tsx
│   └── (tenant)/
│       ├── _layout.tsx              # Simple 3-tab navigator
│       ├── index.tsx                # My info
│       ├── bills.tsx
│       └── contract.tsx
├── components/
│   └── ui/                          # Button, Input, Card, Badge, Text, etc.
├── context/
│   └── AuthContext.tsx
├── hooks/
│   ├── useAuth.ts
│   ├── useProperties.ts
│   ├── useUnits.ts
│   ├── useTenants.ts
│   ├── useBills.ts
│   └── useContracts.ts
├── lib/
│   └── supabase.ts
├── types/
│   └── index.ts
├── constants/
│   └── theme.ts
└── supabase/
    └── schema.sql
```

## Database Schema Overview

```
profiles        — extends auth.users, adds role (admin|tenant)
properties      — owned by admin
units           — belong to property, have billing_type (monthly|daily)
tenants         — linked to unit + admin, have billing_type
bills           — linked to tenant + unit, period-based
contracts       — linked to tenant + unit, monthly tenants only
```

## Key Design Decisions

- **Billing type lives on both unit and tenant** — unit sets the default, tenant record stores the actual agreement
- **Contracts are only for monthly tenants** — enforce this in UI (hide contract features for daily tenants)
- **RLS enforces admin_id ownership** — no server-side middleware needed
- **TanStack Query manages all remote state** — Zustand only for local UI state (modals, filters)
- **Expo SecureStore for token persistence** — more secure than AsyncStorage for auth tokens
