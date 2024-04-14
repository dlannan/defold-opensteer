# defold-opensteer
A port of opensteer as a native extension for Defold based on the JS one I previously did here:
https://github.com/dlannan/opensteer/

![Pedestrian Demo](/screenshots/2024-04-14_13-12.png)
![Soccer Demo](/screenshots/2024-04-14_13-13.png)

The original OpenSteer project is available in a couple of places:
https://opensteer.sourceforge.net/
https://github.com/meshula/OpenSteer

The OpenSteer here is incomplete and only the Soccer demo and the pedestrian demo have been made operational.
There are likely a number of issues with the steering library that still need resolving.
I hope to improve this over time.

## Uses
Opensteer is a library I have used in many projects over the years (usually highly modified) to be able to achieve
a number of capabilities in simulations and games. Some of these are:
- Character control and behavior
- Vehicle traffic control and behavior
- Group management in large scale (LQDB specifically)
- Phsyics systems that need course initial collision checks

## Licenses
This project is distributed under the MIT license as OpenSteer is. 

The included assets (male and female characters) are free models from Sketchfab here:
Male Walking: https://skfb.ly/o7SrW   License: Free Standard
Female Walking: https://skfb.ly/o7Srw   License: Free Standard
Please credit the Author for this work if you use it, and make sure you follow licensing guidelines from Sketchfab.
Author: Denys Almaral
https://sketchfab.com/denysalmaral

I highly recommend his work. They were very easy to use directly from sketfab in gltf format into Defold. Thanks!


