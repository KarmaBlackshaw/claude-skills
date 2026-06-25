# Apartment Management App — Plan 6: Tenant Portal + Admin Navigation

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Prerequisite:** Plans 1–5 complete and all tests passing.

**Goal:** Wire up admin bottom tab navigation and build the tenant-facing portal (my info, my bills, my contract). Tenant can only view — no create/edit. Contract tab is hidden for daily tenants.

**Architecture:** Admin layout uses Expo Router tabs with 4 tabs (Dashboard, Tenants, Properties, Billing, Contracts). Tenant layout uses 2–3 tabs depending on billing type. Both layouts read `profile` from `AuthContext`.

**Tech Stack:** Expo Router, NativeWind, Supabase, TanStack Query, TypeScript

---

### Task 17: Admin Tab Layout + Dashboard

**Files:**
- Create: `app/(admin)/_layout.tsx`
- Create: `app/(admin)/index.tsx`

- [ ] **Step 1: Create `app/(admin)/_layout.tsx`**

```typescript
import React from 'react'
import { Tabs } from 'expo-router'
import { View } from 'react-native'
import { AppText } from '../../components/ui'

function TabIcon({ focused, label }: { focused: boolean; label: string }) {
  return (
    <View className="items-center">
      <AppText variant="caption" color={focused ? 'primary' : 'muted'}>{label}</AppText>
    </View>
  )
}

export default function AdminLayout() {
  return (
    <Tabs
      screenOptions={{
        headerShown: false,
        tabBarStyle: { backgroundColor: '#fff', borderTopColor: '#E2E8F0' },
        tabBarActiveTintColor: '#2563EB',
        tabBarInactiveTintColor: '#94A3B8',
      }}
    >
      <Tabs.Screen
        name="index"
        options={{ title: 'Dashboard', tabBarLabel: 'Dashboard' }}
      />
      <Tabs.Screen
        name="tenants"
        options={{ title: 'Tenants', tabBarLabel: 'Tenants' }}
      />
      <Tabs.Screen
        name="properties"
        options={{ title: 'Properties', tabBarLabel: 'Properties' }}
      />
      <Tabs.Screen
        name="billing"
        options={{ title: 'Billing', tabBarLabel: 'Billing' }}
      />
      <Tabs.Screen
        name="contracts"
        options={{ title: 'Contracts', tabBarLabel: 'Contracts' }}
      />
    </Tabs>
  )
}
```

- [ ] **Step 2: Create `app/(admin)/index.tsx`**

```typescript
import React from 'react'
import { View, ScrollView } from 'react-native'
import { useRouter } from 'expo-router'
import { useTenants } from '../../hooks/useTenants'
import { useBills } from '../../hooks/useBills'
import { useContracts } from '../../hooks/useContracts'
import { useAuth } from '../../hooks/useAuth'
import { Card, AppText, Badge } from '../../components/ui'
import { formatCurrency } from '../../lib/billing'

function StatCard({ label, value, badge }: { label: string; value: string; badge?: { label: string; variant: 'success' | 'warning' | 'danger' | 'info' | 'neutral' } }) {
  return (
    <Card className="flex-1 mx-1">
      <AppText variant="label" color="secondary" className="mb-1">{label}</AppText>
      <AppText variant="heading">{value}</AppText>
      {badge && <Badge label={badge.label} variant={badge.variant} />}
    </Card>
  )
}

export default function AdminDashboard() {
  const { profile } = useAuth()
  const { data: activeTenants } = useTenants({ status: 'active' })
  const { data: pendingBills } = useBills({ status: 'pending' })
  const { data: overdueBills } = useBills({ status: 'overdue' })
  const { data: activeContracts } = useContracts('active')

  const totalOutstanding = [...(pendingBills ?? []), ...(overdueBills ?? [])]
    .reduce((sum, b) => sum + b.amount, 0)

  return (
    <ScrollView className="flex-1 bg-slate-50" contentContainerClassName="p-4">
      <AppText variant="heading" className="mb-1">Dashboard</AppText>
      <AppText color="secondary" className="mb-6">Welcome, {profile?.full_name}</AppText>

      <View className="flex-row mb-4">
        <StatCard label="Active Tenants" value={String(activeTenants?.length ?? 0)} />
        <StatCard label="Active Contracts" value={String(activeContracts?.length ?? 0)} />
      </View>

      <View className="flex-row mb-4">
        <StatCard
          label="Pending Bills"
          value={String(pendingBills?.length ?? 0)}
          badge={pendingBills && pendingBills.length > 0 ? { label: 'Action needed', variant: 'warning' } : undefined}
        />
        <StatCard
          label="Overdue Bills"
          value={String(overdueBills?.length ?? 0)}
          badge={overdueBills && overdueBills.length > 0 ? { label: 'Overdue', variant: 'danger' } : undefined}
        />
      </View>

      <Card>
        <AppText variant="label" color="secondary" className="mb-1">Total Outstanding</AppText>
        <AppText variant="heading" color={totalOutstanding > 0 ? 'danger' : 'primary'}>
          {formatCurrency(totalOutstanding)}
        </AppText>
      </Card>
    </ScrollView>
  )
}
```

