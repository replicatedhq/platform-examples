/**
 * Flipt Node.js SDK Example
 *
 * This example demonstrates how to integrate Flipt feature flags
 * into a Node.js application.
 *
 * Install: npm install @flipt-io/flipt
 */

const { FliptClient } = require('@flipt-io/flipt');

// Initialize Flipt client
const flipt = new FliptClient({
  url: process.env.FLIPT_URL || 'http://flipt.flipt.svc.cluster.local:8080',
  // Optional: authentication
  // authentication: {
  //   clientToken: process.env.FLIPT_CLIENT_TOKEN
  // }
});

// Example 1: Simple boolean flag evaluation
async function checkBooleanFlag() {
  try {
    const result = await flipt.evaluateBoolean({
      namespaceKey: 'default',
      flagKey: 'new_dashboard',
      entityId: 'user-123',
      context: {
        email: 'user@example.com',
        plan: 'enterprise',
        region: 'us-east-1'
      }
    });

    if (result.enabled) {
      console.log('✓ New dashboard is enabled for this user');
      return true;
    } else {
      console.log('✗ New dashboard is disabled for this user');
      return false;
    }
  } catch (error) {
    console.error('Error evaluating flag:', error);
    // Default to false on error (fail-safe)
    return false;
  }
}

// Example 2: Variant flag evaluation (A/B testing)
async function checkVariantFlag() {
  try {
    const result = await flipt.evaluateVariant({
      namespaceKey: 'default',
      flagKey: 'checkout_flow',
      entityId: 'user-456',
      context: {
        userId: 'user-456',
        email: 'test@example.com',
        accountAge: '30'
      }
    });

    console.log(`User assigned to variant: ${result.variantKey}`);

    switch (result.variantKey) {
      case 'control':
        return 'original_checkout';
      case 'variant_a':
        return 'streamlined_checkout';
      case 'variant_b':
        return 'express_checkout';
      default:
        return 'original_checkout';
    }
  } catch (error) {
    console.error('Error evaluating variant:', error);
    return 'original_checkout'; // Default variant
  }
}

// Example 3: Batch evaluation (multiple flags at once)
async function evaluateMultipleFlags(userId, context) {
  try {
    const flags = ['new_dashboard', 'dark_mode', 'beta_features'];
    const results = {};

    for (const flagKey of flags) {
      const result = await flipt.evaluateBoolean({
        namespaceKey: 'default',
        flagKey,
        entityId: userId,
        context
      });
      results[flagKey] = result.enabled;
    }

    console.log('Feature flags for user:', results);
    return results;
  } catch (error) {
    console.error('Error evaluating flags:', error);
    return {};
  }
}

// Example 4: Using flags in Express middleware
function createFeatureFlagMiddleware(flipt) {
  return async (req, res, next) => {
    const userId = req.user?.id || 'anonymous';
    const context = {
      email: req.user?.email || '',
      plan: req.user?.plan || 'free',
      ip: req.ip,
      userAgent: req.get('user-agent')
    };

    try {
      // Evaluate all relevant flags for this request
      req.features = await evaluateMultipleFlags(userId, context);
      next();
    } catch (error) {
      console.error('Error loading feature flags:', error);
      req.features = {}; // Empty features on error
      next();
    }
  };
}

// Example 5: Graceful degradation with caching
class FliptCache {
  constructor(flipt, ttlMs = 60000) { // 1 minute default TTL
    this.flipt = flipt;
    this.cache = new Map();
    this.ttlMs = ttlMs;
  }

  getCacheKey(namespaceKey, flagKey, entityId) {
    return `${namespaceKey}:${flagKey}:${entityId}`;
  }

  async evaluateBoolean(namespaceKey, flagKey, entityId, context) {
    const cacheKey = this.getCacheKey(namespaceKey, flagKey, entityId);
    const cached = this.cache.get(cacheKey);

    // Check if cache is valid
    if (cached && Date.now() - cached.timestamp < this.ttlMs) {
      return cached.value;
    }

    // Fetch fresh value
    try {
      const result = await this.flipt.evaluateBoolean({
        namespaceKey,
        flagKey,
        entityId,
        context
      });

      // Update cache
      this.cache.set(cacheKey, {
        value: result,
        timestamp: Date.now()
      });

      return result;
    } catch (error) {
      // Return stale cache on error if available
      if (cached) {
        console.warn('Using stale cache due to error:', error);
        return cached.value;
      }
      throw error;
    }
  }
}

// Example usage in an Express app
const express = require('express');
const app = express();

// Add feature flag middleware
app.use(createFeatureFlagMiddleware(flipt));

app.get('/dashboard', async (req, res) => {
  if (req.features.new_dashboard) {
    res.render('dashboard-v2');
  } else {
    res.render('dashboard-v1');
  }
});

app.get('/api/config', async (req, res) => {
  res.json({
    features: req.features,
    version: '1.0.0'
  });
});

// Main execution
async function main() {
  console.log('Flipt Node.js SDK Examples\n');

  // Example 1: Boolean flag
  console.log('Example 1: Boolean Flag');
  await checkBooleanFlag();
  console.log('');

  // Example 2: Variant flag
  console.log('Example 2: Variant Flag');
  const variant = await checkVariantFlag();
  console.log(`Selected checkout: ${variant}\n`);

  // Example 3: Batch evaluation
  console.log('Example 3: Batch Evaluation');
  await evaluateMultipleFlags('user-789', {
    email: 'user789@example.com',
    plan: 'premium'
  });
  console.log('');

  // Example 4: Cached evaluation
  console.log('Example 4: Cached Evaluation');
  const cachedClient = new FliptCache(flipt);
  const result1 = await cachedClient.evaluateBoolean('default', 'new_dashboard', 'user-123', {});
  console.log('First call (from API):', result1.enabled);
  const result2 = await cachedClient.evaluateBoolean('default', 'new_dashboard', 'user-123', {});
  console.log('Second call (from cache):', result2.enabled);
}

// Run examples if executed directly
if (require.main === module) {
  main().catch(console.error);
}

module.exports = {
  flipt,
  checkBooleanFlag,
  checkVariantFlag,
  evaluateMultipleFlags,
  createFeatureFlagMiddleware,
  FliptCache
};
