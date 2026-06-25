# Apartment Management App — Plan 2: Properties & Units

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Prerequisite:** Plan 1 (Foundation) complete and all tests passing.

**Goal:** Admin can create properties, add units to each property, set billing type and rate per unit, and view/edit unit details.

**Architecture:** TanStack Query manages remote state. `useProperties` and `useUnits` hooks encapsulate all Supabase calls. Screens compose hooks + UI components. Unit list lives under a property (nested route).

**Tech Stack:** Expo Router, NativeWind, Supabase, TanStack Query, TypeScript

---

### Task 7: Properties API + Hook

**Files:**
- Create: `lib/api/properties.ts`
- Create: `hooks/useProperties.ts`
- Create: `__tests__/hooks/useProperties.test.tsx`

- [ ] **Step 1: Write failing test**

```typescript
// __tests__/hooks/useProperties.test.tsx
import { renderHook, waitFor } from '@testing-library/react-native'
import { createWrapper } from '../helpers/queryWrapper'
import { useProperties } from '../../hooks/useProperties'

jest.mock('../../lib/api/properties', () => ({
  fetchProperties: jest.fn().mockResolvedValue([
    { id: '1', name: 'Building A', address: '123 Main St', admin_id: 'admin1', description: null, created_at: '2025-01-01T00:00:00Z' },
  ]),
}))

test('returns properties list', async () => {
  const { result } = renderHook(() => useProperties(), { wrapper: createWrapper() })
  await waitFor(() => expect(result.current.isSuccess).toBe(true))
  expect(result.current.data).toHaveLength(1)
  expect(result.current.data![0].name).toBe('Building A')
})
```

- [ ] **Step 2: Create test helper `__tests__/helpers/queryWrapper.tsx`**

```typescript
import React from 'react'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'

export function createWrapper() {
  const queryClient = new QueryClient({ defaultOptions: { queries: { retry: false } } })
  return ({ children }: { children: React.ReactNode }) => (
    <QueryClientProvider client={queryClient}>{children}</QueryClientProvider>
  )
}
```

- [ ] **Step 3: Run — expect FAIL**

```bash
npx jest __tests__/hooks/useProperties.test.tsx
```

- [ ] **Step 4: Create `lib/api/properties.ts`**

```typescript
import { supabase } from '../supabase'
import type { Property } from '../../types'

export async function fetchProperties(): Promise<Property[]> {
  const { data, error } = await supabase
    .from('properties')
    .select('*')
    .order('created_at', { ascending: false })
  if (error) throw error
  return data
}

export async function fetchProperty(id: string): Promise<Property> {
  const { data, error } = await supabase
    .from('properties')
    .select('*')
    .eq('id', id)
    .single()
  if (error) throw error
  return data
}

export async function createProperty(input: Pick<Property, 'name' | 'address' | 'description'>): Promise<Property> {
  const { data, error } = await supabase
    .from('properties')
    .insert(input)
    .select()
    .single()
  if (error) throw error
  return data
}

export async function updateProperty(id: string, input: Partial<Pick<Property, 'name' | 'address' | 'description'>>): Promise<Property> {
  const { data, error } = await supabase
    .from('properties')
    .update(input)
    .eq('id', id)
    .select()
    .single()
  if (error) throw error
  return data
}

export async function deleteProperty(id: string): Promise<void> {
  const { error } = await supabase.from('properties').delete().eq('id', id)
  if (error) throw error
}
```

- [ ] **Step 5: Create `hooks/useProperties.ts`**

```typescript
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import { fetchProperties, fetchProperty, createProperty, updateProperty, deleteProperty } from '../lib/api/properties'
import type { Property } from '../types'

export const PROPERTIES_KEY = ['properties'] as const

export function useProperties() {
  return useQuery({ queryKey: PROPERTIES_KEY, queryFn: fetchProperties })
}

export function useProperty(id: string) {
  return useQuery({ queryKey: [...PROPERTIES_KEY, id], queryFn: () => fetchProperty(id), enabled: !!id })
}

export function useCreateProperty() {
  const qc = useQueryClient()
  return useMutation({
    mutationFn: createProperty,
    onSuccess: () => qc.invalidateQueries({ queryKey: PROPERTIES_KEY }),
  })
}

export function useUpdateProperty() {
  const qc = useQueryClient()
  return useMutation({
    mutationFn: ({ id, input }: { id: string; input: Parameters<typeof updateProperty>[1] }) =>
      updateProperty(id, input),
    onSuccess: () => qc.invalidateQueries({ queryKey: PROPERTIES_KEY }),
  })
}

export function useDeleteProperty() {
  const qc = useQueryClient()
  return useMutation({
    mutationFn: deleteProperty,
    onSuccess: () => qc.invalidateQueries({ queryKey: PROPERTIES_KEY }),
  })
}
```