- [ ] **Step 3: Commit**

```bash
git add app/(admin)/_layout.tsx app/(admin)/index.tsx && git commit -m "feat: admin tab layout and dashboard"
```

---

### Task 18: Tenant Layout + My Info Screen

**Files:**
- Create: `app/(tenant)/_layout.tsx`
- Create: `app/(tenant)/index.tsx`

- [ ] **Step 1: Create `app/(tenant)/_layout.tsx`**

```typescript
import React from 'react'
import { Tabs } from 'expo-router'
import { useAuth } from '../../hooks/useAuth'
import { useTenantProfile } from '../../hooks/useTenantProfile'

export default function TenantLayout() {
  const { profile } = useAuth()
  const { data: tenantRecord } = useTenantProfile(profile?.id)
  const isMonthly = tenantRecord?.billing_type === 'monthly'

  return (
    <Tabs
      screenOptions={{
        headerShown: false,
        tabBarStyle: { backgroundColor: '#fff', borderTopColor: '#E2E8F0' },
        tabBarActiveTintColor: '#2563EB',
        tabBarInactiveTintColor: '#94A3B8',
      }}
    >
      <Tabs.Screen name="index" options={{ title: 'My Info', tabBarLabel: 'My Info' }} />
      <Tabs.Screen name="bills" options={{ title: 'My Bills', tabBarLabel: 'Bills' }} />
      <Tabs.Screen
        name="contract"
        options={{
          title: 'My Contract',
          tabBarLabel: 'Contract',
          href: isMonthly ? '/(tenant)/contract' : null,
        }}
      />
    </Tabs>
  )
}
```

- [ ] **Step 2: Create `hooks/useTenantProfile.ts`**

```typescript
import { useQuery } from '@tanstack/react-query'
import { supabase } from '../lib/supabase'
import type { TenantWithUnit } from '../types'

export function useTenantProfile(userId: string | undefined) {
  return useQuery({
    queryKey: ['tenantProfile', userId],
    queryFn: async (): Promise<TenantWithUnit | null> => {
      if (!userId) return null
      const { data, error } = await supabase
        .from('tenants')
        .select('*, unit:units(unit_number, floor, billing_type, monthly_rate, daily_rate)')
        .eq('user_id', userId)
        .eq('status', 'active')
        .maybeSingle()
      if (error) throw error
      return data as TenantWithUnit | null
    },
    enabled: !!userId,
  })
}
```

- [ ] **Step 3: Create `app/(tenant)/index.tsx`**

```typescript
import React from 'react'
import { View, ScrollView } from 'react-native'
import { useAuth } from '../../hooks/useAuth'
import { useTenantProfile } from '../../hooks/useTenantProfile'
import { Card, AppText, Badge, LoadingSpinner, billingBadge } from '../../components/ui'
import { formatCurrency } from '../../lib/billing'

function Row({ label, value }: { label: string; value: string }) {
  return (
    <View className="flex-row justify-between py-2 border-b border-slate-100">
      <AppText color="secondary">{label}</AppText>
      <AppText>{value}</AppText>
    </View>
  )
}

export default function TenantInfoScreen() {
  const { profile, signOut } = useAuth()
  const { data: tenant, isLoading } = useTenantProfile(profile?.id)

  if (isLoading) return <LoadingSpinner />

  const billing = tenant ? billingBadge(tenant.billing_type) : null
  const rate = tenant?.billing_type === 'monthly'
    ? (tenant.unit as any)?.monthly_rate
    : (tenant?.unit as any)?.daily_rate

  return (
    <ScrollView className="flex-1 bg-slate-50" contentContainerClassName="p-4">
      <AppText variant="heading" className="mb-4">My Info</AppText>

      <Card className="mb-4">
        <AppText variant="subheading" className="mb-3">{profile?.full_name}</AppText>
        <Row label="Email" value={profile?.email ?? ''} />
        {profile?.phone && <Row label="Phone" value={profile.phone} />}
      </Card>

      {tenant && (
        <Card className="mb-4">
          <AppText variant="label" color="secondary" className="mb-3">Unit Info</AppText>
          {tenant.unit && <Row label="Unit" value={`Unit ${tenant.unit.unit_number}`} />}
          {tenant.unit?.floor !== null && tenant.unit?.floor !== undefined && (
            <Row label="Floor" value={String(tenant.unit.floor)} />
          )}
          <Row label="Move-in" value={tenant.move_in_date} />
          <View className="flex-row items-center mt-2 gap-2">
            {billing && <Badge label={billing.label} variant={billing.variant} />}
            {rate && <AppText variant="caption" color="secondary">{formatCurrency(rate)}/{tenant.billing_type === 'monthly' ? 'mo' : 'day'}</AppText>}
          </View>
        </Card>
      )}

      <View className="mt-4">
        <AppText
          className="text-center text-red-500 font-semibold py-3"
          onPress={signOut}
        >
          Sign Out
        </AppText>
      </View>
    </ScrollView>
  )
}
```

