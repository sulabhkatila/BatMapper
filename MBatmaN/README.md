# BatMapper iOS

[BatMapper](https://www.researchgate.net/publication/317634120_BatMapper_Acoustic_Sensing_Based_Indoor_Floor_Plan_Construction_Using_Smartphones) maps the geometry of the environment (rooms, hallways) without using any photo signals. It uses your speaker and microphone!

Since Bats can't really see, they use echo-location to map out their environment to be able to catch their preys. Bats, basically, shout and, then, wait for their sound waves to bounce back from surfaces. By calculating how long the waves take to get back to them, they understand how far each "thing" is in their surrounding.


[BatMapper](https://www.researchgate.net/publication/317634120_BatMapper_Acoustic_Sensing_Based_Indoor_Floor_Plan_Construction_Using_Smartphones) showed that it is possible to implement such features in modern smartphones.

This repository represents the iOS app that builds on the paper.


## How the app works

* **Speakers**: This, obviously, is what makes the sound. We produce sounds of very specific frequencies. These specific sounds are what strike the surrounding objects and bounce back towards the phone.

* **Microphones**: After the speaker makes the sound, we wait for the sound to bouce back and hit our microphones. a standard iPhone has 4 microphones. One on the top, one on the bottom, and two in the back (near where the camera is). The 2 back microphones help get better videos and are a very new concept. It wasn't a standard when the paper was written. The app only uses the top and bottom microphones for the calculations.

* **IMU sensors**: Accelerometer and Gyroscope are used to map user movements in the environment that is getting mapped. It also helps account for and eliminate any undesired movements (like arm swings) that comes with real-life data collection. 

### Putting everything together

As the user walks through an indoor environment with the app running, the device continuously emits chirps (The Sound signal), records echoes, and tracks motion using the IMU.

Each chirp provides a snapshot of nearby surfaces from the phone's current position. As more measurements are collected from different locations, the app combines them to build a larger picture of the surrounding space.
