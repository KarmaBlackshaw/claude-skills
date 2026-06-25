# Apartment Management App — Plan 4: Billing

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Prerequisite:** Plans 1–3 complete and all tests passing.

**Goal:** Admin can create bills for tenants (monthly or daily), view all bills with status filters, mark bills as paid, and see overdue bills automatically flagged.

**Architecture:** Bills are manually created by the admin (no auto-generation). Daily billing requires a start+end date; the amount is calculated from `daily_rate * days`. Monthly billing uses the unit's `monthly_rate`. `useBills` hook wraps all Supabase calls.

**Tech Stack:** Expo Router, NativeWind, Supabase, TanStack Query, TypeScript

---

### Task 13: Billing Helpers + API + Hook

**Files:**
- Create: `lib/billing.ts`
- Create: `lib/api/bills.ts`
- Create: `hooks/useBills.ts`
- Create: `__tests__/lib/billing.test.ts`
- Create: `__tests__/hooks/useBills.test.tsx`

- [ ] **Step 1: Write failing billing helper tests**

```typescript
// __tests__/lib/billing.test.ts
import { calcDailyAmount, calcMonthlyAmount, isOverdue } from '../../lib/billing'

test('calcDailyAmount: 5 days at $25/day = $125', () => {
  expect(calcDailyAmount(25, '2025-01-01', '2025-01-05')).toBe(125)
})

test('calcDailyAmount: same start and end = 1 day', () => {
  expect(calcDailyAmount(25, '2025-01-01', '2025-01-01')).toBe(25)
})

test('calcMonthlyAmount returns the rate', () => {
  expect(calcMonthlyAmount(500)).toBe(500)
})

test('isOverdue: past due date and unpaid = true', () => {
  expect(isOverdue('2020-01-01', 'pending')).toBe(true)
})

test('isOverdue: paid = false even if past due', () => {
  expect(isOverdue('2020-01-01', 'paid')).toBe(false)
})

test('isOverdue: future due date = false', () => {
  expect(isOverdue('2099-12-31', 'pending')).toBe(false)
})
```

- [ ] **Step 2: Run — expect FAIL**

```bash
npx jest __tests__/lib/billing.test.ts
```

- [ ] **Step 3: Create `lib/billing.ts`**

```typescript
import type { BillStatus } from '../types'

export function calcDailyAmount(dailyRate: number, periodStart: string, periodEnd: string): number {
  const start = new Date(periodStart)
  const end = new Date(periodEnd)
  const days = Math.max(1, Math.round((end.getTime() - start.getTime()) / (1000 * 60 * 60 * 24)) + 1)
  return parseFloat((dailyRate * days).toFixed(2))
}

export function calcMonthlyAmount(monthlyRate: number): number {
  return monthlyRate
}

export function isOverdue(dueDateStr: string, status: BillStatus): boolean {
  if (status === 'paid') return false
  return new Date(dueDateStr) < new Date(new Date().toDateString())
}

export function formatCurrency(amount: number): string {
  return `$${amount.toFixed(2)}`
}

export function formatDateRange(start: string, end: string): string {
  if (start === end) return start
  return `${start} – ${end}`
}
```

- [ ] **Step 4: Run billing tests — expect PASS**

```bash
npx jest __tests__/lib/billing.test.ts
```

- [ ] **Step 5: Write failing hook test**

```typescript
// __tests__/hooks/useBills.test.tsx
import { renderHook, waitFor } from '@testing-library/react-native'
import { createWrapper } from '../helpers/queryWrapper'
import { useBills } from '../../hooks/useBills'

jest.mock('../../lib/api/bills', () => ({
  fetchBills: jest.fn().mockResolvedValue([
    {
      id: 'b1', tenant_id: 't1', unit_id: 'u1', amount: 500,
      billing_type: 'monthly', period_start: '2025-01-01', period_end: '2025-01-31',
      due_date: '2025-01-05', paid_at: null, status: 'pending', notes: null,
      created_at: '2025-01-01T00:00:00Z',
      tenant: { full_name: 'John Doe', email: 'john@test.com' },
    },
  ]),
}))

test('returns bills list', async () => {
  const { result } = renderHook(() => useBills(), { wrapper: createWrapper() })
  await waitFor(() => expect(result.current.isSuccess).toBe(true))
  expect(result.current.data![0].amount).toBe(500)
})
```

