# Apartment Management App — Plan 1: Foundation

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Initialize the Expo project, configure NativeWind, set up Drizzle + SQLite local database, define TypeScript types, build the design system components, and wire up the root layout (no auth — offline-first).

**Architecture:** Expo Router v3 for navigation, expo-sqlite + Drizzle ORM for local storage, NativeWind v4 for styling. No remote backend, no auth. App starts directly in admin mode. A simple AsyncStorage role toggle can be added later for tenant switching.

**Tech Stack:** Expo SDK 54, Expo Router v6, NativeWind v4, expo-sqlite, Drizzle ORM, TanStack Query v5, TypeScript, Jest, RNTL

> **Status:** Tasks 1–3 are COMPLETE (already implemented and committed). Start from Task 4.

---

### ✅ Task 1: Initialize Project — DONE (commit: d52ae4d)
### ✅ Task 2: NativeWind + Design Tokens — DONE (commit: edd9786)
### ✅ Task 3: TypeScript Types — DONE (commit: c641e6b)

---

### Task 4: Drizzle + SQLite Setup

**Files:**
- Create: `db/schema.ts`
- Create: `db/index.ts`
- Create: `db/seed.ts`
- Create: `__tests__/db/schema.test.ts`

- [ ] **Step 1: Install dependencies**

```bash
cd /Users/admin/Documents/personal/agentic-ai/apartment-manager
npx expo install expo-sqlite
npm install drizzle-orm
npm install --save-dev drizzle-kit
```

- [ ] **Step 2: Write failing test**

Create `__tests__/db/schema.test.ts`:

```typescript
import { properties, units, tenants, bills, contracts } from '../../db/schema'

test('properties table has required columns', () => {
  expect(properties.name).toBeDefined()
  expect(properties.address).toBeDefined()
})

test('units table has billing_type column', () => {
  expect(units.billing_type).toBeDefined()
})

test('bills table has status column', () => {
  expect(bills.status).toBeDefined()
})
```

- [ ] **Step 3: Run — expect FAIL**

```bash
npx jest __tests__/db/schema.test.ts
```
Expected: `Cannot find module '../../db/schema'`

- [ ] **Step 4: Create `db/schema.ts`**

```typescript
import { sqliteTable, text, integer, real, sql } from 'drizzle-orm/sqlite-core'

export const properties = sqliteTable('properties', {
  id: text('id').primaryKey(),
  name: text('name').notNull(),
  address: text('address').notNull(),
  description: text('description'),
  created_at: text('created_at').notNull().default(sql`(CURRENT_TIMESTAMP)`),
})

export const units = sqliteTable('units', {
  id: text('id').primaryKey(),
  property_id: text('property_id').notNull().references(() => properties.id),
  unit_number: text('unit_number').notNull(),
  floor: integer('floor'),
  bedrooms: integer('bedrooms').notNull().default(1),
  bathrooms: integer('bathrooms').notNull().default(1),
  monthly_rate: real('monthly_rate'),
  daily_rate: real('daily_rate'),
  billing_type: text('billing_type', { enum: ['monthly', 'daily'] }).notNull(),
  status: text('status', { enum: ['available', 'occupied', 'maintenance'] }).notNull().default('available'),
  created_at: text('created_at').notNull().default(sql`(CURRENT_TIMESTAMP)`),
})

export const tenants = sqliteTable('tenants', {
  id: text('id').primaryKey(),
  unit_id: text('unit_id').references(() => units.id),
  full_name: text('full_name').notNull(),
  email: text('email').notNull(),
  phone: text('phone').notNull(),
  billing_type: text('billing_type', { enum: ['monthly', 'daily'] }).notNull(),
  move_in_date: text('move_in_date').notNull(),
  move_out_date: text('move_out_date'),
  status: text('status', { enum: ['active', 'inactive'] }).notNull().default('active'),
  created_at: text('created_at').notNull().default(sql`(CURRENT_TIMESTAMP)`),
})

export const bills = sqliteTable('bills', {
  id: text('id').primaryKey(),
  tenant_id: text('tenant_id').notNull().references(() => tenants.id),
  unit_id: text('unit_id').notNull().references(() => units.id),
  amount: real('amount').notNull(),
  billing_type: text('billing_type', { enum: ['monthly', 'daily'] }).notNull(),
  period_start: text('period_start').notNull(),
  period_end: text('period_end').notNull(),
  due_date: text('due_date').notNull(),
  paid_at: text('paid_at'),
  status: text('status', { enum: ['pending', 'paid', 'overdue'] }).notNull().default('pending'),
  notes: text('notes'),
  created_at: text('created_at').notNull().default(sql`(CURRENT_TIMESTAMP)`),
})

export const contracts = sqliteTable('contracts', {
  id: text('id').primaryKey(),
  tenant_id: text('tenant_id').notNull().references(() => tenants.id),
  unit_id: text('unit_id').notNull().references(() => units.id),
  start_date: text('start_date').notNull(),
  end_date: text('end_date').notNull(),
  monthly_rate: real('monthly_rate').notNull(),
  deposit: real('deposit').notNull().default(0),
  terms: text('terms'),
  status: text('status', { enum: ['active', 'expired', 'terminated'] }).notNull().default('active'),
  signed_at: text('signed_at'),
  created_at: text('created_at').notNull().default(sql`(CURRENT_TIMESTAMP)`),
})
```

