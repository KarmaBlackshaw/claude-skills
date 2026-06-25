# Apartment Management App — Plan 3: Tenant Management

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Prerequisite:** Plans 1 and 2 complete and all tests passing.

**Goal:** Admin can create, view, edit, and deactivate tenants. Each tenant is linked to a unit and has a billing type (monthly or daily). Tenant list shows status and billing type.

**Architecture:** `useTenants` hook wraps all Supabase calls. Creating a tenant also marks the linked unit as `occupied`. Deactivating a tenant marks the unit as `available`.

**Tech Stack:** Expo Router, NativeWind, Supabase, TanStack Query, TypeScript

---

### Task 11: Tenants API + Hook

**Files:**
- Create: `lib/api/tenants.ts`
- Create: `hooks/useTenants.ts`
- Create: `__tests__/hooks/useTenants.test.tsx`

- [ ] **Step 1: Write failing test**

```typescript
// __tests__/hooks/useTenants.test.tsx
import { renderHook, waitFor } from '@testing-library/react-native'
import { createWrapper } from '../helpers/queryWrapper'
import { useTenants } from '../../hooks/useTenants'

jest.mock('../../lib/api/tenants', () => ({
  fetchTenants: jest.fn().mockResolvedValue([
    {
      id: 't1', user_id: null, unit_id: 'u1', admin_id: 'a1',
      full_name: 'John Doe', email: 'john@test.com', phone: '555-0100',
      billing_type: 'monthly', move_in_date: '2025-01-01',
      move_out_date: null, status: 'active', created_at: '2025-01-01T00:00:00Z',
    },
  ]),
}))

test('returns tenant list', async () => {
  const { result } = renderHook(() => useTenants(), { wrapper: createWrapper() })
  await waitFor(() => expect(result.current.isSuccess).toBe(true))
  expect(result.current.data![0].full_name).toBe('John Doe')
})

test('filters by status', async () => {
  const { result } = renderHook(() => useTenants({ status: 'active' }), { wrapper: createWrapper() })
  await waitFor(() => expect(result.current.isSuccess).toBe(true))
  expect(result.current.data!.every((t) => t.status === 'active')).toBe(true)
})
```

- [ ] **Step 2: Run — expect FAIL**

```bash
npx jest __tests__/hooks/useTenants.test.tsx
```

- [ ] **Step 3: Create `lib/api/tenants.ts`**

```typescript
import { supabase } from '../supabase'
import type { Tenant, TenantWithUnit } from '../../types'

export interface TenantFilters {
  status?: 'active' | 'inactive'
  billing_type?: 'monthly' | 'daily'
}

export async function fetchTenants(filters?: TenantFilters): Promise<TenantWithUnit[]> {
  let query = supabase
    .from('tenants')
    .select('*, unit:units(unit_number, floor, billing_type)')
    .order('full_name')

  if (filters?.status) query = query.eq('status', filters.status)
  if (filters?.billing_type) query = query.eq('billing_type', filters.billing_type)

  const { data, error } = await query
  if (error) throw error
  return data as TenantWithUnit[]
}

export async function fetchTenant(id: string): Promise<TenantWithUnit> {
  const { data, error } = await supabase
    .from('tenants')
    .select('*, unit:units(unit_number, floor, billing_type, status)')
    .eq('id', id)
    .single()
  if (error) throw error
  return data as TenantWithUnit
}

export interface CreateTenantInput {
  unit_id: string
  full_name: string
  email: string
  phone: string
  billing_type: 'monthly' | 'daily'
  move_in_date: string
}

export async function createTenant(input: CreateTenantInput): Promise<Tenant> {
  const { data, error } = await supabase
    .from('tenants')
    .insert({ ...input, status: 'active' })
    .select()
    .single()
  if (error) throw error

  // Mark unit as occupied
  await supabase.from('units').update({ status: 'occupied' }).eq('id', input.unit_id)

  return data
}

export async function updateTenant(
  id: string,
  input: Partial<Pick<Tenant, 'full_name' | 'email' | 'phone' | 'move_out_date'>>
): Promise<Tenant> {
  const { data, error } = await supabase
    .from('tenants')
    .update(input)
    .eq('id', id)
    .select()
    .single()
  if (error) throw error
  return data
}

export async function deactivateTenant(id: string, unitId: string): Promise<void> {
  const { error } = await supabase
    .from('tenants')
    .update({ status: 'inactive', move_out_date: new Date().toISOString().split('T')[0] })
    .eq('id', id)
  if (error) throw error
  await supabase.from('units').update({ status: 'available' }).eq('id', unitId)
}
```

- [ ] **Step 4: Create `hooks/useTenants.ts`**

