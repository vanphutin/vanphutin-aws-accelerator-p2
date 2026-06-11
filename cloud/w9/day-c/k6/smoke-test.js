import http from 'k6/http';
import { check, sleep } from 'k6';

export const options = {
  vus: 10,
  duration: '30s',
  thresholds: {
    http_req_failed: ['rate<0.01'],
    http_req_duration: ['p(95)<300'],
  },
};

const BASE_URL = __ENV.BASE_URL || 'http://api.local';

export default function () {
  const health = http.get(`${BASE_URL}/health`);
  check(health, {
    'health status 200': (r) => r.status === 200,
    'health trả status ok': (r) => r.json('status') === 'ok',
  });

  const listOrders = http.get(`${BASE_URL}/api/orders`);
  check(listOrders, {
    'GET orders status 200': (r) => r.status === 200,
    'GET orders có mảng orders': (r) => Array.isArray(r.json('orders')),
  });

  const createOrder = http.post(
    `${BASE_URL}/api/orders`,
    JSON.stringify({ total: 42, currency: 'USD', item_count: 1 }),
    { headers: { 'Content-Type': 'application/json' } }
  );
  check(createOrder, {
    'POST orders status 201': (r) => r.status === 201,
    'POST orders có order id': (r) => Boolean(r.json('order.id')),
  });

  sleep(1);
}