- [ ] **Step 6: Run — expect PASS**

```bash
npx jest __tests__/hooks/useProperties.test.tsx
```

- [ ] **Step 7: Commit**

```bash
git add lib/api/properties.ts hooks/useProperties.ts __tests__/ && git commit -m "feat: properties API and hook"
```

---

### Task 8: Units API + Hook

**Files:**
- Create: `lib/api/units.ts`
- Create: `hooks/useUnits.ts`
- Create: `__tests__/hooks/useUnits.test.tsx`

- [ ] **Step 1: Write failing test**

```typescript
// __tests__/hooks/useUnits.test.tsx
import { renderHook, waitFor } from '@testing-library/react-native'
import { createWrapper } from '../helpers/queryWrapper'
import { useUnits } from '../../hooks/useUnits'

jest.mock('../../lib/api/units', () => ({
  fetchUnits: jest.fn().mockResolvedValue([
    { id: 'u1', property_id: 'p1', unit_number: '101', floor: 1,
      bedrooms: 2, bathrooms: 1, monthly_rate: 500, daily_rate: null,
      billing_type: 'monthly', status: 'available', created_at: '2025-01-01T00:00:00Z' },
  ]),
}))

test('returns units for a property', async () => {
  const { result } = renderHook(() => useUnits('p1'), { wrapper: createWrapper() })
  await waitFor(() => expect(result.current.isSuccess).toBe(true))
  expect(result.current.data![0].unit_number).toBe('101')
})
```

- [ ] **Step 2: Run — expect FAIL**

```bash
npx jest __tests__/hooks/useUnits.test.tsx
```

- [ ] **Step 3: Create `lib/api/units.ts`**

```typescript
import { supabase } from '../supabase'
import type { Unit } from '../../types'

export async function fetchUnits(propertyId: string): Promise<Unit[]> {
  const { data, error } = await supabase
    .from('units')
    .select('*')
    .eq('property_id', propertyId)
    .order('unit_number')
  if (error) throw error
  return data
}

export async function fetchUnit(id: string): Promise<Unit> {
  const { data, error } = await supabase.from('units').select('*').eq('id', id).single()
  if (error) throw error
  return data
}

export async function createUnit(input: Omit<Unit, 'id' | 'created_at'>): Promise<Unit> {
  const { data, error } = await supabase.from('units').insert(input).select().single()
  if (error) throw error
  return data
}

export async function updateUnit(id: string, input: Partial<Omit<Unit, 'id' | 'property_id' | 'created_at'>>): Promise<Unit> {
  const { data, error } = await supabase.from('units').update(input).eq('id', id).select().single()
  if (error) throw error
  return data
}

export async function deleteUnit(id: string): Promise<void> {
  const { error } = await supabase.from('units').delete().eq('id', id)
  if (error) throw error
}
```

- [ ] **Step 4: Create `hooks/useUnits.ts`**

```typescript
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import { fetchUnits, fetchUnit, createUnit, updateUnit, deleteUnit } from '../lib/api/units'

export const unitsKey = (propertyId: string) => ['units', propertyId] as const

export function useUnits(propertyId: string) {
  return useQuery({ queryKey: unitsKey(propertyId), queryFn: () => fetchUnits(propertyId), enabled: !!propertyId })
}

export function useUnit(id: string) {
  return useQuery({ queryKey: ['unit', id], queryFn: () => fetchUnit(id), enabled: !!id })
}

export function useCreateUnit(propertyId: string) {
  const qc = useQueryClient()
  return useMutation({
    mutationFn: createUnit,
    onSuccess: () => qc.invalidateQueries({ queryKey: unitsKey(propertyId) }),
  })
}

export function useUpdateUnit(propertyId: string) {
  const qc = useQueryClient()
  return useMutation({
    mutationFn: ({ id, input }: { id: string; input: Parameters<typeof updateUnit>[1] }) => updateUnit(id, input),
    onSuccess: () => qc.invalidateQueries({ queryKey: unitsKey(propertyId) }),
  })
}

export function useDeleteUnit(propertyId: string) {
  const qc = useQueryClient()
  return useMutation({
    mutationFn: deleteUnit,
    onSuccess: () => qc.invalidateQueries({ queryKey: unitsKey(propertyId) }),
  })
}
```

