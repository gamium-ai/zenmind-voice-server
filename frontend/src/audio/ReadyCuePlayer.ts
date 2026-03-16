const READY_CUE_FREQUENCY_HZ = 880;
const READY_CUE_DURATION_SECONDS = 0.14;
const READY_CUE_ATTACK_SECONDS = 0.01;
const READY_CUE_RELEASE_SECONDS = 0.03;
const READY_CUE_PEAK_GAIN = 0.035;
const MIN_GAIN = 0.0001;

type BrowserWindow = typeof window & {
  webkitAudioContext?: typeof AudioContext;
};

export class ReadyCuePlayer {
  private audioContext: AudioContext | null = null;
  private activeOscillator: OscillatorNode | null = null;
  private activeGainNode: GainNode | null = null;

  async prime(): Promise<void> {
    if (this.audioContext == null) {
      const AudioContextCtor = window.AudioContext || (window as BrowserWindow).webkitAudioContext;
      if (AudioContextCtor == null) {
        throw new Error('当前浏览器不支持 AudioContext');
      }
      this.audioContext = new AudioContextCtor();
    }

    if (this.audioContext.state === 'suspended') {
      await this.audioContext.resume();
    }
  }

  async playReadyCue(): Promise<void> {
    await this.prime();

    const ctx = this.audioContext;
    if (ctx == null) {
      return;
    }

    this.stop();

    const oscillator = ctx.createOscillator();
    const gainNode = ctx.createGain();
    const startAt = ctx.currentTime + 0.005;
    const attackEndAt = startAt + READY_CUE_ATTACK_SECONDS;
    const stopAt = startAt + READY_CUE_DURATION_SECONDS;
    const releaseStartAt = stopAt - READY_CUE_RELEASE_SECONDS;

    oscillator.type = 'sine';
    oscillator.frequency.setValueAtTime(READY_CUE_FREQUENCY_HZ, startAt);

    gainNode.gain.setValueAtTime(MIN_GAIN, startAt);
    gainNode.gain.linearRampToValueAtTime(READY_CUE_PEAK_GAIN, attackEndAt);
    gainNode.gain.linearRampToValueAtTime(READY_CUE_PEAK_GAIN * 0.65, releaseStartAt);
    gainNode.gain.exponentialRampToValueAtTime(MIN_GAIN, stopAt);

    oscillator.connect(gainNode);
    gainNode.connect(ctx.destination);

    this.activeOscillator = oscillator;
    this.activeGainNode = gainNode;

    await new Promise<void>((resolve) => {
      oscillator.onended = () => {
        if (this.activeOscillator === oscillator) {
          this.activeOscillator = null;
        }
        if (this.activeGainNode === gainNode) {
          this.activeGainNode = null;
        }
        oscillator.disconnect();
        gainNode.disconnect();
        resolve();
      };

      oscillator.start(startAt);
      oscillator.stop(stopAt);
    });
  }

  stop(): void {
    const oscillator = this.activeOscillator;
    const gainNode = this.activeGainNode;

    this.activeOscillator = null;
    this.activeGainNode = null;

    if (oscillator != null) {
      try {
        oscillator.stop();
      } catch {
        // Ignore nodes that have already ended.
      }
      oscillator.disconnect();
    }

    if (gainNode != null) {
      gainNode.disconnect();
    }
  }
}
