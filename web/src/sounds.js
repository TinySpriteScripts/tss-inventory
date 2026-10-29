// Original UI sounds generated locally; no audio downloads or game sound banks.
let audioContext = null;
let noiseBuffer = null;
let lastSoundTime = -Infinity;
let configuration = { enabled: false, volume: 0.2, actions: {} };
let preferences = {};

function volume(value, fallback) {
  return typeof value === "number" && Number.isFinite(value) ? Math.max(0, Math.min(1, value)) : fallback;
}

export function configureSounds(settings, playerPreferences) {
  if (settings) configuration = { ...settings, volume: volume(settings.volume, 0.2) };
  if (playerPreferences) preferences = playerPreferences;
}

function unlockAudio() {
  if (!configuration.enabled) return;
  try {
    const AudioContextClass = window.AudioContext || window.webkitAudioContext;
    if (!AudioContextClass) return;
    if (!audioContext) audioContext = new AudioContextClass();
    if (audioContext.state === "suspended") void audioContext.resume().catch(() => {});
  } catch { /* Unavailable audio must never interrupt an inventory action. */ }
}

window.addEventListener("pointerdown", unlockAudio, { passive: true });
window.addEventListener("keydown", unlockAudio, { passive: true });

function tone(startTime, frequency, endFrequency, duration, level, waveform = "sine") {
  const oscillator = audioContext.createOscillator();
  const envelope = audioContext.createGain();
  oscillator.type = waveform;
  oscillator.frequency.setValueAtTime(frequency, startTime);
  oscillator.frequency.exponentialRampToValueAtTime(endFrequency, startTime + duration);
  envelope.gain.setValueAtTime(0, startTime);
  envelope.gain.linearRampToValueAtTime(level, startTime + 0.004);
  envelope.gain.exponentialRampToValueAtTime(0.00001, startTime + duration);
  oscillator.connect(envelope);
  envelope.connect(audioContext.destination);
  oscillator.onended = () => { oscillator.disconnect(); envelope.disconnect(); };
  oscillator.start(startTime);
  oscillator.stop(startTime + duration);
}

function click(startTime, duration, level, cutoff) {
  if (!noiseBuffer) {
    noiseBuffer = audioContext.createBuffer(1, Math.ceil(audioContext.sampleRate * 0.1), audioContext.sampleRate);
    const samples = noiseBuffer.getChannelData(0);
    for (let sampleIndex = 0; sampleIndex < samples.length; sampleIndex += 1) samples[sampleIndex] = Math.random() * 2 - 1;
  }
  const noise = audioContext.createBufferSource();
  const filter = audioContext.createBiquadFilter();
  const envelope = audioContext.createGain();
  noise.buffer = noiseBuffer;
  filter.type = "lowpass";
  filter.frequency.value = cutoff;
  envelope.gain.setValueAtTime(0, startTime);
  envelope.gain.linearRampToValueAtTime(level, startTime + 0.002);
  envelope.gain.exponentialRampToValueAtTime(0.00001, startTime + duration);
  noise.connect(filter);
  filter.connect(envelope);
  envelope.connect(audioContext.destination);
  noise.onended = () => { noise.disconnect(); filter.disconnect(); envelope.disconnect(); };
  noise.start(startTime);
  noise.stop(startTime + duration);
}

export function playInventorySound(action, previewPreferences = null) {
  const selectedPreferences = previewPreferences || preferences;
  const level = volume(selectedPreferences.soundVolume, configuration.volume);
  if (!configuration.enabled || configuration.actions?.[action] === false || selectedPreferences.soundMuted || level === 0) return;
  unlockAudio();
  if (!audioContext || audioContext.state !== "running") return;
  const startTime = audioContext.currentTime;
  if (startTime - lastSoundTime < 0.045) return;
  lastSoundTime = startTime;
  try {
    if (action === "move") click(startTime, 0.035, level * 0.3, 1800);
    else if (action === "equip") {
      click(startTime, 0.025, level * 0.22, 1400);
      click(startTime + 0.04, 0.035, level * 0.3, 2200);
      tone(startTime + 0.035, 240, 180, 0.055, level * 0.09, "triangle");
    } else if (action === "purchase") {
      tone(startTime, 660, 660, 0.1, level * 0.14);
      tone(startTime + 0.065, 880, 880, 0.14, level * 0.12);
    } else if (action === "reject") tone(startTime, 160, 105, 0.085, level * 0.12);
  } catch { /* Sound failures do not affect the confirmed operation. */ }
}
