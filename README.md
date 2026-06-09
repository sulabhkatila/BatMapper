# BatMapper iOS


My room is sqaure-ish... rectangle for sure. Below is the video that confirms that geometry.

I open the app, put my phone horizontally, and hit record, and it instants emits a sound that feels like is piercing my ear-drums. But I resist, and walk along the edges (about 0.5 meters away) of my ro0m. The slim blue line in the picture shows my motion. As I walk, the phone starts mapping the geometry of the room. It starts drawing yellow and red dots for the points in the room where there exists walls and blue dots where there is open space.


This way we know where and how far exactly the walls are (The exact numbers are also available).


### Video and picture confirming there is space in my room and also that there are four walls.

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
