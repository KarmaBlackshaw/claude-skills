# Apartment Management App — Plan 5: Contracts

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Prerequisite:** Plans 1–4 complete and all tests passing.

**Goal:** Admin can create contracts for monthly tenants only, view contract details, and mark contracts as terminated or expired. Daily tenants do not have contracts — the UI enforces this.

**Architecture:** `useContracts` hook wraps Supabase. Contract list only shows monthly tenants. Contract status updates are manual (admin marks terminated; expired is informational based on end_date).

**Tech Stack:** Expo Router, NativeWind, Supabase, TanStack Query, TypeScript

---

### Task 15: Contracts API + Hook

**Files:**
- Create: `lib/api/contracts.ts`
- Create: `hooks/useContracts.ts`
- Create: `__tests__/hooks/useContracts.test.tsx`

- [ ] **Step 1: Write failing test**

```typescript
// __tests__/hooks/useContracts.test.tsx
import { renderHook, waitFor } from '@testing-library/react-native'
import { createWrapper } from '../helpers/queryWrapper'
import { useContracts } from '../../hooks/useContracts'

jest.mock('../../lib/api/contracts', () => ({
  fetchContracts: jest.fn().mockResolvedValue([
    {
      id: 'c1', tenant_id: 't1', unit_id: 'u1',
      start_date: '2025-01-01', end_date: '2025-12-31',
      monthly_rate: 500, deposit: 1000, terms: 'Standard lease',
      status: 'active', signed_at: null, created_at: '2025-01-01T00:00:00Z',
      tenant: { full_name: 'John Doe', email: 'john@test.com' },
      unit: { unit_number: '101' },
    },
  ]),
}))

test('returns contract list', async () => {
  const { result } = renderHook(() => useContracts(), { wrapper: createWrapper() })
  await waitFor(() => expect(result.current.isSuccess).toBe(true))
  expect(result.current.data![0].monthly_rate).toBe(500)
})
```

- [ ] **Step 2: Run — expect FAIL**

```bash
npx jest __tests__/hooks/useContracts.test.tsx
```

- [ ] **Step 3: Create `lib/api/contracts.ts`**

```typescript
import { supabase } from '../supabase'
import type { Contract, ContractWithTenant, ContractStatus } from '../../types'

export async function fetchContracts(status?: ContractStatus): Promise<ContractWithTenant[]> {
  let query = supabase
    .from('contracts')
    .select('*, tenant:tenants(full_name, email), unit:units(unit_number)')
    .order('created_at', { ascending: false })

  if (status) query = query.eq('status', status)

  const { data, error } = await query
  if (error) throw error
  return data as ContractWithTenant[]
}

export async function fetchContractByTenant(tenantId: string): Promise<ContractWithTenant | null> {
  const { data, error } = await supabase
    .from('contracts')
    .select('*, tenant:tenants(full_name, email), unit:units(unit_number)')
    .eq('tenant_id', tenantId)
    .eq('status', 'active')
    .maybeSingle()
  if (error) throw error
  return data as ContractWithTenant | null
}

export async function fetchContract(id: string): Promise<ContractWithTenant> {
  const { data, error } = await supabase
    .from('contracts')
    .select('*, tenant:tenants(full_name, email), unit:units(unit_number)')
    .eq('id', id)
    .single()
  if (error) throw error
  return data as ContractWithTenant
}

export interface CreateContractInput {
  tenant_id: string
  unit_id: string
  start_date: string
  end_date: string
  monthly_rate: number
  deposit: number
  terms?: string
}

export async function createContract(input: CreateContractInput): Promise<Contract> {
  const { data, error } = await supabase
    .from('contracts')
    .insert({ ...input, status: 'active' })
    .select()
    .single()
  if (error) throw error
  return data
}

export async function terminateContract(id: string): Promise<Contract> {
  const { data, error } = await supabase
    .from('contracts')
    .update({ status: 'terminated' })
    .eq('id', id)
    .select()
    .single()
  if (error) throw error
  return data
}

export async function signContract(id: string): Promise<Contract> {
  const { data, error } = await supabase
    .from('contracts')
    .update({ signed_at: new Date().toISOString() })
    .eq('id', id)
    .select()
    .single()
  if (error) throw error
  return data
}
```

- [ ] **Step 4: Create `hooks/useContracts.ts`**

