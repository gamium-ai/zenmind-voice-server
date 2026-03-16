package config

import (
	"strings"
	"testing"
)

func TestApplyEnvLoadsRequiredVoiceConfig(t *testing.T) {
	setRequiredEnv(t)
	t.Setenv("APP_VOICE_TTS_LOCAL_SPEECH_RATE", "1.5")

	cfg := defaults()
	if err := applyEnv(cfg); err != nil {
		t.Fatalf("applyEnv: %v", err)
	}
	if err := validate(cfg); err != nil {
		t.Fatalf("validate: %v", err)
	}

	if cfg.Asr.Realtime.Model != "asr-model-a" {
		t.Fatalf("unexpected ASR model: %q", cfg.Asr.Realtime.Model)
	}
	if cfg.Tts.Local.Model != "tts-model-a" {
		t.Fatalf("unexpected TTS model: %q", cfg.Tts.Local.Model)
	}
	if cfg.Tts.Voices.DefaultVoice != "voice-a" {
		t.Fatalf("unexpected default voice: %q", cfg.Tts.Voices.DefaultVoice)
	}
	if len(cfg.Tts.Voices.Options) != 2 {
		t.Fatalf("expected 2 voices, got %d", len(cfg.Tts.Voices.Options))
	}
	if cfg.Tts.Voices.Options[0].ID != "voice-a" {
		t.Fatalf("unexpected first voice: %+v", cfg.Tts.Voices.Options[0])
	}
	if cfg.Tts.Local.SpeechRate != 1.5 {
		t.Fatalf("unexpected speech rate: %v", cfg.Tts.Local.SpeechRate)
	}
}

func TestApplyEnvRejectsInvalidVoiceCatalogJSON(t *testing.T) {
	setRequiredEnv(t)
	t.Setenv("APP_VOICE_TTS_VOICES_JSON", "{not-json}")

	cfg := defaults()
	err := applyEnv(cfg)
	if err == nil || !strings.Contains(err.Error(), "APP_VOICE_TTS_VOICES_JSON") {
		t.Fatalf("unexpected error: %v", err)
	}
}

func TestValidateRejectsMissingRequiredConfiguration(t *testing.T) {
	t.Setenv("APP_VOICE_ASR_REALTIME_BASE_URL", "")
	t.Setenv("APP_VOICE_ASR_REALTIME_MODEL", "")
	t.Setenv("APP_VOICE_TTS_LOCAL_ENDPOINT", "")
	t.Setenv("APP_VOICE_TTS_LOCAL_MODEL", "")
	t.Setenv("APP_VOICE_TTS_DEFAULT_VOICE", "")
	t.Setenv("APP_VOICE_TTS_VOICES_JSON", "")

	cfg := defaults()
	if err := applyEnv(cfg); err != nil {
		t.Fatalf("applyEnv: %v", err)
	}
	err := validate(cfg)
	if err == nil {
		t.Fatal("expected validation error")
	}
	for _, envName := range []string{
		"APP_VOICE_ASR_REALTIME_BASE_URL",
		"APP_VOICE_ASR_REALTIME_MODEL",
		"APP_VOICE_TTS_LOCAL_ENDPOINT",
		"APP_VOICE_TTS_LOCAL_MODEL",
		"APP_VOICE_TTS_DEFAULT_VOICE",
		"APP_VOICE_TTS_VOICES_JSON",
	} {
		if !strings.Contains(err.Error(), envName) {
			t.Fatalf("expected %s in error: %v", envName, err)
		}
	}
}

func TestValidateRejectsDefaultVoiceOutsideCatalog(t *testing.T) {
	setRequiredEnv(t)
	t.Setenv("APP_VOICE_TTS_DEFAULT_VOICE", "voice-missing")

	cfg := defaults()
	if err := applyEnv(cfg); err != nil {
		t.Fatalf("applyEnv: %v", err)
	}
	err := validate(cfg)
	if err == nil || !strings.Contains(err.Error(), "APP_VOICE_TTS_DEFAULT_VOICE") {
		t.Fatalf("unexpected error: %v", err)
	}
}

func setRequiredEnv(t *testing.T) {
	t.Helper()
	t.Setenv("APP_VOICE_ASR_REALTIME_BASE_URL", "wss://asr.example.com/realtime")
	t.Setenv("APP_VOICE_ASR_REALTIME_MODEL", "asr-model-a")
	t.Setenv("APP_VOICE_TTS_LOCAL_ENDPOINT", "wss://tts.example.com/realtime")
	t.Setenv("APP_VOICE_TTS_LOCAL_MODEL", "tts-model-a")
	t.Setenv("APP_VOICE_TTS_DEFAULT_VOICE", "voice-a")
	t.Setenv("APP_VOICE_TTS_VOICES_JSON", `[{"id":"voice-a","displayName":"Voice A","provider":"provider-a"},{"id":"voice-b","displayName":"Voice B","provider":"provider-a"}]`)
}
