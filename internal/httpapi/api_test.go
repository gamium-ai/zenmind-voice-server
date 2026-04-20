package httpapi

import (
	"bytes"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"
	"testing/fstest"

	"zenmind-voice-server/internal/config"
	"zenmind-voice-server/internal/tts"
)

func TestCapabilities(t *testing.T) {
	app := &config.App{}
	*app = *configTestApp()
	api := NewWithUIFS(app, tts.NewVoiceCatalog(app), testUIFS())
	mux := http.NewServeMux()
	api.Register(mux)

	req := httptest.NewRequest(http.MethodGet, "/api/voice/capabilities", nil)
	rec := httptest.NewRecorder()
	mux.ServeHTTP(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("expected 200, got %d", rec.Code)
	}

	var payload map[string]any
	if err := json.Unmarshal(rec.Body.Bytes(), &payload); err != nil {
		t.Fatalf("decode response: %v", err)
	}
	if payload["websocketPath"] != "/api/voice/ws" {
		t.Fatalf("unexpected websocket path: %#v", payload["websocketPath"])
	}
	asrPayload := payload["asr"].(map[string]any)
	defaults := asrPayload["defaults"].(map[string]any)
	clientGate := defaults["clientGate"].(map[string]any)
	if clientGate["enabled"] != true {
		t.Fatalf("expected client gate enabled, got %#v", clientGate["enabled"])
	}
	if clientGate["rmsThreshold"] != 0.008 {
		t.Fatalf("unexpected client gate threshold: %#v", clientGate["rmsThreshold"])
	}
	if clientGate["openHoldMs"] != float64(120) {
		t.Fatalf("unexpected client gate openHoldMs: %#v", clientGate["openHoldMs"])
	}
	if clientGate["closeHoldMs"] != float64(480) {
		t.Fatalf("unexpected client gate closeHoldMs: %#v", clientGate["closeHoldMs"])
	}
	if clientGate["preRollMs"] != float64(240) {
		t.Fatalf("unexpected client gate preRollMs: %#v", clientGate["preRollMs"])
	}
	ttsPayload := payload["tts"].(map[string]any)
	if ttsPayload["streamInput"] != true {
		t.Fatalf("expected streamInput=true")
	}
	deprecatedModes := ttsPayload["deprecatedModes"].([]any)
	if len(deprecatedModes) != 1 || deprecatedModes[0] != "llm" {
		t.Fatalf("unexpected deprecatedModes: %#v", deprecatedModes)
	}
	if ttsPayload["defaultMode"] != "local" {
		t.Fatalf("unexpected defaultMode: %#v", ttsPayload["defaultMode"])
	}
	if ttsPayload["runnerConfigured"] != true {
		t.Fatalf("expected runnerConfigured=true")
	}
	audioFormat := ttsPayload["audioFormat"].(map[string]any)
	if audioFormat["responseFormat"] != "pcm" {
		t.Fatalf("unexpected responseFormat: %#v", audioFormat["responseFormat"])
	}
	if audioFormat["sampleRate"] != float64(24000) {
		t.Fatalf("unexpected sampleRate: %#v", audioFormat["sampleRate"])
	}
}

func TestVoices(t *testing.T) {
	app := &config.App{}
	*app = *configTestApp()
	api := NewWithUIFS(app, tts.NewVoiceCatalog(app), testUIFS())
	mux := http.NewServeMux()
	api.Register(mux)

	req := httptest.NewRequest(http.MethodGet, "/api/voice/tts/voices", nil)
	rec := httptest.NewRecorder()
	mux.ServeHTTP(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("expected 200, got %d", rec.Code)
	}

	var payload struct {
		DefaultVoice string `json:"defaultVoice"`
		Voices       []struct {
			ID      string `json:"id"`
			Default bool   `json:"default"`
		} `json:"voices"`
	}
	if err := json.Unmarshal(rec.Body.Bytes(), &payload); err != nil {
		t.Fatalf("decode response: %v", err)
	}
	if payload.DefaultVoice != "Cherry" {
		t.Fatalf("unexpected default voice: %s", payload.DefaultVoice)
	}
	if len(payload.Voices) != 2 {
		t.Fatalf("expected 2 voices, got %d", len(payload.Voices))
	}
	if payload.Voices[0].ID != "Cherry" || !payload.Voices[0].Default {
		t.Fatalf("unexpected first voice: %+v", payload.Voices[0])
	}
}

