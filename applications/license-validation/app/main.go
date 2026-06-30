package main

import (
	"crypto"
	"crypto/rsa"
	"crypto/sha256"
	"crypto/x509"
	"encoding/base64"
	"encoding/json"
	"encoding/pem"
	"fmt"
	"html/template"
	"log"
	"math"
	"net/http"
	"os"
	"strconv"
	"strings"
	"sync"
	"time"
)

// LicenseField represents a single custom license field from the Replicated SDK.
type LicenseField struct {
	Name      string      `json:"name"`
	Title     string      `json:"title"`
	Type      string      `json:"type"`
	Value     any `json:"value"`
	Signature struct {
		V1 string `json:"v1"`
	} `json:"signature"`
}

// LicenseInfo represents the license metadata from the Replicated SDK.
type LicenseInfo struct {
	LicenseID      string     `json:"license_id"`
	InstallationID string     `json:"installation_id"`
	Assignee       string     `json:"assignee"`
	ReleaseChannel string     `json:"release_channel"`
	LicenseType    string     `json:"license_type"`
	ExpirationTime *time.Time `json:"expiration_time"`
}

// AppState holds the current validated license state used for rendering.
type AppState struct {
	// License metadata
	LicenseID      string
	CustomerName   string
	LicenseType    string
	ReleaseChannel string
	ExpirationTime string
	IsExpired      bool

	// Custom fields
	Edition   string
	SeatCount int
	SeatUsage int

	// Validation
	SignatureValid bool
	SignatureError string
	LicenseLoaded  bool
	SDKError       string

	// Derived UI state
	ThemeClass     string
	EditionLabel   string
	SeatPercent    int
	SeatBarClass   string
	FeaturesLocked bool
}

var (
	state     AppState
	stateMu   sync.RWMutex
	publicKey *rsa.PublicKey
	tmpl      *template.Template
)

func main() {
	sdkAddr := os.Getenv("REPLICATED_SDK_ADDRESS")
	if sdkAddr == "" {
		sdkAddr = "http://replicated:3000"
	}

	pubKeyPEM := os.Getenv("REPLICATED_APP_PUBLIC_KEY")
	if pubKeyPEM != "" {
		key, err := parsePublicKey(pubKeyPEM)
		if err != nil {
			log.Printf("WARNING: Failed to parse public key: %v", err)
		} else {
			publicKey = key
			log.Println("Loaded application public key for signature validation")
		}
	} else {
		log.Println("WARNING: REPLICATED_APP_PUBLIC_KEY not set - signature validation disabled")
	}

	seatUsage := 12
	if v := os.Getenv("SIMULATED_SEAT_USAGE"); v != "" {
		if n, err := strconv.Atoi(v); err == nil {
			seatUsage = n
		}
	}

	stateMu.Lock()
	state.SeatUsage = seatUsage
	stateMu.Unlock()

	var err error
	tmpl, err = template.New("index").Funcs(template.FuncMap{
		"lower": strings.ToLower,
	}).Parse(indexHTML)
	if err != nil {
		log.Fatalf("Failed to parse template: %v", err)
	}

	// Start background license polling
	go pollLicense(sdkAddr)

	http.HandleFunc("/", handleIndex)
	http.HandleFunc("/healthz", handleHealthz)

	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}
	log.Printf("License Validation app listening on :%s", port)
	log.Fatal(http.ListenAndServe(":"+port, nil))
}

func pollLicense(sdkAddr string) {
	ticker := time.NewTicker(30 * time.Second)
	defer ticker.Stop()

	// Initial fetch
	fetchLicense(sdkAddr)

	for range ticker.C {
		fetchLicense(sdkAddr)
	}
}

