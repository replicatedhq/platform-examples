/**
 * Flipt Go SDK Example
 *
 * This example demonstrates how to integrate Flipt feature flags
 * into a Go application.
 *
 * Install: go get go.flipt.io/flipt/rpc/flipt
 */

package main

import (
	"context"
	"fmt"
	"log"
	"net/http"
	"os"
	"time"

	flipt "go.flipt.io/flipt/rpc/flipt"
	"google.golang.org/grpc"
	"google.golang.org/grpc/credentials/insecure"
)

// FliptClient wraps the Flipt gRPC client
type FliptClient struct {
	client flipt.FliptClient
	conn   *grpc.ClientConn
}

// NewFliptClient creates a new Flipt client
func NewFliptClient(address string) (*FliptClient, error) {
	// Connect to Flipt gRPC server
	conn, err := grpc.Dial(
		address,
		grpc.WithTransportCredentials(insecure.NewCredentials()),
		grpc.WithBlock(),
		grpc.WithTimeout(5*time.Second),
	)
	if err != nil {
		return nil, fmt.Errorf("failed to connect to Flipt: %w", err)
	}

	client := flipt.NewFliptClient(conn)
	return &FliptClient{
		client: client,
		conn:   conn,
	}, nil
}

// Close closes the gRPC connection
func (c *FliptClient) Close() error {
	return c.conn.Close()
}

// Example 1: Simple boolean flag evaluation
func (c *FliptClient) CheckBooleanFlag(ctx context.Context, userID string) (bool, error) {
	resp, err := c.client.EvaluateBoolean(ctx, &flipt.EvaluationRequest{
		NamespaceKey: "default",
		FlagKey:      "new_dashboard",
		EntityId:     userID,
		Context: map[string]string{
			"email":  "user@example.com",
			"plan":   "enterprise",
			"region": "us-east-1",
		},
	})
	if err != nil {
		return false, fmt.Errorf("failed to evaluate flag: %w", err)
	}

	if resp.Enabled {
		fmt.Println("✓ New dashboard is enabled for this user")
	} else {
		fmt.Println("✗ New dashboard is disabled for this user")
	}

	return resp.Enabled, nil
}

// Example 2: Variant flag evaluation (A/B testing)
func (c *FliptClient) CheckVariantFlag(ctx context.Context, userID string) (string, error) {
	resp, err := c.client.EvaluateVariant(ctx, &flipt.EvaluationRequest{
		NamespaceKey: "default",
		FlagKey:      "checkout_flow",
		EntityId:     userID,
		Context: map[string]string{
			"userId":     userID,
			"email":      "test@example.com",
			"accountAge": "30",
		},
	})
	if err != nil {
		return "control", fmt.Errorf("failed to evaluate variant: %w", err)
	}

	fmt.Printf("User assigned to variant: %s\n", resp.VariantKey)

	switch resp.VariantKey {
	case "control":
		return "original_checkout", nil
	case "variant_a":
		return "streamlined_checkout", nil
	case "variant_b":
		return "express_checkout", nil
	default:
		return "original_checkout", nil
	}
}

// Example 3: Batch evaluation
func (c *FliptClient) EvaluateMultipleFlags(ctx context.Context, userID string, context map[string]string) (map[string]bool, error) {
	flags := []string{"new_dashboard", "dark_mode", "beta_features"}
	results := make(map[string]bool)

	for _, flagKey := range flags {
		resp, err := c.client.EvaluateBoolean(ctx, &flipt.EvaluationRequest{
			NamespaceKey: "default",
			FlagKey:      flagKey,
			EntityId:     userID,
			Context:      context,
		})
		if err != nil {
			log.Printf("Error evaluating flag %s: %v", flagKey, err)
			results[flagKey] = false
			continue
		}
		results[flagKey] = resp.Enabled
	}

	fmt.Printf("Feature flags for user: %+v\n", results)
	return results, nil
}

// Example 4: HTTP middleware for feature flags
type FeatureFlagMiddleware struct {
	client *FliptClient
}

func NewFeatureFlagMiddleware(client *FliptClient) *FeatureFlagMiddleware {
	return &FeatureFlagMiddleware{client: client}
}

func (m *FeatureFlagMiddleware) Handler(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		ctx := r.Context()

		// Extract user info from request (simplified)
		userID := r.Header.Get("X-User-ID")
		if userID == "" {
			userID = "anonymous"
		}

		context := map[string]string{
			"email":     r.Header.Get("X-User-Email"),
			"plan":      r.Header.Get("X-User-Plan"),
			"ip":        r.RemoteAddr,
			"userAgent": r.UserAgent(),
		}

		// Evaluate flags
		features, err := m.client.EvaluateMultipleFlags(ctx, userID, context)
		if err != nil {
			log.Printf("Error loading feature flags: %v", err)
			features = make(map[string]bool) // Empty on error
		}

		// Add features to context
		type contextKey string
		const featuresKey contextKey = "features"
		ctx = context.WithValue(ctx, featuresKey, features)

		next.ServeHTTP(w, r.WithContext(ctx))
	})
}