- [ ] **Step 5: Run — expect PASS**

```bash
npx jest __tests__/hooks/useUnits.test.tsx
```

- [ ] **Step 6: Commit**

```bash
git add lib/api/units.ts hooks/useUnits.ts __tests__/hooks/useUnits.test.tsx && git commit -m "feat: units API and hook"
```

---

### Task 9: Property Screens

**Files:**
- Create: `app/(admin)/properties/_layout.tsx`
- Create: `app/(admin)/properties/index.tsx`
- Create: `app/(admin)/properties/new.tsx`
- Create: `app/(admin)/properties/[id].tsx`
- Create: `components/admin/PropertyCard.tsx`

- [ ] **Step 1: Create `components/admin/PropertyCard.tsx`**

```typescript
import React from 'react'
import { TouchableOpacity, View } from 'react-native'
import { Card, AppText, Badge } from '../ui'
import type { Property } from '../../types'

interface PropertyCardProps {
  property: Property
  unitCount?: number
  onPress: () => void
}

export function PropertyCard({ property, unitCount, onPress }: PropertyCardProps) {
  return (
    <TouchableOpacity onPress={onPress} activeOpacity={0.7} className="mb-3">
      <Card>
        <AppText variant="subheading">{property.name}</AppText>
        <AppText color="secondary" className="mt-1">{property.address}</AppText>
        {unitCount !== undefined && (
          <View className="flex-row items-center mt-2">
            <Badge label={`${unitCount} unit${unitCount !== 1 ? 's' : ''}`} variant="neutral" />
          </View>
        )}
      </Card>
    </TouchableOpacity>
  )
}
```

- [ ] **Step 2: Create `app/(admin)/properties/_layout.tsx`**

```typescript
import { Stack } from 'expo-router'

export default function PropertiesLayout() {
  return (
    <Stack>
      <Stack.Screen name="index" options={{ title: 'Properties' }} />
      <Stack.Screen name="new" options={{ title: 'Add Property', presentation: 'modal' }} />
      <Stack.Screen name="[id]" options={{ title: 'Property' }} />
    </Stack>
  )
}
```

- [ ] **Step 3: Create `app/(admin)/properties/index.tsx`**

```typescript
import React from 'react'
import { View, FlatList } from 'react-native'
import { useRouter } from 'expo-router'
import { useProperties } from '../../../hooks/useProperties'
import { PropertyCard } from '../../../components/admin/PropertyCard'
import { LoadingSpinner, EmptyState, Button } from '../../../components/ui'

export default function PropertiesScreen() {
  const router = useRouter()
  const { data: properties, isLoading } = useProperties()

  if (isLoading) return <LoadingSpinner />

  return (
    <View className="flex-1 bg-slate-50">
      <FlatList
        data={properties}
        keyExtractor={(p) => p.id}
        contentContainerClassName="p-4"
        renderItem={({ item }) => (
          <PropertyCard
            property={item}
            onPress={() => router.push(`/(admin)/properties/${item.id}`)}
          />
        )}
        ListEmptyComponent={
          <EmptyState
            title="No properties yet"
            description="Add your first property to get started"
            actionLabel="Add Property"
            onAction={() => router.push('/(admin)/properties/new')}
          />
        }
        ListFooterComponent={
          properties && properties.length > 0 ? (
            <Button
              label="Add Property"
              onPress={() => router.push('/(admin)/properties/new')}
              variant="secondary"
              className="mt-2"
            />
          ) : null
        }
      />
    </View>
  )
}
```

- [ ] **Step 4: Create `app/(admin)/properties/new.tsx`**