- [ ] **Step 6: Run — expect FAIL**

```bash
npx jest __tests__/hooks/useBills.test.tsx
```

- [ ] **Step 7: Create `lib/api/bills.ts`**

```typescript
import { supabase } from '../supabase'
import type { Bill, BillWithTenant, BillStatus } from '../../types'

export interface BillFilters {
  status?: BillStatus
  tenant_id?: string
  billing_type?: 'monthly' | 'daily'
}

export async function fetchBills(filters?: BillFilters): Promise<BillWithTenant[]> {
  let query = supabase
    .from('bills')
    .select('*, tenant:tenants(full_name, email)')
    .order('due_date', { ascending: false })

  if (filters?.status) query = query.eq('status', filters.status)
  if (filters?.tenant_id) query = query.eq('tenant_id', filters.tenant_id)
  if (filters?.billing_type) query = query.eq('billing_type', filters.billing_type)

  const { data, error } = await query
  if (error) throw error
  return data as BillWithTenant[]
}

export async function fetchBill(id: string): Promise<BillWithTenant> {
  const { data, error } = await supabase
    .from('bills')
    .select('*, tenant:tenants(full_name, email)')
    .eq('id', id)
    .single()
  if (error) throw error
  return data as BillWithTenant
}

export interface CreateBillInput {
  tenant_id: string
  unit_id: string
  amount: number
  billing_type: 'monthly' | 'daily'
  period_start: string
  period_end: string
  due_date: string
  notes?: string
}

export async function createBill(input: CreateBillInput): Promise<Bill> {
  const { data, error } = await supabase
    .from('bills')
    .insert({ ...input, status: 'pending' })
    .select()
    .single()
  if (error) throw error
  return data
}

export async function markBillPaid(id: string): Promise<Bill> {
  const { data, error } = await supabase
    .from('bills')
    .update({ status: 'paid', paid_at: new Date().toISOString() })
    .eq('id', id)
    .select()
    .single()
  if (error) throw error
  return data
}

export async function markOverdueBills(): Promise<void> {
  const today = new Date().toISOString().split('T')[0]
  const { error } = await supabase
    .from('bills')
    .update({ status: 'overdue' })
    .eq('status', 'pending')
    .lt('due_date', today)
  if (error) throw error
}

export async function deleteBill(id: string): Promise<void> {
  const { error } = await supabase.from('bills').delete().eq('id', id)
  if (error) throw error
}
```

- [ ] **Step 8: Create `hooks/useBills.ts`**

```typescript
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import {
  fetchBills, fetchBill, createBill, markBillPaid, deleteBill,
  type BillFilters,
} from '../lib/api/bills'

export const BILLS_KEY = ['bills'] as const

export function useBills(filters?: BillFilters) {
  return useQuery({
    queryKey: [...BILLS_KEY, filters],
    queryFn: () => fetchBills(filters),
  })
}

export function useBill(id: string) {
  return useQuery({
    queryKey: [...BILLS_KEY, id],
    queryFn: () => fetchBill(id),
    enabled: !!id,
  })
}

export function useCreateBill() {
  const qc = useQueryClient()
  return useMutation({
    mutationFn: createBill,
    onSuccess: () => qc.invalidateQueries({ queryKey: BILLS_KEY }),
  })
}

export function useMarkBillPaid() {
  const qc = useQueryClient()
  return useMutation({
    mutationFn: markBillPaid,
    onSuccess: () => qc.invalidateQueries({ queryKey: BILLS_KEY }),
  })
}

export function useDeleteBill() {
  const qc = useQueryClient()
  return useMutation({
    mutationFn: deleteBill,
    onSuccess: () => qc.invalidateQueries({ queryKey: BILLS_KEY }),
  })
}
```

- [ ] **Step 9: Run all tests — expect PASS**

```bash
npx jest
```

- [ ] **Step 10: Commit**

```bash
git add lib/billing.ts lib/api/bills.ts hooks/useBills.ts __tests__/ && git commit -m "feat: billing helpers, API, and hook"
```

---

### Task 14: Billing Screens

**Files:**
- Create: `app/(admin)/billing/_layout.tsx`
- Create: `app/(admin)/billing/index.tsx`
- Create: `app/(admin)/billing/new.tsx`
- Create: `app/(admin)/billing/[id].tsx`
- Create: `components/admin/BillCard.tsx`