- [ ] **Step 4: Commit**

```bash
git add app/(tenant)/_layout.tsx app/(tenant)/index.tsx hooks/useTenantProfile.ts && git commit -m "feat: tenant layout and my info screen"
```

---

### Task 19: Tenant Bills Screen

**Files:**
- Create: `app/(tenant)/bills.tsx`

- [ ] **Step 1: Create `app/(tenant)/bills.tsx`**

```typescript
import React from 'react'
import { View, FlatList } from 'react-native'
import { useAuth } from '../../hooks/useAuth'
import { useTenantProfile } from '../../hooks/useTenantProfile'
import { useBills } from '../../hooks/useBills'
import { Card, AppText, Badge, LoadingSpinner, EmptyState, billStatusBadge, billingBadge } from '../../components/ui'
import { formatCurrency, formatDateRange } from '../../lib/billing'
import type { BillWithTenant } from '../../types'

function BillRow({ bill }: { bill: BillWithTenant }) {
  const statusBadge = billStatusBadge(bill.status)
  return (
    <Card className="mb-3">
      <View className="flex-row items-start justify-between">
        <View className="flex-1">
          <AppText variant="subheading">{formatCurrency(bill.amount)}</AppText>
          <AppText color="secondary" variant="caption">{formatDateRange(bill.period_start, bill.period_end)}</AppText>
          <AppText color="secondary" variant="caption">Due: {bill.due_date}</AppText>
        </View>
        <Badge label={statusBadge.label} variant={statusBadge.variant} />
      </View>
      {bill.paid_at && (
        <AppText variant="caption" color="success" className="mt-1">Paid on {bill.paid_at.split('T')[0]}</AppText>
      )}
      {bill.notes && <AppText variant="caption" color="muted" className="mt-1">{bill.notes}</AppText>}
    </Card>
  )
}

export default function TenantBillsScreen() {
  const { profile } = useAuth()
  const { data: tenant, isLoading: loadingTenant } = useTenantProfile(profile?.id)
  const { data: bills, isLoading: loadingBills } = useBills(
    tenant ? { tenant_id: tenant.id } : undefined
  )

  if (loadingTenant || loadingBills) return <LoadingSpinner />

  return (
    <View className="flex-1 bg-slate-50">
      <FlatList
        data={bills}
        keyExtractor={(b) => b.id}
        contentContainerClassName="p-4"
        ListHeaderComponent={<AppText variant="heading" className="mb-4">My Bills</AppText>}
        renderItem={({ item }) => <BillRow bill={item} />}
        ListEmptyComponent={
          <EmptyState title="No bills yet" description="Your bills will appear here" />
        }
      />
    </View>
  )
}
```

- [ ] **Step 2: Commit**

```bash
git add app/(tenant)/bills.tsx && git commit -m "feat: tenant bills screen"
```

---

### Task 20: Tenant Contract Screen

**Files:**
- Create: `app/(tenant)/contract.tsx`

- [ ] **Step 1: Create `app/(tenant)/contract.tsx`**

