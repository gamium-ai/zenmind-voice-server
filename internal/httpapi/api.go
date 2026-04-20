package httpapi

import (
	"bytes"
	"embed"
	"encoding/json"
	"errors"
	"io"
	"io/fs"
	"net/http"
	"path"
	"strings"

	"zenmind-voice-server/internal/config"
	"zenmind-voice-server/internal/tts"
)

//go:embed ui
var embeddedUIFiles embed.FS

type API struct {
	app          *config.App
	voiceCatalog *tts.VoiceCatalog
	uiFS         fs.FS
}

func New(app *config.App, voiceCatalog *tts.VoiceCatalog) *API {
	return NewWithUIFS(app, voiceCatalog, mustEmbeddedUIFS())
}

func NewWithUIFS(app *config.App, voiceCatalog *tts.VoiceCatalog, uiFS fs.FS) *API {
	return &API{app: app, voiceCatalog: voiceCatalog, uiFS: uiFS}
}

func (a *API) Register(mux *http.ServeMux) {
	apiMux := http.NewServeMux()
	apiMux.HandleFunc("/api/voice/capabilities", a.capabilities)
	apiMux.HandleFunc("/api/voice/tts/voices", a.voices)
	apiMux.HandleFunc("/actuator/health", a.health)

	mux.Handle("/api/", apiMux)
	mux.Handle("/actuator/", apiMux)
	mux.Handle("/", http.HandlerFunc(a.serveStatic))
}

func (a *API) capabilities(w http.ResponseWriter, _ *http.Request) {
	clientGate := a.app.Asr.ClientGate.Normalized()
	writeJSON(w, http.StatusOK, map[string]any{
		"websocketPath": "/api/voice/ws",
		"asr": map[string]any{
			"configured": a.app.Asr.Realtime.HasAPIKey(),
			"defaults": map[string]any{
				"sampleRate": 16000,
				"language":   "zh",
				"clientGate": map[string]any{
					"enabled":      clientGate.Enabled,
					"rmsThreshold": clientGate.RMSThreshold,
					"openHoldMs":   clientGate.OpenHoldMs,
					"closeHoldMs":  clientGate.CloseHoldMs,
					"preRollMs":    clientGate.PreRollMs,
				},
				"turnDetection": map[string]any{
					"type":              "server_vad",
					"threshold":         0,
					"silenceDurationMs": 400,
				},
			},
		},
		"tts": map[string]any{
			"modes":             []string{"local", "llm"},
			"deprecatedModes":   []string{"llm"},
			"streamInput":       true,
			"defaultMode":       a.app.Tts.DefaultMode,
			"speechRateDefault": a.app.Tts.Local.SpeechRate,
			"audioFormat": map[string]any{
				"sampleRate":     tts.ParseSampleRate(a.app.Tts.Local.ResponseFormat),
				"channels":       1,
				"responseFormat": tts.NormalizeResponseFormat(a.app.Tts.Local.ResponseFormat),
			},
			"runnerConfigured": a.app.Tts.Llm.Runner.IsConfigured(),
			"voicesEndpoint":   "/api/voice/tts/voices",
		},
	})
}

func (a *API) voices(w http.ResponseWriter, _ *http.Request) {
	voices := make([]map[string]any, 0, len(a.voiceCatalog.ListVoices()))
	defaultVoice := a.voiceCatalog.DefaultVoiceID()
	for _, voice := range a.voiceCatalog.ListVoices() {
		displayName := strings.TrimSpace(voice.DisplayName)
		if displayName == "" {
			displayName = voice.ID
		}
		voices = append(voices, map[string]any{
			"id":          voice.ID,
			"displayName": displayName,
			"provider":    voice.Provider,
			"default":     strings.EqualFold(voice.ID, defaultVoice),
		})
	}
	writeJSON(w, http.StatusOK, map[string]any{
		"defaultVoice": defaultVoice,
		"voices":       voices,
	})
}

func (a *API) health(w http.ResponseWriter, _ *http.Request) {
	writeJSON(w, http.StatusOK, map[string]any{
		"status": "UP",
	})
}

func (a *API) serveStatic(w http.ResponseWriter, r *http.Request) {
	if a.uiFS == nil {
		http.Error(w, "embedded UI is unavailable", http.StatusServiceUnavailable)
		return
	}

	filePath := strings.TrimPrefix(path.Clean("/"+r.URL.Path), "/")
	if filePath == "" || filePath == "." {
		filePath = "index.html"
	}

	if served, err := serveIfPresent(w, r, a.uiFS, filePath); err == nil && served {
		return
	}

	if served, err := serveIfPresent(w, r, a.uiFS, "index.html"); err == nil && served {
		return
	}

	http.Error(w, "embedded UI build is missing index.html; run make frontend-build-embed", http.StatusServiceUnavailable)
}

func writeJSON(w http.ResponseWriter, status int, payload any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(payload)
}

func mustEmbeddedUIFS() fs.FS {
	uiFS, err := fs.Sub(embeddedUIFiles, "ui")
	if err != nil {
		panic(err)
	}
	return uiFS
}

func serveIfPresent(w http.ResponseWriter, r *http.Request, uiFS fs.FS, filePath string) (bool, error) {
	filePath = strings.TrimPrefix(filePath, "/")
	if filePath == "" || filePath == "." {
		filePath = "index.html"
	}

	info, err := fs.Stat(uiFS, filePath)
	if err != nil {
		if errors.Is(err, fs.ErrNotExist) {
			return false, nil
		}
		return false, err
	}
	if info.IsDir() {
		nestedIndex := path.Join(filePath, "index.html")
		nestedInfo, nestedErr := fs.Stat(uiFS, nestedIndex)
		if nestedErr != nil {
			if errors.Is(nestedErr, fs.ErrNotExist) {
				return false, nil
			}
			return false, nestedErr
		}
		info = nestedInfo
		filePath = nestedIndex
	}

	file, err := uiFS.Open(filePath)
	if err != nil {
		return false, err
	}
	defer file.Close()

	reader, ok := file.(io.ReadSeeker)
	if !ok {
		data, readErr := io.ReadAll(file)
		if readErr != nil {
			return false, readErr
		}
		reader = bytes.NewReader(data)
	}

	http.ServeContent(w, r, info.Name(), info.ModTime(), reader)
	return true, nil
}
