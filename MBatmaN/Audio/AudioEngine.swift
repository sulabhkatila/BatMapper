//
//  AudioEngine.swift
//  MBatmaN
//
//  Manages chirp emission and microphone recording with signal processing.
//

import AVFoundation
import Foundation

// MARK: - Chirp Emitter

/// Plays the chirp.wav sonar signal on loop through the speaker.
final class ChirpEmitter {
  private var audioPlayer: AVAudioPlayer?

  /// Start playing the chirp signal on loop.
  func start() {
    guard let url = Bundle.main.url(forResource: "chirp", withExtension: "wav") else {
      print("[ChirpEmitter] chirp.wav not found in bundle")
      return
    }

    do {
      audioPlayer = try AVAudioPlayer(contentsOf: url)
      audioPlayer?.numberOfLoops = -1
      audioPlayer?.volume = 1.0
      audioPlayer?.play()
      print("[ChirpEmitter] Started chirp playback")
    } catch {
      print("[ChirpEmitter] Error playing chirp: \(error)")
    }
  }

  /// Pause playback (can be resumed).
  func pause() {
    audioPlayer?.pause()
  }

  /// Stop and release the player.
  func stop() {
    audioPlayer?.stop()
    audioPlayer = nil
  }
}

// MARK: - Audio Recorder

/// Records audio from the microphone at 48kHz and processes it through
/// the signal processing pipeline to extract wall distances.
///
/// The audio tap callback runs on a background audio thread.
/// Signal processing (nonisolated) runs there too.
/// Only the published distance values are dispatched to main.
final class AudioRecorder {
  // MARK: - Published distances (read from main thread only)
  private(set) var distL: Float = 0
  private(set) var distR: Float = 0

  // MARK: - Private state
  private var audioEngine: AVAudioEngine?
  // Signal processing runs on the audio thread — marked nonisolated/Sendable
  // The paper only accounted for 2 microphones
  // NOTE: Recent iPhone's have 2 additional microphones on the back
  // (If able to account for that.... maybe even better outcomes??)
  private nonisolated(unsafe) let signalProL = SignalProcessing()
  private nonisolated(unsafe) let signalProR = SignalProcessing()
  private var isRecording = false

  /// Target sample rate
  private let sampleRate: Double = 48000

  /// Buffer size: 2 * 70ms at 48kHz
  private let bufferSize: Int = 2 * 70 * 48000 / 1000

  // MARK: - Public API

  /// Start recording and processing audio.
  func start() {
    guard !isRecording else { return }

    // Configure audio session for playback and recording simultaneously
    let session = AVAudioSession.sharedInstance()
    do {
      try session.setCategory(
        .playAndRecord, mode: .measurement, options: [.defaultToSpeaker, .allowBluetoothHFP])
      try session.setPreferredSampleRate(sampleRate)
      try session.setActive(true)
    } catch {
      print("[AudioRecorder] Audio session error: \(error)")
      return
    }

    audioEngine = AVAudioEngine()
    guard let engine = audioEngine else { return }

    let inputNode = engine.inputNode
    let inputFormat = inputNode.outputFormat(forBus: 0)

    let channelCount = Int(inputFormat.channelCount)
    let halfBuffer = bufferSize / 2

    // Capture references for the closure (avoid capturing self strongly)
    let signalL = signalProL
    let signalR = signalProR

    inputNode.installTap(onBus: 0, bufferSize: AVAudioFrameCount(bufferSize), format: nil) {
      [weak self] buffer, _ in
      guard let self = self, self.isRecording else { return }

      let frameLength = Int(buffer.frameLength)
      guard frameLength > 0 else { return }

      // Extract samples from buffer
      guard let channelData = buffer.floatChannelData else { return }

      // On iOS, if stereo: channel 0 = L, channel 1 = R
      // If mono, use same data for both
      let ch0 = channelData[0]
      let ch1 = channelCount > 1 ? channelData[1] : channelData[0]

      let sampleCount = min(frameLength, halfBuffer)
      guard sampleCount > 100 else { return }

      var recordingL = [Int16](repeating: 0, count: sampleCount)
      var recordingR = [Int16](repeating: 0, count: sampleCount)

      for i in 0..<sampleCount {
        recordingL[i] = Int16(clamping: Int(ch0[i] * 32767))
        recordingR[i] = Int16(clamping: Int(ch1[i] * 32767))
      }

      // Process on audio thread (SignalProcessing is nonisolated)
      let disAmpL = signalL.process(recordingL)
      let disAmpR = signalR.process(recordingR)

      // Extract best distance
      var newDistL = disAmpL.first?[0] ?? 0
      var newDistR = disAmpR.first?[0] ?? 0

      // Apply the Android distance filtering heuristics
      let currentDistR = self.distR
      let currentDistL = self.distL

      for i in 0..<disAmpL.count {
        if disAmpL[i][0] < 0.95 && disAmpL[i][0] > 0.7 && abs(disAmpL[i][0] - currentDistR) > 0.2 {
          newDistL = disAmpL[i][0]
          break
        }
      }

      for i in 0..<disAmpR.count {
        if disAmpR[i][0] > 1.3 && disAmpR[i][0] < 1.5 && abs(disAmpR[i][0] - currentDistL) > 0.2 {
          newDistR = disAmpR[i][0]
          break
        }
      }

      // Dispatch results to main thread
      DispatchQueue.main.async {
        self.distL = newDistL
        self.distR = newDistR
      }
    }

    do {
      try engine.start()
      isRecording = true
      print(
        "[AudioRecorder] Started recording at \(inputFormat.sampleRate)Hz, \(inputFormat.channelCount)ch"
      )
    } catch {
      print("[AudioRecorder] Engine start error: \(error)")
    }
  }

  /// Stop recording.
  func stop() {
    isRecording = false
    audioEngine?.inputNode.removeTap(onBus: 0)
    audioEngine?.stop()
    audioEngine = nil
    print("[AudioRecorder] Stopped recording")
  }
}
