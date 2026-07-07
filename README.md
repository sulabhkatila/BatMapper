# BatMapper iOS

> [!Note]
> The unofficial iOS implementation of the [BatMapper](https://www.researchgate.net/publication/317634120_BatMapper_Acoustic_Sensing_Based_Indoor_Floor_Plan_Construction_Using_Smartphones) paper

Bats use echolocation to understand their enivronment and move around.

They emit sounds and wait for the sound to hit objects and get back to them. Based on how long the echo takes to get back to them, they are able to crate a map of their surrounding.

Smart-phones have speakers, microphones, and a processor. Which means they can produce sound, hear sound, and do calculations. Its true... your phone is a bat.

[BatMapper](https://www.researchgate.net/publication/317634120_BatMapper_Acoustic_Sensing_Based_Indoor_Floor_Plan_Construction_Using_Smartphones) maps the geometry of the environment (rooms, hallways) without using any photo signals. It uses your speaker and microphone!


## Demo

My room is sqaure-ish... rectangle for sure. Below is the video that confirms that geometry.

> Video and picture confirming there is space in my room (despite living in NYC) and also that there are four walls.
> Blue represents open space and the red and yellow lines represent the walls.

<table>
  <tr>
    <td width="50%" align="center">

<img src="https://github.com/user-attachments/assets/8c83d462-6058-43ee-8069-b3601e56cd22" width="70%">

   </td>
    <td width="50%" align="center">

https://github.com/user-attachments/assets/02d54c66-d9f6-4cf8-9d7c-078b0f3b717c

   </td>
  </tr>
</table>


## How the app works

> [!Note]
> This section is basically a simple enough paraphrase of the entire paper with some additional background and without the technical specifities.

### Some Background
#### What parts of our phones are relevant to us?

- **Speaker**: Phones have 1 main speaker that can generate sounds of varied pitch (up-to 20 kHZ).

- **Microphones**: Phones can have many microphones but minimally they will have at-least 2 microphones. One near top and one near bottom. The main purpose of the bottom microphone is really to capture human voice for calls. This means it is designed to capture near field low frequency sound waves. The top microphone is slightly more capable-- it can capture even more distant sounds with even higher frequencies. With power comes problems... the top microphone, because it is so capable, also captures more noise.

- **IMU sensors**:
    - Accelerometer: Measures how quickly the phone is accelerating in the x, y, and z directions. (Scaling factors for the 3 unit vectors of the acceleration vector.)
    - Gyroscope: Measures how quickly the phone is rotating about the x, y, and z axes. (Scaling factors for the 3 unit vectors of the angular velocity vector.)
    > This implementation uses pedometer but thats adds zero value. I just thought having steps would look cool in the UI, however, pedometer does not provide step metrics as they are being taken. Which means 0 value added to UI as well. And I will be removing it shortly.

#### Physics

##### What is sound?
- Sound is a wave that travels through a medium (like air).

- Amplitude of the wave determines the loudness of the sound. The higher the amplitude of the wave the louder the sound. Sound from afar are fainter because they loose amplitude while traveling.

- Frequency of the wave determines the pitch of the sound. Higher the frequency the higher the pitch.

- **Echo**: A reflected sound wave that returns to the microphone after bouncing off a surface. The reflected sound has the same frequency as the original sound (assuming stationary subjects, refer to Dopler effect for more information), but its amplitude is reduced because some energy is lost during propagation.

- **Pure tone**: A sound consisting of a single frequency. Most sounds in the natural world are not pure tones—they are combinations of many frequencies occurring simultaneously. If represented in crest and trough, they'd be sine waves. To build intuition, think of the sustained note of a piano key. (Technically, a piano note is not a pure tone, but it is a useful approximation.)

- **Complex sound**: A sound consisting of many pure tones. When two pure-tones are combined their amplitutes (at every point) add up to form a this new wave (complex sound). In other words, If a sound cannot be represented by a single a sine wave with some amplitude and frequency, then it is a complex sound. Everything in the real word, is basically a complex sound.

##### FFT
- A magical black box to which, if we provide a wave (sound), it outputs all the distinct pure tones that make up the wave.

##### What is movement?
- Movement is simply a change in position over time.

- In a 2D plane, we can represent an object's position using two coordinates: **(x, y)**.

- If the object moves, these coordinates change. The change in these coordinates over time is movement.

##### How to map movement (it has a cool name: The DEAD Reckoning)
- Imagine user start at some coordinate, eg. **(0, 0)**

- After any motion, calculate current position in relation to prior position to get the new coordinate.

- Repeat the process for everytime motion is sensed.

### Putting everything together

As the user walks through an indoor environment with the app running, the device continuously emits chirps (The Sound signal), records echoes, and tracks motion using the IMU sensors.

FFT is used to 

Each chirp provides a snapshot of nearby surfaces from the phone's current position. As more measurements are collected from different locations, the app combines them to build a larger picture of the surrounding space.

## Technical Architecture

Under the hood, BatMapper is built with a modular architecture in Swift, separating UI, orchestration, audio processing, and motion tracking.

### 1. Orchestration (`BatMapperViewModel`)

The `BatMapperViewModel` acts as the central brain of the app, running on the `MainActor`. It orchestrates the `ChirpEmitter`, `AudioRecorder`, and `MotionTracker`. It uses a high-frequency (20Hz) refresh timer to synchronize background tracking data into `@Published` properties, ensuring a smooth, reactive UI in SwiftUI. It also manages exporting the generated map to a PDF format.

### 2. Acoustic Subsystem (`AudioEngine`)

The acoustic module handles the emission of the sonar signal and the recording of the echoes.

- **ChirpEmitter**: Uses `AVAudioPlayer` to continuously loop a specific high-frequency `chirp.wav` template through the device's speakers.
- **AudioRecorder**: Leverages `AVAudioEngine` to tap the microphone bus at a high sample rate (48kHz). It extracts left and right channel audio buffers and feeds them into the signal processing pipeline on a background thread. It also applies validation heuristics to ensure only stable wall distances are passed to the view model.

### 3. Signal Processing Pipeline (`SignalProcessing`)

The core algorithm that translates raw audio into distance measurements. It runs concurrently for both audio channels and consists of several stages:

- **IIR Bandpass Filter**: Isolates the specific frequencies of the emitted chirp, removing background noise.
- **Cross-Correlation**: Matches the filtered audio against the known chirp template to pinpoint exactly when the chirp was emitted and when echoes returned.
- **Gaussian Smoothing & Peak Detection**: Smooths the correlation results and identifies local maxima (peaks), representing acoustic reflections (echoes).
- **Distance Generation**: Calculates the distance to the reflecting surface using the time delay of the peaks and the speed of sound.

### 4. Motion & Map Generation (`MotionTracker` & `InertialTracking`)

This module combines the acoustic distances with the user's movement to construct the 2D floor plan.

- **Orientation & Steps**: Uses `CMMotionManager` for device attitude (yaw) and `CMPedometer` for step detection. It includes custom smoothing to detect right-angle turns and snap orientation, compensating for drift.
- **Point Generation**: As the user walks, it interleaves their positional trace with the detected left and right wall coordinates (derived from the audio distance and current yaw).
- **Door Detection**: Monitors the history of wall distances. Sudden, temporary increases in depth (recesses) are classified as open doors and marked distinctively on the map.
- **Loop Closure**: Corrects accumulated drift in the map when the user completes a loop and returns to a previously visited area.

## Privacy First

All computation is done completely locally on your device. The app uses your microphone and speaker to generate map points in real-time, and **no data ever leaves your phone**.

## How to run it

### 1. Download the code

You can download the project as a ZIP file or clone the repository via git:

```bash
git clone https://github.com/sulabhkatila/batmapper.git
```

### 2. Compile and install using Xcode

1. Open the `MBatmaN.xcodeproj` file in Xcode.
2. Connect your iPhone to your Mac and select it as the build target at the top of the Xcode window.
3. **Sign the code**:
    - Click on the `MBatmaN` project file in the left navigator.
    - Go to the **Signing & Capabilities** tab.
    - Select your personal Apple ID in the **Team** dropdown. If you haven't added your account, you can do so in Xcode Settings > Accounts.
4. **Enable Developer Mode on your iPhone**:
    - On your iPhone, go to **Settings > Privacy & Security > Developer Mode**.
    - Turn it on and restart your phone when prompted.
    - After restarting, confirm turning on Developer Mode and enter your passcode.
5. Hit the **Run** button (the play icon) in Xcode to compile and install the app on your phone.
    - _Note: On the first installation, you might need to trust your developer certificate. On your iPhone, go to **Settings > General > VPN & Device Management**, tap your Apple ID under Developer App, and choose to "Trust" it._

### 3. Using the App

1. Open the BatMapper app on your iPhone.
2. Hold your phone **horizontally** in front of you.
3. Hit the **Record** button to start.
4. Move around the floor that you want to map. The app will emit its sonar chirps, and you will see the map geometry updating dynamically as you walk.