```typescript
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import {
  fetchTenants, fetchTenant, createTenant, updateTenant, deactivateTenant,
  type TenantFilters,
} from '../lib/api/tenants'

export const TENANTS_KEY = ['tenants'] as const

export function useTenants(filters?: TenantFilters) {
  return useQuery({
    queryKey: [...TENANTS_KEY, filters],
    queryFn: () => fetchTenants(filters),
  })
}

export function useTenant(id: string) {
  return useQuery({
    queryKey: [...TENANTS_KEY, id],
    queryFn: () => fetchTenant(id),
    enabled: !!id,
  })
}

export function useCreateTenant() {
  const qc = useQueryClient()
  return useMutation({
    mutationFn: createTenant,
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: TENANTS_KEY })
      qc.invalidateQueries({ queryKey: ['units'] })
    },
  })
}

export function useUpdateTenant() {
  const qc = useQueryClient()
  return useMutation({
    mutationFn: ({ id, input }: { id: string; input: Parameters<typeof updateTenant>[1] }) =>
      updateTenant(id, input),
    onSuccess: () => qc.invalidateQueries({ queryKey: TENANTS_KEY }),
  })
}

export function useDeactivateTenant() {
  const qc = useQueryClient()
  return useMutation({
    mutationFn: ({ id, unitId }: { id: string; unitId: string }) => deactivateTenant(id, unitId),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: TENANTS_KEY })
      qc.invalidateQueries({ queryKey: ['units'] })
    },
  })
}
```

- [ ] **Step 5: Run — expect PASS**

```bash
npx jest __tests__/hooks/useTenants.test.tsx
```

- [ ] **Step 6: Commit**

```bash
git add lib/api/tenants.ts hooks/useTenants.ts __tests__/hooks/useTenants.test.tsx && git commit -m "feat: tenants API and hook"
```

---

### Task 12: Tenant Screens

**Files:**
- Create: `app/(admin)/tenants/_layout.tsx`
- Create: `app/(admin)/tenants/index.tsx`
- Create: `app/(admin)/tenants/new.tsx`
- Create: `app/(admin)/tenants/[id].tsx`
- Create: `components/admin/TenantCard.tsx`

- [ ] **Step 1: Create `components/admin/TenantCard.tsx`**

```typescript
import React from 'react'
import { TouchableOpacity, View } from 'react-native'
import { Card, AppText, Badge, billingBadge, tenantStatusBadge } from '../ui'
import type { TenantWithUnit } from '../../types'

interface TenantCardProps {
  tenant: TenantWithUnit
  onPress: () => void
}

export function TenantCard({ tenant, onPress }: TenantCardProps) {
  const billing = billingBadge(tenant.billing_type)
  const status = tenantStatusBadge(tenant.status)

  return (
    <TouchableOpacity onPress={onPress} activeOpacity={0.7} className="mb-3">
      <Card>
        <View className="flex-row items-start justify-between">
          <View className="flex-1">
            <AppText variant="subheading">{tenant.full_name}</AppText>
            <AppText color="secondary" variant="caption">{tenant.email}</AppText>
          </View>
          <Badge label={status.label} variant={status.variant} />
        </View>
        <View className="flex-row items-center gap-2 mt-2">
          <Badge label={billing.label} variant={billing.variant} />
          {tenant.unit && (
            <AppText variant="caption" color="secondary">Unit {tenant.unit.unit_number}</AppText>
          )}
        </View>
      </Card>
    </TouchableOpacity>
  )
}
```

- [ ] **Step 2: Create `app/(admin)/tenants/_layout.tsx`**

```typescript
import { Stack } from 'expo-router'

export default function TenantsLayout() {
  return (
    <Stack>
      <Stack.Screen name="index" options={{ title: 'Tenants' }} />
      <Stack.Screen name="new" options={{ title: 'Add Tenant', presentation: 'modal' }} />
      <Stack.Screen name="[id]" options={{ title: 'Tenant' }} />
    </Stack>
  )
}
```

- [ ] **Step 3: Create `app/(admin)/tenants/index.tsx`**

