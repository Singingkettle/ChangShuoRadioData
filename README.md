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

# Notes

These notes are mainly about how to simulate a real wireless communication system.

1. How to convert a baseband to a passband signal (Date: 2024/05/23)
```
https://www.mathworks.com/help/comm/ug/passband-modulation.html
```

2. Using a cache tools to avoid duplicate initialization about some method (such as, filters' coefficients), which are very time consuming (Date: 2024/06/04).

3. Product of SPS and SPAN must be even.

4.  About the valid values for DVABSAPSK the doc in matlab is not consistent with the official code, we use the official code to define the config parameters' range. As a result, there are bugs about codeIDF about doc link: https://www.mathworks.com/help/comm/ref/dvbsapskmod.html