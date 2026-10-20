# Portable FFT note

On macOS it is natural to use Accelerate (vDSP) for FFTs. It does not exist on Windows. Options for the Windows build, in the order we would try them:

1. **`juce::dsp::FFT`.** Already in JUCE, cross-platform, float precision. Good enough for most DSP.
2. **A small radix-2 FFT in double precision.** Our STFT had to match a PyTorch reference (the `torch.stft` of a neural network we ported to ONNX) to better than -130 dB. Single-precision FFTs could not do that; a plain iterative radix-2 FFT in `double`, with precomputed twiddle factors and a bit-reversal table, did. Real-input transforms are done through one complex FFT of half the length. It is slower than vDSP and fast enough for offline analysis; measure before using it on the audio thread.
3. **A vendored library** such as pocketfft, if you need arbitrary sizes or more speed.

Keep the macOS path untouched behind `#if JUCE_MAC` while you port: the Mac build is your reference. Test the Windows FFT against the Mac one (forward then inverse should return the input; compare against a naive DFT on small sizes) before you chase differences in the plug-in's output.

The same applies to BLAS calls (`cblas_*` from Accelerate): write a plain C++ fallback first, then measure it on the runner before deciding whether it needs a library.