> **Note on IDs:** IDs are `text` PKs. Generate them with `crypto.randomUUID()` at insert time in the API layer (not in the schema default, to keep schema testable in Node).

- [ ] **Step 5: Create `db/index.ts`**

```typescript
import { drizzle } from 'drizzle-orm/expo-sqlite'
import { openDatabaseSync } from 'expo-sqlite'
import * as schema from './schema'

// Singleton — safe to import anywhere
const expo = openDatabaseSync('apartment-manager.db', { enableChangeListener: true })
export const db = drizzle(expo, { schema })

export function initializeDatabase() {
  expo.execSync(`
    PRAGMA journal_mode = WAL;
    PRAGMA foreign_keys = ON;

    CREATE TABLE IF NOT EXISTS properties (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      address TEXT NOT NULL,
      description TEXT,
      created_at TEXT NOT NULL DEFAULT (CURRENT_TIMESTAMP)
    );

    CREATE TABLE IF NOT EXISTS units (
      id TEXT PRIMARY KEY,
      property_id TEXT NOT NULL REFERENCES properties(id),
      unit_number TEXT NOT NULL,
      floor INTEGER,
      bedrooms INTEGER NOT NULL DEFAULT 1,
      bathrooms INTEGER NOT NULL DEFAULT 1,
      monthly_rate REAL,
      daily_rate REAL,
      billing_type TEXT NOT NULL CHECK (billing_type IN ('monthly', 'daily')),
      status TEXT NOT NULL DEFAULT 'available' CHECK (status IN ('available', 'occupied', 'maintenance')),
      created_at TEXT NOT NULL DEFAULT (CURRENT_TIMESTAMP),
      UNIQUE(property_id, unit_number)
    );

    CREATE TABLE IF NOT EXISTS tenants (
      id TEXT PRIMARY KEY,
      unit_id TEXT REFERENCES units(id),
      full_name TEXT NOT NULL,
      email TEXT NOT NULL,
      phone TEXT NOT NULL,
      billing_type TEXT NOT NULL CHECK (billing_type IN ('monthly', 'daily')),
      move_in_date TEXT NOT NULL,
      move_out_date TEXT,
      status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'inactive')),
      created_at TEXT NOT NULL DEFAULT (CURRENT_TIMESTAMP)
    );

    CREATE TABLE IF NOT EXISTS bills (
      id TEXT PRIMARY KEY,
      tenant_id TEXT NOT NULL REFERENCES tenants(id),
      unit_id TEXT NOT NULL REFERENCES units(id),
      amount REAL NOT NULL,
      billing_type TEXT NOT NULL CHECK (billing_type IN ('monthly', 'daily')),
      period_start TEXT NOT NULL,
      period_end TEXT NOT NULL,
      due_date TEXT NOT NULL,
      paid_at TEXT,
      status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'paid', 'overdue')),
      notes TEXT,
      created_at TEXT NOT NULL DEFAULT (CURRENT_TIMESTAMP)
    );

    CREATE TABLE IF NOT EXISTS contracts (
      id TEXT PRIMARY KEY,
      tenant_id TEXT NOT NULL REFERENCES tenants(id),
      unit_id TEXT NOT NULL REFERENCES units(id),
      start_date TEXT NOT NULL,
      end_date TEXT NOT NULL,
      monthly_rate REAL NOT NULL,
      deposit REAL NOT NULL DEFAULT 0,
      terms TEXT,
      status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'expired', 'terminated')),
      signed_at TEXT,
      created_at TEXT NOT NULL DEFAULT (CURRENT_TIMESTAMP)
    );
  `)
}
```

