# Analog message audio sources

These short audio clips drive analog modulation (FM/PM/AM variants) as the
message baseband. Digital modulation uses `RandomBit` instead; see
`csrd.support.modulation.messageSourceForModulation`.

All clips are derived from **public-domain** NASA recordings (works of the U.S.
Government, no copyright) obtained via Wikimedia Commons. Each was trimmed to a
short segment, downmixed to mono, resampled to 44.1 kHz, and peak-normalized.

| File | Source (Wikimedia Commons) | Original | License |
| --- | --- | --- | --- |
| `nasa_apollo1_voice.wav` | `File:Apollo One Recording.ogg` | NASA mission voice audio | Public Domain (NASA / U.S. Gov) |
| `nasa_gemini_jingle_music.wav` | `File:Gemini VI Jingle Bells.ogg` | NASA Gemini VI music | Public Domain (NASA / U.S. Gov) |

Clips are continuous voice/music with real spectral content (beacon-tone and
sonification clips were dropped because their near-silent / near-DC segments
made occupied-bandwidth estimation degenerate for narrowband analog modulation).

The legacy bundled clip `../audio_mix_441.wav` is also used as a source.

Selection among these files is deterministic given the scenario/burst seed so
runs remain reproducible (see `Audio.m`).