- [ ] **Step 1: Create `components/admin/BillCard.tsx`**

```typescript
import React from 'react'
import { TouchableOpacity, View } from 'react-native'
import { Card, AppText, Badge, billStatusBadge, billingBadge } from '../ui'
import { formatCurrency, formatDateRange } from '../../lib/billing'
import type { BillWithTenant } from '../../types'

interface BillCardProps {
  bill: BillWithTenant
  onPress: () => void
}

export function BillCard({ bill, onPress }: BillCardProps) {
  const statusBadge = billStatusBadge(bill.status)
  const billing = billingBadge(bill.billing_type)

  return (
    <TouchableOpacity onPress={onPress} activeOpacity={0.7} className="mb-3">
      <Card>
        <View className="flex-row items-start justify-between">
          <View className="flex-1">
            <AppText variant="subheading">{bill.tenant.full_name}</AppText>
            <AppText color="secondary" variant="caption">{formatDateRange(bill.period_start, bill.period_end)}</AppText>
          </View>
          <View className="items-end gap-1">
            <AppText variant="subheading">{formatCurrency(bill.amount)}</AppText>
            <Badge label={statusBadge.label} variant={statusBadge.variant} />
          </View>
        </View>
        <View className="flex-row items-center gap-2 mt-2">
          <Badge label={billing.label} variant={billing.variant} />
          <AppText variant="caption" color="secondary">Due: {bill.due_date}</AppText>
        </View>
      </Card>
    </TouchableOpacity>
  )
}
```

- [ ] **Step 2: Create `app/(admin)/billing/_layout.tsx`**

```typescript
import { Stack } from 'expo-router'

export default function BillingLayout() {
  return (
    <Stack>
      <Stack.Screen name="index" options={{ title: 'Billing' }} />
      <Stack.Screen name="new" options={{ title: 'New Bill', presentation: 'modal' }} />
      <Stack.Screen name="[id]" options={{ title: 'Bill' }} />
    </Stack>
  )
}
```

- [ ] **Step 3: Create `app/(admin)/billing/index.tsx`**

```typescript
import React, { useState } from 'react'
import { View, FlatList } from 'react-native'
import { useRouter } from 'expo-router'
import { useBills } from '../../../hooks/useBills'
import { BillCard } from '../../../components/admin/BillCard'
import { LoadingSpinner, EmptyState, Button } from '../../../components/ui'
import type { BillStatus } from '../../../types'

const FILTERS: { label: string; value: BillStatus | undefined }[] = [
  { label: 'All', value: undefined },
  { label: 'Pending', value: 'pending' },
  { label: 'Overdue', value: 'overdue' },
  { label: 'Paid', value: 'paid' },
]

export default function BillingScreen() {
  const router = useRouter()
  const [statusFilter, setStatusFilter] = useState<BillStatus | undefined>(undefined)
  const { data: bills, isLoading } = useBills(statusFilter ? { status: statusFilter } : undefined)

  if (isLoading) return <LoadingSpinner />

  return (
    <View className="flex-1 bg-slate-50">
      <View className="flex-row gap-2 px-4 pt-3">
        {FILTERS.map((f) => (
          <Button key={f.label} label={f.label} size="sm"
            variant={statusFilter === f.value ? 'primary' : 'secondary'}
            onPress={() => setStatusFilter(f.value)} />
        ))}
      </View>
      <FlatList
        data={bills}
        keyExtractor={(b) => b.id}
        contentContainerClassName="p-4"
        renderItem={({ item }) => (
          <BillCard bill={item} onPress={() => router.push(`/(admin)/billing/${item.id}`)} />
        )}
        ListEmptyComponent={
          <EmptyState
            title="No bills"
            description="Create a bill for a tenant"
            actionLabel="New Bill"
            onAction={() => router.push('/(admin)/billing/new')}
          />
        }
        ListFooterComponent={
          bills && bills.length > 0
            ? <Button label="New Bill" variant="secondary" onPress={() => router.push('/(admin)/billing/new')} className="mt-2" />
            : null
        }
      />
    </View>
  )
}
```

- [ ] **Step 4: Create `app/(admin)/billing/new.tsx`**

