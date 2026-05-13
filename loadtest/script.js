import http from 'k6/http';
import { check, sleep } from 'k6';
import { Counter, Trend } from 'k6/metrics';

export const options = {
  scenarios: {
    warmup: {
      executor: 'ramping-vus',
      startVUs: 0,
      stages: [{ duration: '30s', target: 10 }],
      gracefulRampDown: '0s',
    },
    sustained: {
      executor: 'constant-vus',
      vus: 10,
      duration: '2m',
      startTime: '30s',
    },
  },
  thresholds: {
    http_req_failed:   ['rate<0.01'],
    http_req_duration: ['p(95)<300'],
  },
};

const BASE_URL = __ENV.BASE_URL || 'http://localhost:3000';
const API_KEY = __ENV.API_KEY || 'KoMCAd6QYGsMkJEPtknEcGhIrxFwj8TTcRfauIED';

export default function () {
  const isRead = Math.random() < 0.8;

  if (isRead) {
    const res = http.get(`${BASE_URL}/abc123`, { redirects: 0 });
    check(res, {
      'redirect status is 302 or 404': (r) => [302, 404].includes(r.status),
    });
  } else {
    const payload = JSON.stringify({
      target: `https://example.com/page-${Math.floor(Math.random() * 1000)}`,
    });
    const res = http.post(`${BASE_URL}/api/v2/links`, payload, {
      headers: {
        'Content-Type': 'application/json',
        'X-API-Key': API_KEY,
      },
    });
    check(res, {
      'create returns 201': (r) => r.status === 201,
    });
  }

  sleep(Math.random() * 0.5);
}