func fetchLicense(sdkAddr string) {
	client := &http.Client{Timeout: 5 * time.Second}

	// Fetch license info
	infoResp, err := client.Get(sdkAddr + "/api/v1/license/info")
	if err != nil {
		stateMu.Lock()
		state.SDKError = fmt.Sprintf("Cannot reach Replicated SDK: %v", err)
		state.LicenseLoaded = false
		state.FeaturesLocked = true
		state.ThemeClass = "theme-error"
		stateMu.Unlock()
		log.Printf("SDK error (license/info): %v", err)
		return
	}
	defer infoResp.Body.Close()

	if infoResp.StatusCode != http.StatusOK {
		stateMu.Lock()
		state.SDKError = fmt.Sprintf("SDK returned status %d for license/info", infoResp.StatusCode)
		state.LicenseLoaded = false
		state.FeaturesLocked = true
		state.ThemeClass = "theme-error"
		stateMu.Unlock()
		return
	}

	var info LicenseInfo
	if err := json.NewDecoder(infoResp.Body).Decode(&info); err != nil {
		stateMu.Lock()
		state.SDKError = fmt.Sprintf("Failed to decode license info: %v", err)
		state.LicenseLoaded = false
		stateMu.Unlock()
		return
	}

	// Fetch license fields
	fieldsResp, err := client.Get(sdkAddr + "/api/v1/license/fields")
	if err != nil {
		stateMu.Lock()
		state.SDKError = fmt.Sprintf("Cannot reach Replicated SDK: %v", err)
		state.LicenseLoaded = false
		stateMu.Unlock()
		log.Printf("SDK error (license/fields): %v", err)
		return
	}
	defer fieldsResp.Body.Close()

	var fields []LicenseField
	if fieldsResp.StatusCode == http.StatusOK {
		if err := json.NewDecoder(fieldsResp.Body).Decode(&fields); err != nil {
			log.Printf("Failed to decode license fields: %v", err)
		}
	}

	// Process and validate
	stateMu.Lock()
	defer stateMu.Unlock()

	state.SDKError = ""
	state.LicenseLoaded = true
	state.LicenseID = info.LicenseID
	state.CustomerName = info.Assignee
	state.LicenseType = info.LicenseType
	state.ReleaseChannel = info.ReleaseChannel

	if info.ExpirationTime != nil {
		state.ExpirationTime = info.ExpirationTime.Format("2006-01-02")
		state.IsExpired = info.ExpirationTime.Before(time.Now())
	} else {
		state.ExpirationTime = "Never"
		state.IsExpired = false
	}

	// Extract custom fields
	state.Edition = "community"
	state.SeatCount = 0
	allSigsValid := true
	sigChecked := false

	for _, f := range fields {
		// Validate signature if public key is available
		if publicKey != nil && f.Signature.V1 != "" {
			sigChecked = true
			if !verifyFieldSignature(f) {
				allSigsValid = false
				log.Printf("Signature validation FAILED for field: %s", f.Name)
			}
		}

		switch f.Name {
		case "edition":
			if v, ok := f.Value.(string); ok {
				state.Edition = v
			}
		case "seat_count":
			switch v := f.Value.(type) {
			case float64:
				state.SeatCount = int(v)
			case string:
				if n, err := strconv.Atoi(v); err == nil {
					state.SeatCount = n
				}
			}
		}
	}

	if publicKey != nil && sigChecked {
		state.SignatureValid = allSigsValid
		if !allSigsValid {
			state.SignatureError = "One or more license field signatures failed validation. License fields may have been tampered with."
		} else {
			state.SignatureError = ""
		}
	} else if publicKey == nil {
		state.SignatureValid = false
		state.SignatureError = "No public key configured - signature validation is disabled"
	} else {
		state.SignatureValid = true
		state.SignatureError = ""
	}

	// Derive UI state
	state.FeaturesLocked = state.IsExpired || (publicKey != nil && sigChecked && !allSigsValid)

	switch state.Edition {
	case "enterprise":
		state.ThemeClass = "theme-enterprise"
		state.EditionLabel = "Enterprise"
	case "trial":
		state.ThemeClass = "theme-trial"
		state.EditionLabel = "Trial"
	case "community":
		state.ThemeClass = "theme-community"
		state.EditionLabel = "Community"
	default:
		state.ThemeClass = "theme-community"
		label := state.Edition
		if len(label) > 0 {
			label = strings.ToUpper(label[:1]) + label[1:]
		}
		state.EditionLabel = label
	}

	if state.FeaturesLocked {
		state.ThemeClass = "theme-error"
	}

	if state.SeatCount > 0 {
		state.SeatPercent = int(math.Min(float64(state.SeatUsage)*100/float64(state.SeatCount), 100))
	} else {
		state.SeatPercent = 0
	}

	switch {
	case state.SeatPercent >= 90:
		state.SeatBarClass = "bar-danger"
	case state.SeatPercent >= 70:
		state.SeatBarClass = "bar-warning"
	default:
		state.SeatBarClass = "bar-ok"
	}

	log.Printf("License updated: customer=%s edition=%s seats=%d/%d sig_valid=%v",
		state.CustomerName, state.Edition, state.SeatUsage, state.SeatCount, state.SignatureValid)
}

