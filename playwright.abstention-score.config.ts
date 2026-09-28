import { defineConfig, devices } from '@playwright/test';
export default defineConfig({testDir:'./test/e2e',testMatch:'abstention_score.spec.ts',workers:1,retries:0,
 reporter:[['list'],['json',{outputFile:'abstention-score-report/results.json'}]],
 use:{baseURL:process.env.E2E_BASE_URL||'http://127.0.0.1:4173',trace:'retain-on-failure'},
 webServer:process.env.E2E_BASE_URL?undefined:{command:'python3 -m http.server 4173 --directory web --bind 127.0.0.1',url:'http://127.0.0.1:4173/labs/abstention-score/index.html',reuseExistingServer:false},
 projects:[{name:'desktop',use:{...devices['Desktop Chrome'],viewport:{width:1440,height:1000}}},{name:'mobile',use:{...devices['Pixel 5']}}]});