- [ ] **Step 6: Create `db/seed.ts`** (dev convenience — runs in dev mode only)

```typescript
import { db } from './index'
import { properties, units } from './schema'
import { crypto } from 'react-native'

export async function seedDatabase() {
  const existing = await db.select().from(properties).limit(1)
  if (existing.length > 0) return // Already seeded

  const propId = crypto.randomUUID()
  await db.insert(properties).values({
    id: propId,
    name: 'Sunset Apartments',
    address: '123 Main Street',
    description: 'Demo property',
  })

  await db.insert(units).values([
    { id: crypto.randomUUID(), property_id: propId, unit_number: '101', floor: 1, bedrooms: 2, bathrooms: 1, billing_type: 'monthly', monthly_rate: 500, daily_rate: null },
    { id: crypto.randomUUID(), property_id: propId, unit_number: '102', floor: 1, bedrooms: 1, bathrooms: 1, billing_type: 'daily', monthly_rate: null, daily_rate: 30 },
  ])
}
```

- [ ] **Step 7: Run tests — expect PASS**

```bash
npx jest __tests__/db/schema.test.ts
```

Note: The schema test imports from `db/schema.ts` which uses `drizzle-orm/sqlite-core`. If Jest can't resolve this, add to `moduleNameMapper` in `package.json`:

```json
"moduleNameMapper": {
  "^drizzle-orm/expo-sqlite$": "<rootDir>/__mocks__/drizzle-expo-sqlite.js"
}
```

And create `__mocks__/drizzle-expo-sqlite.js`:
```javascript
module.exports = {
  drizzle: jest.fn(() => ({})),
}
```

The schema itself (using `sqliteTable`, `text`, `integer`, etc.) only needs `drizzle-orm/sqlite-core` which is a pure JS module — it should work in Jest without mocking.

- [ ] **Step 8: Commit**

```bash
git add db/ __tests__/db/ && git commit -m "feat: drizzle schema and sqlite db setup"
```

---

### Task 5: Base UI Components

**Files:**
- Create: `components/ui/AppText.tsx`
- Create: `components/ui/Button.tsx`
- Create: `components/ui/Input.tsx`
- Create: `components/ui/Card.tsx`
- Create: `components/ui/Badge.tsx`
- Create: `components/ui/EmptyState.tsx`
- Create: `components/ui/LoadingSpinner.tsx`
- Create: `components/ui/index.ts`
- Create: `__tests__/ui/Button.test.tsx`

- [ ] **Step 1: Write failing Button test**

```typescript
// __tests__/ui/Button.test.tsx
import React from 'react'
import { render, fireEvent } from '@testing-library/react-native'
import { Button } from '../../components/ui/Button'

test('calls onPress when tapped', () => {
  const fn = jest.fn()
  const { getByText } = render(<Button label="Save" onPress={fn} />)
  fireEvent.press(getByText('Save'))
  expect(fn).toHaveBeenCalledTimes(1)
})

test('does not call onPress when disabled', () => {
  const fn = jest.fn()
  const { getByText } = render(<Button label="Save" onPress={fn} disabled />)
  fireEvent.press(getByText('Save'))
  expect(fn).not.toHaveBeenCalled()
})

test('shows activity indicator when loading', () => {
  const { getByTestId } = render(<Button label="Save" onPress={() => {}} loading />)
  expect(getByTestId('btn-loading')).toBeTruthy()
})
```

