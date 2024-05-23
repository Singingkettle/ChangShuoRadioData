# Introduction

A good data is curcial for the success of signal recognition tasks.
However, some of few datas are publicly acesseed in the current time (such as [deepsig]() for modulation classification
task, [ucla](https://cores.ee.ucla.edu/downloads/datasets/wisig/) for specific emmitter identification).
Basically, a signal data recognition pipline is:

1. signal detection or localision task: when (time duration) and where (center frequency and band) exists a signal
2. signal type: modulation type or other type (such as: wifi vs 5g)
3. emitter type: friendly or not friendly, which one (like face recognition)
4. emitter location: figure out the intrerested signal location

# What's new

v0.0.1 was released in 23/01/2024, which was located in ref/DataSimulationTool
you can run generate.m to simulate wireless data, and
use [ChangShuoRadioRecognition](https://github.com/Singingkettle/ChangShuoRadioRecognition) to do a joint DL model for
radio detection and modulation classification