```typescript
import React, { useState } from 'react'
import { View, ScrollView, KeyboardAvoidingView, Platform } from 'react-native'
import { useRouter } from 'expo-router'
import { useCreateProperty } from '../../../hooks/useProperties'
import { Input, Button, AppText } from '../../../components/ui'

export default function NewPropertyScreen() {
  const router = useRouter()
  const { mutateAsync, isPending } = useCreateProperty()
  const [name, setName] = useState('')
  const [address, setAddress] = useState('')
  const [description, setDescription] = useState('')
  const [errors, setErrors] = useState<{ name?: string; address?: string }>({})

  async function handleSubmit() {
    const errs: typeof errors = {}
    if (!name.trim()) errs.name = 'Property name is required'
    if (!address.trim()) errs.address = 'Address is required'
    if (Object.keys(errs).length) { setErrors(errs); return }

    await mutateAsync({ name: name.trim(), address: address.trim(), description: description.trim() || null })
    router.back()
  }

  return (
    <KeyboardAvoidingView behavior={Platform.OS === 'ios' ? 'padding' : 'height'} className="flex-1 bg-slate-50">
      <ScrollView contentContainerClassName="p-4">
        <AppText variant="subheading" className="mb-4">Property Details</AppText>
        <Input label="Property Name" value={name} onChangeText={setName} error={errors.name} placeholder="e.g. Sunset Apartments" />
        <Input label="Address" value={address} onChangeText={setAddress} error={errors.address} placeholder="123 Main Street" />
        <Input label="Description (optional)" value={description} onChangeText={setDescription} multiline numberOfLines={3} placeholder="Additional notes..." />
        <Button label="Create Property" onPress={handleSubmit} loading={isPending} className="mt-4" />
      </ScrollView>
    </KeyboardAvoidingView>
  )
}
```

- [ ] **Step 5: Create `app/(admin)/properties/[id].tsx`**

```typescript
import React, { useState, useEffect } from 'react'
import { View, ScrollView, KeyboardAvoidingView, Platform, Alert } from 'react-native'
import { useLocalSearchParams, useRouter } from 'expo-router'
import { useProperty, useUpdateProperty, useDeleteProperty } from '../../../hooks/useProperties'
import { useUnits } from '../../../hooks/useUnits'
import { Input, Button, AppText, LoadingSpinner, Card } from '../../../components/ui'
import { UnitCard } from '../../../components/admin/UnitCard'

export default function PropertyDetailScreen() {
  const { id } = useLocalSearchParams<{ id: string }>()
  const router = useRouter()
  const { data: property, isLoading } = useProperty(id)
  const { data: units } = useUnits(id)
  const { mutateAsync: update, isPending: updating } = useUpdateProperty()
  const { mutateAsync: remove, isPending: deleting } = useDeleteProperty()

  const [name, setName] = useState('')
  const [address, setAddress] = useState('')
  const [description, setDescription] = useState('')

  useEffect(() => {
    if (property) {
      setName(property.name)
      setAddress(property.address)
      setDescription(property.description ?? '')
    }
  }, [property])

  if (isLoading) return <LoadingSpinner />

  async function handleSave() {
    await update({ id, input: { name: name.trim(), address: address.trim(), description: description.trim() || null } })
    router.back()
  }

  function handleDelete() {
    Alert.alert('Delete Property', 'This will delete the property and all its units. Continue?', [
      { text: 'Cancel', style: 'cancel' },
      { text: 'Delete', style: 'destructive', onPress: async () => { await remove(id); router.back() } },
    ])
  }

  return (
    <KeyboardAvoidingView behavior={Platform.OS === 'ios' ? 'padding' : 'height'} className="flex-1 bg-slate-50">
      <ScrollView contentContainerClassName="p-4">
        <AppText variant="subheading" className="mb-4">Edit Property</AppText>
        <Input label="Property Name" value={name} onChangeText={setName} />
        <Input label="Address" value={address} onChangeText={setAddress} />
        <Input label="Description" value={description} onChangeText={setDescription} multiline numberOfLines={3} />
        <Button label="Save Changes" onPress={handleSave} loading={updating} className="mb-3" />

        <View className="flex-row items-center justify-between mb-3 mt-4">
          <AppText variant="subheading">Units ({units?.length ?? 0})</AppText>
          <Button label="Add Unit" size="sm" onPress={() => router.push(`/(admin)/properties/${id}/units/new`)} />
        </View>
        {units?.map((unit) => (
          <UnitCard key={unit.id} unit={unit} onPress={() => router.push(`/(admin)/properties/${id}/units/${unit.id}`)} />
        ))}

        <Button label="Delete Property" variant="danger" onPress={handleDelete} loading={deleting} className="mt-8" />
      </ScrollView>
    </KeyboardAvoidingView>
  )
}
```