func verifyFieldSignature(field LicenseField) bool {
	if publicKey == nil || field.Signature.V1 == "" {
		return false
	}

	sigBytes, err := base64.StdEncoding.DecodeString(field.Signature.V1)
	if err != nil {
		log.Printf("Failed to decode signature for field %s: %v", field.Name, err)
		return false
	}

	// The signed content is the string representation of the field value
	var valueStr string
	switch v := field.Value.(type) {
	case string:
		valueStr = v
	case float64:
		if v == float64(int64(v)) {
			valueStr = strconv.FormatInt(int64(v), 10)
		} else {
			valueStr = strconv.FormatFloat(v, 'f', -1, 64)
		}
	case bool:
		valueStr = strconv.FormatBool(v)
	default:
		valueStr = fmt.Sprintf("%v", v)
	}

	hash := sha256.Sum256([]byte(valueStr))
	err = rsa.VerifyPSS(publicKey, crypto.SHA256, hash[:], sigBytes, nil)
	return err == nil
}

func parsePublicKey(pemStr string) (*rsa.PublicKey, error) {
	block, _ := pem.Decode([]byte(pemStr))
	if block == nil {
		return nil, fmt.Errorf("failed to decode PEM block")
	}

	pub, err := x509.ParsePKIXPublicKey(block.Bytes)
	if err != nil {
		return nil, fmt.Errorf("failed to parse public key: %w", err)
	}

	rsaPub, ok := pub.(*rsa.PublicKey)
	if !ok {
		return nil, fmt.Errorf("public key is not RSA")
	}

	return rsaPub, nil
}

func handleIndex(w http.ResponseWriter, r *http.Request) {
	if r.URL.Path != "/" {
		http.NotFound(w, r)
		return
	}

	stateMu.RLock()
	s := state
	stateMu.RUnlock()

	w.Header().Set("Content-Type", "text/html; charset=utf-8")
	if err := tmpl.Execute(w, s); err != nil {
		log.Printf("Template error: %v", err)
		http.Error(w, "Internal Server Error", http.StatusInternalServerError)
	}
}

func handleHealthz(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	fmt.Fprintf(w, `{"status":"ok"}`)
}

