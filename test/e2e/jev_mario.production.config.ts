import {defineConfig,devices} from '@playwright/test';
export default defineConfig({testDir:'.',testMatch:'jev_mario.production.spec.ts',workers:1,retries:0,reporter:[['list'],['html',{outputFolder:'jev-public-report',open:'never'}]],use:{baseURL:'https://my-web-app-b67f4.web.app',trace:'retain-on-failure'},projects:[{name:'desktop',use:{...devices['Desktop Chrome']}}]});