```typescript
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import {
  fetchContracts, fetchContract, fetchContractByTenant,
  createContract, terminateContract, signContract,
} from '../lib/api/contracts'
import type { ContractStatus } from '../types'

export const CONTRACTS_KEY = ['contracts'] as const

export function useContracts(status?: ContractStatus) {
  return useQuery({
    queryKey: [...CONTRACTS_KEY, status],
    queryFn: () => fetchContracts(status),
  })
}

export function useContract(id: string) {
  return useQuery({
    queryKey: [...CONTRACTS_KEY, id],
    queryFn: () => fetchContract(id),
    enabled: !!id,
  })
}

export function useContractByTenant(tenantId: string) {
  return useQuery({
    queryKey: [...CONTRACTS_KEY, 'tenant', tenantId],
    queryFn: () => fetchContractByTenant(tenantId),
    enabled: !!tenantId,
  })
}

export function useCreateContract() {
  const qc = useQueryClient()
  return useMutation({
    mutationFn: createContract,
    onSuccess: () => qc.invalidateQueries({ queryKey: CONTRACTS_KEY }),
  })
}

export function useTerminateContract() {
  const qc = useQueryClient()
  return useMutation({
    mutationFn: terminateContract,
    onSuccess: () => qc.invalidateQueries({ queryKey: CONTRACTS_KEY }),
  })
}

export function useSignContract() {
  const qc = useQueryClient()
  return useMutation({
    mutationFn: signContract,
    onSuccess: () => qc.invalidateQueries({ queryKey: CONTRACTS_KEY }),
  })
}
```

- [ ] **Step 5: Run — expect PASS**

```bash
npx jest __tests__/hooks/useContracts.test.tsx
```

- [ ] **Step 6: Commit**

```bash
git add lib/api/contracts.ts hooks/useContracts.ts __tests__/hooks/useContracts.test.tsx && git commit -m "feat: contracts API and hook"
```

---

### Task 16: Contract Screens

**Files:**
- Create: `app/(admin)/contracts/_layout.tsx`
- Create: `app/(admin)/contracts/index.tsx`
- Create: `app/(admin)/contracts/new.tsx`
- Create: `app/(admin)/contracts/[id].tsx`
- Create: `components/admin/ContractCard.tsx`

- [ ] **Step 1: Create `components/admin/ContractCard.tsx`**

```typescript
import React from 'react'
import { TouchableOpacity, View } from 'react-native'
import { Card, AppText, Badge, contractStatusBadge } from '../ui'
import { formatCurrency } from '../../lib/billing'
import type { ContractWithTenant } from '../../types'

interface ContractCardProps {
  contract: ContractWithTenant
  onPress: () => void
}

export function ContractCard({ contract, onPress }: ContractCardProps) {
  const statusBadge = contractStatusBadge(contract.status)
  const isExpiringSoon = contract.status === 'active' &&
    new Date(contract.end_date) <= new Date(Date.now() + 30 * 24 * 60 * 60 * 1000)

  return (
    <TouchableOpacity onPress={onPress} activeOpacity={0.7} className="mb-3">
      <Card>
        <View className="flex-row items-start justify-between">
          <View className="flex-1">
            <AppText variant="subheading">{contract.tenant.full_name}</AppText>
            <AppText color="secondary" variant="caption">Unit {contract.unit.unit_number}</AppText>
          </View>
          <View className="items-end gap-1">
            <Badge label={statusBadge.label} variant={statusBadge.variant} />
            {isExpiringSoon && <Badge label="Expiring soon" variant="warning" />}
          </View>
        </View>
        <View className="flex-row items-center justify-between mt-2">
          <AppText variant="caption" color="secondary">{contract.start_date} – {contract.end_date}</AppText>
          <AppText variant="caption">{formatCurrency(contract.monthly_rate)}/mo</AppText>
        </View>
        {!contract.signed_at && contract.status === 'active' && (
          <Badge label="Not signed" variant="warning" />
        )}
      </Card>
    </TouchableOpacity>
  )
}
```

- [ ] **Step 2: Create `app/(admin)/contracts/_layout.tsx`**

```typescript
import { Stack } from 'expo-router'

export default function ContractsLayout() {
  return (
    <Stack>
      <Stack.Screen name="index" options={{ title: 'Contracts' }} />
      <Stack.Screen name="new" options={{ title: 'New Contract', presentation: 'modal' }} />
      <Stack.Screen name="[id]" options={{ title: 'Contract' }} />
    </Stack>
  )
}
```

- [ ] **Step 3: Create `app/(admin)/contracts/index.tsx`**

