# SKILL.md — Frontend Development SOP

> **Tujuan:** Dokumen ini adalah panduan teknis baku (*Standard Operating Procedure*) untuk pengembangan frontend di proyek ini. Setiap fitur baru **wajib** mengikuti pola-pola yang tercantum di sini agar codebase tetap konsisten.
>
> **Referensi Desain:** [`DESIGN.md`](./DESIGN.md) — Design token, color palette, typography, dan component spec.  
> **Referensi API:** [`ROUTES.md`](./ROUTES.md) — Semua endpoint dan auth level per microservice.

---

## Daftar Isi

1. [Stack & Struktur File](#1-stack--struktur-file)
2. [Data Fetching — `createServerFn`](#2-data-fetching--createserverfn)
3. [State Management & Caching — `useQuery`](#3-state-management--caching--usequery)
4. [Error Handling & Resilience](#4-error-handling--resilience)
5. [UI/UX Patterns](#5-uiux-patterns)
6. [Design System](#6-design-system)
7. [Checklist Pembuatan Fitur Baru](#7-checklist-pembuatan-fitur-baru)

---

## 1. Stack & Struktur File

### Tech Stack
| Layer | Library | Versi |
|---|---|---|
| Framework | TanStack Start (Vite + SSR) | latest |
| Routing | TanStack Router | latest |
| Server Functions | `createServerFn` (TanStack Start) | latest |
| Client State & Cache | TanStack Query (`useQuery`) | latest |
| HTTP (client-side) | `apiGet/apiPost` from `@/lib/api/client.ts` | internal |
| Icons | `lucide-react` | latest |
| Styling | Vanilla CSS (design tokens dari `DESIGN.md`) | — |

### Konvensi Nama & Lokasi File

```
frontend/src/
├── lib/
│   ├── api/
│   │   ├── client.ts        # apiGet, apiPost, ApiError, ApiEnvelope<T>
│   │   ├── config.ts        # serviceBase(), ServiceKey, SEED_DEMO_DATE
│   │   ├── types.ts         # Shared API response types
│   │   ├── flights.ts       # Domain-specific fetcher functions
│   │   └── ...              # 1 file per domain (bookings, pricing, dst.)
│   ├── auth/
│   │   └── middleware.ts    # authMiddleware untuk protected server fn
│   ├── dashboard.server.ts  # Server functions untuk halaman dashboard
│   ├── profile.server.ts    # Server functions untuk halaman profile
│   └── my-bookings.server.ts
└── routes/
    └── dashboard.tsx        # Route component — konsumsi server fn via useQuery
```

**Aturan penamaan:**
- File server function: `[nama-halaman].server.ts`
- File API domain: `[nama-domain].ts` di dalam `lib/api/`
- Server function export: `get[Nama]Fn` (contoh: `getDashboardDataFn`, `getProfileFn`)

---

## 2. Data Fetching — `createServerFn`

### Prinsip Utama
- **Semua panggilan API ke microservice dilakukan server-side** — menghindari CORS dan menjaga token tetap di server.
- Gunakan `createServerFn` dari `@tanstack/react-start`, bukan `fetch` langsung di dalam komponen.
- Setiap halaman memiliki file `.server.ts` sendiri.

### Pattern: Public Server Function (tanpa auth)

Gunakan untuk data operasional yang tidak memerlukan JWT (dashboard, flights listing, pricing search).

```typescript
// lib/dashboard.server.ts
import { createServerFn } from "@tanstack/react-start";

const SERVICE_BASE =
  process.env.FLIGHT_OPS_SERVICE_URL ?? "http://localhost:8003";

export const getDashboardDataFn = createServerFn({ method: "GET" }).handler(
  async (): Promise<DashboardData> => {
    // Selalu gunakan Promise.all untuk request paralel
    const [flights, revenue, alerts] = await Promise.all([
      fetchFlights(),
      fetchRevenue(),
      fetchAlerts(),
    ]);
    return { flights, alerts, stats: { flightsToday: flights.length, revenue } };
  },
);
```

### Pattern: Protected Server Function (dengan auth)

Gunakan untuk data yang memerlukan JWT (profile, bookings, payments).

```typescript
// lib/profile.server.ts
import { createServerFn } from "@tanstack/react-start";
import { authMiddleware } from "@/lib/auth/middleware";

export const getProfileFn = createServerFn({ method: "GET" })
  .middleware([authMiddleware])          // ← wajib untuk protected routes
  .handler(async ({ context }): Promise<PassengerProfile> => {
    const { userId, passengerId, accessToken } = context;
    const targetId = passengerId || userId;

    const res = await fetch(`${PASSENGER_BASE}/v1/passengers/${targetId}`, {
      headers: {
        Authorization: `Bearer ${accessToken}`,
        "X-Request-ID": crypto.randomUUID(),  // ← selalu sertakan
        Accept: "application/json",
      },
    });
    // ... error handling & envelope unwrapping
  });
```

### Pattern: Fetcher Helper Internal

Setiap request ke microservice dibungkus dalam fungsi `fetch*` kecil dengan **try/catch** dan fallback:

```typescript
// Pola standar fetcher helper — selalu kembalikan nilai fallback, jangan throw
async function fetchFlights(date: string): Promise<FlightListItem[]> {
  try {
    const res = await fetch(`${FLIGHT_OPS_BASE}/v1/flights?date=${date}`, {
      headers: { Accept: "application/json", "X-Request-ID": crypto.randomUUID() },
      signal: AbortSignal.timeout(5000),   // ← timeout wajib: 5 detik
    });
    if (!res.ok) return [];               // ← non-2xx: kembalikan empty
    const body = await res.json();
    // Unwrap envelope { success, data } atau array langsung
    if (Array.isArray(body)) return body;
    if (Array.isArray(body?.data)) return body.data;
    return [];
  } catch {
    return [];                            // ← network error: kembalikan empty
  }
}
```

### Envelope Unwrapping

Backend bisa mengembalikan dua format — selalu handle keduanya:

```typescript
// Format 1: { success: boolean, data: T }
// Format 2: T langsung (array atau object)

const envelope = await res.json();
if (Array.isArray(envelope)) return envelope;
if ("data" in envelope && envelope.data) return envelope.data;
return fallbackValue;
```

### Service Base URL

Selalu ambil dari environment variable dengan fallback `localhost`:

```typescript
const FLIGHT_OPS_BASE =
  process.env.FLIGHT_OPS_SERVICE_URL ?? "http://localhost:8003";
```

Referensi port lengkap ada di [`ROUTES.md`](./ROUTES.md#service-port-map).

---

## 3. State Management & Caching — `useQuery`

### Konfigurasi Standar

```typescript
// Di dalam komponen React
const { data, isLoading, isError, refetch } = useQuery({
  queryKey: ["dashboard"],          // key unik per halaman/resource
  queryFn: () => getDashboardDataFn(),
  refetchInterval: 60_000,          // auto-refresh: 60 detik untuk data operasional
  staleTime: 30_000,                // stale-while-revalidate: 30 detik
});
```

### Tabel Konfigurasi per Tipe Data

| Tipe Data | `refetchInterval` | `staleTime` | Keterangan |
|---|---|---|---|
| Data operasional real-time (flights, status) | `60_000` | `30_000` | Dashboard, Flight Status |
| Data user (profile, bookings) | `false` | `300_000` | Tidak perlu auto-refresh |
| Data harga / promosi | `300_000` | `60_000` | Sesuai TTL Redis di backend |
| Data referensi (routes, aircraft types) | `false` | `Infinity` | Hampir tidak berubah |

### Query Key Convention

```typescript
// Halaman tunggal
queryKey: ["dashboard"]
queryKey: ["profile"]

// Resource dengan ID
queryKey: ["booking", pnr]
queryKey: ["flight", flightId]

// Resource dengan filter
queryKey: ["flights", { date, origin, destination }]
queryKey: ["prices", flightId, seatClass]
```

### Destructuring Pattern

Selalu destructure `data`, `isLoading`, `isError`, dan `refetch`:

```typescript
const { data, isLoading, isError, refetch } = useQuery({ ... });

// Gunakan nullish coalescing untuk safe defaults
const flights = data?.flights ?? [];
const stats = data?.stats?.flightsToday ?? 0;
```

---

## 4. Error Handling & Resilience

### Prinsip: Graceful Degradation

> **Aturan utama:** Kegagalan satu microservice **tidak boleh membuat halaman crash**. Selalu kembalikan nilai fallback kosong dari fetcher helper.

```typescript
// ✅ BENAR — fallback kosong
async function fetchAlerts(): Promise<DashboardAlert[]> {
  try {
    const res = await fetch(NOTIF_BASE + "/v1/notifications", { ... });
    if (!res.ok) return [];   // service error → empty list
    // ... parse body
  } catch {
    return [];                 // network error → empty list
  }
}

// ❌ SALAH — akan crash seluruh halaman
async function fetchAlerts(): Promise<DashboardAlert[]> {
  const res = await fetch(NOTIF_BASE + "/v1/notifications");
  if (!res.ok) throw new Error("Failed");  // ← jangan throw dari fetcher
  return res.json();
}
```

### Error Banner dengan Retry

Selalu tampilkan error banner (bukan crash) ketika `isError === true`:

```tsx
{isError && (
  <div className="mt-4 flex items-center gap-3 rounded-lg border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-700">
    <AlertCircle className="h-4 w-4 shrink-0" />
    <span>
      Gagal memuat data. Data mungkin tidak lengkap.{" "}
      <button
        onClick={() => refetch()}
        className="font-medium underline underline-offset-2"
      >
        Coba lagi
      </button>
    </span>
  </div>
)}
```

### Timeout Wajib

Setiap `fetch` ke microservice **harus** menggunakan `AbortSignal.timeout`:

```typescript
signal: AbortSignal.timeout(5000),  // 5 detik — tidak boleh lebih dari 10 detik
```

### Header Standar

Setiap request harus menyertakan header ini:

```typescript
headers: {
  Accept: "application/json",
  "X-Request-ID": crypto.randomUUID(),      // untuk distributed tracing
  // jika protected:
  Authorization: `Bearer ${accessToken}`,
}
```

---

## 5. UI/UX Patterns

### 5.1 Skeleton Loading States

**Wajib** untuk setiap section yang menunggu data. Gunakan `animate-pulse` dari Tailwind / utility class CSS:

```tsx
// Skeleton untuk tabel
function FlightsTableSkeleton() {
  return (
    <tbody>
      {Array.from({ length: 5 }).map((_, i) => (
        <tr key={i} className="border-b border-border last:border-0">
          {Array.from({ length: 5 }).map((_, j) => (
            <td key={j} className="px-5 py-3">
              <div className="h-4 w-20 animate-pulse rounded bg-surface" />
            </td>
          ))}
        </tr>
      ))}
    </tbody>
  );
}

// Skeleton untuk list/card
function AlertsSkeleton() {
  return (
    <ul className="divide-y divide-border">
      {Array.from({ length: 4 }).map((_, i) => (
        <li key={i} className="flex items-start gap-3 px-5 py-4">
          <div className="h-5 w-16 animate-pulse rounded-full bg-surface" />
          <div className="flex-1 space-y-1.5">
            <div className="h-4 w-full animate-pulse rounded bg-surface" />
            <div className="h-3 w-12 animate-pulse rounded bg-surface" />
          </div>
        </li>
      ))}
    </ul>
  );
}
```

**Pola render tiga state (loading → empty → data):**

```tsx
{isLoading ? (
  <SkeletonComponent />
) : data.length === 0 ? (
  <EmptyState icon={<Icon className="opacity-30" />} message="Tidak ada data." />
) : (
  <ActualContent data={data} />
)}
```

### 5.2 Prinsip "Honest UI"

> **Jangan pernah menampilkan angka palsu / dummy.** Jika data belum tersedia atau belum dikoneksikan ke API, tampilkan `—` (em dash).

```tsx
// ✅ BENAR — jujur tentang status data
<StatCard value={isLoading ? "…" : data ? formatValue(data) : "—"} />

// ❌ SALAH — data palsu menyesatkan
<StatCard value="98,302" />   // hardcoded fake number
```

**Aturan lengkap:**
- Loading: tampilkan `"…"` (ellipsis)
- Data tersedia: tampilkan nilai aktual yang diformat
- Service belum dikoneksikan: tampilkan `"—"` (em dash)
- Error: tampilkan `"—"` + error banner di atas halaman

### 5.3 Helper Functions untuk UI

Pisahkan logika pemetaan data → UI ke dalam fungsi helper **di luar komponen** agar mudah di-test:

```typescript
// ✅ BENAR — helper terpisah, mudah di-test
export function statusTone(status: string): "green" | "orange" | "red" | "sky" | "stone" {
  const s = status?.toUpperCase() ?? "";
  if (s === "ON_TIME" || s === "ARRIVED" || s === "LANDED") return "green";
  if (s === "BOARDING" || s === "GATE_CLOSED") return "orange";
  if (s === "DELAYED" || s === "CANCELLED") return "red";
  if (s === "SCHEDULED" || s === "IN_AIR") return "sky";
  return "stone";
}

export function statusLabel(status: string): string {
  const map: Record<string, string> = {
    SCHEDULED: "Scheduled", BOARDING: "Boarding",
    DELAYED: "Delayed", CANCELLED: "Cancelled",
    // dst.
  };
  return map[status?.toUpperCase()] ?? status ?? "Unknown";
}
```

**Kapan membuat helper:**
- Mapping status API → warna badge → buat `[entity]Tone()`
- Mapping status API → label human-readable → buat `[entity]Label()`
- Format angka/currency → buat `format[DataType]()`
- Format tanggal/waktu → buat `to[Format]()`

### 5.4 Format Currency IDR

```typescript
function formatRevenue(amount: number, currency: string): string {
  if (!amount) return "—";
  if (currency === "IDR") {
    const m = amount / 1_000_000;
    return m >= 1
      ? `Rp ${m.toFixed(1)} M`
      : `Rp ${(amount / 1_000).toFixed(0)} K`;
  }
  return new Intl.NumberFormat("en-US", {
    style: "currency", currency, maximumFractionDigits: 0,
  }).format(amount);
}
```

### 5.5 Format Tanggal

```typescript
// Tanggal lokal ID untuk subtitle halaman
const today = new Date().toLocaleDateString("id-ID", {
  weekday: "long", day: "numeric", month: "long", year: "numeric",
  timeZone: "Asia/Jakarta",
});

// HH:mm dari ISO string untuk waktu penerbangan
function toHHMM(iso: string): string {
  try {
    return new Date(iso).toLocaleTimeString("id-ID", {
      hour: "2-digit", minute: "2-digit", hour12: false,
      timeZone: "Asia/Jakarta",
    });
  } catch { return "--:--"; }
}
```

### 5.6 Empty State

Setiap list/tabel **wajib** memiliki empty state yang informatif:

```tsx
// Empty state standar
<div className="flex flex-col items-center justify-center px-5 py-10 text-sm text-stone">
  <IconComponent className="mb-2 h-8 w-8 opacity-30" />
  Tidak ada [entitas] [konteks].
</div>

// Empty state di dalam tabel (gunakan colSpan)
<tbody>
  <tr>
    <td colSpan={5} className="px-5 py-10 text-center text-sm text-stone">
      <Plane className="mx-auto mb-2 h-8 w-8 opacity-30" />
      Tidak ada penerbangan hari ini.
    </td>
  </tr>
</tbody>
```

### 5.7 Button IDs untuk Testing

Setiap button interaktif **harus** memiliki `id` yang deskriptif (untuk browser testing dan automation):

```tsx
<button id="dashboard-export-btn" ...>Export</button>
<button id="dashboard-liveops-btn" onClick={() => refetch()} ...>Refresh</button>
<button id="booking-submit-btn" ...>Pesan Sekarang</button>
```

Konvensi: `[halaman]-[aksi]-btn`

### 5.8 Loading State di Button Refresh

```tsx
<button onClick={() => refetch()} ...>
  {isLoading ? (
    <span className="inline-flex items-center gap-1.5">
      <Loader2 className="h-3.5 w-3.5 animate-spin" />
      Memuat…
    </span>
  ) : (
    "Refresh"
  )}
</button>
```

---

## 6. Design System

> Referensi lengkap: [`DESIGN.md`](./DESIGN.md)

### Palet Warna Utama (CSS Variables)

| Token | Nilai | Penggunaan |
|---|---|---|
| `bg-canvas` | `#ffffff` | Background utama halaman |
| `bg-surface` | `#f6f5f4` | Background card, skeleton |
| `bg-surface-soft` | `#fafaf9` | Hover row tabel |
| `text-ink` | `#1a1a1a` | Teks utama, heading |
| `text-charcoal` | `#37352f` | Body text, tabel |
| `text-slate` | `#5d5b54` | Teks sekunder |
| `text-stone` | `#a4a097` | Label muted, empty state |
| `border-border` | `#e5e3df` | Divider tabel, card border |
| `text-link-blue` | `#0075de` | Link inline |

### Tint Cards (KPI / Feature Cards)

```tsx
// Gunakan bg-tint-* untuk KPI metric cards
<div className="rounded-xl bg-tint-lavender p-6"> {/* purple accent */}
<div className="rounded-xl bg-tint-peach p-6">    {/* orange accent */}
<div className="rounded-xl bg-tint-mint p-6">     {/* green accent */}
<div className="rounded-xl bg-tint-sky p-6">      {/* blue accent */}
```

### Badge Tone System

Komponen `<Badge tone={...}>` menerima tone berikut:

| Tone | Warna | Penggunaan |
|---|---|---|
| `green` | Hijau | ON_TIME, ARRIVED, CONFIRMED, SUCCESS |
| `orange` | Oranye | BOARDING, GATE_CLOSED, WARNING |
| `red` | Merah | DELAYED, CANCELLED, FAILED, ERROR |
| `sky` | Biru muda | SCHEDULED, IN_AIR, INFO |
| `purple` | Ungu | PROMO, LOYALTY, MILES |
| `stone` | Abu-abu | Unknown, default |

### Typography Scale (Tailwind Classes)

```
text-[11px] uppercase tracking-wider  → micro label (StatCard, section header)
text-xs                               → caption, timestamp
text-sm                               → body tabel, list item
text-2xl font-semibold               → metric value (StatCard)
text-ink / text-charcoal / text-stone → hirarki teks
```

### Komponen Shared (`@/components/AppLayout`)

```tsx
import { AppLayout, Card, CardHeader, StatCard, Badge } from "@/components/AppLayout";

// AppLayout — wrapper halaman dengan title, subtitle, actions
<AppLayout title="Dashboard" subtitle="Deskripsi" actions={<>...</>}>
  {/* konten */}
</AppLayout>

// Card — container putih dengan border
<Card className="lg:col-span-2">
  <CardHeader title="Judul" action={<a>Lihat semua →</a>} />
  {/* konten */}
</Card>

// StatCard — metric card di grid atas
<StatCard label="Label" value="12,438" delta="+18%" tone="mint" icon={Ticket} />

// Badge — status pill
<Badge tone="green">On Time</Badge>
<Badge tone="red">Delayed</Badge>
```

---

## 7. Checklist Pembuatan Fitur Baru

Gunakan checklist ini sebelum commit setiap fitur baru:

### Server Function (`*.server.ts`)
- [ ] File dibuat di `frontend/src/lib/[nama].server.ts`
- [ ] Export function bernama `get[Nama]Fn`
- [ ] Tipe return sudah didefinisikan dengan `export type`
- [ ] Semua fetcher helper menggunakan `try/catch` dengan fallback
- [ ] `AbortSignal.timeout(5000)` ada di setiap `fetch`
- [ ] Header `X-Request-ID: crypto.randomUUID()` ada di setiap request
- [ ] Service base URL diambil dari `process.env` dengan fallback `localhost`
- [ ] Protected routes menggunakan `.middleware([authMiddleware])`
- [ ] Envelope unwrapping menangani kedua format (`{ data }` dan raw)

### Route Component (`routes/*.tsx`)
- [ ] Import dari file `.server.ts` yang sesuai
- [ ] Menggunakan `useQuery` dengan `queryKey` yang unik
- [ ] `refetchInterval` dan `staleTime` sesuai tipe data (lihat tabel Sec. 3)
- [ ] Render tiga state: `isLoading` → empty → data
- [ ] Skeleton component dibuat untuk setiap section
- [ ] Error banner ditampilkan jika `isError === true`
- [ ] Tidak ada angka/data hardcoded — semua dari API atau `"—"`
- [ ] Semua button punya `id` yang deskriptif
- [ ] Button refresh menampilkan spinner saat `isLoading`

### Design & Accessibility
- [ ] Menggunakan design tokens dari `DESIGN.md` (via Tailwind CSS custom classes)
- [ ] Badge tone menggunakan sistem yang sudah ada (`statusTone()`, `alertTone()`)
- [ ] Format angka/tanggal menggunakan helper function, bukan inline logic
- [ ] Empty state memiliki ikon dan pesan yang informatif
- [ ] Tabel responsif menggunakan `overflow-x-auto`

---

## Appendix: Referensi Cepat

### Environment Variables (Frontend)

```bash
VITE_API_FLIGHT_OPS=http://localhost:8003
VITE_API_INVENTORY=http://localhost:8002
VITE_API_PASSENGER=http://localhost:8001
VITE_API_NOTIFICATION=http://localhost:8004
VITE_API_BOOKING=http://localhost:8005
VITE_API_PRICING=http://localhost:8006
VITE_API_PAYMENT=http://localhost:8007
VITE_API_LOYALTY=http://localhost:8008
VITE_API_CREW=http://localhost:8009
VITE_API_MAINTENANCE=http://localhost:8010

# Server-side (process.env, bukan VITE_)
FLIGHT_OPS_SERVICE_URL=http://localhost:8003
PAYMENT_SERVICE_URL=http://localhost:8007
NOTIFICATION_SERVICE_URL=http://localhost:8004
PASSENGER_SERVICE_URL=http://localhost:8001
BOOKING_SERVICE_URL=http://localhost:8005
```

### Pola Import Standar

```typescript
// Server function
import { createServerFn } from "@tanstack/react-start";
import { authMiddleware } from "@/lib/auth/middleware";

// Client component
import { createFileRoute } from "@tanstack/react-router";
import { useQuery } from "@tanstack/react-query";
import { AppLayout, Card, CardHeader, StatCard, Badge } from "@/components/AppLayout";

// Icons (hanya import yang digunakan)
import { Loader2, AlertCircle, Bell, Plane } from "lucide-react";

// API types
import type { FlightListItem, BookingDetail } from "@/lib/api/types";

// Service-specific API functions
import { apiGet, apiPost } from "@/lib/api/client";
```

### Status Flight Lifecycle

```
SCHEDULED → CHECK_IN_OPEN → BOARDING → GATE_CLOSED → DEPARTED → IN_AIR → LANDED → ARRIVED
                                              ↓
                                      DELAYED / CANCELLED
```

Pemetaan tone: `SCHEDULED/IN_AIR/DEPARTED` → `sky` | `BOARDING/CHECK_IN_OPEN` → `orange` | `DELAYED/CANCELLED` → `red` | `ARRIVED/LANDED` → `green`
