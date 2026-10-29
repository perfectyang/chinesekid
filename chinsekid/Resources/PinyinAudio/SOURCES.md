# Pinyin audio sources

- Initials and finals (`*.mp3` without a tone number): `sreading.org/pinyin` audio mirrored in the `data` branch of https://github.com/zispace/hanyu-pinyin-audio.
- Whole-recognition syllables: all 16 use audio from the Chinese Language Institute (StudyCLI) pinyin chart, mirrored in the `data` branch of https://github.com/zispace/hanyu-pinyin-audio.
- Standalone simple-final tones (`a1`–`a4`, `e1`–`e4`, `i1`–`i4`, `u1`–`u4`, and `v1`–`v4`): https://github.com/cmguo/PinYinSound. The `v` filenames represent `ü`.
- Syllable-and-tone recordings used by 拼读小火车 (for example, `ba1.mp3`): https://github.com/cmguo/PinYinSound. Only recordings for the combinations offered in the app are bundled; missing tones fall back to system speech.
- Standalone `o` tones (`o1`–`o4`): the Mandarin Temple audio collection mirrored in https://github.com/zispace/hanyu-pinyin-audio/tree/data/mandarintemple.com/audio. The source identifies `o1` as `喔` (ō), providing the intended unrounded standalone vowel without the `w` onset of `我`. `o1.wav` is stored locally as `o.mp3` to preserve the app's existing resource lookup.

The filenames used for whole-recognition syllables include tone numbers so they cannot be confused with the no-tone initials and finals. The GitHub collection identifies the StudyCLI pinyin chart as the upstream audio source for this group.

All 87 active pinyin clips are peak-normalized to approximately -3.5 dBFS for consistent playback volume. This changes gain only; it does not alter pitch or pronunciation.