```typescript
import React, { useState } from 'react'
import { View, FlatList } from 'react-native'
import { useRouter } from 'expo-router'
import { useTenants } from '../../../hooks/useTenants'
import { TenantCard } from '../../../components/admin/TenantCard'
import { LoadingSpinner, EmptyState, Button, AppText } from '../../../components/ui'

export default function TenantsScreen() {
  const router = useRouter()
  const [showInactive, setShowInactive] = useState(false)
  const { data: tenants, isLoading } = useTenants(showInactive ? undefined : { status: 'active' })

  if (isLoading) return <LoadingSpinner />

  return (
    <View className="flex-1 bg-slate-50">
      <View className="flex-row items-center gap-2 px-4 pt-3">
        <Button
          label="Active" size="sm"
          variant={!showInactive ? 'primary' : 'secondary'}
          onPress={() => setShowInactive(false)}
        />
        <Button
          label="All" size="sm"
          variant={showInactive ? 'primary' : 'secondary'}
          onPress={() => setShowInactive(true)}
        />
      </View>
      <FlatList
        data={tenants}
        keyExtractor={(t) => t.id}
        contentContainerClassName="p-4"
        renderItem={({ item }) => (
          <TenantCard tenant={item} onPress={() => router.push(`/(admin)/tenants/${item.id}`)} />
        )}
        ListEmptyComponent={
          <EmptyState
            title="No tenants"
            description="Add your first tenant to get started"
            actionLabel="Add Tenant"
            onAction={() => router.push('/(admin)/tenants/new')}
          />
        }
        ListFooterComponent={
          tenants && tenants.length > 0
            ? <Button label="Add Tenant" variant="secondary" onPress={() => router.push('/(admin)/tenants/new')} className="mt-2" />
            : null
        }
      />
    </View>
  )
}
```

- [ ] **Step 4: Create `app/(admin)/tenants/new.tsx`**

```typescript
import React, { useState } from 'react'
import { View, ScrollView, KeyboardAvoidingView, Platform } from 'react-native'
import { useRouter } from 'expo-router'
import { useCreateTenant } from '../../../hooks/useTenants'
import { useProperties } from '../../../hooks/useProperties'
import { useUnits } from '../../../hooks/useUnits'
import { Input, Button, AppText } from '../../../components/ui'
import type { BillingType } from '../../../types'

export default function NewTenantScreen() {
  const router = useRouter()
  const { mutateAsync, isPending } = useCreateTenant()
  const { data: properties } = useProperties()

  const [fullName, setFullName] = useState('')
  const [email, setEmail] = useState('')
  const [phone, setPhone] = useState('')
  const [billingType, setBillingType] = useState<BillingType>('monthly')
  const [moveInDate, setMoveInDate] = useState(new Date().toISOString().split('T')[0])
  const [selectedPropertyId, setSelectedPropertyId] = useState('')
  const [selectedUnitId, setSelectedUnitId] = useState('')
  const [errors, setErrors] = useState<Record<string, string>>({})

  const { data: units } = useUnits(selectedPropertyId)
  const availableUnits = units?.filter((u) => u.status === 'available' && u.billing_type === billingType) ?? []

  async function handleSubmit() {
    const errs: Record<string, string> = {}
    if (!fullName.trim()) errs.fullName = 'Name is required'
    if (!email.trim()) errs.email = 'Email is required'
    if (!phone.trim()) errs.phone = 'Phone is required'
    if (!selectedUnitId) errs.unit = 'Please select a unit'
    if (!moveInDate) errs.moveInDate = 'Move-in date is required'
    if (Object.keys(errs).length) { setErrors(errs); return }

    await mutateAsync({
      unit_id: selectedUnitId,
      full_name: fullName.trim(),
      email: email.trim(),
      phone: phone.trim(),
      billing_type: billingType,
      move_in_date: moveInDate,
    })
    router.back()
  }

  return (
    <KeyboardAvoidingView behavior={Platform.OS === 'ios' ? 'padding' : 'height'} className="flex-1 bg-slate-50">
      <ScrollView contentContainerClassName="p-4">
        <Input label="Full Name" value={fullName} onChangeText={setFullName} error={errors.fullName} placeholder="Jane Doe" />
        <Input label="Email" value={email} onChangeText={setEmail} keyboardType="email-address" autoCapitalize="none" error={errors.email} placeholder="jane@example.com" />
        <Input label="Phone" value={phone} onChangeText={setPhone} keyboardType="phone-pad" error={errors.phone} placeholder="+1 555 0100" />
        <Input label="Move-in Date (YYYY-MM-DD)" value={moveInDate} onChangeText={setMoveInDate} error={errors.moveInDate} />

        <AppText variant="label" color="secondary" className="mb-2">Billing Type</AppText>
        <View className="flex-row gap-2 mb-4">
          {(['monthly', 'daily'] as BillingType[]).map((t) => (
            <Button key={t} label={t === 'monthly' ? 'Monthly' : 'Daily'} size="sm"
              variant={billingType === t ? 'primary' : 'secondary'}
              onPress={() => { setBillingType(t); setSelectedUnitId('') }}
              className="flex-1" />
          ))}
        </View>

        <AppText variant="label" color="secondary" className="mb-2">Property</AppText>
        {properties?.map((p) => (
          <Button key={p.id} label={p.name} size="sm"
            variant={selectedPropertyId === p.id ? 'primary' : 'secondary'}
            onPress={() => { setSelectedPropertyId(p.id); setSelectedUnitId('') }}
            className="mb-2" />
        ))}

        {selectedPropertyId && (
          <>
            <AppText variant="label" color="secondary" className="mb-2 mt-2">
              Available {billingType === 'monthly' ? 'Monthly' : 'Daily'} Units
            </AppText>
            {availableUnits.length === 0
              ? <AppText color="muted" variant="caption">No available units for this billing type</AppText>
              : availableUnits.map((u) => (
                  <Button key={u.id}
                    label={`Unit ${u.unit_number} — $${(billingType === 'monthly' ? u.monthly_rate : u.daily_rate)?.toFixed(2)}/${billingType === 'monthly' ? 'mo' : 'day'}`}
                    size="sm"
                    variant={selectedUnitId === u.id ? 'primary' : 'secondary'}
                    onPress={() => setSelectedUnitId(u.id)}
                    className="mb-2" />
                ))
            }
            {errors.unit && <AppText variant="caption" color="danger">{errors.unit}</AppText>}
          </>
        )}

        <Button label="Add Tenant" onPress={handleSubmit} loading={isPending} className="mt-6" />
      </ScrollView>
    </KeyboardAvoidingView>
  )
}
```