- [ ] **Step 2: Run — expect FAIL**

```bash
npx jest __tests__/ui/Button.test.tsx
```

- [ ] **Step 3: Create `components/ui/Button.tsx`**

```typescript
import React from 'react'
import { TouchableOpacity, ActivityIndicator, Text } from 'react-native'

type Variant = 'primary' | 'secondary' | 'ghost' | 'danger'
type Size = 'sm' | 'md' | 'lg'

interface ButtonProps {
  label: string
  onPress: () => void
  variant?: Variant
  size?: Size
  disabled?: boolean
  loading?: boolean
  className?: string
}

const bg: Record<Variant, string> = {
  primary: 'bg-primary active:bg-primary-dark',
  secondary: 'bg-slate-100 active:bg-slate-200',
  ghost: 'bg-transparent',
  danger: 'bg-danger',
}
const txtColor: Record<Variant, string> = {
  primary: 'text-white',
  secondary: 'text-slate-700',
  ghost: 'text-primary',
  danger: 'text-white',
}
const padding: Record<Size, string> = {
  sm: 'px-3 py-2',
  md: 'px-4 py-3',
  lg: 'px-6 py-4',
}
const txtSize: Record<Size, string> = {
  sm: 'text-sm',
  md: 'text-base',
  lg: 'text-lg',
}

export function Button({
  label, onPress, variant = 'primary', size = 'md',
  disabled = false, loading = false, className = '',
}: ButtonProps) {
  return (
    <TouchableOpacity
      onPress={onPress}
      disabled={disabled || loading}
      className={`rounded-xl flex-row items-center justify-center ${bg[variant]} ${padding[size]} ${(disabled || loading) ? 'opacity-50' : ''} ${className}`}
    >
      {loading
        ? <ActivityIndicator testID="btn-loading" size="small" color={variant === 'primary' || variant === 'danger' ? '#fff' : '#2563EB'} />
        : <Text className={`font-semibold ${txtColor[variant]} ${txtSize[size]}`}>{label}</Text>
      }
    </TouchableOpacity>
  )
}
```

- [ ] **Step 4: Run — expect PASS**

```bash
npx jest __tests__/ui/Button.test.tsx
```

- [ ] **Step 5: Create `components/ui/AppText.tsx`**

```typescript
import React from 'react'
import { Text, TextProps } from 'react-native'

type Variant = 'display' | 'heading' | 'subheading' | 'body' | 'caption' | 'label'
type Color = 'primary' | 'secondary' | 'muted' | 'danger' | 'success' | 'warning'

interface AppTextProps extends TextProps {
  variant?: Variant
  color?: Color
}

const varCls: Record<Variant, string> = {
  display:    'text-3xl font-bold',
  heading:    'text-2xl font-semibold',
  subheading: 'text-lg font-semibold',
  body:       'text-base',
  caption:    'text-sm',
  label:      'text-xs font-medium uppercase tracking-widest',
}
const clrCls: Record<Color, string> = {
  primary:   'text-slate-900',
  secondary: 'text-slate-600',
  muted:     'text-slate-400',
  danger:    'text-red-500',
  success:   'text-emerald-600',
  warning:   'text-amber-600',
}

export function AppText({ variant = 'body', color = 'primary', className = '', ...props }: AppTextProps) {
  return <Text className={`${varCls[variant]} ${clrCls[color]} ${className}`} {...props} />
}
```

- [ ] **Step 6: Create `components/ui/Input.tsx`**

