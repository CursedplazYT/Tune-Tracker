# Audio classification Yamnet

|      | Android | iOS | Linux | Mac | Windows | Web |
|------|---------|-----|-------|-----|---------|-----|
| live | ✅       | ✅   |       |    |         |     |

This project is a sample of how to perform Audio Classification using
TensorFlow Lite in Flutter. It includes support for both Android and IOS.

## Download model and labels


To build the project, you must first download the YAMNET TensorFlow Lite
model and its corresponding labels. You can do this by
running `sh ./scripts/download_model.sh` from the root folder of the repository.

## About the sample

- You can use Flutter-supported IDEs such as Android Studio or Visual Studio.
  This project has been tested on Android Studio Flamingo.
- Before building, ensure that you have downloaded the model and the labels by
  following a set of instructions.

## Overview
This app tracks the playtime of a piano player. It uses TensorFlow Lite to perform real-time audio classification. It listens to the microphone input and processes and classifies sounds based on a pre-trained model. 
## Features
- Real-time Audio Classification: Uses TensorFlow Lite to classify   incoming Audio.
- User-Friendly Interface: Simple and interactive UI for easy usability.
- Customized Model Support: Ability to swap out TFLlite models for different sound classification tasks.
## Screenshots
![Screenshot 2025-03-01 154719](https://github.com/user-attachments/assets/785283f3-2ebc-416e-9e62-0fb6c01c8f1e)
![Screenshot 2025-03-01 154642](https://github.com/user-attachments/assets/cee4db4a-abb7-4266-8412-2e821973ba2d)