// Example 5: Cached client with TTL
type CachedFliptClient struct {
	client *FliptClient
	cache  map[string]*cacheEntry
	ttl    time.Duration
}

type cacheEntry struct {
	value     bool
	timestamp time.Time
}

func NewCachedFliptClient(client *FliptClient, ttl time.Duration) *CachedFliptClient {
	return &CachedFliptClient{
		client: client,
		cache:  make(map[string]*cacheEntry),
		ttl:    ttl,
	}
}

func (c *CachedFliptClient) EvaluateBoolean(ctx context.Context, namespaceKey, flagKey, entityID string, context map[string]string) (bool, error) {
	cacheKey := fmt.Sprintf("%s:%s:%s", namespaceKey, flagKey, entityID)

	// Check cache
	if entry, ok := c.cache[cacheKey]; ok {
		if time.Since(entry.timestamp) < c.ttl {
			return entry.value, nil
		}
	}

	// Fetch fresh value
	resp, err := c.client.client.EvaluateBoolean(ctx, &flipt.EvaluationRequest{
		NamespaceKey: namespaceKey,
		FlagKey:      flagKey,
		EntityId:     entityID,
		Context:      context,
	})
	if err != nil {
		// Return stale cache on error if available
		if entry, ok := c.cache[cacheKey]; ok {
			log.Printf("Using stale cache due to error: %v", err)
			return entry.value, nil
		}
		return false, err
	}

	// Update cache
	c.cache[cacheKey] = &cacheEntry{
		value:     resp.Enabled,
		timestamp: time.Now(),
	}

	return resp.Enabled, nil
}

// Example HTTP handlers
func dashboardHandler(w http.ResponseWriter, r *http.Request) {
	type contextKey string
	const featuresKey contextKey = "features"

	features, ok := r.Context().Value(featuresKey).(map[string]bool)
	if !ok {
		features = make(map[string]bool)
	}

	if features["new_dashboard"] {
		fmt.Fprintf(w, "Showing new dashboard v2")
	} else {
		fmt.Fprintf(w, "Showing old dashboard v1")
	}
}

func configHandler(w http.ResponseWriter, r *http.Request) {
	type contextKey string
	const featuresKey contextKey = "features"

	features, ok := r.Context().Value(featuresKey).(map[string]bool)
	if !ok {
		features = make(map[string]bool)
	}

	w.Header().Set("Content-Type", "application/json")
	fmt.Fprintf(w, `{"features": %+v, "version": "1.0.0"}`, features)
}

func main() {
	// Get Flipt address from environment or use default
	fliptAddr := os.Getenv("FLIPT_ADDR")
	if fliptAddr == "" {
		fliptAddr = "flipt.flipt.svc.cluster.local:9000"
	}

	// Create Flipt client
	client, err := NewFliptClient(fliptAddr)
	if err != nil {
		log.Fatalf("Failed to create Flipt client: %v", err)
	}
	defer client.Close()

	ctx := context.Background()

	fmt.Println("Flipt Go SDK Examples\n")

	// Example 1: Boolean flag
	fmt.Println("Example 1: Boolean Flag")
	_, err = client.CheckBooleanFlag(ctx, "user-123")
	if err != nil {
		log.Printf("Error: %v", err)
	}
	fmt.Println()

	// Example 2: Variant flag
	fmt.Println("Example 2: Variant Flag")
	variant, err := client.CheckVariantFlag(ctx, "user-456")
	if err != nil {
		log.Printf("Error: %v", err)
	} else {
		fmt.Printf("Selected checkout: %s\n", variant)
	}
	fmt.Println()

	// Example 3: Batch evaluation
	fmt.Println("Example 3: Batch Evaluation")
	_, err = client.EvaluateMultipleFlags(ctx, "user-789", map[string]string{
		"email": "user789@example.com",
		"plan":  "premium",
	})
	if err != nil {
		log.Printf("Error: %v", err)
	}
	fmt.Println()

	// Example 4: Cached evaluation
	fmt.Println("Example 4: Cached Evaluation")
	cachedClient := NewCachedFliptClient(client, 1*time.Minute)
	result1, _ := cachedClient.EvaluateBoolean(ctx, "default", "new_dashboard", "user-123", nil)
	fmt.Printf("First call (from API): %v\n", result1)
	result2, _ := cachedClient.EvaluateBoolean(ctx, "default", "new_dashboard", "user-123", nil)
	fmt.Printf("Second call (from cache): %v\n", result2)
	fmt.Println()

	// Example 5: HTTP server with middleware
	fmt.Println("Example 5: Starting HTTP server with feature flag middleware")
	middleware := NewFeatureFlagMiddleware(client)

	mux := http.NewServeMux()
	mux.HandleFunc("/dashboard", dashboardHandler)
	mux.HandleFunc("/api/config", configHandler)

	handler := middleware.Handler(mux)

	fmt.Println("Server listening on :8080")
	log.Fatal(http.ListenAndServe(":8080", handler))
}