- [ ] **Step 6: Commit**

```bash
git add app/(admin)/properties/ components/admin/PropertyCard.tsx && git commit -m "feat: property list, create, and detail screens"
```

---

### Task 10: Unit Screens

**Files:**
- Create: `app/(admin)/properties/[propertyId]/units/_layout.tsx`
- Create: `app/(admin)/properties/[propertyId]/units/index.tsx`
- Create: `app/(admin)/properties/[propertyId]/units/new.tsx`
- Create: `app/(admin)/properties/[propertyId]/units/[id].tsx`
- Create: `components/admin/UnitCard.tsx`

- [ ] **Step 1: Create `components/admin/UnitCard.tsx`**

```typescript
import React from 'react'
import { TouchableOpacity, View } from 'react-native'
import { Card, AppText, Badge, unitStatusBadge, billingBadge } from '../ui'
import type { Unit } from '../../types'

interface UnitCardProps {
  unit: Unit
  onPress: () => void
}

export function UnitCard({ unit, onPress }: UnitCardProps) {
  const statusBadge = unitStatusBadge(unit.status)
  const billing = billingBadge(unit.billing_type)
  const rate = unit.billing_type === 'monthly' ? unit.monthly_rate : unit.daily_rate

  return (
    <TouchableOpacity onPress={onPress} activeOpacity={0.7} className="mb-3">
      <Card>
        <View className="flex-row items-start justify-between">
          <View className="flex-1">
            <AppText variant="subheading">Unit {unit.unit_number}</AppText>
            {unit.floor !== null && <AppText color="secondary" variant="caption">Floor {unit.floor}</AppText>}
          </View>
          <Badge label={statusBadge.label} variant={statusBadge.variant} />
        </View>
        <View className="flex-row items-center gap-2 mt-2">
          <Badge label={billing.label} variant={billing.variant} />
          <AppText variant="caption" color="secondary">
            ${rate?.toFixed(2)} / {unit.billing_type === 'monthly' ? 'mo' : 'day'}
          </AppText>
        </View>
      </Card>
    </TouchableOpacity>
  )
}
```

- [ ] **Step 2: Create `app/(admin)/properties/[propertyId]/units/_layout.tsx`**

```typescript
import { Stack } from 'expo-router'

export default function UnitsLayout() {
  return (
    <Stack>
      <Stack.Screen name="index" options={{ title: 'Units' }} />
      <Stack.Screen name="new" options={{ title: 'Add Unit', presentation: 'modal' }} />
      <Stack.Screen name="[id]" options={{ title: 'Unit' }} />
    </Stack>
  )
}
```

- [ ] **Step 3: Create `app/(admin)/properties/[propertyId]/units/index.tsx`**

```typescript
import React from 'react'
import { View, FlatList } from 'react-native'
import { useLocalSearchParams, useRouter } from 'expo-router'
import { useUnits } from '../../../../../hooks/useUnits'
import { UnitCard } from '../../../../../components/admin/UnitCard'
import { LoadingSpinner, EmptyState, Button } from '../../../../../components/ui'

export default function UnitsScreen() {
  const { propertyId } = useLocalSearchParams<{ propertyId: string }>()
  const router = useRouter()
  const { data: units, isLoading } = useUnits(propertyId)

  if (isLoading) return <LoadingSpinner />

  return (
    <View className="flex-1 bg-slate-50">
      <FlatList
        data={units}
        keyExtractor={(u) => u.id}
        contentContainerClassName="p-4"
        renderItem={({ item }) => (
          <UnitCard unit={item} onPress={() => router.push(`/(admin)/properties/${propertyId}/units/${item.id}`)} />
        )}
        ListEmptyComponent={
          <EmptyState
            title="No units yet"
            description="Add units to this property"
            actionLabel="Add Unit"
            onAction={() => router.push(`/(admin)/properties/${propertyId}/units/new`)}
          />
        }
        ListFooterComponent={
          units && units.length > 0
            ? <Button label="Add Unit" variant="secondary" onPress={() => router.push(`/(admin)/properties/${propertyId}/units/new`)} className="mt-2" />
            : null
        }
      />
    </View>
  )
}
```