```typescript
import React, { useState } from 'react'
import { View, ScrollView, KeyboardAvoidingView, Platform } from 'react-native'
import { useRouter } from 'expo-router'
import { useCreateBill } from '../../../hooks/useBills'
import { useTenants } from '../../../hooks/useTenants'
import { Input, Button, AppText } from '../../../components/ui'
import { calcDailyAmount, calcMonthlyAmount } from '../../../lib/billing'
import type { BillingType, TenantWithUnit } from '../../../types'

export default function NewBillScreen() {
  const router = useRouter()
  const { mutateAsync, isPending } = useCreateBill()
  const { data: tenants } = useTenants({ status: 'active' })

  const [selectedTenant, setSelectedTenant] = useState<TenantWithUnit | null>(null)
  const [periodStart, setPeriodStart] = useState(new Date().toISOString().split('T')[0])
  const [periodEnd, setPeriodEnd] = useState(new Date().toISOString().split('T')[0])
  const [dueDate, setDueDate] = useState('')
  const [notes, setNotes] = useState('')
  const [errors, setErrors] = useState<Record<string, string>>({})

  function calcAmount(): number {
    if (!selectedTenant) return 0
    if (selectedTenant.billing_type === 'daily') {
      const rate = selectedTenant.unit?.billing_type === 'daily' ? 0 : 0
      // Use unit's daily_rate — fetched via TenantWithUnit doesn't include rate, so we'll use notes field for override
      // In practice, fetch the unit to get rate. For now surface it via the form.
      return 0
    }
    return 0
  }

  async function handleSubmit() {
    const errs: Record<string, string> = {}
    if (!selectedTenant) errs.tenant = 'Please select a tenant'
    if (!periodStart) errs.periodStart = 'Period start is required'
    if (!periodEnd) errs.periodEnd = 'Period end is required'
    if (!dueDate) errs.dueDate = 'Due date is required'
    if (Object.keys(errs).length) { setErrors(errs); return }

    // Amount is shown on screen; for monthly it's the unit monthly_rate, for daily it's rate * days
    // Both rates come from the unit — we need to fetch the full unit. This is done in the hook.
    // For now, admin enters a manual override amount for simplicity.
    if (!errors.amount) {
      setErrors({ ...errs, amount: 'Amount could not be calculated — check unit rates' })
    }
  }

  return (
    <KeyboardAvoidingView behavior={Platform.OS === 'ios' ? 'padding' : 'height'} className="flex-1 bg-slate-50">
      <ScrollView contentContainerClassName="p-4">
        <AppText variant="subheading" className="mb-4">Select Tenant</AppText>
        {errors.tenant && <AppText variant="caption" color="danger" className="mb-2">{errors.tenant}</AppText>}
        {tenants?.map((t) => (
          <Button key={t.id}
            label={`${t.full_name} — Unit ${t.unit?.unit_number ?? '?'} (${t.billing_type})`}
            size="sm"
            variant={selectedTenant?.id === t.id ? 'primary' : 'secondary'}
            onPress={() => setSelectedTenant(t)}
            className="mb-2" />
        ))}

        <Input label="Period Start (YYYY-MM-DD)" value={periodStart} onChangeText={setPeriodStart} error={errors.periodStart} />
        <Input label="Period End (YYYY-MM-DD)" value={periodEnd} onChangeText={setPeriodEnd} error={errors.periodEnd} />
        <Input label="Due Date (YYYY-MM-DD)" value={dueDate} onChangeText={setDueDate} error={errors.dueDate} />
        <Input label="Notes (optional)" value={notes} onChangeText={setNotes} multiline numberOfLines={2} />

        <Button label="Create Bill" onPress={handleSubmit} loading={isPending} className="mt-4" />
      </ScrollView>
    </KeyboardAvoidingView>
  )
}
```

> **Note:** The `new.tsx` above needs a `useUnit` call to get the rate once a tenant is selected. Replace `handleSubmit` with this complete version that fetches the unit rate:

