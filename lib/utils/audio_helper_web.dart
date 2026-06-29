// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:js' as js;

void initAudioJs() {
  js.context.callMethod('eval', [
    '''
    if (!window.sleepAudio) {
      window.sleepAudio = {
        ctx: null,
        source: null,
        gainNode: null,
        alarmCtx: null,
        alarmInterval: null,
        type: 'none'
      };
    }
    
    window.sleepAudio.start = function(type) {
      this.stop();
      try {
        const AudioContext = window.AudioContext || window.webkitAudioContext;
        if (!AudioContext) return;
        this.ctx = new AudioContext();
        this.gainNode = this.ctx.createGain();
        this.gainNode.gain.value = 0.5;
        this.gainNode.connect(this.ctx.destination);
        
        if (type === 'bell') {
          const osc = this.ctx.createOscillator();
          const osc2 = this.ctx.createOscillator();
          osc.type = 'sine';
          osc.frequency.setValueAtTime(110, this.ctx.currentTime);
          osc2.type = 'sine';
          osc2.frequency.setValueAtTime(111, this.ctx.currentTime);
          
          const lfo = this.ctx.createOscillator();
          const lfoGain = this.ctx.createGain();
          lfo.frequency.value = 0.2;
          lfoGain.gain.value = 0.1;
          
          lfo.connect(lfoGain);
          lfoGain.connect(osc.frequency);
          
          osc.connect(this.gainNode);
          osc2.connect(this.gainNode);
          
          osc.start();
          osc2.start();
          lfo.start();
          
          this.source = {
            stop: function() {
              osc.stop();
              osc2.stop();
              lfo.stop();
            }
          };
        } else if (type === 'rain' || type === 'waves' || type === 'white') {
          const bufferSize = 2 * this.ctx.sampleRate;
          const noiseBuffer = this.ctx.createBuffer(1, bufferSize, this.ctx.sampleRate);
          const output = noiseBuffer.getChannelData(0);
          
          let lastOut = 0.0;
          for (let i = 0; i < bufferSize; i++) {
            const white = Math.random() * 2 - 1;
            if (type === 'waves' || type === 'rain') {
              output[i] = (lastOut + (0.02 * white)) / 1.02;
              lastOut = output[i];
              output[i] *= 3.5;
            } else {
              output[i] = white * 0.5;
            }
          }
          
          const noiseNode = this.ctx.createBufferSource();
          noiseNode.buffer = noiseBuffer;
          noiseNode.loop = true;
          
          if (type === 'waves') {
            const lfo = this.ctx.createOscillator();
            const lfoGain = this.ctx.createGain();
            lfo.frequency.value = 0.08;
            
            const waveGain = this.ctx.createGain();
            waveGain.gain.value = 0.3;
            
            const filter = this.ctx.createBiquadFilter();
            filter.type = 'lowpass';
            filter.frequency.value = 400;
            
            const filterLFO = this.ctx.createOscillator();
            const filterLFOGain = this.ctx.createGain();
            filterLFO.frequency.value = 0.08;
            filterLFOGain.gain.value = 250;
            
            filterLFO.connect(filterLFOGain);
            filterLFOGain.connect(filter.frequency);
            
            noiseNode.connect(filter);
            filter.connect(waveGain);
            waveGain.connect(this.gainNode);
            
            lfo.connect(lfoGain);
            lfoGain.connect(waveGain.gain);
            
            noiseNode.start();
            lfo.start();
            filterLFO.start();
            
            this.source = {
              stop: function() {
                noiseNode.stop();
                lfo.stop();
                filterLFO.stop();
              }
            };
          } else if (type === 'rain') {
            const filter = this.ctx.createBiquadFilter();
            filter.type = 'bandpass';
            filter.frequency.value = 800;
            filter.Q.value = 1.0;
            
            noiseNode.connect(filter);
            filter.connect(this.gainNode);
            noiseNode.start();
            
            this.source = {
              stop: function() {
                noiseNode.stop();
              }
            };
          } else {
            noiseNode.connect(this.gainNode);
            noiseNode.start();
            
            this.source = {
              stop: function() {
                noiseNode.stop();
              }
            };
          }
        }
        this.type = type;
      } catch (e) {
        console.error(e);
      }
    };

    window.sleepAudio.stop = function() {
      if (this.source) {
        try { this.source.stop(); } catch(e){}
        this.source = null;
      }
      if (this.ctx) {
        try { this.ctx.close(); } catch(e){}
        this.ctx = null;
      }
      this.type = 'none';
    };

    window.sleepAudio.setVolume = function(val) {
      if (this.gainNode && this.ctx) {
        this.gainNode.gain.setValueAtTime(val, this.ctx.currentTime);
      }
    };

    window.sleepAudio.startAlarm = function() {
      this.stopAlarm();
      try {
        const AudioContext = window.AudioContext || window.webkitAudioContext;
        if (!AudioContext) return;
        this.alarmCtx = new AudioContext();
        this.alarmInterval = setInterval(() => {
          if (!this.alarmCtx) return;
          const osc = this.alarmCtx.createOscillator();
          const gain = this.alarmCtx.createGain();
          osc.connect(gain);
          gain.connect(this.alarmCtx.destination);
          
          osc.frequency.setValueAtTime(880, this.alarmCtx.currentTime);
          gain.gain.setValueAtTime(0.25, this.alarmCtx.currentTime);
          gain.gain.exponentialRampToValueAtTime(0.01, this.alarmCtx.currentTime + 0.35);
          
          osc.start();
          osc.stop(this.alarmCtx.currentTime + 0.45);
        }, 800);
      } catch(e) {
        console.error(e);
      }
    };

    window.sleepAudio.stopAlarm = function() {
      if (this.alarmInterval) {
        clearInterval(this.alarmInterval);
        this.alarmInterval = null;
      }
      if (this.alarmCtx) {
        try { this.alarmCtx.close(); } catch(e){}
        this.alarmCtx = null;
      }
    };
    '''
  ]);
}

void startAlarm() {
  js.context['sleepAudio']?.callMethod('startAlarm');
}

void stopAlarm() {
  js.context['sleepAudio']?.callMethod('stopAlarm');
}

void stopAudio() {
  js.context['sleepAudio']?.callMethod('stop');
}

void startAudio(String type) {
  js.context['sleepAudio']?.callMethod('start', [type]);
}

void setAudioVolume(double volume) {
  js.context['sleepAudio']?.callMethod('setVolume', [volume]);
}