- [ ] **Step 4: Create `app/(admin)/properties/[propertyId]/units/new.tsx`**

```typescript
import React, { useState } from 'react'
import { View, ScrollView, KeyboardAvoidingView, Platform } from 'react-native'
import { useLocalSearchParams, useRouter } from 'expo-router'
import { useCreateUnit } from '../../../../../hooks/useUnits'
import { Input, Button, AppText } from '../../../../../components/ui'
import type { BillingType } from '../../../../../types'

export default function NewUnitScreen() {
  const { propertyId } = useLocalSearchParams<{ propertyId: string }>()
  const router = useRouter()
  const { mutateAsync, isPending } = useCreateUnit(propertyId)
  const [unitNumber, setUnitNumber] = useState('')
  const [floor, setFloor] = useState('')
  const [bedrooms, setBedrooms] = useState('1')
  const [bathrooms, setBathrooms] = useState('1')
  const [billingType, setBillingType] = useState<BillingType>('monthly')
  const [monthlyRate, setMonthlyRate] = useState('')
  const [dailyRate, setDailyRate] = useState('')
  const [errors, setErrors] = useState<Record<string, string>>({})

  async function handleSubmit() {
    const errs: Record<string, string> = {}
    if (!unitNumber.trim()) errs.unitNumber = 'Unit number is required'
    if (billingType === 'monthly' && !monthlyRate) errs.rate = 'Monthly rate is required'
    if (billingType === 'daily' && !dailyRate) errs.rate = 'Daily rate is required'
    if (Object.keys(errs).length) { setErrors(errs); return }

    await mutateAsync({
      property_id: propertyId,
      unit_number: unitNumber.trim(),
      floor: floor ? parseInt(floor) : null,
      bedrooms: parseInt(bedrooms) || 1,
      bathrooms: parseInt(bathrooms) || 1,
      billing_type: billingType,
      monthly_rate: billingType === 'monthly' ? parseFloat(monthlyRate) : null,
      daily_rate: billingType === 'daily' ? parseFloat(dailyRate) : null,
      status: 'available',
    })
    router.back()
  }

  return (
    <KeyboardAvoidingView behavior={Platform.OS === 'ios' ? 'padding' : 'height'} className="flex-1 bg-slate-50">
      <ScrollView contentContainerClassName="p-4">
        <Input label="Unit Number" value={unitNumber} onChangeText={setUnitNumber} error={errors.unitNumber} placeholder="e.g. 101" />
        <Input label="Floor (optional)" value={floor} onChangeText={setFloor} keyboardType="number-pad" placeholder="1" />
        <Input label="Bedrooms" value={bedrooms} onChangeText={setBedrooms} keyboardType="number-pad" />
        <Input label="Bathrooms" value={bathrooms} onChangeText={setBathrooms} keyboardType="number-pad" />

        <AppText variant="label" color="secondary" className="mb-2">Billing Type</AppText>
        <View className="flex-row gap-2 mb-4">
          <Button
            label="Monthly" size="sm"
            variant={billingType === 'monthly' ? 'primary' : 'secondary'}
            onPress={() => setBillingType('monthly')}
            className="flex-1"
          />
          <Button
            label="Daily" size="sm"
            variant={billingType === 'daily' ? 'primary' : 'secondary'}
            onPress={() => setBillingType('daily')}
            className="flex-1"
          />
        </View>

        {billingType === 'monthly'
          ? <Input label="Monthly Rate ($)" value={monthlyRate} onChangeText={setMonthlyRate} keyboardType="decimal-pad" error={errors.rate} placeholder="500.00" />
          : <Input label="Daily Rate ($)" value={dailyRate} onChangeText={setDailyRate} keyboardType="decimal-pad" error={errors.rate} placeholder="25.00" />
        }

        <Button label="Create Unit" onPress={handleSubmit} loading={isPending} className="mt-4" />
      </ScrollView>
    </KeyboardAvoidingView>
  )
}
```

- [ ] **Step 5: Create `app/(admin)/properties/[propertyId]/units/[id].tsx`**

