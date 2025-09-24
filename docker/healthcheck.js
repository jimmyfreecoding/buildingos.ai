#!/usr/bin/env node

/**
 * 健康检查脚本
 * 用于 Docker 容器健康检查
 */

const http = require('http');
const https = require('https');
const url = require('url');

// 默认配置
const DEFAULT_CONFIG = {
  timeout: 5000,
  retries: 3,
  interval: 1000,
};

/**
 * 执行 HTTP 健康检查
 * @param {string} checkUrl - 检查的 URL
 * @param {object} options - 配置选项
 * @returns {Promise<boolean>} - 检查结果
 */
function httpHealthCheck(checkUrl, options = {}) {
  return new Promise((resolve) => {
    const config = { ...DEFAULT_CONFIG, ...options };
    const parsedUrl = url.parse(checkUrl);
    const client = parsedUrl.protocol === 'https:' ? https : http;
    
    const requestOptions = {
      hostname: parsedUrl.hostname,
      port: parsedUrl.port || (parsedUrl.protocol === 'https:' ? 443 : 80),
      path: parsedUrl.path,
      method: 'GET',
      timeout: config.timeout,
      headers: {
        'User-Agent': 'Docker-HealthCheck/1.0',
      },
    };

    const req = client.request(requestOptions, (res) => {
      const isHealthy = res.statusCode >= 200 && res.statusCode < 400;
      resolve(isHealthy);
    });

    req.on('error', () => {
      resolve(false);
    });

    req.on('timeout', () => {
      req.destroy();
      resolve(false);
    });

    req.end();
  });
}

/**
 * 带重试的健康检查
 * @param {string} checkUrl - 检查的 URL
 * @param {object} options - 配置选项
 * @returns {Promise<boolean>} - 检查结果
 */
async function healthCheckWithRetry(checkUrl, options = {}) {
  const config = { ...DEFAULT_CONFIG, ...options };
  
  for (let i = 0; i < config.retries; i++) {
    const isHealthy = await httpHealthCheck(checkUrl, config);
    
    if (isHealthy) {
      return true;
    }
    
    // 如果不是最后一次重试，等待一段时间
    if (i < config.retries - 1) {
      await new Promise(resolve => setTimeout(resolve, config.interval));
    }
  }
  
  return false;
}

/**
 * 主函数
 */
async function main() {
  const args = process.argv.slice(2);
  
  if (args.length === 0) {
    console.error('Usage: healthcheck.js <url> [timeout] [retries]');
    process.exit(1);
  }
  
  const checkUrl = args[0];
  const timeout = parseInt(args[1]) || DEFAULT_CONFIG.timeout;
  const retries = parseInt(args[2]) || DEFAULT_CONFIG.retries;
  
  console.log(`Health checking: ${checkUrl}`);
  console.log(`Timeout: ${timeout}ms, Retries: ${retries}`);
  
  try {
    const isHealthy = await healthCheckWithRetry(checkUrl, {
      timeout,
      retries,
      interval: DEFAULT_CONFIG.interval,
    });
    
    if (isHealthy) {
      console.log('✅ Health check passed');
      process.exit(0);
    } else {
      console.log('❌ Health check failed');
      process.exit(1);
    }
  } catch (error) {
    console.error('❌ Health check error:', error.message);
    process.exit(1);
  }
}

// 如果直接运行此脚本
if (require.main === module) {
  main();
}

module.exports = {
  httpHealthCheck,
  healthCheckWithRetry,
};