```typescript
import React from 'react'
import { View, TextInput, TextInputProps } from 'react-native'
import { AppText } from './AppText'

interface InputProps extends TextInputProps {
  label?: string
  error?: string
  hint?: string
}

export function Input({ label, error, hint, className = '', ...props }: InputProps) {
  return (
    <View className="mb-4">
      {label && <AppText variant="label" color="secondary" className="mb-1.5">{label}</AppText>}
      <TextInput
        className={`border rounded-xl px-4 py-3 text-base text-slate-900 bg-white ${error ? 'border-red-400' : 'border-slate-200'} ${className}`}
        placeholderTextColor="#94A3B8"
        {...props}
      />
      {error && <AppText variant="caption" color="danger" className="mt-1">{error}</AppText>}
      {hint && !error && <AppText variant="caption" color="muted" className="mt-1">{hint}</AppText>}
    </View>
  )
}
```

- [ ] **Step 7: Create `components/ui/Card.tsx`**

```typescript
import React from 'react'
import { View, ViewProps } from 'react-native'

export function Card({ children, className = '', ...props }: ViewProps & { children: React.ReactNode }) {
  return (
    <View className={`bg-white rounded-2xl p-4 shadow-sm border border-slate-100 ${className}`} {...props}>
      {children}
    </View>
  )
}
```

- [ ] **Step 8: Create `components/ui/Badge.tsx`**

```typescript
import React from 'react'
import { View } from 'react-native'
import { AppText } from './AppText'
import type { BillingType, UnitStatus, BillStatus, ContractStatus, TenantStatus } from '../../types'

export type BadgeVariant = 'success' | 'warning' | 'danger' | 'info' | 'neutral'

const bg: Record<BadgeVariant, string> = {
  success: 'bg-emerald-100', warning: 'bg-amber-100',
  danger: 'bg-red-100', info: 'bg-blue-100', neutral: 'bg-slate-100',
}
const txt: Record<BadgeVariant, string> = {
  success: 'text-emerald-700', warning: 'text-amber-700',
  danger: 'text-red-700', info: 'text-blue-700', neutral: 'text-slate-600',
}

export function Badge({ label, variant = 'neutral' }: { label: string; variant?: BadgeVariant }) {
  return (
    <View className={`px-2.5 py-0.5 rounded-full ${bg[variant]}`}>
      <AppText variant="caption" className={`font-medium ${txt[variant]}`}>{label}</AppText>
    </View>
  )
}

export const billingBadge = (t: BillingType) =>
  t === 'monthly' ? { label: 'Monthly', variant: 'info' as BadgeVariant } : { label: 'Daily', variant: 'warning' as BadgeVariant }

export const unitStatusBadge = (s: UnitStatus): { label: string; variant: BadgeVariant } => ({
  available: { label: 'Available', variant: 'success' },
  occupied:  { label: 'Occupied',  variant: 'info' },
  maintenance: { label: 'Maintenance', variant: 'warning' },
}[s])

export const billStatusBadge = (s: BillStatus): { label: string; variant: BadgeVariant } => ({
  pending:  { label: 'Pending', variant: 'warning' },
  paid:     { label: 'Paid',    variant: 'success' },
  overdue:  { label: 'Overdue', variant: 'danger' },
}[s])

export const contractStatusBadge = (s: ContractStatus): { label: string; variant: BadgeVariant } => ({
  active:     { label: 'Active',     variant: 'success' },
  expired:    { label: 'Expired',    variant: 'neutral' },
  terminated: { label: 'Terminated', variant: 'danger' },
}[s])

export const tenantStatusBadge = (s: TenantStatus) =>
  s === 'active' ? { label: 'Active', variant: 'success' as BadgeVariant } : { label: 'Inactive', variant: 'neutral' as BadgeVariant }
```

- [ ] **Step 9: Create `components/ui/EmptyState.tsx`**

```typescript
import React from 'react'
import { View } from 'react-native'
import { AppText } from './AppText'
import { Button } from './Button'

interface EmptyStateProps {
  title: string
  description?: string
  actionLabel?: string
  onAction?: () => void
}

export function EmptyState({ title, description, actionLabel, onAction }: EmptyStateProps) {
  return (
    <View className="flex-1 items-center justify-center p-8">
      <AppText variant="heading" className="text-center mb-2">{title}</AppText>
      {description && <AppText color="secondary" className="text-center mb-6">{description}</AppText>}
      {actionLabel && onAction && <Button label={actionLabel} onPress={onAction} />}
    </View>
  )
}
```

