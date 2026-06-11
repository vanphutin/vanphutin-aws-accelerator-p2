import http from 'k6/http';
import { check, sleep } from 'k6';
import { Rate } from 'k6/metrics';

export const canary_error_rate = new Rate('canary_error_rate');

export const options = {
  stages: [
    { duration: '1m', target: 50 },
    { duration: '3m', target: 50 },
    { duration: '1m', target: 0 },
  ],
  thresholds: {
    http_req_duration: ['p(95)<200'],
    http_req_failed: ['rate<0.01'],
    canary_error_rate: ['rate<0.01'],
  },
};

const BASE_URL = __ENV.BASE_URL || 'http://api.local';

function randomOrderPayload() {
  return JSON.stringify({
    total: Math.floor(Math.random() * 200) + 1,
    currency: 'USD',
    item_count: Math.floor(Math.random() * 5) + 1,
  });
}

export default function () {
  const usePost = Math.random() < 0.10;
  const response = usePost
    ? http.post(`${BASE_URL}/api/orders`, randomOrderPayload(), {
        headers: { 'Content-Type': 'application/json' },
      })
    : http.get(`${BASE_URL}/api/orders`);

  const version = response.headers['X-Service-Version'] || response.headers['x-service-version'] || 'unknown';
  const failed = response.status >= 500 || response.status === 0;

  canary_error_rate.add(failed && version === 'canary', { version });

  check(response, {
    'status nhỏ hơn 500': (r) => r.status < 500,
    'response có body': (r) => Boolean(r.body && r.body.length > 0),
  });

  sleep(1);
}

export function handleSummary(data) {
  return {
    stdout: textSummary(data),
    'day-c/k6/load-test-summary.json': JSON.stringify(data, null, 2),
  };
}

function textSummary(data) {
  const p95 = data.metrics.http_req_duration?.percentiles?.['p(95)'];
  const failed = data.metrics.http_req_failed?.rate;
  return [
    'Tóm tắt k6 load test',
    `p95 latency: ${p95} ms`,
    `http_req_failed: ${failed}`,
    'Để xuất Prometheus remote write, chạy:',
    'K6_PROMETHEUS_RW_SERVER_URL=http://localhost:9090/api/v1/write k6 run -o experimental-prometheus-rw day-c/k6/load-test.js',
    '',
  ].join('\n');
}