const indexHTML = `<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>License Validation Demo</title>
<style>
  :root {
    --bg: #0f172a;
    --card: #1e293b;
    --text: #e2e8f0;
    --muted: #94a3b8;
    --border: #334155;
  }
  * { margin: 0; padding: 0; box-sizing: border-box; }
  body {
    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
    background: var(--bg);
    color: var(--text);
    min-height: 100vh;
  }

  /* Theme colors */
  .theme-enterprise { --accent: #22c55e; --accent-bg: rgba(34,197,94,0.1); --accent-border: rgba(34,197,94,0.3); }
  .theme-trial { --accent: #f59e0b; --accent-bg: rgba(245,158,11,0.1); --accent-border: rgba(245,158,11,0.3); }
  .theme-community { --accent: #3b82f6; --accent-bg: rgba(59,130,246,0.1); --accent-border: rgba(59,130,246,0.3); }
  .theme-error { --accent: #ef4444; --accent-bg: rgba(239,68,68,0.1); --accent-border: rgba(239,68,68,0.3); }

  .header {
    background: var(--accent-bg);
    border-bottom: 2px solid var(--accent);
    padding: 1.5rem 2rem;
    display: flex;
    align-items: center;
    justify-content: space-between;
  }
  .header h1 { font-size: 1.5rem; }
  .edition-badge {
    background: var(--accent);
    color: #000;
    font-weight: 700;
    padding: 0.35rem 1rem;
    border-radius: 9999px;
    font-size: 0.875rem;
    text-transform: uppercase;
    letter-spacing: 0.05em;
  }

  .container { max-width: 900px; margin: 2rem auto; padding: 0 1.5rem; }

  .alert {
    background: rgba(239,68,68,0.15);
    border: 1px solid rgba(239,68,68,0.4);
    border-radius: 0.5rem;
    padding: 1rem 1.25rem;
    margin-bottom: 1.5rem;
    color: #fca5a5;
  }
  .alert-title { font-weight: 700; margin-bottom: 0.25rem; color: #ef4444; }

  .grid { display: grid; grid-template-columns: 1fr 1fr; gap: 1.5rem; margin-bottom: 1.5rem; }
  @media (max-width: 640px) { .grid { grid-template-columns: 1fr; } }

  .card {
    background: var(--card);
    border: 1px solid var(--border);
    border-radius: 0.75rem;
    padding: 1.5rem;
  }
  .card-title {
    font-size: 0.75rem;
    text-transform: uppercase;
    letter-spacing: 0.1em;
    color: var(--muted);
    margin-bottom: 1rem;
  }

  .info-row { display: flex; justify-content: space-between; padding: 0.5rem 0; border-bottom: 1px solid var(--border); }
  .info-row:last-child { border-bottom: none; }
  .info-label { color: var(--muted); }
  .info-value { font-weight: 500; }

  .seat-meter { margin-top: 0.75rem; }
  .seat-numbers { display: flex; justify-content: space-between; margin-bottom: 0.5rem; font-size: 0.875rem; }
  .seat-bar-bg {
    height: 1.5rem;
    background: var(--border);
    border-radius: 0.75rem;
    overflow: hidden;
  }
  .seat-bar-fill {
    height: 100%;
    border-radius: 0.75rem;
    transition: width 0.5s ease;
  }
  .bar-ok { background: #22c55e; }
  .bar-warning { background: #f59e0b; }
  .bar-danger { background: #ef4444; }

  .sig-status {
    display: flex;
    align-items: center;
    gap: 0.75rem;
    font-size: 1.1rem;
    margin-top: 0.5rem;
  }
  .sig-icon { font-size: 2rem; }
  .sig-valid { color: #22c55e; }
  .sig-invalid { color: #ef4444; }
  .sig-disabled { color: #f59e0b; }
  .sig-detail { font-size: 0.8rem; color: var(--muted); margin-top: 0.25rem; }

  .features { margin-top: 0.75rem; }
  .feature-item {
    display: flex;
    align-items: center;
    gap: 0.5rem;
    padding: 0.5rem 0;
    border-bottom: 1px solid var(--border);
  }
  .feature-item:last-child { border-bottom: none; }
  .feature-check { color: #22c55e; }
  .feature-lock { color: #ef4444; }
  .feature-name { flex: 1; }
  .feature-tier { font-size: 0.75rem; color: var(--muted); }

  .full-width { grid-column: 1 / -1; }

  .sdk-error {
    text-align: center;
    padding: 3rem;
    color: var(--muted);
  }
  .sdk-error h2 { color: var(--text); margin-bottom: 0.5rem; }
</style>
</head>
<body class="{{.ThemeClass}}">
<div class="header">
  <h1>License Validation Demo</h1>
  {{if .LicenseLoaded}}
  <span class="edition-badge">{{.EditionLabel}}</span>
  {{end}}
</div>

<div class="container">
  {{if .SDKError}}
  <div class="sdk-error">
    <h2>Waiting for Replicated SDK</h2>
    <p>{{.SDKError}}</p>
    <p style="margin-top:1rem; font-size:0.875rem;">The app will automatically retry every 30 seconds.</p>
  </div>
  {{else}}

  {{if .FeaturesLocked}}
  <div class="alert">
    <div class="alert-title">License Enforcement Active</div>
    {{if .IsExpired}}
    <p>Your license has expired. Features are locked until the license is renewed.</p>
    {{else if not .SignatureValid}}
    <p>{{.SignatureError}}</p>
    <p style="margin-top:0.5rem">Features are locked because the license could not be verified. Contact your vendor to resolve this issue.</p>
    {{end}}
  </div>
  {{end}}

  <div class="grid">
    <div class="card">
      <div class="card-title">License Details</div>
      <div class="info-row">
        <span class="info-label">Customer</span>
        <span class="info-value">{{.CustomerName}}</span>
      </div>
      <div class="info-row">
        <span class="info-label">License ID</span>
        <span class="info-value" style="font-family:monospace; font-size:0.8rem;">{{.LicenseID}}</span>
      </div>
      <div class="info-row">
        <span class="info-label">Type</span>
        <span class="info-value">{{.LicenseType}}</span>
      </div>
      <div class="info-row">
        <span class="info-label">Channel</span>
        <span class="info-value">{{.ReleaseChannel}}</span>
      </div>
      <div class="info-row">
        <span class="info-label">Expires</span>
        <span class="info-value" {{if .IsExpired}}style="color:#ef4444"{{end}}>
          {{.ExpirationTime}}{{if .IsExpired}} (EXPIRED){{end}}
        </span>
      </div>
    </div>

    <div class="card">
      <div class="card-title">Seat Entitlement</div>
      {{if gt .SeatCount 0}}
      <div class="seat-meter">
        <div class="seat-numbers">
          <span>{{.SeatUsage}} used</span>
          <span>{{.SeatCount}} licensed</span>
        </div>
        <div class="seat-bar-bg">
          <div class="seat-bar-fill {{.SeatBarClass}}" style="width:{{.SeatPercent}}%"></div>
        </div>
        {{if gt .SeatUsage .SeatCount}}
        <p style="color:#ef4444; margin-top:0.75rem; font-size:0.875rem;">
          Seat limit exceeded. {{.SeatUsage}}/{{.SeatCount}} seats in use.
        </p>
        {{end}}
      </div>
      {{else}}
      <p style="color:var(--muted); margin-top:0.5rem;">No seat limit configured (unlimited).</p>
      {{end}}
    </div>

    <div class="card">
      <div class="card-title">Signature Validation</div>
      {{if and .SignatureValid (not .SignatureError)}}
      <div class="sig-status">
        <span class="sig-icon sig-valid">&#10003;</span>
        <div>
          <div>All field signatures verified</div>
          <div class="sig-detail">License fields are authentic and untampered</div>
        </div>
      </div>
      {{else if .SignatureError}}
      <div class="sig-status">
        {{if not .SignatureValid}}
        <span class="sig-icon sig-invalid">&#10007;</span>
        {{else}}
        <span class="sig-icon sig-disabled">&#9888;</span>
        {{end}}
        <div>
          <div>{{.SignatureError}}</div>
          <div class="sig-detail">
            {{if not .SignatureValid}}
            Signature verification uses RSA-PSS with SHA-256 against the application public key
            {{end}}
          </div>
        </div>
      </div>
      {{end}}
    </div>

    <div class="card">
      <div class="card-title">Feature Entitlements</div>
      <div class="features">
        <div class="feature-item">
          {{if and (not .FeaturesLocked) (or (eq .Edition "community") (eq .Edition "trial") (eq .Edition "enterprise"))}}
          <span class="feature-check">&#10003;</span>
          {{else}}
          <span class="feature-lock">&#128274;</span>
          {{end}}
          <span class="feature-name">Core Dashboard</span>
          <span class="feature-tier">All editions</span>
        </div>
        <div class="feature-item">
          {{if and (not .FeaturesLocked) (or (eq .Edition "trial") (eq .Edition "enterprise"))}}
          <span class="feature-check">&#10003;</span>
          {{else}}
          <span class="feature-lock">&#128274;</span>
          {{end}}
          <span class="feature-name">Advanced Analytics</span>
          <span class="feature-tier">Trial + Enterprise</span>
        </div>
        <div class="feature-item">
          {{if and (not .FeaturesLocked) (eq .Edition "enterprise")}}
          <span class="feature-check">&#10003;</span>
          {{else}}
          <span class="feature-lock">&#128274;</span>
          {{end}}
          <span class="feature-name">SSO / SAML Integration</span>
          <span class="feature-tier">Enterprise only</span>
        </div>
        <div class="feature-item">
          {{if and (not .FeaturesLocked) (eq .Edition "enterprise")}}
          <span class="feature-check">&#10003;</span>
          {{else}}
          <span class="feature-lock">&#128274;</span>
          {{end}}
          <span class="feature-name">Audit Logging</span>
          <span class="feature-tier">Enterprise only</span>
        </div>
        <div class="feature-item">
          {{if and (not .FeaturesLocked) (eq .Edition "enterprise")}}
          <span class="feature-check">&#10003;</span>
          {{else}}
          <span class="feature-lock">&#128274;</span>
          {{end}}
          <span class="feature-name">Priority Support</span>
          <span class="feature-tier">Enterprise only</span>
        </div>
      </div>
    </div>
  </div>

  {{end}}
</div>
</body>
</html>`
