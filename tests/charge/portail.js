// Test de charge k6 du portail (sections 3.3 et 4, sprints 6 et 9).
// SLO vérifiés par les seuils : p95 < 500 ms, p99 < 1 s, erreurs < 0,5 %.
import http from 'k6/http';
import { check, sleep } from 'k6';

const URL = __ENV.URL_CIBLE;
// jeton d'exemption de la limitation de débit du WAF (fourni par la pipeline, jamais versionné)
const PARAMS = { headers: { 'x-test-charge': __ENV.JETON_CHARGE || '' } };

export const options = {
  insecureSkipTLSVerify: true,
  scenarios: {
    nominal: {
      executor: 'ramping-vus',
      stages: [
        { duration: '30s', target: 20 },
        { duration: '2m', target: 20 },
        { duration: '30s', target: 0 },
      ],
    },
  },
  thresholds: {
    http_req_duration: ['p(95)<500', 'p(99)<1000'],
    http_req_failed: ['rate<0.005'],
    checks: ['rate>0.995'],
  },
};

export default function () {
  const reponses = http.batch([
    ['GET', `${URL}/`, null, PARAMS],
    ['GET', `${URL}/api/health`, null, PARAMS],
    ['GET', `${URL}/api/portefeuilles`, null, PARAMS],
  ]);
  check(reponses[0], { 'accueil 200': (r) => r.status === 200 });
  check(reponses[1], { 'api 200': (r) => r.status === 200 });
  check(reponses[2], { 'portefeuilles 200': (r) => r.status === 200 });
  sleep(1);
}