- [ ] **Step 10: Create `components/ui/LoadingSpinner.tsx`**

```typescript
import React from 'react'
import { View, ActivityIndicator } from 'react-native'

export function LoadingSpinner() {
  return (
    <View className="flex-1 items-center justify-center">
      <ActivityIndicator size="large" color="#2563EB" />
    </View>
  )
}
```

- [ ] **Step 11: Create `components/ui/index.ts`**

```typescript
export { AppText } from './AppText'
export { Button } from './Button'
export { Input } from './Input'
export { Card } from './Card'
export { Badge, billingBadge, unitStatusBadge, billStatusBadge, contractStatusBadge, tenantStatusBadge } from './Badge'
export { EmptyState } from './EmptyState'
export { LoadingSpinner } from './LoadingSpinner'
export type { BadgeVariant } from './Badge'
```

- [ ] **Step 12: Run all tests**

```bash
npx jest
```
Expected: all tests pass (theme: 2, types: 1, button: 3).

- [ ] **Step 13: Commit**

```bash
git add components/ui/ __tests__/ui/ && git commit -m "feat: design system UI components"
```

---

### Task 6: Root Layout (No Auth)

**Files:**
- Create: `app/_layout.tsx`
- Create: `app/(admin)/_layout.tsx` (stub — just Stack, no tabs yet)
- Create: `app/(admin)/index.tsx` (stub — placeholder until Task 17)
- Create: `context/DatabaseContext.tsx`

- [ ] **Step 1: Create `context/DatabaseContext.tsx`**

```typescript
import React, { createContext, useContext, useEffect, useState } from 'react'
import { initializeDatabase } from '../db'

interface DatabaseContextValue {
  ready: boolean
}

const DatabaseContext = createContext<DatabaseContextValue>({ ready: false })

export function DatabaseProvider({ children }: { children: React.ReactNode }) {
  const [ready, setReady] = useState(false)

  useEffect(() => {
    try {
      initializeDatabase()
      setReady(true)
    } catch (e) {
      console.error('DB init failed:', e)
    }
  }, [])

  return (
    <DatabaseContext.Provider value={{ ready }}>
      {children}
    </DatabaseContext.Provider>
  )
}

export function useDatabase() {
  return useContext(DatabaseContext)
}
```

- [ ] **Step 2: Create `app/_layout.tsx`**

```typescript
import React from 'react'
import { Slot } from 'expo-router'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { DatabaseProvider, useDatabase } from '../context/DatabaseContext'
import { LoadingSpinner } from '../components/ui'
import '../global.css'

const queryClient = new QueryClient()

function AppContent() {
  const { ready } = useDatabase()
  if (!ready) return <LoadingSpinner />
  return <Slot />
}

export default function RootLayout() {
  return (
    <DatabaseProvider>
      <QueryClientProvider client={queryClient}>
        <AppContent />
      </QueryClientProvider>
    </DatabaseProvider>
  )
}
```

- [ ] **Step 3: Create `app/(admin)/_layout.tsx`** (stub — full tabs added in Task 17)

```typescript
import { Stack } from 'expo-router'

export default function AdminLayout() {
  return <Stack screenOptions={{ headerShown: true }} />
}
```

- [ ] **Step 4: Create `app/(admin)/index.tsx`** (placeholder)

```typescript
import React from 'react'
import { View } from 'react-native'
import { AppText } from '../../components/ui'

export default function AdminPlaceholder() {
  return (
    <View className="flex-1 items-center justify-center bg-slate-50">
      <AppText variant="heading">Apartment Manager</AppText>
      <AppText color="secondary" className="mt-2">DB ready — screens coming soon</AppText>
    </View>
  )
}
```

- [ ] **Step 5: Run full test suite**

```bash
npx jest
```
Expected: all tests pass.

- [ ] **Step 6: Commit**

```bash
git add app/ context/ && git commit -m "feat: root layout with db provider, no auth"
```

---

**Foundation complete.** Proceed to [Properties & Units plan](./2026-05-03-apt-mgmt-02-properties-units.md).