```typescript
import React, { useState } from 'react'
import { View, FlatList } from 'react-native'
import { useRouter } from 'expo-router'
import { useContracts } from '../../../hooks/useContracts'
import { ContractCard } from '../../../components/admin/ContractCard'
import { LoadingSpinner, EmptyState, Button } from '../../../components/ui'
import type { ContractStatus } from '../../../types'

const FILTERS: { label: string; value: ContractStatus | undefined }[] = [
  { label: 'Active', value: 'active' },
  { label: 'All', value: undefined },
  { label: 'Expired', value: 'expired' },
  { label: 'Terminated', value: 'terminated' },
]

export default function ContractsScreen() {
  const router = useRouter()
  const [statusFilter, setStatusFilter] = useState<ContractStatus | undefined>('active')
  const { data: contracts, isLoading } = useContracts(statusFilter)

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
        data={contracts}
        keyExtractor={(c) => c.id}
        contentContainerClassName="p-4"
        renderItem={({ item }) => (
          <ContractCard contract={item} onPress={() => router.push(`/(admin)/contracts/${item.id}`)} />
        )}
        ListEmptyComponent={
          <EmptyState
            title="No contracts"
            description="Create a contract for a monthly tenant"
            actionLabel="New Contract"
            onAction={() => router.push('/(admin)/contracts/new')}
          />
        }
        ListFooterComponent={
          contracts && contracts.length > 0
            ? <Button label="New Contract" variant="secondary" onPress={() => router.push('/(admin)/contracts/new')} className="mt-2" />
            : null
        }
      />
    </View>
  )
}
```

- [ ] **Step 4: Create `app/(admin)/contracts/new.tsx`**

```typescript
import React, { useState } from 'react'
import { View, ScrollView, KeyboardAvoidingView, Platform } from 'react-native'
import { useRouter } from 'expo-router'
import { useCreateContract } from '../../../hooks/useContracts'
import { useTenants } from '../../../hooks/useTenants'
import { Input, Button, AppText } from '../../../components/ui'
import type { TenantWithUnit } from '../../../types'

export default function NewContractScreen() {
  const router = useRouter()
  const { mutateAsync, isPending } = useCreateContract()
  // Only monthly tenants get contracts
  const { data: tenants } = useTenants({ status: 'active', billing_type: 'monthly' })

  const [selectedTenant, setSelectedTenant] = useState<TenantWithUnit | null>(null)
  const [startDate, setStartDate] = useState(new Date().toISOString().split('T')[0])
  const [endDate, setEndDate] = useState('')
  const [monthlyRate, setMonthlyRate] = useState('')
  const [deposit, setDeposit] = useState('0')
  const [terms, setTerms] = useState('')
  const [errors, setErrors] = useState<Record<string, string>>({})

  // Pre-fill rate from tenant's unit when selected
  function handleSelectTenant(tenant: TenantWithUnit) {
    setSelectedTenant(tenant)
    // monthlyRate should come from unit — prompt admin to confirm
  }

  async function handleSubmit() {
    const errs: Record<string, string> = {}
    if (!selectedTenant) errs.tenant = 'Please select a tenant'
    if (!startDate) errs.startDate = 'Start date is required'
    if (!endDate) errs.endDate = 'End date is required'
    if (!monthlyRate || isNaN(parseFloat(monthlyRate))) errs.monthlyRate = 'Valid monthly rate is required'
    if (new Date(endDate) <= new Date(startDate)) errs.endDate = 'End date must be after start date'
    if (Object.keys(errs).length) { setErrors(errs); return }

    await mutateAsync({
      tenant_id: selectedTenant!.id,
      unit_id: selectedTenant!.unit_id!,
      start_date: startDate,
      end_date: endDate,
      monthly_rate: parseFloat(monthlyRate),
      deposit: parseFloat(deposit) || 0,
      terms: terms.trim() || undefined,
    })
    router.back()
  }

  return (
    <KeyboardAvoidingView behavior={Platform.OS === 'ios' ? 'padding' : 'height'} className="flex-1 bg-slate-50">
      <ScrollView contentContainerClassName="p-4">
        <AppText variant="subheading" className="mb-2">Select Monthly Tenant</AppText>
        {errors.tenant && <AppText variant="caption" color="danger" className="mb-2">{errors.tenant}</AppText>}
        {tenants?.length === 0 && (
          <AppText color="muted" variant="caption" className="mb-4">No active monthly tenants found</AppText>
        )}
        {tenants?.map((t) => (
          <Button key={t.id}
            label={`${t.full_name} — Unit ${t.unit?.unit_number ?? '?'}`}
            size="sm"
            variant={selectedTenant?.id === t.id ? 'primary' : 'secondary'}
            onPress={() => handleSelectTenant(t)}
            className="mb-2" />
        ))}

        <Input label="Start Date (YYYY-MM-DD)" value={startDate} onChangeText={setStartDate} error={errors.startDate} />
        <Input label="End Date (YYYY-MM-DD)" value={endDate} onChangeText={setEndDate} error={errors.endDate} placeholder="e.g. 2026-12-31" />
        <Input label="Monthly Rate ($)" value={monthlyRate} onChangeText={setMonthlyRate} keyboardType="decimal-pad" error={errors.monthlyRate} placeholder="500.00" />
        <Input label="Security Deposit ($)" value={deposit} onChangeText={setDeposit} keyboardType="decimal-pad" placeholder="0.00" />
        <Input label="Terms & Conditions (optional)" value={terms} onChangeText={setTerms} multiline numberOfLines={4} placeholder="Standard lease terms..." />

        <Button label="Create Contract" onPress={handleSubmit} loading={isPending} className="mt-4" />
      </ScrollView>
    </KeyboardAvoidingView>
  )
}
```