func TestStaticRoutesServeEmbeddedUI(t *testing.T) {
	app := &config.App{}
	*app = *configTestApp()
	api := NewWithUIFS(app, tts.NewVoiceCatalog(app), testUIFS())
	mux := http.NewServeMux()
	api.Register(mux)

	rootReq := httptest.NewRequest(http.MethodGet, "/", nil)
	rootRec := httptest.NewRecorder()
	mux.ServeHTTP(rootRec, rootReq)

	if rootRec.Code != http.StatusOK {
		t.Fatalf("GET / expected 200, got %d", rootRec.Code)
	}
	if !bytes.Contains(rootRec.Body.Bytes(), []byte("Embedded Voice Console")) {
		t.Fatalf("GET / body = %q, want embedded index html", rootRec.Body.String())
	}

	assetReq := httptest.NewRequest(http.MethodGet, "/assets/app.js", nil)
	assetRec := httptest.NewRecorder()
	mux.ServeHTTP(assetRec, assetReq)

	if assetRec.Code != http.StatusOK {
		t.Fatalf("GET /assets/app.js expected 200, got %d", assetRec.Code)
	}
	if !bytes.Contains(assetRec.Body.Bytes(), []byte("console.log('voice console')")) {
		t.Fatalf("GET /assets/app.js body = %q, want embedded asset", assetRec.Body.String())
	}
}

func TestStaticRoutesFallbackToIndexHTML(t *testing.T) {
	app := &config.App{}
	*app = *configTestApp()
	api := NewWithUIFS(app, tts.NewVoiceCatalog(app), testUIFS())
	mux := http.NewServeMux()
	api.Register(mux)

	req := httptest.NewRequest(http.MethodGet, "/qa/session/demo", nil)
	rec := httptest.NewRecorder()
	mux.ServeHTTP(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("expected 200, got %d", rec.Code)
	}
	if !bytes.Contains(rec.Body.Bytes(), []byte("Embedded Voice Console")) {
		t.Fatalf("fallback body = %q, want index html", rec.Body.String())
	}
}

func TestStaticRoutesDoNotInterceptAPIPrefixes(t *testing.T) {
	app := &config.App{}
	*app = *configTestApp()
	api := NewWithUIFS(app, tts.NewVoiceCatalog(app), testUIFS())
	mux := http.NewServeMux()
	api.Register(mux)

	apiReq := httptest.NewRequest(http.MethodGet, "/api/voice/capabilities", nil)
	apiRec := httptest.NewRecorder()
	mux.ServeHTTP(apiRec, apiReq)

	if apiRec.Code != http.StatusOK {
		t.Fatalf("GET /api/voice/capabilities expected 200, got %d", apiRec.Code)
	}
	if got := apiRec.Header().Get("Content-Type"); got != "application/json" {
		t.Fatalf("GET /api/voice/capabilities content-type = %q, want application/json", got)
	}

	missingAPIReq := httptest.NewRequest(http.MethodGet, "/api/missing", nil)
	missingAPIRec := httptest.NewRecorder()
	mux.ServeHTTP(missingAPIRec, missingAPIReq)
	if missingAPIRec.Code != http.StatusNotFound {
		t.Fatalf("GET /api/missing expected 404, got %d", missingAPIRec.Code)
	}

	missingActuatorReq := httptest.NewRequest(http.MethodGet, "/actuator/missing", nil)
	missingActuatorRec := httptest.NewRecorder()
	mux.ServeHTTP(missingActuatorRec, missingActuatorReq)
	if missingActuatorRec.Code != http.StatusNotFound {
		t.Fatalf("GET /actuator/missing expected 404, got %d", missingActuatorRec.Code)
	}
}

func configTestApp() *config.App {
	app := &config.App{
		ServerPort: 11953,
	}
	app.Asr.Realtime.APIKey = "sk-asr"
	app.Asr.ClientGate.Enabled = true
	app.Asr.ClientGate.RMSThreshold = 0.008
	app.Asr.ClientGate.OpenHoldMs = 120
	app.Asr.ClientGate.CloseHoldMs = 480
	app.Asr.ClientGate.PreRollMs = 240
	app.Tts.DefaultMode = "local"
	app.Tts.Local.APIKey = "sk-tts"
	app.Tts.Local.ResponseFormat = "pcm"
	app.Tts.Local.SpeechRate = 1.2
	app.Tts.Llm.Runner.BaseURL = "http://localhost:8081"
	app.Tts.Llm.Runner.AgentKey = "demo"
	app.Tts.Voices.DefaultVoice = "Cherry"
	app.Tts.Voices.Options = []config.VoiceOption{
		{ID: "Cherry", DisplayName: "Cherry", Provider: "dashscope"},
		{ID: "Serena", DisplayName: "Serena", Provider: "dashscope"},
	}
	return app
}

func testUIFS() fstest.MapFS {
	return fstest.MapFS{
		"index.html": {
			Data: []byte("<!doctype html><html><body>Embedded Voice Console</body></html>"),
		},
		"assets/app.js": {
			Data: []byte("console.log('voice console')"),
		},
	}
}