- [ ] **Step 5: Create `app/(admin)/tenants/[id].tsx`**

```typescript
import React, { useState, useEffect } from 'react'
import { View, ScrollView, Alert } from 'react-native'
import { useLocalSearchParams, useRouter } from 'expo-router'
import { useTenant, useUpdateTenant, useDeactivateTenant } from '../../../hooks/useTenants'
import { Input, Button, AppText, LoadingSpinner, Card, Badge, billingBadge, tenantStatusBadge } from '../../../components/ui'

export default function TenantDetailScreen() {
  const { id } = useLocalSearchParams<{ id: string }>()
  const router = useRouter()
  const { data: tenant, isLoading } = useTenant(id)
  const { mutateAsync: update, isPending: updating } = useUpdateTenant()
  const { mutateAsync: deactivate, isPending: deactivating } = useDeactivateTenant()

  const [fullName, setFullName] = useState('')
  const [email, setEmail] = useState('')
  const [phone, setPhone] = useState('')

  useEffect(() => {
    if (tenant) {
      setFullName(tenant.full_name)
      setEmail(tenant.email)
      setPhone(tenant.phone)
    }
  }, [tenant])

  if (isLoading) return <LoadingSpinner />
  if (!tenant) return null

  const billing = billingBadge(tenant.billing_type)
  const statusBadge = tenantStatusBadge(tenant.status)

  async function handleSave() {
    await update({ id, input: { full_name: fullName.trim(), email: email.trim(), phone: phone.trim() } })
    router.back()
  }

  function handleDeactivate() {
    Alert.alert(
      'Move Out Tenant',
      `Mark ${tenant!.full_name} as moved out? This frees up the unit.`,
      [
        { text: 'Cancel', style: 'cancel' },
        {
          text: 'Move Out',
          style: 'destructive',
          onPress: async () => {
            await deactivate({ id, unitId: tenant!.unit_id! })
            router.back()
          },
        },
      ]
    )
  }

  return (
    <ScrollView className="flex-1 bg-slate-50" contentContainerClassName="p-4">
      <Card className="mb-4">
        <View className="flex-row items-center gap-2 mb-1">
          <Badge label={statusBadge.label} variant={statusBadge.variant} />
          <Badge label={billing.label} variant={billing.variant} />
        </View>
        {tenant.unit && <AppText color="secondary" variant="caption">Unit {tenant.unit.unit_number}</AppText>}
        <AppText color="secondary" variant="caption">Move-in: {tenant.move_in_date}</AppText>
        {tenant.move_out_date && <AppText color="secondary" variant="caption">Move-out: {tenant.move_out_date}</AppText>}
      </Card>

      <Input label="Full Name" value={fullName} onChangeText={setFullName} />
      <Input label="Email" value={email} onChangeText={setEmail} keyboardType="email-address" autoCapitalize="none" />
      <Input label="Phone" value={phone} onChangeText={setPhone} keyboardType="phone-pad" />

      <Button label="Save Changes" onPress={handleSave} loading={updating} className="mb-3" />

      {tenant.status === 'active' && (
        <Button label="Move Out Tenant" variant="danger" onPress={handleDeactivate} loading={deactivating} />
      )}
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
git add app/(admin)/tenants/ components/admin/TenantCard.tsx && git commit -m "feat: tenant list, create, detail, and deactivate screens"
```

---

**Plan 3 complete.** Admin can manage tenants and link them to units. Proceed to [Billing plan](./2026-05-03-apt-mgmt-04-billing.md).