- [ ] **Step 5: Create `app/(admin)/contracts/[id].tsx`**

```typescript
import React from 'react'
import { View, ScrollView, Alert } from 'react-native'
import { useLocalSearchParams, useRouter } from 'expo-router'
import { useContract, useTerminateContract, useSignContract } from '../../../hooks/useContracts'
import { Button, AppText, LoadingSpinner, Card, Badge, contractStatusBadge } from '../../../components/ui'
import { formatCurrency } from '../../../lib/billing'

export default function ContractDetailScreen() {
  const { id } = useLocalSearchParams<{ id: string }>()
  const router = useRouter()
  const { data: contract, isLoading } = useContract(id)
  const { mutateAsync: terminate, isPending: terminating } = useTerminateContract()
  const { mutateAsync: sign, isPending: signing } = useSignContract()

  if (isLoading) return <LoadingSpinner />
  if (!contract) return null

  const statusBadge = contractStatusBadge(contract.status)
  const isExpired = contract.status === 'active' && new Date(contract.end_date) < new Date()

  function handleTerminate() {
    Alert.alert('Terminate Contract', 'Mark this contract as terminated?', [
      { text: 'Cancel', style: 'cancel' },
      {
        text: 'Terminate',
        style: 'destructive',
        onPress: async () => { await terminate(id); router.back() },
      },
    ])
  }

  return (
    <ScrollView className="flex-1 bg-slate-50" contentContainerClassName="p-4">
      <Card className="mb-4">
        <View className="flex-row items-center gap-2 mb-2">
          <Badge label={statusBadge.label} variant={statusBadge.variant} />
          {isExpired && <Badge label="Expired" variant="neutral" />}
          {!contract.signed_at && contract.status === 'active' && (
            <Badge label="Unsigned" variant="warning" />
          )}
        </View>
        <AppText variant="heading">{contract.tenant.full_name}</AppText>
        <AppText color="secondary">Unit {contract.unit.unit_number}</AppText>
      </Card>

      <Card className="mb-4">
        <AppText variant="label" color="secondary" className="mb-3">Contract Details</AppText>
        <View className="gap-2">
          <Row label="Period" value={`${contract.start_date} – ${contract.end_date}`} />
          <Row label="Monthly Rate" value={formatCurrency(contract.monthly_rate)} />
          <Row label="Deposit" value={formatCurrency(contract.deposit)} />
          {contract.signed_at && (
            <Row label="Signed" value={contract.signed_at.split('T')[0]} />
          )}
        </View>
      </Card>

      {contract.terms && (
        <Card className="mb-4">
          <AppText variant="label" color="secondary" className="mb-2">Terms</AppText>
          <AppText color="secondary">{contract.terms}</AppText>
        </Card>
      )}

      {contract.status === 'active' && !contract.signed_at && (
        <Button label="Mark as Signed" onPress={() => sign(id)} loading={signing} className="mb-3" />
      )}
      {contract.status === 'active' && (
        <Button label="Terminate Contract" variant="danger" onPress={handleTerminate} loading={terminating} />
      )}
    </ScrollView>
  )
}

function Row({ label, value }: { label: string; value: string }) {
  return (
    <View className="flex-row justify-between">
      <AppText color="secondary">{label}</AppText>
      <AppText>{value}</AppText>
    </View>
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
git add app/(admin)/contracts/ components/admin/ContractCard.tsx && git commit -m "feat: contract list, create, and detail screens"
```

---

**Plan 5 complete.** Admin can manage contracts for monthly tenants. Proceed to [Tenant Portal plan](./2026-05-03-apt-mgmt-06-tenant-portal.md).