```typescript
import React from 'react'
import { View, ScrollView } from 'react-native'
import { useAuth } from '../../hooks/useAuth'
import { useTenantProfile } from '../../hooks/useTenantProfile'
import { useContractByTenant } from '../../hooks/useContracts'
import { Card, AppText, Badge, LoadingSpinner, EmptyState, contractStatusBadge } from '../../components/ui'
import { formatCurrency } from '../../lib/billing'

function Row({ label, value }: { label: string; value: string }) {
  return (
    <View className="flex-row justify-between py-2 border-b border-slate-100">
      <AppText color="secondary">{label}</AppText>
      <AppText>{value}</AppText>
    </View>
  )
}

export default function TenantContractScreen() {
  const { profile } = useAuth()
  const { data: tenant, isLoading: loadingTenant } = useTenantProfile(profile?.id)
  const { data: contract, isLoading: loadingContract } = useContractByTenant(tenant?.id ?? '')

  if (loadingTenant || loadingContract) return <LoadingSpinner />

  if (!contract) {
    return (
      <EmptyState
        title="No active contract"
        description="Your contract will appear here once created by your admin"
      />
    )
  }

  const statusBadge = contractStatusBadge(contract.status)
  const isExpiringSoon = new Date(contract.end_date) <= new Date(Date.now() + 30 * 24 * 60 * 60 * 1000)

  return (
    <ScrollView className="flex-1 bg-slate-50" contentContainerClassName="p-4">
      <AppText variant="heading" className="mb-4">My Contract</AppText>

      <Card className="mb-4">
        <View className="flex-row items-center gap-2 mb-2">
          <Badge label={statusBadge.label} variant={statusBadge.variant} />
          {isExpiringSoon && <Badge label="Expiring soon" variant="warning" />}
          {!contract.signed_at && <Badge label="Awaiting signature" variant="warning" />}
        </View>
        <AppText color="secondary" variant="caption">Unit {contract.unit.unit_number}</AppText>
      </Card>

      <Card className="mb-4">
        <AppText variant="label" color="secondary" className="mb-3">Details</AppText>
        <Row label="Start Date" value={contract.start_date} />
        <Row label="End Date" value={contract.end_date} />
        <Row label="Monthly Rate" value={formatCurrency(contract.monthly_rate)} />
        <Row label="Security Deposit" value={formatCurrency(contract.deposit)} />
        {contract.signed_at && <Row label="Signed" value={contract.signed_at.split('T')[0]} />}
      </Card>

      {contract.terms && (
        <Card>
          <AppText variant="label" color="secondary" className="mb-2">Terms & Conditions</AppText>
          <AppText color="secondary">{contract.terms}</AppText>
        </Card>
      )}
    </ScrollView>
  )
}
```

- [ ] **Step 2: Commit**

```bash
git add app/(tenant)/contract.tsx && git commit -m "feat: tenant contract screen"
```

---

### Task 21: Final Wiring + Not Found Screen

**Files:**
- Create: `app/+not-found.tsx`
- Verify: all route groups connected

- [ ] **Step 1: Create `app/+not-found.tsx`**

```typescript
import React from 'react'
import { Link } from 'expo-router'
import { View } from 'react-native'
import { AppText } from '../components/ui'

export default function NotFoundScreen() {
  return (
    <View className="flex-1 items-center justify-center bg-slate-50 p-8">
      <AppText variant="heading" className="mb-2">Page not found</AppText>
      <Link href="/" className="text-primary text-base mt-4">Go home</Link>
    </View>
  )
}
```

- [ ] **Step 2: Run full test suite**

```bash
npx jest
```
Expected: all tests pass.

- [ ] **Step 3: Start dev server and verify routing**

```bash
npx expo start
```

Test checklist:
- [ ] Unauthenticated → login screen shown
- [ ] Admin login → admin dashboard with 5 tabs
- [ ] Tenant login (monthly) → 3 tabs (My Info, Bills, Contract)
- [ ] Tenant login (daily) → 2 tabs (My Info, Bills) — Contract tab hidden
- [ ] Admin can create property → unit → tenant → bill → contract
- [ ] Tenant sees their bills and contract (if monthly)

- [ ] **Step 4: Final commit**

```bash
git add app/+not-found.tsx && git commit -m "feat: not-found screen and final wiring"
```

---

**All plans complete.** Full apartment management app implemented.

## What's built

| Feature | Who | Done |
|---------|-----|------|
| Login + role routing | Admin + Tenant | ✓ |
| Properties CRUD | Admin | ✓ |
| Units CRUD (monthly/daily) | Admin | ✓ |
| Tenant management + move-out | Admin | ✓ |
| Bill creation + mark paid | Admin | ✓ |
| Contract management (monthly only) | Admin | ✓ |
| My info | Tenant | ✓ |
| My bills | Tenant | ✓ |
| My contract (monthly only) | Tenant | ✓ |

## Potential next steps

- Push notifications for overdue bills (Expo Notifications)
- PDF contract export (expo-print)
- Auto bill generation on a schedule (Supabase Edge Functions)
- Tenant app account creation flow (admin invites tenant by email)