```typescript
import React, { useState, useEffect } from 'react'
import { View, ScrollView, Alert } from 'react-native'
import { useLocalSearchParams, useRouter } from 'expo-router'
import { useUnit, useUpdateUnit, useDeleteUnit } from '../../../../../hooks/useUnits'
import { Input, Button, AppText, LoadingSpinner, Badge, unitStatusBadge } from '../../../../../components/ui'
import type { BillingType, UnitStatus } from '../../../../../types'

export default function UnitDetailScreen() {
  const { propertyId, id } = useLocalSearchParams<{ propertyId: string; id: string }>()
  const router = useRouter()
  const { data: unit, isLoading } = useUnit(id)
  const { mutateAsync: update, isPending: updating } = useUpdateUnit(propertyId)
  const { mutateAsync: remove, isPending: deleting } = useDeleteUnit(propertyId)

  const [unitNumber, setUnitNumber] = useState('')
  const [floor, setFloor] = useState('')
  const [billingType, setBillingType] = useState<BillingType>('monthly')
  const [monthlyRate, setMonthlyRate] = useState('')
  const [dailyRate, setDailyRate] = useState('')
  const [status, setStatus] = useState<UnitStatus>('available')

  useEffect(() => {
    if (unit) {
      setUnitNumber(unit.unit_number)
      setFloor(unit.floor?.toString() ?? '')
      setBillingType(unit.billing_type)
      setMonthlyRate(unit.monthly_rate?.toString() ?? '')
      setDailyRate(unit.daily_rate?.toString() ?? '')
      setStatus(unit.status)
    }
  }, [unit])

  if (isLoading) return <LoadingSpinner />

  async function handleSave() {
    await update({
      id,
      input: {
        unit_number: unitNumber.trim(),
        floor: floor ? parseInt(floor) : null,
        billing_type: billingType,
        monthly_rate: billingType === 'monthly' ? parseFloat(monthlyRate) : null,
        daily_rate: billingType === 'daily' ? parseFloat(dailyRate) : null,
        status,
      },
    })
    router.back()
  }

  function handleDelete() {
    Alert.alert('Delete Unit', 'Delete this unit?', [
      { text: 'Cancel', style: 'cancel' },
      { text: 'Delete', style: 'destructive', onPress: async () => { await remove(id); router.back() } },
    ])
  }

  const statusBadge = unitStatusBadge(status)

  return (
    <ScrollView className="flex-1 bg-slate-50" contentContainerClassName="p-4">
      <Input label="Unit Number" value={unitNumber} onChangeText={setUnitNumber} />
      <Input label="Floor" value={floor} onChangeText={setFloor} keyboardType="number-pad" />

      <AppText variant="label" color="secondary" className="mb-2">Billing Type</AppText>
      <View className="flex-row gap-2 mb-4">
        {(['monthly', 'daily'] as BillingType[]).map((t) => (
          <Button key={t} label={t === 'monthly' ? 'Monthly' : 'Daily'} size="sm"
            variant={billingType === t ? 'primary' : 'secondary'}
            onPress={() => setBillingType(t)} className="flex-1" />
        ))}
      </View>

      {billingType === 'monthly'
        ? <Input label="Monthly Rate ($)" value={monthlyRate} onChangeText={setMonthlyRate} keyboardType="decimal-pad" />
        : <Input label="Daily Rate ($)" value={dailyRate} onChangeText={setDailyRate} keyboardType="decimal-pad" />
      }

      <AppText variant="label" color="secondary" className="mb-2">Status</AppText>
      <View className="flex-row gap-2 mb-4">
        {(['available', 'occupied', 'maintenance'] as UnitStatus[]).map((s) => {
          const b = unitStatusBadge(s)
          return (
            <Button key={s} label={b.label} size="sm"
              variant={status === s ? 'primary' : 'secondary'}
              onPress={() => setStatus(s)} className="flex-1" />
          )
        })}
      </View>

      <Button label="Save Changes" onPress={handleSave} loading={updating} className="mb-3" />
      <Button label="Delete Unit" variant="danger" onPress={handleDelete} loading={deleting} />
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
git add app/(admin)/properties/ components/admin/UnitCard.tsx && git commit -m "feat: unit list, create, and detail screens"
```

---

**Plan 2 complete.** Admin can now manage properties and units. Proceed to [Tenant Management plan](./2026-05-03-apt-mgmt-03-tenants.md).
