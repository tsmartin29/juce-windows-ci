// Headless test for the example plug-in. Plain console exe: prints one line per check and exits non-zero on any failure.
// It runs on the Windows runner (no audio device, no real window): DSP, state round trip, editor render to an image.
#include <juce_audio_processors/juce_audio_processors.h>
#include <juce_gui_basics/juce_gui_basics.h>
#include "PluginProcessor.h"
#include "PluginEditor.h"

static int failures = 0, checks = 0;

static void check (bool ok, const juce::String& what)
{
    ++checks;
    if (! ok) ++failures;
    std::printf ("%s  %s\n", ok ? "ok  " : "FAIL", what.toRawUTF8());
}

// True if the image holds more than one distinct colour (i.e. something was painted, not a blank rectangle).
static bool hasContent (const juce::Image& img)
{
    if (! img.isValid()) return false;
    const auto first = img.getPixelAt (0, 0);
    for (int y = 0; y < img.getHeight(); y += 2)
        for (int x = 0; x < img.getWidth(); x += 2)
            if (img.getPixelAt (x, y) != first) return true;
    return false;
}

static void testDsp()
{
    GainProcessor p;
    p.setPlayConfigDetails (2, 2, 48000.0, 256);
    p.prepareToPlay (48000.0, 256);

    auto run = [&p] (float gainDb)
    {
        if (auto* prm = p.apvts.getParameter ("gain"))
            prm->setValueNotifyingHost (prm->convertTo0to1 (gainDb));
        p.prepareToPlay (48000.0, 256);       // snap the smoother to the new value
        juce::AudioBuffer<float> b (2, 256);
        for (int ch = 0; ch < 2; ++ch)
            for (int i = 0; i < 256; ++i) b.setSample (ch, i, 0.5f);
        juce::MidiBuffer midi;
        p.processBlock (b, midi);
        return b.getSample (0, 255);
    };

    check (std::abs (run (0.0f) - 0.5f) < 1.0e-5f, "0 dB leaves the signal alone");
    check (std::abs (run (-6.0f) - 0.5f * juce::Decibels::decibelsToGain (-6.0f)) < 1.0e-4f, "-6 dB halves (about) the level");
    check (std::abs (run (12.0f) - 0.5f * juce::Decibels::decibelsToGain (12.0f)) < 1.0e-3f, "+12 dB boosts the level");

    juce::AudioBuffer<float> silence (2, 256);
    silence.clear();
    juce::MidiBuffer midi;
    p.processBlock (silence, midi);
    check (silence.getMagnitude (0, 256) == 0.0f, "silence stays silent");
}

static void testState()
{
    GainProcessor a, b;
    if (auto* prm = a.apvts.getParameter ("gain"))
        prm->setValueNotifyingHost (prm->convertTo0to1 (-18.0f));
    juce::MemoryBlock blob;
    a.getStateInformation (blob);
    b.setStateInformation (blob.getData(), (int) blob.getSize());
    check (std::abs (b.apvts.getRawParameterValue ("gain")->load() - (-18.0f)) < 0.05f, "state round trip restores the gain");
}

// Render the editor offscreen. This does NOT depend on the size of the runner's display: createComponentSnapshot paints
// the component into an image, no OS window is opened. Sizes are printed, not just asserted, so a CI log tells you why.
static void testEditor()
{
    GainProcessor p;
    std::unique_ptr<juce::AudioProcessorEditor> ed (p.createEditor());
    check (ed != nullptr, "createEditor returns an editor");
    if (ed == nullptr) return;

    std::printf ("      editor opens at %d x %d\n", ed->getWidth(), ed->getHeight());
    check (ed->getWidth() == 320 && ed->getHeight() == 240, "editor opens at its default size");

    for (double scale : { 0.7, 1.0, 2.0 })
    {
        const int w = juce::jlimit (200, 800, (int) (320 * scale)), h = juce::jlimit (160, 640, (int) (240 * scale));
        ed->setSize (w, h);
        auto img = ed->createComponentSnapshot (ed->getLocalBounds(), true, 1.0f);
        std::printf ("      scale %.1f -> %d x %d, snapshot %d x %d\n", scale, ed->getWidth(), ed->getHeight(), img.getWidth(), img.getHeight());
        check (img.getWidth() == w && img.getHeight() == h && hasContent (img),
               "editor renders non-blank at scale " + juce::String (scale, 1));
    }
}

int main()
{
    juce::ScopedJuceInitialiser_GUI gui;       // message manager + fonts, no windows
    testDsp();
    testState();
    testEditor();
    std::printf ("\n%d checks, %d failed\n", checks, failures);
    return failures == 0 ? 0 : 1;
}