```typescript
// Replace handleSubmit in app/(admin)/billing/new.tsx
import { fetchUnit } from '../../../lib/api/units'

async function handleSubmit() {
  const errs: Record<string, string> = {}
  if (!selectedTenant) errs.tenant = 'Please select a tenant'
  if (!periodStart) errs.periodStart = 'Period start is required'
  if (!periodEnd) errs.periodEnd = 'Period end is required'
  if (!dueDate) errs.dueDate = 'Due date is required'
  if (Object.keys(errs).length) { setErrors(errs); return }

  if (!selectedTenant!.unit_id) { setErrors({ tenant: 'Tenant has no unit assigned' }); return }

  const unit = await fetchUnit(selectedTenant!.unit_id)
  const amount = selectedTenant!.billing_type === 'monthly'
    ? calcMonthlyAmount(unit.monthly_rate!)
    : calcDailyAmount(unit.daily_rate!, periodStart, periodEnd)

  await mutateAsync({
    tenant_id: selectedTenant!.id,
    unit_id: selectedTenant!.unit_id,
    amount,
    billing_type: selectedTenant!.billing_type,
    period_start: periodStart,
    period_end: periodEnd,
    due_date: dueDate,
    notes: notes.trim() || undefined,
  })
  router.back()
}
```

- [ ] **Step 5: Create `app/(admin)/billing/[id].tsx`**

```typescript
import React from 'react'
import { View, ScrollView, Alert } from 'react-native'
import { useLocalSearchParams, useRouter } from 'expo-router'
import { useBill, useMarkBillPaid, useDeleteBill } from '../../../hooks/useBills'
import { Button, AppText, LoadingSpinner, Card, Badge, billStatusBadge, billingBadge } from '../../../components/ui'
import { formatCurrency, formatDateRange } from '../../../lib/billing'

export default function BillDetailScreen() {
  const { id } = useLocalSearchParams<{ id: string }>()
  const router = useRouter()
  const { data: bill, isLoading } = useBill(id)
  const { mutateAsync: markPaid, isPending: paying } = useMarkBillPaid()
  const { mutateAsync: remove, isPending: deleting } = useDeleteBill()

  if (isLoading) return <LoadingSpinner />
  if (!bill) return null

  const statusBadge = billStatusBadge(bill.status)
  const billing = billingBadge(bill.billing_type)

  async function handleMarkPaid() {
    await markPaid(id)
  }

  function handleDelete() {
    Alert.alert('Delete Bill', 'Delete this bill permanently?', [
      { text: 'Cancel', style: 'cancel' },
      { text: 'Delete', style: 'destructive', onPress: async () => { await remove(id); router.back() } },
    ])
  }

  return (
    <ScrollView className="flex-1 bg-slate-50" contentContainerClassName="p-4">
      <Card className="mb-4">
        <AppText variant="heading" className="mb-1">{formatCurrency(bill.amount)}</AppText>
        <AppText variant="subheading" color="secondary">{bill.tenant.full_name}</AppText>
        <View className="flex-row gap-2 mt-2">
          <Badge label={statusBadge.label} variant={statusBadge.variant} />
          <Badge label={billing.label} variant={billing.variant} />
        </View>
      </Card>

      <Card>
        <View className="gap-2">
          <View className="flex-row justify-between">
            <AppText color="secondary">Period</AppText>
            <AppText>{formatDateRange(bill.period_start, bill.period_end)}</AppText>
          </View>
          <View className="flex-row justify-between">
            <AppText color="secondary">Due Date</AppText>
            <AppText>{bill.due_date}</AppText>
          </View>
          {bill.paid_at && (
            <View className="flex-row justify-between">
              <AppText color="secondary">Paid On</AppText>
              <AppText>{bill.paid_at.split('T')[0]}</AppText>
            </View>
          )}
          {bill.notes && (
            <View>
              <AppText color="secondary">Notes</AppText>
              <AppText>{bill.notes}</AppText>
            </View>
          )}
        </View>
      </Card>

      {bill.status !== 'paid' && (
        <Button label="Mark as Paid" onPress={handleMarkPaid} loading={paying} className="mt-4" />
      )}
      <Button label="Delete Bill" variant="danger" onPress={handleDelete} loading={deleting} className="mt-3" />
    </ScrollView>
  )
}
```

- [ ] **Step 6: Run full test suite**

```bash
npx jest
```
Expected: all tests pass.

- [ ] **Step 7: Commit**

```bash
git add app/(admin)/billing/ components/admin/BillCard.tsx lib/billing.ts && git commit -m "feat: billing screens and helpers"
```

---

**Plan 4 complete.** Admin can create and manage bills. Proceed to [Contracts plan](./2026-05-03-apt-mgmt-05-contracts.md).
