import http from 'k6/http';
import { check, sleep } from 'k6';
import { Rate, Trend } from 'k6/metrics';

// ============================================================
//  KerjaDekat — k6 Load Test untuk Demo HPA Scaling
// ============================================================
//
//  Cara pakai:
//    k6 run k6-hpa-loadtest.js
//
//  Script ini punya 3 fase:
//    1. Ramp-up   : 0 → 80 VUs dalam 1 menit
//    2. Sustained : 80 VUs selama 3 menit (trigger HPA)
//    3. Ramp-down : 80 → 0 VUs dalam 1 menit
//
//  Total durasi: ~5 menit
//  Target: backend /api/health endpoint via Kong proxy
// ============================================================

const BASE_URL = __ENV.BASE_URL || 'http://localhost:9080';

// Custom metrics
const errorRate = new Rate('errors');
const healthLatency = new Trend('health_latency');

export const options = {
  stages: [
    // Fase 1: Ramp-up — naikkan load perlahan
    { duration: '1m', target: 80 },

    // Fase 2: Sustained load — pertahankan 80 VUs
    // HPA scale-up stabilization = 30s, jadi kita tahan 3 menit
    { duration: '3m', target: 80 },

    // Fase 3: Ramp-down — turunkan load
    // HPA scale-down stabilization = 120s, jadi scale-down akan terlihat setelah tes selesai
    { duration: '1m', target: 0 },
  ],
  thresholds: {
    http_req_duration: ['p(95)<2000'],   // 95% request < 2 detik
    errors: ['rate<0.1'],                 // error rate < 10%
  },
};

export default function () {
  // --- Test 1: Backend health endpoint ---
  const healthRes = http.get(`${BASE_URL}/api/health`);
  healthLatency.add(healthRes.timings.duration);

  const healthOk = check(healthRes, {
    'health status 200': (r) => r.status === 200,
    'health body ok': (r) => {
      try {
        return JSON.parse(r.body).status === 'ok';
      } catch {
        return false;
      }
    },
  });
  errorRate.add(!healthOk);

  // --- Test 2: Frontend landing page ---
  const frontRes = http.get(`${BASE_URL}/`);
  check(frontRes, {
    'frontend status 200': (r) => r.status === 200,
    'frontend has title': (r) => r.body && r.body.includes('KerjaDekat'),
  });

  // --- Test 3: API endpoint yang lebih berat (jika ada) ---
  // Ini akan membuat backend bekerja lebih keras
  const endpoints = [
    '/api/health',
    '/api/health',
    '/api/health',
  ];

  for (const ep of endpoints) {
    const res = http.get(`${BASE_URL}${ep}`);
    check(res, {
      [`${ep} status ok`]: (r) => r.status === 200 || r.status === 404,
    });
  }

  // Jeda singkat antar iterasi (simulasi user think-time)
  sleep(0.3);
}

export function handleSummary(data) {
  // Print ringkasan di akhir
  const totalReqs = data.metrics.http_reqs ? data.metrics.http_reqs.values.count : 0;
  const avgDuration = data.metrics.http_req_duration ? data.metrics.http_req_duration.values.avg.toFixed(1) : 0;
  const p95Duration = data.metrics.http_req_duration ? data.metrics.http_req_duration.values['p(95)'].toFixed(1) : 0;
  const errRate = data.metrics.errors ? (data.metrics.errors.values.rate * 100).toFixed(1) : 0;

  console.log('\n' + '='.repeat(60));
  console.log('  KerjaDekat Load Test — Ringkasan');
  console.log('='.repeat(60));
  console.log(`  Total Requests : ${totalReqs}`);
  console.log(`  Avg Latency    : ${avgDuration} ms`);
  console.log(`  P95 Latency    : ${p95Duration} ms`);
  console.log(`  Error Rate     : ${errRate}%`);
  console.log('='.repeat(60));
  console.log('  Cek HPA setelah test:');
  console.log('    kubectl get hpa -n kerjadekat');
  console.log('    kubectl get pods -n kerjadekat');
  console.log('='.repeat(60) + '\n');

  return {
    stdout: textSummary(data, { indent: '  ', enableColors: true }),
  };
}

import { textSummary } from 'https://jslib.k6.io/k6-summary/0.0.2/index.js';
